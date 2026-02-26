import Foundation

// MARK: - Recommendation Service

/// Service layer wrapping recommendation-related API calls.
final class RecommendationService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Feed

    /// Fetches the personalized recommendation feed.
    func feed() async throws -> [RecommendedContent] {
        let response: [RecommendedContent] = try await apiClient.request(
            RecommendationEndpoints.feed()
        )
        return response
    }

    // MARK: - Similar

    /// Fetches content similar to the given content ID.
    /// Backend returns `{ items: [...] }` (paginated wrapper).
    func similar(id: String) async throws -> [RecommendedContent] {
        try await apiClient.requestPaginated(
            RecommendationEndpoints.similar(id: id)
        )
    }

    // MARK: - Gaps

    /// Fetches recommendations targeting knowledge gaps.
    /// Backend returns `{ items: [...] }` (paginated wrapper).
    func gaps() async throws -> [RecommendedContent] {
        try await apiClient.requestPaginated(
            RecommendationEndpoints.gaps()
        )
    }

    // MARK: - Trending

    /// Fetches trending content recommendations.
    /// Backend returns `{ items: [...] }` (paginated wrapper).
    func trending() async throws -> [RecommendedContent] {
        try await apiClient.requestPaginated(
            RecommendationEndpoints.trending()
        )
    }
}
