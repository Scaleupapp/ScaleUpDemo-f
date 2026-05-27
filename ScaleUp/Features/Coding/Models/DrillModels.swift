import Foundation

// MARK: - Drill subtype enum

enum DrillSubtype: String, Codable, Sendable, CaseIterable {
    case prompt
    case verify
    case decompose
    case refactor   // present in backend but never served in Phase A (filtered server-side)

    var displayName: String {
        switch self {
        case .prompt:    return "Prompt"
        case .verify:    return "Bug Hunt"
        case .decompose: return "Decompose"
        case .refactor:  return "Refactor"
        }
    }

    var iconName: String {
        switch self {
        case .prompt:    return "text.bubble"
        case .verify:    return "magnifyingglass"
        case .decompose: return "list.number"
        case .refactor:  return "arrow.triangle.2.circlepath"
        }
    }
}

enum DrillDifficulty: String, Codable, Sendable {
    case easy, medium, hard
}

enum RoleTrack: String, Codable, Sendable {
    case swe
    case ds
    case ai_eng = "ai_eng"
}

// MARK: - GET /api/coding/drills/today response

struct DrillTodayResponse: Codable, Sendable {
    let bundleId: String
    let brief: String
    let timeBudgetMinutes: Int
    let drillSubtype: DrillSubtype
    let difficulty: DrillDifficulty
    let roleTrack: RoleTrack
    let language: String
    let acceptanceCriteria: [String]?
    let starterRepo: StarterRepo?  // only present for refactor drills (which we don't serve)

    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case brief
        case timeBudgetMinutes = "time_budget_minutes"
        case drillSubtype = "drill_subtype"
        case difficulty
        case roleTrack = "role_track"
        case language
        case acceptanceCriteria = "acceptance_criteria"
        case starterRepo = "starter_repo"
    }
}

struct StarterRepo: Codable, Sendable {
    let files: [FileNode]
}

struct FileNode: Codable, Sendable {
    let path: String
    let content: String
}

// MARK: - POST /api/coding/drills/:id/start response

struct DrillStartResponse: Codable, Sendable {
    let attemptId: String
    let bundleId: String
    let brief: String
    let timeBudgetMinutes: Int
    let drillSubtype: DrillSubtype
    let difficulty: DrillDifficulty
    let roleTrack: RoleTrack
    let language: String
    let acceptanceCriteria: [String]?
    let starterRepo: StarterRepo?
    let visibleTests: [TestSpec]?  // only refactor

    enum CodingKeys: String, CodingKey {
        case attemptId = "attempt_id"
        case bundleId = "bundle_id"
        case brief
        case timeBudgetMinutes = "time_budget_minutes"
        case drillSubtype = "drill_subtype"
        case difficulty
        case roleTrack = "role_track"
        case language
        case acceptanceCriteria = "acceptance_criteria"
        case starterRepo = "starter_repo"
        case visibleTests = "visible_tests"
    }
}

struct TestSpec: Codable, Sendable {
    let name: String
    let command: String
}

// MARK: - POST /api/coding/drills/request body

struct DrillRequestBody: Codable, Sendable {
    let drillSubtype: DrillSubtype?
    let difficulty: DrillDifficulty?
    let topicHint: String?

    enum CodingKeys: String, CodingKey {
        case drillSubtype = "drill_subtype"
        case difficulty
        case topicHint = "topic_hint"
    }
}

// MARK: - DrillStartResponse → DrillTodayResponse bridge

extension DrillStartResponse {
    /// Convert a /drills/request response (DrillStartResponse) to the DrillTodayResponse
    /// shape used by DrillSession. Used by the "Practice another" and Compass action card flows.
    func toTodayResponse() -> DrillTodayResponse {
        DrillTodayResponse(
            bundleId: self.bundleId,
            brief: self.brief,
            timeBudgetMinutes: self.timeBudgetMinutes,
            drillSubtype: self.drillSubtype,
            difficulty: self.difficulty,
            roleTrack: self.roleTrack,
            language: self.language,
            acceptanceCriteria: self.acceptanceCriteria,
            starterRepo: self.starterRepo
        )
    }
}

// MARK: - POST /api/coding/drills/:id/submit body + response

