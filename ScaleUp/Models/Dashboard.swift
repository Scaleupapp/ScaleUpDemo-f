import Foundation

// MARK: - DashboardResponse

struct DashboardResponse: Codable, Hashable, Sendable {
    let objectives: [Objective]
    let readinessScore: Int
    let knowledgeProfile: KnowledgeProfile?
    let journey: JourneySummary?
    let weeklyStats: WeeklyStats
    let nextActions: [NextAction]
    let upcomingMilestones: [Milestone]
    let pendingQuizzes: Int
}

// MARK: - JourneySummary

struct JourneySummary: Codable, Hashable, Sendable {
    let title: String
    let currentPhase: String?
    let currentWeek: Int
    let progress: JourneyProgress
    let streak: Int?

    /// Maps the free-form phase string to a JourneyPhase enum when possible.
    var phase: JourneyPhase {
        guard let currentPhase else { return .foundation }
        return JourneyPhase(rawValue: currentPhase) ?? .foundation
    }
}

// MARK: - WeeklyStats

struct WeeklyStats: Codable, Hashable, Sendable {
    let contentConsumed: Int
    let totalContentConsumed: Int
    let dominantTopics: [String]
}

// MARK: - NextAction

struct NextAction: Codable, Hashable, Sendable {
    let type: String
    let message: String
    let data: [String: AnyCodableValue]?
}

// MARK: - AnyCodableValue

/// A type-erased Codable value for handling dynamic JSON fields.
enum AnyCodableValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyCodableValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyCodableValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
