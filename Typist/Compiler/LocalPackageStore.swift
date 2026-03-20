//
//  LocalPackageStore.swift
//  Typist
//

import Foundation

struct LocalPackageEntry: Identifiable, Equatable, Sendable {
    let namespace: String
    let name: String
    let version: String
    let sizeInBytes: Int64
    let url: URL

    var id: String { "\(namespace)/\(name)/\(version)" }
    var displayName: String { "@\(namespace)/\(name)" }
    var spec: String { "@\(namespace)/\(name):\(version)" }
}

struct LocalPackageSnapshot: Equatable, Sendable {
    let entries: [LocalPackageEntry]

    var totalSizeInBytes: Int64 {
        entries.reduce(0) { $0 + $1.sizeInBytes }
    }
}

struct LocalPackageStore: Sendable {
    let rootURL: URL?

    nonisolated init(rootURL: URL? = TypstBridge.localPackagesDirectoryURL) {
        self.rootURL = rootURL
    }

    nonisolated func snapshot() throws -> LocalPackageSnapshot {
        let fileManager = FileManager.default
        guard let rootURL else {
            return LocalPackageSnapshot(entries: [])
        }

        guard fileManager.fileExists(atPath: rootURL.path) else {
            return LocalPackageSnapshot(entries: [])
        }

        let namespaceURLs = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var entries: [LocalPackageEntry] = []

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
                    // Only list directories that contain a typst.toml
                    let manifest = versionURL.appendingPathComponent("typst.toml")
                    guard fileManager.fileExists(atPath: manifest.path) else { continue }

                    entries.append(
                        LocalPackageEntry(
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
        return LocalPackageSnapshot(entries: entries)
    }

    /// Import a folder as a local package. The folder must contain a `typst.toml`
    /// with `[package]` metadata (name, version). Returns the imported entry spec.
    nonisolated func importFolder(at sourceURL: URL) throws -> String {
        let fileManager = FileManager.default
        guard let rootURL else {
            throw LocalPackageError.storageUnavailable
        }

        let securedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if securedAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let manifestURL = sourceURL.appendingPathComponent("typst.toml")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw LocalPackageError.missingManifest
        }

        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
        let (name, version, namespace) = try parseManifest(manifest)

        let destDir = rootURL
            .appendingPathComponent(namespace, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)

        if fileManager.fileExists(atPath: destDir.path) {
            try fileManager.removeItem(at: destDir)
        }
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)

        let contents = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for item in contents {
            let dest = destDir.appendingPathComponent(item.lastPathComponent)
            try fileManager.copyItem(at: item, to: dest)
        }

        return "@\(namespace)/\(name):\(version)"
    }

    nonisolated func remove(_ entry: LocalPackageEntry) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: entry.url.path) else { return }
        try fileManager.removeItem(at: entry.url)
        // Clean up empty parent directories
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

    // MARK: - Private

    private nonisolated func parseManifest(_ content: String) throws -> (name: String, version: String, namespace: String) {
        // Minimal TOML parsing for [package] section
        var name: String?
        var version: String?
        var namespace: String = "local"
        var inPackageSection = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[package]" {
                inPackageSection = true
                continue
            }
            if trimmed.hasPrefix("[") {
                inPackageSection = false
                continue
            }
            guard inPackageSection else { continue }

            if let value = extractTomlValue(from: trimmed, key: "name") {
                name = value
            } else if let value = extractTomlValue(from: trimmed, key: "version") {
                version = value
            } else if let value = extractTomlValue(from: trimmed, key: "namespace") {
                namespace = value
            }
        }

        guard let pkgName = name, !pkgName.isEmpty else {
            throw LocalPackageError.invalidManifest("missing package name")
        }
        guard let pkgVersion = version, !pkgVersion.isEmpty else {
            throw LocalPackageError.invalidManifest("missing package version")
        }

        return (pkgName, pkgVersion, namespace)
    }

    private nonisolated func extractTomlValue(from line: String, key: String) -> String? {
        let pattern = key + "\\s*=\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
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
        ) else { return 0 }

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

enum LocalPackageError: Error, LocalizedError {
    case storageUnavailable
    case missingManifest
    case invalidManifest(String)

    var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return L10n.tr("error.local_package.storage_unavailable")
        case .missingManifest:
            return L10n.tr("error.local_package.missing_manifest")
        case .invalidManifest(let detail):
            return L10n.format("error.local_package.invalid_manifest", detail)
        }
    }
}
