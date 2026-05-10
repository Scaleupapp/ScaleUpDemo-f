import Foundation

// MARK: - Plan DTOs
//
// PlanCurrent / PlanWeeklyEntry / PlanAllocation / PlanMilestone are
// generated from openapi.yaml — see ScaleUp/Generated/OpenAPI/. Don't
// hand-roll equivalents here; if the wire shape changes, update the
// backend's openapi.yaml and run scripts/regenerate-openapi-types.sh.

/// Type alias to keep older view-model code referring to the historic name
/// while the underlying type comes from the spec.
typealias PlanDTO = APIPlanCurrent

struct PlanStatusDTO: Decodable, Sendable {
    let status: String
    let planId: String?
}

// MARK: - Plan Service

actor PlanService {
    static let shared = PlanService()

    private let api = APIClient.shared

    func fetchStatus() async throws -> PlanStatusDTO {
        try await api.request(PlanEndpoints.status)
    }

    func fetchCurrent() async throws -> APIPlanCurrent {
        try await api.request(PlanEndpoints.current)
    }

    func fetchMastery() async throws -> APIPlanMastery {
        try await api.request(PlanEndpoints.mastery)
    }

    /// POSTs `/plan/tasks/{taskId}/complete` with a self-rating (1...5) for
    /// `.manual` and `.externalLink` task types. Returns the generated
    /// completion result data block (taskId / planId / weekNumber).
    @discardableResult
    func markTaskComplete(
        taskId: String,
        selfRating: Int
    ) async throws -> APIMarkPlanTaskComplete200ResponseAllOfData {
        struct Body: Encodable, Sendable {
            let selfRating: Int
        }
        return try await api.request(
            PlanEndpoints.markTaskComplete(taskId: taskId),
            body: Body(selfRating: selfRating)
        )
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
    case mastery
    case markTaskComplete(taskId: String)

    var path: String {
        switch self {
        case .status:  return "/plan/status"
        case .current: return "/plan/current"
        case .mastery: return "/plan/mastery"
        case .markTaskComplete(let taskId):
            return "/plan/tasks/\(taskId)/complete"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .status, .current, .mastery: return .get
        case .markTaskComplete:           return .post
        }
    }
}