struct DrillSubmitBody: Codable, Sendable {
    let drillSubtype: DrillSubtype
    let submission: DrillSubmission

    enum CodingKeys: String, CodingKey {
        case drillSubtype = "drill_subtype"
        case submission
    }
}

/// Tagged-union of per-subtype submission shapes.
/// Encodes/decodes to one of:
///   { prompt_text: String }
///   { bug_locations: [BugLocation] }
///   { decomposition_steps: [DecompositionStep] }
///   { refactored_code: { files: [FileNode] } }
enum DrillSubmission: Codable, Sendable {
    case prompt(text: String)
    case verify(bugLocations: [BugLocation])
    case decompose(steps: [DecompositionStep])
    case refactor(files: [FileNode])

    private struct PromptBody: Codable { let prompt_text: String }
    private struct VerifyBody: Codable { let bug_locations: [BugLocation] }
    private struct DecomposeBody: Codable { let decomposition_steps: [DecompositionStep] }
    private struct RefactorBody: Codable { let refactored_code: RefactoredCodeWrapper }
    private struct RefactoredCodeWrapper: Codable { let files: [FileNode] }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .prompt(let text):
            try container.encode(PromptBody(prompt_text: text))
        case .verify(let bugs):
            try container.encode(VerifyBody(bug_locations: bugs))
        case .decompose(let steps):
            try container.encode(DecomposeBody(decomposition_steps: steps))
        case .refactor(let files):
            try container.encode(RefactorBody(refactored_code: .init(files: files)))
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Best-effort decoding; in practice we always encode, never decode this type.
        if let p = try? container.decode(PromptBody.self) {
            self = .prompt(text: p.prompt_text); return
        }
        if let v = try? container.decode(VerifyBody.self) {
            self = .verify(bugLocations: v.bug_locations); return
        }
        if let d = try? container.decode(DecomposeBody.self) {
            self = .decompose(steps: d.decomposition_steps); return
        }
        if let r = try? container.decode(RefactorBody.self) {
            self = .refactor(files: r.refactored_code.files); return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unrecognized DrillSubmission shape"
        )
    }
}

struct BugLocation: Codable, Sendable, Identifiable, Hashable {
    var id: UUID = UUID()
    var file: String
    var line: Int
    var explanation: String

    enum CodingKeys: String, CodingKey {
        case file, line, explanation
    }
}

struct DecompositionStep: Codable, Sendable, Identifiable, Hashable {
    var id: UUID = UUID()
    var step: String
    var rationale: String

    enum CodingKeys: String, CodingKey {
        case step, rationale
    }
}

struct DrillSubmitResponse: Codable, Sendable {
    let attemptId: String
    let status: String  // "submitted"
    let pollUrl: String

    enum CodingKeys: String, CodingKey {
        case attemptId = "attempt_id"
        case status
        case pollUrl = "poll_url"
    }
}

// MARK: - GET /api/coding/drills/:id/result response (200 or 202)

/// 202 response (still grading)
struct DrillResultPendingResponse: Codable, Sendable {
    let attemptId: String
    let status: String  // 'in_progress' | 'submitted'

    enum CodingKeys: String, CodingKey {
        case attemptId = "attempt_id"
        case status
    }
}

/// A single item in the `what_you_missed` array of a graded result.
struct WhatYouMissedItem: Codable, Sendable, Identifiable, Hashable {
    let title: String
    let detail: String
    let reference: String?

    // Synthesize id for ForEach — title is expected to be unique within a result.
    var id: String { title + (reference ?? "") }
}

/// 200 response (graded)
struct DrillResultGradedResponse: Codable, Sendable {
    let attemptId: String
    let status: String  // 'graded'
    let overallScore: Int
    let rubricBreakdown: [RubricItem]
    let whatToTryNext: String?
    let whatYouMissed: [WhatYouMissedItem]?  // NEW — nil/absent treated as empty on render
    let integrityConfidence: String?
    let gradedAt: String?
    let drillSubtype: DrillSubtype
    let difficulty: DrillDifficulty
    let roleTrack: RoleTrack

