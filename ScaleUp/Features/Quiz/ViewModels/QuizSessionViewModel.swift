import SwiftUI

@Observable
@MainActor
final class QuizSessionViewModel {

    // MARK: - State

    var quiz: Quiz?
    var attemptId: String?
    var currentIndex = 0
    var answers: [Int: String] = [:]   // questionIndex → "A"/"B"/"C"/"D"
    var textResponses: [Int: String] = [:]  // questionIndex → text response
    var timeTaken: [Int: Double] = [:]
    var timeRemaining: Int = 60
    var isSubmitting = false
    var isCompleting = false
    var isStarting = false
    var hasCompleted = false
    var completedAttempt: QuizAttempt?
    var errorMessage: String?
    /// Hard error from start/complete — when set, QuizSessionView shows an
    /// error state with Retry/Back buttons instead of the quiz UI. Replaces
    /// the previous "silent local-only mode" fallback which masked 404s and
    /// stranded users in a results-screen-that-also-404s loop.
    var loadError: String?
    /// Server told us the user already completed this quiz — caller should
    /// route directly to the results screen instead of asking them to
    /// re-answer (which would 404 on completeQuiz again).
    var alreadyCompleted = false

    // Timer
    private var timerTask: Task<Void, Never>?
    private var questionStartTime: Date?

    private let quizService = QuizService()

    // MARK: - Computed

