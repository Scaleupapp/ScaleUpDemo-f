import Foundation

// MARK: - User Service

/// Service layer wrapping user profile API calls.
final class UserService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Get Me

    /// Fetches the current authenticated user's profile.
    func getMe() async throws -> User {
        let response: User = try await apiClient.request(
            UserEndpoints.me()
        )
        return response
    }

    // MARK: - Update Me

    /// Updates the current user's profile.
    func updateMe(name: String? = nil, bio: String? = nil, phone: String? = nil, avatarUrl: String? = nil) async throws -> User {
        let response: User = try await apiClient.request(
            UserEndpoints.updateMe(name: name, bio: bio, phone: phone, avatarUrl: avatarUrl)
        )
        return response
    }

    // MARK: - Get User

    /// Fetches a public user profile by ID.
    func getUser(id: String) async throws -> PublicUser {
        let response: PublicUser = try await apiClient.request(
            UserEndpoints.getUser(id: id)
        )
        return response
    }
}
