import Foundation

// Rich answer cards from Compass Progress Intelligence. Decoded by `type`;
// unknown types decode to `.unknown` and are rendered as nothing (forward-compatible).
//
// These are response-only types, but the V2 API client constrains response models
// to `Codable`, so they conform to Codable. encode(to:) is provided for CompassCard
// (its enum payload can't be synthesized) but is never exercised at runtime.

enum CompassCardPayload {
    case readiness(CompassReadinessPayload)
    case activityResult(CompassActivityResultPayload)
    case topicDetail(CompassTopicDetailPayload)
    case weakTopics([CompassWeakTopic])
    case recentActivity([CompassActivityItem])
    case tutoringResult(CompassTutoringResultPayload)
    case unknown
}

struct CompassCard: Codable, Identifiable {
    let id = UUID()
    let type: String
    let payload: CompassCardPayload

    private enum CodingKeys: String, CodingKey { case type, payload }
    private struct WeakTopicsWrapper: Codable { let topics: [CompassWeakTopic] }
    private struct RecentActivityWrapper: Codable { let items: [CompassActivityItem] }

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
        case "tutoring_result":       payload = .tutoringResult(try c.decode(CompassTutoringResultPayload.self, forKey: .payload))
        default:                      payload = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        switch payload {
        case .readiness(let p):       try c.encode(p, forKey: .payload)
        case .activityResult(let p):  try c.encode(p, forKey: .payload)
        case .topicDetail(let p):     try c.encode(p, forKey: .payload)
        case .weakTopics(let t):      try c.encode(WeakTopicsWrapper(topics: t), forKey: .payload)
        case .recentActivity(let i):  try c.encode(RecentActivityWrapper(items: i), forKey: .payload)
        case .tutoringResult(let p):  try c.encode(p, forKey: .payload)
        case .unknown:                try c.encodeNil(forKey: .payload)
        }
    }
}

struct CompassReadinessPayload: Codable {
    let value: Double?; let target: Double?; let source: String?
    let distanceToTarget: Double?; let contributors: [Contributor]; let topDraggers: [Dragger]; let note: String
    struct Contributor: Codable, Identifiable { let id = UUID(); let name: String; let score: Double?; let weight: Double?; let assessed: Bool
        private enum CodingKeys: String, CodingKey { case name, score, weight, assessed } }
    struct Dragger: Codable, Identifiable { let id = UUID(); let name: String; let score: Double?; let weight: Double?
        private enum CodingKeys: String, CodingKey { case name, score, weight } }
}

struct CompassActivityResultPayload: Codable {
    let activityType: String; let title: String; let date: String?
    let overallScore: Double?; let scoreLabel: String; let dimensions: [Dimension]; let highlights: Highlights
    struct Dimension: Codable, Identifiable { let id = UUID(); let name: String; let score: Double?; let feedback: String?
        private enum CodingKeys: String, CodingKey { case name, score, feedback } }
    struct Highlights: Codable { let strengths: [String]; let improvements: [String] }
}

struct CompassTopicDetailPayload: Codable {
    let topic: String; let score: Double?; let level: String?; let trend: String?
    let history: [Point]; let misconceptions: [Misconception]; let dueConcepts: [String]
    struct Point: Codable, Identifiable { let id = UUID(); let score: Double?; let date: String?
        private enum CodingKeys: String, CodingKey { case score, date } }
    struct Misconception: Codable, Identifiable { let id = UUID(); let tag: String; let explanation: String
        private enum CodingKeys: String, CodingKey { case tag, explanation } }
}

struct CompassWeakTopic: Codable, Identifiable {
    let id = UUID(); let topic: String; let score: Double?; let trend: String; let assessedBy: [String]
    private enum CodingKeys: String, CodingKey { case topic, score, trend, assessedBy }
}

struct CompassActivityItem: Codable, Identifiable {
    let id = UUID(); let type: String; let title: String; let score: Double?; let date: String?
    private enum CodingKeys: String, CodingKey { case type, title, score, date }
}

struct CompassTutoringResultPayload: Codable {
    let topic: String
    let checkScore: Double?
    let beforeScore: Double?
    let afterScore: Double?
    let delta: Double?
}
