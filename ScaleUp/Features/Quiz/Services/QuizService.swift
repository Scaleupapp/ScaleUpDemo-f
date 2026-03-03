import Foundation

// MARK: - Quiz Service

actor QuizService {
    private let api = APIClient.shared

    // MARK: - Quiz List

    func fetchAllQuizzes() async throws -> [Quiz] {
        try await api.request(QuizEndpoints.list)
    }

    func fetchPendingQuizzes() async throws -> [Quiz] {
        try await api.request(QuizEndpoints.pending)
    }

    func fetchQuizHistory() async throws -> [QuizAttempt] {
        try await api.request(QuizEndpoints.history)
    }

    func fetchSkillAssessments() async throws -> [Quiz] {
        try await api.request(QuizEndpoints.skillAssessments)
    }

    // MARK: - Quiz Detail

    func fetchQuiz(id: String) async throws -> Quiz {
        try await api.request(QuizEndpoints.detail(id: id))
    }

    // MARK: - Quiz Session

    func startQuiz(id: String) async throws -> QuizAttempt {
        try await api.request(QuizEndpoints.start(id: id))
    }

    func submitAnswer(quizId: String, questionIndex: Int, selectedAnswer: String, timeTaken: Double?, textResponse: String? = nil) async throws -> QuizAttempt {
        let body = QuizAnswerBody(questionIndex: questionIndex, selectedAnswer: selectedAnswer, timeTaken: timeTaken, textResponse: textResponse)
        return try await api.request(QuizEndpoints.answer(id: quizId), body: body)
    }

    func completeQuiz(id: String) async throws -> QuizAttempt {
        try await api.request(QuizEndpoints.complete(id: id))
    }

    // MARK: - Results

    func fetchResults(quizId: String) async throws -> QuizEnrichedResults {
        try await api.request(QuizEndpoints.results(id: quizId))
    }

    // MARK: - On-Demand Quiz

    func requestQuiz(
        topic: String,
        contentIds: [String]? = nil,
        questionCount: Int? = nil,
        assessmentType: String? = nil,
        objectiveId: String? = nil,
        isSkillAssessment: Bool = false
    ) async throws -> QuizTriggerResponse {
        let body = QuizRequestBody(
            topic: topic,
            contentIds: contentIds,
            questionCount: questionCount,
            assessmentType: assessmentType,
            objectiveId: objectiveId,
            isSkillAssessment: isSkillAssessment ? true : nil
        )
        return try await api.request(QuizEndpoints.request, body: body)
    }

    func checkTriggerStatus(triggerId: String) async throws -> QuizTriggerResponse {
        try await api.request(QuizEndpoints.triggerStatus(id: triggerId))
    }
}

// MARK: - Endpoints

private enum QuizEndpoints: Endpoint {
    case list
    case pending
    case history
    case skillAssessments
    case detail(id: String)
    case start(id: String)
    case answer(id: String)
    case complete(id: String)
    case results(id: String)
    case request
    case triggerStatus(id: String)

    var path: String {
        switch self {
        case .list: return "/quizzes"
        case .pending: return "/quizzes/pending"
        case .history: return "/quizzes/history"
        case .skillAssessments: return "/quizzes/skill-assessments"
        case .detail(let id): return "/quizzes/\(id)"
        case .start(let id): return "/quizzes/\(id)/start"
        case .answer(let id): return "/quizzes/\(id)/answer"
        case .complete(let id): return "/quizzes/\(id)/complete"
        case .results(let id): return "/quizzes/\(id)/results"
        case .request: return "/quizzes/request"
        case .triggerStatus(let id): return "/quizzes/trigger/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .pending, .history, .detail, .results, .triggerStatus, .skillAssessments:
            return .get
        case .start, .complete, .request:
            return .post
        case .answer:
            return .put
        }
    }
}
