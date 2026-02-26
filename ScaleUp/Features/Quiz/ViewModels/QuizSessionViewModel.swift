import SwiftUI

// MARK: - Quiz Session View Model

@Observable
@MainActor
final class QuizSessionViewModel {

    // MARK: - State

    var quiz: Quiz?
    var attempt: QuizAttempt?
    var currentQuestionIndex: Int = 0
    var selectedAnswer: String?
    var answers: [Int: String] = [:]
    var isSubmitting: Bool = false
    var isCompleted: Bool = false
    var questionStartTime: Date = .now
    var error: APIError?

    // MARK: - Dependencies

    private let quizService: QuizService

    // MARK: - Init

    init(quizService: QuizService) {
        self.quizService = quizService
    }

    // MARK: - Computed Properties

    var totalQuestions: Int {
        quiz?.questions.count ?? 0
    }

    var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentQuestionIndex) / Double(totalQuestions)
    }

    var currentQuestion: QuizQuestion? {
        guard let quiz, currentQuestionIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentQuestionIndex]
    }

    var isLastQuestion: Bool {
        currentQuestionIndex >= totalQuestions - 1
    }

    var hasSelectedAnswer: Bool {
        selectedAnswer != nil
    }

    // MARK: - Start Quiz

    /// Starts a quiz attempt and loads the quiz data.
    func startQuiz(id: String) async {
        isSubmitting = true
        error = nil

        do {
            async let attemptTask = quizService.start(id: id)
            async let quizTask = quizService.getQuiz(id: id)

            let (newAttempt, loadedQuiz) = try await (attemptTask, quizTask)
            self.attempt = newAttempt
            self.quiz = loadedQuiz
            self.currentQuestionIndex = 0
            self.questionStartTime = .now
            self.answers = [:]
            self.selectedAnswer = nil
            self.isCompleted = false
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isSubmitting = false
    }

    // MARK: - Select Answer

    /// Sets the selected answer with haptic feedback.
    func selectAnswer(_ answer: String) {
        guard !isSubmitting else { return }
        selectedAnswer = answer
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Submit Answer

    /// Submits the selected answer for the current question and advances to the next.
    func submitAnswer() async {
        guard !isSubmitting, !isCompleted else { return }
        guard let attempt, let selectedAnswer else { return }
        guard let quiz else { return }

        isSubmitting = true

        let timeTaken = Date().timeIntervalSince(questionStartTime)

        do {
            try await quizService.answer(
                id: quiz.id,
                questionIndex: currentQuestionIndex,
                selectedAnswer: selectedAnswer,
                timeTaken: timeTaken
            )
            answers[currentQuestionIndex] = selectedAnswer

            if isLastQuestion {
                await completeQuiz()
            } else {
                nextQuestion()
            }
        } catch {
            print("[QuizSession] submitAnswer error: \(error)")
            // Don't block — advance locally even if API fails
            answers[currentQuestionIndex] = selectedAnswer
            if isLastQuestion {
                await completeQuiz()
            } else {
                nextQuestion()
            }
        }

        isSubmitting = false
    }

    // MARK: - Skip Question

    /// Submits a skip for the current question and advances.
    func skipQuestion() async {
        guard let attempt else { return }
        guard let quiz else { return }

        isSubmitting = true

        let timeTaken = Date().timeIntervalSince(questionStartTime)

        do {
            try await quizService.answer(
                id: quiz.id,
                questionIndex: currentQuestionIndex,
                selectedAnswer: "skipped",
                timeTaken: timeTaken
            )
            answers[currentQuestionIndex] = "__skipped__"

            if isLastQuestion {
                await completeQuiz()
            } else {
                nextQuestion()
            }
        } catch {
            print("[QuizSession] skipQuestion error: \(error)")
            // Don't block — advance locally even if API fails
            answers[currentQuestionIndex] = "__skipped__"
            if isLastQuestion {
                await completeQuiz()
            } else {
                nextQuestion()
            }
        }

        isSubmitting = false
    }

    // MARK: - Complete Quiz

    /// Completes the quiz attempt and loads results.
    func completeQuiz() async {
        guard !isCompleted else { return }
        guard let attempt else { return }
        guard let quiz else { return }

        do {
            let completedAttempt = try await quizService.complete(id: quiz.id)
            self.attempt = completedAttempt
            self.isCompleted = true

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("[QuizSession] completeQuiz error: \(error)")
            // Mark completed locally so user isn't stuck
            self.isCompleted = true
        }
    }

    // MARK: - Next Question

    /// Advances to the next question and resets selection state.
    func nextQuestion() {
        guard currentQuestionIndex < totalQuestions - 1 else { return }
        currentQuestionIndex += 1
        selectedAnswer = nil
        questionStartTime = .now
    }
}
