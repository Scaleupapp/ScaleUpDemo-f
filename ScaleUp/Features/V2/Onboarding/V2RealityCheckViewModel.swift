import Foundation

// MARK: - Models

struct V2RequiredTimeRequest: Codable {
    let objectiveType: String
    let specifics: [String: String]
    let timeline: String
    let currentLevel: String
}

struct V2RequiredTimeResponse: Codable {
    let requiredHoursPerWeek: Int
    let requiredHoursPerDay: Double
    let totalHoursRemaining: Int
    let timelineWeeks: Int
    let baselineLabel: String
    let paths: PathsBlock
    let warnings: [String]

    struct PathsBlock: Codable {
        let commit: PathOption
        let lessTime: PathOptionAlt
        let moreTime: PathOptionAlt
    }

    struct PathOption: Codable {
        let hoursPerWeek: Int
        let label: String
    }

    struct PathOptionAlt: Codable {
        let hoursPerWeek: Int
        let timelineLabel: String
    }
}

// MARK: - View Model

@Observable
@MainActor
final class V2RealityCheckViewModel {
    var data: V2RequiredTimeResponse?
    var isLoading = false
    var error: String?

    /// Defaults match the iOS objective-setup mockup. Replace with the user's
    /// pending objective inputs once the v2 objective-setup flow saves them.
    func load(
        objectiveType: String = "interview_preparation",
        specifics: [String: String] = ["targetRole": "SDE", "targetCompany": "Google"],
        timeline: String = "6_months",
        currentLevel: String = "intermediate"
    ) async {
        isLoading = true
        error = nil
        do {
            let body = V2RequiredTimeRequest(
                objectiveType: objectiveType,
                specifics: specifics,
                timeline: timeline,
                currentLevel: currentLevel
            )
            let resp: V2APIResponse<V2RequiredTimeResponse> = try await V2APIClient.shared.post("/objective/required-time", body: body)
            data = resp.data
        } catch {
            self.error = "Couldn't compute required time. Pull to retry."
            data = nil
        }
        isLoading = false
    }
}
