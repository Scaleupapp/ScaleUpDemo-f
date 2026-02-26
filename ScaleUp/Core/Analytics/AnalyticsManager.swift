import Foundation
import os

// MARK: - Analytics Manager

/// Dispatches `AnalyticsEvent` instances to configured analytics
/// backends. Currently logs events in DEBUG builds; designed for
/// drop-in Firebase Analytics / Mixpanel integration.
///
/// Inject via the SwiftUI environment or `DependencyContainer`.
/// Disable at runtime by setting `isEnabled = false` or at
/// compile time via `AppConfig.isAnalyticsEnabled`.
@Observable
@MainActor
final class AnalyticsManager {

    // MARK: - Properties

    /// Master switch — when `false`, all `track` calls are no-ops.
    private var isEnabled: Bool

    /// Currently identified user, if any.
    private(set) var userId: String?

    /// Custom user properties sent alongside events.
    private(set) var userProperties: [String: String] = [:]

    /// Logger for debug output.
    private let logger = Logger(subsystem: "com.scaleup.app", category: "Analytics")

    // MARK: - Init

    init(isEnabled: Bool = AppConfig.isAnalyticsEnabled) {
        self.isEnabled = isEnabled
    }

    // MARK: - Event Tracking

    /// Record an analytics event. No-op when analytics is disabled.
    func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }

        #if DEBUG
        let params = event.parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        logger.info("Analytics: \(event.name) [\(params)]")
        #endif

        // Future: Firebase.Analytics.logEvent(event.name, parameters: event.parameters)
        // Future: Mixpanel.getInstance()?.track(event: event.name, properties: event.parameters)
    }

    // MARK: - User Identity

    /// Associate a user ID with subsequent events.
    /// Pass `nil` to clear the identity (e.g. on sign out).
    func setUserId(_ id: String?) {
        userId = id

        #if DEBUG
        logger.info("Analytics user ID: \(id ?? "nil")")
        #endif

        // Future: Firebase.Analytics.setUserID(id)
        // Future: Mixpanel.getInstance()?.identify(distinctId: id ?? "")
    }

    /// Attach a custom property to the current user profile.
    func setUserProperty(_ value: String, forName name: String) {
        userProperties[name] = value

        #if DEBUG
        logger.info("Analytics user property: \(name)=\(value)")
        #endif

        // Future: Firebase.Analytics.setUserProperty(value, forName: name)
        // Future: Mixpanel.getInstance()?.people.set(properties: [name: value])
    }

    // MARK: - Configuration

    /// Enable or disable event dispatch at runtime.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        logger.info("Analytics \(enabled ? "enabled" : "disabled")")
    }

    /// Clear all user identity and properties.
    func reset() {
        userId = nil
        userProperties.removeAll()
        logger.info("Analytics state reset")
    }
}
