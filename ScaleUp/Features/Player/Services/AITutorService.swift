import Foundation

// MARK: - AI Tutor Service

actor AITutorService {

    private let api = APIClient.shared

    // MARK: - Check Tutor Status

    func checkStatus(contentId: String) async throws -> TutorStatus {
        try await api.request(TutorEndpoints.status(contentId: contentId))
    }

    // MARK: - Get or Create Conversation

    func getConversation(contentId: String) async throws -> TutorConversation {
        try await api.request(TutorEndpoints.conversation(contentId: contentId))
    }

    // MARK: - Send Message

    func sendMessage(contentId: String, message: String) async throws -> TutorSendMessageResponse {
        let body = TutorMessageRequest(message: message)
        return try await api.request(TutorEndpoints.sendMessage(contentId: contentId), body: body)
    }

    // MARK: - List Conversations (History)

    func listConversations(page: Int = 1, limit: Int = 20) async throws -> [TutorConversationSummary] {
        try await api.request(TutorEndpoints.conversations(page: page, limit: limit))
    }

    // MARK: - Delete Conversation

    func deleteConversation(contentId: String) async throws {
        _ = try await api.requestRaw(TutorEndpoints.delete(contentId: contentId))
    }
}

// MARK: - Request Bodies

private struct TutorMessageRequest: Encodable, Sendable {
    let message: String
}

// MARK: - Endpoints

private enum TutorEndpoints: Endpoint {
    case status(contentId: String)
    case conversation(contentId: String)
    case sendMessage(contentId: String)
    case conversations(page: Int, limit: Int)
    case delete(contentId: String)

    var path: String {
        switch self {
        case .status(let id):           return "/tutor/\(id)/status"
        case .conversation(let id):     return "/tutor/\(id)"
        case .sendMessage(let id):      return "/tutor/\(id)/message"
        case .conversations:            return "/tutor/conversations"
        case .delete(let id):           return "/tutor/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .status, .conversation, .conversations:
            return .get
        case .sendMessage:
            return .post
        case .delete:
            return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .conversations(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        default:
            return nil
        }
    }
}
