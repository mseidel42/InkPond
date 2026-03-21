//
//  ExposedAuxiliaryDirectory.swift
//  InkPond
//

import Foundation

enum ExposedAuxiliaryDirectory {
    nonisolated static var localDocumentsURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    nonisolated static var applicationSupportURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    nonisolated static func directory(named name: String, under rootURL: URL?) -> URL? {
        rootURL?.appendingPathComponent(name, isDirectory: true)
    }

    nonisolated static func ensureDirectoryExists(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    nonisolated static func migrateLegacyDirectoryIfNeeded(
        named name: String,
        from legacyRootURL: URL?,
        to currentRootURL: URL?
    ) {
        guard let legacyDirectory = directory(named: name, under: legacyRootURL),
              let currentDirectory = directory(named: name, under: currentRootURL) else {
            return
        }

        let fileManager = FileManager.default
        guard legacyDirectory.standardizedFileURL != currentDirectory.standardizedFileURL else { return }
        guard fileManager.fileExists(atPath: legacyDirectory.path) else { return }

        ensureDirectoryExists(at: currentDirectory.deletingLastPathComponent())

        if !fileManager.fileExists(atPath: currentDirectory.path) {
            try? fileManager.moveItem(at: legacyDirectory, to: currentDirectory)
            return
        }

        guard let items = try? fileManager.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for item in items {
            let destination = currentDirectory.appendingPathComponent(item.lastPathComponent)
            guard !fileManager.fileExists(atPath: destination.path) else { continue }
            try? fileManager.moveItem(at: item, to: destination)
        }

        if let remainingItems = try? fileManager.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ), remainingItems.isEmpty {
            try? fileManager.removeItem(at: legacyDirectory)
        }
    }
}
