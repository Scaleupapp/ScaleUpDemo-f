import Foundation

// MARK: - Player Service

actor PlayerService {

    private let api = APIClient.shared

    // MARK: - Stream

    func fetchStreamURL(contentId: String) async throws -> StreamResponse {
        try await api.request(PlayerEndpoints.stream(id: contentId))
    }

    // MARK: - Progress

    func updateProgress(
        contentId: String,
        currentPosition: Int,
        totalDuration: Int,
        timeSpent: Int
    ) async throws -> ContentProgress {
        let body = ProgressUpdateRequest(
            currentPosition: currentPosition,
            totalDuration: totalDuration,
            timeSpent: timeSpent
        )
        return try await api.request(PlayerEndpoints.updateProgress(id: contentId), body: body)
    }

    func markComplete(contentId: String) async throws {
        _ = try await api.requestRaw(PlayerEndpoints.complete(id: contentId))
    }

    // MARK: - Comments

    func fetchComments(contentId: String, page: Int = 1) async throws -> CommentsResponse {
        try await api.request(PlayerEndpoints.comments(id: contentId, page: page))
    }

    func addComment(contentId: String, text: String, parentId: String? = nil) async throws -> Comment {
        let body = AddCommentRequest(text: text, parentId: parentId)
        return try await api.request(PlayerEndpoints.addComment(id: contentId), body: body)
    }

    // MARK: - Playlists

    func fetchMyPlaylists() async throws -> [Playlist] {
        try await api.request(PlayerEndpoints.myPlaylists)
    }

    func addToPlaylist(playlistId: String, contentId: String) async throws -> Playlist {
        let body = AddToPlaylistRequest(contentId: contentId)
        return try await api.request(PlayerEndpoints.addToPlaylist(playlistId: playlistId), body: body)
    }

    func createPlaylist(title: String, description: String? = nil) async throws -> Playlist {
        let body = CreatePlaylistRequest(title: title, description: description)
        return try await api.request(PlayerEndpoints.createPlaylist, body: body)
    }
}

// MARK: - Response Types

struct StreamResponse: Codable, Sendable {
    let streamURL: String?
    let url: String?

    var resolvedURL: String? { streamURL ?? url }
}

// MARK: - Request Bodies

private struct ProgressUpdateRequest: Encodable, Sendable {
    let currentPosition: Int
    let totalDuration: Int
    let timeSpent: Int
}

private struct AddCommentRequest: Encodable, Sendable {
    let text: String
    let parentId: String?
}

private struct AddToPlaylistRequest: Encodable, Sendable {
    let contentId: String
}

private struct CreatePlaylistRequest: Encodable, Sendable {
    let title: String
    let description: String?
}

// MARK: - Endpoints

private enum PlayerEndpoints: Endpoint {
    case stream(id: String)
    case updateProgress(id: String)
    case complete(id: String)
    case comments(id: String, page: Int)
    case addComment(id: String)
    case myPlaylists
    case addToPlaylist(playlistId: String)
    case createPlaylist

    var path: String {
        switch self {
        case .stream(let id): return "/content/\(id)/stream"
        case .updateProgress(let id): return "/progress/\(id)"
        case .complete(let id): return "/progress/\(id)/complete"
        case .comments(let id, _): return "/content/\(id)/comments"
        case .addComment(let id): return "/content/\(id)/comments"
        case .myPlaylists: return "/social/playlists"
        case .addToPlaylist(let id): return "/social/playlists/\(id)/items"
        case .createPlaylist: return "/social/playlists"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .stream, .comments, .myPlaylists: return .get
        case .updateProgress: return .put
        case .complete, .addComment, .addToPlaylist, .createPlaylist: return .post
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .comments(_, let page):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "20")
            ]
        default:
            return nil
        }
    }
}
