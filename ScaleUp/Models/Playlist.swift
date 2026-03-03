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
}

// MARK: - Playlist Item

struct PlaylistItem: Codable, Sendable, Identifiable {
    let id: String
    let contentId: String?
    let order: Int?
    let addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case contentId, order, addedAt
    }
}
