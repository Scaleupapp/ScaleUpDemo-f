import Foundation

/// Capstone wire types — mirror backend `/api/coding/capstones/*` shapes.
/// Hand-rolled rather than using the generated `APICapstone*` types because
/// the SwiftUI views want a flat, ergonomic shape (the generator emits
/// Inner / FilesInner companion types that don't compose well).

enum CapstoneSessionStatus: String, Codable, Sendable, CaseIterable {
    case scheduled
    case provisioning
    case ready
    case in_progress
    case paused
    case submitted
    case evaluating
    case graded
    case aborted
    case expired

    /// Display label for the mobile Live screen status badge.
    var displayLabel: String {
        switch self {
        case .scheduled:    return "Scheduled"
        case .provisioning: return "Setting up your laptop session…"
        case .ready:        return "Ready — open the laptop"
        case .in_progress:  return "In progress"
        case .paused:       return "Paused"
        case .submitted:    return "Submitted"
        case .evaluating:   return "Grading…"
        case .graded:       return "Graded"
        case .aborted:      return "Aborted"
        case .expired:      return "Time up"
        }
    }
}

struct CapstoneLibraryEntry: Codable, Sendable, Identifiable {
    let bundleId: String
    let brief: String
    let difficulty: DrillDifficulty
    let roleTrack: RoleTrack
    let timeBudgetMinutes: Int
    let language: String
    let stackVariant: String?
    let interviewParallel: String?
    let alreadyCompleted: Bool

    var id: String { bundleId }

    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case brief
        case difficulty
        case roleTrack = "role_track"
        case timeBudgetMinutes = "time_budget_minutes"
        case language
        case stackVariant = "stack_variant"
        case interviewParallel = "interview_parallel"
        case alreadyCompleted = "already_completed"
    }
}

struct CapstoneStartResponse: Codable, Sendable {
    let sessionId: String
    let status: CapstoneSessionStatus
    let pairingCode: String
    let expiresAt: Date
    let timeBudgetSeconds: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case pairingCode = "pairing_code"
        case expiresAt = "expires_at"
        case timeBudgetSeconds = "time_budget_seconds"
    }
}

struct CapstoneSessionCounters: Codable, Sendable {
    var filesChanged: Int?
    var compassTurns: Int?
    var testsRun: Int?
    var testsPassing: Int?
    var testsTotal: Int?

    enum CodingKeys: String, CodingKey {
        case filesChanged = "files_changed"
        case compassTurns = "compass_turns"
        case testsRun = "tests_run"
        case testsPassing = "tests_passing"
        case testsTotal = "tests_total"
    }
}

struct CapstoneSessionView: Codable, Sendable {
    let sessionId: String
    let status: CapstoneSessionStatus
    let sandboxHostUrl: String?
    let startedAt: Date?
    let timeBudgetSeconds: Int
    let pausedTotalSeconds: Int
    let counters: CapstoneSessionCounters?
    /// The learner-visible bundle projection — present on GET /:id/status so a
    /// resumed session can rebuild the live screen without a separate fetch.
    let bundle: GeneratedBundleView?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case sandboxHostUrl = "sandbox_host_url"
        case startedAt = "started_at"
        case timeBudgetSeconds = "time_budget_seconds"
        case pausedTotalSeconds = "paused_total_seconds"
        case counters
        case bundle
    }
}

enum CapstoneControlAction: String, Codable {
    case pause, resume, abort, submit
}

struct CapstoneControlRequest: Codable {
    let action: CapstoneControlAction
}

struct CapstoneDimensionScores: Codable, Sendable, Hashable {
    let correctness: Double
    let codeQuality: Double
    let aiPairEffectiveness: Double
    let verificationDiscipline: Double
    let decomposition: Double
    let reflectionQuality: Double

    enum CodingKeys: String, CodingKey {
        case correctness
        case codeQuality = "code_quality"
        case aiPairEffectiveness = "ai_pair_effectiveness"
        case verificationDiscipline = "verification_discipline"
        case decomposition
        case reflectionQuality = "reflection_quality"
    }
}

/// Per-dimension narrative (grading-transparency). Forward-only — older graded
/// sessions won't have these, so every field is optional.
struct CapstoneDimensionFeedbackEntry: Codable, Sendable, Hashable {
    let why: String?
    let toImprove: String?

    enum CodingKeys: String, CodingKey {
        case why
        case toImprove = "to_improve"
    }
}

