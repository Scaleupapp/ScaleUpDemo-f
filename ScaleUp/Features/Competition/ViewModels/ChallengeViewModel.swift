import SwiftUI

@Observable
@MainActor
final class ChallengeViewModel {

    // MARK: - State

    let challengeId: String
    var questions: [ChallengeQuestion] = []
    var currentQuestionIndex = 0
    var selectedAnswer: String? = nil
    var isLoading = false
    var isComplete = false
    var result: ChallengeResult? = nil
    var error: String? = nil

    // Background
    private var backgroundObserver: NSObjectProtocol? = nil
    private var questionStartTime: Date?

    private let service = CompetitionService()

    // MARK: - Computed

    var currentQuestion: ChallengeQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var totalQuestions: Int { questions.count }

    var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(totalQuestions)
    }

    var isLastQuestion: Bool {
        currentQuestionIndex >= totalQuestions - 1
    }

    // MARK: - Init

    init(challengeId: String) {
        self.challengeId = challengeId
    }

    // MARK: - Start Challenge

    func startChallenge() async {
        isLoading = true
        error = nil

        do {
            let response = try await service.startChallenge(id: challengeId)
            questions = response.questions
            currentQuestionIndex = 0
            selectedAnswer = nil
            isComplete = false
            result = nil
            questionStartTime = Date()
            setupBackgroundDetection()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Submit Answer

    func submitAnswer() async {
        let timeSpent = questionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let answer = selectedAnswer ?? ""

        do {
            _ = try await service.submitAnswer(
                challengeId: challengeId,
                questionIndex: currentQuestionIndex,
                selectedAnswer: answer,
                timeSpent: timeSpent
            )
        } catch {
            self.error = error.localizedDescription
        }

        if isLastQuestion {
            await completeChallenge()
        } else {
            currentQuestionIndex += 1
            selectedAnswer = nil
            questionStartTime = Date()
        }
    }

    // MARK: - Complete Challenge

    func completeChallenge() async {
        do {
            let challengeResult = try await service.completeChallenge(id: challengeId)
            result = challengeResult
            isComplete = true
        } catch {
            self.error = error.localizedDescription
            isComplete = true
        }
    }

    // MARK: - Background Detection

    private func setupBackgroundDetection() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.selectedAnswer = nil
                await self.submitAnswer()
            }
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
    }
}
