import Foundation

enum QuizType: String, Codable, Hashable {
    case topicConsolidation = "topic_consolidation"
    case weeklyReview = "weekly_review"
    case milestoneAssessment = "milestone_assessment"
    case retentionCheck = "retention_check"
    case onDemand = "on_demand"
    case playlistMastery = "playlist_mastery"
}
