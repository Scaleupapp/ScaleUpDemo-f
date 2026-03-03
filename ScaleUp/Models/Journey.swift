import Foundation

// MARK: - Journey Status

enum JourneyStatus: String, Codable, Sendable {
    case generating, active, paused, completed, abandoned
}

// MARK: - Journey (full model)

struct Journey: Codable, Sendable, Identifiable {
    let id: String
    let userId: String?
    let objectiveId: String?
    let title: String?
    let status: JourneyStatus?
    let phases: [JourneyPhase]?
    let currentPhaseIndex: Int?
    let currentWeek: Int?
    let weeklyPlans: [WeeklyPlan]?
    let milestones: [Milestone]?
    let adaptationHistory: [AdaptationEntry]?
    let progress: JourneyProgress?
    let aiModel: String?
    let generatedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, objectiveId, title, status, phases
        case currentPhaseIndex, currentWeek, weeklyPlans
        case milestones, adaptationHistory, progress
        case aiModel, generatedAt, createdAt, updatedAt
    }

    var totalWeeks: Int {
        weeklyPlans?.count ?? 0
    }

    var currentPhaseName: String? {
        guard let idx = currentPhaseIndex, let phases, idx < phases.count else { return nil }
        return phases[idx].name
    }
}

// MARK: - Journey Phase

struct JourneyPhase: Codable, Sendable, Identifiable {
    var id: String { "\(order)-\(name)" }
    let name: String
    let type: String?
    let order: Int
    let durationDays: Int?
    let startDate: Date?
    let endDate: Date?
    let status: String?
    let objectives: [String]?
    let focusTopics: [String]?
}

// MARK: - Weekly Plan

struct WeeklyPlan: Codable, Sendable, Identifiable {
    var id: String { "week-\(weekNumber)" }
    let weekNumber: Int
    let startDate: Date?
    let endDate: Date?
    let phaseIndex: Int?
    let status: String?
    let dailyAssignments: [DailyAssignment]?
    let scheduledQuiz: ScheduledQuiz?
    let goals: [String]?
    let outcomes: [String]?
}

// MARK: - Daily Assignment

struct DailyAssignment: Codable, Sendable, Identifiable {
    var id: String { "day-\(day)" }
    let day: Int
    let contentIds: [String]?
    let topics: [String]?
    let estimatedTime: Int?
    let completed: Bool?
    let completedAt: Date?
}

// MARK: - Scheduled Quiz

struct ScheduledQuiz: Codable, Sendable {
    let dayOfWeek: Int?
    let type: String?
    let topics: [String]?
    let quizId: String?
    let completed: Bool?
}

// MARK: - Adaptation Entry

struct AdaptationEntry: Codable, Sendable, Identifiable {
    var id: String { "\(trigger)-\(date?.timeIntervalSince1970 ?? 0)" }
    let date: Date?
    let trigger: String
    let changes: String?
    let details: AdaptationDetails?
}

struct AdaptationDetails: Codable, Sendable {
    let topic: String?
    let score: Int?
    let attemptId: String?
}

// MARK: - Journey Dashboard (GET /journey/dashboard response)

struct JourneyDashboard: Codable, Sendable {
    let objective: JourneyObjective?
    let journey: JourneyDashboardSummary?
    let currentPhase: JourneyPhaseSnapshot?
    let phases: [JourneyPhaseSnapshot]?
    let progress: JourneyProgress?
    let pace: JourneyPace?
    let currentWeek: JourneyDashboardWeek?
    let today: JourneyDashboardToday?
    let topicMastery: [KnowledgeSnapshot]?
    let milestones: [Milestone]?
    let nextMilestone: Milestone?
    let nextAction: JourneyNextAction?
}

// MARK: - Objective in Dashboard

struct JourneyObjective: Codable, Sendable {
    let id: String?
    let objectiveType: String?
    let specifics: JourneyObjectiveSpecifics?
    let timeline: String?
    let targetDate: Date?
    let currentLevel: String?
    let weeklyCommitHours: Int?
    let daysRemaining: Int?

    var goalTitle: String {
        if let role = specifics?.targetRole {
            return "Become a \(role)"
        } else if let skill = specifics?.targetSkill {
            return "Master \(skill)"
        } else if let exam = specifics?.examName {
            return "Prepare for \(exam)"
        }
        return objectiveType?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Learning Goal"
    }

