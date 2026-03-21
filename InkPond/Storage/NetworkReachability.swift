//
//  NetworkReachability.swift
//  InkPond
//

import Foundation
import Network
import os.log

/// Lightweight wrapper around NWPathMonitor for checking network availability
/// before iCloud operations.
@Observable
final class NetworkReachability {
    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.inkpond.network-reachability")

    private(set) var isConnected: Bool = true
    private(set) var isExpensive: Bool = false
    private(set) var isConstrained: Bool = false

    /// Human-readable description of the current network state.
    var statusDescription: String {
        if !isConnected {
            return L10n.tr("network.status.disconnected")
        }
        if isConstrained {
            return L10n.tr("network.status.constrained")
        }
        if isExpensive {
            return L10n.tr("network.status.expensive")
        }
        return L10n.tr("network.status.connected")
    }

    func start() {
        guard monitor == nil else { return }
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained
            }
        }
        pathMonitor.start(queue: monitorQueue)
        monitor = pathMonitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }

    /// Synchronous snapshot of whether the network is reachable.
    /// Safe to call from any actor context.
    nonisolated static func currentlyReachable() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        let box = OSAllocatedUnfairLock(initialState: false)
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            box.withLock { $0 = path.status == .satisfied }
            semaphore.signal()
        }
        let queue = DispatchQueue(label: "com.inkpond.reachability-check")
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 3)
        monitor.cancel()
        return box.withLock { $0 }
    }
}
