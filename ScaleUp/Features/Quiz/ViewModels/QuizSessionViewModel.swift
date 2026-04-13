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

            // Restore any existing answers
            for answer in attempt.answers {
                answers[answer.questionIndex] = answer.selectedAnswer
            }
        } catch {
            // Continue with local-only mode
            attemptId = "local-\(quiz.id)"
        }

        isStarting = false
        startTimer()
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
        } catch {
            // Build local result
            hasCompleted = true
            AnalyticsService.shared.track(.quizCompleted(
                quizId: quiz.id,
                topic: quiz.topic,
                score: 0,
                totalQuestions: quiz.totalQuestions
            ))
        }

        isCompleting = false
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
}
