import Foundation

// MARK: - Codable Models

/// A row returned by GET /api/v2/me/assessments — one assessment + the student's session (if any).
struct PlacementAssessmentRow: Codable, Identifiable {
    let assessment: PlacementAssessment
    let session: PlacementSessionLite?

    var id: String { assessment.id }
}

/// Flattened Assessment document (only fields needed for the take-flow).
struct PlacementAssessment: Codable, Identifiable {
    let id: String
    let type: String          // "mcq" | "capstone" | "interview"
    let title: String
    let status: String?       // always "released" on list, but keep optional for tolerance
    let opensAt: String?      // ISO8601 string — backend uses Date but lean() returns string
    let closesAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type, title, status, opensAt, closesAt
    }
}

/// The student's own AssessmentSession (lightweight — just status + result).
struct PlacementSessionLite: Codable {
    let id: String?
    let status: String?       // "scheduled"|"in_progress"|"submitted"|"graded"|"expired"
    let result: PlacementSessionResult?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case status, result
    }
}

struct PlacementSessionResult: Codable {
    let score: Double?
    let integrity: String?
}

// MARK: - Start Result

/// Response shape from POST /api/v2/me/assessments/:id/start
struct AssessmentStartResult: Codable {
    let assessmentSessionId: String
    let engine: AssessmentEngine
    let meta: AssessmentMeta?
}

struct AssessmentEngine: Codable {
    let type: String          // "mcq" | "capstone" | "interview"
    let sessionId: String?    // interview / capstone engine session id
    let quizId: String?       // mcq only
}

struct AssessmentMeta: Codable {
    let systemInstruction: String?
    // Capstone fields
    let pairingCode: String?
    let expiresAt: String?
    let timeBudgetSeconds: Int?
}

// MARK: - Sync Result

/// Response shape from POST /api/v2/me/assessments/sessions/:sessionId/sync
struct AssessmentSyncResult: Codable {
    let status: String?
    let result: PlacementSessionResult?
}

// MARK: - API Service

/// Thin @MainActor service for placement assessment endpoints.
/// All networking goes through V2APIClient.shared (GET/POST /api/v2).
@MainActor
final class PlacementsAssessmentsApi {
    static let shared = PlacementsAssessmentsApi()
    private init() {}

    private struct _EmptyBody: Codable {}

    // GET /api/v2/me/assessments
    func listAssessments() async throws -> [PlacementAssessmentRow] {
        let resp: V2APIResponse<[PlacementAssessmentRow]> = try await V2APIClient.shared.get("/me/assessments")
        return resp.data
    }

    // POST /api/v2/me/assessments/:id/start
    func startAssessment(_ id: String) async throws -> AssessmentStartResult {
        let resp: V2APIResponse<AssessmentStartResult> = try await V2APIClient.shared.post(
            "/me/assessments/\(id)/start",
            body: _EmptyBody()
        )
        return resp.data
    }

    // POST /api/v2/me/assessments/sessions/:sessionId/sync
    func syncSession(_ sessionId: String) async throws -> AssessmentSyncResult {
        let resp: V2APIResponse<AssessmentSyncResult> = try await V2APIClient.shared.post(
            "/me/assessments/sessions/\(sessionId)/sync",
            body: _EmptyBody()
        )
        return resp.data
    }
}

// MARK: - V2APIError helpers (Placement assessment use)

extension V2APIError {
    /// Extracts the machine `code` string from a 4xx response body shaped:
    ///   { "success": false, "code": "NOT_OPEN", "message": "..." }
    /// Returns nil when no `code` key is present.
    func extractCode() -> String? {
        guard case .httpError(_, let data) = self else { return nil }
        struct CodeBody: Decodable { let code: String? }
        return (try? JSONDecoder().decode(CodeBody.self, from: data))?.code
    }
}
