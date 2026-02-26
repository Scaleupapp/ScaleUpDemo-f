import Foundation

// MARK: - Search Service

/// Service layer wrapping search API calls.
final class SearchService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Search Content

    /// Searches content by query with optional filters.
    func searchContent(
        query: String,
        domain: String? = nil,
        difficulty: String? = nil,
        page: Int? = nil,
        limit: Int? = nil
    ) async throws -> PaginatedData<Content> {
        let response: PaginatedData<Content> = try await apiClient.requestFlatPaginated(
            ContentEndpoints.explore(
                domain: domain,
                difficulty: difficulty,
                search: query,
                page: page,
                limit: limit
            )
        )
        return response
    }

    // MARK: - Search Creators

    /// Searches for creators.
    func searchCreators() async throws -> [CreatorProfile] {
        let response: [CreatorProfile] = try await apiClient.request(
            CreatorEndpoints.searchCreators()
        )
        return response
    }
}
