import Foundation

// MARK: - User Objective

struct UserObjective: Codable, Sendable, Identifiable {
    let id: String
    let objectiveType: String?
    let specifics: ObjectiveSpecifics?
    let timeline: String?
    let targetDate: Date?
    let currentLevel: String?
    let weeklyCommitHours: Int?
    let preferredLearningStyle: String?
    let topicsOfInterest: [String]?
    let status: ObjectiveStatus?
    let isPrimary: Bool?
    let weight: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case objectiveType, specifics, timeline, targetDate
        case currentLevel, weeklyCommitHours, preferredLearningStyle
        case topicsOfInterest, status, isPrimary, weight, createdAt
    }

    var specificTitle: String {
        if let s = specifics {
            if let name = s.examName, !name.isEmpty { return name }
            if let role = s.targetRole, !role.isEmpty { return role }
            if let skill = s.targetSkill, !skill.isEmpty { return skill }
            if let from = s.fromDomain, let to = s.toDomain, !from.isEmpty, !to.isEmpty {
                return "\(from) → \(to)"
            }
        }
        return typeDisplay
    }

    var typeDisplay: String {
        (objectiveType ?? "learning")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var timelineDisplay: String {
        (timeline ?? "no_deadline")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var levelDisplay: String {
        (currentLevel ?? "beginner").capitalized
    }

    var typeIcon: String {
        switch objectiveType {
        case "exam_preparation": return "doc.text.fill"
        case "upskilling": return "arrow.up.circle.fill"
        case "interview_preparation": return "person.fill.questionmark"
        case "career_switch": return "arrow.triangle.swap"
        case "academic_excellence": return "graduationcap.fill"
        case "casual_learning": return "book.fill"
        case "networking": return "person.3.fill"
        default: return "target"
        }
    }
}

// MARK: - Objective Status

enum ObjectiveStatus: String, Codable, Sendable {
    case active, paused, completed, abandoned

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .active: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle.fill"
        }
    }
}
