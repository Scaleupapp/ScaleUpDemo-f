import Foundation

enum UserDefaultsManager {
    private nonisolated(unsafe) static let defaults = UserDefaults.standard

    enum Key: String {
        case hasCompletedOnboarding
        case prefersDarkMode
        case hasFCMToken
        case lastFeedRefresh

        // Notification Preferences
        case notificationDailyReminder
        case notificationDailyReminderHour
        case notificationDailyReminderMinute
        case notificationQuizReminders
        case notificationStreakReminders
        case notificationMilestoneCelebrations
    }

    static func set(_ value: Bool, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    static func getBool(for key: Key) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    static func set(_ value: String, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    static func getString(for key: Key) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    static func set(_ value: Int, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    static func getInt(for key: Key) -> Int {
        defaults.integer(forKey: key.rawValue)
    }

    static func set(_ value: Date, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    static func getDate(for key: Key) -> Date? {
        defaults.object(forKey: key.rawValue) as? Date
    }

    static func remove(for key: Key) {
        defaults.removeObject(forKey: key.rawValue)
    }
}