struct CapstoneDimensionFeedback: Codable, Sendable, Hashable {
    let correctness: CapstoneDimensionFeedbackEntry?
    let codeQuality: CapstoneDimensionFeedbackEntry?
    let aiPairEffectiveness: CapstoneDimensionFeedbackEntry?
    let verificationDiscipline: CapstoneDimensionFeedbackEntry?
    let decomposition: CapstoneDimensionFeedbackEntry?
    let reflectionQuality: CapstoneDimensionFeedbackEntry?

    enum CodingKeys: String, CodingKey {
        case correctness
        case codeQuality = "code_quality"
        case aiPairEffectiveness = "ai_pair_effectiveness"
        case verificationDiscipline = "verification_discipline"
        case decomposition
        case reflectionQuality = "reflection_quality"
    }
}

/// Weight (0..1) each dimension contributes to overall_score — snapshotted on
/// the result so the UI can show "Correctness · 25%".
struct CapstoneRubricWeights: Codable, Sendable, Hashable {
    let correctness: Double?
    let codeQuality: Double?
    let aiPairEffectiveness: Double?
    let verificationDiscipline: Double?
    let decomposition: Double?
    let reflectionQuality: Double?

    enum CodingKeys: String, CodingKey {
        case correctness
        case codeQuality = "code_quality"
        case aiPairEffectiveness = "ai_pair_effectiveness"
        case verificationDiscipline = "verification_discipline"
        case decomposition
        case reflectionQuality = "reflection_quality"
    }
}

/// Deterministic visible/hidden test split behind the correctness score —
/// explains "I did well but scored low" (hidden edge-case tests failing).
struct CapstoneTestSummary: Codable, Sendable, Hashable {
    let visiblePassed: Int?
    let visibleTotal: Int?
    let hiddenPassed: Int?
    let hiddenTotal: Int?
    let lintPassed: Bool?

    enum CodingKeys: String, CodingKey {
        case visiblePassed = "visible_passed"
        case visibleTotal = "visible_total"
        case hiddenPassed = "hidden_passed"
        case hiddenTotal = "hidden_total"
        case lintPassed = "lint_passed"
    }
}

struct CapstoneResult: Codable, Sendable {
    let overallScore: Int
    let dimensionScores: CapstoneDimensionScores
    let dimensionFeedback: CapstoneDimensionFeedback?
    let overallRationale: String?
    let testSummary: CapstoneTestSummary?
    let rubricWeights: CapstoneRubricWeights?
    let strengths: [String]
    let gaps: [String]
    let interviewParallel: String?
    let integrityConfidence: String
    let anchorDriftDetected: Bool?
    let gradedAt: Date?
    let bundleId: String?
    let isRetry: Bool?
    let evidenceNotes: String?

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case dimensionScores = "dimension_scores"
        case dimensionFeedback = "dimension_feedback"
        case overallRationale = "overall_rationale"
        case testSummary = "test_summary"
        case rubricWeights = "rubric_weights"
        case strengths
        case gaps
        case interviewParallel = "interview_parallel"
        case integrityConfidence = "integrity_confidence"
        case anchorDriftDetected = "anchor_drift_detected"
        case gradedAt = "graded_at"
        case bundleId = "bundle_id"
        case isRetry = "is_retry"
        case evidenceNotes = "evidence_notes"
    }

    /// One presentational row per dimension, in rubric order, joining score +
    /// weight + feedback so the result view can iterate cleanly.
    struct DimensionRow: Identifiable {
        let id: String          // snake_case key (RubricBar formats it)
        let score: Double       // 0..10
        let weightPct: Int?     // e.g. 25
        let why: String?
        let toImprove: String?
    }

    var dimensionRows: [DimensionRow] {
        func pct(_ w: Double?) -> Int? { w.map { Int(($0 * 100).rounded()) } }
        return [
            DimensionRow(id: "correctness", score: dimensionScores.correctness,
                         weightPct: pct(rubricWeights?.correctness),
                         why: dimensionFeedback?.correctness?.why,
                         toImprove: dimensionFeedback?.correctness?.toImprove),
            DimensionRow(id: "code_quality", score: dimensionScores.codeQuality,
                         weightPct: pct(rubricWeights?.codeQuality),
                         why: dimensionFeedback?.codeQuality?.why,
                         toImprove: dimensionFeedback?.codeQuality?.toImprove),
            DimensionRow(id: "ai_pair_effectiveness", score: dimensionScores.aiPairEffectiveness,
                         weightPct: pct(rubricWeights?.aiPairEffectiveness),
                         why: dimensionFeedback?.aiPairEffectiveness?.why,
                         toImprove: dimensionFeedback?.aiPairEffectiveness?.toImprove),
            DimensionRow(id: "verification_discipline", score: dimensionScores.verificationDiscipline,
                         weightPct: pct(rubricWeights?.verificationDiscipline),
                         why: dimensionFeedback?.verificationDiscipline?.why,
                         toImprove: dimensionFeedback?.verificationDiscipline?.toImprove),
            DimensionRow(id: "decomposition", score: dimensionScores.decomposition,
                         weightPct: pct(rubricWeights?.decomposition),
                         why: dimensionFeedback?.decomposition?.why,
                         toImprove: dimensionFeedback?.decomposition?.toImprove),
            DimensionRow(id: "reflection_quality", score: dimensionScores.reflectionQuality,
                         weightPct: pct(rubricWeights?.reflectionQuality),
                         why: dimensionFeedback?.reflectionQuality?.why,
                         toImprove: dimensionFeedback?.reflectionQuality?.toImprove),
        ]
    }
}

