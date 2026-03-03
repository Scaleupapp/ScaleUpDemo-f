import Foundation

// MARK: - Dashboard

struct Dashboard: Codable, Sendable {
    let readinessScore: Int?
    let nextActions: [NextAction]?
    let pendingQuizzes: Int?
    let weeklyStats: WeeklyStats?
    let knowledgeProfile: KnowledgeProfile?
    let objectives: [Objective]?
    let journey: JourneyOverview?
    let upcomingMilestones: [Milestone]?
    let weeklyGrowth: WeeklyGrowth?

    var knowledgeSnapshot: [KnowledgeSnapshot] {
        knowledgeProfile?.topicMastery ?? []
    }
}

// MARK: - Objective

struct Objective: Codable, Sendable, Identifiable {
    let id: String
    let objectiveType: String?
    let specifics: DashboardObjectiveSpecifics?
    let isPrimary: Bool?
    let timeline: String?
    let targetDate: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case objectiveType, specifics, isPrimary, timeline, targetDate
    }

    var targetRole: String? { specifics?.targetRole }
    var targetSkill: String? { specifics?.targetSkill }

    var daysRemaining: Int? {
        guard let target = targetDate else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0)
    }
}

struct DashboardObjectiveSpecifics: Codable, Sendable {
    let targetRole: String?
    let targetSkill: String?
}

// MARK: - Journey Overview

struct JourneyOverview: Codable, Sendable {
    let title: String?
    let currentPhase: String?
    let currentWeek: Int?
    let progress: JourneyProgress?
    let streak: Int?
}

struct JourneyProgress: Codable, Sendable {
    let contentAssigned: Int?
    let contentConsumed: Int?
    let milestonesTotal: Int?
    let milestonesCompleted: Int?
    let overallPercentage: Int?
    let quizzesCompleted: Int?
    let quizzesAssigned: Int?
    let currentStreak: Int?
    let longestStreak: Int?
}

// MARK: - Milestone

struct Milestone: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let type: String?
    let status: String?
    let targetCriteria: MilestoneTarget?
    let scheduledWeek: Int?
    let scheduledDate: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, type, status, targetCriteria, scheduledWeek, scheduledDate
    }
}

struct MilestoneTarget: Codable, Sendable, Hashable {
    let targetScore: Int?
    let targetTopic: String?
}

// MARK: - Weekly Growth

struct WeeklyGrowth: Codable, Sendable {
    let contentDelta: Int?
    let contentThisWeek: Int?
    let contentLastWeek: Int?
}

// MARK: - Knowledge Profile

struct KnowledgeProfile: Codable, Sendable {
    let overallScore: Int?
    let totalTopicsCovered: Int?
    let totalQuizzesTaken: Int?
    let strengths: [String]?
    let weaknesses: [String]?
    let topicMastery: [KnowledgeSnapshot]?
}

// MARK: - Next Action

struct NextAction: Codable, Sendable, Identifiable {
    var id: String { type + (message ?? "") }
    let type: String
    let message: String?
}

// MARK: - Weekly Stats

struct WeeklyStats: Codable, Sendable {
    let contentConsumed: Int?
    let totalContentConsumed: Int?
    let dominantTopics: [String]?
}

// MARK: - Knowledge Snapshot

struct KnowledgeSnapshot: Codable, Sendable, Identifiable {
    var id: String { topic }
    let topic: String
    let score: Int
    let level: String?
    let trend: Trend?
}

// MARK: - Trend

enum Trend: String, Codable, Sendable {
    case improving, stable, declining

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }
}

// MARK: - Daily Plan

struct DailyPlan: Codable, Sendable {
    let dayNumber: Int?
    let items: [DailyPlanItem]?
    let estimatedMinutes: Int?
}

struct DailyPlanItem: Codable, Sendable, Identifiable {
    var id: String { contentId ?? title }
    let title: String
    let contentId: String?
    let contentType: ContentType?
    let duration: Int?
    let isCompleted: Bool?
    let topic: String?
}
