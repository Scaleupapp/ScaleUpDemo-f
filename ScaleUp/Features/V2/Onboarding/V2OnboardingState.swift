import Foundation

/// Shared state that flows from V2ObjectiveSetupView → V2RealityCheckView →
/// (existing v1 diagnostic flow) → V2CalibrationInsightsView.
///
/// We DON'T save the objective until the user picks a commitment path on
/// Reality Check — that's when weeklyCommitHours is finalized. Until then
/// we carry the parsed objective in memory.
@Observable
@MainActor
final class V2OnboardingState {

    // What the user typed / chose on the objective setup screen
    var rawGoalText: String = ""

    var objectiveType: V2ObjectiveType = .interviewPreparation
    var targetRole: String = ""
    var targetCompanies: [String] = []
    var examName: String = ""
    var targetSkill: String = ""
    var fromDomain: String = ""
    var toDomain: String = ""

    var timeline: V2Timeline = .sixMonths
    var currentLevel: V2CurrentLevel = .intermediate
    var location: String = ""

    // Filled by the Reality Check screen after the user picks a path
    var chosenWeeklyHours: Int? = nil

    // After successful save:
    var savedObjectiveId: String? = nil

    // After diagnostic completes:
    var diagnosticAttemptId: String? = nil

    /// Build the payload shape that `/api/v1/onboarding/objective` accepts.
    func objectiveSaveBody(weeklyCommitHours: Int) -> V2ObjectiveSaveBody {
        var specifics: [String: String] = [:]
        if !targetRole.isEmpty   { specifics["targetRole"] = targetRole }
        if let firstCompany = targetCompanies.first { specifics["targetCompany"] = firstCompany }
        if !examName.isEmpty     { specifics["examName"]   = examName }
        if !targetSkill.isEmpty  { specifics["targetSkill"] = targetSkill }
        if !fromDomain.isEmpty   { specifics["fromDomain"]  = fromDomain }
        if !toDomain.isEmpty     { specifics["toDomain"]    = toDomain }

        return V2ObjectiveSaveBody(
            objectiveType: objectiveType.rawValue,
            specifics: specifics,
            timeline: timeline.rawValue,
            currentLevel: currentLevel.rawValue,
            weeklyCommitHours: weeklyCommitHours
        )
    }

    /// Build the body for `/api/v2/objective/required-time` (no commit-hours yet).
    func requiredTimeBody() -> V2RequiredTimeRequest {
        var specifics: [String: String] = [:]
        if !targetRole.isEmpty   { specifics["targetRole"] = targetRole }
        if let firstCompany = targetCompanies.first { specifics["targetCompany"] = firstCompany }
        if !examName.isEmpty     { specifics["examName"]   = examName }
        if !targetSkill.isEmpty  { specifics["targetSkill"] = targetSkill }
        if !fromDomain.isEmpty   { specifics["fromDomain"]  = fromDomain }
        if !toDomain.isEmpty     { specifics["toDomain"]    = toDomain }
        return V2RequiredTimeRequest(
            objectiveType: objectiveType.rawValue,
            specifics: specifics,
            timeline: timeline.rawValue,
            currentLevel: currentLevel.rawValue
        )
    }
}

// MARK: - Enums

enum V2ObjectiveType: String, Codable, CaseIterable {
    // v1 collapses "campus placement" and "interview prep" into the single
    // `interview_preparation` enum — they're the same backend objective.
    // Only the UI copy varies, which we handle by inspecting specifics.
    case careerSwitch          = "career_switch"
    case interviewPreparation  = "interview_preparation"
    case competitiveExam       = "exam_preparation"
    case upskilling            = "upskilling"
}

enum V2Timeline: String, Codable, CaseIterable {
    case oneMonth   = "1_month"
    case threeMonths = "3_months"
    case sixMonths  = "6_months"
    case oneYear    = "1_year"
    case noDeadline = "no_deadline"

    var label: String {
        switch self {
        case .oneMonth:   return "1 month"
        case .threeMonths: return "3 months"
        case .sixMonths:  return "6 months"
        case .oneYear:    return "12 months"
        case .noDeadline: return "Custom"
        }
    }
}

enum V2CurrentLevel: String, Codable, CaseIterable {
    case beginner     = "beginner"
    case intermediate = "intermediate"
    case advanced     = "advanced"
}

// MARK: - Request bodies

struct V2ObjectiveSaveBody: Codable {
    let objectiveType: String
    let specifics: [String: String]
    let timeline: String
    let currentLevel: String
    let weeklyCommitHours: Int
}

// MARK: - Save service

@MainActor
final class V2ObjectiveSaveService {
    static let shared = V2ObjectiveSaveService()

    struct SaveResponse: Codable {
        let success: Bool?
        let data: ObjectiveData?
        let message: String?

        struct ObjectiveData: Codable {
            let _id: String?
            let id: String?
            var objectiveId: String? { _id ?? id }
        }
    }

    /// POSTs to v1 `/api/v1/onboarding/objective` — reuses the v1 endpoint so the
    /// saved objective is interoperable with the rest of the app immediately.
    func saveObjective(body: V2ObjectiveSaveBody) async throws -> String? {
        // Resolve v1 base URL from Info.plist
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(baseURLString)/onboarding/objective") else {
            throw V2APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await KeychainManager.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw V2APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoded = try JSONDecoder().decode(SaveResponse.self, from: data)
        return decoded.data?.objectiveId
    }
}
