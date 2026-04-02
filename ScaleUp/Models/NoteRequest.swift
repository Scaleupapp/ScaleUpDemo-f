import Foundation

struct NoteRequest: Codable, Sendable, Identifiable {
    let id: String
    let requestedBy: NoteRequestUser?
    let title: String
    let description: String?
    let domain: String
    let topics: [String]?
    let difficulty: String?
    let collegeName: String?
    let status: String // open, in_progress, fulfilled, closed
    let fulfilledBy: NoteRequestUser?
    let fulfilledContentId: NoteRequestContent?
    let fulfilledAt: Date?
    let upvoteCount: Int
    let responseCount: Int?
    let isUpvotedByMe: Bool?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case requestedBy, title, description, domain, topics, difficulty, collegeName
        case status, fulfilledBy, fulfilledContentId, fulfilledAt
        case upvoteCount, responseCount, isUpvotedByMe, createdAt
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

struct NoteRequestUser: Codable, Sendable {
    let _id: String
    let firstName: String
    let lastName: String?
    let username: String?
    let profilePicture: String?
    var displayName: String { "\(firstName) \(lastName ?? "")".trimmingCharacters(in: .whitespaces) }
}

struct NoteRequestContent: Codable, Sendable {
    let _id: String
    let title: String
    let thumbnailURL: String?
    let domain: String?
}
