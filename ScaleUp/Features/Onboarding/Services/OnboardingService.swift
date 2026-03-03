import Foundation

// MARK: - Onboarding Service

actor OnboardingService {

    private let api = APIClient.shared

    // MARK: - Step 1: Profile

    func updateProfile(firstName: String, lastName: String?) async throws {
        let body = ProfileRequest(firstName: firstName, lastName: lastName)
        _ = try await api.requestRaw(OnboardingEndpoints.profile, body: body)
    }

    // MARK: - Step 2: Background

    func updateBackground(education: [Education], workExperience: [WorkExperience]) async throws {
        let body = BackgroundRequest(education: education, workExperience: workExperience)
        _ = try await api.requestRaw(OnboardingEndpoints.background, body: body)
    }

    // MARK: - Step 3: Objective

    func setObjective(
        type: ObjectiveType,
        specifics: ObjectiveSpecifics?,
        timeline: Timeline,
        currentLevel: CurrentLevel,
        weeklyCommitHours: Int
    ) async throws {
        let body = ObjectiveRequest(
            objectiveType: type,
            specifics: specifics,
            timeline: timeline,
            currentLevel: currentLevel,
            weeklyCommitHours: weeklyCommitHours
        )
        _ = try await api.requestRaw(OnboardingEndpoints.objective, body: body)
    }

    // MARK: - Step 4: Preferences

    func updatePreferences(style: LearningStyle, weeklyCommitHours: Int) async throws {
        let body = PreferencesRequest(
            preferredLearningStyle: style,
            weeklyCommitHours: weeklyCommitHours
        )
        _ = try await api.requestRaw(OnboardingEndpoints.preferences, body: body)
    }

    // MARK: - Step 5: Interests

    func updateInterests(skills: [String], topicsOfInterest: [String]) async throws {
        let body = InterestsRequest(skills: skills, topicsOfInterest: topicsOfInterest)
        _ = try await api.requestRaw(OnboardingEndpoints.interests, body: body)
    }

    // MARK: - Step 6: Complete

    func complete() async throws {
        _ = try await api.requestRaw(OnboardingEndpoints.complete)
    }
}

// MARK: - Endpoints

private enum OnboardingEndpoints: Endpoint {
    case profile
    case background
    case objective
    case preferences
    case interests
    case complete

    var path: String {
        switch self {
        case .profile: return "/onboarding/profile"
        case .background: return "/onboarding/background"
        case .objective: return "/onboarding/objective"
        case .preferences: return "/onboarding/preferences"
        case .interests: return "/onboarding/interests"
        case .complete: return "/onboarding/complete"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .objective, .complete: return .post
        case .profile, .background, .preferences, .interests: return .put
        }
    }
}

// MARK: - Request Bodies

private struct ProfileRequest: Encodable, Sendable {
    let firstName: String
    let lastName: String?
}

private struct BackgroundRequest: Encodable, Sendable {
    let education: [Education]
    let workExperience: [WorkExperience]
}

struct ObjectiveSpecifics: Codable, Sendable {
    var examName: String?
    var targetSkill: String?
    var targetRole: String?
    var targetCompany: String?
    var fromDomain: String?
    var toDomain: String?
}

private struct ObjectiveRequest: Encodable, Sendable {
    let objectiveType: ObjectiveType
    let specifics: ObjectiveSpecifics?
    let timeline: Timeline
    let currentLevel: CurrentLevel
    let weeklyCommitHours: Int
}

private struct PreferencesRequest: Encodable, Sendable {
    let preferredLearningStyle: LearningStyle
    let weeklyCommitHours: Int
}

private struct InterestsRequest: Encodable, Sendable {
    let skills: [String]
    let topicsOfInterest: [String]
}
