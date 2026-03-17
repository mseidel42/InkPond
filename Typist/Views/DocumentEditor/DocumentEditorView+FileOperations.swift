//
//  DocumentEditorView+FileOperations.swift
//  Typist
//

import Foundation
import SwiftUI
import SwiftData

extension DocumentEditorView {
    func prepareDocumentForEditing() {
        ProjectFileManager.ensureProjectRoot(for: document)

        let typFiles = ProjectFileManager.listAllTypFiles(for: document)
        if document.requiresImportConfiguration || document.requiresInitialEntrySelection {
            let resolution = ProjectFileManager.resolveImportedEntryFile(from: typFiles)
            if let suggestedEntry = resolution.entryFileName {
                if !typFiles.contains(document.entryFileName) {
                    document.entryFileName = suggestedEntry
                }
                if resolution.requiresInitialSelection && document.importEntryFileOptions.isEmpty {
                    document.importEntryFileOptions = typFiles
                }
            }
            if !resolution.requiresInitialSelection {
                document.importEntryFileOptions = []
            }
            document.requiresInitialEntrySelection = resolution.requiresInitialSelection
            applyAutomaticImportDirectories()
            document.requiresImportConfiguration = document.requiresInitialEntrySelection
                || !document.importImageDirectoryOptions.isEmpty
                || !document.importFontDirectoryOptions.isEmpty
            if document.requiresImportConfiguration {
                showingImportConfiguration = true
                currentFileName = ""
                editorText = ""
                entrySource = ""
                return
            }
        }

        ProjectFileManager.migrateContentIfNeeded(for: document)
        loadFile(named: document.entryFileName)
    }

    func loadFile(named name: String) {
        saveTask?.cancel()
        saveTask = nil

        // If the file is in iCloud and not yet downloaded, trigger download
        let fileURL = ProjectFileManager.typFileURL(named: name, for: document)
        if ProjectFileManager.useCoordination {
            try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
        }

        let text = (try? ProjectFileManager.readTypFile(named: name, for: document)) ?? ""
        insertionRequest = nil
        pendingCursorJump = nil
        editorViewState = EditorViewState()
        currentFileName = name
        isLoadingFileContent = true
        editorText = text
        isLoadingFileContent = false
        lastPersistedText = text
        if name == document.entryFileName {
            entrySource = text
        }
        compilationErrorLines = recomputeCompilationErrorLines()
        pumpPendingInsertionsIfNeeded()
    }

    func handleEditorTextChange(_ content: String) {
        guard !currentFileName.isEmpty else { return }
        if isEditingEntryFile {
            entrySource = content
        }
        scheduleSave(content: content, for: currentFileName)
    }

