import Foundation

// MARK: - Diagnostic DTOs

struct DiagnosticAttemptStart: Decodable, Sendable {
    let attemptId: String
    let flowType: String          // "new_user" | "recalibration"
    let competenciesToAssess: [DiagnosticCompetency]
    /// True when the backend already has self-ratings for every competency
    /// (captured during onboarding). Lets the client skip its self-rating
    /// screen instead of asking the user the same question twice.
    let selfRatingsAlreadyProvided: Bool?
}

struct DiagnosticCompetency: Decodable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String                // canonical slug, e.g. "quantitative-reasoning"
    let displayName: String?        // human-readable, e.g. "Quantitative Reasoning"
    let questionCap: Int
    /// Self-rating echoed from onboarding (canonical raw value: "novice" | …).
    /// Optional for older backends that didn't include it.
    let selfRating: String?

    /// Human-readable label for UI surfaces; falls back to a title-cased
    /// version of the canonical slug when the backend didn't provide one.
    var displayLabel: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return name
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

struct DiagnosticQuestion: Decodable, Identifiable, Sendable {
    let id: String                // questionId from backend
    let competency: String
    let difficulty: String        // "easy" | "medium" | "hard"
    let prompt: String
    let options: [DiagnosticOption]
    /// Canonical competency name used for voice scoring and topic
    /// transition logic. Optional defensively in case the wire omits it.
    let canonicalCompetency: String?
    /// Plan 3a: question type. V2 returns "voice" for voice-eligible
    /// questions. Optional / nil treated as standard MCQ.
    let type: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id", competency, difficulty, prompt, options, canonicalCompetency, type
    }
}

struct DiagnosticOption: Decodable, Identifiable, Hashable, Sendable {
    let id: String                // "A" | "B" | "C" | "D"
    let text: String

    enum CodingKeys: String, CodingKey {
        case id = "key", text
    }
}

struct DiagnosticNextQuestion: Decodable, Sendable {
    let question: DiagnosticQuestion?
    let done: Bool?
    /// Authoritative progress from the server — `total` is the real pool
    /// size, which the client trusts over any locally-estimated total.
    let progress: DiagnosticProgress?
}

struct DiagnosticProgress: Decodable, Sendable {
    let current: Int?
    let total: Int?
}

struct DiagnosticResults: Decodable, Sendable {
    let attemptId: String
    let perCompetency: [DiagnosticCompetencyResult]

    enum CodingKeys: String, CodingKey {
        case attemptId, perCompetency = "results"
    }
}

struct DiagnosticCompetencyResult: Decodable, Identifiable, Sendable {
    var id: String { competency }
    let competency: String
    let score: Int                // 0-100
    let band: String              // "novice"|"familiar"|"proficient"|"expert"
    let calibrationDelta: Int?    // selfRating - assessed
}

// MARK: - Self-Rating Enum

enum DiagnosticSelfRating: String, CaseIterable, Codable, Identifiable, Sendable {
    case novice, familiar, proficient, expert, unsure
    var id: String { rawValue }
    var displayLabel: String {
        switch self {
        case .novice:     return "I haven't worked with this"
        case .familiar:   return "I'm familiar"
        case .proficient: return "I'm proficient"
        case .expert:     return "I know this well"
        case .unsure:     return "Not sure"
        }
    }
}
