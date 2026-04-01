import Foundation

// MARK: - Flashcard Set

struct FlashcardSet: Codable, Sendable, Identifiable {
    let id: String
    let userId: String?
    let contentId: FlashcardContentRef?
    let title: String
    let cards: [FlashcardCard]
    let totalCards: Int
    let status: String // generating, ready, failed
    let generatedAt: Date?
    let lastStudiedAt: Date?
    let timesStudied: Int?
    let masteredCount: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, contentId, title, cards, totalCards
        case status, generatedAt, lastStudiedAt, timesStudied, masteredCount, createdAt
    }

    var isReady: Bool { status == "ready" }
    var isGenerating: Bool { status == "generating" }

    var masteryPercentage: Int {
        guard totalCards > 0 else { return 0 }
        return Int(Double(masteredCount ?? 0) / Double(totalCards) * 100)
    }
}

// MARK: - Flashcard Card

struct FlashcardCard: Codable, Sendable, Identifiable {
    let id: String
    let front: String
    let back: String
    let hint: String?
    let difficulty: String?
    let concept: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case front, back, hint, difficulty, concept
    }
}

// MARK: - Content Reference (can be string or populated)

enum FlashcardContentRef: Codable, Sendable {
    case id(String)
    case content(FlashcardContentInfo)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .id(str)
        } else {
            let info = try container.decode(FlashcardContentInfo.self)
            self = .content(info)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .id(let str): try container.encode(str)
        case .content(let info): try container.encode(info)
        }
    }

    var title: String? {
        if case .content(let info) = self { return info.title }
        return nil
    }

    var contentType: String? {
        if case .content(let info) = self { return info.contentType }
        return nil
    }
}

struct FlashcardContentInfo: Codable, Sendable {
    let id: String
    let title: String?
    let domain: String?
    let contentType: String?
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, domain, contentType, thumbnailURL
    }
}

// MARK: - Responses

struct FlashcardListResponse: Codable, Sendable {
    let items: [FlashcardSet]
    let pagination: FlashcardPagination?
}

struct FlashcardPagination: Codable, Sendable {
    let page: FlexInt
    let limit: FlexInt
    let total: FlexInt
    let totalPages: FlexInt
}

/// Handles JSON values that can be either Int or String
struct FlexInt: Codable, Sendable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let strVal = try? container.decode(String.self), let parsed = Int(strVal) {
            value = parsed
        } else {
            value = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct FlashcardGenerateResponse: Codable, Sendable {
    let status: String
    let contentId: String
}
