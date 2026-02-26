import Foundation

// MARK: - Progress Endpoints

enum ProgressEndpoints {

    // MARK: - Request Bodies

    struct UpdateProgressBody: Encodable {
        let currentPosition: Double
        let timeSpent: Double
    }

    // MARK: - Endpoints

    static func update(contentId: String, position: Double, duration: Double) -> Endpoint {
        .put(
            "/progress/\(contentId)",
            body: UpdateProgressBody(currentPosition: position, timeSpent: duration)
        )
    }

    static func complete(contentId: String) -> Endpoint {
        .post("/progress/\(contentId)/complete")
    }

    static func history(limit: Int? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return .get("/progress/history", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func stats() -> Endpoint {
        .get("/progress/stats")
    }
}
