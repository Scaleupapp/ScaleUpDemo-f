import Foundation

// MARK: - Diagnostic Service

actor DiagnosticService {
    private let api = APIClient.shared

    func start() async throws -> DiagnosticAttemptStart {
        try await api.request(DiagnosticEndpoints.start)
    }

    func submitSelfRating(attemptId: String, ratings: [String: String]) async throws {
        struct Body: Encodable, Sendable { let ratings: [String: String] }
        let _: EmptyData = try await api.request(DiagnosticEndpoints.selfRating(id: attemptId), body: Body(ratings: ratings))
    }

    func nextQuestion(attemptId: String) async throws -> DiagnosticNextQuestion {
        try await api.request(DiagnosticEndpoints.nextQuestion(id: attemptId))
    }

    func submitAnswer(attemptId: String, questionId: String, selectedAnswer: String, timeTaken: Double) async throws {
        struct Body: Encodable, Sendable {
            let questionId: String
            let selectedAnswer: String
            let timeTaken: Double
        }
        let _: EmptyData = try await api.request(
            DiagnosticEndpoints.answer(id: attemptId),
            body: Body(questionId: questionId, selectedAnswer: selectedAnswer, timeTaken: timeTaken)
        )
    }

    func finish(attemptId: String) async throws -> DiagnosticResults {
        try await api.request(DiagnosticEndpoints.finish(id: attemptId))
    }

    func abandon(attemptId: String) async throws {
        struct EmptyBody: Encodable, Sendable {}
        let _: EmptyData = try await api.request(DiagnosticEndpoints.abandon(id: attemptId), body: EmptyBody())
    }
}

// MARK: - Endpoints

private enum DiagnosticEndpoints: Endpoint {
    case start
    case selfRating(id: String)
    case nextQuestion(id: String)
    case answer(id: String)
    case finish(id: String)
    case abandon(id: String)

    var path: String {
        switch self {
        case .start:                  return "/diagnostic/start"
        case .selfRating(let id):     return "/diagnostic/\(id)/self-rating"
        case .nextQuestion(let id):   return "/diagnostic/\(id)/next-question"
        case .answer(let id):         return "/diagnostic/\(id)/answer"
        case .finish(let id):         return "/diagnostic/\(id)/finish"
        case .abandon(let id):        return "/diagnostic/\(id)/abandon"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .nextQuestion: return .get
        default:            return .post
        }
    }
}
