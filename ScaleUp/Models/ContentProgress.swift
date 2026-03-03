import Foundation

// MARK: - Content Progress

struct ContentProgress: Codable, Sendable, Identifiable {
    var id: String { contentId }
    let contentId: String
    let currentPosition: Int?
    let totalDuration: Int?
    let percentageCompleted: Int?
    let isCompleted: Bool?
    let totalTimeSpent: Int?
    let sessionCount: Int?
    let content: Content?

    enum CodingKeys: String, CodingKey {
        case contentId, currentPosition, totalDuration, percentageCompleted
        case isCompleted, totalTimeSpent, sessionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPosition = try container.decodeIfPresent(Int.self, forKey: .currentPosition)
        totalDuration = try container.decodeIfPresent(Int.self, forKey: .totalDuration)
        percentageCompleted = try container.decodeIfPresent(Int.self, forKey: .percentageCompleted)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted)
        totalTimeSpent = try container.decodeIfPresent(Int.self, forKey: .totalTimeSpent)
        sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount)

        // contentId can be either a string (ObjectId) or a populated Content object
        if let populatedContent = try? container.decode(Content.self, forKey: .contentId) {
            contentId = populatedContent.id
            content = populatedContent
        } else {
            contentId = try container.decode(String.self, forKey: .contentId)
            content = nil
        }
    }

    // Memberwise init for mock data
    init(contentId: String, currentPosition: Int?, totalDuration: Int?, percentageCompleted: Int?, isCompleted: Bool?, totalTimeSpent: Int?, sessionCount: Int?, content: Content?) {
        self.contentId = contentId
        self.currentPosition = currentPosition
        self.totalDuration = totalDuration
        self.percentageCompleted = percentageCompleted
        self.isCompleted = isCompleted
        self.totalTimeSpent = totalTimeSpent
        self.sessionCount = sessionCount
        self.content = content
    }

    var progress: Double {
        guard let pct = percentageCompleted else { return 0 }
        return Double(pct) / 100.0
    }
}
