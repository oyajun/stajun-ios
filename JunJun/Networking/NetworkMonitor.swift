import Foundation
import Network

/// Observes network reachability so the UI can react to going offline/online.
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    /// Whether the device currently has a usable network path.
    /// Starts as `true` so the UI doesn't flash "offline" before the first update.
    private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }
}
