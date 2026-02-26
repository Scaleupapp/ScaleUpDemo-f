import Foundation

// MARK: - User

struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let phone: String?
    let isPhoneVerified: Bool
    let isEmailVerified: Bool
    let firstName: String
    let lastName: String
    let username: String?
    let profilePicture: String?
    let bio: String?
    let dateOfBirth: String?
    let location: String?
    let education: [Education]
    let workExperience: [WorkExperience]
    let skills: [String]
    let role: UserRole
    let authProvider: String
    let onboardingComplete: Bool
    let onboardingStep: Int
    let followersCount: Int
    let followingCount: Int
    let isActive: Bool
    let isBanned: Bool
    let lastLoginAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, phone, isPhoneVerified, isEmailVerified
        case firstName, lastName, username, profilePicture
        case bio, dateOfBirth, location, education, workExperience
        case skills, role, authProvider
        case onboardingComplete, onboardingStep
        case followersCount, followingCount
        case isActive, isBanned, lastLoginAt, createdAt
    }
}

// MARK: - Education

struct Education: Codable, Hashable {
    let degree: String
    let institution: String
    let yearOfCompletion: Int?
    let currentlyPursuing: Bool
}

// MARK: - WorkExperience

struct WorkExperience: Codable, Hashable {
    let role: String
    let company: String
    let years: Int?
    let currentlyWorking: Bool
}

// MARK: - PublicUser

struct PublicUser: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let username: String?
    let profilePicture: String?
    let bio: String?
    let role: UserRole
    let followersCount: Int
    let followingCount: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, username, profilePicture
        case bio, role, followersCount, followingCount
    }
}

// MARK: - AuthResponse

struct AuthResponse: Codable, Hashable {
    let user: User
    let accessToken: String
    let refreshToken: String
}
