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
    case competitionChallenge = "competition_challenge"
    case competitionResults = "competition_results"
    case competitionReminder = "competition_reminder"
    case creatorApplication = "creator_application"
    // Placement (institution) assessment notifications. The backend starts
    // emitting these only after PLACEMENTS_NOTIFICATIONS_ENABLED flips on, but
    // the app must decode them today so an early payload doesn't break the inbox.
    case assessmentAssigned = "assessment_assigned"
    case assessmentResults = "assessment_results"
    /// Forward-compatible catch-all. ANY unrecognised server type decodes here
    /// via `init(from:)` instead of throwing — a single unknown type used to
    /// fail the whole `[AppNotification]` decode and blank the inbox.
    case other = "other"

    /// Decode-tolerant: unknown raw strings fall back to `.other` rather than
    /// throwing, so future notification types never break older clients.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NotificationType(rawValue: raw) ?? .other
    }

    var icon: String {
        switch self {
        case .quizAvailable: return "brain.head.profile"
        case .milestoneReached: return "trophy.fill"
        case .streakReminder: return "flame.fill"
        case .journeyUpdate: return "map.fill"
        case .socialFollow: return "person.fill.badge.plus"
        case .socialComment: return "bubble.left.fill"
        case .competitionChallenge: return "bolt.fill"
        case .competitionResults: return "chart.bar.fill"
        case .competitionReminder: return "bell.badge.fill"
        case .creatorApplication: return "person.crop.circle.badge.checkmark"
        case .assessmentAssigned: return "checklist"
        case .assessmentResults: return "chart.bar.doc.horizontal.fill"
        case .other: return "bell.fill"
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
        case .competitionChallenge: return "gold"
        case .competitionResults: return "green"
        case .competitionReminder: return "orange"
        case .creatorApplication: return "blue"
        case .assessmentAssigned: return "gold"
        case .assessmentResults: return "green"
        case .other: return "gold"
        }
    }
}

// MARK: - Unread Count Response

struct UnreadCountResponse: Codable, Sendable {
    let unreadCount: Int
}
