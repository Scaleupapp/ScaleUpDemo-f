import Foundation

// MARK: - Paginated Result

struct PaginatedResult<T: Sendable>: Sendable {
    let items: [T]
    let total: Int
    let hasNextPage: Bool
}

actor AdminService {
    private let api = APIClient.shared

    func fetchStats() async throws -> AdminStats {
        try await api.request(AdminEndpoints.stats)
    }

    func fetchUsers(search: String? = nil, role: String? = nil, page: Int = 1) async throws -> PaginatedResult<AdminUser> {
        let data = try await api.requestRawData(AdminEndpoints.users(search: search, role: role, page: page))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: dateString) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        let response = try decoder.decode(PaginatedAPIResponse<[AdminUser]>.self, from: data)
        return PaginatedResult(
            items: response.data ?? [],
            total: response.pagination?.total ?? 0,
            hasNextPage: response.pagination?.hasNextPage ?? false
        )
    }

    func banUser(id: String) async throws {
        _ = try await api.requestRaw(AdminEndpoints.ban(userId: id))
    }

    func unbanUser(id: String) async throws {
        _ = try await api.requestRaw(AdminEndpoints.unban(userId: id))
    }

    func fetchApplications(page: Int = 1) async throws -> [CreatorApplication] {
        try await api.request(AdminEndpoints.applications(page: page))
    }

    func rejectApplication(id: String, note: String) async throws {
        let body = AdminRejectRequest(reviewNote: note)
        _ = try await api.requestRaw(AdminEndpoints.rejectApplication(id: id), body: body)
    }

    func moderateContent(id: String, status: String, note: String?) async throws {
        let body = ModerateRequest(moderationStatus: status, moderationNote: note)
        _ = try await api.requestRaw(AdminEndpoints.moderateContent(id: id), body: body)
    }

    func promoteCreator(userId: String, tier: String, reason: String? = nil) async throws {
        let body = PromoteRequest(tier: tier, reason: reason)
        _ = try await api.requestRaw(AdminEndpoints.promoteCreator(userId: userId), body: body)
    }

    func fetchCreators(search: String? = nil, page: Int = 1) async throws -> [Creator] {
        try await api.request(AdminEndpoints.creators(search: search, page: page))
    }

    // MARK: - Content Moderation

    func fetchContent(status: String? = nil, minReports: Int? = nil, search: String? = nil, page: Int = 1) async throws -> PaginatedResult<Content> {
        let data = try await api.requestRawData(AdminEndpoints.content(status: status, minReports: minReports, search: search, page: page))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: dateString) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        let response = try decoder.decode(PaginatedAPIResponse<[Content]>.self, from: data)
        return PaginatedResult(
            items: response.data ?? [],
            total: response.pagination?.total ?? 0,
            hasNextPage: response.pagination?.hasNextPage ?? false
        )
    }

    func removeContent(id: String, reason: String) async throws {
        let body = RemoveContentRequest(reason: reason)
        _ = try await api.requestRaw(AdminEndpoints.removeContent(id: id), body: body)
    }

    func dismissReports(id: String) async throws {
        _ = try await api.requestRaw(AdminEndpoints.dismissReports(id: id))
    }

    func fetchContentReports(contentId: String) async throws -> [ContentReport] {
        try await api.request(AdminEndpoints.contentReports(contentId: contentId))
    }
}

// MARK: - Content Report Model

struct ContentReport: Codable, Sendable, Identifiable {
    let id: String
    let contentId: String
    let reporterId: ReportUser?
    let reason: String
    let description: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case contentId, reporterId, reason, description, createdAt
    }

    var reasonDisplay: String {
        reason.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct ReportUser: Codable, Sendable {
    let id: String?
    let firstName: String?
    let lastName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, email
    }

    var displayName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

// MARK: - Paginated API Response

private struct PaginatedAPIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let pagination: SimplePagination?
}

private struct SimplePagination: Decodable {
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
    let hasNextPage: Bool
    let hasPrevPage: Bool
}

// MARK: - Request Bodies

private struct AdminRejectRequest: Encodable, Sendable {
    let reviewNote: String
}

private struct ModerateRequest: Encodable, Sendable {
    let moderationStatus: String
    let moderationNote: String?
}

private struct PromoteRequest: Encodable, Sendable {
    let tier: String
    let reason: String?
}

private struct RemoveContentRequest: Encodable, Sendable {
    let reason: String
}

// MARK: - Endpoints

private enum AdminEndpoints: Endpoint {
    case stats
    case users(search: String?, role: String?, page: Int)
    case ban(userId: String)
    case unban(userId: String)
    case applications(page: Int)
    case rejectApplication(id: String)
    case moderateContent(id: String)
    case promoteCreator(userId: String)
    case creators(search: String?, page: Int)
    case content(status: String?, minReports: Int?, search: String?, page: Int)
    case removeContent(id: String)
    case dismissReports(id: String)
    case contentReports(contentId: String)

    var path: String {
        switch self {
        case .stats: return "/admin/stats"
        case .users: return "/admin/users"
        case .ban(let id): return "/admin/users/\(id)/ban"
        case .unban(let id): return "/admin/users/\(id)/unban"
        case .applications: return "/admin/applications"
        case .rejectApplication(let id): return "/admin/applications/\(id)/reject"
        case .moderateContent(let id): return "/admin/content/\(id)/moderate"
        case .promoteCreator(let id): return "/admin/creators/\(id)/promote"
        case .creators: return "/admin/creators"
        case .content: return "/admin/content"
        case .removeContent(let id): return "/admin/content/\(id)/remove"
        case .dismissReports(let id): return "/admin/content/\(id)/dismiss"
        case .contentReports(let id): return "/admin/content/\(id)/reports"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .stats, .users, .applications, .content, .contentReports, .creators: return .get
        case .ban, .unban, .moderateContent, .promoteCreator, .removeContent, .dismissReports: return .put
        case .rejectApplication: return .post
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .users(let search, let role, let page):
            var items = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
            if let search { items.append(URLQueryItem(name: "search", value: search)) }
            if let role { items.append(URLQueryItem(name: "role", value: role)) }
            return items
        case .applications(let page):
            return [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
        case .creators(let search, let page):
            var items = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "50")]
            if let search { items.append(URLQueryItem(name: "search", value: search)) }
            return items
        case .content(let status, let minReports, let search, let page):
            var items = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
            if let status { items.append(URLQueryItem(name: "status", value: status)) }
            if let minReports { items.append(URLQueryItem(name: "minReports", value: "\(minReports)")) }
            if let search { items.append(URLQueryItem(name: "search", value: search)) }
            return items
        default:
            return nil
        }
    }
}
