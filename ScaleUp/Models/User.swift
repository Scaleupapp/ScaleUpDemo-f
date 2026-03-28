import Foundation

// MARK: - User

struct User: Codable, Sendable, Identifiable {
    let id: String
    let email: String?
    let phone: String?
    let firstName: String
    let lastName: String?
    let username: String?
    let profilePicture: String?
    let bio: String?
    let role: UserRole
    let authProvider: AuthProvider?
    let onboardingComplete: Bool?
    let onboardingStep: Int?
    let followersCount: Int?
    let followingCount: Int?
    let isActive: Bool?
    let skills: [String]?
    let education: [Education]?
    let workExperience: [WorkExperience]?
    let location: String?
    let dateOfBirth: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, phone, firstName, lastName, username
        case profilePicture, bio, role, authProvider
        case onboardingComplete, onboardingStep
        case followersCount, followingCount, isActive
        case skills, education, workExperience
        case location, dateOfBirth, createdAt
    }

    var displayName: String {
        if let last = lastName, !last.isEmpty {
            return "\(firstName) \(last)"
        }
        return firstName
    }

    init(partial: PartialUser) {
        self.id = partial.id
        self.firstName = partial.firstName ?? "Unknown"
        self.lastName = partial.lastName
        self.email = partial.email
        self.profilePicture = partial.profilePicture
        self.education = partial.education
        self.workExperience = partial.workExperience
        self.skills = partial.skills
        self.role = .consumer
        self.phone = nil; self.username = nil; self.bio = nil
        self.authProvider = nil; self.onboardingComplete = nil; self.onboardingStep = nil
        self.followersCount = nil; self.followingCount = nil; self.isActive = nil
        self.location = nil; self.dateOfBirth = nil; self.createdAt = nil
    }
}

// MARK: - Enums

enum UserRole: String, Codable, Sendable {
    case consumer, creator, admin
}

enum AuthProvider: String, Codable, Sendable {
    case local, google, linkedin, phone
}

// MARK: - Sub-models

struct Education: Codable, Sendable, Identifiable, Hashable {
    var id: String { "\(degree)-\(institution)" }
    let degree: String
    let institution: String
    let yearOfCompletion: Int?
    let currentlyPursuing: Bool?
}

struct WorkExperience: Codable, Sendable, Identifiable, Hashable {
    var id: String { "\(role)-\(company)" }
    let role: String
    let company: String
    let years: Int?
    let currentlyWorking: Bool?
}

// MARK: - Auth Response

struct AuthData: Codable, Sendable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let isNewUser: Bool?
}
