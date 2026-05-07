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

    func getResults(attemptId: String) async throws -> DiagnosticResultsResponse {
        try await api.request(DiagnosticEndpoints.results(id: attemptId))
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
    case results(id: String)

    var path: String {
        switch self {
        case .start:                  return "/diagnostic/start"
        case .selfRating(let id):     return "/diagnostic/\(id)/self-rating"
        case .nextQuestion(let id):   return "/diagnostic/\(id)/next-question"
        case .answer(let id):         return "/diagnostic/\(id)/answer"
        case .finish(let id):         return "/diagnostic/\(id)/finish"
        case .abandon(let id):        return "/diagnostic/\(id)/abandon"
        case .results(let id):        return "/diagnostic/\(id)/results"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .nextQuestion, .results: return .get
        default:                      return .post
        }
    }
}

// MARK: - Results DTOs

struct DiagnosticInsightsDTO: Decodable, Sendable {
    let hero: String
    let calibration: String
    let patterns: [String]
    let topicTakeaways: [String: String]
    let planHeadline: String
}

struct DiagnosticResultDTO: Decodable, Sendable {
    let competency: String
    let canonicalCompetency: String?
    let band: String
    let score: Int
    let calibrationDelta: Int
    let calibrationClass: String
    let questionsAsked: Int
    let displayName: String?
    let selfRating: String?
    let strongestMoment: String?
    let stretchMoment: String?
    let missedDifficulties: [String]?
}

struct DiagnosticResultsResponse: Decodable, Sendable {
    let attemptId: String
    let status: String
    let insightsStatus: String
    let insights: DiagnosticInsightsDTO?
    let planStatus: String
    let results: [DiagnosticResultDTO]
}
