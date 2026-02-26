import Foundation

// MARK: - CreatorProfile

struct CreatorProfile: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let domain: String
    let specializations: [String]
    let bio: String?
    let tier: CreatorTier
    let stats: CreatorStats
    let socialLinks: CreatorSocialLinks?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, domain, specializations
        case bio, tier, stats, socialLinks, createdAt
    }
}

// MARK: - CreatorStats

struct CreatorStats: Codable, Hashable {
    let totalContent: Int
    let totalViews: Int
    let totalFollowers: Int
    let averageRating: Double
}

// MARK: - CreatorSocialLinks

struct CreatorSocialLinks: Codable, Hashable {
    let linkedin: String?
    let twitter: String?
    let youtube: String?
    let website: String?
}

// MARK: - CreatorSearchResult

/// Wrapper for the `/creator/search` endpoint response. The API returns user
/// objects with a nested `creatorProfile` rather than flat `CreatorProfile` objects.
struct CreatorSearchResult: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let followersCount: Int?
    let creatorProfile: CreatorProfile?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, followersCount, creatorProfile
    }

    /// Display name combining first and last name.
    var displayName: String {
        "\(firstName) \(lastName)"
    }
}

// MARK: - CreatorApplication

struct CreatorApplication: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let domain: String
    let specializations: [String]
    let experience: String?
    let motivation: String?
    let sampleContentLinks: [String]?
    let portfolioUrl: String?
    let socialLinks: CreatorSocialLinks?
    let endorsements: [Endorsement]?
    let status: ApplicationStatus
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, domain, specializations
        case experience, motivation
        case sampleContentLinks, portfolioUrl
        case socialLinks, endorsements
        case status, createdAt
    }
}

// MARK: - Endorsement

struct Endorsement: Codable, Hashable {
    let endorserId: String
    let note: String?
    let createdAt: String
}

// MARK: - ApplicationStatus

enum ApplicationStatus: String, Codable, Hashable {
    case pending
    case approved
    case rejected
}
