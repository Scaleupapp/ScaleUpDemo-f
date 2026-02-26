import Foundation

// MARK: - Social Service

/// Service layer wrapping social interaction API calls.
final class SocialService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Follow

    /// Follows another user.
    func follow(userId: String) async throws {
        try await apiClient.requestVoid(
            SocialEndpoints.follow(userId: userId)
        )
    }

    // MARK: - Unfollow

    /// Unfollows a user.
    func unfollow(userId: String) async throws {
        try await apiClient.requestVoid(
            SocialEndpoints.unfollow(userId: userId)
        )
    }

    // MARK: - Followers

    /// Fetches a user's followers list.
    func followers(userId: String, page: Int? = nil, limit: Int? = nil) async throws -> PaginatedData<PublicUser> {
        let response: PaginatedData<PublicUser> = try await apiClient.request(
            SocialEndpoints.followers(userId: userId, page: page, limit: limit)
        )
        return response
    }

    // MARK: - Following

    /// Fetches the list of users someone is following.
    func following(userId: String, page: Int? = nil, limit: Int? = nil) async throws -> PaginatedData<PublicUser> {
        let response: PaginatedData<PublicUser> = try await apiClient.request(
            SocialEndpoints.following(userId: userId, page: page, limit: limit)
        )
        return response
    }

    // MARK: - Playlists

    /// Fetches the user's playlists.
    func playlists() async throws -> [Playlist] {
        let response: [Playlist] = try await apiClient.request(
            SocialEndpoints.listPlaylists()
        )
        return response
    }

    // MARK: - Playlist CRUD

    /// Creates a new playlist.
    func createPlaylist(name: String, description: String?, isPublic: Bool) async throws -> Playlist {
        let response: Playlist = try await apiClient.request(
            SocialEndpoints.createPlaylist(name: name, description: description, isPublic: isPublic)
        )
        return response
    }

    /// Fetches a single playlist by ID.
    func getPlaylist(id: String) async throws -> Playlist {
        let response: Playlist = try await apiClient.request(
            SocialEndpoints.getPlaylist(id: id)
        )
        return response
    }

    /// Updates an existing playlist's metadata.
    func updatePlaylist(id: String, name: String?, description: String?, isPublic: Bool?) async throws -> Playlist {
        let response: Playlist = try await apiClient.request(
            SocialEndpoints.updatePlaylist(id: id, name: name, description: description, isPublic: isPublic)
        )
        return response
    }

    /// Deletes a playlist by ID.
    func deletePlaylist(id: String) async throws {
        try await apiClient.requestVoid(
            SocialEndpoints.deletePlaylist(id: id)
        )
    }

    /// Adds a content item to a playlist.
    func addToPlaylist(playlistId: String, contentId: String) async throws -> Playlist {
        let response: Playlist = try await apiClient.request(
            SocialEndpoints.addToPlaylist(playlistId: playlistId, contentId: contentId)
        )
        return response
    }

    /// Removes a content item from a playlist.
    func removeFromPlaylist(playlistId: String, contentId: String) async throws -> Playlist {
        let response: Playlist = try await apiClient.request(
            SocialEndpoints.removeFromPlaylist(playlistId: playlistId, contentId: contentId)
        )
        return response
    }
}
