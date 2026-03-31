import Foundation

// MARK: - Comment

struct Comment: Codable, Sendable, Identifiable {
    let id: String
    let userId: CommentUser?
    let contentId: String?
    let parentId: String?
    let text: String
    let likeCount: Int?
    let isEdited: Bool?
    let replyCount: Int?
    let createdAt: Date?
    let updatedAt: Date?

    // Mutable state for UI
    var isLikedByMe: Bool = false

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, contentId, parentId, text
        case likeCount, isEdited, replyCount, createdAt, updatedAt
    }

    // Custom decoder: userId can be either a populated CommentUser object or a plain string (ObjectId)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        contentId = try container.decodeIfPresent(String.self, forKey: .contentId)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        text = try container.decode(String.self, forKey: .text)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited)
        replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        // Handle userId as either a CommentUser object or a plain string ObjectId
        if let user = try? container.decodeIfPresent(CommentUser.self, forKey: .userId) {
            userId = user
        } else if let userIdString = try? container.decodeIfPresent(String.self, forKey: .userId) {
            userId = CommentUser(id: userIdString, firstName: "You", lastName: nil, username: nil, profilePicture: nil)
        } else {
            userId = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(contentId, forKey: .contentId)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(likeCount, forKey: .likeCount)
        try container.encodeIfPresent(isEdited, forKey: .isEdited)
        try container.encodeIfPresent(replyCount, forKey: .replyCount)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    // Memberwise init for mock data and manual creation
    init(id: String, userId: CommentUser?, contentId: String?, parentId: String?, text: String, likeCount: Int?, isEdited: Bool?, replyCount: Int? = nil, createdAt: Date?, updatedAt: Date?) {
        self.id = id
        self.userId = userId
        self.contentId = contentId
        self.parentId = parentId
        self.text = text
        self.likeCount = likeCount
        self.isEdited = isEdited
        self.replyCount = replyCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var timeAgo: String {
        guard let date = createdAt else { return "" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 604800 { return "\(seconds / 86400)d ago" }
        return "\(seconds / 604800)w ago"
    }
}

// MARK: - Comment User (populated from userId)

struct CommentUser: Codable, Sendable {
    let id: String
    let firstName: String
    let lastName: String?
    let username: String?
    let profilePicture: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, username, profilePicture
    }

    var displayName: String {
        if let last = lastName, !last.isEmpty {
            return "\(firstName) \(last)"
        }
        return firstName
    }

    var initials: String {
        let first = firstName.prefix(1)
        let last = (lastName ?? "").prefix(1)
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Comments Response

struct CommentsResponse: Codable, Sendable {
    let comments: [Comment]
    let pagination: CommentPagination?
}

struct RepliesResponse: Codable, Sendable {
    let replies: [Comment]
    let pagination: CommentPagination?
}

struct CommentLikeResponse: Codable, Sendable {
    let liked: Bool
    let likeCount: Int
}

struct CommentPagination: Codable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasNextPage: Bool?
    let hasPrevPage: Bool?
}
