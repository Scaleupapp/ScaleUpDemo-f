import Foundation

// MARK: - Admin Stats

struct AdminStats: Codable, Sendable {
    let totalUsers: Int?
    let totalCreators: Int?
    let totalContent: Int?
    let publishedContent: Int?
    let reportedContent: Int?
    let pendingApplications: Int?
    let bannedUsers: Int?
}

// MARK: - Admin User

struct AdminUser: Codable, Sendable, Identifiable {
    let id: String
    let email: String?
    let firstName: String
    let lastName: String?
    let username: String?
    let profilePicture: String?
    let role: UserRole
    let isActive: Bool?
    let isBanned: Bool?
    let createdAt: Date?
    let lastLoginAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, firstName, lastName, username
        case profilePicture, role, isActive, isBanned, createdAt, lastLoginAt
    }

    var displayName: String {
        if let last = lastName, !last.isEmpty { return "\(firstName) \(last)" }
        return firstName
    }
}
