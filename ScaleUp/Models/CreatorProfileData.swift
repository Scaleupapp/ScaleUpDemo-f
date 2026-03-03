import Foundation

// MARK: - Creator Profile Data

struct CreatorProfileData: Codable, Sendable {
    let userId: String?
    let tier: CreatorTier?
    let domain: String?
    let specializations: [String]?
    let bio: String?
    let stats: CreatorStats?
    let isVerified: Bool?
    let verifiedAt: Date?
}

// MARK: - Creator Stats

struct CreatorStats: Codable, Sendable {
    let totalContent: Int?
    let totalViews: Int?
    let totalFollowers: Int?
    let averageRating: Double?
    let totalQuizzesGenerated: Int?
}
