import SwiftUI
import Network

// MARK: - Network Monitor

/// Observes network connectivity using NWPathMonitor and publishes
/// the current status as an @Observable property for SwiftUI views.
@Observable
@MainActor
final class NetworkMonitor {

    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - State

    var isConnected: Bool = true

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.scaleup.networkMonitor")

    // MARK: - Init

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Offline Banner View

/// A small yellow warning banner that slides in from the top when the
/// device loses internet connectivity.
struct OfflineBanner: View {
    @State private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.backgroundDark)

                Text("No internet connection")
                    .font(Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(ColorTokens.backgroundDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs + 2)
            .background(ColorTokens.warning)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - View Modifier

/// Attaches an offline banner at the top of the modified view.
/// The banner automatically appears/disappears based on network status.
struct OfflineBannerModifier: ViewModifier {
    func body(content: Self.Content) -> some View {
        VStack(spacing: 0) {
            OfflineBanner()
                .animation(Animations.standard, value: NetworkMonitor.shared.isConnected)

            content
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds an offline banner that slides in at the top when the device
    /// has no internet connection.
    func offlineBanner() -> some View {
        modifier(OfflineBannerModifier())
    }
}
