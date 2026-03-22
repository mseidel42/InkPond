import Foundation
import os

enum BookmarkManager {
    private static let bookmarksDirectory = ProjectFileManager.documentsURL.appendingPathComponent(".bookmarks", isDirectory: true)
    private static let _lock = OSAllocatedUnfairLock<[String: URL]>(initialState: [:])

    static func hasBookmark(projectID: String) -> Bool {
        if _lock.withLock({ $0[projectID] }) != nil { return true }
        let fileURL = bookmarksDirectory.appendingPathComponent("\(projectID).bookmark")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func saveBookmark(for url: URL, projectID: String) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: bookmarksDirectory.path) {
            try fm.createDirectory(at: bookmarksDirectory, withIntermediateDirectories: true)
        }

        let bookmarkData = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let fileURL = bookmarksDirectory.appendingPathComponent("\(projectID).bookmark")
        try bookmarkData.write(to: fileURL)
    }

    static func loadBookmark(projectID: String) -> URL? {
        if let url = _lock.withLock({ $0[projectID] }) { return url }

        let fileURL = bookmarksDirectory.appendingPathComponent("\(projectID).bookmark")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        var isStale = false
        guard let resolvedURL = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else { return nil }

        if resolvedURL.startAccessingSecurityScopedResource() {
            _lock.withLock { $0[projectID] = resolvedURL }
            return resolvedURL
        }
        return nil
    }

    static func removeBookmark(projectID: String) {
        if let url = _lock.withLock({ $0[projectID] }) {
            url.stopAccessingSecurityScopedResource()
            _lock.withLock { $0.removeValue(forKey: projectID) }
        }
        let fileURL = bookmarksDirectory.appendingPathComponent("\(projectID).bookmark")
        try? FileManager.default.removeItem(at: fileURL)
    }
}
