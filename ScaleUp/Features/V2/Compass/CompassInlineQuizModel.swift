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
    var isLastQuestion: Bool { currentIndex >= totalQuestions - 1 }

    func begin() async {
        phase = .generating
        do {
            let trigger = try await quizService.requestQuiz(
                topic: topic,
                questionCount: questionCount,
                assessmentType: "recall",
                source: "tutoring"
            )
            var quizId = trigger.quizId
            var tries = 0
            while quizId == nil && tries < 30 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                let s = try await quizService.checkTriggerStatus(triggerId: trigger.triggerId ?? "")
                if s.status == "failed" {
                    phase = .failed
                    errorMessage = "Couldn't build a check right now."
                    return
                }
                quizId = s.quizId
                tries += 1
            }
            guard let qid = quizId else {
                phase = .failed
                errorMessage = "The check took too long to build."
                return
            }
            let q = try await quizService.fetchQuiz(id: qid)
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
        guard phase == .taking, let quiz else { return }
        answers[currentIndex] = label
        _ = try? await quizService.submitAnswer(
            quizId: quiz.id,
            questionIndex: currentIndex,
            selectedAnswer: label,
            timeTaken: nil
        )
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
