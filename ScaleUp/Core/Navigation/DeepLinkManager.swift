import Foundation
import os

// MARK: - Deep Link Manager

/// Manages incoming deep links from URL schemes, notifications, and external sources.
/// Coordinates with `AppRouter` to navigate to the appropriate destination.
@Observable @MainActor
final class DeepLinkManager {

    // MARK: - State

    /// A deep link that is waiting to be consumed. Set when a deep link arrives
    /// while the app is still loading or the target view is not yet mounted.
    var pendingDeepLink: DeepLink?

    // MARK: - Private

    private let logger = Logger(subsystem: "com.scaleup", category: "DeepLink")

    // MARK: - Handle Deep Link

    /// Processes a deep link immediately. If the app is not in a state to navigate
    /// (e.g., user is not authenticated), the deep link is stored as pending.
    func handle(_ deepLink: DeepLink) {
        logger.info("Handling deep link: \(String(describing: deepLink))")
        pendingDeepLink = deepLink
    }

    // MARK: - Handle URL

    /// Attempts to parse and handle a URL with the `scaleup://` scheme.
    /// - Parameter url: The incoming URL.
    /// - Returns: `true` if the URL was successfully parsed as a deep link.
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        logger.info("Received URL: \(url.absoluteString)")

        guard let deepLink = DeepLink.from(url: url) else {
            logger.warning("Could not parse deep link from URL: \(url.absoluteString)")
            return false
        }

        handle(deepLink)
        return true
    }

    // MARK: - Handle Notification

    /// Parses a notification's `userInfo` dictionary into a `DeepLink`.
    /// - Parameter userInfo: The notification payload.
    /// - Returns: The parsed `DeepLink`, or `nil` if the payload is not navigable.
    func handleNotification(userInfo: [AnyHashable: Any]) -> DeepLink? {
        logger.info("Parsing notification userInfo for deep link")

        guard let deepLink = DeepLink.from(userInfo: userInfo) else {
            logger.warning("Could not parse deep link from notification userInfo")
            return nil
        }

        handle(deepLink)
        return deepLink
    }

    // MARK: - Consume

    /// Consumes and returns the pending deep link, clearing it from state.
    /// Call this from the view layer after navigation has been performed.
    func consumePendingDeepLink() -> DeepLink? {
        guard let deepLink = pendingDeepLink else { return nil }
        pendingDeepLink = nil
        logger.info("Consumed pending deep link: \(String(describing: deepLink))")
        return deepLink
    }
}
