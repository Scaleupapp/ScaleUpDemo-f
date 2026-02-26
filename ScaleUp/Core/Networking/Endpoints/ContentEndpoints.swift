import Foundation

// MARK: - Content Endpoints

enum ContentEndpoints {

    // MARK: - Request Bodies

    struct RateBody: Encodable {
        let value: Int
    }

    struct AddCommentBody: Encodable {
        let text: String
        let parentId: String?
    }

    struct RequestUploadBody: Encodable {
        let fileName: String
        let fileType: String
        let contentType: String
    }

    struct CompleteUploadBody: Encodable {
        let uploadId: String
        let fileUrl: String
        let title: String
        let description: String?
        let domain: String?
        let difficulty: String?
        let tags: [String]?
    }

    struct UpdateContentBody: Encodable {
        let title: String?
        let description: String?
        let domain: String?
        let difficulty: String?
        let tags: [String]?
    }

    // MARK: - Endpoints

    static func feed() -> Endpoint {
        .get("/content/feed")
    }

    static func explore(
        domain: String? = nil,
        difficulty: String? = nil,
        search: String? = nil,
        creatorId: String? = nil,
        page: Int? = nil,
        limit: Int? = nil
    ) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let domain { queryItems.append(URLQueryItem(name: "domain", value: domain)) }
        if let difficulty { queryItems.append(URLQueryItem(name: "difficulty", value: difficulty)) }
        if let search { queryItems.append(URLQueryItem(name: "search", value: search)) }
        if let creatorId { queryItems.append(URLQueryItem(name: "creatorId", value: creatorId)) }
        if let page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return .get("/content/explore", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func getContent(id: String) -> Endpoint {
        .get("/content/\(id)")
    }

    static func streamUrl(id: String) -> Endpoint {
        .get("/content/\(id)/stream")
    }

    static func likedContent(page: Int? = nil, limit: Int? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        return .get("/content/liked", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func savedContent(page: Int? = nil, limit: Int? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        return .get("/content/saved", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func like(id: String) -> Endpoint {
        .post("/content/\(id)/like")
    }

    static func save(id: String) -> Endpoint {
        .post("/content/\(id)/save")
    }

    static func rate(id: String, value: Int) -> Endpoint {
        .post("/content/\(id)/rate", body: RateBody(value: value))
    }

    static func getComments(id: String, page: Int? = nil, limit: Int? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return .get("/content/\(id)/comments", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func addComment(id: String, text: String, parentId: String? = nil) -> Endpoint {
        .post("/content/\(id)/comments", body: AddCommentBody(text: text, parentId: parentId))
    }

    static func requestUpload(fileName: String, fileType: String, contentType: String) -> Endpoint {
        .post("/content/upload/request", body: RequestUploadBody(fileName: fileName, fileType: fileType, contentType: contentType))
    }

    static func completeUpload(uploadId: String, fileUrl: String, title: String, description: String? = nil, domain: String? = nil, difficulty: String? = nil, tags: [String]? = nil) -> Endpoint {
        .post(
            "/content/upload/complete",
            body: CompleteUploadBody(
                uploadId: uploadId,
                fileUrl: fileUrl,
                title: title,
                description: description,
                domain: domain,
                difficulty: difficulty,
                tags: tags
            )
        )
    }

    static func myContent() -> Endpoint {
        .get("/content/my")
    }

    static func update(id: String, title: String? = nil, description: String? = nil, domain: String? = nil, difficulty: String? = nil, tags: [String]? = nil) -> Endpoint {
        .put(
            "/content/\(id)",
            body: UpdateContentBody(title: title, description: description, domain: domain, difficulty: difficulty, tags: tags)
        )
    }

    static func publish(id: String) -> Endpoint {
        .post("/content/\(id)/publish")
    }

    static func unpublish(id: String) -> Endpoint {
        .post("/content/\(id)/unpublish")
    }
}
