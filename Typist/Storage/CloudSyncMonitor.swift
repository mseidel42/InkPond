//
//  CloudSyncMonitor.swift
//  Typist
//

import Foundation
import os.log

/// Tracks iCloud download/upload status for files in a project directory
/// using NSMetadataQuery.
@Observable
@MainActor
final class CloudSyncMonitor {
    private var query: NSMetadataQuery?
    private var gatheringObserver: Any?
    private var updateObserver: Any?
    private var monitoredURL: URL?

    /// Per-file sync status keyed by relative path.
    private(set) var fileStatuses: [String: FileCloudStatus] = [:]

    /// Whether the initial metadata gathering has completed.
    private(set) var isGathering: Bool = false

    enum FileCloudStatus: Equatable {
        case current
        case downloading(progress: Double)
        case uploading(progress: Double)
        case notDownloaded
        case error(String)
    }

    func startMonitoring(projectURL: URL, predicate: NSPredicate? = nil) {
        stopMonitoring()
        monitoredURL = projectURL

        let metadataQuery = NSMetadataQuery()
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = predicate ?? NSPredicate(
            format: "%K BEGINSWITH %@",
            NSMetadataItemPathKey,
            projectURL.path
        )
        // Throttle updates
        metadataQuery.notificationBatchingInterval = 0.5

        gatheringObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.processQueryResults()
                self?.isGathering = false
            }
        }

        updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.processQueryResults()
            }
        }

        isGathering = true
        metadataQuery.start()
        query = metadataQuery
    }

    func stopMonitoring() {
        query?.stop()
        query = nil
        if let obs = gatheringObserver {
            NotificationCenter.default.removeObserver(obs)
            gatheringObserver = nil
        }
        if let obs = updateObserver {
            NotificationCenter.default.removeObserver(obs)
            updateObserver = nil
        }
        fileStatuses = [:]
        isGathering = false
        monitoredURL = nil
    }

    /// Request iCloud to download a file that is not yet local.
    nonisolated func startDownloading(at url: URL) {
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            os_log(.error, "CloudSyncMonitor: failed to start download for %{public}@: %{public}@",
                   url.lastPathComponent, error.localizedDescription)
        }
    }

    /// Request download for all not-yet-downloaded files.
    func downloadAll() {
        guard let base = monitoredURL else { return }
        for (relativePath, status) in fileStatuses {
            if case .notDownloaded = status {
                let url = base.appendingPathComponent(relativePath)
                startDownloading(at: url)
            }
        }
    }

    /// Starts monitoring the entire iCloud Documents directory (all projects).
    func startMonitoringAll() {
        guard let docsURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.P0int.Typist"
        )?.appendingPathComponent("Documents", isDirectory: true) else { return }
        // Use a catch-all predicate — the scope already limits to the Documents subdirectory.
        let anyFile = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        startMonitoring(projectURL: docsURL, predicate: anyFile)
    }

    // MARK: - Summary

    /// Aggregated sync summary across all monitored files.
    var summary: SyncSummary {
        var total = 0
        var current = 0
        var downloading = 0
        var uploading = 0
        var notDownloaded = 0
        var errored = 0

        for (_, status) in fileStatuses {
            total += 1
            switch status {
            case .current: current += 1
            case .downloading: downloading += 1
            case .uploading: uploading += 1
            case .notDownloaded: notDownloaded += 1
            case .error: errored += 1
            }
        }

        return SyncSummary(
            total: total,
            current: current,
            downloading: downloading,
            uploading: uploading,
            notDownloaded: notDownloaded,
            errored: errored
        )
    }

    struct SyncSummary: Equatable {
        let total: Int
        let current: Int
        let downloading: Int
        let uploading: Int
        let notDownloaded: Int
        let errored: Int

        var isFullySynced: Bool { total > 0 && current == total }
        var hasActivity: Bool { downloading > 0 || uploading > 0 }
        var pendingCount: Int { notDownloaded + downloading + uploading }
    }

    // MARK: - Private

    private func processQueryResults() {
        guard let query, let baseURL = monitoredURL else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        let basePath = baseURL.standardizedFileURL.path
        let basePathSlash = basePath.hasSuffix("/") ? basePath : basePath + "/"
        var newStatuses: [String: FileCloudStatus] = [:]

        for item in query.results {
            guard let metadataItem = item as? NSMetadataItem else { continue }

            // Skip directories
            let contentType = metadataItem.value(forAttribute: NSMetadataItemContentTypeKey) as? String
            if contentType == "public.folder" { continue }

            // Compute relative path from the item URL or path attribute
            let relativePath: String
            if let itemURL = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL {
                let itemStd = itemURL.standardizedFileURL.path
                if itemStd.hasPrefix(basePathSlash) {
                    relativePath = String(itemStd.dropFirst(basePathSlash.count))
                } else {
                    // Fallback: use just the file name
                    relativePath = itemURL.lastPathComponent
                }
            } else if let itemPath = metadataItem.value(forAttribute: NSMetadataItemPathKey) as? String {
                if itemPath.hasPrefix(basePathSlash) {
                    relativePath = String(itemPath.dropFirst(basePathSlash.count))
                } else {
                    relativePath = (itemPath as NSString).lastPathComponent
                }
            } else {
                continue
            }

            guard !relativePath.isEmpty else { continue }

            newStatuses[relativePath] = status(for: metadataItem)
        }

        fileStatuses = newStatuses
    }

    private func status(for item: NSMetadataItem) -> FileCloudStatus {
        // Check for errors first
        if let downloadError = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) as? NSError {
            return .error(downloadError.localizedDescription)
        }
        if let uploadError = item.value(forAttribute: NSMetadataUbiquitousItemUploadingErrorKey) as? NSError {
            return .error(uploadError.localizedDescription)
        }

        // Check download status
        let downloadStatus = item.value(
            forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey
        ) as? String

        if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
            return .notDownloaded
        }

        // Check if currently downloading
        if let isDownloading = item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool,
           isDownloading {
            let progress = item.value(
                forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey
            ) as? Double ?? 0
            return .downloading(progress: progress / 100.0)
        }

        // Check if currently uploading
        if let isUploading = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool,
           isUploading {
            let progress = item.value(
                forAttribute: NSMetadataUbiquitousItemPercentUploadedKey
            ) as? Double ?? 0
            return .uploading(progress: progress / 100.0)
        }

        return .current
    }

    // Cleanup is handled by stopMonitoring() — callers must call it before releasing.
}
