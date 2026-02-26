import Foundation

// MARK: - Knowledge Endpoints

enum KnowledgeEndpoints {

    static func profile() -> Endpoint {
        .get("/knowledge/profile")
    }

    static func topic(name: String) -> Endpoint {
        .get("/knowledge/topic/\(name)")
    }

    static func gaps() -> Endpoint {
        .get("/knowledge/gaps")
    }

    static func strengths() -> Endpoint {
        .get("/knowledge/strengths")
    }
}
