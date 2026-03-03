import SwiftUI

enum QuizListTab: String, CaseIterable {
    case available = "Available"
    case completed = "Completed"
}

@Observable
@MainActor
final class QuizListViewModel {

    var selectedTab: QuizListTab = .available
    var allQuizzes: [Quiz] = []
    var skillAssessments: [Quiz] = []
    var completedAttempts: [QuizAttempt] = []
    var isLoading = false
    var errorMessage: String?

    // On-demand quiz generation
    var isGenerating = false
    var generationTopic = ""
    var generationTriggerId: String?
    var generationStatus: String?
    var generatedQuizId: String?
    var generationFailed = false
    var selectedQuestionCount: Int = 10
    var selectedAssessmentType: AssessmentType = .mixed
    var userObjective: Objective?
    var linkToObjective: Bool = false

    private let quizService = QuizService()
    private let dashboardService = DashboardService()
    private var pollTask: Task<Void, Never>?

    // MARK: - Filtered Lists

    var availableQuizzes: [Quiz] {
        allQuizzes.filter { quiz in
            quiz.status == .ready || quiz.status == .delivered || quiz.status == .inProgress
        }
    }

    var liveQuizzes: [Quiz] {
        allQuizzes.filter { $0.status == .inProgress }
    }

    var pendingQuizzes: [Quiz] {
        allQuizzes.filter { $0.status == .ready || $0.status == .delivered }
    }

    var pendingAssessments: [Quiz] {
        skillAssessments.filter { $0.status == .ready || $0.status == .delivered || $0.status == .inProgress }
    }

    var completedAssessments: [Quiz] {
        skillAssessments.filter { $0.status == .completed }
    }

    // MARK: - Load

    func loadQuizzes() async {
        isLoading = true
        errorMessage = nil

        async let quizzesTask: [Quiz] = {
            (try? await self.quizService.fetchAllQuizzes()) ?? []
        }()
        async let historyTask: [QuizAttempt] = {
            (try? await self.quizService.fetchQuizHistory()) ?? []
        }()
        async let assessmentsTask: [Quiz] = {
            (try? await self.quizService.fetchSkillAssessments()) ?? []
        }()

        let (quizzes, history, assessments) = await (quizzesTask, historyTask, assessmentsTask)

        allQuizzes = quizzes
        completedAttempts = history
        skillAssessments = assessments
        isLoading = false
    }

    // MARK: - Request Quiz

    func requestQuiz(topic: String) async {
        isGenerating = true
        generationStatus = "Queuing..."

        do {
            let response = try await quizService.requestQuiz(
                topic: topic,
                questionCount: selectedQuestionCount,
                assessmentType: selectedAssessmentType.rawValue,
                objectiveId: linkToObjective ? userObjective?.id : nil
            )
            generationTriggerId = response.triggerId
            generationStatus = "Generating quiz..."

            // Start polling
            if let triggerId = response.triggerId {
                pollForQuiz(triggerId: triggerId)
            }
        } catch {
            generationStatus = "Failed to generate quiz"
            isGenerating = false
        }
    }

    func loadUserObjective() async {
        guard userObjective == nil else { return }
        if let dashboard = try? await dashboardService.fetchDashboard() {
            userObjective = dashboard.objectives?.first(where: { $0.isPrimary == true }) ?? dashboard.objectives?.first
        }
    }

    func resetGenerationState() {
        generationTopic = ""
        selectedQuestionCount = 10
        selectedAssessmentType = .mixed
        linkToObjective = false
        isGenerating = false
        generationTriggerId = nil
        generationStatus = nil
        generatedQuizId = nil
        generationFailed = false
    }

