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
        let weeksOverdue: Int?
        // Readiness redesign (v2.2): personalized target + bands (P2 "why this
        // target") and the per-competency breakdown + coverage (P1b "what's in
        // your number"). All optional so older API responses still decode.
        let target: Int?
        let targetBands: TargetBands?
        let coverage: Double?
        let breakdown: [BreakdownItem]?

        struct TargetBands: Codable {
            let competitive: Int
            let strong: Int
            let exceptional: Int
        }
        struct BreakdownItem: Codable, Identifiable, Hashable {
            let name: String
            let weight: Int
            let score: Int
            let assessed: Bool
            let primitive: String
            var id: String { name }
        }
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
        // New role-aware fields (backend commit 01f707c)
        let role: String?
        let creatorTier: String?
        let applicationStatus: String?
    }
}

// MARK: - Analytics (deep "You" payload)

struct V2YouAnalytics: Codable {
    let user: UserBlock
    let objectiveLabel: String?
    let counts: Counts
    let quizPerformance: QuizPerformance
    let timeInvested: TimeInvested
    let velocity: Velocity
    let masteryMap: [MasteryEntry]
    let strengths: [String]
    let weaknesses: [String]
    let cognitive: Cognitive
    let streak: V2YouOverview.StreakBlock
    let recentActivity: [ActivityEntry]
    let achievements: [Achievement]

    struct UserBlock: Codable {
        let name: String
        let firstName: String
        let initial: String
        let avatarURL: String?
        let email: String?
        let role: String
        let memberSince: String?
    }
    struct Counts: Codable {
        let quizzesTaken: Int
        let contentCompleted: Int
        let interviewsTaken: Int
        let compassConversations: Int
        let topicsCovered: Int
    }
    struct QuizPerformance: Codable {
        let trend: [TrendPoint]
        let averageScore: Int?
        let direction: String

        struct TrendPoint: Codable {
            let date: String?
            let score: Int
        }
    }
    struct TimeInvested: Codable {
        let totalMinutes: Int
        let contentMinutes: Int
        let interviewMinutes: Int
    }
    struct Velocity: Codable {
        let topicsPerWeek: Double
        let avgScoreImprovement: Double
        let overallScore: Int
    }
    struct MasteryEntry: Codable, Identifiable {
        var id: String { topic }
        let topic: String
        let score: Int
        let level: String
        let trend: String
        let quizzesTaken: Int
        let lastAssessedAt: String?
    }
    struct Cognitive: Codable {
        let bestTime: BestTime?
        let preferredFormat: String?
        let sessionStyle: SessionStyle?
        let learnerType: String?

        struct BestTime: Codable {
            let block: String?
            let hour: Int?
            let scoreLift: Int
        }
        struct SessionStyle: Codable {
            let style: String
            let medianMinutes: Int
        }
    }
    struct ActivityEntry: Codable, Identifiable {
        var id: String { (at ?? "") + type + (title ?? "") }
        let type: String
        let at: String?
        let title: String?
        let detail: String?
    }
    struct Achievement: Codable, Identifiable {
        var id: String { achievementId }
        let achievementId: String
        let label: String
        let earned: Bool

        enum CodingKeys: String, CodingKey {
            case achievementId = "id"
            case label, earned
        }
    }
}

// MARK: - View Model

@Observable
@MainActor
final class V2YouViewModel {
    var data: V2YouOverview?
    var isLoading = false
    var error: String?

    var analytics: V2YouAnalytics?
    var analyticsLoading = false
    var analyticsError: String?

    /// Creator-only profile (tier, stats, etc.) — loaded after overview when role==creator.
    var creatorStats: CreatorProfileData?

    /// Convenience derived from the freshly-loaded flags. Defaults gracefully
    /// when the new fields are missing (e.g. older backend response).
    var role: String {
        if let r = data?.flags.role, !r.isEmpty { return r }
        if data?.flags.isAdmin == true { return "admin" }
        if data?.flags.isCreator == true { return "creator" }
        return "consumer"
    }

    var isCreatorRole: Bool { role == "creator" }
    var isAdminRole: Bool { role == "admin" }
    var isConsumerOrContributor: Bool { role == "consumer" || role == "contributor" }
    var applicationStatus: String? { data?.flags.applicationStatus }
    var creatorTier: String? { data?.flags.creatorTier }

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

        // After overview, load creator stats if we're a creator.
        if isCreatorRole {
            await loadCreatorStats()
        }
    }

    func loadCreatorStats() async {
        let service = CreatorService()
        creatorStats = try? await service.fetchMyProfile()
    }

    func loadAnalytics() async {
        analyticsLoading = true
        analyticsError = nil
        do {
            let response: V2APIResponse<V2YouAnalytics> = try await V2APIClient.shared.get("/you/analytics")
            analytics = response.data
        } catch {
            self.analyticsError = "Couldn't load your analytics. Pull to refresh."
            self.analytics = nil
        }
        analyticsLoading = false
    }
}
