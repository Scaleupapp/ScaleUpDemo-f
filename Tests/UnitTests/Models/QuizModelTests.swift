import XCTest
@testable import ScaleUp

// MARK: - Quiz Model Tests

/// Tests for `Quiz`, `QuizQuestion`, `QuizAttempt`, `QuizAnswer`, `QuizScore`,
/// `TopicBreakdown`, `QuizAnalysis`, and related enum decoding.
final class QuizModelTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Quiz Decoding

    func testQuiz_decodesFromFullJSON() throws {
        // Given
        let json = JSONFactory.quizJSON(
            id: "quiz-abc",
            userId: "user-123",
            type: "topic_consolidation",
            topic: "Swift Basics",
            sourceContent: ["content-1", "content-2"],
            passingScore: 80,
            timeLimit: 30,
            status: "ready",
            expiresAt: "2025-02-01T00:00:00.000Z",
            createdAt: "2025-01-15T00:00:00.000Z"
        )
        let data = JSONFactory.data(from: json)

        // When
        let quiz = try decoder.decode(Quiz.self, from: data)

        // Then
        XCTAssertEqual(quiz.id, "quiz-abc")
        XCTAssertEqual(quiz.userId, "user-123")
        XCTAssertEqual(quiz.type, .topicConsolidation)
        XCTAssertEqual(quiz.topic, "Swift Basics")
        XCTAssertEqual(quiz.sourceContent, ["content-1", "content-2"])
        XCTAssertEqual(quiz.passingScore, 80)
        XCTAssertEqual(quiz.timeLimit, 30)
        XCTAssertEqual(quiz.status, .ready)
        XCTAssertEqual(quiz.expiresAt, "2025-02-01T00:00:00.000Z")
        XCTAssertEqual(quiz.createdAt, "2025-01-15T00:00:00.000Z")
    }

    func testQuiz_idMapsFromUnderscore() throws {
        let json = JSONFactory.quizJSON(id: "mongo_quiz_id")
        let data = JSONFactory.data(from: json)
        let quiz = try decoder.decode(Quiz.self, from: data)
        XCTAssertEqual(quiz.id, "mongo_quiz_id")
    }

    func testQuiz_missingOptionalFields() throws {
        let json = JSONFactory.quizJSON(timeLimit: nil, expiresAt: nil)
        let data = JSONFactory.data(from: json)
        let quiz = try decoder.decode(Quiz.self, from: data)

        XCTAssertNil(quiz.timeLimit)
        XCTAssertNil(quiz.expiresAt)
    }

    func testQuiz_withMultipleQuestions() throws {
        let questions = [
            JSONFactory.quizQuestionJSON(question: "What is var?", correctAnswer: 0),
            JSONFactory.quizQuestionJSON(question: "What is let?", correctAnswer: 1),
            JSONFactory.quizQuestionJSON(question: "What is func?", correctAnswer: 2)
        ]
        let json = JSONFactory.quizJSON(questions: questions)
        let data = JSONFactory.data(from: json)

        let quiz = try decoder.decode(Quiz.self, from: data)

        XCTAssertEqual(quiz.questions.count, 3)
        XCTAssertEqual(quiz.questions[0].question, "What is var?")
        XCTAssertEqual(quiz.questions[1].question, "What is let?")
        XCTAssertEqual(quiz.questions[2].question, "What is func?")
    }

    // MARK: - QuizQuestion Decoding

    func testQuizQuestion_decodesFromFullJSON() throws {
        let json = JSONFactory.quizQuestionJSON(
            question: "What is a protocol?",
            options: ["Interface", "Class", "Struct", "Enum"],
            correctAnswer: 0,
            explanation: "Protocols define a blueprint of methods.",
            difficulty: "intermediate",
            type: "multiple_choice",
            relatedContent: "content-99",
            relatedTimestamp: 180.5
        )
        let data = JSONFactory.data(from: json)

        let question = try decoder.decode(QuizQuestion.self, from: data)

        XCTAssertEqual(question.question, "What is a protocol?")
        XCTAssertEqual(question.options, ["Interface", "Class", "Struct", "Enum"])
        XCTAssertEqual(question.correctAnswer, 0)
        XCTAssertEqual(question.explanation, "Protocols define a blueprint of methods.")
        XCTAssertEqual(question.difficulty, .intermediate)
        XCTAssertEqual(question.type, "multiple_choice")
        XCTAssertEqual(question.relatedContent, "content-99")
        XCTAssertEqual(question.relatedTimestamp, 180.5, accuracy: 0.001)
    }

    func testQuizQuestion_missingOptionalFields() throws {
        let json = JSONFactory.quizQuestionJSON(
            explanation: nil,
            difficulty: nil,
            type: nil,
            relatedContent: nil,
            relatedTimestamp: nil
        )
        let data = JSONFactory.data(from: json)

        let question = try decoder.decode(QuizQuestion.self, from: data)

        XCTAssertNil(question.explanation)
        XCTAssertNil(question.difficulty)
        XCTAssertNil(question.type)
        XCTAssertNil(question.relatedContent)
        XCTAssertNil(question.relatedTimestamp)
    }

    // MARK: - QuizAttempt Decoding

    func testQuizAttempt_decodesFromFullJSON() throws {
        let json = JSONFactory.quizAttemptJSON(
            id: "attempt-abc",
            quizId: "quiz-123",
            userId: "user-456",
            status: "completed",
            startedAt: "2025-01-15T10:00:00.000Z",
            completedAt: "2025-01-15T10:30:00.000Z"
        )
        let data = JSONFactory.data(from: json)

        let attempt = try decoder.decode(QuizAttempt.self, from: data)

        XCTAssertEqual(attempt.id, "attempt-abc")
        XCTAssertEqual(attempt.quizId, "quiz-123")
        XCTAssertEqual(attempt.userId, "user-456")
        XCTAssertEqual(attempt.status, "completed")
        XCTAssertEqual(attempt.startedAt, "2025-01-15T10:00:00.000Z")
        XCTAssertEqual(attempt.completedAt, "2025-01-15T10:30:00.000Z")
    }

    func testQuizAttempt_idMapsFromUnderscore() throws {
        let json = JSONFactory.quizAttemptJSON(id: "underscore_attempt")
        let data = JSONFactory.data(from: json)
        let attempt = try decoder.decode(QuizAttempt.self, from: data)
        XCTAssertEqual(attempt.id, "underscore_attempt")
    }

    func testQuizAttempt_missingOptionalFields() throws {
        let json = JSONFactory.quizAttemptJSON(completedAt: nil)
        let data = JSONFactory.data(from: json)
        let attempt = try decoder.decode(QuizAttempt.self, from: data)
        XCTAssertNil(attempt.completedAt)
    }

    // MARK: - QuizAnswer Decoding

    func testQuizAnswer_decodesFromJSON() throws {
        let json: [String: Any] = [
            "questionIndex": 2,
            "selectedAnswer": 1,
            "timeTaken": 25
        ]
        let data = JSONFactory.data(from: json)

        let answer = try decoder.decode(QuizAnswer.self, from: data)

        XCTAssertEqual(answer.questionIndex, 2)
        XCTAssertEqual(answer.selectedAnswer, 1)
        XCTAssertEqual(answer.timeTaken, 25)
    }

    func testQuizAnswer_optionalTimeTaken() throws {
        let json: [String: Any] = [
            "questionIndex": 0,
            "selectedAnswer": 3
        ]
        let data = JSONFactory.data(from: json)

        let answer = try decoder.decode(QuizAnswer.self, from: data)

        XCTAssertNil(answer.timeTaken)
    }

    // MARK: - QuizScore Decoding

    func testQuizScore_decodesFromJSON() throws {
        let json: [String: Any] = [
            "total": 10,
            "correct": 7,
            "incorrect": 2,
            "skipped": 1,
            "percentage": 70.0
        ]
        let data = JSONFactory.data(from: json)

        let score = try decoder.decode(QuizScore.self, from: data)

        XCTAssertEqual(score.total, 10)
        XCTAssertEqual(score.correct, 7)
        XCTAssertEqual(score.incorrect, 2)
        XCTAssertEqual(score.skipped, 1)
        XCTAssertEqual(score.percentage, 70.0, accuracy: 0.001)
    }

    // MARK: - TopicBreakdown Decoding

    func testTopicBreakdown_decodesFromJSON() throws {
        let json: [String: Any] = [
            "topic": "Closures",
            "correct": 3,
            "total": 5,
            "percentage": 60.0
        ]
        let data = JSONFactory.data(from: json)

        let breakdown = try decoder.decode(TopicBreakdown.self, from: data)

        XCTAssertEqual(breakdown.topic, "Closures")
        XCTAssertEqual(breakdown.correct, 3)
        XCTAssertEqual(breakdown.total, 5)
        XCTAssertEqual(breakdown.percentage, 60.0, accuracy: 0.001)
    }

    // MARK: - QuizAnalysis Decoding

    func testQuizAnalysis_decodesFromFullJSON() throws {
        let json: [String: Any] = [
            "strengths": ["Variables", "Functions"],
            "weaknesses": ["Closures"],
            "missedConcepts": [
                [
                    "concept": "Trailing closure syntax",
                    "contentId": "content-abc",
                    "timestamp": 150.0,
                    "suggestion": "Review closure section"
                ]
            ],
            "confidenceScore": 0.75,
            "comparisonToPrevious": [
                "previousScore": 60.0,
                "improvement": 10.0,
                "trend": "improving"
            ]
        ]
        let data = JSONFactory.data(from: json)

        let analysis = try decoder.decode(QuizAnalysis.self, from: data)

        XCTAssertEqual(analysis.strengths, ["Variables", "Functions"])
        XCTAssertEqual(analysis.weaknesses, ["Closures"])
        XCTAssertEqual(analysis.missedConcepts?.count, 1)
        XCTAssertEqual(analysis.missedConcepts?.first?.concept, "Trailing closure syntax")
        XCTAssertEqual(analysis.confidenceScore, 0.75, accuracy: 0.001)
        XCTAssertEqual(analysis.comparisonToPrevious?.previousScore, 60.0, accuracy: 0.001)
        XCTAssertEqual(analysis.comparisonToPrevious?.improvement, 10.0, accuracy: 0.001)
        XCTAssertEqual(analysis.comparisonToPrevious?.trend, .improving)
    }

    func testQuizAnalysis_optionalFieldsMissing() throws {
        let json: [String: Any] = [
            "strengths": ["Basics"],
            "weaknesses": []
        ]
        let data = JSONFactory.data(from: json)

        let analysis = try decoder.decode(QuizAnalysis.self, from: data)

        XCTAssertEqual(analysis.strengths, ["Basics"])
        XCTAssertTrue(analysis.weaknesses.isEmpty)
        XCTAssertNil(analysis.missedConcepts)
        XCTAssertNil(analysis.confidenceScore)
        XCTAssertNil(analysis.comparisonToPrevious)
    }

    // MARK: - MissedConcept Decoding

    func testMissedConcept_decodesFromJSON() throws {
        let json: [String: Any] = [
            "concept": "Generics",
            "contentId": "content-gen",
            "timestamp": 450.0,
            "suggestion": "Watch the generics tutorial"
        ]
        let data = JSONFactory.data(from: json)

        let missed = try decoder.decode(MissedConcept.self, from: data)

        XCTAssertEqual(missed.concept, "Generics")
        XCTAssertEqual(missed.contentId, "content-gen")
        XCTAssertEqual(missed.timestamp, 450.0, accuracy: 0.001)
        XCTAssertEqual(missed.suggestion, "Watch the generics tutorial")
    }

    func testMissedConcept_optionalFieldsMissing() throws {
        let json: [String: Any] = [
            "concept": "Async/Await"
        ]
        let data = JSONFactory.data(from: json)

        let missed = try decoder.decode(MissedConcept.self, from: data)

        XCTAssertEqual(missed.concept, "Async/Await")
        XCTAssertNil(missed.contentId)
        XCTAssertNil(missed.timestamp)
        XCTAssertNil(missed.suggestion)
    }

    // MARK: - ComparisonToPrevious Decoding

    func testComparisonToPrevious_decodesFromJSON() throws {
        let json: [String: Any] = [
            "previousScore": 55.0,
            "improvement": 15.0,
            "trend": "improving"
        ]
        let data = JSONFactory.data(from: json)

        let comparison = try decoder.decode(ComparisonToPrevious.self, from: data)

        XCTAssertEqual(comparison.previousScore, 55.0, accuracy: 0.001)
        XCTAssertEqual(comparison.improvement, 15.0, accuracy: 0.001)
        XCTAssertEqual(comparison.trend, .improving)
    }

    func testComparisonToPrevious_optionalFieldsMissing() throws {
        let json: [String: Any] = [:]
        let data = JSONFactory.data(from: json)

        let comparison = try decoder.decode(ComparisonToPrevious.self, from: data)

        XCTAssertNil(comparison.previousScore)
        XCTAssertNil(comparison.improvement)
        XCTAssertNil(comparison.trend)
    }

    // MARK: - Enum Decoding: QuizType

    func testQuizType_allCases() throws {
        let cases: [(String, QuizType)] = [
            ("topic_consolidation", .topicConsolidation),
            ("weekly_review", .weeklyReview),
            ("milestone_assessment", .milestoneAssessment),
            ("retention_check", .retentionCheck),
            ("on_demand", .onDemand),
            ("playlist_mastery", .playlistMastery)
        ]

        for (raw, expected) in cases {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try decoder.decode(QuizType.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed for raw value: \(raw)")
        }
    }

    func testQuizType_invalidValue_throws() {
        let data = "\"unknown_type\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(QuizType.self, from: data))
    }

    // MARK: - Enum Decoding: QuizStatus

    func testQuizStatus_allCases() throws {
        let cases: [(String, QuizStatus)] = [
            ("generating", .generating),
            ("ready", .ready),
            ("delivered", .delivered),
            ("in_progress", .inProgress),
            ("completed", .completed),
            ("expired", .expired)
        ]

        for (raw, expected) in cases {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try decoder.decode(QuizStatus.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed for raw value: \(raw)")
        }
    }

    func testQuizStatus_invalidValue_throws() {
        let data = "\"cancelled\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(QuizStatus.self, from: data))
    }

    // MARK: - Enum Decoding: Trend

    func testTrend_allCases() throws {
        let cases: [(String, Trend)] = [
            ("improving", .improving),
            ("stable", .stable),
            ("declining", .declining)
        ]

        for (raw, expected) in cases {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try decoder.decode(Trend.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed for raw value: \(raw)")
        }
    }

    // MARK: - Identifiable Conformance

    func testQuiz_conformsToIdentifiable() throws {
        let json = JSONFactory.quizJSON(id: "quiz-identifiable")
        let data = JSONFactory.data(from: json)
        let quiz = try decoder.decode(Quiz.self, from: data)
        XCTAssertEqual(quiz.id, "quiz-identifiable")
    }

    func testQuizAttempt_conformsToIdentifiable() throws {
        let json = JSONFactory.quizAttemptJSON(id: "attempt-identifiable")
        let data = JSONFactory.data(from: json)
        let attempt = try decoder.decode(QuizAttempt.self, from: data)
        XCTAssertEqual(attempt.id, "attempt-identifiable")
    }

    // MARK: - QuizAttempt with Analysis

    func testQuizAttempt_withFullAnalysis() throws {
        var json = JSONFactory.quizAttemptJSON()
        json["topicBreakdown"] = [
            ["topic": "Variables", "correct": 2, "total": 3, "percentage": 66.7]
        ]
        json["analysis"] = [
            "strengths": ["Variables"],
            "weaknesses": ["Closures"],
            "confidenceScore": 0.8
        ] as [String: Any]
        let data = JSONFactory.data(from: json)

        let attempt = try decoder.decode(QuizAttempt.self, from: data)

        XCTAssertEqual(attempt.topicBreakdown?.count, 1)
        XCTAssertEqual(attempt.topicBreakdown?.first?.topic, "Variables")
        XCTAssertNotNil(attempt.analysis)
        XCTAssertEqual(attempt.analysis?.strengths, ["Variables"])
        XCTAssertEqual(attempt.analysis?.confidenceScore, 0.8, accuracy: 0.001)
    }
}
