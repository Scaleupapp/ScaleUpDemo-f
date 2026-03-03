import Foundation

actor UserService {
    private let api = APIClient.shared

    func fetchMe() async throws -> User {
        try await api.request(UserEndpoints.me)
    }

    func updateProfile(body: UpdateProfileRequest) async throws -> User {
        try await api.request(UserEndpoints.updateMe, body: body)
    }

    func uploadAvatar(imageData: Data) async throws -> User {
        try await api.uploadMultipart(
            UserEndpoints.uploadAvatar,
            fileData: imageData,
            fieldName: "avatar",
            fileName: "avatar.jpg",
            mimeType: "image/jpeg"
        )
    }

    func deactivate() async throws {
        _ = try await api.requestRaw(UserEndpoints.deactivate)
    }

    func follow(userId: String) async throws {
        _ = try await api.requestRaw(UserEndpoints.follow(userId: userId))
    }

    func unfollow(userId: String) async throws {
        _ = try await api.requestRaw(UserEndpoints.unfollow(userId: userId))
    }

    func fetchFollowers(userId: String, page: Int = 1) async throws -> [FollowUser] {
        let wrapper: FollowListResponse = try await api.request(UserEndpoints.followers(userId: userId, page: page))
        return wrapper.followers ?? wrapper.items ?? []
    }

    func fetchFollowing(userId: String, page: Int = 1) async throws -> [FollowUser] {
        let wrapper: FollowListResponse = try await api.request(UserEndpoints.following(userId: userId, page: page))
        return wrapper.following ?? wrapper.items ?? []
    }

    func fetchLikedContent(page: Int = 1) async throws -> [Content] {
        try await api.request(UserEndpoints.likedContent(page: page))
    }

    func fetchSavedContent(page: Int = 1) async throws -> [Content] {
        try await api.request(UserEndpoints.savedContent(page: page))
    }

    func fetchViewHistory(page: Int = 1) async throws -> [ContentProgress] {
        try await api.request(UserEndpoints.viewHistory(page: page))
    }
}

// MARK: - Request Bodies

struct UpdateProfileRequest: Encodable, Sendable {
    var firstName: String?
    var lastName: String?
    var username: String?
    var bio: String?
    var location: String?
    var skills: [String]?
    var education: [EducationInput]?
    var workExperience: [WorkExperienceInput]?
}

struct EducationInput: Encodable, Sendable {
    let degree: String
    let institution: String
    let yearOfCompletion: Int?
    let currentlyPursuing: Bool?
}

struct WorkExperienceInput: Encodable, Sendable {
    let role: String
    let company: String
    let years: Int?
    let currentlyWorking: Bool?
}

// MARK: - Response Types

private struct FollowListResponse: Codable, Sendable {
    let followers: [FollowUser]?
    let following: [FollowUser]?
    let items: [FollowUser]?
}

// MARK: - Endpoints

private enum UserEndpoints: Endpoint {
    case me
    case updateMe
    case uploadAvatar
    case deactivate
    case publicProfile(userId: String)
    case follow(userId: String)
    case unfollow(userId: String)
    case followers(userId: String, page: Int)
    case following(userId: String, page: Int)
    case likedContent(page: Int)
    case savedContent(page: Int)
    case viewHistory(page: Int)

    var path: String {
        switch self {
        case .me, .updateMe, .deactivate: return "/users/me"
        case .uploadAvatar: return "/users/me/avatar"
        case .publicProfile(let id): return "/users/\(id)"
        case .follow(let id), .unfollow(let id): return "/social/follow/\(id)"
        case .followers(let id, _): return "/social/followers/\(id)"
        case .following(let id, _): return "/social/following/\(id)"
        case .likedContent: return "/content/liked"
        case .savedContent: return "/content/saved"
        case .viewHistory: return "/progress/history"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .me, .publicProfile, .followers, .following, .likedContent, .savedContent, .viewHistory:
            return .get
        case .updateMe, .uploadAvatar:
            return .put
        case .follow:
            return .post
        case .unfollow, .deactivate:
            return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .followers(_, let page), .following(_, let page):
            return [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
        case .likedContent(let page), .savedContent(let page), .viewHistory(let page):
            return [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
        default:
            return nil
        }
    }
}