    var timelineDisplay: String {
        guard let days = daysRemaining else { return timeline?.replacingOccurrences(of: "_", with: " ") ?? "" }
        if days <= 0 { return "Target reached" }
        if days == 1 { return "1 day left" }
        if days < 7 { return "\(days) days left" }
        if days < 30 { return "\(days / 7) weeks left" }
        return "\(days / 30) months left"
    }
}

struct JourneyObjectiveSpecifics: Codable, Sendable {
    let examName: String?
    let targetRole: String?
    let targetSkill: String?
    let targetCompany: String?
    let fromDomain: String?
    let toDomain: String?
}

// MARK: - Phase Snapshot

struct JourneyPhaseSnapshot: Codable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let type: String?
    let status: String?
    let focusTopics: [String]?
    let objectives: [String]?
    let order: Int?
    let contentAssigned: Int?
    let contentConsumed: Int?
}

// MARK: - Pace

struct JourneyPace: Codable, Sendable {
    let status: String?
    let weeksRemaining: Int?
    let estimatedCompletionDate: Date?
    let daysRemaining: Int?

    var statusDisplay: String {
        switch status {
        case "ahead": return "Ahead of schedule"
        case "on_track": return "On track"
        case "behind": return "Behind schedule"
        case "at_risk": return "At risk"
        default: return "On track"
        }
    }

    var statusIcon: String {
        switch status {
        case "ahead": return "hare.fill"
        case "on_track": return "checkmark.circle.fill"
        case "behind": return "tortoise.fill"
        case "at_risk": return "exclamationmark.triangle.fill"
        default: return "checkmark.circle.fill"
        }
    }
}

struct JourneyDashboardSummary: Codable, Sendable {
    let id: String?
    let title: String?
    let status: String?
    let currentWeek: Int?
    let totalWeeks: Int?
    let createdAt: Date?
}

struct JourneyDashboardWeek: Codable, Sendable {
    let weekNumber: Int?
    let goals: [String]?
    let theme: String?
    let daysSummary: [DaySummary]?
    let completedDays: Int?
    let totalDays: Int?
    let totalContent: Int?
}

struct DaySummary: Codable, Sendable, Identifiable {
    var id: Int { day }
    let day: Int
    let completed: Bool?
    let contentCount: Int?
    let topics: [String]?
}

struct JourneyDashboardToday: Codable, Sendable {
    let day: Int?
    let completed: Bool?
    let contentItems: [Content]?
    let todayStats: TodayStats?
}

struct TodayStats: Codable, Sendable {
    let totalItems: Int?
    let completedItems: Int?
    let inProgressItems: Int?
}

struct JourneyNextAction: Codable, Sendable {
    let type: String?
    let label: String?
    let subtitle: String?
    let contentId: String?
    let contentType: String?
    let progressPercentage: Double?
}

// MARK: - Today Response (GET /journey/today)

struct TodayResponse: Codable, Sendable {
    let weekNumber: Int?
    let day: Int?
    let plan: DailyAssignment?
    let contentItems: [Content]?
    let weekGoals: [String]?
    let todayStats: TodayStats?
    let topicMastery: [KnowledgeSnapshot]?
    let journeyProgress: JourneyProgressSummary?
}

struct JourneyProgressSummary: Codable, Sendable {
    let currentWeek: Int?
    let totalWeeks: Int?
    let overallPercentage: Double?
    let weekCompletedDays: Int?
    let weekTotalDays: Int?
}

// MARK: - Week Response (GET /journey/week/:n)

struct WeekResponse: Codable, Sendable {
    let weekPlan: WeeklyPlan?
    let contentItems: [Content]?
    let weekStats: WeekStats?
    let topicMastery: [KnowledgeSnapshot]?
    let isCurrentWeek: Bool?
}

struct WeekStats: Codable, Sendable {
    let totalItems: Int?
    let completedItems: Int?
    let completedDays: Int?
    let totalDays: Int?
}

// MARK: - Assignment Complete Response

struct AssignmentCompleteResponse: Codable, Sendable {
    let assignment: DailyAssignment?
    let progress: JourneyProgress?
}

// MARK: - Generate Request

struct GenerateJourneyRequest: Encodable, Sendable {
    let objectiveId: String
}
