import Foundation

/// Client for user-to-user moderation — blocking abusive users and reporting
/// objectionable user-generated content (App Store Guideline 1.2).
actor ModerationService {
    static let shared = ModerationService()
    private let api = APIClient.shared

    /// Report objectionable UGC. `targetType` is one of "comment", "user",
    /// "noteRequest", "content".
    func report(targetType: String, targetId: String, reason: String, description: String? = nil) async throws {
        let body = ReportBody(targetType: targetType, targetId: targetId, reason: reason, description: description)
        _ = try await api.requestRaw(ModerationEndpoints.report, body: body)
    }

    func blockUser(_ userId: String) async throws {
        _ = try await api.requestRaw(ModerationEndpoints.block(userId: userId))
    }

    func unblockUser(_ userId: String) async throws {
        _ = try await api.requestRaw(ModerationEndpoints.unblock(userId: userId))
    }

    func listBlocked() async throws -> [BlockedUser] {
        try await api.request(ModerationEndpoints.blocked)
    }
}

// MARK: - Models

struct BlockedUser: Codable, Sendable, Identifiable {
    let id: String
    let firstName: String?
    let lastName: String?
    let username: String?
    let profilePicture: String?
    let blockedAt: String?

    var displayName: String {
        let name = [firstName, lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        if let u = username, !u.isEmpty { return "@\(u)" }
        return "User"
    }
}

/// Standard report reasons shown to the user when flagging content.
enum ReportReason: String, CaseIterable, Identifiable {
    case inappropriate, spam, harassment, hate_speech, misleading, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .inappropriate: return "Inappropriate content"
        case .spam: return "Spam"
        case .harassment: return "Harassment or bullying"
        case .hate_speech: return "Hate speech"
        case .misleading: return "Misleading or false"
        case .other: return "Something else"
        }
    }
}

// MARK: - Request bodies

private struct ReportBody: Encodable, Sendable {
    let targetType: String
    let targetId: String
    let reason: String
    let description: String?
}

// MARK: - Endpoints

private enum ModerationEndpoints: Endpoint {
    case report
    case block(userId: String)
    case unblock(userId: String)
    case blocked

    var path: String {
        switch self {
        case .report: return "/social/report"
        case .block(let id), .unblock(let id): return "/social/block/\(id)"
        case .blocked: return "/social/blocked"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .report, .block: return .post
        case .unblock: return .delete
        case .blocked: return .get
        }
    }
}
