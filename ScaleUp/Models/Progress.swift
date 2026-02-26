import Foundation

// MARK: - ContentProgress

struct ContentProgress: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let contentId: ProgressContentRef
    let currentPosition: Double
    let totalDuration: Double
    let percentageCompleted: Double
    let isCompleted: Bool
    let completedAt: String?
    let totalTimeSpent: Double?
    let lastSessionAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, contentId
        case currentPosition, totalDuration
        case percentageCompleted, isCompleted, completedAt
        case totalTimeSpent, lastSessionAt
    }
}

// MARK: - ProgressContentRef

/// Flexible ref: in history responses contentId is a populated object,
/// in update responses it's a plain ObjectId string.
enum ProgressContentRef: Codable, Hashable {
    case populated(ProgressContent)
    case id(String)

    var contentIdString: String {
        switch self {
        case .populated(let content): return content.id
        case .id(let id): return id
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let content = try? container.decode(ProgressContent.self) {
            self = .populated(content)
        } else if let id = try? container.decode(String.self) {
            self = .id(id)
        } else {
            throw DecodingError.typeMismatch(
                ProgressContentRef.self,
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

// MARK: - ProgressContent

/// Content data populated in history responses.
struct ProgressContent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let thumbnailURL: String?
    let domain: String?
    let duration: Int?
    let sourceType: SourceType?
    let youtubeVideoId: String?
    let creatorId: CreatorOrId?

    var resolvedThumbnailURL: String? {
        if sourceType == .youtube, let videoId = youtubeVideoId, !videoId.isEmpty {
            return "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg"
        }
        return thumbnailURL
    }

    var creator: ContentCreator {
        creatorId?.resolved ?? ContentCreator(id: "", firstName: "Unknown", lastName: "Creator", username: nil, profilePicture: nil)
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, thumbnailURL, domain, duration
        case sourceType, youtubeVideoId, creatorId
    }
}

// MARK: - ProgressStats

struct ProgressStats: Codable, Hashable {
    let totalContentConsumed: Int
    let totalTimeSpent: Double
    let dominantTopics: [String]
    let topicCount: Int
    let topicBreakdown: [ProgressTopicBreakdown]
}

// MARK: - ProgressTopicBreakdown

struct ProgressTopicBreakdown: Codable, Hashable {
    let topic: String
    let contentConsumed: Int
    let affinityScore: Double
}
