import UserNotifications
import UIKit
import os

// MARK: - Notification Manager

/// Manages local notification scheduling, authorization, and badge counts.
///
/// This class wraps `UNUserNotificationCenter` to provide a clean, observable
/// interface for the rest of the app. All scheduling methods are safe to call
/// regardless of authorization status — they will silently no-op if the user
/// has not granted permission.
@Observable @MainActor
final class NotificationManager {

    // MARK: - State

    var isAuthorized = false
    var pendingNotifications: [UNNotificationRequest] = []

    // MARK: - Private

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.scaleup", category: "Notifications")

    // MARK: - Notification Identifiers

    private enum Identifier {
        static let dailyReminder = "com.scaleup.daily-reminder"
        static let streakReminder = "com.scaleup.streak-reminder"
        static let quizReminderPrefix = "com.scaleup.quiz-reminder."
        static let milestonePrefix = "com.scaleup.milestone."
    }

    // MARK: - Authorization

    /// Requests notification authorization from the user.
    /// - Returns: `true` if the user granted permission.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            isAuthorized = granted
            logger.info("Notification authorization \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            isAuthorized = false
            return false
        }
    }

    /// Checks the current authorization status and updates the `isAuthorized` property.
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .denied, .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        logger.debug("Authorization status: \(settings.authorizationStatus.rawValue)")
    }

    // MARK: - Schedule: Daily Reminder

    /// Schedules a daily learning reminder at the specified time.
    /// Replaces any existing daily reminder.
    /// - Parameters:
    ///   - hour: The hour component (0-23).
    ///   - minute: The minute component (0-59).
    func scheduleDailyReminder(hour: Int, minute: Int) {
        guard isAuthorized else {
            logger.warning("Cannot schedule daily reminder — not authorized")
            return
        }

        // Remove existing daily reminder first
        center.removePendingNotificationRequests(
            withIdentifiers: [Identifier.dailyReminder]
        )

        let content = UNMutableNotificationContent()
        content.title = "Time to Learn"
        content.body = "Your daily learning session is waiting. Keep your streak alive!"
        content.sound = .default
        content.userInfo = ["type": "streak"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Identifier.dailyReminder,
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Failed to schedule daily reminder: \(error.localizedDescription)")
            } else {
                self?.logger.info("Scheduled daily reminder at \(hour):\(minute)")
            }
        }
    }

    // MARK: - Schedule: Quiz Reminder

    /// Schedules a one-time notification reminding the user about an available quiz.
    /// - Parameters:
    ///   - quizTitle: The display title for the quiz.
    ///   - contentId: The content ID associated with the quiz, used for deep linking.
    ///   - delay: Time interval from now until the notification fires.
    func scheduleQuizReminder(quizTitle: String, contentId: String, delay: TimeInterval) {
        guard isAuthorized else {
            logger.warning("Cannot schedule quiz reminder — not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Quiz Ready"
        content.body = "Test your knowledge: \(quizTitle)"
        content.sound = .default
        content.userInfo = [
            "type": "quiz",
            "id": contentId
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(delay, 1),
            repeats: false
        )

        let identifier = "\(Identifier.quizReminderPrefix)\(contentId)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Failed to schedule quiz reminder: \(error.localizedDescription)")
            } else {
                self?.logger.info("Scheduled quiz reminder for '\(quizTitle)' in \(delay)s")
            }
        }
    }

    // MARK: - Schedule: Streak Reminder

    /// Schedules a streak reminder notification at 8 PM daily.
    /// Intended to remind the user if they haven't completed any activity today.
    func scheduleStreakReminder() {
        guard isAuthorized else {
            logger.warning("Cannot schedule streak reminder — not authorized")
            return
        }

        // Remove existing streak reminder
        center.removePendingNotificationRequests(
            withIdentifiers: [Identifier.streakReminder]
        )

        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak!"
        content.body = "You haven't learned anything today. A quick session keeps your streak going."
        content.sound = .default
        content.userInfo = ["type": "streak"]

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Identifier.streakReminder,
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Failed to schedule streak reminder: \(error.localizedDescription)")
            } else {
                self?.logger.info("Scheduled streak reminder at 8 PM daily")
            }
        }
    }

    // MARK: - Schedule: Milestone

    /// Fires an immediate notification celebrating a milestone achievement.
    /// - Parameters:
    ///   - title: The milestone title (e.g., "10-Day Streak!").
    ///   - message: A congratulatory message.
    func scheduleMilestoneNotification(title: String, message: String) {
        guard isAuthorized else {
            logger.warning("Cannot schedule milestone notification — not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.userInfo = ["type": "milestone"]

        // Fire in 1 second so the user sees a banner
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )

        let identifier = "\(Identifier.milestonePrefix)\(UUID().uuidString)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Failed to schedule milestone notification: \(error.localizedDescription)")
            } else {
                self?.logger.info("Scheduled milestone: \(title)")
            }
        }
    }

    // MARK: - Cancel

    /// Cancels all pending notifications.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        logger.info("Cancelled all pending notifications")
    }

    /// Cancels a specific pending notification by identifier.
    /// - Parameter id: The notification request identifier.
    func cancelNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        logger.info("Cancelled notification: \(id)")
    }

    // MARK: - Badge Management

    /// Clears the app badge count.
    func clearBadge() {
        setBadge(count: 0)
    }

    /// Sets the app badge to the specified count.
    /// - Parameter count: The badge number to display. Use 0 to clear.
    func setBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { [weak self] error in
            if let error {
                self?.logger.error("Failed to set badge count: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Refresh Pending

    /// Fetches the list of currently pending notification requests.
    func refreshPendingNotifications() async {
        pendingNotifications = await center.pendingNotificationRequests()
        logger.debug("Pending notifications: \(self.pendingNotifications.count)")
    }
}
