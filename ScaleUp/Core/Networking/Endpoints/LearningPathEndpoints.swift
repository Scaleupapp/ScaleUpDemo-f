import Foundation

// MARK: - Learning Path Endpoints

enum LearningPathEndpoints {

    // MARK: - Request Bodies

    struct CreatePathBody: Encodable {
        let title: String
        let description: String?
        let domain: String?
        let difficulty: String?
        let tags: [String]?
    }

    struct UpdatePathBody: Encodable {
        let title: String?
        let description: String?
        let domain: String?
        let difficulty: String?
        let tags: [String]?
    }

    struct AddItemBody: Encodable {
        let contentId: String
        let order: Int?
    }

    struct ReorderBody: Encodable {
        let orderedIds: [String]
    }

    struct RatePathBody: Encodable {
        let rating: Int
    }

    // MARK: - Endpoints

    static func explore() -> Endpoint {
        .get("/learning-paths/explore")
    }

    static func mine() -> Endpoint {
        .get("/learning-paths/mine")
    }

    static func getPath(id: String) -> Endpoint {
        .get("/learning-paths/\(id)")
    }

    static func create(title: String, description: String? = nil, domain: String? = nil, difficulty: String? = nil, tags: [String]? = nil) -> Endpoint {
        .post(
            "/learning-paths",
            body: CreatePathBody(title: title, description: description, domain: domain, difficulty: difficulty, tags: tags)
        )
    }

    static func update(id: String, title: String? = nil, description: String? = nil, domain: String? = nil, difficulty: String? = nil, tags: [String]? = nil) -> Endpoint {
        .put(
            "/learning-paths/\(id)",
            body: UpdatePathBody(title: title, description: description, domain: domain, difficulty: difficulty, tags: tags)
        )
    }

    static func publish(id: String) -> Endpoint {
        .post("/learning-paths/\(id)/publish")
    }

    static func archive(id: String) -> Endpoint {
        .post("/learning-paths/\(id)/archive")
    }

    static func addItem(id: String, contentId: String, order: Int? = nil) -> Endpoint {
        .post("/learning-paths/\(id)/items", body: AddItemBody(contentId: contentId, order: order))
    }

    static func reorder(id: String, orderedIds: [String]) -> Endpoint {
        .put("/learning-paths/\(id)/items/reorder", body: ReorderBody(orderedIds: orderedIds))
    }

    static func removeItem(id: String, contentId: String) -> Endpoint {
        .delete("/learning-paths/\(id)/items/\(contentId)")
    }

    static func follow(id: String) -> Endpoint {
        .post("/learning-paths/\(id)/follow")
    }

    static func unfollow(id: String) -> Endpoint {
        .post("/learning-paths/\(id)/unfollow")
    }

    static func rate(id: String, rating: Int) -> Endpoint {
        .post("/learning-paths/\(id)/rate", body: RatePathBody(rating: rating))
    }
}
