import Foundation

// MARK: - Follow User

struct FollowUser: Codable, Sendable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String?
    let username: String?
    let profilePicture: String?
    let role: UserRole?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, username, profilePicture, role
    }

    var displayName: String {
        if let last = lastName, !last.isEmpty { return "\(firstName) \(last)" }
        return firstName
    }

    var initials: String {
        let first = firstName.prefix(1)
        let last = (lastName ?? "").prefix(1)
        return "\(first)\(last)".uppercased()
    }
}
