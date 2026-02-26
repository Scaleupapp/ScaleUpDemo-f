import Foundation

// MARK: - Comment

struct Comment: Codable, Identifiable, Hashable {
    let id: String
    let userId: CommentUser
    let contentId: String
    let text: String
    let parentId: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, contentId, text, parentId, createdAt
    }
}

// MARK: - CommentUser

struct CommentUser: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let profilePicture: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, profilePicture
    }
}

// MARK: - Playlist

struct Playlist: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let isPublic: Bool
    let items: [PlaylistItem]
    let itemCount: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, title, description
        case isPublic, items, itemCount, createdAt
    }
}

// MARK: - PlaylistItem

struct PlaylistItem: Codable, Identifiable, Hashable {
    /// When populated, this is the full Content object; when not, just the ObjectId string.
    let contentId: PlaylistContentRef
    let order: Int?
    let addedAt: String?

    var id: String { contentId.id }
}

/// Flexible ref that decodes either a populated Content-like object or a plain ObjectId string.
enum PlaylistContentRef: Codable, Hashable {
    case populated(PlaylistContent)
    case id(String)

    var id: String {
        switch self {
        case .populated(let content): return content.id
        case .id(let id): return id
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let content = try? container.decode(PlaylistContent.self) {
            self = .populated(content)
        } else if let id = try? container.decode(String.self) {
            self = .id(id)
        } else {
            throw DecodingError.typeMismatch(
                PlaylistContentRef.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected String or Object for contentId")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .populated(let content): try container.encode(content)
        case .id(let id): try container.encode(id)
        }
    }
}

/// Lightweight content data returned when playlist items are populated.
struct PlaylistContent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let domain: String?
    let thumbnailURL: String?
    let duration: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, domain, thumbnailURL, duration
    }
}

// MARK: - LearningPath

struct LearningPath: Codable, Identifiable, Hashable {
    let id: String
    let creatorId: String
    let title: String
    let description: String?
    let domain: String
    let topics: [String]
    let difficulty: Difficulty
    let items: [LearningPathItem]
    let isPublished: Bool
    let followerCount: Int
    let averageRating: Double
    let ratingCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case creatorId, title, description
        case domain, topics, difficulty
        case items, isPublished
        case followerCount, averageRating, ratingCount
        case createdAt
    }
}

// MARK: - LearningPathItem

struct LearningPathItem: Codable, Hashable {
    let contentId: String
    let order: Int
}
