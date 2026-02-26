import Foundation

// MARK: - Admin Endpoints

enum AdminEndpoints {

    // MARK: - Request Bodies

    struct RejectApplicationBody: Encodable {
        let reviewNote: String?
    }

    struct ModerateContentBody: Encodable {
        let status: String
        let note: String?
    }

    // MARK: - Endpoints

    static func stats() -> Endpoint {
        .get("/admin/stats")
    }

    static func users(page: Int? = nil, limit: Int? = nil, role: String? = nil, search: String? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let role { queryItems.append(URLQueryItem(name: "role", value: role)) }
        if let search { queryItems.append(URLQueryItem(name: "search", value: search)) }

        return .get("/admin/users", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func ban(userId: String) -> Endpoint {
        .post("/admin/users/\(userId)/ban")
    }

    static func unban(userId: String) -> Endpoint {
        .post("/admin/users/\(userId)/unban")
    }

    static func applications(page: Int? = nil, limit: Int? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return .get("/admin/applications", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func rejectApplication(id: String, reviewNote: String? = nil) -> Endpoint {
        .post("/admin/applications/\(id)/reject", body: RejectApplicationBody(reviewNote: reviewNote))
    }

    static func moderateContent(id: String, status: String, note: String? = nil) -> Endpoint {
        .post("/admin/content/\(id)/moderate", body: ModerateContentBody(status: status, note: note))
    }
}
