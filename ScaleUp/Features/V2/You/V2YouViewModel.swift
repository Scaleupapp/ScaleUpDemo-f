import Foundation

// MARK: - Models

struct V2YouOverview: Codable {
    let user: UserBlock
    let readiness: ReadinessBlock
    let weekProgress: WeekProgressBlock?
    let streak: StreakBlock
    let topGap: TopGapBlock?
    let timeInvested: TimeBlock
    let flags: FlagsBlock
    let objectiveLabel: String?

    struct UserBlock: Codable {
        let name: String
        let firstName: String
        let initial: String
        let avatarURL: String?
        let role: String
    }
    struct ReadinessBlock: Codable {
        let score: Int
        let onTrackText: String
        let targetDate: String?
        let weeksRemaining: Int?
    }
    struct WeekProgressBlock: Codable {
        let done: Int
        let total: Int
        let week: Int
    }
    struct StreakBlock: Codable {
        let current: Int
        let longest: Int
    }
    struct TopGapBlock: Codable {
        let topic: String
        let masteryPct: Int
        let ctaLabel: String
    }
    struct TimeBlock: Codable {
        let hours: Int
    }
    struct FlagsBlock: Codable {
        let isCreator: Bool
        let isAdmin: Bool
    }
}

// MARK: - View Model

@Observable
@MainActor
final class V2YouViewModel {
    var data: V2YouOverview?
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            let response: V2APIResponse<V2YouOverview> = try await V2APIClient.shared.get("/you/overview")
            data = response.data
        } catch {
            self.error = "Couldn't load your overview. Pull to refresh."
            self.data = nil
        }
        isLoading = false
    }
}
