import Foundation

// MARK: - Content Service

/// Service layer wrapping content-related API calls.
final class ContentService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Feed

    /// Fetches the user's personalized content feed.
    func getFeed() async throws -> [Content] {
        let response: [Content] = try await apiClient.request(
            ContentEndpoints.feed()
        )
        return response
    }

    // MARK: - Explore

    /// Browses content with optional filters.
    /// Backend returns a plain array in `data`, not paginated format.
    func explore(
        domain: String? = nil,
        difficulty: String? = nil,
        search: String? = nil,
        creatorId: String? = nil,
        page: Int? = nil,
        limit: Int? = nil
    ) async throws -> [Content] {
        let response: [Content] = try await apiClient.request(
            ContentEndpoints.explore(
                domain: domain,
                difficulty: difficulty,
                search: search,
                creatorId: creatorId,
                page: page,
                limit: limit
            )
        )
        return response
    }

    // MARK: - Get Content

    /// Fetches a single content item by ID.
    func getContent(id: String) async throws -> Content {
        let response: Content = try await apiClient.request(
            ContentEndpoints.getContent(id: id)
        )
        return response
    }

    // MARK: - Liked Content

    /// Fetches the user's liked content list.
    func likedContent(page: Int? = nil, limit: Int? = nil) async throws -> [Content] {
        let response: [Content] = try await apiClient.request(
            ContentEndpoints.likedContent(page: page, limit: limit)
        )
        return response
    }

    // MARK: - Saved Content

    /// Fetches the user's saved/bookmarked content list.
    func savedContent(page: Int? = nil, limit: Int? = nil) async throws -> [Content] {
        let response: [Content] = try await apiClient.request(
            ContentEndpoints.savedContent(page: page, limit: limit)
        )
        return response
    }

    // MARK: - Like

    /// Toggles a like on content.
    func like(id: String) async throws {
        try await apiClient.requestVoid(
            ContentEndpoints.like(id: id)
        )
    }

    // MARK: - Save

    /// Toggles a save/bookmark on content.
    func save(id: String) async throws {
        try await apiClient.requestVoid(
            ContentEndpoints.save(id: id)
        )
    }

    // MARK: - Rate

    /// Rates a content item.
    func rate(id: String, value: Int) async throws {
        try await apiClient.requestVoid(
            ContentEndpoints.rate(id: id, value: value)
        )
    }

    // MARK: - Comments

    /// Fetches comments for a content item.
    ///
    /// The backend returns `{ data: { comments: [...], pagination: {...} } }` rather than
    /// the standard `{ data: { items: [...], pagination: {...} } }`, so we decode into
    /// `CommentsResponseData` and map it to `PaginatedData<Comment>` for callers.
    func getComments(id: String, page: Int? = nil, limit: Int? = nil) async throws -> PaginatedData<Comment> {
        let response: CommentsResponseData = try await apiClient.request(
            ContentEndpoints.getComments(id: id, page: page, limit: limit)
        )
        return PaginatedData(items: response.comments, pagination: response.pagination)
    }

    /// Adds a comment to a content item.
    func addComment(id: String, text: String, parentId: String? = nil) async throws -> Comment {
        let response: Comment = try await apiClient.request(
            ContentEndpoints.addComment(id: id, text: text, parentId: parentId)
        )
        return response
    }

    // MARK: - Stream URL

    /// Fetches a presigned S3 stream URL for the given content.
    func getStreamUrl(id: String) async throws -> String {
        let response: StreamURLResponse = try await apiClient.request(
            ContentEndpoints.streamUrl(id: id)
        )
        return response.url
    }
}

// MARK: - Stream URL Response

private struct StreamURLResponse: Decodable {
    let url: String
}
