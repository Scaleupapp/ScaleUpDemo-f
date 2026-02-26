import Foundation

// MARK: - Objective

struct Objective: Codable, Identifiable, Hashable {
    let id: String
    let userId: String?
    let objectiveType: ObjectiveType
    let specifics: ObjectiveSpecifics?
    let timeline: Timeline?
    let currentLevel: Difficulty?
    let weeklyCommitHours: Double?
    let status: ObjectiveStatus?
    let isPrimary: Bool?
    let weight: Int?
    let targetDate: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, objectiveType, specifics
        case timeline, currentLevel, weeklyCommitHours
        case status, isPrimary, weight, targetDate
        case createdAt, updatedAt
    }
}

// MARK: - ObjectiveStatus

enum ObjectiveStatus: String, Codable, Hashable {
    case active
    case paused
    case completed
}

// MARK: - ObjectiveSpecifics

struct ObjectiveSpecifics: Codable, Hashable {
    let examName: String?
    let targetSkill: String?
    let targetRole: String?
    let targetCompany: String?
    let fromDomain: String?
    let toDomain: String?
}
