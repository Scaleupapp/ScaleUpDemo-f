import SwiftUI

// MARK: - Knowledge Profile View Model

@Observable
final class KnowledgeProfileViewModel {

    // MARK: - Published State

    var profile: KnowledgeProfile?
    var stats: ProgressStats?
    var gapRecommendations: [Content] = []
    var isLoading: Bool = false
    var error: APIError?

    // MARK: - Dependencies

    private let knowledgeService: KnowledgeService
    private let progressService: ProgressService
    private let recommendationService: RecommendationService

    // MARK: - Init

    init(
        knowledgeService: KnowledgeService,
        progressService: ProgressService,
        recommendationService: RecommendationService
    ) {
        self.knowledgeService = knowledgeService
        self.progressService = progressService
        self.recommendationService = recommendationService
    }

    // MARK: - Load Profile

    /// Fetches the knowledge profile, progress stats, and gap recommendations concurrently.
    @MainActor
    func loadProfile() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let ks = knowledgeService
            let ps = progressService
            let rs = recommendationService
            async let profileTask = ks.profile()
            async let statsTask = ps.stats()
            async let gapsTask = rs.gaps()

            let (fetchedProfile, fetchedStats, fetchedGaps) = try await (
                profileTask,
                statsTask,
                gapsTask
            )

            self.profile = fetchedProfile
            self.stats = fetchedStats
            self.gapRecommendations = fetchedGaps
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Refresh

    /// Refreshes all data without showing the full loading state.
    @MainActor
    func refresh() async {
        error = nil

        do {
            let ks = knowledgeService
            let ps = progressService
            let rs = recommendationService
            async let profileTask = ks.profile()
            async let statsTask = ps.stats()
            async let gapsTask = rs.gaps()

            let (fetchedProfile, fetchedStats, fetchedGaps) = try await (
                profileTask,
                statsTask,
                gapsTask
            )

            self.profile = fetchedProfile
            self.stats = fetchedStats
            self.gapRecommendations = fetchedGaps
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    /// All topics sorted by score descending (highest mastery first).
    var sortedTopics: [TopicMastery] {
        profile?.topicMastery.sorted { $0.score > $1.score } ?? []
    }

    /// Top strengths from the knowledge profile.
    var topStrengths: [String] {
        profile?.strengths ?? []
    }

    /// Top weaknesses from the knowledge profile.
    var topWeaknesses: [String] {
        profile?.weaknesses ?? []
    }

    /// Overall score as an integer for display.
    var overallScoreInt: Int {
        Int(profile?.overallScore ?? 0)
    }

    /// Total topics covered.
    var totalTopicsCovered: Int {
        profile?.totalTopicsCovered ?? 0
    }

    /// Total quizzes taken.
    var totalQuizzesTaken: Int {
        profile?.totalQuizzesTaken ?? 0
    }

    /// Formatted hours learned from total time spent (seconds).
    var hoursLearned: String {
        let totalSeconds = Int(stats?.totalTimeSpent ?? 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Total lessons completed.
    var lessonsCompleted: Int {
        stats?.totalContentConsumed ?? 0
    }

    /// Total topics explored.
    var topicsExplored: Int {
        stats?.topicCount ?? 0
    }

    /// Whether the profile has any data to display.
    var hasData: Bool {
        profile != nil && (profile?.totalQuizzesTaken ?? 0) > 0
    }

    /// Score for a specific topic name (used by strengths/weaknesses).
    func scoreForTopic(_ topicName: String) -> Int {
        let mastery = profile?.topicMastery.first { $0.topic.lowercased() == topicName.lowercased() }
        return Int(mastery?.score ?? 0)
    }

    /// Gap recommendations filtered by a specific topic.
    func gapRecommendationsForTopic(_ topicName: String) -> [Content] {
        gapRecommendations.filter { content in
            content.topics.contains { $0.lowercased() == topicName.lowercased() }
        }
    }
}
