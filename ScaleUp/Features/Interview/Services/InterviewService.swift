import Foundation

actor InterviewService {

    // MARK: - Start Interview

    func startInterview(type: InterviewType, targetRole: String, targetCompany: String?, difficulty: InterviewDifficulty, objectiveId: String? = nil) async throws -> StartInterviewResponse {
        struct Body: Encodable {
            let interviewType: String
            let targetRole: String
            let targetCompany: String?
            let difficulty: String
            let objectiveId: String?
        }
        return try await APIClient.shared.request(
            InterviewEndpoints.start,
            body: Body(interviewType: type.rawValue, targetRole: targetRole, targetCompany: targetCompany, difficulty: difficulty.rawValue, objectiveId: objectiveId)
        )
    }

    // MARK: - Complete Interview (save transcript)

    func completeInterview(sessionId: String, transcript: [TranscriptEntry], integrityData: [String: Any]? = nil) async throws {
        struct Body: Encodable {
            let transcript: [TranscriptEntry]
        }
        _ = try await APIClient.shared.requestRaw(
            InterviewEndpoints.complete(sessionId: sessionId),
            body: Body(transcript: transcript)
        )
    }

    // MARK: - Get Session

    func getSession(sessionId: String) async throws -> InterviewSession {
        return try await APIClient.shared.request(InterviewEndpoints.session(sessionId: sessionId))
    }

    // MARK: - Get Status

    func getStatus(sessionId: String) async throws -> InterviewStatusResponse {
        return try await APIClient.shared.request(InterviewEndpoints.status(sessionId: sessionId))
    }

    // MARK: - List Sessions

    func listSessions(page: Int = 1, limit: Int = 20) async throws -> [InterviewSessionSummary] {
        return try await APIClient.shared.request(InterviewEndpoints.list(page: page, limit: limit))
    }

    // MARK: - Delete Session

    func deleteSession(sessionId: String) async throws {
        _ = try await APIClient.shared.requestRaw(InterviewEndpoints.delete(sessionId: sessionId))
    }

    // MARK: - Analytics

    func fetchAnalytics() async throws -> InterviewAnalytics {
        return try await APIClient.shared.request(InterviewEndpoints.analytics)
    }
}

// MARK: - Endpoints

private enum InterviewEndpoints: Endpoint {
    case start
    case complete(sessionId: String)
    case session(sessionId: String)
    case status(sessionId: String)
    case list(page: Int, limit: Int)
    case delete(sessionId: String)
    case analytics

    var path: String {
        switch self {
        case .start: return "/interviews/start"
        case .complete(let id): return "/interviews/\(id)/complete"
        case .session(let id): return "/interviews/\(id)"
        case .status(let id): return "/interviews/\(id)/status"
        case .list: return "/interviews"
        case .delete(let id): return "/interviews/\(id)"
        case .analytics: return "/interviews/analytics"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .start, .complete: return .post
        case .session, .status, .list, .analytics: return .get
        case .delete: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let page, let limit):
            return [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "\(limit)")]
        default: return nil
        }
    }
}