    enum CodingKeys: String, CodingKey {
        case attemptId = "attempt_id"
        case status
        case overallScore = "overall_score"
        case rubricBreakdown = "rubric_breakdown"
        case whatToTryNext = "what_to_try_next"
        case whatYouMissed = "what_you_missed"
        case integrityConfidence = "integrity_confidence"
        case gradedAt = "graded_at"
        case drillSubtype = "drill_subtype"
        case difficulty
        case roleTrack = "role_track"
    }
}

struct RubricItem: Codable, Sendable, Hashable {
    let dimension: String
    let score: Double
    let feedback: String?
}

// MARK: - Calibration

struct CalibrationStartResponse: Codable, Sendable {
    let calibrationId: String
    let roleTrack: RoleTrack
    let estimatedMinutes: Int
    let drills: [CalibrationDrill]

    enum CodingKeys: String, CodingKey {
        case calibrationId = "calibration_id"
        case roleTrack = "role_track"
        case estimatedMinutes = "estimated_minutes"
        case drills
    }
}

struct CalibrationDrill: Codable, Sendable {
    let drillSubtype: DrillSubtype
    let attemptId: String
    let bundleId: String
    let brief: String
    let timeBudgetMinutes: Int

    enum CodingKeys: String, CodingKey {
        case drillSubtype = "drill_subtype"
        case attemptId = "attempt_id"
        case bundleId = "bundle_id"
        case brief
        case timeBudgetMinutes = "time_budget_minutes"
    }
}

struct CalibrationSubmitBody: Codable, Sendable {
    let submissions: [CalibrationDrillSubmission]
}

struct CalibrationDrillSubmission: Codable, Sendable {
    let drillSubtype: DrillSubtype
    let attemptId: String
    let submission: DrillSubmission

    enum CodingKeys: String, CodingKey {
        case drillSubtype = "drill_subtype"
        case attemptId = "attempt_id"
        case submission
    }
}

struct CalibrationSubmitResponse: Codable, Sendable {
    let calibrationId: String
    let status: String
    let pollUrl: String?

    enum CodingKeys: String, CodingKey {
        case calibrationId = "calibration_id"
        case status
        case pollUrl = "poll_url"
    }
}

struct CalibrationResultResponse: Codable, Sendable {
    let calibrationId: String
    let status: String  // 'pending' | 'partial' | 'graded'
    let drills: [CalibrationDrillResult]?
    let baselineAxes: BaselineAxes?
    let recommendedDifficulty: DrillDifficulty?

    enum CodingKeys: String, CodingKey {
        case calibrationId = "calibration_id"
        case status
        case drills
        case baselineAxes = "baseline_axes"
        case recommendedDifficulty = "recommended_difficulty"
    }
}

struct CalibrationDrillResult: Codable, Sendable {
    let drillSubtype: DrillSubtype
    let status: String
    let overallScore: Int?
    let rubricBreakdown: [RubricItem]?
    let whatYouMissed: [WhatYouMissedItem]?  // NEW — matches the regular drill result shape

    enum CodingKeys: String, CodingKey {
        case drillSubtype = "drill_subtype"
        case status
        case overallScore = "overall_score"
        case rubricBreakdown = "rubric_breakdown"
        case whatYouMissed = "what_you_missed"
    }
}

struct BaselineAxes: Codable, Sendable {
    let prompting: Double
    let verification: Double
    let decomposition: Double
    let refactoring: Double  // 0 in Phase A
}

// MARK: - DrillContext

/// Minimal drill data that all per-subtype input views need.
/// Lets both `DrillSession` (regular) and `CalibrationSession`
/// feed the same 3 input views without those views touching the session.
struct DrillContext: Sendable {
    let brief: String
    let drillSubtype: DrillSubtype
    let language: String?
    let timeBudgetMinutes: Int
    let acceptanceCriteria: [String]?

    init(from drill: DrillTodayResponse) {
        self.brief = drill.brief
        self.drillSubtype = drill.drillSubtype
        self.language = drill.language
        self.timeBudgetMinutes = drill.timeBudgetMinutes
        self.acceptanceCriteria = drill.acceptanceCriteria
    }

    init(from cal: CalibrationDrill) {
        self.brief = cal.brief
        self.drillSubtype = cal.drillSubtype
        self.language = nil
        self.timeBudgetMinutes = cal.timeBudgetMinutes
        self.acceptanceCriteria = nil
    }
}
