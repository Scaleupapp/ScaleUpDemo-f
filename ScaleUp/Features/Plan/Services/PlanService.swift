import Foundation

// MARK: - Plan DTOs

struct PlanStatusDTO: Decodable, Sendable {
    let status: String
    let planId: String?
}

struct WeeklyAllocation: Decodable, Sendable {
    let topic: String
    let canonicalTopic: String?
    let hoursAllocated: Double
    let focusActivity: String
}

struct WeeklyEntry: Decodable, Sendable {
    let weekNumber: Int
    let weekLabel: String
    let totalHours: Double
    let allocations: [WeeklyAllocation]
}

struct PlanMilestone: Decodable, Sendable {
    let title: String
    let measurableCriteria: String
    let weekTarget: Int
    let isUserStated: Bool
}

struct PlanDTO: Decodable, Sendable {
    let planId: String
    let planHeadline: String
    let totalWeeks: Int
    let totalHours: Double
    let milestoneCount: Int
    let bufferRecommendation: String?
    let weeklySchedule: [WeeklyEntry]
    let milestones: [PlanMilestone]
    let source: String?
}

// MARK: - Plan Service

actor PlanService {
    static let shared = PlanService()

    private let api = APIClient.shared

    func fetchStatus() async throws -> PlanStatusDTO {
        try await api.request(PlanEndpoints.status)
    }

    func fetchCurrent() async throws -> PlanDTO {
        try await api.request(PlanEndpoints.current)
    }
}

// MARK: - Recalibration Growth DTOs

struct GrowthBar: Codable, Identifiable, Sendable {
    var id: String { canonicalName }
    let canonicalName: String
    let oldScore: Double
    let newScore: Double
    let delta: Double
    let oldBand: String?
    let newBand: String?
    let bandShift: String?
}

struct RecalibrationGrowth: Codable, Sendable {
    let growthBars: [GrowthBar]
    let biggestJump: GrowthBar?
    let newGaps: [String]
    let summary: String
}

struct RecalibrationResultsDTO: Decodable, Sendable {
    let recalibrationGrowth: RecalibrationGrowth?
    let previousAttemptId: String?
    let insights: DiagnosticInsightsDTO?
}

// MARK: - Endpoints

private enum PlanEndpoints: Endpoint {
    case status
    case current

    var path: String {
        switch self {
        case .status:  return "/plan/status"
        case .current: return "/plan/current"
        }
    }

    var method: HTTPMethod { .get }
}
