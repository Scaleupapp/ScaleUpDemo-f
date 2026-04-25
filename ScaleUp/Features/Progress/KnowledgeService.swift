import Foundation

actor KnowledgeService {
    private let api = APIClient.shared

    func getProfile(objectiveId: String? = nil) async throws -> FullKnowledgeProfile {
        try await api.request(KnowledgeEndpoints.profile(objectiveId: objectiveId))
    }

    func getTopicDetail(topic: String) async throws -> TopicMasteryEntry {
        try await api.request(KnowledgeEndpoints.topic(name: topic))
    }

    func getGaps(objectiveId: String? = nil) async throws -> [KnowledgeGap] {
        try await api.request(KnowledgeEndpoints.gaps(objectiveId: objectiveId))
    }

    func getStrengths(objectiveId: String? = nil) async throws -> [KnowledgeSnapshot] {
        try await api.request(KnowledgeEndpoints.strengths(objectiveId: objectiveId))
    }

    func getConsumptionStats(objectiveId: String? = nil) async throws -> ConsumptionStats {
        try await api.request(ProgressEndpoints.stats(objectiveId: objectiveId))
    }

    func getHistory(page: Int = 1, limit: Int = 20) async throws -> [ContentProgress] {
        try await api.request(ProgressEndpoints.history(page: page, limit: limit))
    }

    func getActivityHeatmap(days: Int = 90, objectiveId: String? = nil) async throws -> [ActivityDay] {
        try await api.request(ProgressEndpoints.activityHeatmap(days: days, objectiveId: objectiveId))
    }

    func getTimeline(limit: Int = 20, objectiveId: String? = nil) async throws -> [TimelineEvent] {
        try await api.request(ProgressEndpoints.timeline(limit: limit, objectiveId: objectiveId))
    }

    func getInsights(refresh: Bool = false) async throws -> ProgressInsightsResponse {
        try await api.request(ProgressEndpoints.insights(refresh: refresh))
    }
}

// MARK: - Knowledge Endpoints

private enum KnowledgeEndpoints: Endpoint {
    case profile(objectiveId: String?)
    case topic(name: String)
    case gaps(objectiveId: String?)
    case strengths(objectiveId: String?)

    var path: String {
        switch self {
        case .profile: return "/knowledge/profile"
        case .topic(let name): return "/knowledge/topic/\(name)"
        case .gaps: return "/knowledge/gaps"
        case .strengths: return "/knowledge/strengths"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .profile(let objectiveId), .gaps(let objectiveId), .strengths(let objectiveId):
            guard let objectiveId else { return nil }
            return [URLQueryItem(name: "objectiveId", value: objectiveId)]
        case .topic:
            return nil
        }
    }
}

// MARK: - Progress Endpoints

private enum ProgressEndpoints: Endpoint {
    case stats(objectiveId: String?)
    case history(page: Int, limit: Int)
    case activityHeatmap(days: Int, objectiveId: String?)
    case timeline(limit: Int, objectiveId: String?)
    case insights(refresh: Bool)

    var path: String {
        switch self {
        case .stats: return "/progress/stats"
        case .history: return "/progress/history"
        case .activityHeatmap: return "/progress/activity-heatmap"
        case .timeline: return "/progress/timeline"
        case .insights: return "/progress/insights"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .stats(let objectiveId):
            guard let objectiveId else { return nil }
            return [URLQueryItem(name: "objectiveId", value: objectiveId)]
        case .history(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .activityHeatmap(let days, let objectiveId):
            var items = [URLQueryItem(name: "days", value: "\(days)")]
            if let objectiveId { items.append(URLQueryItem(name: "objectiveId", value: objectiveId)) }
            return items
        case .timeline(let limit, let objectiveId):
            var items = [URLQueryItem(name: "limit", value: "\(limit)")]
            if let objectiveId { items.append(URLQueryItem(name: "objectiveId", value: objectiveId)) }
            return items
        case .insights(let refresh):
            return refresh ? [URLQueryItem(name: "refresh", value: "true")] : nil
        }
    }
}
