import Foundation

// MARK: - Codable Models

/// A row returned by GET /api/v2/me/assessments — one assessment + the student's session (if any).
struct PlacementAssessmentRow: Codable, Identifiable {
    let assessment: PlacementAssessment
    let session: PlacementSessionLite?
    let windowClosed: Bool?

    var id: String { assessment.id }
}

/// Flattened Assessment document (only fields needed for the take-flow).
struct PlacementAssessment: Codable, Identifiable {
    let id: String
    let type: String          // "mcq" | "capstone" | "interview" | "drill"
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
    // Wave 3 (additive): timed-assessment window. `deadlineAt` is the absolute
    // ISO time at which the take auto-submits; `durationSeconds` is its length.
    let deadlineAt: String?
    let durationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case status, result, deadlineAt, durationSeconds
    }
}

struct PlacementSessionResult: Codable {
    let score: Double?
    let integrity: String?
    let raw: PlacementResultRaw?
    // Wave 3 (additive): the score is being human-reviewed before it's final.
    let needsReview: Bool?
    // Wave 3 (additive): "insufficient" == not enough evidence to grade.
    let gradeStatus: String?
}

struct PlacementResultRaw: Codable {
    // MCQ
    let competencyBreakdown: [String: Double]?
    // Interview
    let dimensions: [PlacementResultDimension]?
    // Capstone
    let dimensionScores: [PlacementResultDimension]?
    // Drill
    let rubricBreakdown: [RubricItem]?      // RubricItem from DrillModels
    let whatYouMissed: [WhatYouMissedItem]? // WhatYouMissedItem from DrillModels

    enum CodingKeys: String, CodingKey {
        case competencyBreakdown = "competency_breakdown"
        case dimensions
        case dimensionScores = "dimension_scores"
        case rubricBreakdown = "rubric_breakdown"
        case whatYouMissed = "what_you_missed"
    }
}

struct PlacementResultDimension: Codable, Identifiable {
    var id: String { name }
    let name: String
    let score: Double?
    let feedback: String?
}

// MARK: - Review

/// Response shape from GET /api/v2/me/assessments/sessions/:sessionId/review
struct PlacementReviewResponse: Codable {
    let windowClosed: Bool
    let score: Double?
    let engineType: String?
    let questions: [PlacementReviewQuestion]
}

struct PlacementReviewQuestion: Codable, Identifiable {
    let index: Int
    let questionText: String
    let scenario: String?
    let options: [PlacementReviewOption]
    let correctAnswer: String?
    let explanation: String?
    let studentAnswer: String?
    let isCorrect: Bool?

    var id: Int { index }
}

struct PlacementReviewOption: Codable {
    let label: String
    let text: String
}

// MARK: - Start Result

/// Response shape from POST /api/v2/me/assessments/:id/start
struct AssessmentStartResult: Codable {
    let assessmentSessionId: String
    let engine: AssessmentEngine
    let meta: AssessmentMeta?
    // Wave 3 (additive): timed-assessment deadline for this session. May arrive
    // either at the top level or nested under `meta` depending on engine — read
    // via `effectiveDeadlineAt`.
    let deadlineAt: String?
    let durationSeconds: Int?

    /// Deadline to enforce on the take surface, tolerant of either nesting.
    var effectiveDeadlineAt: String? { deadlineAt ?? meta?.deadlineAt }
}

struct AssessmentEngine: Codable {
    let type: String          // "mcq" | "capstone" | "interview" | "drill"
    let sessionId: String?    // interview / capstone / drill engine session id (attemptId for drill)
    let quizId: String?       // mcq only
    let bundleId: String?     // drill only — the DrillBundle id
}

struct AssessmentMeta: Codable {
    let systemInstruction: String?
    // Capstone fields
    let pairingCode: String?
    let expiresAt: String?
    let timeBudgetSeconds: Int?
    // Drill fields (from safeBundleView)
    let brief: String?
    let acceptanceCriteria: [String]?
    let drillSubtype: String?
    let timeBudgetMinutes: Int?
    let starterRepo: StarterRepo?  // StarterRepo is defined in DrillModels.swift
    // Wave 3 (additive): some engines carry the deadline in meta.
    let deadlineAt: String?
    let durationSeconds: Int?
}

// MARK: - Integrity Telemetry (Wave 3)

/// Snapshot body for POST /api/v2/me/assessments/sessions/:sessionId/integrity.
/// Cumulative (monotonic) counters — server clamps to max seen. Fields are
/// optional so a surface with no text input (MCQ / interview) omits `pasteCount`.
struct PlacementIntegritySnapshot: Codable {
    let appBackgroundedCount: Int?
    let focusLossSeconds: Int?
    let pasteCount: Int?
}

struct PlacementIntegrityResult: Codable {
    let integritySignals: PlacementIntegritySignals?
}

struct PlacementIntegritySignals: Codable {
    let flagged: Bool?
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

    // POST /api/v2/me/assessments/sessions/:sessionId/integrity
    // Idempotent cumulative snapshot of integrity counters. Best-effort:
    // callers wrap in `try?` — a 409 (NOT_IN_PROGRESS) once terminal is expected.
    @discardableResult
    func postIntegritySnapshot(
        sessionId: String,
        snapshot: PlacementIntegritySnapshot
    ) async throws -> PlacementIntegrityResult {
        let resp: V2APIResponse<PlacementIntegrityResult> = try await V2APIClient.shared.post(
            "/me/assessments/sessions/\(sessionId)/integrity",
            body: snapshot
        )
        return resp.data
    }

    // GET /api/v2/me/assessments/sessions/:sessionId/review
    func fetchReview(sessionId: String) async throws -> PlacementReviewResponse {
        let resp: V2APIResponse<PlacementReviewResponse> = try await V2APIClient.shared.get(
            "/me/assessments/sessions/\(sessionId)/review"
        )
        return resp.data
    }

    // POST /api/coding/drills/:attemptId/submit
    func submitPlacementDrill(attemptId: String, body: DrillSubmitBody) async throws -> DrillSubmitResponse {
        try await V2APIClient.shared.postCoding("/drills/\(attemptId)/submit", body: body)
    }

    // GET /api/coding/drills/:attemptId/result (200 = graded, 202 = pending)
    func pollPlacementDrillResult(attemptId: String) async throws -> DrillResultPoll {
        let (data, status) = try await V2APIClient.shared.rawCodingData(method: "GET", path: "/drills/\(attemptId)/result")
        if status == 200 {
            let graded = try JSONDecoder().decode(DrillResultGradedResponse.self, from: data)
            return .graded(graded)
        } else {
            let pending = try JSONDecoder().decode(DrillResultPendingResponse.self, from: data)
            return .pending(pending)
        }
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
