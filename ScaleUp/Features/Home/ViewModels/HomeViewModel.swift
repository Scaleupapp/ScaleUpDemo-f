import SwiftUI

@Observable
@MainActor
final class HomeViewModel {

    var dashboard: Dashboard?
    var continueWatching: [ContentProgress] = []
    var recommendations: [Content] = []
    var trending: [Content] = []
    var allContent: [Content] = []
    var isLoading = false
    var errorMessage: String?

    private let dashboardService = DashboardService()
    private let contentService = ContentService()

    // MARK: - Computed

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    var heroContent: Content? {
        recommendations.first ?? allContent.first
    }

    var isNewUser: Bool {
        let watched = weeklyStats?.totalContentConsumed ?? 0
        return readinessScore == 0 && watched == 0 && continueWatching.isEmpty
    }

    var firstNextAction: NextAction? {
        dashboard?.nextActions?.first
    }

    var readinessScore: Int {
        dashboard?.readinessScore ?? 0
    }

    var weeklyStats: WeeklyStats? {
        dashboard?.weeklyStats
    }

    var pendingQuizzes: Int {
        dashboard?.pendingQuizzes ?? 0
    }

    // MARK: - New Computed Properties

    var primaryObjective: Objective? {
        dashboard?.objectives?.first(where: { $0.isPrimary == true }) ?? dashboard?.objectives?.first
    }

    var journey: JourneyOverview? {
        dashboard?.journey
    }

    var knowledgeProfile: KnowledgeProfile? {
        dashboard?.knowledgeProfile
    }

    var topSkills: [KnowledgeSnapshot] {
        let all = dashboard?.knowledgeSnapshot ?? []
        return Array(all.sorted { $0.score > $1.score }.prefix(5))
    }

    var strengths: [String] {
        dashboard?.knowledgeProfile?.strengths ?? []
    }

    var weaknesses: [String] {
        dashboard?.knowledgeProfile?.weaknesses ?? []
    }

    var upcomingMilestones: [Milestone] {
        dashboard?.upcomingMilestones ?? []
    }

    var weeklyGrowth: WeeklyGrowth? {
        dashboard?.weeklyGrowth
    }

    var weeklyGrowthDelta: Int {
        dashboard?.weeklyGrowth?.contentDelta ?? 0
    }

    // MARK: - Load

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        async let dashboardTask: Dashboard? = {
            try? await self.dashboardService.fetchDashboard()
        }()

        async let watchingTask: [ContentProgress] = {
            (try? await self.dashboardService.fetchContinueWatching()) ?? []
        }()

        async let recsTask: [Content] = {
            (try? await self.contentService.fetchRecommendations()) ?? []
        }()

        async let trendingTask: [Content] = {
            (try? await self.contentService.fetchTrending(limit: 10)) ?? []
        }()

        async let exploreTask: [Content] = {
            (try? await self.contentService.explore(page: 1, limit: 20)) ?? []
        }()

        let (dash, watching, recs, trend, explore) = await (dashboardTask, watchingTask, recsTask, trendingTask, exploreTask)

        dashboard = dash
        continueWatching = watching.filter { $0.isCompleted != true && ($0.percentageCompleted ?? 0) > 0 }
        recommendations = recs
        trending = trend
        allContent = explore

