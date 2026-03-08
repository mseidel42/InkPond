//
//  ProjectFileManager.swift
//  Typist
//

import Foundation
import os.log

// MARK: - Error type

enum TypistFileError: LocalizedError {
    case cannotDeleteEntryFile
    case fileAlreadyExists(String)
    case fileNotFound(String)
    case invalidFileName(String)
    case unsafePath(String)

    var errorDescription: String? {
        switch self {
        case .cannotDeleteEntryFile:
            return L10n.tr("error.file.cannot_delete_entry")
        case .fileAlreadyExists(let name):
            return L10n.format("error.file.already_exists", name)
        case .fileNotFound(let name):
            return L10n.format("error.file.not_found", name)
        case .invalidFileName(let name):
            return L10n.format("error.file.invalid_name", name)
        case .unsafePath(let path):
            return L10n.format("error.file.unsafe_path", path)
        }
    }
}

// MARK: - Project file listing

struct ProjectFiles {
    var typFiles: [String]   // file names relative to project root
    var imageFiles: [String] // file names inside images/
    var fontFiles: [String]  // file names inside fonts/
}

struct ProjectTreeNode: Identifiable, Hashable {
    enum Kind: Hashable {
        case directory
        case typ
        case image
        case font
        case other
    }

    let relativePath: String
    let displayName: String
    let kind: Kind
    let children: [ProjectTreeNode]

    var id: String { relativePath }
    var isDirectory: Bool { kind == .directory }
}

struct EntryFileResolution {
    let entryFileName: String?
    let requiresInitialSelection: Bool
}

// MARK: - ProjectFileManager

enum ProjectFileManager {

    // MARK: - Directory layout

