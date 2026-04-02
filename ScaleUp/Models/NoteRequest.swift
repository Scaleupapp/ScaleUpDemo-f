import Foundation

struct NoteRequest: Codable, Sendable, Identifiable {
    let id: String
    let requestedBy: NoteRequestUserRef?
    let title: String
    let description: String?
    let domain: String
    let topics: [String]?
    let difficulty: String?
    let collegeName: String?
    let status: String // open, in_progress, fulfilled, closed
    let fulfilledBy: NoteRequestUserRef?
    let fulfilledContentId: NoteRequestContentRef?
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

// Handles both raw ObjectId string and populated user object from backend
enum NoteRequestUserRef: Codable, Sendable {
    case id(String)
    case populated(NoteRequestUser)

    var user: NoteRequestUser? {
        if case .populated(let u) = self { return u }
        return nil
    }

    init(from decoder: Decoder) throws {
        if let str = try? decoder.singleValueContainer().decode(String.self) {
            self = .id(str)
        } else {
            self = .populated(try NoteRequestUser(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .id(let str): var c = encoder.singleValueContainer(); try c.encode(str)
        case .populated(let u): try u.encode(to: encoder)
        }
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

// Handles both raw ObjectId string and populated content object
enum NoteRequestContentRef: Codable, Sendable {
    case id(String)
    case populated(NoteRequestContent)

    var content: NoteRequestContent? {
        if case .populated(let c) = self { return c }
        return nil
    }

    init(from decoder: Decoder) throws {
        if let str = try? decoder.singleValueContainer().decode(String.self) {
            self = .id(str)
        } else {
            self = .populated(try NoteRequestContent(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .id(let str): var c = encoder.singleValueContainer(); try c.encode(str)
        case .populated(let c): try c.encode(to: encoder)
        }
    }
}

struct NoteRequestContent: Codable, Sendable {
    let _id: String
    let title: String
    let thumbnailURL: String?
    let domain: String?
}
