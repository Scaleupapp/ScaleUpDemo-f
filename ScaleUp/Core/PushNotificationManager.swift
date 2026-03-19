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
        return nil
    }

    // MARK: - Clear Badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
