//
//  ExportManager.swift
//  Typist
//

import Foundation
import UIKit

enum ExportManager {

    /// Compile document to PDF data on a background thread.
    /// Reads source from the entry file on disk.
    static func compilePDF(for document: TypistDocument) async -> Result<Data, TypstBridgeError> {
        let source = (try? ProjectFileManager.readTypFile(named: document.entryFileName, for: document)) ?? document.content
        let fontPaths = FontManager.allFontPaths(for: document)
        let rootDir = ProjectFileManager.projectDirectory(for: document).path

        return await Task.detached {
            TypstBridge.compile(source: source, fontPaths: fontPaths, rootDir: rootDir)
        }.value
    }

    /// Write PDF data to a temporary file and return its URL.
    static func temporaryPDFURL(data: Data, title: String) throws -> URL {
        let sanitized = title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitized).pdf")
        try data.write(to: url)
        return url
    }

    /// Write .typ source to a temporary file and return its URL.
    /// Uses `fileName` as the exported file name (e.g. "main.typ").
    static func temporaryTypURL(for document: TypistDocument, fileName: String) throws -> URL {
        let sanitized = fileName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitized)
        let source = (try? ProjectFileManager.readTypFile(named: fileName, for: document)) ?? document.content
        try source.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Zip the entire project directory and return a temporary URL.
    /// The zip file is named after the document title.
    static func zipProject(for document: TypistDocument) throws -> URL {
        let projectDir = ProjectFileManager.projectDirectory(for: document)
        let sanitized = document.title.replacingOccurrences(of: "/", with: "-")
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitized).zip")

        // Remove any previous export at this path
        try? FileManager.default.removeItem(at: zipURL)

        // Use NSFileCoordinatorWritingForMerging to create a zip via a Process is unavailable on iOS.
        // Instead, use the built-in ZIP support via FileManager on iOS 16+ / coordinated copy.
        // We rely on the ZipFoundation-free approach: iterate files and write a zip manually,
        // or use the NSFileCoordinatorWritingOptions compress workaround.
        // The simplest supported approach on iOS is to use a URLSession background download trick,
        // but the most reliable approach is to use the system archiver via Process — unavailable on iOS.
        // We use a pure-Swift streaming zip writer below.
        try writeZip(sourceDir: projectDir, destinationURL: zipURL)
        return zipURL
    }

    // MARK: - Minimal ZIP writer (stored + deflated via zlib)

    private static func writeZip(sourceDir: URL, destinationURL: URL) throws {
        var entries: [(relativePath: String, url: URL)] = []
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: sourceDir, includingPropertiesForKeys: [.isDirectoryKey],
                                          options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir { continue }
                let relative = String(fileURL.path.dropFirst(sourceDir.path.count + 1))
                entries.append((relativePath: relative, url: fileURL))
            }
        }

        var zipData = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        for entry in entries {
            guard let fileData = try? Data(contentsOf: entry.url) else { continue }
            let localHeaderOffset = UInt32(zipData.count)
            offsets.append(localHeaderOffset)

            let nameData = Data(entry.relativePath.utf8)
            let crc = crc32(fileData)
            let compressed = zlibDeflate(fileData)
            let useCompression = compressed.count < fileData.count
            let storedData = useCompression ? compressed : fileData
            let method: UInt16 = useCompression ? 8 : 0

            // Local file header
            var local = Data()
            local += uint32LE(0x04034b50)           // signature
            local += uint16LE(20)                   // version needed
            local += uint16LE(0)                    // flags
            local += uint16LE(method)               // compression
            local += uint16LE(0)                    // mod time
            local += uint16LE(0)                    // mod date
            local += uint32LE(crc)                  // crc-32
            local += uint32LE(UInt32(storedData.count))   // compressed size
            local += uint32LE(UInt32(fileData.count))     // uncompressed size
            local += uint16LE(UInt16(nameData.count))     // file name length
            local += uint16LE(0)                    // extra field length
            local += nameData
            local += storedData
            zipData += local

            // Central directory entry
            var central = Data()
            central += uint32LE(0x02014b50)         // signature
            central += uint16LE(20)                 // version made by
            central += uint16LE(20)                 // version needed
            central += uint16LE(0)                  // flags
            central += uint16LE(method)
            central += uint16LE(0)                  // mod time
            central += uint16LE(0)                  // mod date
            central += uint32LE(crc)
            central += uint32LE(UInt32(storedData.count))
            central += uint32LE(UInt32(fileData.count))
            central += uint16LE(UInt16(nameData.count))
            central += uint16LE(0)                  // extra field length
            central += uint16LE(0)                  // comment length
            central += uint16LE(0)                  // disk number start
            central += uint16LE(0)                  // internal attrs
            central += uint32LE(0)                  // external attrs
            central += uint32LE(localHeaderOffset)
            central += nameData
            centralDirectory += central
        }

        let centralOffset = UInt32(zipData.count)
        zipData += centralDirectory

        // End of central directory record
        var eocd = Data()
        eocd += uint32LE(0x06054b50)
        eocd += uint16LE(0)                         // disk number
        eocd += uint16LE(0)                         // disk with central dir
        eocd += uint16LE(UInt16(entries.count))
        eocd += uint16LE(UInt16(entries.count))
        eocd += uint32LE(UInt32(centralDirectory.count))
        eocd += uint32LE(centralOffset)
        eocd += uint16LE(0)                         // comment length
        zipData += eocd

        try zipData.write(to: destinationURL)
    }

    private static func uint16LE(_ v: UInt16) -> Data {
        var x = v.littleEndian; return Data(bytes: &x, count: 2)
    }
    private static func uint32LE(_ v: UInt32) -> Data {
        var x = v.littleEndian; return Data(bytes: &x, count: 4)
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 == 1 { crc = (crc >> 1) ^ 0xEDB88320 }
                else { crc >>= 1 }
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    private static func zlibDeflate(_ data: Data) -> Data {
        // NSData.CompressionAlgorithm.zlib on Apple platforms produces raw DEFLATE
        // (equivalent to deflateInit2 with windowBits=-15), which is what ZIP entries require.
        guard let compressed = try? (data as NSData).compressed(using: .zlib) as Data else { return data }
        return compressed
    }

    /// Present the system print dialog for PDF data.
    static func printPDF(data: Data, jobName: String) {
        let controller = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = jobName
        printInfo.outputType = .general
        controller.printInfo = printInfo
        controller.printingItem = data
        controller.present(animated: true)
    }
}
