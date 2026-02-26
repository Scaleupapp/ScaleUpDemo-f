import Foundation

// MARK: - Creator Service

/// Service layer wrapping creator-related API calls.
final class CreatorService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Apply

    /// Submits a creator application.
    func apply(motivation: String? = nil, expertise: [String]? = nil, portfolio: String? = nil) async throws {
        try await apiClient.requestVoid(
            CreatorEndpoints.apply(motivation: motivation, expertise: expertise, portfolio: portfolio)
        )
    }

    // MARK: - Application Status

    /// Checks the status of the user's creator application.
    func applicationStatus() async throws -> CreatorApplication {
        let response: CreatorApplication = try await apiClient.request(
            CreatorEndpoints.applicationStatus()
        )
        return response
    }

    // MARK: - Search

    /// Searches for creators. Returns user objects with nested creator profiles.
    func search() async throws -> [CreatorSearchResult] {
        let response: [CreatorSearchResult] = try await apiClient.request(
            CreatorEndpoints.searchCreators()
        )
        return response
    }

    // MARK: - Profile

    /// Fetches the current user's creator profile.
    func profile() async throws -> CreatorProfile {
        let response: CreatorProfile = try await apiClient.request(
            CreatorEndpoints.profile()
        )
        return response
    }

    // MARK: - Update Profile

    /// Updates the creator's profile.
    func updateProfile(bio: String? = nil, expertise: [String]? = nil, socialLinks: [String: String]? = nil) async throws -> CreatorProfile {
        let response: CreatorProfile = try await apiClient.request(
            CreatorEndpoints.updateProfile(bio: bio, expertise: expertise, socialLinks: socialLinks)
        )
        return response
    }
}
