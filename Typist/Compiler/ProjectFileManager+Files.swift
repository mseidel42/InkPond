//
//  ProjectFileManager+Files.swift
//  Typist
//

import Foundation
import os.log

extension ProjectFileManager {
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

    static func deleteProjectFile(relativePath: String, for document: TypistDocument) throws {
        let url = try validatedProjectPath(relativePath: relativePath, for: document)
        try FileManager.default.removeItem(at: url)
        os_log(.info, "ProjectFileManager: deleted %{public}@", relativePath)
    }

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
}
