import Foundation

// MARK: - Quiz Service

/// Service layer wrapping quiz-related API calls.
final class QuizService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - List

    /// Fetches the user's available quizzes.
    func list() async throws -> [Quiz] {
        let response: [Quiz] = try await apiClient.request(
            QuizEndpoints.list()
        )
        return response
    }

    // MARK: - Get Quiz

    /// Fetches a single quiz by ID.
    func getQuiz(id: String) async throws -> Quiz {
        let response: Quiz = try await apiClient.request(
            QuizEndpoints.getQuiz(id: id)
        )
        return response
    }

    // MARK: - Start

    /// Starts a quiz attempt.
    func start(id: String) async throws -> QuizAttempt {
        let response: QuizAttempt = try await apiClient.request(
            QuizEndpoints.start(id: id)
        )
        return response
    }

    // MARK: - Answer

    /// Submits an answer for a quiz question.
    func answer(id: String, questionIndex: Int, selectedAnswer: String, timeTaken: Double) async throws {
        try await apiClient.requestVoid(
            QuizEndpoints.answer(id: id, questionIndex: questionIndex, selectedAnswer: selectedAnswer, timeTaken: timeTaken)
        )
    }

    // MARK: - Complete

    /// Completes a quiz attempt.
    func complete(id: String) async throws -> QuizAttempt {
        let response: QuizAttempt = try await apiClient.request(
            QuizEndpoints.complete(id: id)
        )
        return response
    }

    // MARK: - Results

    /// Fetches results for a completed quiz.
    func results(id: String) async throws -> QuizAttempt {
        let response: QuizAttempt = try await apiClient.request(
            QuizEndpoints.results(id: id)
        )
        return response
    }

    // MARK: - Request

    /// Requests a new AI-generated quiz on a topic.
    /// Returns a trigger response with the trigger ID for status polling.
    func request(topic: String, contentIds: [String]? = nil) async throws -> QuizTriggerResponse {
        let response: QuizTriggerResponse = try await apiClient.request(
            QuizEndpoints.request(topic: topic, contentIds: contentIds)
        )
        return response
    }

    // MARK: - Trigger Status

    /// Checks the status of a quiz generation trigger.
    func triggerStatus(triggerId: String) async throws -> QuizTriggerResponse {
        let response: QuizTriggerResponse = try await apiClient.request(
            QuizEndpoints.triggerStatus(triggerId: triggerId)
        )
        return response
    }

    // MARK: - History

    /// Fetches the user's quiz attempt history.
    func history() async throws -> [QuizAttempt] {
        let response: [QuizAttempt] = try await apiClient.request(
            QuizEndpoints.history()
        )
        return response
    }
}