struct CapstoneFlaggedMoment: Codable, Sendable, Identifiable {
    let tSeconds: Int
    let label: String
    let detail: String?
    let severity: String?

    var id: String { "\(tSeconds)-\(label)" }

    enum CodingKeys: String, CodingKey {
        case tSeconds = "t_seconds"
        case label, detail, severity
    }
}

struct CapstoneReplaySnapshot: Codable, Sendable, Identifiable {
    let tSeconds: Int
    let snapshotUrl: String

    var id: Int { tSeconds }

    enum CodingKeys: String, CodingKey {
        case tSeconds = "t_seconds"
        case snapshotUrl = "snapshot_url"
    }
}

struct CapstoneReplay: Codable, Sendable {
    let sessionId: String
    let eventStreamUrl: String
    let durationSeconds: Int
    let snapshots: [CapstoneReplaySnapshot]
    let flaggedMoments: [CapstoneFlaggedMoment]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case eventStreamUrl = "event_stream_url"
        case durationSeconds = "duration_seconds"
        case snapshots
        case flaggedMoments = "flagged_moments"
    }
}

/// Response from POST /capstones/:id/rejoin — a fresh pairing code + QR
/// the user can use to reconnect the laptop mid-session.
struct CapstoneRejoinResponse: Codable, Identifiable, Sendable {
    let sessionId: String
    let pairingCode: String
    let expiresAt: Date

    /// Identifiable conformance keyed on pairingCode so each new code
    /// triggers a fresh sheet presentation.
    var id: String { pairingCode }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case pairingCode = "pairing_code"
        case expiresAt = "expires_at"
    }
}

/// Errors the service layer can throw — mapped to learner-readable strings
/// by the view-model layer.
enum CapstoneServiceError: Error, Sendable {
    case sessionNotFound
    case notACapstone
    case noCodingTrackForObjective
    case pairingCodeInvalid
    case pairingCodeExpired
    case pairingCodeUsed
    case invalidTransition(currentStatus: String?)
    case reflectionAlreadyRecorded
    case sessionNotGraded(currentStatus: String?)
    case stillEvaluating
    case notResumable(currentStatus: String?)
}

// MARK: - History

struct CapstoneHistoryResponse: Codable, Sendable {
    let items: [CapstoneHistoryItem]
    let pagination: CapstonePagination
    let stats: CapstoneHistoryStats
    let weeklySeries: [CapstoneWeeklyPoint]

    enum CodingKeys: String, CodingKey {
        case items, pagination, stats
        case weeklySeries = "weekly_series"
    }
}

struct CapstoneHistoryItem: Codable, Sendable, Identifiable {
    let sessionId: String
    let bundleId: String?
    let bundleBriefPreview: String
    let difficulty: String?
    let roleTrack: String?
    let timeBudgetMinutes: Int?
    let overallScore: Int?
    let dimensionScores: CapstoneDimensionScores?
    let integrityConfidence: String?
    let gradedAt: Date?
    let isRetry: Bool

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case bundleId = "bundle_id"
        case bundleBriefPreview = "bundle_brief_preview"
        case difficulty
        case roleTrack = "role_track"
        case timeBudgetMinutes = "time_budget_minutes"
        case overallScore = "overall_score"
        case dimensionScores = "dimension_scores"
        case integrityConfidence = "integrity_confidence"
        case gradedAt = "graded_at"
        case isRetry = "is_retry"
    }
}

