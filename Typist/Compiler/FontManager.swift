//
//  FontManager.swift
//  Typist
//

import Foundation
import os.log

enum FontManager {

    // MARK: - Bundled fonts

    /// Paths to bundled CJK fonts (思源黑体 + 思源宋体) used as fallbacks.
    static var bundledCJKFontPaths: [String] {
        [
            Bundle.main.path(forResource: "SourceHanSansSC-Regular", ofType: "otf"),
            Bundle.main.path(forResource: "SourceHanSerifSC-Regular", ofType: "otf"),
            Bundle.main.path(forResource: "SourceHanSansSC-Bold", ofType: "otf"),
            Bundle.main.path(forResource: "SourceHanSerifSC-Bold", ofType: "otf"),
        ].compactMap { $0 }
    }

    /// Returns the Typst-usable font family name (OTF name record #1) for a bundled font path.
    static func typstFamilyName(forBundledPath path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              data.count > 12 else { return nil }
        // Read sfnt offset table to find the 'name' table.
        let numTables = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt16.self).bigEndian }
        var nameTableOffset: Int?
        for i in 0..<Int(numTables) {
            let base = 12 + i * 16
            guard base + 16 <= data.count else { break }
            let tag = data[base..<base+4]
            if tag == Data([0x6E, 0x61, 0x6D, 0x65]) { // 'name'
                nameTableOffset = Int(data.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: base + 8, as: UInt32.self).bigEndian
                })
                break
            }
        }
        guard let nOff = nameTableOffset, nOff + 6 <= data.count else { return nil }
        let count = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: nOff + 2, as: UInt16.self).bigEndian })
        let strOff = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: nOff + 4, as: UInt16.self).bigEndian })
        for i in 0..<count {
            let rec = nOff + 6 + i * 12
            guard rec + 12 <= data.count else { break }
            let pid  = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: rec,     as: UInt16.self).bigEndian }
            let enc  = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: rec + 2, as: UInt16.self).bigEndian }
            let nid  = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: rec + 6, as: UInt16.self).bigEndian }
            let slen = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: rec + 8, as: UInt16.self).bigEndian })
            let soff = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: rec + 10, as: UInt16.self).bigEndian })
            guard pid == 3, enc == 1, nid == 1 else { continue }
            let strStart = nOff + strOff + soff
            guard strStart + slen <= data.count else { continue }
            let strData = data[strStart..<strStart+slen]
            return String(bytes: strData, encoding: .utf16BigEndian)
        }
        return nil
    }

    // MARK: - Import / Delete (per-project)

    /// Copy a font file into the project's fonts directory.
    /// Returns the destination file name on success.
    @discardableResult
    static func importFont(from sourceURL: URL, for document: TypistDocument) throws -> String {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        ProjectFileManager.ensureFontsDirectory(for: document)
        let fileName = sourceURL.lastPathComponent
        let destination = ProjectFileManager.fontsDirectory(for: document)
            .appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        os_log(.info, "FontManager: imported %{public}@ into project %{public}@", fileName, document.projectID)
        return fileName
    }

    /// Full path for a font file in a document's project, or nil if missing.
    static func fontFilePath(for fileName: String, in document: TypistDocument) -> String? {
        let path = ProjectFileManager.fontsDirectory(for: document)
            .appendingPathComponent(fileName).path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// Delete a font file from the document's project directory.
    static func deleteFont(fileName: String, from document: TypistDocument) {
        let url = ProjectFileManager.fontsDirectory(for: document)
            .appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
        os_log(.info, "FontManager: deleted %{public}@ from project %{public}@", fileName, document.projectID)
    }

    // MARK: - Resolve paths for compilation

    /// Returns all font file paths: bundled CJK fonts + document's custom fonts.
    static func allFontPaths(for document: TypistDocument) -> [String] {
        var paths: [String] = bundledCJKFontPaths
        for name in document.fontFileNames {
            if let path = fontFilePath(for: name, in: document) {
                paths.append(path)
            }
        }
        return paths
    }

}
