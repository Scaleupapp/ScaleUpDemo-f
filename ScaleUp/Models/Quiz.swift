import Foundation

// MARK: - Quiz

struct Quiz: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let title: String
    let type: QuizType
    let topic: String
    let sourceContentIds: [String]?
    let objectiveId: String?
    let questions: [QuizQuestion]
    let totalQuestions: Int
    let timePerQuestion: Int?
    let status: QuizStatus
    let expiresAt: String?
    let aiModel: String?
    let generatedAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, title, type, topic
        case sourceContentIds, objectiveId
        case questions, totalQuestions, timePerQuestion
        case status, expiresAt
        case aiModel, generatedAt, createdAt, updatedAt
    }

    /// Total time limit in seconds (timePerQuestion * totalQuestions).
    var timeLimit: Int? {
        guard let tpq = timePerQuestion, tpq > 0 else { return nil }
        return tpq * totalQuestions
    }
}

// MARK: - QuizOption

struct QuizOption: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case label, text
    }
}

// MARK: - QuizQuestion

struct QuizQuestion: Codable, Hashable, Identifiable {
    let id: String
    let questionText: String
    let questionType: String?
    let options: [QuizOption]
    let correctAnswer: String?
    let explanation: String?
    let difficulty: String?
    let sourceContentId: String?
    let sourceTimestamp: String?
    let concept: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case questionText, questionType, options
        case correctAnswer, explanation, difficulty
        case sourceContentId, sourceTimestamp, concept
    }

    /// The option text values as a plain string array (for backward compatibility).
    var optionTexts: [String] {
        options.map(\.text)
    }

    /// Returns the label ("A", "B", etc.) for the option at the given index.
    func optionLabel(at index: Int) -> String {
        guard index < options.count else { return "\(index + 1)" }
        return options[index].label
    }
}

// MARK: - QuizAttempt

struct QuizAttempt: Codable, Identifiable, Hashable {
    let id: String
    let quizId: String
    let userId: String
    let answers: [QuizAnswer]
    let score: QuizScore?
    let topicBreakdown: [TopicBreakdown]?
    let analysis: QuizAnalysis?
    let status: String
    let startedAt: String
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case quizId, userId, answers, score
        case topicBreakdown, analysis
        case status, startedAt, completedAt
    }
}

// MARK: - QuizAnswer

struct QuizAnswer: Codable, Hashable {
    let questionIndex: Int
    let selectedAnswer: String
    let timeTaken: Double?
}

// MARK: - QuizScore

struct QuizScore: Codable, Hashable {
    let total: Int
    let correct: Int
    let incorrect: Int
    let skipped: Int
    let percentage: Double
}

// MARK: - TopicBreakdown

struct TopicBreakdown: Codable, Hashable {
    let topic: String
    let correct: Int
    let total: Int
    let percentage: Double
}

// MARK: - QuizAnalysis

struct QuizAnalysis: Codable, Hashable {
    let strengths: [String]
    let weaknesses: [String]
    let missedConcepts: [MissedConcept]?
    let confidenceScore: Double?
    let comparisonToPrevious: ComparisonToPrevious?
}

// MARK: - MissedConcept

struct MissedConcept: Codable, Hashable {
    let concept: String?
    let contentId: String?
    let timestamp: String?
    let suggestion: String?
}

// MARK: - ComparisonToPrevious

struct ComparisonToPrevious: Codable, Hashable {
    let previousScore: Double?
    let improvement: Double?
    let trend: Trend?
}

// MARK: - QuizTriggerResponse

struct QuizTriggerResponse: Codable {
    let triggerId: String
    let status: String
    let topic: String
    let quizId: String?
}
