import Foundation

// MARK: - App Notification

struct AppNotification: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let userId: String?
    let type: NotificationType
    let title: String
    let message: String
    let isRead: Bool
    let deepLink: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, type, title, message, isRead, deepLink, createdAt, updatedAt
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable, Sendable {
    case quizAvailable = "quiz_available"
    case milestoneReached = "milestone_reached"
    case streakReminder = "streak_reminder"
    case journeyUpdate = "journey_update"
    case socialFollow = "social_follow"
    case socialComment = "social_comment"

    var icon: String {
        switch self {
        case .quizAvailable: return "brain.head.profile"
        case .milestoneReached: return "trophy.fill"
        case .streakReminder: return "flame.fill"
        case .journeyUpdate: return "map.fill"
        case .socialFollow: return "person.fill.badge.plus"
        case .socialComment: return "bubble.left.fill"
        }
    }

    var iconColor: String {
        switch self {
        case .quizAvailable: return "gold"
        case .milestoneReached: return "gold"
        case .streakReminder: return "orange"
        case .journeyUpdate: return "blue"
        case .socialFollow: return "purple"
        case .socialComment: return "green"
        }
    }
}

// MARK: - Unread Count Response

struct UnreadCountResponse: Codable, Sendable {
    let unreadCount: Int
}
