//
//  DocumentListView+Actions.swift
//  Typist
//

import SwiftUI
import SwiftData

extension DocumentListView {
    func areDocumentsOrdered(_ lhs: TypistDocument, _ rhs: TypistDocument) -> Bool {
        let primaryComparison = compare(lhs, rhs, by: sortField)
        if primaryComparison != .orderedSame {
            return sortDirection.orders(primaryComparison)
        }

        let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }

        let modifiedComparison = lhs.modifiedAt.compare(rhs.modifiedAt)
        if modifiedComparison != .orderedSame {
            return modifiedComparison == .orderedDescending
        }

        return lhs.createdAt > rhs.createdAt
    }

    func compare(_ lhs: TypistDocument, _ rhs: TypistDocument, by field: SortField) -> ComparisonResult {
        switch field {
        case .title:
            lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        case .modifiedAt:
            lhs.modifiedAt.compare(rhs.modifiedAt)
        case .createdAt:
            lhs.createdAt.compare(rhs.createdAt)
        }
    }

    func scheduleFilesystemSync(delay: Duration = .milliseconds(300)) {
        syncTask?.cancel()
        syncTask = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                syncWithFilesystem()
            }
        }
    }

    func syncWithFilesystem() {
        let existingFolders = ProjectFileManager.trackedFolderNames()

        for document in documents where !existingFolders.contains(document.projectID) {
            if selectedDocument == document {
                selectedDocument = nil
            }
            modelContext.delete(document)
        }

        let knownIDs = Set(documents.map { $0.projectID })
        let newFolders = ProjectFileManager.untrackedFolderNames(knownProjectIDs: knownIDs)
        for folderName in newFolders {
            let folderURL = ProjectFileManager.projectDirectory(folderName: folderName)
            let allFiles = ProjectFileManager.listAllFiles(in: folderURL)
            let doc = TypistDocument(title: folderName, content: "")
            doc.projectID = folderName
            configureImportedDocument(doc, relativePaths: allFiles)
            modelContext.insert(doc)
        }
    }

    func configureImportedDocument(_ document: TypistDocument, relativePaths: [String]) {
        let typFiles = relativePaths.filter { $0.hasSuffix(".typ") }.sorted()
        let resolution = ProjectFileManager.resolveImportedEntryFile(from: typFiles)
        if let entryFile = resolution.entryFileName {
            document.entryFileName = entryFile
        }
        document.requiresInitialEntrySelection = resolution.requiresInitialSelection
        document.importEntryFileOptions = resolution.requiresInitialSelection ? typFiles : []

        let imageDirectoryOptions = ProjectFileManager.imageDirectoryCandidates(from: relativePaths)
        if ProjectFileManager.requiresImportDirectorySelection(imageDirectoryOptions) {
            document.importImageDirectoryOptions = imageDirectoryOptions
        } else {
            document.importImageDirectoryOptions = []
            if let autoImageDirectory = ProjectFileManager.defaultImportDirectory(from: imageDirectoryOptions) {
                document.imageDirectoryName = autoImageDirectory
            }
        }

        let fontDirectoryOptions = ProjectFileManager.fontDirectoryCandidates(from: relativePaths)
        if ProjectFileManager.requiresImportDirectorySelection(fontDirectoryOptions) {
            document.importFontDirectoryOptions = fontDirectoryOptions
        } else {
            document.importFontDirectoryOptions = []
            if let autoFontDirectory = ProjectFileManager.defaultImportDirectory(from: fontDirectoryOptions) {
                _ = ProjectFileManager.importFontFiles(from: autoFontDirectory, for: document)
            }
        }

        document.requiresImportConfiguration = document.requiresInitialEntrySelection
            || !document.importImageDirectoryOptions.isEmpty
            || !document.importFontDirectoryOptions.isEmpty
    }

    func nextAvailableTitle() -> String {
        let titles = Set(documents.map { $0.title })
        let base = L10n.untitledBase
        if !titles.contains(base) { return base }
        var i = 1
        while titles.contains(L10n.untitled(number: i)) { i += 1 }
        return L10n.untitled(number: i)
    }

    func addDocument() {
        let title = nextAvailableTitle()
        let doc = TypistDocument(title: title, content: "")
        doc.projectID = ProjectFileManager.uniqueFolderName(for: title)
        do {
            try ProjectFileManager.createInitialProject(for: doc)
            modelContext.insert(doc)
        } catch {
            try? ProjectFileManager.deleteProjectDirectory(for: doc)
            projectActionError = error.localizedDescription
            return
        }
        selectedDocument = doc
        InteractionFeedback.notify(.success)
        AccessibilitySupport.announce(L10n.a11yDocumentCreated(title))
    }

    func importZip(from url: URL) {
        let title = url.deletingPathExtension().lastPathComponent
        let doc = TypistDocument(title: title, content: "")
        doc.projectID = ProjectFileManager.uniqueFolderName(for: title)
        let destDir = ProjectFileManager.projectDirectory(for: doc)

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            try ProjectFileManager.createProjectRoot(for: doc)
            let extracted = try ZipImporter.extract(from: url, to: destDir)
            configureImportedDocument(doc, relativePaths: extracted)
            modelContext.insert(doc)
            selectedDocument = doc
            InteractionFeedback.notify(.success)
            AccessibilitySupport.announce(L10n.a11yDocumentImported(title))
        } catch {
            try? ProjectFileManager.deleteProjectDirectory(for: doc)
            zipImportError = error.localizedDescription
        }
    }
}
