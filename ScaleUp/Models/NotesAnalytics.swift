import Foundation

struct NotesAnalytics: Codable, Sendable {
    let overview: AnalyticsOverview
    let viewsOverTime: [ViewDataPoint]
    let topNotes: [TopNote]
    let domainBreakdown: [DomainStat]
}

struct AnalyticsOverview: Codable, Sendable {
    let totalNotes: Int
    let totalViews: Int
    let totalSaves: Int
    let totalLikes: Int
    let avgQualityScore: Int
    let saveToViewRatio: Double
}

struct ViewDataPoint: Codable, Sendable, Identifiable {
    let date: String
    let views: Int
    var id: String { date }
}

struct TopNote: Codable, Sendable, Identifiable {
    let _id: String
    let title: String
    let viewCount: Int
    let likeCount: Int
    let saveCount: Int
    var id: String { _id }
}

struct DomainStat: Codable, Sendable, Identifiable {
    let domain: String
    let noteCount: Int
    let totalViews: Int
    var id: String { domain }
}
