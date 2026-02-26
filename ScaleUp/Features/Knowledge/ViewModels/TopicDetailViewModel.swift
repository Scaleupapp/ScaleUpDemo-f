import SwiftUI

// MARK: - Topic Detail View Model

@Observable
final class TopicDetailViewModel {

    // MARK: - Published State

    let topicName: String
    var mastery: TopicMastery?
    var gapContent: [Content] = []
    var isLoading: Bool = false
    var error: APIError?

    // MARK: - Dependencies

    private let knowledgeService: KnowledgeService
    private let recommendationService: RecommendationService

    // MARK: - Init

    init(
        topicName: String,
        knowledgeService: KnowledgeService,
        recommendationService: RecommendationService
    ) {
        self.topicName = topicName
        self.knowledgeService = knowledgeService
        self.recommendationService = recommendationService
    }

    // MARK: - Load Topic

    /// Fetches topic detail and gap-filling recommendations concurrently.
    @MainActor
    func loadTopic() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let ks = knowledgeService
            let rs = recommendationService
            let topic = topicName
            async let masteryTask = ks.topic(name: topic)
            async let gapsTask = rs.gaps()

            let (fetchedMastery, fetchedGaps) = try await (
                masteryTask,
                gapsTask
            )

            self.mastery = fetchedMastery
            // Filter gap recommendations to those related to this topic
            self.gapContent = fetchedGaps.filter { content in
                content.topics.contains { $0.lowercased() == topicName.lowercased() }
            }
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Computed Properties

    /// Score as integer for display.
    var scoreInt: Int {
        Int(mastery?.score ?? 0)
    }

    /// Score as progress fraction (0.0 to 1.0).
    var scoreProgress: Double {
        (mastery?.score ?? 0) / 100.0
    }

    /// Display-friendly level name.
    var levelDisplayName: String {
        guard let level = mastery?.level else { return "Not Started" }
        switch level {
        case .notStarted: return "Not Started"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }

    /// Color associated with the mastery level.
    var levelColor: Color {
        guard let level = mastery?.level else { return ColorTokens.textTertiaryDark }
        switch level {
        case .expert: return ColorTokens.anchorGold
        case .advanced: return ColorTokens.primary
        case .intermediate: return ColorTokens.info
        case .beginner: return ColorTokens.textSecondaryDark
        case .notStarted: return ColorTokens.textTertiaryDark
        }
    }

    /// Trend display icon.
    var trendIcon: String {
        guard let trend = mastery?.trend else { return "arrow.right" }
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    /// Trend display label.
    var trendLabel: String {
        guard let trend = mastery?.trend else { return "Stable" }
        switch trend {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }

    /// Trend display color.
    var trendColor: Color {
        guard let trend = mastery?.trend else { return ColorTokens.textSecondaryDark }
        switch trend {
        case .improving: return ColorTokens.success
        case .stable: return ColorTokens.textSecondaryDark
        case .declining: return ColorTokens.error
        }
    }

    /// Formatted "last assessed" date string.
    var lastAssessedFormatted: String? {
        guard let dateString = mastery?.lastAssessedAt else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = isoFormatter.date(from: dateString)
            ?? ISO8601DateFormatter().date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }

    /// Number of quizzes taken for this topic.
    var quizCount: Int {
        mastery?.quizzesTaken ?? 0
    }
}