    func scheduleSave(content: String, for fileName: String) {
        guard fileName == currentFileName else { return }
        guard content != lastPersistedText else {
            saveTask?.cancel()
            saveTask = nil
            return
        }

        let fileURL = ProjectFileManager.typFileURL(named: fileName, for: document)
        let shouldRefreshPreviewAfterSave = fileName != document.entryFileName

        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            do {
                try await backgroundFileWriter.write(content, to: fileURL)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if self.currentFileName == fileName, self.editorText == content {
                        self.lastPersistedText = content
                        self.document.modifiedAt = Date()
                        if shouldRefreshPreviewAfterSave {
                            self.compileToken = UUID()
                        }
                    }
                    self.saveTask = nil
                }
            } catch {
                await MainActor.run {
                    self.fileSaveError = error.localizedDescription
                    self.saveTask = nil
                }
            }
        }
    }

    func flushPendingSave() {
        saveTask?.cancel()
        saveTask = nil
        persistCurrentFileImmediately(content: editorText)
    }

    func persistCurrentFileImmediately(content: String) {
        guard !currentFileName.isEmpty else { return }
        guard content != lastPersistedText else { return }

        let shouldRefreshPreviewAfterSave = currentFileName != document.entryFileName
        let fileURL = ProjectFileManager.typFileURL(named: currentFileName, for: document)

        do {
            if ProjectFileManager.useCoordination {
                try CloudFileCoordinator.writeString(content, to: fileURL)
            } else {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            lastPersistedText = content
            document.modifiedAt = Date()
            if shouldRefreshPreviewAfterSave {
                compileToken = UUID()
            }
        } catch {
            fileSaveError = error.localizedDescription
        }
    }

    func applyAutomaticImportDirectories() {
        if !ProjectFileManager.requiresImportDirectorySelection(document.importImageDirectoryOptions) {
            if let autoImageDirectory = ProjectFileManager.defaultImportDirectory(from: document.importImageDirectoryOptions) {
                document.imageDirectoryName = autoImageDirectory
            }
            document.importImageDirectoryOptions = []
        }

        if !ProjectFileManager.requiresImportDirectorySelection(document.importFontDirectoryOptions) {
            if let autoFontDirectory = ProjectFileManager.defaultImportDirectory(from: document.importFontDirectoryOptions) {
                _ = ProjectFileManager.importFontFiles(from: autoFontDirectory, for: document)
            }
            document.importFontDirectoryOptions = []
        }
    }

    func persistEditorPosition() {
        document.lastEditedFileName = currentFileName
        document.lastCursorLocation = editorViewState.selectedLocation
    }

    func scheduleEditorPositionSync(delay: Duration = .milliseconds(700)) {
        positionSyncTask?.cancel()
        positionSyncTask = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                persistEditorPositionIfNeeded()
            }
        }
    }

    func persistEditorPositionIfNeeded() {
        guard !currentFileName.isEmpty else { return }
        let nextFileName = currentFileName
        let nextLocation = editorViewState.selectedLocation
        guard document.lastEditedFileName != nextFileName || document.lastCursorLocation != nextLocation else {
            return
        }

        persistEditorPosition()
        try? modelContext.save()
    }

    func hasSavedPosition() -> Bool {
        document.lastCursorLocation > 0
    }

    func restoreSavedPosition() {
        let savedFileName = document.lastEditedFileName
        if !savedFileName.isEmpty, savedFileName != currentFileName {
            openFile(named: savedFileName)
        }
        pendingCursorJump = document.lastCursorLocation
        pendingPreviewSync = true
    }

    func syncCursorToPreviewIfPending() {
        guard pendingPreviewSync else { return }
        pendingPreviewSync = false

        guard let sourceMap = compiler.sourceMap, !sourceMap.isEmpty else { return }
        guard syncCoordinator.beginSync(.editorToPreview) else { return }

        let cursorLocation = editorViewState.selectedLocation
        let text = editorText as NSString
        let prefix = cursorLocation <= text.length
            ? text.substring(to: cursorLocation)
            : editorText
        let line = prefix.components(separatedBy: "\n").count

        if let target = sourceMap.pdfPosition(forLine: line) {
            syncCoordinator.previewScrollTarget = PreviewScrollTarget(
                page: target.page,
                yPoints: target.yPoints,
                xPoints: target.xPoints
            )
        }
        syncCoordinator.endSync()
    }

    func openFile(named name: String) {
        flushPendingSave()
        loadFile(named: name)
        InteractionFeedback.selection()
    }

    func compilePreviewNow() {
        flushPendingSave()
        pendingManualCompileFeedback = true
        compiler.compileNow(
            source: entrySource,
            fontPaths: compileFontPaths,
            rootDir: rootDir,
            previewCachePolicy: .bypassCache,
            previewCacheDescriptor: compiledPreviewCacheDescriptor
        )
    }

    func clearCachesAndRecompile() {
        flushPendingSave()
        pendingManualCompileFeedback = true
        InteractionFeedback.notify(.warning)
        AccessibilitySupport.announce(L10n.a11yCacheRefreshStarted)
        let source = entrySource
        let fontPaths = compileFontPaths
        let rootDirectory = rootDir

        compiler.clearPreview()

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PreviewPackageCacheStore().clearAll()
                }.value
                await MainActor.run {
                    compiler.compileNow(
                        source: source,
                        fontPaths: fontPaths,
                        rootDir: rootDirectory,
                        previewCachePolicy: .bypassCache,
                        previewCacheDescriptor: compiledPreviewCacheDescriptor
                    )
                }
            } catch {
                await MainActor.run {
                    previewActionError = error.localizedDescription
                }
            }
        }
    }

    @discardableResult
    func refreshCompileFontPaths() -> Bool {
        let latestPaths = FontManager.allFontPaths(for: document)
        guard latestPaths != compileFontPaths else { return false }
        compileFontPaths = latestPaths
        return true
    }

    func handleCompileInputsChanged() {
        guard refreshCompileFontPaths() else { return }
        guard canTriggerPreviewActions else { return }
        compileToken = UUID()
    }

    func refreshReferenceCompletions() {
        let projectDir = ProjectFileManager.projectDirectory(for: document)
        let fm = FileManager.default

        var bibEntries: [(key: String, type: String)] = []
        if let items = try? fm.contentsOfDirectory(atPath: projectDir.path) {
            for item in items where item.hasSuffix(".bib") {
                let url = projectDir.appendingPathComponent(item)
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    bibEntries.append(contentsOf: CompletionEngine.parseBibTeX(content))
                }
            }
        }
        cachedBibEntries = bibEntries

        let engine = CompletionEngine.shared
        var labels: [(name: String, kind: String)] = []
        let typFiles = ProjectFileManager.listAllTypFiles(for: document)
        for file in typFiles where file != currentFileName {
            if let content = try? ProjectFileManager.readTypFile(named: file, for: document) {
                labels.append(contentsOf: engine.scanLabels(in: content))
            }
        }
        cachedExternalLabels = labels

        refreshImageFiles()
    }

    func refreshImageFiles() {
        let allFiles = ProjectFileManager.listAllFiles(in: ProjectFileManager.projectDirectory(for: document))
        let imageExtensions = ProjectFileManager.supportedImageFileExtensions
        cachedImageFiles = allFiles.filter { path in
            let ext = (path as NSString).pathExtension.lowercased()
            return imageExtensions.contains(ext)
        }
    }

    func triggerZipExport() {
        if appFontLibrary.isEmpty {
            flushPendingSave()
            exporter.exportZip(for: document)
        } else {
            showingZipExportWarning = true
        }
    }

    // MARK: - Error Navigation

    /// Map a file path from a Typst error message to the actual project file name.
    /// Typst FFI internally names the entry source "main.typ" regardless of the
    /// real file name, so we map it back to the document's entry file.
    private func resolveErrorFileName(_ path: String) -> String {
        if path == "main.typ" && document.entryFileName != "main.typ" {
            return document.entryFileName
        }
        return path
    }

    /// Recompute error lines from the current compiler error message.
    /// Call whenever `compiler.errorMessage` or `currentFileName` changes.
    func recomputeCompilationErrorLines() -> Set<Int> {
        guard let message = compiler.errorMessage else { return [] }
        var result = Set<Int>()
        let lines = message.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("("), trimmed.hasSuffix(")") else { continue }
            let candidate = String(trimmed.dropFirst().dropLast())
            let parts = candidate.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count >= 3,
                  let lineNum = Int(parts[parts.count - 2]),
                  lineNum > 0 else { continue }
            let path = parts.dropLast(2).joined(separator: ":")
            guard !path.isEmpty else { continue }
            let resolved = resolveErrorFileName(path)
            if resolved == currentFileName {
                result.insert(lineNum)
            }
        }
        return result
    }

    /// Navigate the editor to a compilation error location.
    func navigateToError(file: String, line: Int, column: Int) {
        let resolvedFile = resolveErrorFileName(file)

        // Switch to editor tab on iPhone
        if sizeClass != .regular {
            selectedTab = 0
        }

        // Open the file if it's not already open
        if resolvedFile != currentFileName {
            openFile(named: resolvedFile)
        }

        // Compute UTF-16 offset from line:column
        let offset = utf16Offset(forLine: line, column: column, in: editorText)
        pendingCursorJump = offset
        InteractionFeedback.impact(.light)
    }

    func utf16Offset(forLine line: Int, column: Int, in text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        var offset = 0
        for i in 0..<min(line - 1, lines.count) {
            offset += (lines[i] as NSString).length + 1 // +1 for \n
        }
        if line - 1 < lines.count {
            offset += min(max(column - 1, 0), (lines[line - 1] as NSString).length)
        }
        return offset
    }
}
