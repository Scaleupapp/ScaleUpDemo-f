import Foundation

// MARK: - LEGACY V1 — slated for removal
/// **DEPRECATED — Legacy V1 surface.** Only consumed by v1 Progress/Journey VMs.
/// v2 uses `V2LearnViewModel.knowledgeService` paths instead.
/// Scheduled for removal after 2026-06-15. See LEGACY_V1.md.
@available(*, deprecated, message: "Legacy V1 — see LEGACY_V1.md")
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
