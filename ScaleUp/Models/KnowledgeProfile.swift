import Foundation

// MARK: - KnowledgeProfile

struct KnowledgeProfile: Codable, Hashable {
    let overallScore: Double
    let totalTopicsCovered: Int
    let totalQuizzesTaken: Int
    let strengths: [String]
    let weaknesses: [String]
    let topicMastery: [TopicMastery]
}

// MARK: - TopicMastery

struct TopicMastery: Codable, Hashable {
    let topic: String
    let score: Double
    let level: MasteryLevel
    let trend: Trend
    let quizzesTaken: Int?
    let lastAssessedAt: String?
}
