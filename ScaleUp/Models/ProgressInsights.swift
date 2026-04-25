import Foundation

// MARK: - Top-level response from GET /progress/insights

struct ProgressInsightsResponse: Decodable, Sendable {
    let state: InsightsState
    let cards: [InsightCard]
    let objective: InsightObjectiveSummary?
    let generatedAt: String?
    let cacheTtlSeconds: Int?

    enum InsightsState: String, Decodable, Sendable {
        case coldStart = "cold_start"
        case idle
        case active
    }
}

// MARK: - One card the UI renders directly

struct InsightCard: Decodable, Identifiable, Sendable {
    let id: String
    let kind: InsightKind
    let icon: String        // SF Symbol name from the backend
    let tone: InsightTone
    let title: String
    let body: String
    let metric: InsightMetric?
    let cta: InsightCTA?

    enum InsightKind: String, Decodable, Sendable {
        case momentum, objective, attention, milestone
        case coldStart = "cold_start"
    }

    enum InsightTone: String, Decodable, Sendable {
        case positive, neutral, caution, celebration
    }
}

struct InsightMetric: Decodable, Sendable {
    let label: String
    let value: String
    let delta: String?
}

struct InsightCTA: Decodable, Sendable {
    let label: String
    let deeplink: String?   // e.g. "scaleup://topic/system-design"
}

// MARK: - Optional objective summary (used by future Where-You're-Heading detail UI)

struct InsightObjectiveSummary: Decodable, Sendable {
    let hasObjective: Bool
    let objectiveType: String?
    let label: String?
    let targetDate: String?
    let daysToTarget: Int?
    let readinessPct: Int?
    let weekDelta: Int?
}
