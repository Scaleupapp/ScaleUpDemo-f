import SwiftUI

@Observable
@MainActor
final class QuizResultsViewModel {

    var quiz: Quiz?
    var results: QuizEnrichedResults?
    var isLoading = false
    var showAnswerReview = false

    private let quizService = QuizService()

    // MARK: - Computed

    var score: QuizScore? { results?.score }
    var analysis: QuizAnalysis? { results?.analysis }
    var topicBreakdown: [TopicBreakdown] { results?.topicBreakdown ?? [] }
    var competencyBreakdown: [CompetencyBreakdownItem] { results?.competencyBreakdown ?? [] }
    var competency: CompetencyData? { results?.competency }
    var recommendedContent: [Content] { results?.recommendedContent ?? [] }
    var journeyImpact: JourneyImpact? { results?.journeyImpact }
    var nextActions: [QuizNextAction] { results?.nextActions ?? [] }

    var scorePercentage: Double { score?.percentage ?? 0 }

    var scoreGrade: String {
        let pct = scorePercentage
        if pct >= 90 { return "Excellent!" }
        if pct >= 80 { return "Great Job!" }
        if pct >= 70 { return "Good Work!" }
        if pct >= 50 { return "Keep Learning" }
        return "Needs Review"
    }

    var scoreColor: Color {
        let pct = scorePercentage
        if pct >= 80 { return ColorTokens.gold }
        if pct >= 60 { return .orange }
        return .red
    }

    var trendIcon: String {
        guard let trend = analysis?.comparisonToPrevious?.trend else { return "minus" }
        switch trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "minus"
        }
    }

    var trendColor: Color {
        guard let trend = analysis?.comparisonToPrevious?.trend else { return ColorTokens.textTertiary }
        switch trend {
        case "improving": return .green
        case "declining": return .red
        default: return .orange
        }
    }

    var formattedTotalTime: String {
        guard let time = results?.totalTime else { return "--" }
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }

    // MARK: - Load

    func loadResults(quizId: String) async {
        isLoading = true

        // Fetch quiz detail and results in parallel
        async let quizTask: Quiz? = {
            try? await self.quizService.fetchQuiz(id: quizId)
        }()
        async let resultsTask: QuizEnrichedResults? = {
            try? await self.quizService.fetchResults(quizId: quizId)
        }()

        let (q, r) = await (quizTask, resultsTask)
        quiz = q
        results = r

        if results == nil {
            loadMockResults()
        }

        isLoading = false
    }

    func loadFromAttempt(_ attempt: QuizAttempt, quiz: Quiz?) {
        self.quiz = quiz
        self.results = QuizEnrichedResults(
            score: attempt.score,
            analysis: attempt.analysis,
            answers: attempt.answers,
            topicBreakdown: attempt.topicBreakdown,
            competencyBreakdown: attempt.competencyBreakdown,
            completedAt: attempt.completedAt,
            totalTime: attempt.totalTime,
            competency: nil,
            recommendedContent: nil,
            journeyImpact: nil,
            nextActions: nil
        )

        // Try to fetch enriched results
        if let quizInfo = attempt.quizId {
            Task {
                if let enriched = try? await quizService.fetchResults(quizId: quizInfo.id) {
                    self.results = enriched
                }
            }
        }
    }

    private func loadMockResults() {
        results = QuizEnrichedResults(
            score: QuizScore(total: 10, correct: 7, incorrect: 2, skipped: 1, percentage: 70),
            analysis: QuizAnalysis(
                strengths: ["Product Strategy", "User Research", "Roadmapping"],
                weaknesses: ["Metrics", "Prioritization"],
                missedConcepts: [
                    MissedConcept(concept: "RICE Framework", contentId: nil, timestamp: "4:30", suggestion: "Review the prioritization framework section"),
                    MissedConcept(concept: "North Star Metric", contentId: nil, timestamp: "8:15", suggestion: "Watch the metrics definition segment")
                ],
                confidenceScore: 65,
                comparisonToPrevious: ComparisonData(previousScore: 60, improvement: 10, trend: "improving")
            ),
            answers: nil,
            topicBreakdown: [
                TopicBreakdown(topic: "Product Strategy", correct: 3, total: 3, percentage: 100),
                TopicBreakdown(topic: "User Research", correct: 2, total: 2, percentage: 100),
                TopicBreakdown(topic: "Metrics", correct: 1, total: 3, percentage: 33),
                TopicBreakdown(topic: "Prioritization", correct: 1, total: 2, percentage: 50)
            ],
            competencyBreakdown: nil,
            completedAt: Date(),
            totalTime: 420,
            competency: CompetencyData(
                topic: "product management", level: "intermediate", score: 72,
                quizzesTaken: 5, trend: "improving",
                scoreHistory: [
                    ScoreHistoryEntry(score: 45, date: Date().addingTimeInterval(-86400 * 30)),
                    ScoreHistoryEntry(score: 55, date: Date().addingTimeInterval(-86400 * 20)),
                    ScoreHistoryEntry(score: 62, date: Date().addingTimeInterval(-86400 * 14)),
                    ScoreHistoryEntry(score: 68, date: Date().addingTimeInterval(-86400 * 7)),
                    ScoreHistoryEntry(score: 72, date: Date())
                ]
            ),
            recommendedContent: nil,
            journeyImpact: JourneyImpact(
                currentWeek: 3, totalWeeks: 8, overallProgress: 37.5,
                adaptationHint: "Good progress! Focus on metrics to level up."
            ),
            nextActions: [
                QuizNextAction(type: "study_weak_areas", label: "Study Metrics & Prioritization", contentId: nil, topic: nil),
                QuizNextAction(type: "continue_journey", label: "Continue Your Journey", contentId: nil, topic: nil),
                QuizNextAction(type: "explore_topic", label: "Explore more PM content", contentId: nil, topic: "product management")
            ]
        )
    }
}

// QuizEnrichedResults uses memberwise init from the struct definition
