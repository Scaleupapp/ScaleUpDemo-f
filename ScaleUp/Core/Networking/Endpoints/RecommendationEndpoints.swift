import Foundation

// MARK: - Recommendation Endpoints

enum RecommendationEndpoints {

    static func feed() -> Endpoint {
        .get("/recommendations/feed")
    }

    static func similar(id: String) -> Endpoint {
        .get("/recommendations/similar/\(id)")
    }

    static func objective(id: String) -> Endpoint {
        .get("/recommendations/objective/\(id)")
    }

    static func gaps() -> Endpoint {
        .get("/recommendations/gaps")
    }

    static func trending() -> Endpoint {
        .get("/recommendations/trending")
    }
}