        isLoading = false
    }

    // MARK: - Mock Data

    private func loadMockData() {
        let mockCreator = Creator(
            id: "c1", firstName: "Sarah", lastName: "Johnson", username: "sarahj",
            profilePicture: nil, bio: "Product leader & educator",
            tier: .anchor, followersCount: 12400, contentCount: 45, averageRating: 4.7
        )

        let mockCreator2 = Creator(
            id: "c2", firstName: "Alex", lastName: "Chen", username: "alexc",
            profilePicture: nil, bio: "Data science mentor",
            tier: .core, followersCount: 8200, contentCount: 32, averageRating: 4.5
        )

        let mockCreator3 = Creator(
            id: "c3", firstName: "Priya", lastName: "Sharma", username: "priyas",
            profilePicture: nil, bio: "Career coach",
            tier: .rising, followersCount: 3100, contentCount: 18, averageRating: 4.3
        )

        recommendations = [
            Content(id: "1", creatorId: mockCreator, title: "Product Strategy Fundamentals: Building Your First Roadmap", description: "Learn how to build a product roadmap from scratch", contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1245, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: ["Strategy", "Roadmapping"], tags: ["PM", "strategy"], difficulty: .intermediate, aiData: AIData(summary: "A comprehensive guide to building product roadmaps", keyConcepts: nil, prerequisites: nil, qualityScore: 85), status: .published, viewCount: 14200, likeCount: 890, commentCount: 45, saveCount: 320, averageRating: 4.6, ratingCount: 156, publishedAt: Date().addingTimeInterval(-86400 * 3), createdAt: nil),
            Content(id: "2", creatorId: mockCreator2, title: "SQL for Data Analysis: Advanced Queries & Window Functions", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 2100, sourceType: .youtube, sourceAttribution: nil, domain: "Data Science", topics: ["SQL", "Analytics"], tags: nil, difficulty: .advanced, aiData: nil, status: .published, viewCount: 8900, likeCount: 620, commentCount: 28, saveCount: 445, averageRating: 4.8, ratingCount: 89, publishedAt: Date().addingTimeInterval(-86400 * 1), createdAt: nil),
            Content(id: "3", creatorId: mockCreator3, title: "How to Ace the Product Manager Interview", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 900, sourceType: .original, sourceAttribution: nil, domain: "Career", topics: ["Interviews", "PM"], tags: nil, difficulty: .beginner, aiData: nil, status: .published, viewCount: 22100, likeCount: 1540, commentCount: 92, saveCount: 780, averageRating: 4.5, ratingCount: 234, publishedAt: Date().addingTimeInterval(-86400 * 5), createdAt: nil),
            Content(id: "4", creatorId: mockCreator, title: "User Research Methods That Actually Work", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1800, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: ["User Research", "UX"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 6700, likeCount: 410, commentCount: 18, saveCount: 290, averageRating: 4.4, ratingCount: 78, publishedAt: Date().addingTimeInterval(-86400 * 8), createdAt: nil),
            Content(id: "5", creatorId: mockCreator2, title: "Python Data Pipelines: From CSV to Dashboard", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 2700, sourceType: .youtube, sourceAttribution: nil, domain: "Data Science", topics: ["Python", "ETL"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 11500, likeCount: 780, commentCount: 56, saveCount: 520, averageRating: 4.7, ratingCount: 145, publishedAt: Date().addingTimeInterval(-86400 * 2), createdAt: nil),
            Content(id: "6", creatorId: mockCreator3, title: "Personal Branding for Career Growth", description: nil, contentType: .article, contentURL: nil, thumbnailURL: nil, duration: 480, sourceType: .original, sourceAttribution: nil, domain: "Career", topics: ["Branding", "Growth"], tags: nil, difficulty: .beginner, aiData: nil, status: .published, viewCount: 4200, likeCount: 310, commentCount: 15, saveCount: 180, averageRating: 4.2, ratingCount: 56, publishedAt: Date().addingTimeInterval(-86400 * 10), createdAt: nil)
        ]

        trending = Array(recommendations.prefix(4).shuffled())
        allContent = recommendations

        continueWatching = [
            ContentProgress(contentId: "1", currentPosition: 620, totalDuration: 1245, percentageCompleted: 50, isCompleted: false, totalTimeSpent: 620, sessionCount: 2, content: recommendations[0]),
            ContentProgress(contentId: "5", currentPosition: 810, totalDuration: 2700, percentageCompleted: 30, isCompleted: false, totalTimeSpent: 810, sessionCount: 1, content: recommendations[4])
        ]

        dashboard = Dashboard(
            readinessScore: 64,
            nextActions: [
                NextAction(type: "quiz", message: "You have a quiz ready on Product Management"),
                NextAction(type: "content", message: "Continue: Product Strategy Fundamentals")
            ],
            pendingQuizzes: 2,
            weeklyStats: WeeklyStats(contentConsumed: 7, totalContentConsumed: 34, dominantTopics: ["Product Management", "Data Science"]),
            knowledgeProfile: KnowledgeProfile(
                overallScore: 64,
                totalTopicsCovered: 3,
                totalQuizzesTaken: 2,
                strengths: ["Product Strategy"],
                weaknesses: ["User Research"],
                topicMastery: [
                    KnowledgeSnapshot(topic: "Product Strategy", score: 78, level: "intermediate", trend: .improving),
                    KnowledgeSnapshot(topic: "SQL", score: 65, level: "intermediate", trend: .stable),
                    KnowledgeSnapshot(topic: "User Research", score: 42, level: "beginner", trend: .improving)
                ]
            ),
            objectives: nil,
            journey: nil,
            upcomingMilestones: nil,
            weeklyGrowth: nil
        )
    }
}