    private static var documentsURL: URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("DocumentDirectory unavailable — this should never happen in a sandboxed app")
        }
        return docs
    }

    static func projectDirectory(for document: TypistDocument) -> URL {
        documentsURL.appendingPathComponent(document.projectID, isDirectory: true)
    }

    static func projectDirectory(folderName: String) -> URL {
        documentsURL.appendingPathComponent(folderName, isDirectory: true)
    }

    // MARK: - Folder naming

    /// Convert a project title into a safe directory name.
    static func sanitizeFolderName(_ title: String) -> String {
        var name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let unsafe = CharacterSet(charactersIn: "/:\\*?\"<>|")
        name = name.components(separatedBy: unsafe).joined(separator: "-")
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if name.isEmpty { name = L10n.untitledBase }
        return String(name.prefix(200))
    }

    /// Return a folder name that doesn't already exist under Documents/.
    static func uniqueFolderName(for title: String) -> String {
        let fm = FileManager.default
        let base = sanitizeFolderName(title)
        if !fm.fileExists(atPath: documentsURL.appendingPathComponent(base).path) { return base }
        var i = 2
        while fm.fileExists(atPath: documentsURL.appendingPathComponent("\(base) \(i)").path) { i += 1 }
        return "\(base) \(i)"
    }

    // MARK: - Rename

    /// Move the project folder to a new title-derived name. Returns the new projectID.
    @discardableResult
    static func renameProjectDirectory(for document: TypistDocument, to newTitle: String) -> String {
        let newFolderName = uniqueFolderName(for: newTitle)
        let oldDir = projectDirectory(for: document)
        let newDir = documentsURL.appendingPathComponent(newFolderName, isDirectory: true)
        if FileManager.default.fileExists(atPath: oldDir.path) {
            try? FileManager.default.moveItem(at: oldDir, to: newDir)
        }
        return newFolderName
    }

    // MARK: - Filesystem sync

    /// Scan Documents/ and return folder names not yet tracked in the store.
    static func untrackedFolderNames(knownProjectIDs: Set<String>) -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents.compactMap { url -> String? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            let name = url.lastPathComponent
            return knownProjectIDs.contains(name) ? nil : name
        }.sorted()
    }

    static func trackedFolderNames() -> Set<String> {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return Set(contents.compactMap { url -> String? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return url.lastPathComponent
        })
    }

    // MARK: - Legacy migration

    /// One-time migration: moves Documents/Projects/<UUID>/ → Documents/<title>/ for each document
    /// whose projectID is still a UUID string.
    static func migrateLegacyStructure(documents: [TypistDocument]) {
        let fm = FileManager.default
        let legacyRoot = documentsURL.appendingPathComponent("Projects", isDirectory: true)
        // Quick bail-out if there is nothing from the old layout
        guard fm.fileExists(atPath: legacyRoot.path) else { return }

        for doc in documents {
            guard UUID(uuidString: doc.projectID) != nil else { continue }
            let oldDir = legacyRoot.appendingPathComponent(doc.projectID, isDirectory: true)
            let newFolderName = uniqueFolderName(for: doc.title)
            let newDir = documentsURL.appendingPathComponent(newFolderName, isDirectory: true)
            if fm.fileExists(atPath: oldDir.path) {
                try? fm.moveItem(at: oldDir, to: newDir)
            }
            doc.projectID = newFolderName
            os_log(.info, "ProjectFileManager: migrated %{public}@ → %{public}@", doc.title, newFolderName)
        }

        // Remove the now-empty Projects/ directory
        if let items = try? fm.contentsOfDirectory(atPath: legacyRoot.path), items.isEmpty {
            try? fm.removeItem(at: legacyRoot)
        }
    }

    static func imagesDirectory(for document: TypistDocument) -> URL {
        let imageDirName = safeImageDirectoryName(from: document.imageDirectoryName)
        if imageDirName.isEmpty {
            return projectDirectory(for: document)
        }
        return projectDirectory(for: document)
            .appendingPathComponent(imageDirName, isDirectory: true)
    }

    static func fontsDirectory(for document: TypistDocument) -> URL {
        projectDirectory(for: document)
            .appendingPathComponent("fonts", isDirectory: true)
    }

    // MARK: - Lifecycle

    static func ensureProjectRoot(for document: TypistDocument) {
        try? FileManager.default.createDirectory(at: projectDirectory(for: document), withIntermediateDirectories: true)
    }

    static func ensureImageDirectory(for document: TypistDocument) {
        ensureProjectRoot(for: document)
        let imageDirectory = imagesDirectory(for: document)
        if imageDirectory.standardizedFileURL != projectDirectory(for: document).standardizedFileURL {
            try? FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
    }

    static func ensureFontsDirectory(for document: TypistDocument) {
        ensureProjectRoot(for: document)
        try? FileManager.default.createDirectory(at: fontsDirectory(for: document), withIntermediateDirectories: true)
    }

    static func ensureDefaultAssetDirectories(for document: TypistDocument) {
        ensureImageDirectory(for: document)
        ensureFontsDirectory(for: document)
    }

    static func ensureProjectStructure(for document: TypistDocument) {
        ensureProjectRoot(for: document)
        ensureDefaultAssetDirectories(for: document)
    }

    static func deleteProjectDirectory(for document: TypistDocument) {
        let dir = projectDirectory(for: document)
        try? FileManager.default.removeItem(at: dir)
        os_log(.info, "ProjectFileManager: deleted project dir for %{public}@", document.projectID)
    }

    // MARK: - .typ file URLs

    static func entryFileURL(for document: TypistDocument) -> URL {
        projectDirectory(for: document).appendingPathComponent(document.entryFileName)
    }

    static func typFileURL(named name: String, for document: TypistDocument) -> URL {
        projectDirectory(for: document).appendingPathComponent(name)
    }

    // MARK: - Path validation

    /// Reject names that contain path separators or parent-directory components.
    private static func validateFileName(_ name: String) throws {
        guard !name.isEmpty,
              !name.contains("/"),
              !name.contains("\\"),
              name != "..",
              !name.hasPrefix("../"),
              !name.contains("/../") else {
            throw TypistFileError.invalidFileName(name)
        }
    }

    // MARK: - .typ file CRUD

    static func readTypFile(named name: String, for document: TypistDocument) throws -> String {
        let url = try validatedProjectPath(relativePath: name, for: document)
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func writeTypFile(named name: String, content: String, for document: TypistDocument) throws {
        let url = try validatedProjectPath(relativePath: name, for: document)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    static func createTypFile(named name: String, for document: TypistDocument) throws {
        try validateFileName(name)
        let url = try validatedProjectPath(relativePath: name, for: document)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw TypistFileError.fileAlreadyExists(name)
        }
        try "".write(to: url, atomically: true, encoding: .utf8)
        os_log(.info, "ProjectFileManager: created %{public}@ in %{public}@", name, document.projectID)
    }

    static func deleteTypFile(named name: String, for document: TypistDocument) throws {
        guard name != document.entryFileName else {
            throw TypistFileError.cannotDeleteEntryFile
        }
        let url = try validatedProjectPath(relativePath: name, for: document)
        try FileManager.default.removeItem(at: url)
        os_log(.info, "ProjectFileManager: deleted %{public}@ from %{public}@", name, document.projectID)
    }

    /// Delete any file by relative path (relative to project root).
    static func deleteProjectFile(relativePath: String, for document: TypistDocument) throws {
        let url = try validatedProjectPath(relativePath: relativePath, for: document)
        try FileManager.default.removeItem(at: url)
        os_log(.info, "ProjectFileManager: deleted %{public}@", relativePath)
    }

    /// Import an external file into a subdirectory of the project.
    /// `subdir` is relative to the project root (e.g. "images" or "fonts").
    @discardableResult
    static func importFile(from sourceURL: URL, to subdir: String, for document: TypistDocument) throws -> String {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        ensureProjectRoot(for: document)
        let destDir = try validatedProjectPath(relativePath: subdir, for: document, allowEmpty: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let fileName = sourceURL.lastPathComponent
        let dest = destDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        os_log(.info, "ProjectFileManager: imported %{public}@ into %{public}@/%{public}@", fileName, document.projectID, subdir)
        return subdir.isEmpty ? fileName : "\(subdir)/\(fileName)"
    }

    // MARK: - File listing

    static func listProjectFiles(for document: TypistDocument) -> ProjectFiles {
        let fm = FileManager.default
        let projectDir = projectDirectory(for: document)

        // .typ files in project root
        let typFiles: [String]
        if let items = try? fm.contentsOfDirectory(atPath: projectDir.path) {
            typFiles = items
                .filter { $0.hasSuffix(".typ") }
                .sorted()
        } else {
            typFiles = []
        }

        // image files in images subdir
        let imageFiles: [String]
        let imagesDir = imagesDirectory(for: document)
        if let items = try? fm.contentsOfDirectory(atPath: imagesDir.path) {
            imageFiles = items.filter { !$0.hasPrefix(".") }.sorted()
        } else {
            imageFiles = []
        }

        // font files in fonts subdir
        let fontFiles: [String]
        let fontsDir = fontsDirectory(for: document)
        if let items = try? fm.contentsOfDirectory(atPath: fontsDir.path) {
            fontFiles = items.filter { !$0.hasPrefix(".") }.sorted()
        } else {
            fontFiles = []
        }

        return ProjectFiles(typFiles: typFiles, imageFiles: imageFiles, fontFiles: fontFiles)
    }

    static func listAllTypFiles(for document: TypistDocument) -> [String] {
        listAllTypFiles(in: projectDirectory(for: document))
    }

    static func listAllTypFiles(in projectDirectory: URL) -> [String] {
        listAllFiles(in: projectDirectory)
            .filter { $0.hasSuffix(".typ") }
            .sorted()
    }

    static func listAllFiles(in projectDirectory: URL) -> [String] {
        let fm = FileManager.default
        let rootURL = projectDirectory.standardizedFileURL
        let rootComponents = rootURL.pathComponents
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [String] = []

        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            let standardizedFileURL = fileURL.standardizedFileURL
            let fileComponents = standardizedFileURL.pathComponents
            guard fileComponents.starts(with: rootComponents) else { continue }

            let relativeComponents = fileComponents.dropFirst(rootComponents.count)
            guard !relativeComponents.isEmpty else { continue }

            let relativePath = relativeComponents.joined(separator: "/")
            files.append(relativePath)
        }

        return files.sorted()
    }

    static func projectTree(for document: TypistDocument) -> [ProjectTreeNode] {
        let imageDirectoryName = safeImageDirectoryName(from: document.imageDirectoryName)
        return buildProjectTree(in: projectDirectory(for: document), relativePrefix: "", imageDirectoryName: imageDirectoryName)
    }

    static func imageDirectoryCandidates(from relativePaths: [String]) -> [String] {
        directoryCandidates(from: relativePaths)
    }

    static func fontDirectoryCandidates(from relativePaths: [String]) -> [String] {
        directoryCandidates(from: relativePaths)
    }

    static func importFontFiles(from relativeDirectory: String, for document: TypistDocument) -> [String] {
        let urls = listFiles(in: relativeDirectory, for: document, matching: ["otf", "ttf", "woff", "woff2"])
        guard !urls.isEmpty else {
            document.fontFileNames = []
            return []
        }

        ensureFontsDirectory(for: document)
        let fontsDir = fontsDirectory(for: document)

        let imported = urls.compactMap { sourceURL -> String? in
            let fileName = sourceURL.lastPathComponent
            let destination = fontsDir.appendingPathComponent(fileName)
            if sourceURL.standardizedFileURL != destination.standardizedFileURL {
                try? FileManager.default.removeItem(at: destination)
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                } catch {
                    return nil
                }
            }
            return fileName
        }

        let uniqueNames = Array(Set(imported)).sorted()
        document.fontFileNames = uniqueNames
        return uniqueNames
    }

    static func resolveImportedEntryFile(from typFiles: [String]) -> EntryFileResolution {
        let sortedFiles = typFiles.sorted()
        if let mainFile = sortedFiles.first(where: { ($0 as NSString).lastPathComponent == "main.typ" }) {
            return EntryFileResolution(entryFileName: mainFile, requiresInitialSelection: false)
        }
        if let firstTypFile = sortedFiles.first {
            return EntryFileResolution(entryFileName: firstTypFile, requiresInitialSelection: true)
        }
        return EntryFileResolution(entryFileName: nil, requiresInitialSelection: false)
    }

    private static func buildProjectTree(
        in directory: URL,
        relativePrefix: String,
        imageDirectoryName: String
    ) -> [ProjectTreeNode] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let nodes = contents.compactMap { url -> ProjectTreeNode? in
            let name = url.lastPathComponent
            let relativePath = relativePrefix.isEmpty ? name : "\(relativePrefix)/\(name)"
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])

            if values?.isDirectory == true {
                return ProjectTreeNode(
                    relativePath: relativePath,
                    displayName: name,
                    kind: .directory,
                    children: buildProjectTree(
                        in: url,
                        relativePrefix: relativePath,
                        imageDirectoryName: imageDirectoryName
                    )
                )
            }

            return ProjectTreeNode(
                relativePath: relativePath,
                displayName: name,
                kind: fileKind(for: relativePath, imageDirectoryName: imageDirectoryName),
                children: []
            )
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private static func fileKind(for relativePath: String, imageDirectoryName: String) -> ProjectTreeNode.Kind {
        let ext = (relativePath as NSString).pathExtension.lowercased()
        if ext == "typ" { return .typ }
        if relativePath.hasPrefix("fonts/") { return .font }
        if !imageDirectoryName.isEmpty, relativePath.hasPrefix(imageDirectoryName + "/") { return .image }
        switch ext {
        case "jpg", "jpeg", "png", "gif", "svg", "webp":
            return .image
        case "otf", "ttf", "woff", "woff2":
            return .font
        default:
            return .other
        }
    }

    // MARK: - Content migration

    /// One-time migration: write document.content → entry file on disk.
    /// Does nothing if entry file already exists with non-empty content, or if document.content is empty.
    static func migrateContentIfNeeded(for document: TypistDocument) {
        guard !document.requiresInitialEntrySelection else { return }

        let entryURL = entryFileURL(for: document)
        let fm = FileManager.default

        if fm.fileExists(atPath: entryURL.path) {
            // Entry file already exists — don't overwrite user's work
            return
        }

        // Write content from SwiftData field to disk
        let source = document.content
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        try? source.write(to: entryURL, atomically: true, encoding: .utf8)
        os_log(.info, "ProjectFileManager: migrated content to %{public}@ for %{public}@",
               document.entryFileName, document.projectID)
    }

    /// Normalize and validate a relative path before resolving it under project root.
    private static func validatedProjectPath(relativePath: String,
                                             for document: TypistDocument,
                                             allowEmpty: Bool = false) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if allowEmpty { return projectDirectory(for: document) }
            throw TypistFileError.invalidFileName(relativePath)
        }
        guard !trimmed.hasPrefix("/"),
              !trimmed.contains("\\"),
              !trimmed.hasPrefix("~") else {
            throw TypistFileError.unsafePath(relativePath)
        }

        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else { throw TypistFileError.unsafePath(relativePath) }
        for component in components {
            if component.isEmpty || component == "." || component == ".." {
                throw TypistFileError.unsafePath(relativePath)
            }
        }

        let normalized = components.map(String.init).joined(separator: "/")
        let root = projectDirectory(for: document).standardizedFileURL
        let target = root.appendingPathComponent(normalized, isDirectory: false).standardizedFileURL
        let rootPath = root.path
        let targetPath = target.path
        guard targetPath == rootPath || targetPath.hasPrefix(rootPath + "/") else {
            throw TypistFileError.unsafePath(relativePath)
        }
        return target
    }

    /// Keep image subdirectory as one safe path component to avoid path traversal.
    private static func safeImageDirectoryName(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        guard !trimmed.contains("/"),
              !trimmed.contains("\\"),
              trimmed != ".",
              trimmed != ".." else {
            return "images"
        }
        return String(trimmed.prefix(80))
    }

    // MARK: - Image management

    /// Save image data to the project images directory.
    /// Returns the relative path for use in Typst source (e.g. "images/img-A1B2C3D4.jpg").
    @discardableResult
    static func saveImage(data: Data, fileName: String, for document: TypistDocument) throws -> String {
        ensureImageDirectory(for: document)
        let imageDir = safeImageDirectoryName(from: document.imageDirectoryName)
        let dest = imagesDirectory(for: document).appendingPathComponent(fileName)
        try data.write(to: dest)
        os_log(.info, "ProjectFileManager: saved image %{public}@", fileName)
        return imageDir.isEmpty ? fileName : "\(imageDir)/\(fileName)"
    }

    private static func directoryCandidates(from relativePaths: [String]) -> [String] {
        var directories: Set<String> = [""]

        for path in relativePaths {
            let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }

            let components = normalized.split(separator: "/").map(String.init)
            guard components.count > 1 else {
                directories.insert("")
                continue
            }

            for depth in 1..<(components.count) {
                let directory = components.prefix(depth).joined(separator: "/")
                directories.insert(directory)
            }
        }

        return directories.sorted {
            let lhsIsRoot = $0.isEmpty
            let rhsIsRoot = $1.isEmpty
            if lhsIsRoot != rhsIsRoot {
                return lhsIsRoot
            }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private static func listFiles(in relativeDirectory: String, for document: TypistDocument, matching extensions: Set<String>) -> [URL] {
        let directoryURL = (try? validatedProjectPath(relativePath: relativeDirectory, for: document, allowEmpty: true))
            ?? projectDirectory(for: document)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return extensions.contains(ext)
        }.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }
}
