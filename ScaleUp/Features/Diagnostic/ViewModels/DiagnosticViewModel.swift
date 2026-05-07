import SwiftUI

// MARK: - Diagnostic View Model

@Observable
@MainActor
final class DiagnosticViewModel {

    // MARK: - Phase

    enum Phase: Equatable {
        case welcome, selfRating, preparing, quiz, results, error
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

    // MARK: - Plan 3a Task 9 / Task 11 — per-topic progress + voice routing
    // Per-topic progress state. Task 11 wires these to the actual
    // adaptive diagnostic engine state.
    var currentTopicIndex: Int = 0
    var totalTopicCount: Int = 0
    var currentTopicName: String = ""
    var nextTopicName: String = ""
    var showingTransition: Bool = false
    /// True when the currently-displayed question is a voice question
    /// (BE V2 returns `type: "voice"`). Routes the container view to
    /// render `DiagnosticVoiceAnswerView` instead of `DiagnosticQuestionView`.
    var isVoiceQuestion: Bool = false

    /// Tracks the most-recently-shown competency so we can detect topic
    /// transitions when the next question arrives.
    private var lastShownCompetency: String?

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

    // MARK: - Recalibration Bootstrap
    //
    // Seeds the VM with a server-created recalibration attempt and immediately
    // loads the first question. Skips welcome + self-rating phases entirely;
    // those were captured during the original diagnostic.

    func prepareForRecalibration(attemptId: String, totalQuestions: Int) async {
        self.attemptId = attemptId
        self.totalQuestionsTarget = totalQuestions
        self.startedAt = Date()
        self.phase = .preparing
        await loadNextQuestion()
        if currentQuestion != nil {
            self.phase = .quiz
        }
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
            // Plan 3a Task 11: seed per-topic progress so the chip renders.
            totalTopicCount = competencies.count
            currentTopicIndex = 0
            currentTopicName = competencies.first?.name ?? ""
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
        phase = .preparing
        do {
            let ratingsPayload = selfRatings.mapValues { $0.rawValue }
            try await service.submitSelfRating(attemptId: attemptId, ratings: ratingsPayload)
            AnalyticsService.shared.track(.diagnosticSelfRatingSubmitted(attemptId: attemptId))
            await loadNextQuestion()
            phase = .quiz
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
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
            MixpanelDiagnostic.trackQuestionAnswered(
                questionId: question.id,
                competency: question.canonicalCompetency ?? question.competency,
                type: question.type ?? "mcq",
                timeMs: Int(timeTaken * 1000)
            )
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
            } else if let question = next.question {
                // Plan 3a Task 11: detect topic transition + voice routing
                // before rendering the new question.
                handleQuestionTransition(
                    previousCompetency: lastShownCompetency,
                    nextCompetency: question.canonicalCompetency ?? question.competency,
                    nextQuestionType: question.type
                )
                currentQuestion = question
                currentSelection = nil
                currentQuestionStartedAt = Date()
                lastShownCompetency = question.canonicalCompetency ?? question.competency
                MixpanelDiagnostic.trackQuestionShown(
                    questionId: question.id,
                    competency: question.canonicalCompetency ?? question.competency,
                    type: question.type ?? "mcq",
                    topicIndex: currentTopicIndex,
                    topicTotal: totalTopicCount
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
    }

    // MARK: - Plan 3a Task 11 — Per-topic transition + voice routing

    /// Update transition + voice-question state when moving from one question
    /// to the next. Called from `loadNextQuestion` whenever a new question
    /// arrives. If the topic changed, briefly shows the transition card.
    func handleQuestionTransition(
        previousCompetency: String?,
        nextCompetency: String,
        nextQuestionType: String?
    ) {
        if let prev = previousCompetency, prev != nextCompetency {
            // Topic changed — fire topicCompleted for the outgoing topic, then advance.
            MixpanelDiagnostic.trackTopicCompleted(
                competency: prev,
                topicIndex: currentTopicIndex,
                topicTotal: totalTopicCount
            )
            nextTopicName = nextCompetency
            showingTransition = true
            currentTopicIndex = min(currentTopicIndex + 1, max(totalTopicCount - 1, 0))
        }
        currentTopicName = nextCompetency
        isVoiceQuestion = (nextQuestionType == "voice")
    }

    /// Submit a successful voice answer result. The voice endpoint already
    /// recorded scoring server-side; locally we just advance to the next
    /// question. Voice scoring is a band, not correct/incorrect, so we
    /// don't go through the typed `submitAnswer` flow.
    func handleVoiceAnswerComplete(_ result: VoiceAnswerResult) {
        if let q = currentQuestion {
            MixpanelDiagnostic.trackVoiceUsed(
                questionId: q.id,
                competency: q.canonicalCompetency ?? q.competency,
                durationSec: 0
            )
        }
        questionsAnswered += 1
        Task { await self.loadNextQuestion() }
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
