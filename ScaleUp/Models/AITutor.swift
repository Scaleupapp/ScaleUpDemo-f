import Foundation

// MARK: - Tutor Tier

enum TutorTier: String, Codable, Sendable {
    case full
    case limited
    case disabled
}

// MARK: - Quick Prompt

struct QuickPrompt: Codable, Sendable, Identifiable {
    let id: String
    let label: String
    let prompt: String
}

// MARK: - Tutor Status

struct TutorStatus: Sendable {
    let tier: TutorTier
    let hasTranscript: Bool
    let hasAiData: Bool
    let quickPrompts: [QuickPrompt]
}

extension TutorStatus: Decodable {
    private enum CodingKeys: String, CodingKey {
        case tier, hasTranscript, hasAiData, quickPrompts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tier = try container.decode(TutorTier.self, forKey: .tier)
        hasAiData = (try? container.decode(Bool.self, forKey: .hasAiData)) ?? false
        quickPrompts = (try? container.decodeIfPresent([QuickPrompt].self, forKey: .quickPrompts)) ?? []

        // Backend can return hasTranscript as Bool or String (empty string = false)
        if let boolVal = try? container.decode(Bool.self, forKey: .hasTranscript) {
            hasTranscript = boolVal
        } else if let strVal = try? container.decode(String.self, forKey: .hasTranscript) {
            hasTranscript = !strVal.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            hasTranscript = false
        }
    }
}

// MARK: - Tutor Message

struct TutorMessage: Codable, Sendable, Identifiable {
    let role: TutorMessageRole
    let content: String
    let contextMeta: TutorContextMeta?
    let createdAt: Date?

    var id: String {
        "\(role.rawValue)_\(createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)_\(content.hashValue)"
    }

    var timeString: String {
        guard let date = createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum TutorMessageRole: String, Codable, Sendable {
    case user
    case assistant
}

struct TutorContextMeta: Codable, Sendable {
    let timestampRange: String?
    let conceptsReferenced: [String]?
    let tutorTier: TutorTier?
}

// MARK: - Conversation

struct TutorConversation: Codable, Sendable {
    let conversationId: String
    let contentId: String
    let contentTitle: String?
    let tutorTier: TutorTier
    let messages: [TutorMessage]
    let messageCount: Int
    let quickPrompts: [QuickPrompt]?
}

// MARK: - Send Message Response

struct TutorSendMessageResponse: Codable, Sendable {
    let message: TutorMessage
    let tutorTier: TutorTier
    let messageCount: Int
}

// MARK: - Conversation Summary (for history list)

struct TutorConversationSummary: Codable, Sendable, Identifiable {
    let id: String
    let contentId: String
    let contentTitle: String?
    let contentDomain: String?
    let tutorTier: TutorTier
    let messageCount: Int
    let lastMessageAt: Date?
    let lastMessage: TutorLastMessage?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case contentId, contentTitle, contentDomain
        case tutorTier, messageCount, lastMessageAt, lastMessage
    }

    var timeAgo: String {
        guard let date = lastMessageAt else { return "" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 604800 { return "\(seconds / 86400)d ago" }
        return "\(seconds / 604800)w ago"
    }
}

struct TutorLastMessage: Codable, Sendable {
    let role: TutorMessageRole
    let preview: String
}

// MARK: - Delete Response

struct TutorDeleteResponse: Codable, Sendable {
    let deleted: Bool
}
