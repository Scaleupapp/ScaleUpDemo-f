import Foundation

actor KnowledgeService {
    private let api = APIClient.shared

    func getProfile() async throws -> FullKnowledgeProfile {
        try await api.request(KnowledgeEndpoints.profile)
    }

    func getTopicDetail(topic: String) async throws -> TopicMasteryEntry {
        try await api.request(KnowledgeEndpoints.topic(name: topic))
    }

    func getGaps() async throws -> [KnowledgeGap] {
        try await api.request(KnowledgeEndpoints.gaps)
    }

    func getStrengths() async throws -> [KnowledgeSnapshot] {
        try await api.request(KnowledgeEndpoints.strengths)
    }

    func getConsumptionStats() async throws -> ConsumptionStats {
        try await api.request(ProgressEndpoints.stats)
    }

    func getHistory(page: Int = 1, limit: Int = 20) async throws -> [ContentProgress] {
        try await api.request(ProgressEndpoints.history(page: page, limit: limit))
    }

    func getActivityHeatmap(days: Int = 90) async throws -> [ActivityDay] {
        try await api.request(ProgressEndpoints.activityHeatmap(days: days))
    }

    func getTimeline(limit: Int = 20) async throws -> [TimelineEvent] {
        try await api.request(ProgressEndpoints.timeline(limit: limit))
    }
}

// MARK: - Knowledge Endpoints

private enum KnowledgeEndpoints: Endpoint {
    case profile
    case topic(name: String)
    case gaps
    case strengths

    var path: String {
        switch self {
        case .profile: return "/knowledge/profile"
        case .topic(let name): return "/knowledge/topic/\(name)"
        case .gaps: return "/knowledge/gaps"
        case .strengths: return "/knowledge/strengths"
        }
    }

    var method: HTTPMethod { .get }
}

// MARK: - Progress Endpoints

private enum ProgressEndpoints: Endpoint {
    case stats
    case history(page: Int, limit: Int)
    case activityHeatmap(days: Int)
    case timeline(limit: Int)

    var path: String {
        switch self {
        case .stats: return "/progress/stats"
        case .history: return "/progress/history"
        case .activityHeatmap: return "/progress/activity-heatmap"
        case .timeline: return "/progress/timeline"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .history(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .activityHeatmap(let days):
            return [URLQueryItem(name: "days", value: "\(days)")]
        case .timeline(let limit):
            return [URLQueryItem(name: "limit", value: "\(limit)")]
        default:
            return nil
        }
    }
}
