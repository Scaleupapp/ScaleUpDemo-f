import Foundation

// MARK: - Learning Path

struct LearningPath: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let domain: String?
    let difficulty: String?
    let items: [LearningPathItem]?
    let creatorId: String?
    let creatorName: String?
    let followerCount: Int?
    let averageRating: Double?
    let ratingCount: Int?
    let estimatedDuration: Int?
    let isPublished: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, description, domain, difficulty, items
        case creatorId, creatorName, followerCount
        case averageRating, ratingCount, estimatedDuration, isPublished
    }

    var formattedDuration: String {
        guard let mins = estimatedDuration, mins > 0 else { return "" }
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }

    var itemCount: Int { items?.count ?? 0 }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: LearningPath, rhs: LearningPath) -> Bool { lhs.id == rhs.id }
}

struct LearningPathItem: Codable, Sendable, Identifiable {
    var id: String { contentId ?? title ?? UUID().uuidString }
    let contentId: String?
    let title: String?
    let order: Int?
}
