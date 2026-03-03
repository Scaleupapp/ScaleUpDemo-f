import SwiftUI

// MARK: - Full Knowledge Profile (GET /knowledge/profile)

struct FullKnowledgeProfile: Codable, Sendable {
    let topicMastery: [TopicMasteryEntry]?
    let learningVelocity: LearningVelocity?
    let retention: RetentionData?
    let behavioralProfile: BehavioralProfile?
    let strengths: [String]?
    let weaknesses: [String]?
    let overallScore: Int?
    let totalQuizzesTaken: Int?
    let totalTopicsCovered: Int?
}

// MARK: - Topic Mastery Entry

struct TopicMasteryEntry: Codable, Sendable, Identifiable {
    var id: String { topic }
    let topic: String
    let score: Int?
    let level: String?
    let quizzesTaken: Int?
    let lastAssessedAt: Date?
    let scoreHistory: [ScoreHistoryEntry]?
    let trend: Trend?

    var scoreValue: Int { score ?? 0 }

    var levelDisplay: String {
        (level ?? "not_started").replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Learning Velocity

struct LearningVelocity: Codable, Sendable {
    let topicsPerWeek: Double?
    let averageScoreImprovement: Double?
    let contentToMasteryRatio: Double?
}

// MARK: - Retention Data

struct RetentionData: Codable, Sendable {
    let averageRetentionRate: Double?
    let optimalReviewInterval: Int?
}

// MARK: - Behavioral Profile

struct BehavioralProfile: Codable, Sendable {
    let type: String?
    let averageAnswerTime: Double?
    let peakHours: [Int]?
    let consistencyScore: Double?

    var typeDisplay: String {
        (type ?? "balanced").replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Knowledge Gap (GET /knowledge/gaps)

struct KnowledgeGap: Codable, Sendable, Identifiable {
    var id: String { topic }
    let topic: String
    let score: Int?
    let level: String?
    let quizzesTaken: Int?
    let suggestion: String?

    var scoreValue: Int { score ?? 0 }
}

// MARK: - Consumption Stats (GET /progress/stats)

struct ConsumptionStats: Codable, Sendable {
    let totalContentConsumed: Int?
    let totalTimeSpent: Int?
    let dominantTopics: [String]?
    let topicCount: Int?
    let topicBreakdown: [TopicBreakdownStat]?

    var formattedTimeSpent: String {
        guard let total = totalTimeSpent else { return "0m" }
        let hours = total / 3600
        let mins = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}

struct TopicBreakdownStat: Codable, Sendable, Identifiable {
    var id: String { topic }
    let topic: String
    let contentConsumed: Int?
    let affinityScore: Double?
}

// MARK: - Next Action Item (GET /recommendations/next-actions)

struct NextActionsResponse: Codable, Sendable {
    let actions: [NextActionItem]?
}

struct NextActionItem: Codable, Sendable, Identifiable {
    var id: String { "\(priority)-\(type)" }
    let priority: Int
    let type: String
    let label: String
    let subtitle: String?
    let quizId: String?
    let contentId: String?
    let content: Content?
    let progressPercentage: Double?
    let items: [Content]?
    let topic: String?

    var icon: String {
        switch type {
        case "take_quiz": return "brain.head.profile"
        case "resume_content": return "play.circle.fill"
        case "journey_today": return "calendar.badge.clock"
        case "fill_gaps": return "exclamationmark.triangle.fill"
        case "explore": return "safari.fill"
        default: return "arrow.right.circle.fill"
        }
    }
}

// MARK: - Activity Heatmap (GET /progress/activity-heatmap)

struct ActivityDay: Codable, Sendable, Identifiable {
    var id: String { date }
    let date: String
    let count: Int

    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

// MARK: - Timeline Event (GET /progress/timeline)

struct TimelineEvent: Codable, Sendable, Identifiable {
    var id: String { "\(type)-\(title)-\(Int(date?.timeIntervalSince1970 ?? 0))" }
    let type: String
    let title: String
    let subtitle: String?
    let date: Date?
    let metadata: TimelineMetadata?

    var icon: String {
        switch type {
        case "content_completed": return "play.circle.fill"
        case "quiz_completed": return "brain.head.profile"
        case "milestone_achieved": return "flag.fill"
        case "streak_milestone": return "flame.fill"
        default: return "circle.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case "content_completed": return ColorTokens.info
        case "quiz_completed": return ColorTokens.gold
        case "milestone_achieved": return ColorTokens.success
        case "streak_milestone": return ColorTokens.streakActive
        default: return ColorTokens.textTertiary
        }
    }
}

struct TimelineMetadata: Codable, Sendable {
    let contentType: String?
    let duration: Int?
    let thumbnailURL: String?
    let topic: String?
    let percentage: Double?
    let milestoneType: String?
}
