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
