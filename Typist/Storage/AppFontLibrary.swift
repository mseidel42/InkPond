//
//  AppFontLibrary.swift
//  Typist
//

import Foundation
import Observation

struct AppFontItem: Identifiable, Equatable, Sendable {
    let displayName: String
    let path: String
    let fileName: String?
    let isBuiltIn: Bool

    var id: String { path }
}

struct AppFontGroup: Identifiable, Sendable {
    let familyName: String
    let isBuiltIn: Bool
    let fileNames: [String]
    let count: Int

    var id: String { familyName }
}

@Observable
final class AppFontLibrary {
    private let rootURL: URL?

    private(set) var items: [AppFontItem] = []

    init(rootURL: URL? = nil) {
        self.rootURL = rootURL
        reload()
    }

    var fileNames: [String] {
        items.compactMap { item in
            guard !item.isBuiltIn else { return nil }
            return item.fileName
        }
    }

    var fontPaths: [String] {
        items.map(\.path)
    }

    /// "Empty" intentionally refers to imported App fonts only.
    var isEmpty: Bool {
        fileNames.isEmpty
    }

    var groupedItems: [AppFontGroup] {
        var dict: [String: (isBuiltIn: Bool, fileNames: [String])] = [:]
        for item in items {
            let key = item.displayName
            if var existing = dict[key] {
                if let fn = item.fileName { existing.fileNames.append(fn) }
                dict[key] = existing
            } else {
                let fns: [String] = item.fileName.map { [$0] } ?? []
                dict[key] = (isBuiltIn: item.isBuiltIn, fileNames: fns)
            }
        }
        return dict.map { key, value in
            AppFontGroup(familyName: key, isBuiltIn: value.isBuiltIn, fileNames: value.fileNames, count: max(1, value.fileNames.count))
        }.sorted { $0.familyName.localizedCaseInsensitiveCompare($1.familyName) == .orderedAscending }
    }

    func reload() {
        items = FontManager.appFontItems(rootURL: rootURL)
    }

    func importFonts(from urls: [URL]) throws {
        var firstError: Error?

        for url in urls {
            do {
                _ = try FontManager.importAppFont(from: url, rootURL: rootURL)
            } catch {
                firstError = firstError ?? error
            }
        }

        reload()

        if let firstError {
            throw firstError
        }
    }

    func delete(fileName: String) {
        FontManager.deleteAppFont(fileName: fileName, rootURL: rootURL)
        reload()
    }
}
