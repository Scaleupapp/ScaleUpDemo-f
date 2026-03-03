import Foundation

actor CreatorService {
    private let api = APIClient.shared

    func apply(body: CreatorApplyRequest) async throws -> CreatorApplication {
        try await api.request(CreatorEndpoints.apply, body: body)
    }

    func fetchMyApplication() async throws -> CreatorApplication {
        try await api.request(CreatorEndpoints.myApplication)
    }

    func fetchMyProfile() async throws -> CreatorProfileData {
        try await api.request(CreatorEndpoints.myProfile)
    }

    func updateProfile(bio: String?, specializations: [String]?) async throws -> CreatorProfileData {
        let body = UpdateCreatorProfileRequest(bio: bio, specializations: specializations)
        return try await api.request(CreatorEndpoints.updateProfile, body: body)
    }

    func fetchPendingApplications(domain: String? = nil, page: Int = 1) async throws -> [CreatorApplication] {
        try await api.request(CreatorEndpoints.pendingApplications(domain: domain, page: page))
    }

    func endorseApplication(id: String, note: String?) async throws {
        let body = EndorseRequest(note: note)
        _ = try await api.requestRaw(CreatorEndpoints.endorse(applicationId: id), body: body)
    }

    func rejectApplication(id: String, note: String) async throws {
        let body = RejectRequest(note: note)
        _ = try await api.requestRaw(CreatorEndpoints.reject(applicationId: id), body: body)
    }

    func searchCreators(search: String? = nil, domain: String? = nil, tier: String? = nil, page: Int = 1) async throws -> [Creator] {
        try await api.request(CreatorEndpoints.search(search: search, domain: domain, tier: tier, page: page))
    }
}

// MARK: - Request Bodies

struct CreatorApplyRequest: Encodable, Sendable {
    let domain: String
    let specializations: [String]
    let experience: String
    let motivation: String
    let sampleContentLinks: [String]
    let portfolioUrl: String?
    let socialLinks: SocialLinksInput?
}

struct SocialLinksInput: Encodable, Sendable {
    var linkedin: String?
    var twitter: String?
    var youtube: String?
    var website: String?
}

private struct UpdateCreatorProfileRequest: Encodable, Sendable {
    let bio: String?
    let specializations: [String]?
}

private struct EndorseRequest: Encodable, Sendable {
    let note: String?
}

private struct RejectRequest: Encodable, Sendable {
    let note: String
}

// MARK: - Endpoints

private enum CreatorEndpoints: Endpoint {
    case apply
    case myApplication
    case myProfile
    case updateProfile
    case pendingApplications(domain: String?, page: Int)
    case endorse(applicationId: String)
    case reject(applicationId: String)
    case search(search: String?, domain: String?, tier: String?, page: Int)

    var path: String {
        switch self {
        case .apply: return "/creator/apply"
        case .myApplication: return "/creator/application"
        case .myProfile, .updateProfile: return "/creator/profile"
        case .pendingApplications: return "/creator/applications"
        case .endorse(let id): return "/creator/applications/\(id)/endorse"
        case .reject(let id): return "/creator/applications/\(id)/reject"
        case .search: return "/creator/search"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .myApplication, .myProfile, .pendingApplications, .search: return .get
        case .apply, .endorse, .reject: return .post
        case .updateProfile: return .put
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .pendingApplications(let domain, let page):
            var items = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
            if let domain { items.append(URLQueryItem(name: "domain", value: domain)) }
            return items
        case .search(let search, let domain, let tier, let page):
            var items = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
            if let search { items.append(URLQueryItem(name: "search", value: search)) }
            if let domain { items.append(URLQueryItem(name: "domain", value: domain)) }
            if let tier { items.append(URLQueryItem(name: "tier", value: tier)) }
            return items
        default:
            return nil
        }
    }
}
