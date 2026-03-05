//
//  TypstCompiler.swift
//  Typist
//
//  Debounced compile pipeline: source → Rust FFI → PDFKit document.
//

import Foundation
import PDFKit
import Observation

@Observable
final class TypstCompiler {
    private(set) var pdfDocument: PDFDocument?
    private(set) var errorMessage: String?
    private(set) var isCompiling: Bool = false
    /// Tracks whether a compiled PDF is currently available.
    private(set) var compiledOnce: Bool = false

    private var compileTask: Task<Void, Never>?
    private var compileGeneration: UInt64 = 0

    /// Schedule a compilation 500 ms after the last call.
    /// Cancels any in-flight compile task before scheduling a new one.
    func compile(source: String, fontPaths: [String], rootDir: String? = nil) {
        compileTask?.cancel()
        compileGeneration &+= 1
        let generation = compileGeneration
        compileTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return // cancelled — do nothing
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard generation == self.compileGeneration else { return }
                self.isCompiling = true
            }

            let result = await Task.detached(priority: .userInitiated) {
                TypstBridge.compile(source: source, fontPaths: fontPaths, rootDir: rootDir)
            }.value

            await MainActor.run {
                guard generation == self.compileGeneration else { return }
                self.isCompiling = false
                switch result {
                case .success(let pdfData):
                    self.pdfDocument = PDFDocument(data: pdfData)
                    self.errorMessage = nil
                    self.compiledOnce = (self.pdfDocument != nil)
                case .failure(let error):
                    // Keep the last successful PDF visible; only update the error banner.
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clear current preview content and cancel any in-flight compilation.
    func clearPreview() {
        compileTask?.cancel()
        compileTask = nil
        compileGeneration &+= 1
        isCompiling = false
        pdfDocument = nil
        errorMessage = nil
        compiledOnce = false
    }

    /// Cancel any in-flight compilation (e.g. when document is closed).
    func cancel() {
        compileTask?.cancel()
        compileTask = nil
        compileGeneration &+= 1
        isCompiling = false
    }
}
