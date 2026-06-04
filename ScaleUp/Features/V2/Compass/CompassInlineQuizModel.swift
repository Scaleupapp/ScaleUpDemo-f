import SwiftUI

@Observable
@MainActor
final class CompassInlineQuizModel: Identifiable {
    let id = UUID()
    let topic: String
    let questionCount: Int
    let beforeScore: Double?

    enum Phase: Equatable { case generating, taking, completing, done, failed }
    var phase: Phase = .generating
    var finished = false          // Fix 1: ensures onFinished fires exactly once
    var isSubmitting = false      // Fix 3: prevents double-submit on fast taps
    var quiz: Quiz?
    var reviewedQuiz: Quiz?     // completed quiz: correctAnswer/explanation populated
    var attemptId: String?
    var currentIndex = 0
    var answers: [Int: String] = [:]   // questionIndex → label ("A"/"B"/...)
    var checkScore: Double?
    var errorMessage: String?

    private let quizService = QuizService()

    init(topic: String, questionCount: Int, beforeScore: Double?) {
        self.topic = topic
        self.questionCount = questionCount
        self.beforeScore = beforeScore
    }

    var currentQuestion: QuizQuestion? {
        guard let quiz, currentIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentIndex]
    }
    var totalQuestions: Int { quiz?.questions.count ?? questionCount }
    var isLastQuestion: Bool { currentIndex >= max(1, totalQuestions) - 1 }  // Fix 5: safe when quiz has 0 questions

    func begin() async {
        phase = .generating
        do {
            // Step (a): request quiz generation
            let trigger = try await quizService.requestQuiz(
                topic: topic,
                questionCount: questionCount,
                assessmentType: "recall",
                source: "tutoring"
            )
            var quizId = trigger.quizId

            // Step (b): if quizId already returned, skip polling entirely
            if quizId == nil {
                // Fix 2: require a non-empty triggerId before entering the poll loop
                guard let triggerId = trigger.triggerId, !triggerId.isEmpty else {
                    phase = .failed
                    errorMessage = "Couldn't queue the check."
                    return
                }
                // Step (c): poll with the valid triggerId (≤30 × 2 s)
                var tries = 0
                while quizId == nil && tries < 30 {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    let s = try await quizService.checkTriggerStatus(triggerId: triggerId)
                    if s.status == "failed" {
                        phase = .failed
                        errorMessage = "Couldn't build a check right now."
                        return
                    }
                    quizId = s.quizId
                    tries += 1
                }
                guard quizId != nil else {
                    phase = .failed
                    errorMessage = "The check took too long to build."
                    return
                }
            }

            // Step (d): fetch, start, and transition
            let qid = quizId!
            let q = try await quizService.fetchQuiz(id: qid)
            // Fix 5: guard against a 0-question quiz
            guard !q.questions.isEmpty else {
                phase = .failed
                errorMessage = "Couldn't build a check right now."
                return
            }
            let attempt = try await quizService.startQuiz(id: qid)
            self.quiz = q
            self.attemptId = attempt.id
            self.currentIndex = 0
            self.phase = .taking
        } catch {
            phase = .failed
            errorMessage = "Couldn't start the check."
        }
    }

    func choose(_ label: String) async {
        // Fix 3: prevent double-submit on fast taps
        guard phase == .taking, !isSubmitting, let quiz else { return }
        isSubmitting = true
        answers[currentIndex] = label
        _ = try? await quizService.submitAnswer(
            quizId: quiz.id,
            questionIndex: currentIndex,
            selectedAnswer: label,
            timeTaken: nil
        )
        isSubmitting = false
        if isLastQuestion {
            await complete()
        } else {
            currentIndex += 1
        }
    }

    private func complete() async {
        guard let quiz else { return }
        phase = .completing
        do {
            let attempt = try await quizService.completeQuiz(id: quiz.id)
            checkScore = attempt.score?.percentage
            reviewedQuiz = try? await quizService.fetchQuiz(id: quiz.id)  // now has correctAnswer/explanation
            phase = .done
        } catch {
            phase = .failed
            errorMessage = "Couldn't submit the check."
        }
    }
}
