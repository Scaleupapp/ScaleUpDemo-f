import Foundation

// MARK: - Diagnostic DTOs

struct DiagnosticAttemptStart: Decodable, Sendable {
    let attemptId: String
    let flowType: String          // "new_user" | "existing_user_tune"
    let competenciesToAssess: [DiagnosticCompetency]
}

struct DiagnosticCompetency: Decodable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let questionCap: Int
}

struct DiagnosticQuestion: Decodable, Identifiable, Sendable {
    let id: String                // questionId from backend
    let competency: String
    let difficulty: String        // "easy" | "medium" | "hard"
    let prompt: String
    let options: [DiagnosticOption]

    enum CodingKeys: String, CodingKey {
        case id = "_id", competency, difficulty, prompt, options
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
