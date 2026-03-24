import UserNotifications
import UIKit

@MainActor
@Observable
final class PushNotificationManager: NSObject {

    var isPermissionGranted = false
    var deviceToken: String?

    private let notificationService = NotificationService()

    // MARK: - Request Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isPermissionGranted = granted

            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            isPermissionGranted = false
        }
    }

    // MARK: - Check Current Status

    func checkPermissionStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isPermissionGranted = settings.authorizationStatus == .authorized
    }

    // MARK: - Handle Device Token

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token

        // Send token to backend
        Task {
            try? await notificationService.registerDeviceToken(token)
        }
    }

    // MARK: - Handle Push Notification

    func handleNotification(_ userInfo: [AnyHashable: Any]) -> String? {
        // Extract deep link from notification payload
        if let deepLink = userInfo["deepLink"] as? String {
            return deepLink
        }
        if let data = userInfo["data"] as? [String: Any],
           let deepLink = data["deepLink"] as? String {
            return deepLink
        }

        // Extract type-based deep link for competition notifications
        let type = userInfo["type"] as? String
            ?? (userInfo["data"] as? [String: Any])?["type"] as? String
        let data = userInfo["data"] as? [String: Any] ?? [:]

        switch type {
        case "challenge_live":
            if let challengeId = data["challengeId"] as? String {
                return "challenge://\(challengeId)"
            }
        case "weekly_results":
            if let topic = data["topic"] as? String {
                return "leaderboard://\(topic)"
            }
            return "leaderboard://"
        case "live_event_reminder":
            if let eventId = data["eventId"] as? String {
                return "live_event://\(eventId)"
            }
        case "streak_reminder":
            return "home://competition"
        case "live_event_results":
            if let eventId = data["eventId"] as? String {
                return "live_event_results://\(eventId)"
            }
        default:
            break
        }

        return nil
    }

    // MARK: - Clear Badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
