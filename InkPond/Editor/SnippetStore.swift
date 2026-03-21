//
//  SnippetStore.swift
//  InkPond
//

import Foundation
import os

@Observable
final class SnippetStore {
    private(set) var userSnippets: [Snippet] = []
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "InkPond", category: "SnippetStore")

    var allSnippets: [Snippet] {
        SnippetLibrary.builtIn + userSnippets
    }

    init() {
        loadFromDisk()
    }

    // MARK: - CRUD

    func add(_ snippet: Snippet) {
        userSnippets.append(snippet)
        saveToDisk()
    }

    func update(_ snippet: Snippet) {
        guard let index = userSnippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        userSnippets[index] = snippet
        saveToDisk()
    }

    func delete(_ snippet: Snippet) {
        userSnippets.removeAll { $0.id == snippet.id }
        saveToDisk()
    }

    func delete(at offsets: IndexSet, in snippets: [Snippet]) {
        for index in offsets {
            let snippet = snippets[index]
            guard !snippet.isBuiltIn else { continue }
            userSnippets.removeAll { $0.id == snippet.id }
        }
        saveToDisk()
    }

    // MARK: - Grouped

    func snippetsGroupedByCategory(matching query: String = "") -> [(category: String, snippets: [Snippet])] {
        let filtered: [Snippet]
        if query.isEmpty {
            filtered = allSnippets
        } else {
            let lowered = query.lowercased()
            filtered = allSnippets.filter { snippet in
                snippet.title.localizedCaseInsensitiveContains(query) ||
                snippet.category.localizedCaseInsensitiveContains(query) ||
                snippet.keywords.contains { $0.localizedCaseInsensitiveContains(lowered) } ||
                snippet.body.localizedCaseInsensitiveContains(query)
            }
        }

        let grouped = Dictionary(grouping: filtered, by: \.category)
        let knownOrder = SnippetLibrary.categoryOrder
        let allCategories = Set(grouped.keys)
        let ordered = knownOrder.filter { allCategories.contains($0) }
            + allCategories.filter { !knownOrder.contains($0) }.sorted()

        return ordered.compactMap { category in
            guard let snippets = grouped[category] else { return nil }
            return (category: category, snippets: snippets)
        }
    }

    // MARK: - Persistence

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppIdentity.snippetStoreDirectoryName, isDirectory: true)
        let legacyDir = appSupport.appendingPathComponent(AppIdentity.legacySnippetStoreDirectoryName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path),
           FileManager.default.fileExists(atPath: legacyDir.path) {
            try? FileManager.default.moveItem(at: legacyDir, to: dir)
        }

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("user_snippets.json")
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(userSnippets)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to save user snippets: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        let url = Self.storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            userSnippets = try JSONDecoder().decode([Snippet].self, from: data)
        } catch {
            Self.logger.error("Failed to load user snippets: \(error.localizedDescription)")
        }
    }
}
