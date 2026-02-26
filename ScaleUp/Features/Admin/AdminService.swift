import Foundation

// MARK: - Admin Stats Response

struct AdminStatsResponse: Codable {
    let totalUsers: Int
    let totalContent: Int
    let totalCreators: Int
    let activeJourneys: Int
}

// MARK: - Admin Service

/// Service layer wrapping admin-related API calls.
final class AdminService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Stats

    /// Fetches platform-wide admin statistics.
    func stats() async throws -> AdminStatsResponse {
        let response: AdminStatsResponse = try await apiClient.request(
            AdminEndpoints.stats()
        )
        return response
    }

    // MARK: - Users

    /// Fetches a paginated list of users with optional filters.
    func users(page: Int? = nil, limit: Int? = nil, role: String? = nil, search: String? = nil) async throws -> PaginatedData<User> {
        let response: PaginatedData<User> = try await apiClient.request(
            AdminEndpoints.users(page: page, limit: limit, role: role, search: search)
        )
        return response
    }

    // MARK: - Ban

    /// Bans a user by ID.
    func ban(userId: String) async throws {
        try await apiClient.requestVoid(
            AdminEndpoints.ban(userId: userId)
        )
    }

    // MARK: - Unban

    /// Unbans a user by ID.
    func unban(userId: String) async throws {
        try await apiClient.requestVoid(
            AdminEndpoints.unban(userId: userId)
        )
    }

    // MARK: - Applications

    /// Fetches a paginated list of creator applications.
    func applications(page: Int? = nil, limit: Int? = nil) async throws -> PaginatedData<CreatorApplication> {
        let response: PaginatedData<CreatorApplication> = try await apiClient.request(
            AdminEndpoints.applications(page: page, limit: limit)
        )
        return response
    }

    // MARK: - Reject Application

    /// Rejects a creator application by ID with an optional review note.
    func rejectApplication(id: String, reviewNote: String? = nil) async throws {
        try await apiClient.requestVoid(
            AdminEndpoints.rejectApplication(id: id, reviewNote: reviewNote)
        )
    }

    // MARK: - Moderate Content

    /// Moderates a content item by setting its status with an optional note.
    func moderateContent(id: String, status: String, note: String? = nil) async throws {
        try await apiClient.requestVoid(
            AdminEndpoints.moderateContent(id: id, status: status, note: note)
        )
    }
}
