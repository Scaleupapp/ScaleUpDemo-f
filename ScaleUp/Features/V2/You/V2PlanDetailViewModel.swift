import Foundation

// MARK: - Codable models for GET /api/v2/you/plan/detail
//
// Every field is optional/nilable so the screen survives backend additions or
// renames without crashing. We mirror the field names from
// scaleup-backend/src/services/v2/planService.js exactly.

struct V2PlanDetail: Codable {
    let objective: V2PlanObjective?
    let summary: V2PlanSummary?
    let milestones: [V2PlanMilestone]?
    let phases: [V2PlanPhase]?
    let weeks: [V2PlanWeek]?
    let topicCoverage: [V2PlanTopicCoverage]?
    let completedHistory: [V2PlanCompletedHistoryItem]?
}

struct V2PlanObjective: Codable {
    let label: String?
    let type: String?
    let createdAt: String?
    let targetDate: String?
    let currentLevel: String?
    let writeUp: String?
    // `specifics` is free-form — we don't render it directly so we drop it.
}

struct V2PlanSummary: Codable {
    let totalWeeks: Int?
    let totalTasks: Int?
    let completedTasks: Int?
    let skippedTasks: Int?
    let remainingTasks: Int?
    let estimatedTotalHours: Double?
    let investedHours: Double?
    let currentReadiness: Int?
    let targetReadiness: Int?
    let projectedReadiness: Int?
    let onTrack: Bool?
    let weeksLateVsDeadline: Int?
}

struct V2PlanMilestone: Codable, Identifiable {
    var id: String { "\(week ?? 0)-\(label ?? "")" }
    let week: Int?
    let label: String?
    let expectedReadiness: Int?
    let isHit: Bool?
    let isCurrent: Bool?
}

struct V2PlanPhase: Codable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let weeks: [Int]?
    let focus: String?
    let rationale: String?
}

struct V2PlanWeek: Codable, Identifiable {
    var id: Int { week ?? 0 }
    let week: Int?
    let isCurrent: Bool?
    let status: String?
    let focusTopics: [String]?
    let tasks: [V2PlanTask]?
    let done: Int?
    let skipped: Int?
    let total: Int?
    let expectedReadinessAtEnd: Int?
    let notes: String?
}

struct V2PlanTask: Codable, Identifiable {
    var id: String { taskId ?? UUID().uuidString }
    let taskId: String?
    let type: String?
    let title: String?
    let topic: String?
    let topicDisplay: String?
    let estimatedMinutes: Int?
    let difficulty: String?
    let status: String?
    let completedAt: String?
    let reason: String?
    let payload: V2PlanTaskPayload?
}

struct V2PlanTaskPayload: Codable {
    let contentId: String?
    let quizId: String?
    let interviewId: String?
    let url: String?
    let challengeId: String?
}

struct V2PlanTopicCoverage: Codable, Identifiable {
    var id: String { topic ?? UUID().uuidString }
    let topic: String?
    let displayName: String?
    let taskCount: Int?
    let totalMinutes: Int?
    let currentMastery: Int?
    let expectedMastery: Int?
}

struct V2PlanCompletedHistoryItem: Codable, Identifiable {
    var id: String { taskId ?? UUID().uuidString }
    let taskId: String?
    let type: String?
    let title: String?
    let topic: String?
    let completedAt: String?
    let score: Int?
}

// MARK: - View model

import Observation

@Observable
@MainActor
final class V2PlanDetailViewModel {
    var data: V2PlanDetail?
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: V2APIResponse<V2PlanDetail> =
                try await V2APIClient.shared.get("/you/plan/detail")
            data = response.data
            error = nil
        } catch {
            self.error = "Couldn't load your plan."
        }
    }
}
