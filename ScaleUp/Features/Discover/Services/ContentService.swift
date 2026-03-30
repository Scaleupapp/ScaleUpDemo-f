import Foundation

// MARK: - Content Service

actor ContentService {

    private let api = APIClient.shared

    // MARK: - Content

    func fetchContent(id: String) async throws -> Content {
        try await api.request(ContentEndpoints.detail(id: id))
    }

    func explore(
        search: String? = nil,
        domain: String? = nil,
        difficulty: String? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> [Content] {
        try await api.request(ContentEndpoints.explore(
            search: search, domain: domain, difficulty: difficulty, page: page, limit: limit
        ))
    }

    // MARK: - Recommendations

    func fetchRecommendations(limit: Int = 15) async throws -> [Content] {
        try await api.request(ContentEndpoints.recommendations(limit: limit))
    }

    func fetchTrending(limit: Int = 10) async throws -> [Content] {
        let wrapper: ItemsWrapper<Content> = try await api.request(ContentEndpoints.trending(limit: limit))
        return wrapper.items
    }

    func fetchGapContent(limit: Int = 10) async throws -> [Content] {
        let wrapper: ItemsWrapper<Content> = try await api.request(ContentEndpoints.gaps(limit: limit))
        return wrapper.items
    }

    func fetchObjectiveContent(objectiveId: String, limit: Int = 10) async throws -> [Content] {
        let wrapper: ItemsWrapper<Content> = try await api.request(ContentEndpoints.forObjective(id: objectiveId, limit: limit))
        return wrapper.items
    }

    func fetchSimilar(contentId: String, limit: Int = 10) async throws -> [Content] {
        let wrapper: ItemsWrapper<Content> = try await api.request(ContentEndpoints.similar(id: contentId, limit: limit))
        return wrapper.items
    }

    // MARK: - Interactions

    func toggleLike(contentId: String) async throws -> LikeResponse {
        try await api.request(ContentEndpoints.like(id: contentId))
    }

    func toggleSave(contentId: String) async throws -> SaveResponse {
        try await api.request(ContentEndpoints.save(id: contentId))
    }

    func rate(contentId: String, value: Int) async throws {
        let body = RateRequest(value: value)
        _ = try await api.requestRaw(ContentEndpoints.rate(id: contentId), body: body)
    }

    func fetchInteractionStatus(contentId: String) async throws -> InteractionStatus {
        try await api.request(ContentEndpoints.interactionStatus(id: contentId))
    }

    func reportContent(contentId: String, reason: String, description: String?) async throws {
        let body = ReportRequest(reason: reason, description: description)
        _ = try await api.requestRaw(ContentEndpoints.report(id: contentId), body: body)
    }

    // MARK: - Creator

    func fetchCreator(id: String) async throws -> Creator {
        try await api.request(ContentEndpoints.creator(id: id))
    }

    func fetchCreatorContent(creatorId: String, page: Int = 1) async throws -> [Content] {
        try await api.request(ContentEndpoints.creatorContent(id: creatorId, page: page))
    }

    func searchCreators(
        search: String? = nil,
        domain: String? = nil,
        tier: String? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> [Creator] {
        try await api.request(ContentEndpoints.searchCreators(
            search: search, domain: domain, tier: tier, page: page, limit: limit
        ))
    }

    // MARK: - Learning Paths

    func exploreLearningPaths(
        search: String? = nil,
        domain: String? = nil,
        difficulty: String? = nil,
        page: Int = 1,
        limit: Int = 10
    ) async throws -> [LearningPath] {
        try await api.request(ContentEndpoints.learningPaths(
            search: search, domain: domain, difficulty: difficulty, page: page, limit: limit
        ))
    }
}

// MARK: - Response Types

struct ItemsWrapper<T: Codable & Sendable>: Codable, Sendable {
    let items: [T]
}

struct LikeResponse: Codable, Sendable {
    let liked: Bool
    let likeCount: Int
}

struct SaveResponse: Codable, Sendable {
    let saved: Bool
    let saveCount: Int
}

struct InteractionStatus: Codable, Sendable {
    let isLiked: Bool
    let isSaved: Bool
    let userRating: Int
}

private struct RateRequest: Encodable, Sendable {
    let value: Int
}

private struct ReportRequest: Encodable, Sendable {
    let reason: String
    let description: String?
}

// MARK: - Endpoints

private enum ContentEndpoints: Endpoint {
    case detail(id: String)
    case explore(search: String?, domain: String?, difficulty: String?, page: Int, limit: Int)
    case recommendations(limit: Int)
    case trending(limit: Int)
    case gaps(limit: Int)
    case forObjective(id: String, limit: Int)
    case similar(id: String, limit: Int)
    case interactionStatus(id: String)
    case like(id: String)
    case save(id: String)
    case rate(id: String)
    case report(id: String)
    case creator(id: String)
    case creatorContent(id: String, page: Int)
    case searchCreators(search: String?, domain: String?, tier: String?, page: Int, limit: Int)
    case learningPaths(search: String?, domain: String?, difficulty: String?, page: Int, limit: Int)

    var path: String {
        switch self {
        case .interactionStatus(let id): return "/content/\(id)/interaction-status"
        case .detail(let id): return "/content/\(id)"
        case .explore: return "/content/explore"
        case .recommendations: return "/recommendations/feed"
        case .trending: return "/recommendations/trending"
        case .gaps: return "/recommendations/gaps"
        case .forObjective(let id, _): return "/recommendations/objective/\(id)"
        case .similar(let id, _): return "/recommendations/similar/\(id)"
        case .like(let id): return "/content/\(id)/like"
        case .save(let id): return "/content/\(id)/save"
        case .rate(let id): return "/content/\(id)/rate"
        case .report(let id): return "/content/\(id)/report"
        case .creator(let id): return "/creator/\(id)"
        case .creatorContent: return "/content/explore"
        case .searchCreators: return "/creator/search"
        case .learningPaths: return "/learning-paths/explore"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .like, .save, .rate, .report: return .post
        default: return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .explore(let search, let domain, let difficulty, let page, let limit):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let s = search, !s.isEmpty { items.append(URLQueryItem(name: "search", value: s)) }
            if let d = domain, !d.isEmpty { items.append(URLQueryItem(name: "domain", value: d)) }
            if let df = difficulty, !df.isEmpty { items.append(URLQueryItem(name: "difficulty", value: df)) }
            return items
        case .recommendations(let limit), .trending(let limit), .gaps(let limit):
            return [URLQueryItem(name: "limit", value: "\(limit)")]
        case .forObjective(_, let limit), .similar(_, let limit):
            return [URLQueryItem(name: "limit", value: "\(limit)")]
        case .creatorContent(let id, let page):
            return [
                URLQueryItem(name: "creatorId", value: id),
                URLQueryItem(name: "page", value: "\(page)")
            ]
        case .searchCreators(let search, let domain, let tier, let page, let limit):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let s = search, !s.isEmpty { items.append(URLQueryItem(name: "search", value: s)) }
            if let d = domain, !d.isEmpty { items.append(URLQueryItem(name: "domain", value: d)) }
            if let t = tier, !t.isEmpty { items.append(URLQueryItem(name: "tier", value: t)) }
            return items
        case .learningPaths(let search, let domain, let difficulty, let page, let limit):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let s = search, !s.isEmpty { items.append(URLQueryItem(name: "search", value: s)) }
            if let d = domain, !d.isEmpty { items.append(URLQueryItem(name: "domain", value: d)) }
            if let df = difficulty, !df.isEmpty { items.append(URLQueryItem(name: "difficulty", value: df)) }
            return items
        default:
            return nil
        }
    }
}
