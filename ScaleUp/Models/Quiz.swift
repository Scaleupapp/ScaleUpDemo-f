import Foundation

// MARK: - Quiz

struct Quiz: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let userId: String?
    let title: String
    let type: QuizType
    let topic: String
    let sourceContentIds: [String]?
    let questions: [QuizQuestion]
    let totalQuestions: Int
    let timePerQuestion: Int?
    let assessmentType: String?
    let linkedCompetencies: [String]?
    let status: QuizStatus
    let deliveredAt: Date?
    let expiresAt: Date?
    let aiModel: String?
    let generatedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, title, type, topic, sourceContentIds
        case questions, totalQuestions, timePerQuestion
        case assessmentType, linkedCompetencies
        case status, deliveredAt, expiresAt, aiModel, generatedAt
        case createdAt, updatedAt
    }

    var timePerQuestionSeconds: Int { timePerQuestion ?? 60 }
    var estimatedMinutes: Int { max(1, (totalQuestions * timePerQuestionSeconds) / 60) }

    var difficultyDistribution: (easy: Int, medium: Int, hard: Int) {
        var e = 0, m = 0, h = 0
        for q in questions {
            switch q.difficulty {
            case .easy: e += 1
            case .medium: m += 1
            case .hard: h += 1
            case .none: m += 1
            }
        }
        return (e, m, h)
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    var expiresInText: String? {
        guard let expiresAt, !isExpired else { return nil }
        let remaining = expiresAt.timeIntervalSince(Date())
        let days = Int(remaining / 86400)
        let hours = Int(remaining.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h left" }
        let mins = Int(remaining / 60)
        return "\(max(1, mins))m left"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Quiz, rhs: Quiz) -> Bool { lhs.id == rhs.id }
}

// MARK: - Quiz Question

struct QuizQuestion: Codable, Sendable, Identifiable {
    let id: String?
    let questionText: String
    let questionType: QuestionType?
    let options: [QuizOption]
    let correctAnswer: String?     // Only available after completion
    let explanation: String?       // Only available after completion
    let difficulty: QuestionDifficulty?
    let sourceContentId: String?
    let sourceTimestamp: String?
    let concept: String?
    let scenario: String?
    let competency: String?
    let allowTextResponse: Bool?
    let textPrompt: String?
    let timeLimit: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case questionText, questionType, options
        case correctAnswer, explanation, difficulty
        case sourceContentId, sourceTimestamp, concept
        case scenario, competency, allowTextResponse, textPrompt, timeLimit
    }

    var stableId: String { id ?? questionText }
    var effectiveTimeLimit: Int? { timeLimit }
}

struct QuizOption: Codable, Sendable, Identifiable {
    let label: String  // "A", "B", "C", "D"
    let text: String
    let id: String?

    enum CodingKeys: String, CodingKey {
        case label, text
        case id = "_id"
    }

    var stableId: String { id ?? label }
}

// MARK: - Quiz Attempt

struct QuizAttempt: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let userId: String?
    let quizId: QuizAttemptQuizInfo?
    let answers: [QuizAnswer]
    let score: QuizScore?
    let topicBreakdown: [TopicBreakdown]?
    let competencyBreakdown: [CompetencyBreakdownItem]?
    let analysis: QuizAnalysis?
    let startedAt: Date?
    let completedAt: Date?
    let totalTime: Double?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, quizId, answers, score, topicBreakdown
        case competencyBreakdown, analysis
        case startedAt, completedAt, totalTime, status
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: QuizAttempt, rhs: QuizAttempt) -> Bool { lhs.id == rhs.id }
}

// QuizId in attempt can be a string or a populated object
struct QuizAttemptQuizInfo: Codable, Sendable {
    let id: String
    let title: String?
    let type: QuizType?
    let topic: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, type, topic
    }

    init(from decoder: Decoder) throws {
        // Try as object first
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            id = try container.decode(String.self, forKey: .id)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            type = try container.decodeIfPresent(QuizType.self, forKey: .type)
            topic = try container.decodeIfPresent(String.self, forKey: .topic)
        } else {
            // Try as string
            let container = try decoder.singleValueContainer()
            id = try container.decode(String.self)
            title = nil
            type = nil
            topic = nil
        }
    }
}

struct QuizAnswer: Codable, Sendable {
    let questionIndex: Int
    let selectedAnswer: String
    let isCorrect: Bool?
    let timeTaken: Double?
    let textResponse: String?
    let competency: String?
    let textEvaluation: TextEvaluation?
}

struct TextEvaluation: Codable, Sendable {
    let score: Int?
    let feedback: String?
    let partialCredit: Bool?
}

struct QuizScore: Codable, Sendable {
    let total: Int
    let correct: Int
    let incorrect: Int
    let skipped: Int
    let percentage: Double
}

struct TopicBreakdown: Codable, Sendable, Identifiable {
    var id: String { topic }
    let topic: String
    let correct: Int
    let total: Int
    let percentage: Double
}

struct QuizAnalysis: Codable, Sendable {
    let strengths: [String]?
    let weaknesses: [String]?
    let missedConcepts: [MissedConcept]?
    let confidenceScore: Int?
    let comparisonToPrevious: ComparisonData?
}

struct MissedConcept: Codable, Sendable, Identifiable {
    var id: String { concept }
    let concept: String
    let contentId: String?
    let timestamp: String?
    let suggestion: String?
}

struct ComparisonData: Codable, Sendable {
    let previousScore: Double?
    let improvement: Double?
    let trend: String?
}

// MARK: - Competency Breakdown

