import Foundation
import SwiftUI

// MARK: - Content Progress Info (from enriched backend responses)

struct ContentProgressInfo: Codable, Sendable, Hashable {
    let status: String?           // "not_started", "in_progress", "completed"
    let progressPercentage: Int?

    var isCompleted: Bool { status == "completed" }
    var isInProgress: Bool { status == "in_progress" }
}

// MARK: - Content

struct Content: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let creatorId: Creator?
    let title: String
    let description: String?
    let contentType: ContentType
    let contentURL: String?
    let thumbnailURL: String?
    let duration: Int? // seconds
    let sourceType: ContentSource?
    let sourceAttribution: SourceAttribution?
    let domain: String?
    let topics: [String]?
    let tags: [String]?
    let difficulty: Difficulty?
    let aiData: AIData?
    let status: ContentStatus?
    let viewCount: Int?
    let likeCount: Int?
    let commentCount: Int?
    let saveCount: Int?
    let averageRating: Double?
    let ratingCount: Int?
    let publishedAt: Date?
    let createdAt: Date?
    let reportCount: Int?
    let removalReason: String?
    let _progress: ContentProgressInfo?

    // Moderation
    let moderationStatus: String?

    // Notes-specific
    let pageCount: Int?
    let fileFormat: String?
    let collegeName: String?
    let ocrText: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case creatorId, title, description, contentType, contentURL, thumbnailURL
        case duration, sourceType, sourceAttribution, domain, topics, tags
        case difficulty, aiData, status, viewCount, likeCount, commentCount
        case saveCount, averageRating, ratingCount, publishedAt, createdAt
        case reportCount, removalReason, _progress, moderationStatus
        case pageCount, fileFormat, collegeName, ocrText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        contentType = try container.decode(ContentType.self, forKey: .contentType)
        contentURL = try container.decodeIfPresent(String.self, forKey: .contentURL)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        sourceType = try container.decodeIfPresent(ContentSource.self, forKey: .sourceType)
        sourceAttribution = try container.decodeIfPresent(SourceAttribution.self, forKey: .sourceAttribution)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        topics = try container.decodeIfPresent([String].self, forKey: .topics)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty)
        aiData = try container.decodeIfPresent(AIData.self, forKey: .aiData)
        status = try container.decodeIfPresent(ContentStatus.self, forKey: .status)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
        saveCount = try container.decodeIfPresent(Int.self, forKey: .saveCount)
        averageRating = try container.decodeIfPresent(Double.self, forKey: .averageRating)
        ratingCount = try container.decodeIfPresent(Int.self, forKey: .ratingCount)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        reportCount = try container.decodeIfPresent(Int.self, forKey: .reportCount)
        removalReason = try container.decodeIfPresent(String.self, forKey: .removalReason)
        _progress = try container.decodeIfPresent(ContentProgressInfo.self, forKey: ._progress)
        moderationStatus = try container.decodeIfPresent(String.self, forKey: .moderationStatus)
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount)
        fileFormat = try container.decodeIfPresent(String.self, forKey: .fileFormat)
        collegeName = try container.decodeIfPresent(String.self, forKey: .collegeName)
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)

        // creatorId can be either a string (ObjectId) or a populated Creator object
        if let creator = try? container.decodeIfPresent(Creator.self, forKey: .creatorId) {
            creatorId = creator
        } else if let creatorIdString = try? container.decodeIfPresent(String.self, forKey: .creatorId) {
            creatorId = Creator(id: creatorIdString, firstName: "Creator", lastName: nil, username: nil, profilePicture: nil, bio: nil, tier: nil, followersCount: nil, contentCount: nil, averageRating: nil)
        } else {
            creatorId = nil
        }
    }

    // Memberwise init for mock data
    init(id: String, creatorId: Creator?, title: String, description: String?, contentType: ContentType, contentURL: String?, thumbnailURL: String?, duration: Int?, sourceType: ContentSource?, sourceAttribution: SourceAttribution?, domain: String?, topics: [String]?, tags: [String]?, difficulty: Difficulty?, aiData: AIData?, status: ContentStatus?, viewCount: Int?, likeCount: Int?, commentCount: Int?, saveCount: Int?, averageRating: Double?, ratingCount: Int?, publishedAt: Date?, createdAt: Date?, reportCount: Int? = nil, removalReason: String? = nil, _progress: ContentProgressInfo? = nil, moderationStatus: String? = nil, pageCount: Int? = nil, fileFormat: String? = nil, collegeName: String? = nil, ocrText: String? = nil) {
        self.id = id
        self.creatorId = creatorId
        self.title = title
        self.description = description
        self.contentType = contentType
        self.contentURL = contentURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.sourceType = sourceType
        self.sourceAttribution = sourceAttribution
        self.domain = domain
        self.topics = topics
        self.tags = tags
        self.difficulty = difficulty
        self.aiData = aiData
        self.status = status
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.saveCount = saveCount
        self.averageRating = averageRating
        self.ratingCount = ratingCount
        self.publishedAt = publishedAt
        self.createdAt = createdAt
        self.reportCount = reportCount
        self.removalReason = removalReason
        self._progress = _progress
        self.moderationStatus = moderationStatus
        self.pageCount = pageCount
        self.fileFormat = fileFormat
        self.collegeName = collegeName
        self.ocrText = ocrText
    }

    var formattedDuration: String {
        guard let d = duration, d > 0 else { return "" }
        let minutes = d / 60
        let seconds = d % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedPageCount: String {
        guard let p = pageCount, p > 0 else { return "" }
        return "\(p) pg"
    }

    /// Display string for the content card overlay (duration for videos, pages for notes)
    var overlayBadge: String {
        if contentType == .notes { return formattedPageCount }
        return formattedDuration
    }

    var isNotes: Bool { contentType == .notes }

    var isNew: Bool {
        guard let published = publishedAt else { return false }
        return Date().timeIntervalSince(published) < 7 * 24 * 3600
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Content, rhs: Content) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AI Data

struct AIData: Codable, Sendable {
    let summary: String?
    let keyConcepts: [KeyConcept]?
    let prerequisites: [String]?
    let qualityScore: Int?
}

struct KeyConcept: Codable, Sendable, Identifiable {
    var id: String { concept }
    let concept: String
    let description: String?
    let timestamp: String? // "MM:SS"
    let importance: Int?
}

// MARK: - Source Attribution

struct SourceAttribution: Codable, Sendable {
    let platform: String?
    let originalCreatorName: String?
    let originalCreatorUrl: String?
    let originalContentUrl: String?
    let importDisclaimer: String?
}

// MARK: - Enums

enum ContentType: String, Codable, Sendable {
    case video, article, infographic, notes

    var badgeIcon: String {
        switch self {
        case .video: return "play.fill"
        case .article: return "doc.text.fill"
        case .infographic: return "chart.bar.doc.horizontal.fill"
        case .notes: return "doc.text.image.fill"
        }
    }

    var badgeLabel: String {
        switch self {
        case .video: return "VIDEO"
        case .article: return "ARTICLE"
        case .infographic: return "INFOGRAPHIC"
        case .notes: return "NOTES"
        }
    }

    var badgeColor: Color {
        switch self {
        case .video: return ColorTokens.info
        case .article: return ColorTokens.success
        case .infographic: return Color.purple
        case .notes: return .orange
        }
    }
}

enum ContentStatus: String, Codable, Sendable {
    case draft, processing, ready, published, unpublished, rejected, removed

    // Legacy compatibility
    case flagged, archived
}

enum ContentSource: String, Codable, Sendable {
    case original, youtube
}

enum Difficulty: String, Codable, Sendable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
