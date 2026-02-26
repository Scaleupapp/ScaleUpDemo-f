import Foundation

// MARK: - Social Endpoints

enum SocialEndpoints {

    // MARK: - Request Bodies

    struct CreatePlaylistBody: Encodable {
        let title: String
        let description: String?
        let isPublic: Bool
    }

    struct UpdatePlaylistBody: Encodable {
        let name: String?
        let description: String?
        let isPublic: Bool?
    }

    struct AddToPlaylistBody: Encodable {
        let contentId: String
    }

    // MARK: - Follow / Unfollow

    static func follow(userId: String) -> Endpoint {
        .post("/social/follow/\(userId)")
    }

    static func unfollow(userId: String) -> Endpoint {
        .delete("/social/follow/\(userId)")
    }

    // MARK: - Followers / Following

    static func followers(userId: String, page: Int? = nil, limit: Int? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return .get("/social/followers/\(userId)", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func following(userId: String, page: Int? = nil, limit: Int? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return .get("/social/following/\(userId)", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    // MARK: - Comments

    static func deleteComment(id: String) -> Endpoint {
        .delete("/social/comments/\(id)")
    }

    // MARK: - Playlists

    static func createPlaylist(name: String, description: String? = nil, isPublic: Bool = true) -> Endpoint {
        .post("/social/playlists", body: CreatePlaylistBody(title: name, description: description, isPublic: isPublic))
    }

    static func listPlaylists() -> Endpoint {
        .get("/social/playlists")
    }

    static func getPlaylist(id: String) -> Endpoint {
        .get("/social/playlists/\(id)")
    }

    static func updatePlaylist(id: String, name: String? = nil, description: String? = nil, isPublic: Bool? = nil) -> Endpoint {
        .put("/social/playlists/\(id)", body: UpdatePlaylistBody(name: name, description: description, isPublic: isPublic))
    }

    static func deletePlaylist(id: String) -> Endpoint {
        .delete("/social/playlists/\(id)")
    }

    static func addToPlaylist(playlistId: String, contentId: String) -> Endpoint {
        .post("/social/playlists/\(playlistId)/items", body: AddToPlaylistBody(contentId: contentId))
    }

    static func removeFromPlaylist(playlistId: String, contentId: String) -> Endpoint {
        .delete("/social/playlists/\(playlistId)/items/\(contentId)")
    }
}