struct CompetencyBreakdownItem: Codable, Sendable, Identifiable {
    var id: String { competency }
    let competency: String
    let correct: Int?
    let total: Int?
    let percentage: Double?
    let textScoreAvg: Double?
    let level: String?
}

// MARK: - Enriched Results

struct QuizEnrichedResults: Codable, Sendable {
    var score: QuizScore?
    var analysis: QuizAnalysis?
    var answers: [QuizAnswer]?
    var topicBreakdown: [TopicBreakdown]?
    var competencyBreakdown: [CompetencyBreakdownItem]?
    var completedAt: Date?
    var totalTime: Double?
    var competency: CompetencyData?
    var recommendedContent: [Content]?
    var journeyImpact: JourneyImpact?
    var nextActions: [QuizNextAction]?
}

struct CompetencyData: Codable, Sendable {
    let topic: String?
    let level: String?
    let score: Double?
    let quizzesTaken: Int?
    let trend: String?
    let scoreHistory: [ScoreHistoryEntry]?
}

struct ScoreHistoryEntry: Codable, Sendable, Identifiable {
    var id: String { "\(score)-\(date?.timeIntervalSince1970 ?? 0)" }
    let score: Double
    let date: Date?
}

struct JourneyImpact: Codable, Sendable {
    let currentWeek: Int?
    let totalWeeks: Int?
    let overallProgress: Double?
    let adaptationHint: String?
}

struct QuizNextAction: Codable, Sendable, Identifiable {
    var id: String { type }
    let type: String
    let label: String
    let contentId: String?
    let topic: String?
}

// MARK: - Quiz Request

struct QuizRequestBody: Encodable, Sendable {
    let topic: String
    let contentIds: [String]?
    let questionCount: Int?
    let assessmentType: String?
    let objectiveId: String?
    let isSkillAssessment: Bool?
}

// MARK: - Assessment Type

enum AssessmentType: String, CaseIterable, Sendable {
    case knowledgeRecall = "knowledge_recall"
    case appliedScenario = "applied_scenario"
    case situationalJudgment = "situational_judgment"
    case frameworkApplication = "framework_application"
    case caseStudy = "case_study"
    case mixed = "mixed"

    var displayName: String {
        switch self {
        case .knowledgeRecall: return "Knowledge Recall"
        case .appliedScenario: return "Applied Scenario"
        case .situationalJudgment: return "Situational Judgment"
        case .frameworkApplication: return "Framework Application"
        case .caseStudy: return "Case Study"
        case .mixed: return "Mixed"
        }
    }

    var icon: String {
        switch self {
        case .knowledgeRecall: return "brain.head.profile"
        case .appliedScenario: return "theatermasks.fill"
        case .situationalJudgment: return "person.fill.questionmark"
        case .frameworkApplication: return "square.grid.3x3.fill"
        case .caseStudy: return "doc.text.magnifyingglass"
        case .mixed: return "shuffle"
        }
    }

    var subtitle: String {
        switch self {
        case .knowledgeRecall: return "Test factual knowledge and concepts"
        case .appliedScenario: return "Real-world scenario-based questions"
        case .situationalJudgment: return "Evaluate decisions in workplace situations"
        case .frameworkApplication: return "Apply frameworks and models"
        case .caseStudy: return "Complex multi-factor analysis"
        case .mixed: return "Balanced mix of all types"
        }
    }
}

struct QuizTriggerResponse: Codable, Sendable {
    let triggerId: String?
    let status: String?
    let topic: String?
    let quizId: String?
}

struct QuizAnswerBody: Encodable, Sendable {
    let questionIndex: Int
    let selectedAnswer: String
    let timeTaken: Double?
    let textResponse: String?
}

// MARK: - Enums

enum QuizType: String, Codable, Sendable {
    case topicConsolidation = "topic_consolidation"
    case weeklyReview = "weekly_review"
    case milestoneAssessment = "milestone_assessment"
    case retentionCheck = "retention_check"
    case onDemand = "on_demand"
    case playlistMastery = "playlist_mastery"
    case competencyAssessment = "competency_assessment"
    case appliedScenario = "applied_scenario"
    case examSimulation = "exam_simulation"

    var displayName: String {
        switch self {
        case .topicConsolidation: return "Topic Check"
        case .weeklyReview: return "Weekly Review"
        case .milestoneAssessment: return "Milestone"
        case .retentionCheck: return "Retention"
        case .onDemand: return "Custom"
        case .playlistMastery: return "Mastery"
        case .competencyAssessment: return "Competency"
        case .appliedScenario: return "Scenario"
        case .examSimulation: return "Exam Sim"
        }
    }

    var icon: String {
        switch self {
        case .topicConsolidation: return "brain.head.profile"
        case .weeklyReview: return "calendar"
        case .milestoneAssessment: return "flag.fill"
        case .retentionCheck: return "arrow.counterclockwise"
        case .onDemand: return "sparkle"
        case .playlistMastery: return "crown.fill"
        case .competencyAssessment: return "chart.bar.fill"
        case .appliedScenario: return "theatermasks.fill"
        case .examSimulation: return "doc.text.fill"
        }
    }
}

enum QuizStatus: String, Codable, Sendable {
    case generating, ready, delivered
    case inProgress = "in_progress"
    case completed, expired
}

enum QuestionType: String, Codable, Sendable {
    case conceptual, application
    case crossContent = "cross_content"
    case recall
    case criticalThinking = "critical_thinking"
    case situational
    case framework
    case caseStudy = "case_study"
}

enum QuestionDifficulty: String, Codable, Sendable {
    case easy, medium, hard

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

import SwiftUI
