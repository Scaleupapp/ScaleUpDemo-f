import Foundation

actor RecommendationService {
    private let api = APIClient.shared

    func getNextActions() async throws -> NextActionsResponse {
        try await api.request(RecommendationEndpoints.nextActions)
    }

    func getGapContent(limit: Int = 10) async throws -> [Content] {
        try await api.request(RecommendationEndpoints.gaps(limit: limit))
    }

    func getTrending(limit: Int = 10) async throws -> [Content] {
        try await api.request(RecommendationEndpoints.trending(limit: limit))
    }
}

// MARK: - Endpoints

private enum RecommendationEndpoints: Endpoint {
    case nextActions
    case gaps(limit: Int)
    case trending(limit: Int)

    var path: String {
        switch self {
        case .nextActions: return "/recommendations/next-actions"
        case .gaps: return "/recommendations/gaps"
        case .trending: return "/recommendations/trending"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .gaps(let limit), .trending(let limit):
            return [URLQueryItem(name: "limit", value: "\(limit)")]
        default:
            return nil
        }
    }
}