    var totalQuestions: Int { quiz?.totalQuestions ?? 0 }
    var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentIndex + 1) / Double(totalQuestions)
    }

    var currentQuestion: QuizQuestion? {
        guard let quiz, currentIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentIndex]
    }

    var selectedAnswer: String? {
        answers[currentIndex]
    }

    var isLastQuestion: Bool {
        currentIndex >= totalQuestions - 1
    }

    var answeredCount: Int {
        answers.count
    }

    var timeRemainingFormatted: String {
        let mins = timeRemaining / 60
        let secs = timeRemaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var currentQuestionTimeLimit: Int {
        currentQuestion?.effectiveTimeLimit ?? quiz?.timePerQuestionSeconds ?? 60
    }

    var timeRemainingProgress: Double {
        return Double(timeRemaining) / Double(currentQuestionTimeLimit)
    }

    var timeColor: Color {
        if timeRemaining <= 10 { return .red }
        if timeRemaining <= 20 { return .orange }
        return ColorTokens.gold
    }

    // MARK: - Start Quiz

    var currentTextResponse: String {
        get { textResponses[currentIndex] ?? "" }
        set { textResponses[currentIndex] = newValue.isEmpty ? nil : newValue }
    }

    var currentQuestionHasTextInput: Bool {
        currentQuestion?.allowTextResponse == true
    }

    var currentQuestionScenario: String? {
        currentQuestion?.scenario
    }

    // MARK: - Start Quiz

    func startQuiz(_ quiz: Quiz) async {
        self.quiz = quiz
        isStarting = true
        currentIndex = 0
        answers = [:]
        textResponses = [:]
        timeTaken = [:]
        hasCompleted = false
        loadError = nil
        alreadyCompleted = false

        AnalyticsService.shared.track(.quizStarted(
            quizId: quiz.id,
            topic: quiz.topic,
            source: "quiz_list"
        ))
        // Detect content→quiz transition
        AnalyticsService.shared.checkContentToQuizTransition(quizId: quiz.id)

        do {
            let attempt = try await quizService.startQuiz(id: quiz.id)
            attemptId = attempt.id

            // Server may signal that this quiz was already completed in a
            // prior session — route caller straight to results instead of
            // asking the user to re-answer (which would 404 on complete).
            if attempt.status == "completed" {
                completedAttempt = attempt
                alreadyCompleted = true
                hasCompleted = true
                isStarting = false
                return
            }

            // Restore any existing answers
            for answer in attempt.answers {
                answers[answer.questionIndex] = answer.selectedAnswer
            }
        } catch let apiErr as APIError {
            // Defensive regeneration: if the original quiz is gone (expired
            // 7d TTL on an old plan-seeded quiz, or deleted), regenerate a
            // fresh quiz for the same topic via the on-demand path — exactly
            // what V2QuizRequestLoaderSheet does. This lets old plans with
            // stale quizIds still work without the user seeing an error.
            if case .notFound = apiErr {
                let regenerated = await regenerateAndStart(for: quiz)
                if !regenerated {
                    loadError = "This quiz isn't available anymore. We tried to build a fresh one but couldn't reach the server. Try again in a moment."
                    isStarting = false
                    return
                }
                isStarting = false
                startTimer()
                return
            }
            loadError = "Couldn't start this quiz. Please pull to refresh or try a different one."
            isStarting = false
            return
        } catch {
            loadError = "Couldn't start this quiz. Please pull to refresh or try a different one."
            isStarting = false
            return
        }

        isStarting = false
        startTimer()
    }

    /// Re-run startQuiz after a transient failure (network blip, server hiccup).
    func retryStart() async {
        guard let quiz else { return }
        await startQuiz(quiz)
    }

    // MARK: - Select Answer

    func selectAnswer(_ label: String) {
        guard !isSubmitting else { return }
        Haptics.selection()

        let elapsed = questionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        answers[currentIndex] = label
        timeTaken[currentIndex] = elapsed

        // Submit to server (fire-and-forget) — include text response if present
        let qi = currentIndex
        let quizId = quiz?.id ?? ""
        let text = textResponses[currentIndex]
        Task {
            _ = try? await quizService.submitAnswer(
                quizId: quizId,
                questionIndex: qi,
                selectedAnswer: label,
                timeTaken: elapsed,
                textResponse: text
            )
        }

        // Track answer (correctness unknown client-side — server evaluates)
        AnalyticsService.shared.track(.quizQuestionAnswered(
            quizId: quizId,
            questionIndex: qi,
            correct: nil,
            timeToAnswerMs: Int(elapsed * 1000)
        ))
    }

    // MARK: - Navigation

    func nextQuestion() {
        guard !isLastQuestion else { return }
        stopTimer()
        currentIndex += 1
        startTimer()
    }

    func previousQuestion() {
        guard currentIndex > 0 else { return }
        stopTimer()
        currentIndex -= 1
        startTimer()
    }

    func goToQuestion(_ index: Int) {
        guard index >= 0, index < totalQuestions else { return }
        stopTimer()
        currentIndex = index
        startTimer()
    }

    // MARK: - Skip

    func skipQuestion() {
        if answers[currentIndex] == nil {
            answers[currentIndex] = "skipped"

            let quizId = quiz?.id ?? ""
            let qi = currentIndex
            let elapsed = questionStartTime.map { Date().timeIntervalSince($0) } ?? 0
            Task {
                _ = try? await quizService.submitAnswer(
                    quizId: quizId,
                    questionIndex: qi,
                    selectedAnswer: "skipped",
                    timeTaken: elapsed
                )
            }
        }

        if isLastQuestion {
            Task { await completeQuiz() }
        } else {
            nextQuestion()
        }
    }

    // MARK: - Complete

    func completeQuiz() async {
        guard !isCompleting, let quiz else { return }
        // If startQuiz fell into the error path we never opened an attempt;
        // don't try to complete — surface the same error so the user can
        // back out.
        if loadError != nil {
            isCompleting = false
            return
        }
        isCompleting = true
        stopTimer()

        do {
            let result = try await quizService.completeQuiz(id: quiz.id)
            completedAttempt = result
            hasCompleted = true
            let scorePercent = Int(result.score?.percentage ?? 0)
            AnalyticsService.shared.track(.quizCompleted(
                quizId: quiz.id,
                topic: quiz.topic,
                score: scorePercent,
                totalQuestions: quiz.totalQuestions
            ))
            // If score is weak (<60%), seed remediation window with this topic
            if scorePercent < 60 {
                AnalyticsService.shared.recordQuizCompleted(quizId: quiz.id, weakTopics: [quiz.topic])
            }
            // Let the v2 task router auto-complete a plan task tied to this quiz.
            NotificationCenter.default.post(
                name: .v2QuizCompleted,
                object: nil,
                userInfo: ["quizId": quiz.id]
            )
        } catch {
            // No more silent success-on-failure — if the server can't accept
            // completion we surface a real error so the user isn't bounced to
            // a results screen that will also 404. The session view shows the
            // loadError state with Back/Retry buttons. Server is now idempotent
            // for completeQuiz, so the retry path is safe.
            loadError = "We couldn't submit this quiz. Please try again in a moment."
        }

        isCompleting = false
    }

    /// Retry submission after a transient completeQuiz failure.
    func retryComplete() async {
        loadError = nil
        await completeQuiz()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timeRemaining = currentQuestionTimeLimit
        questionStartTime = Date()

        timerTask = Task {
            while timeRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                timeRemaining -= 1
            }
            // Auto-skip on timeout
            if timeRemaining <= 0 && !Task.isCancelled {
                skipQuestion()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    func cleanup() {
        stopTimer()
    }

    /// Request a fresh quiz for the same topic when the original is missing
    /// (pre-baked plan quizzes that have aged past their `expiresAt`). Polls
    /// the trigger until ready (~up to 60s), swaps the loaded quiz on the
    /// session, and opens a new attempt. Returns true on success.
    private func regenerateAndStart(for staleQuiz: Quiz) async -> Bool {
        let topic = staleQuiz.topic
        guard !topic.isEmpty else { return false }
        do {
            let trigger = try await quizService.requestQuiz(
                topic: topic,
                questionCount: staleQuiz.totalQuestions > 0 ? staleQuiz.totalQuestions : 10
            )
            var newQuizId = trigger.quizId
            if newQuizId == nil, let triggerId = trigger.triggerId {
                for _ in 0..<30 {
                    try? await Task.sleep(for: .seconds(2))
                    let status = try await quizService.checkTriggerStatus(triggerId: triggerId)
                    if let qid = status.quizId { newQuizId = qid; break }
                    if status.status == "failed" { return false }
                }
            }
            guard let newId = newQuizId else { return false }
            let fresh = try await quizService.fetchQuiz(id: newId)
            // Reset session state onto the new quiz and open a real attempt.
            self.quiz = fresh
            currentIndex = 0
            answers = [:]
            textResponses = [:]
            timeTaken = [:]
            let attempt = try await quizService.startQuiz(id: fresh.id)
            attemptId = attempt.id
            for answer in attempt.answers {
                answers[answer.questionIndex] = answer.selectedAnswer
            }
            return true
        } catch {
            return false
        }
    }
}
