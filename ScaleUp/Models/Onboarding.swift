import Foundation

// MARK: - Objective Type

enum ObjectiveType: String, Codable, Sendable, CaseIterable, Identifiable {
    case examPreparation = "exam_preparation"
    case upskilling
    case interviewPreparation = "interview_preparation"
    case careerSwitch = "career_switch"
    case academicExcellence = "academic_excellence"
    case casualLearning = "casual_learning"
    case networking

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .examPreparation: return "Exam Prep"
        case .upskilling: return "Upskilling"
        case .interviewPreparation: return "Interview Prep"
        case .careerSwitch: return "Career Switch"
        case .academicExcellence: return "Academic Excellence"
        case .casualLearning: return "Casual Learning"
        case .networking: return "Networking"
        }
    }

    var icon: String {
        switch self {
        case .examPreparation: return "pencil.and.list.clipboard"
        case .upskilling: return "chart.line.uptrend.xyaxis"
        case .interviewPreparation: return "briefcase.fill"
        case .careerSwitch: return "arrow.triangle.swap"
        case .academicExcellence: return "graduationcap.fill"
        case .casualLearning: return "book.fill"
        case .networking: return "person.3.fill"
        }
    }

    var description: String {
        switch self {
        case .examPreparation: return "Prepare for a specific exam"
        case .upskilling: return "Level up a professional skill"
        case .interviewPreparation: return "Ace your next interview"
        case .careerSwitch: return "Transition to a new field"
        case .academicExcellence: return "Excel in your studies"
        case .casualLearning: return "Learn at your own pace"
        case .networking: return "Connect and grow with peers"
        }
    }

    var requiresSpecifics: Bool {
        switch self {
        case .examPreparation, .upskilling, .interviewPreparation, .careerSwitch:
            return true
        case .academicExcellence, .casualLearning, .networking:
            return false
        }
    }
}

// MARK: - Timeline

enum Timeline: String, Codable, Sendable, CaseIterable, Identifiable {
    case oneMonth = "1_month"
    case threeMonths = "3_months"
    case sixMonths = "6_months"
    case oneYear = "1_year"
    case noDeadline = "no_deadline"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        case .noDeadline: return "No Rush"
        }
    }
}

// MARK: - Current Level

enum CurrentLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

// MARK: - Learning Style

enum LearningStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case videos, articles, interactive, mix

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .videos: return "Videos"
        case .articles: return "Articles"
        case .interactive: return "Interactive"
        case .mix: return "Mix of Everything"
        }
    }

    var icon: String {
        switch self {
        case .videos: return "play.rectangle.fill"
        case .articles: return "doc.text.fill"
        case .interactive: return "hand.tap.fill"
        case .mix: return "square.grid.2x2.fill"
        }
    }

    var description: String {
        switch self {
        case .videos: return "Learn through video content"
        case .articles: return "Read in-depth articles"
        case .interactive: return "Hands-on exercises & labs"
        case .mix: return "A blend of all formats"
        }
    }
}

// MARK: - Mutable Entry Models (for onboarding forms)

struct EducationEntry: Identifiable {
    let id = UUID()
    var degree: String = ""
    var institution: String = ""
    var yearOfCompletion: Int?
    var currentlyPursuing: Bool = false
}

struct WorkEntry: Identifiable {
    let id = UUID()
    var role: String = ""
    var company: String = ""
    var years: Int?
    var currentlyWorking: Bool = false
}
