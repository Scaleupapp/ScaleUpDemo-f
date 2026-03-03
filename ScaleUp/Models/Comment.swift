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
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, contentId, parentId, text
        case likeCount, isEdited, createdAt, updatedAt
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

struct CommentPagination: Codable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}
