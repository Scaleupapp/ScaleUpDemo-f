import Foundation

// Rich answer cards from Compass Progress Intelligence. Decoded by `type`;
// unknown types decode to `.unknown` and are rendered as nothing (forward-compatible).

enum CompassCardPayload {
    case readiness(CompassReadinessPayload)
    case activityResult(CompassActivityResultPayload)
    case topicDetail(CompassTopicDetailPayload)
    case weakTopics([CompassWeakTopic])
    case recentActivity([CompassActivityItem])
    case unknown
}

struct CompassCard: Decodable, Identifiable {
    let id = UUID()
    let type: String
    let payload: CompassCardPayload

    private enum CodingKeys: String, CodingKey { case type, payload }
    private struct WeakTopicsWrapper: Decodable { let topics: [CompassWeakTopic] }
    private struct RecentActivityWrapper: Decodable { let items: [CompassActivityItem] }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decode(String.self, forKey: .type)
        type = t
        switch t {
        case "readiness_explanation": payload = .readiness(try c.decode(CompassReadinessPayload.self, forKey: .payload))
        case "activity_result":       payload = .activityResult(try c.decode(CompassActivityResultPayload.self, forKey: .payload))
        case "topic_detail":          payload = .topicDetail(try c.decode(CompassTopicDetailPayload.self, forKey: .payload))
        case "weak_topics":           payload = .weakTopics((try c.decode(WeakTopicsWrapper.self, forKey: .payload)).topics)
        case "recent_activity":       payload = .recentActivity((try c.decode(RecentActivityWrapper.self, forKey: .payload)).items)
        default:                      payload = .unknown
        }
    }
}

struct CompassReadinessPayload: Decodable {
    let value: Double?; let target: Double?; let source: String?
    let distanceToTarget: Double?; let contributors: [Contributor]; let topDraggers: [Dragger]; let note: String
    struct Contributor: Decodable, Identifiable { let id = UUID(); let name: String; let score: Double?; let weight: Double?; let assessed: Bool
        private enum CodingKeys: String, CodingKey { case name, score, weight, assessed } }
    struct Dragger: Decodable, Identifiable { let id = UUID(); let name: String; let score: Double?; let weight: Double?
        private enum CodingKeys: String, CodingKey { case name, score, weight } }
}

struct CompassActivityResultPayload: Decodable {
    let activityType: String; let title: String; let date: String?
    let overallScore: Double?; let scoreLabel: String; let dimensions: [Dimension]; let highlights: Highlights
    struct Dimension: Decodable, Identifiable { let id = UUID(); let name: String; let score: Double?; let feedback: String?
        private enum CodingKeys: String, CodingKey { case name, score, feedback } }
    struct Highlights: Decodable { let strengths: [String]; let improvements: [String] }
}

struct CompassTopicDetailPayload: Decodable {
    let topic: String; let score: Double?; let level: String?; let trend: String?
    let history: [Point]; let misconceptions: [Misconception]; let dueConcepts: [String]
    struct Point: Decodable, Identifiable { let id = UUID(); let score: Double?; let date: String?
        private enum CodingKeys: String, CodingKey { case score, date } }
    struct Misconception: Decodable, Identifiable { let id = UUID(); let tag: String; let explanation: String
        private enum CodingKeys: String, CodingKey { case tag, explanation } }
}

struct CompassWeakTopic: Decodable, Identifiable {
    let id = UUID(); let topic: String; let score: Double?; let trend: String; let assessedBy: [String]
    private enum CodingKeys: String, CodingKey { case topic, score, trend, assessedBy }
}

struct CompassActivityItem: Decodable, Identifiable {
    let id = UUID(); let type: String; let title: String; let score: Double?; let date: String?
    private enum CodingKeys: String, CodingKey { case type, title, score, date }
}
