import SwiftUI

@Observable
@MainActor
final class TopicDetailViewModel {

    // MARK: - State

    let topic: String
    var topicDetail: TopicMasteryEntry?
    var recommendedContent: [Content] = []
    var topicQuiz: Quiz?
    var isLoading = false

    // Generate quiz flow
    var showGenerateSheet = false
    var isGenerating = false
    var generationStatus: String?
    var selectedQuestionCount: Int = 10
    var selectedAssessmentType: AssessmentType = .mixed

    private let knowledgeService = KnowledgeService()
    private let recommendationService = RecommendationService()
    private let quizService = QuizService()

    init(topic: String) {
        self.topic = topic
    }

    // MARK: - Computed

    var score: Int { topicDetail?.scoreValue ?? 0 }
    var level: String { topicDetail?.levelDisplay ?? "Not Started" }
    var trend: Trend? { topicDetail?.trend }
    var quizzesTaken: Int { topicDetail?.quizzesTaken ?? 0 }

    var scoreHistory: [ScoreHistoryEntry] {
        topicDetail?.scoreHistory ?? []
    }

    var hasExistingQuiz: Bool { topicQuiz != nil }

    // MARK: - Load

    func loadTopicDetail() async {
        isLoading = true

        async let detailTask: TopicMasteryEntry? = {
            try? await self.knowledgeService.getTopicDetail(topic: self.topic)
        }()
        async let contentTask: [Content]? = {
            try? await self.recommendationService.getGapContent(limit: 5)
        }()
        async let quizTask: [Quiz]? = {
            try? await self.quizService.fetchPendingQuizzes()
        }()

        let (detail, content, quizzes) = await (detailTask, contentTask, quizTask)

        topicDetail = detail
        recommendedContent = content ?? []

        // Find a quiz matching this topic
        let lowerTopic = topic.lowercased()
        topicQuiz = quizzes?.first(where: {
            $0.topic.lowercased() == lowerTopic
            || $0.topic.lowercased().contains(lowerTopic)
            || lowerTopic.contains($0.topic.lowercased())
        })

        isLoading = false
    }

    // MARK: - Generate Quiz

    func generateQuiz() async {
        isGenerating = true
        generationStatus = "Queuing..."

        do {
            let response = try await quizService.requestQuiz(
                topic: topic,
                questionCount: selectedQuestionCount,
                assessmentType: selectedAssessmentType.rawValue
            )
            generationStatus = "Generating quiz..."

            if let triggerId = response.triggerId {
                await pollForQuiz(triggerId: triggerId)
            }
        } catch {
            generationStatus = "Failed to generate quiz"
            isGenerating = false
        }
    }

    private func pollForQuiz(triggerId: String) async {
        for _ in 0..<20 {
            try? await Task.sleep(for: .seconds(3))

            if let response = try? await quizService.checkTriggerStatus(triggerId: triggerId) {
                generationStatus = response.status

                if response.status == "generated", response.quizId != nil {
                    generationStatus = "Quiz ready!"
                    isGenerating = false
                    showGenerateSheet = false
                    // Reload to pick up the new quiz
                    let quizzes = try? await quizService.fetchPendingQuizzes()
                    let lowerTopic = topic.lowercased()
                    topicQuiz = quizzes?.first(where: {
                        $0.topic.lowercased() == lowerTopic
                        || $0.topic.lowercased().contains(lowerTopic)
                    })
                    return
                }
                if response.status == "failed" {
                    generationStatus = "Generation failed"
                    isGenerating = false
                    return
                }
            }
        }
        generationStatus = "Timed out"
        isGenerating = false
    }

    // MARK: - Mock Data

    private func loadMockData() {
        topicDetail = TopicMasteryEntry(
            topic: topic,
            score: 65,
            level: "intermediate",
            quizzesTaken: 3,
            lastAssessedAt: Date(),
            scoreHistory: [
                ScoreHistoryEntry(score: 30, date: Date().addingTimeInterval(-86400 * 28)),
                ScoreHistoryEntry(score: 42, date: Date().addingTimeInterval(-86400 * 21)),
                ScoreHistoryEntry(score: 55, date: Date().addingTimeInterval(-86400 * 14)),
                ScoreHistoryEntry(score: 60, date: Date().addingTimeInterval(-86400 * 7)),
                ScoreHistoryEntry(score: 65, date: Date())
            ],
            trend: .improving
        )

        recommendedContent = [
            Content(id: "td1", creatorId: nil, title: "Deep Dive: \(topic)", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1200, sourceType: .youtube, sourceAttribution: nil, domain: "Product Management", topics: [topic], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 2800, likeCount: 180, commentCount: 12, saveCount: 90, averageRating: 4.6, ratingCount: 45, publishedAt: Date(), createdAt: nil),
            Content(id: "td2", creatorId: nil, title: "Advanced \(topic) Strategies", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1800, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: [topic], tags: nil, difficulty: .advanced, aiData: nil, status: .published, viewCount: 1900, likeCount: 120, commentCount: 8, saveCount: 65, averageRating: 4.8, ratingCount: 30, publishedAt: Date(), createdAt: nil)
        ]
    }
}
