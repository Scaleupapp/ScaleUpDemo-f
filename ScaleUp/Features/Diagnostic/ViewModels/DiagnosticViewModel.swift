import SwiftUI

// MARK: - Diagnostic View Model

@Observable
@MainActor
final class DiagnosticViewModel {

    // MARK: - Phase

    enum Phase: Equatable {
        case welcome, selfRating, quiz, results, error
    }

    // MARK: - State

    var phase: Phase = .welcome
    var attemptId: String?
    var competencies: [DiagnosticCompetency] = []
    var selfRatings: [String: DiagnosticSelfRating] = [:]
    var currentQuestion: DiagnosticQuestion?
    var currentSelection: String?
    var currentQuestionStartedAt: Date?
    var questionsAnswered = 0
    var totalQuestionsTarget = 0
    var results: DiagnosticResults?
    var errorMessage: String?
    var isLoading = false

    private let service = DiagnosticService()
    private var startedAt: Date?
    private var flowType: String = "new_user"

    // MARK: - Computed

    var canSubmitSelfRatings: Bool {
        guard !competencies.isEmpty else { return false }
        return competencies.allSatisfy { selfRatings[$0.name] != nil }
    }

    var progress: Double {
        guard totalQuestionsTarget > 0 else { return 0 }
        return Double(questionsAnswered) / Double(totalQuestionsTarget)
    }

    // MARK: - Start

    func start() async {
        isLoading = true
        do {
            let attempt = try await service.start()
            attemptId = attempt.attemptId
            flowType = attempt.flowType
            competencies = attempt.competenciesToAssess
            totalQuestionsTarget = competencies.map(\.questionCap).reduce(0, +)
            startedAt = Date()
            phase = .selfRating
            AnalyticsService.shared.track(.diagnosticStarted(flowType: attempt.flowType))
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
        isLoading = false
    }

    // MARK: - Self Rating

    func setRating(_ rating: DiagnosticSelfRating, for competency: String) {
        selfRatings[competency] = rating
    }

    func submitSelfRatings() async {
        guard let attemptId else { return }
        isLoading = true
        do {
            let ratingsPayload = selfRatings.mapValues { $0.rawValue }
            try await service.submitSelfRating(attemptId: attemptId, ratings: ratingsPayload)
            AnalyticsService.shared.track(.diagnosticSelfRatingSubmitted(attemptId: attemptId))
            phase = .quiz
            await loadNextQuestion()
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
        isLoading = false
    }

    // MARK: - Quiz

    func selectOption(_ id: String) {
        currentSelection = id
    }

    func submitCurrentAnswer() async {
        guard let attemptId, let question = currentQuestion, let selection = currentSelection else { return }
        isLoading = true
        let timeTaken = Date().timeIntervalSince(currentQuestionStartedAt ?? Date())
        do {
            try await service.submitAnswer(
                attemptId: attemptId,
                questionId: question.id,
                selectedAnswer: selection,
                timeTaken: timeTaken
            )
            questionsAnswered += 1
            await loadNextQuestion()
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
        isLoading = false
    }

    func loadNextQuestion() async {
        guard let attemptId else { return }
        do {
            let next = try await service.nextQuestion(attemptId: attemptId)
            if next.done == true || next.question == nil {
                await finish()
            } else {
                currentQuestion = next.question
                currentSelection = nil
                currentQuestionStartedAt = Date()
            }
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
    }

    func finish() async {
        guard let attemptId else { return }
        isLoading = true
        do {
            let finishResults = try await service.finish(attemptId: attemptId)
            results = finishResults
            phase = .results
            let avgScore: Int
            if finishResults.perCompetency.isEmpty {
                avgScore = 0
            } else {
                let total = finishResults.perCompetency.map(\.score).reduce(0, +)
                avgScore = Int((Double(total) / Double(finishResults.perCompetency.count)).rounded())
            }
            let duration = Int(Date().timeIntervalSince(startedAt ?? Date()))
            AnalyticsService.shared.track(.diagnosticFinished(
                attemptId: attemptId,
                durationSeconds: duration,
                score: avgScore
            ))
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
        isLoading = false
    }

    // MARK: - Retry

    func retry() async {
        errorMessage = nil
        isLoading = true
        // Reset to welcome so the user can restart the flow cleanly.
        phase = .welcome
        isLoading = false
    }

    // MARK: - Abandon

    func abandonCurrent(at step: String) async {
        let id = attemptId ?? ""
        AnalyticsService.shared.track(.diagnosticAbandoned(attemptId: id, atStep: step))
        if let attemptId {
            Task { try? await service.abandon(attemptId: attemptId) }
        }
    }
}
