import Foundation

// MARK: - Content

struct Content: Codable, Identifiable, Hashable {
    let id: String
    let creatorId: CreatorOrId?
    let title: String
    let description: String?
    let contentType: ContentType
    let contentURL: String
    let thumbnailURL: String?
    let duration: Int?
    let sourceType: SourceType
    let sourceAttribution: SourceAttribution?
    /// YouTube video ID sent by the backend for youtube-sourced content.
    let backendYoutubeVideoId: String?
    let domain: String
    let topics: [String]
    let tags: [String]
    let difficulty: Difficulty
    let aiData: AIData?
    let status: ContentStatus
    let publishedAt: String?
    let viewCount: Int
    let likeCount: Int
    let commentCount: Int
    let saveCount: Int
    let averageRating: Double
    let ratingCount: Int
    let recommendationScore: Double?
    let createdAt: String
    let updatedAt: String

    /// Non-optional accessor with fallback for unpopulated or null creatorId.
    var creator: ContentCreator {
        creatorId?.resolved ?? ContentCreator(id: "", firstName: "Unknown", lastName: "Creator", username: nil, profilePicture: nil)
    }

    /// Resolved thumbnail URL that prefers YouTube CDN for YouTube-sourced content,
    /// falling back to the original thumbnailURL for non-YouTube content.
    /// Always uses YouTube CDN (S3 thumbnails may not be publicly accessible).
    var resolvedThumbnailURL: String? {
        if sourceType == .youtube, let videoId = youtubeVideoId {
            return "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg"
        }
        return thumbnailURL
    }

    /// Returns the YouTube video ID, preferring the backend-provided value, then extracting from contentURL.
    var youtubeVideoId: String? {
        guard sourceType == .youtube else { return nil }

        // Prefer the backend-provided video ID
        if let backendId = backendYoutubeVideoId, !backendId.isEmpty {
            return backendId
        }

        guard let url = URL(string: contentURL) else {
            // Direct video ID (no URL structure)
            if !contentURL.contains("/") && !contentURL.contains(".") {
                return contentURL
            }
            return nil
        }

        // S3 bucket URL: .../youtube/{VIDEO_ID}/...
        if let idx = url.pathComponents.firstIndex(of: "youtube"),
           url.pathComponents.count > idx + 1 {
            return url.pathComponents[idx + 1]
        }

        // youtube.com/watch?v=VIDEO_ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoId
        }

        // youtu.be/VIDEO_ID
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.last
        }

        // youtube.com/embed/VIDEO_ID
        if url.pathComponents.contains("embed"),
           let idx = url.pathComponents.firstIndex(of: "embed"),
           url.pathComponents.count > idx + 1 {
            return url.pathComponents[idx + 1]
        }

        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case creatorId, title, description, contentType
        case contentURL, thumbnailURL, duration
        case sourceType, sourceAttribution
        case backendYoutubeVideoId = "youtubeVideoId"
        case domain, topics, tags, difficulty
        case aiData, status, publishedAt
        case viewCount, likeCount, commentCount, saveCount
        case averageRating, ratingCount
        case recommendationScore = "_recommendationScore"
        case createdAt, updatedAt
    }
}

// MARK: - SourceType

enum SourceType: String, Codable, Hashable {
    case original
    case youtube
}

// MARK: - ContentCreator

struct ContentCreator: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let username: String?
    let profilePicture: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, username, profilePicture
    }
}

// MARK: - CreatorOrId

/// Handles MongoDB's dual format: creatorId can be a populated object or a raw ObjectId string.
enum CreatorOrId: Codable, Hashable {
    case object(ContentCreator)
    case stringId(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try decoding as ContentCreator first
        if let creator = try? container.decode(ContentCreator.self) {
            self = .object(creator)
        } else if let id = try? container.decode(String.self) {
            self = .stringId(id)
        } else {
            self = .stringId("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let creator):
            try container.encode(creator)
        case .stringId(let id):
            try container.encode(id)
        }
    }

    /// Resolved creator, falling back to "Unknown Creator" when only an ID string is available.
    var resolved: ContentCreator {
        switch self {
        case .object(let creator):
            return creator
        case .stringId(let id):
            return ContentCreator(id: id, firstName: "Unknown", lastName: "Creator", username: nil, profilePicture: nil)
        }
    }
}

// MARK: - SourceAttribution

struct SourceAttribution: Codable, Hashable {
    let platform: String?
    let originalCreatorName: String?
    let originalCreatorUrl: String?
    let originalContentUrl: String?
    let importDisclaimer: String?
}

// MARK: - AIData

struct AIData: Codable, Hashable {
    let summary: String?
    let keyConcepts: [KeyConcept]?
    let prerequisites: [String]?
    let qualityScore: Double?
    let autoTags: [String]?
}

// MARK: - KeyConcept

struct KeyConcept: Codable, Hashable {
    let concept: String
    let description: String?
    let timestamp: String?
    let importance: Int?
}