    private func pollForQuiz(triggerId: String) {
        pollTask?.cancel()
        pollTask = Task {
            for _ in 0..<30 {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }

                if let response = try? await quizService.checkTriggerStatus(triggerId: triggerId) {
                    generationStatus = response.status

                    if response.status == "generated", let quizId = response.quizId {
                        generationStatus = "Quiz ready!"
                        isGenerating = false
                        generatedQuizId = quizId
                        Haptics.success()
                        await loadQuizzes()
                        return
                    }
                    if response.status == "failed" {
                        generationStatus = "Generation failed. Try again."
                        isGenerating = false
                        generationFailed = true
                        Haptics.error()
                        return
                    }
                }
            }
            generationStatus = "Timed out. Try again."
            isGenerating = false
            generationFailed = true
        }
    }

    // MARK: - Mock Data

    private func loadMockData() {
        let now = Date()

        allQuizzes = [
            Quiz(id: "q1", userId: nil, title: "Product Management Fundamentals", type: .retentionCheck, topic: "product management", sourceContentIds: nil,
                 questions: mockQuestions(count: 5),
                 totalQuestions: 5, timePerQuestion: 60, assessmentType: nil, linkedCompetencies: nil, status: .ready,
                 deliveredAt: nil, expiresAt: now.addingTimeInterval(86400 * 5),
                 aiModel: "gpt-4o", generatedAt: now.addingTimeInterval(-3600),
                 createdAt: now.addingTimeInterval(-3600), updatedAt: nil),

            Quiz(id: "q2", userId: nil, title: "Data Science Weekly Review", type: .weeklyReview, topic: "data science", sourceContentIds: nil,
                 questions: mockQuestions(count: 12),
                 totalQuestions: 12, timePerQuestion: 60, assessmentType: nil, linkedCompetencies: nil, status: .ready,
                 deliveredAt: nil, expiresAt: now.addingTimeInterval(86400 * 3),
                 aiModel: "gpt-4o", generatedAt: now.addingTimeInterval(-7200),
                 createdAt: now.addingTimeInterval(-7200), updatedAt: nil),

            Quiz(id: "q3", userId: nil, title: "SEO Strategies Assessment", type: .topicConsolidation, topic: "SEO", sourceContentIds: nil,
                 questions: mockQuestions(count: 10),
                 totalQuestions: 10, timePerQuestion: 60, assessmentType: nil, linkedCompetencies: nil, status: .delivered,
                 deliveredAt: now.addingTimeInterval(-1800), expiresAt: now.addingTimeInterval(86400 * 6),
                 aiModel: "gpt-4o", generatedAt: now.addingTimeInterval(-86400),
                 createdAt: now.addingTimeInterval(-86400), updatedAt: nil),

            Quiz(id: "q4", userId: nil, title: "System Design Mastery", type: .milestoneAssessment, topic: "system design", sourceContentIds: nil,
                 questions: mockQuestions(count: 15),
                 totalQuestions: 15, timePerQuestion: 90, assessmentType: nil, linkedCompetencies: nil, status: .ready,
                 deliveredAt: nil, expiresAt: now.addingTimeInterval(86400 * 7),
                 aiModel: "gpt-4o", generatedAt: now.addingTimeInterval(-86400 * 2),
                 createdAt: now.addingTimeInterval(-86400 * 2), updatedAt: nil)
        ]

        completedAttempts = [
            QuizAttempt(id: "a1", userId: nil,
                       quizId: QuizAttemptQuizInfo(id: "qc1", title: "User Research Basics", type: .retentionCheck, topic: "user research"),
                       answers: [],
                       score: QuizScore(total: 5, correct: 5, incorrect: 0, skipped: 0, percentage: 100),
                       topicBreakdown: [TopicBreakdown(topic: "User Research", correct: 5, total: 5, percentage: 100)],
                       competencyBreakdown: nil,
                       analysis: QuizAnalysis(strengths: ["User Research", "Personas"], weaknesses: nil, missedConcepts: nil, confidenceScore: 80,
                                            comparisonToPrevious: ComparisonData(previousScore: 75, improvement: 25, trend: "improving")),
                       startedAt: now.addingTimeInterval(-86400 * 3), completedAt: now.addingTimeInterval(-86400 * 3 + 300),
                       totalTime: 151.27, status: "completed"),

            QuizAttempt(id: "a2", userId: nil,
                       quizId: QuizAttemptQuizInfo(id: "qc2", title: "Entrepreneurship Knowledge Check", type: .topicConsolidation, topic: "entrepreneurship"),
                       answers: [],
                       score: QuizScore(total: 10, correct: 7, incorrect: 2, skipped: 1, percentage: 70),
                       topicBreakdown: [
                           TopicBreakdown(topic: "Business Model", correct: 3, total: 4, percentage: 75),
                           TopicBreakdown(topic: "Funding", correct: 2, total: 3, percentage: 67),
                           TopicBreakdown(topic: "Pitching", correct: 2, total: 3, percentage: 67)
                       ],
                       competencyBreakdown: nil,
                       analysis: QuizAnalysis(strengths: ["Business Model Canvas"], weaknesses: ["Venture Capital"], missedConcepts: [
                           MissedConcept(concept: "Series A Funding", contentId: nil, timestamp: "12:30", suggestion: "Review the funding stages section")
                       ], confidenceScore: 60,
                                            comparisonToPrevious: ComparisonData(previousScore: 60, improvement: 10, trend: "improving")),
                       startedAt: now.addingTimeInterval(-86400 * 7), completedAt: now.addingTimeInterval(-86400 * 7 + 600),
                       totalTime: 420, status: "completed"),

            QuizAttempt(id: "a3", userId: nil,
                       quizId: QuizAttemptQuizInfo(id: "qc3", title: "API Design Principles", type: .weeklyReview, topic: "API design"),
                       answers: [],
                       score: QuizScore(total: 12, correct: 9, incorrect: 3, skipped: 0, percentage: 75),
                       topicBreakdown: [
                           TopicBreakdown(topic: "REST APIs", correct: 4, total: 4, percentage: 100),
                           TopicBreakdown(topic: "Authentication", correct: 3, total: 4, percentage: 75),
                           TopicBreakdown(topic: "Versioning", correct: 2, total: 4, percentage: 50)
                       ],
                       competencyBreakdown: nil,
                       analysis: QuizAnalysis(strengths: ["REST APIs", "HTTP Methods"], weaknesses: ["API Versioning"], missedConcepts: nil, confidenceScore: 74,
                                            comparisonToPrevious: ComparisonData(previousScore: 80, improvement: -5, trend: "stable")),
                       startedAt: now.addingTimeInterval(-86400 * 14), completedAt: now.addingTimeInterval(-86400 * 14 + 480),
                       totalTime: 360, status: "completed")
        ]
    }

    private func mockQuestions(count: Int) -> [QuizQuestion] {
        (0..<count).map { i in
            QuizQuestion(
                id: "mq\(i)",
                questionText: "Sample question \(i + 1) about the topic?",
                questionType: [.conceptual, .application, .recall][i % 3],
                options: [
                    QuizOption(label: "A", text: "First option", id: "a\(i)"),
                    QuizOption(label: "B", text: "Second option", id: "b\(i)"),
                    QuizOption(label: "C", text: "Third option", id: "c\(i)"),
                    QuizOption(label: "D", text: "Fourth option", id: "d\(i)")
                ],
                correctAnswer: nil,
                explanation: nil,
                difficulty: [.easy, .medium, .hard][i % 3],
                sourceContentId: nil,
                sourceTimestamp: nil,
                concept: "Concept \(i + 1)",
                scenario: nil,
                competency: nil,
                allowTextResponse: nil,
                textPrompt: nil,
                timeLimit: nil
            )
        }
    }
}

// Extension for mock data convenience init
private extension QuizAttemptQuizInfo {
    init(id: String, title: String?, type: QuizType?, topic: String?) {
        self.id = id
        self.title = title
        self.type = type
        self.topic = topic
    }
}
