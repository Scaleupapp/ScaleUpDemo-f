import Foundation

// MARK: - Journey

struct Journey: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let objectiveId: String
    let title: String
    let phases: [JourneyPhaseDetail]
    let weeklyPlans: [WeeklyPlan]
    let milestones: [Milestone]
    let progress: JourneyProgress
    let currentPhaseIndex: Int
    let currentWeek: Int
    let status: JourneyStatus
    let createdAt: String

    /// Computed for backward compatibility with views that use `journey.currentPhase`.
    var currentPhase: JourneyPhase {
        guard currentPhaseIndex >= 0, currentPhaseIndex < phases.count,
              let phaseType = phases[currentPhaseIndex].type else {
            return .foundation
        }
        return JourneyPhase(rawValue: phaseType) ?? .foundation
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, objectiveId, title
        case phases, weeklyPlans, milestones
        case progress, currentPhaseIndex, currentWeek
        case status, createdAt
    }
}

// MARK: - JourneyPhaseDetail

struct JourneyPhaseDetail: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String?
    let order: Int?
    let durationDays: Int?
    let startDate: String?
    let endDate: String?
    let status: String?
    let objectives: [String]?
    let focusTopics: [String]?

    // Computed properties for backward compatibility with views
    var description: String { name }
    var topics: [String] { focusTopics ?? [] }
    var weekNumbers: [Int] {
        guard let order, let days = durationDays else { return [] }
        let weeks = max(days / 7, 1)
        let startWeek = (order - 1) * weeks + 1
        return Array(startWeek...(startWeek + weeks - 1))
    }
    var estimatedDuration: String? {
        guard let days = durationDays else { return nil }
        if days >= 7 {
            return "\(days / 7) weeks"
        }
        return "\(days) days"
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, type, order, durationDays
        case startDate, endDate, status
        case objectives, focusTopics
    }
}

// MARK: - WeeklyPlan

struct WeeklyPlan: Codable, Identifiable, Hashable {
    let id: String
    let weekNumber: Int
    let phaseIndex: Int?
    let status: String?
    let dailyAssignments: [DailyAssignment]
    let goals: [String]?
    let outcomes: [String]?

    /// For backward compatibility with views that use `plan.theme`.
    var theme: String {
        goals?.first ?? "Week \(weekNumber)"
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case weekNumber, phaseIndex, status
        case dailyAssignments, goals, outcomes
    }
}

// MARK: - DailyAssignment

struct DailyAssignment: Codable, Hashable {
    let day: Int
    let topics: [String]?
    let contentIds: [String]?
    let estimatedTime: Int?
    let completed: Bool?

    /// For backward compatibility with views.
    var estimatedMinutes: Int { estimatedTime ?? 0 }
    var isRestDay: Bool { (topics ?? []).isEmpty && (contentIds ?? []).isEmpty }
}

// MARK: - Milestone

struct Milestone: Codable, Identifiable, Hashable {
    let id: String
    let type: String?
    let title: String
    let targetCriteria: MilestoneTargetCriteria?
    let scheduledDate: String?
    let status: String?
    let completedAt: String?

    // Computed properties for backward compatibility
    var description: String? { targetCriteria?.targetTopic }
    var targetValue: Int { targetCriteria?.targetScore ?? 0 }
    var currentValue: Int {
        status == "completed" ? targetValue : 0
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type, title, targetCriteria
        case scheduledDate, status, completedAt
    }
}

// MARK: - MilestoneTargetCriteria

struct MilestoneTargetCriteria: Codable, Hashable {
    let targetScore: Int?
    let targetTopic: String?
    let streakDays: Int?
}

// MARK: - JourneyProgress

struct JourneyProgress: Codable, Hashable {
    let overallPercentage: Double?
    let contentConsumed: Int?
    let contentAssigned: Int?
    let quizzesCompleted: Int?
    let quizzesAssigned: Int?
    let currentStreak: Int?
    let milestonesCompleted: Int?
    let milestonesTotal: Int?
}

// MARK: - TodayPlan

struct TodayPlan: Codable, Hashable {
    let weekNumber: Int
    let day: Int
    let plan: DailyAssignment
    let weekGoals: [String]?
}
