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

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case sandboxHostUrl = "sandbox_host_url"
        case startedAt = "started_at"
        case timeBudgetSeconds = "time_budget_seconds"
        case pausedTotalSeconds = "paused_total_seconds"
        case counters
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

struct CapstoneResult: Codable, Sendable {
    let overallScore: Int
    let dimensionScores: CapstoneDimensionScores
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
}