struct CapstonePagination: Codable, Sendable {
    let total: Int
    let limit: Int
    let offset: Int
    let returned: Int
}

struct CapstoneHistoryStats: Codable, Sendable {
    let totalAttempts: Int
    let bestScore: Int?
    let meanScore: Int?
    let currentDifficulty: String?
    let roleTrack: String?

    enum CodingKeys: String, CodingKey {
        case totalAttempts = "total_attempts"
        case bestScore = "best_score"
        case meanScore = "mean_score"
        case currentDifficulty = "current_difficulty"
        case roleTrack = "role_track"
    }
}

struct CapstoneWeeklyPoint: Codable, Sendable, Identifiable {
    let weekIndexFromEnd: Int
    let count: Int
    let meanScore: Int?

    var id: Int { weekIndexFromEnd }

    enum CodingKeys: String, CodingKey {
        case weekIndexFromEnd = "week_index_from_end"
        case count
        case meanScore = "mean_score"
    }
}

// MARK: - Generator (Phase 3)

/// Poll envelope for an async capstone-generation request.
/// status: queued | generating | validating | cross_checking | ready | failed
struct CapstoneGenerationStatus: Codable, Sendable {
    let requestId: String
    let status: String
    let roleTrack: String?
    let difficulty: String?
    let attempts: Int?
    let error: String?
    let bundle: GeneratedBundleView?

    var isTerminal: Bool { status == "ready" || status == "failed" }

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case status
        case roleTrack = "role_track"
        case difficulty
        case attempts
        case error
        case bundle
    }
}

/// One of the learner's recent on-demand generation requests (for the hub's
/// "Your generated capstones" strip — submit-and-walk-away UX).
struct CapstoneGenerationSummary: Codable, Sendable, Identifiable {
    let requestId: String
    let status: String   // queued | generating | validating | cross_checking | ready | failed
    let difficulty: String?
    let roleTrack: String?
    let bundleId: String?
    let briefPreview: String?
    let error: String?

    var id: String { requestId }

    var isTerminal: Bool { status == "ready" || status == "failed" }
    var isBuilding: Bool { !isTerminal }

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case status
        case difficulty
        case roleTrack = "role_track"
        case bundleId = "bundle_id"
        case briefPreview = "brief_preview"
        case error
    }
}

// MARK: - Tracks (Phase 4, auto-assembled)

struct CapstoneTrackResponse: Codable, Sendable {
    let enrolled: Bool
    let reason: String?
    let title: String?
    let roleTrack: String?
    let currentStep: Int?
    let totalSteps: Int?
    let completed: Bool?
    let steps: [CapstoneTrackStep]?

    enum CodingKeys: String, CodingKey {
        case enrolled, reason, title
        case roleTrack = "role_track"
        case currentStep = "current_step"
        case totalSteps = "total_steps"
        case completed, steps
    }
}

struct CapstoneTrackStep: Codable, Sendable, Identifiable {
    let index: Int
    let bundleId: String
    let difficulty: String?
    let briefPreview: String
    let status: String // locked | active | completed
    let overallScore: Int?

    var id: Int { index }

    enum CodingKeys: String, CodingKey {
        case index
        case bundleId = "bundle_id"
        case difficulty
        case briefPreview = "brief_preview"
        case status
        case overallScore = "overall_score"
    }
}

/// The preview-safe projection returned when a generation is ready. Mirrors the
/// backend projectBundle(); enough to launch Preflight.
struct GeneratedBundleView: Codable, Sendable {
    let bundleId: String
    let brief: String
    let timeBudgetMinutes: Int
    let difficulty: String
    let roleTrack: String
    let language: String
    let stackVariant: String?
    let interviewParallel: String?

    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case brief
        case timeBudgetMinutes = "time_budget_minutes"
        case difficulty
        case roleTrack = "role_track"
        case language
        case stackVariant = "stack_variant"
        case interviewParallel = "interview_parallel"
    }

    /// Convert to a library entry so it can flow into CapstonePreflightView.
    func toLibraryEntry() -> CapstoneLibraryEntry {
        CapstoneLibraryEntry(
            bundleId: bundleId,
            brief: brief,
            difficulty: DrillDifficulty(rawValue: difficulty) ?? .medium,
            roleTrack: RoleTrack(rawValue: roleTrack) ?? .swe,
            timeBudgetMinutes: timeBudgetMinutes,
            language: language,
            stackVariant: stackVariant,
            interviewParallel: interviewParallel,
            alreadyCompleted: false
        )
    }
}
