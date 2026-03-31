import Foundation

// MARK: - Playlist

struct Playlist: Codable, Sendable, Identifiable {
    let id: String
    let userId: String?
    let title: String
    let description: String?
    let items: [PlaylistItem]?
    let isPublic: Bool?
    let itemCount: Int?
    let totalDuration: Int?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, title, description, items
        case isPublic, itemCount, totalDuration
        case createdAt, updatedAt
    }

    var formattedDuration: String {
        guard let dur = totalDuration, dur > 0 else { return "" }
        let mins = dur / 60
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }
}

// MARK: - Playlist Item
// contentId can be a string (list) or populated Content (detail)

struct PlaylistItem: Codable, Sendable, Identifiable {
    let id: String
    let contentId: PlaylistContentRef?
    let order: Int?
    let addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case contentId, order, addedAt
    }
}

// MARK: - Content reference in playlist (can be string ID or populated object)

enum PlaylistContentRef: Codable, Sendable {
    case id(String)
    case content(Content)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .id(str)
        } else {
            let content = try container.decode(Content.self)
            self = .content(content)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .id(let str): try container.encode(str)
        case .content(let c): try container.encode(c)
        }
    }

    var contentValue: Content? {
        if case .content(let c) = self { return c }
        return nil
    }

    var idValue: String {
        switch self {
        case .id(let s): return s
        case .content(let c): return c.id
        }
    }
}
