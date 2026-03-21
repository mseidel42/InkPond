//
//  PreviewPackageCacheStore.swift
//  InkPond
//

import Foundation

struct PreviewPackageCacheEntry: Identifiable, Equatable, Sendable {
    let namespace: String
    let name: String
    let version: String
    let sizeInBytes: Int64
    let url: URL

    var id: String { "\(namespace)/\(name)/\(version)" }
    var displayName: String { "\(namespace)/\(name)" }
}

struct PreviewPackageCacheSnapshot: Equatable, Sendable {
    let entries: [PreviewPackageCacheEntry]

    var totalSizeInBytes: Int64 {
        entries.reduce(0) { $0 + $1.sizeInBytes }
    }
}

struct PreviewPackageCacheStore: Sendable {
    let rootURL: URL?

    nonisolated init(rootURL: URL? = TypstBridge.packageCacheDirectoryURL) {
        self.rootURL = rootURL
    }

    nonisolated func snapshot() throws -> PreviewPackageCacheSnapshot {
        let fileManager = FileManager.default
        guard let rootURL else {
            return PreviewPackageCacheSnapshot(entries: [])
        }

        guard fileManager.fileExists(atPath: rootURL.path) else {
            return PreviewPackageCacheSnapshot(entries: [])
        }

        let namespaceURLs = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var entries: [PreviewPackageCacheEntry] = []

        for namespaceURL in namespaceURLs where try isDirectory(namespaceURL) {
            let packageURLs = try fileManager.contentsOfDirectory(
                at: namespaceURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for packageURL in packageURLs where try isDirectory(packageURL) {
                let versionURLs = try fileManager.contentsOfDirectory(
                    at: packageURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for versionURL in versionURLs where try isDirectory(versionURL) {
                    entries.append(
                        PreviewPackageCacheEntry(
                            namespace: namespaceURL.lastPathComponent,
                            name: packageURL.lastPathComponent,
                            version: versionURL.lastPathComponent,
                            sizeInBytes: try directorySize(at: versionURL),
                            url: versionURL
                        )
                    )
                }
            }
        }

        entries.sort {
            ($0.namespace, $0.name, $0.version) < ($1.namespace, $1.name, $1.version)
        }
        return PreviewPackageCacheSnapshot(entries: entries)
    }

    nonisolated func remove(_ entry: PreviewPackageCacheEntry) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: entry.url.path) else { return }
        try fileManager.removeItem(at: entry.url)
        try removeIfEmpty(entry.url.deletingLastPathComponent())
        try removeIfEmpty(entry.url.deletingLastPathComponent().deletingLastPathComponent())
    }

    nonisolated func clearAll() throws {
        let fileManager = FileManager.default
        guard let rootURL else { return }
        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.removeItem(at: rootURL)
        }
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private nonisolated func isDirectory(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        return values.isDirectory == true
    }

    private nonisolated func directorySize(at url: URL) throws -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { continue }
            totalSize += Int64(values.fileSize ?? 0)
        }
        return totalSize
    }

    private nonisolated func removeIfEmpty(_ url: URL) throws {
        let fileManager = FileManager.default
        guard let rootURL else { return }
        guard url.path.hasPrefix(rootURL.path), url != rootURL else { return }
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        if contents.isEmpty {
            try fileManager.removeItem(at: url)
        }
    }
}
