import SwiftUI

// MARK: - Mutual Followers Info

struct MutualFollowersInfo: Codable, Sendable {
    let count: Int
    let users: [FollowUser]
}

// MARK: - Creator

struct Creator: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String?
    let username: String?
    let profilePicture: String?
    let bio: String?
    let tier: CreatorTier?
    let followersCount: Int?
    let contentCount: Int?
    let averageRating: Double?
    let domain: String?
    let specializations: [String]?
    let isVerified: Bool?
    let isVerifiedContributor: Bool?
    let createdAt: Date?
    let isFollowing: Bool?
    let totalViews: Int?
    let mutualFollowers: MutualFollowersInfo?
    let education: [Education]?
    let workExperience: [WorkExperience]?
    let skills: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, username, profilePicture, bio
        case tier, followersCount, contentCount, averageRating
        case domain, specializations, isVerified, isVerifiedContributor, createdAt
        case isFollowing, totalViews, mutualFollowers
        case education, workExperience, skills
        case creatorProfile
    }

    // Nested creator profile from backend response
    private struct CreatorProfileNested: Codable {
        let tier: CreatorTier?
        let domain: String?
        let specializations: [String]?
        let isVerified: Bool?
        let stats: NestedStats?
    }

    private struct NestedStats: Codable {
        let totalContent: Int?
        let totalViews: Int?
        let totalFollowers: Int?
        let averageRating: Double?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        profilePicture = try container.decodeIfPresent(String.self, forKey: .profilePicture)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        isFollowing = try container.decodeIfPresent(Bool.self, forKey: .isFollowing)
        mutualFollowers = try container.decodeIfPresent(MutualFollowersInfo.self, forKey: .mutualFollowers)

        // Try to decode nested creatorProfile (from public profile endpoint)
        let nested = try container.decodeIfPresent(CreatorProfileNested.self, forKey: .creatorProfile)

        // Prefer top-level fields, fall back to nested creatorProfile
        tier = try container.decodeIfPresent(CreatorTier.self, forKey: .tier) ?? nested?.tier
        domain = try container.decodeIfPresent(String.self, forKey: .domain) ?? nested?.domain
        specializations = try container.decodeIfPresent([String].self, forKey: .specializations) ?? nested?.specializations
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? nested?.isVerified
        isVerifiedContributor = try container.decodeIfPresent(Bool.self, forKey: .isVerifiedContributor)
        totalViews = try container.decodeIfPresent(Int.self, forKey: .totalViews) ?? nested?.stats?.totalViews
        contentCount = try container.decodeIfPresent(Int.self, forKey: .contentCount) ?? nested?.stats?.totalContent
        averageRating = try container.decodeIfPresent(Double.self, forKey: .averageRating) ?? nested?.stats?.averageRating
        followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount) ?? nested?.stats?.totalFollowers
        education = try container.decodeIfPresent([Education].self, forKey: .education)
        workExperience = try container.decodeIfPresent([WorkExperience].self, forKey: .workExperience)
        skills = try container.decodeIfPresent([String].self, forKey: .skills)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(profilePicture, forKey: .profilePicture)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(tier, forKey: .tier)
        try container.encodeIfPresent(followersCount, forKey: .followersCount)
        try container.encodeIfPresent(contentCount, forKey: .contentCount)
        try container.encodeIfPresent(averageRating, forKey: .averageRating)
        try container.encodeIfPresent(domain, forKey: .domain)
        try container.encodeIfPresent(specializations, forKey: .specializations)
        try container.encodeIfPresent(isVerified, forKey: .isVerified)
        try container.encodeIfPresent(isVerifiedContributor, forKey: .isVerifiedContributor)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(isFollowing, forKey: .isFollowing)
        try container.encodeIfPresent(totalViews, forKey: .totalViews)
        try container.encodeIfPresent(mutualFollowers, forKey: .mutualFollowers)
        try container.encodeIfPresent(education, forKey: .education)
        try container.encodeIfPresent(workExperience, forKey: .workExperience)
        try container.encodeIfPresent(skills, forKey: .skills)
    }

    // Manual init for mock/fallback
    init(
        id: String, firstName: String, lastName: String?, username: String?,
        profilePicture: String?, bio: String?, tier: CreatorTier?,
        followersCount: Int?, contentCount: Int?, averageRating: Double?,
        domain: String? = nil, specializations: [String]? = nil,
        isVerified: Bool? = nil, isVerifiedContributor: Bool? = nil,
        createdAt: Date? = nil,
        isFollowing: Bool? = nil, totalViews: Int? = nil,
        mutualFollowers: MutualFollowersInfo? = nil,
        education: [Education]? = nil, workExperience: [WorkExperience]? = nil,
        skills: [String]? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.profilePicture = profilePicture
        self.bio = bio
        self.tier = tier
        self.followersCount = followersCount
        self.contentCount = contentCount
        self.averageRating = averageRating
        self.domain = domain
        self.specializations = specializations
        self.isVerified = isVerified
        self.isVerifiedContributor = isVerifiedContributor
        self.createdAt = createdAt
        self.isFollowing = isFollowing
        self.totalViews = totalViews
        self.mutualFollowers = mutualFollowers
        self.education = education
        self.workExperience = workExperience
        self.skills = skills
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Creator, rhs: Creator) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Creator Tier

enum CreatorTier: String, Codable, Sendable {
    case rising, core, anchor

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .anchor: return ColorTokens.gold
        case .core: return Color(hex: 0xC0C0C0) // silver
        case .rising: return Color(hex: 0xCD7F32) // bronze
        }
    }

    var icon: String {
        switch self {
        case .anchor: return "crown.fill"
        case .core: return "star.fill"
        case .rising: return "arrow.up.right"
        }
    }
}
