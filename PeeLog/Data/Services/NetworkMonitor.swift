//
//  NetworkMonitor.swift
//  PeeLog
//
//  Simple reachability using NWPathMonitor to detect offline mode.
//

import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published private(set) var isOnline: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var started = false
    
    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let newValue = (path.status == .satisfied)
            Task { @MainActor in
                guard let self else { return }
                // Avoid publishing duplicate values (NWPathMonitor can emit updates even when status doesn't change).
                // Duplicate publishes can cause downstream views to refresh/fetch repeatedly.
                if self.isOnline != newValue {
                    self.isOnline = newValue
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func stop() {
        monitor.cancel()
        started = false
    }
}


