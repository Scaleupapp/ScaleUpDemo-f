import SwiftUI

// MARK: - Creator Application

struct CreatorApplication: Codable, Sendable, Identifiable {
    let id: String
    let userId: String?
    let applicant: User?
    let domain: String
    let specializations: [String]?
    let experience: String?
    let motivation: String?
    let sampleContentLinks: [String]?
    let portfolioUrl: String?
    let socialLinks: SocialLinks?
    let status: ApplicationStatus
    let endorsements: [Endorsement]?
    let rejectionNote: String?
    let reapplyAfter: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, applicant, domain, specializations
        case experience, motivation, sampleContentLinks
        case portfolioUrl, socialLinks, status
        case endorsements, rejectionNote, reapplyAfter
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        domain = try container.decode(String.self, forKey: .domain)
        status = try container.decode(ApplicationStatus.self, forKey: .status)
        specializations = try container.decodeIfPresent([String].self, forKey: .specializations)
        experience = try container.decodeIfPresent(String.self, forKey: .experience)
        motivation = try container.decodeIfPresent(String.self, forKey: .motivation)
        sampleContentLinks = try container.decodeIfPresent([String].self, forKey: .sampleContentLinks)
        portfolioUrl = try container.decodeIfPresent(String.self, forKey: .portfolioUrl)
        socialLinks = try container.decodeIfPresent(SocialLinks.self, forKey: .socialLinks)
        endorsements = try container.decodeIfPresent([Endorsement].self, forKey: .endorsements)
        rejectionNote = try container.decodeIfPresent(String.self, forKey: .rejectionNote)
        reapplyAfter = try container.decodeIfPresent(Date.self, forKey: .reapplyAfter)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        // userId can be a string or populated User object
        if let userObj = try? container.decode(User.self, forKey: .userId) {
            applicant = userObj
            userId = userObj.id
        } else {
            userId = try container.decodeIfPresent(String.self, forKey: .userId)
            applicant = try container.decodeIfPresent(User.self, forKey: .applicant)
        }
    }
}

// MARK: - Application Status

enum ApplicationStatus: String, Codable, Sendable {
    case pending, endorsed, approved, rejected

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .pending: return "hourglass"
        case .endorsed: return "checkmark.seal"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return ColorTokens.warning
        case .endorsed: return ColorTokens.info
        case .approved: return ColorTokens.success
        case .rejected: return ColorTokens.error
        }
    }
}

// MARK: - Endorsement

struct Endorsement: Codable, Sendable, Identifiable {
    var id: String { "\(creatorId ?? "unknown")-\(Int(endorsedAt?.timeIntervalSince1970 ?? 0))" }
    let creatorId: String?
    let creatorName: String?
    let creatorTier: CreatorTier?
    let note: String?
    let endorsedAt: Date?
}

// MARK: - Social Links

struct SocialLinks: Codable, Sendable {
    let linkedin: String?
    let twitter: String?
    let youtube: String?
    let website: String?
}
