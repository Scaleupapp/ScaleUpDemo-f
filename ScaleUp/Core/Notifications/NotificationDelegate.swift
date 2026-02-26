import UserNotifications
import os

// MARK: - Notification Delegate

/// Handles `UNUserNotificationCenter` delegate callbacks.
///
/// This class is intentionally **not** `@Observable` or `@MainActor` because
/// `UNUserNotificationCenterDelegate` methods are called on an arbitrary queue.
/// It communicates back to the SwiftUI layer via the `onNotificationTap` closure,
/// which the app entry point should wire up to route through `DeepLinkManager`.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    // MARK: - Callback

    /// Called when the user taps a notification. The closure receives a `DeepLink`
    /// parsed from the notification payload. Set this from your `@main` App struct.
    var onNotificationTap: (@Sendable (DeepLink) -> Void)?

    // MARK: - Private

    private let logger = Logger(subsystem: "com.scaleup", category: "NotificationDelegate")

    // MARK: - Did Receive (Notification Tap)

    /// Called when the user taps on a delivered notification.
    /// Parses the `userInfo` into a `DeepLink` and invokes `onNotificationTap`.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        logger.info("Notification tapped with userInfo: \(userInfo)")

        if let deepLink = DeepLink.from(userInfo: userInfo) {
            logger.info("Parsed deep link from notification: \(String(describing: deepLink))")
            let callback = onNotificationTap
            DispatchQueue.main.async {
                callback?(deepLink)
            }
        } else {
            logger.warning("Could not parse deep link from notification payload")
        }

        completionHandler()
    }

    // MARK: - Will Present (Foreground Notification)

    /// Called when a notification arrives while the app is in the foreground.
    /// Displays the notification as a banner so the user is still aware of it.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let title = notification.request.content.title
        logger.info("Presenting foreground notification: \(title)")

        // Show banner, play sound, and update badge even when app is active
        completionHandler([.banner, .sound, .badge])
    }
}
