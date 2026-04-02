import Foundation

// MARK: - Note Request Service

actor NoteRequestService {

    // MARK: - Fetch

    func fetchRequests(domain: String? = nil, sort: String = "recent", page: Int = 1) async throws -> [NoteRequest] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "20"),
        ]
        if let domain { items.append(URLQueryItem(name: "domain", value: domain)) }
        return try await APIClient.shared.request(NoteRequestEndpoints.list(queryItems: items))
    }

    func fetchMyRequests() async throws -> [NoteRequest] {
        return try await APIClient.shared.request(NoteRequestEndpoints.mine)
    }

    func fetchDetail(id: String) async throws -> NoteRequest {
        return try await APIClient.shared.request(NoteRequestEndpoints.detail(id: id))
    }

    // MARK: - Create

    func createRequest(title: String, description: String?, domain: String, difficulty: String?) async throws -> NoteRequest {
        struct Body: Encodable { let title: String; let description: String?; let domain: String; let difficulty: String? }
        return try await APIClient.shared.request(NoteRequestEndpoints.create, body: Body(title: title, description: description, domain: domain, difficulty: difficulty))
    }

    // MARK: - Actions

    struct UpvoteResponse: Decodable, Sendable { let upvoted: Bool; let upvoteCount: Int }

    func toggleUpvote(id: String) async throws -> UpvoteResponse {
        return try await APIClient.shared.request(NoteRequestEndpoints.upvote(id: id))
    }

    func claimRequest(id: String) async throws {
        _ = try await APIClient.shared.requestRaw(NoteRequestEndpoints.claim(id: id))
    }

    func fulfillRequest(id: String, contentId: String) async throws {
        struct Body: Encodable { let contentId: String }
        _ = try await APIClient.shared.requestRaw(NoteRequestEndpoints.fulfill(id: id), body: Body(contentId: contentId))
    }

    func deleteRequest(id: String) async throws {
        _ = try await APIClient.shared.requestRaw(NoteRequestEndpoints.delete(id: id))
    }
}


// MARK: - Endpoints

private enum NoteRequestEndpoints: Endpoint {
    case list(queryItems: [URLQueryItem])
    case mine
    case detail(id: String)
    case create
    case upvote(id: String)
    case claim(id: String)
    case fulfill(id: String)
    case delete(id: String)

    var path: String {
        switch self {
        case .list: return "/note-requests"
        case .mine: return "/note-requests/mine"
        case .detail(let id): return "/note-requests/\(id)"
        case .create: return "/note-requests"
        case .upvote(let id): return "/note-requests/\(id)/upvote"
        case .claim(let id): return "/note-requests/\(id)/claim"
        case .fulfill(let id): return "/note-requests/\(id)/fulfill"
        case .delete(let id): return "/note-requests/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .mine, .detail: return .get
        case .create, .upvote, .claim, .fulfill: return .post
        case .delete: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let items): return items
        default: return nil
        }
    }
}
