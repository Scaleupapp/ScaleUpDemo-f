import Foundation

// MARK: - YouTube Endpoints

enum YouTubeEndpoints {

    // MARK: - Request Bodies

    struct ImportVideoBody: Encodable {
        let videoUrl: String
    }

    struct ImportChannelBody: Encodable {
        let channelUrl: String
    }

    struct ImportPlaylistBody: Encodable {
        let playlistUrl: String
    }

    struct ImportHistoryBody: Encodable {
        let historyData: String
    }

    // MARK: - Endpoints

    static func importVideo(videoUrl: String) -> Endpoint {
        .post("/youtube/import/video", body: ImportVideoBody(videoUrl: videoUrl))
    }

    static func importChannel(channelUrl: String) -> Endpoint {
        .post("/youtube/import/channel", body: ImportChannelBody(channelUrl: channelUrl))
    }

    static func importPlaylist(playlistUrl: String) -> Endpoint {
        .post("/youtube/import/playlist", body: ImportPlaylistBody(playlistUrl: playlistUrl))
    }

    static func search(query: String, maxResults: Int? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "query", value: query)]
        if let maxResults { queryItems.append(URLQueryItem(name: "maxResults", value: String(maxResults))) }

        return .get("/youtube/search", queryItems: queryItems)
    }

    static func importHistory(historyData: String) -> Endpoint {
        .post("/youtube/import/history", body: ImportHistoryBody(historyData: historyData))
    }
}
