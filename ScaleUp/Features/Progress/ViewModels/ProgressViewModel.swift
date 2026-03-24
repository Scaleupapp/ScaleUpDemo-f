import SwiftUI

@Observable
@MainActor
final class ProgressViewModel {

    // MARK: - State

    var knowledgeProfile: FullKnowledgeProfile?
    var consumptionStats: ConsumptionStats?
    var gaps: [KnowledgeGap] = []
    var gapContent: [Content] = []
    var dashboard: Dashboard?
    var quizHistory: [QuizAttempt] = []
    var activityHeatmap: [ActivityDay] = []
    var timelineEvents: [TimelineEvent] = []
    var competitionStats: CompetitionStats? = nil
    var weeklyBoard: WeeklyLeaderboard? = nil
    var isLoading = false
    var errorMessage: String?
    var showAllObjectives = false

    private let knowledgeService = KnowledgeService()
    private let recommendationService = RecommendationService()
    private let dashboardService = DashboardService()
    private let quizService = QuizService()
    private let competitionService = CompetitionService()

    // MARK: - Computed

    var overallScore: Int {
        knowledgeProfile?.overallScore ?? dashboard?.knowledgeProfile?.overallScore ?? 0
    }

    var readinessScore: Int {
        dashboard?.readinessScore ?? 0
    }

    var totalQuizzes: Int {
        knowledgeProfile?.totalQuizzesTaken ?? 0
    }

    var totalTopics: Int {
        knowledgeProfile?.totalTopicsCovered ?? 0
    }

    var topicMastery: [TopicMasteryEntry] {
        knowledgeProfile?.topicMastery ?? []
    }

    var strengths: [String] {
        knowledgeProfile?.strengths ?? dashboard?.knowledgeProfile?.strengths ?? []
    }

    var weaknesses: [String] {
        knowledgeProfile?.weaknesses ?? dashboard?.knowledgeProfile?.weaknesses ?? []
    }

    var velocity: LearningVelocity? {
        knowledgeProfile?.learningVelocity
    }

    var behavioral: BehavioralProfile? {
        knowledgeProfile?.behavioralProfile
    }

    var weeklyGrowth: WeeklyGrowth? {
        dashboard?.weeklyGrowth
    }

    var currentStreak: Int {
        dashboard?.journey?.progress?.currentStreak ?? 0
    }

    var longestStreak: Int {
        dashboard?.journey?.progress?.longestStreak ?? 0
    }

    // MARK: - Load

    func loadProfile(objectiveId: String? = nil) async {
        isLoading = true
        errorMessage = nil

        async let profileTask: FullKnowledgeProfile? = {
            try? await self.knowledgeService.getProfile(objectiveId: objectiveId)
        }()
        async let gapsTask: [KnowledgeGap]? = {
            try? await self.knowledgeService.getGaps(objectiveId: objectiveId)
        }()
        async let statsTask: ConsumptionStats? = {
            try? await self.knowledgeService.getConsumptionStats(objectiveId: objectiveId)
        }()
        async let dashTask: Dashboard? = {
            try? await self.dashboardService.fetchDashboard()
        }()
        async let gapContentTask: [Content]? = {
            try? await self.recommendationService.getGapContent(limit: 6)
        }()
        async let quizTask: [QuizAttempt]? = {
            try? await self.quizService.fetchQuizHistory()
        }()
        async let heatmapTask: [ActivityDay]? = {
            try? await self.knowledgeService.getActivityHeatmap(days: 90, objectiveId: objectiveId)
        }()
        async let timelineTask: [TimelineEvent]? = {
            try? await self.knowledgeService.getTimeline(limit: 20, objectiveId: objectiveId)
        }()
        async let compStatsTask: CompetitionStats? = {
            try? await self.competitionService.fetchCompetitionStats()
        }()
        async let compBoardTask: WeeklyLeaderboard? = {
            try? await self.competitionService.fetchWeeklyLeaderboard()
        }()

        let (profile, gapsResult, stats, dash, gapContentResult, quizzes, heatmap, timeline, compStats, compBoard) =
            await (profileTask, gapsTask, statsTask, dashTask, gapContentTask, quizTask, heatmapTask, timelineTask, compStatsTask, compBoardTask)

        knowledgeProfile = profile
        gaps = gapsResult ?? []
        consumptionStats = stats
        dashboard = dash
        gapContent = gapContentResult ?? []
        quizHistory = quizzes ?? []
        activityHeatmap = heatmap ?? []
        timelineEvents = timeline ?? []
        competitionStats = compStats
        weeklyBoard = compBoard

        isLoading = false
    }

    // MARK: - Mock Data

