import Foundation
import Network
import os

// MARK: - Network Monitor Service

/// An enhanced network connectivity observer that builds on top of
/// `NWPathMonitor` to provide connection type, cost awareness,
/// and lifecycle callbacks.
///
/// Unlike the simpler `NetworkMonitor` in `OfflineBanner`, this
/// service exposes granular connection metadata and optional
/// `onConnectionRestored` / `onConnectionLost` hooks for
/// triggering sync or offline-mode transitions.
@Observable
@MainActor
final class NetworkMonitorService {

    // MARK: - Connection Type

    enum ConnectionType: String, CaseIterable {
        case wifi
        case cellular
        case wired
        case unknown
    }

    // MARK: - Observable State

    /// Whether the device currently has a network path with satisfied status.
    var isConnected: Bool = true

    /// The active connection technology.
    var connectionType: ConnectionType = .unknown

    /// `true` when the path uses a cellular or personal-hotspot interface.
    var isExpensive: Bool = false

    /// `true` when the user has Low Data Mode enabled.
    var isConstrained: Bool = false

    // MARK: - Callbacks

    /// Called on the main actor when connectivity is restored after being lost.
    var onConnectionRestored: (() -> Void)?

    /// Called on the main actor when connectivity is lost.
    var onConnectionLost: (() -> Void)?

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.scaleup.networkMonitorService", qos: .utility)
    private let logger = Logger(subsystem: "com.scaleup.app", category: "Network")

    /// Track previous connectivity to fire transition callbacks.
    private var wasConnected: Bool = true

    // MARK: - Lifecycle

    /// Begin observing network path changes. Call once at app launch.
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
        logger.info("Network monitor service started")
    }

    /// Stop observing. Called automatically on deallocation.
    func stop() {
        monitor.cancel()
        logger.info("Network monitor service stopped")
    }

    // MARK: - Path Handling

    private func handlePathUpdate(_ path: NWPath) {
        let nowConnected = path.status == .satisfied

        isConnected = nowConnected
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        connectionType = resolveConnectionType(path)

        logger.debug(
            "Network: connected=\(nowConnected) type=\(self.connectionType.rawValue) expensive=\(path.isExpensive) constrained=\(path.isConstrained)"
        )

        // Fire transition callbacks
        if nowConnected && !wasConnected {
            logger.info("Connection restored")
            onConnectionRestored?()
        } else if !nowConnected && wasConnected {
            logger.info("Connection lost")
            onConnectionLost?()
        }

        wasConnected = nowConnected
    }

    /// Map `NWPath` interface types to the local `ConnectionType` enum.
    private func resolveConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else {
            return .unknown
        }
    }

    // MARK: - Deinit

    deinit {
        monitor.cancel()
    }
}
