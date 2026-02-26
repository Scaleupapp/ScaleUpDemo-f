import SwiftUI

// MARK: - Quiz Results View Model

@Observable
@MainActor
final class QuizResultsViewModel {

    // MARK: - State

    var attempt: QuizAttempt?
    var quiz: Quiz?
    var showReview: Bool = false
    var isLoading: Bool = false
    var error: APIError?

    // MARK: - Dependencies

    private let quizService: QuizService

    // MARK: - Init

    init(quizService: QuizService) {
        self.quizService = quizService
    }

    // MARK: - Load Results

    /// Loads full results including correct answers for a completed quiz.
    func loadResults(quizId: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            async let quizTask = quizService.getQuiz(id: quizId)
            async let resultsTask = quizService.results(id: quizId)

            let (loadedQuiz, loadedAttempt) = try await (quizTask, resultsTask)
            self.quiz = loadedQuiz
            self.attempt = loadedAttempt
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Computed Properties

    var isHighScore: Bool {
        guard let score else { return false }
        return score.percentage >= 80
    }

    var score: QuizScore? {
        attempt?.score
    }

    var analysis: QuizAnalysis? {
        attempt?.analysis
    }

    var topicBreakdown: [TopicBreakdown]? {
        attempt?.topicBreakdown
    }

    var scorePercentage: Int {
        Int(score?.percentage ?? 0)
    }

    var strengths: [String] {
        analysis?.strengths ?? []
    }

    var weaknesses: [String] {
        analysis?.weaknesses ?? []
    }

    var missedConcepts: [MissedConcept] {
        analysis?.missedConcepts ?? []
    }

    var comparison: ComparisonToPrevious? {
        analysis?.comparisonToPrevious
    }

    var trendText: String? {
        guard let comparison else { return nil }
        guard let improvement = comparison.improvement else { return nil }
        let trend = comparison.trend

        let sign = improvement >= 0 ? "+" : ""
        let arrow: String
        switch trend {
        case .improving: arrow = "\u{2191}"
        case .declining: arrow = "\u{2193}"
        case .stable: arrow = "\u{2192}"
        case .none: arrow = ""
        }

        return "\(arrow) \(sign)\(Int(improvement))% from previous"
    }
}