    private func loadMockData() {
        knowledgeProfile = FullKnowledgeProfile(
            topicMastery: [
                TopicMasteryEntry(topic: "Product-Market Fit", score: 78, level: "intermediate", quizzesTaken: 4, lastAssessedAt: Date(), scoreHistory: [
                    ScoreHistoryEntry(score: 45, date: Date().addingTimeInterval(-86400 * 28)),
                    ScoreHistoryEntry(score: 58, date: Date().addingTimeInterval(-86400 * 21)),
                    ScoreHistoryEntry(score: 68, date: Date().addingTimeInterval(-86400 * 14)),
                    ScoreHistoryEntry(score: 72, date: Date().addingTimeInterval(-86400 * 7)),
                    ScoreHistoryEntry(score: 78, date: Date())
                ], trend: .improving),
                TopicMasteryEntry(topic: "User Research", score: 65, level: "intermediate", quizzesTaken: 3, lastAssessedAt: Date(), scoreHistory: nil, trend: .stable),
                TopicMasteryEntry(topic: "Metrics & Analytics", score: 52, level: "beginner", quizzesTaken: 2, lastAssessedAt: Date(), scoreHistory: nil, trend: .improving),
                TopicMasteryEntry(topic: "Prioritization", score: 40, level: "beginner", quizzesTaken: 1, lastAssessedAt: Date(), scoreHistory: nil, trend: nil),
                TopicMasteryEntry(topic: "Roadmapping", score: 35, level: "beginner", quizzesTaken: 1, lastAssessedAt: Date(), scoreHistory: nil, trend: .declining),
                TopicMasteryEntry(topic: "Stakeholder Mgmt", score: 68, level: "intermediate", quizzesTaken: 2, lastAssessedAt: Date(), scoreHistory: nil, trend: .stable)
            ],
            learningVelocity: LearningVelocity(topicsPerWeek: 2.5, averageScoreImprovement: 8.3, contentToMasteryRatio: 4.2),
            retention: RetentionData(averageRetentionRate: 0.82, optimalReviewInterval: 5),
            behavioralProfile: BehavioralProfile(type: "balanced_learner", averageAnswerTime: 28.5, peakHours: [9, 10, 20, 21], consistencyScore: 0.75),
            strengths: ["Product-Market Fit", "Stakeholder Mgmt", "User Research"],
            weaknesses: ["Roadmapping", "Prioritization"],
            overallScore: 72,
            totalQuizzesTaken: 13,
            totalTopicsCovered: 6
        )

        gaps = [
            KnowledgeGap(topic: "Roadmapping", score: 35, level: "beginner", quizzesTaken: 1, suggestion: "Focus on roadmap frameworks and prioritization techniques"),
            KnowledgeGap(topic: "Prioritization", score: 40, level: "beginner", quizzesTaken: 1, suggestion: "Study RICE, ICE, and weighted scoring methods")
        ]

        consumptionStats = ConsumptionStats(
            totalContentConsumed: 28,
            totalTimeSpent: 36000,
            dominantTopics: ["Product-Market Fit", "User Research", "Metrics"],
            topicCount: 6,
            topicBreakdown: [
                TopicBreakdownStat(topic: "Product-Market Fit", contentConsumed: 10, affinityScore: 0.85),
                TopicBreakdownStat(topic: "User Research", contentConsumed: 7, affinityScore: 0.72),
                TopicBreakdownStat(topic: "Metrics", contentConsumed: 5, affinityScore: 0.65),
                TopicBreakdownStat(topic: "Prioritization", contentConsumed: 3, affinityScore: 0.45),
                TopicBreakdownStat(topic: "Roadmapping", contentConsumed: 2, affinityScore: 0.38),
                TopicBreakdownStat(topic: "Stakeholder Mgmt", contentConsumed: 1, affinityScore: 0.55)
            ]
        )

        dashboard = Dashboard(
            readinessScore: 58,
            nextActions: nil,
            pendingQuizzes: 2,
            weeklyStats: WeeklyStats(contentConsumed: 7, totalContentConsumed: 28, dominantTopics: ["Product-Market Fit"]),
            knowledgeProfile: nil,
            objectives: nil,
            journey: nil,
            upcomingMilestones: nil,
            weeklyGrowth: WeeklyGrowth(contentDelta: 2, contentThisWeek: 7, contentLastWeek: 5)
        )

        gapContent = [
            Content(id: "gap1", creatorId: nil, title: "Roadmapping 101: Building Product Roadmaps", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1500, sourceType: .youtube, sourceAttribution: nil, domain: "Product Management", topics: ["Roadmapping"], tags: nil, difficulty: .beginner, aiData: nil, status: .published, viewCount: 4200, likeCount: 280, commentCount: 18, saveCount: 150, averageRating: 4.7, ratingCount: 67, publishedAt: Date(), createdAt: nil),
            Content(id: "gap2", creatorId: nil, title: "RICE Framework: Prioritization Masterclass", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1200, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: ["Prioritization"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 3100, likeCount: 190, commentCount: 12, saveCount: 95, averageRating: 4.5, ratingCount: 42, publishedAt: Date(), createdAt: nil)
        ]
    }
}
