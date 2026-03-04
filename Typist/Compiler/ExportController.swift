//
//  ExportController.swift
//  Typist
//
//  Shared export state and actions used by DocumentListView and DocumentEditorView.
//

import Foundation
import Observation

@Observable
final class ExportController {
    var isExporting = false
    var exportError: String?
    var exportURL: URL?

    func exportPDF(for document: TypistDocument) {
        guard !isExporting else { return }
        isExporting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await ExportManager.compilePDF(for: document)
            isExporting = false
            switch result {
            case .success(let data):
                do { exportURL = try ExportManager.temporaryPDFURL(data: data, title: document.title) }
                catch { exportError = error.localizedDescription }
            case .failure(let error):
                exportError = error.localizedDescription
            }
        }
    }

    func exportTypSource(for document: TypistDocument, fileName: String) {
        do { exportURL = try ExportManager.temporaryTypURL(for: document, fileName: fileName) }
        catch { exportError = error.localizedDescription }
    }

    func exportZip(for document: TypistDocument) {
        guard !isExporting else { return }
        isExporting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                exportURL = try await Task.detached {
                    try await ExportManager.zipProject(for: document)
                }.value
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }
}
