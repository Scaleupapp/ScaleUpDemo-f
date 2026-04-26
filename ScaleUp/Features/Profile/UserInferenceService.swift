import Foundation

actor UserInferenceService {
    private let api = APIClient.shared

    func list(includeResolved: Bool = false) async throws -> [UserInference] {
        try await api.request(UserInferenceEndpoints.list(includeResolved: includeResolved))
    }

    func resolve(key: String, status: UserInference.InferenceStatus) async throws -> UserInference {
        struct Body: Encodable, Sendable { let status: String }
        return try await api.request(
            UserInferenceEndpoints.resolve(key: key),
            body: Body(status: status.rawValue)
        )
    }
}

private enum UserInferenceEndpoints: Endpoint {
    case list(includeResolved: Bool)
    case resolve(key: String)

    var path: String {
        switch self {
        case .list:                  return "/user-inferences"
        case .resolve(let key):      return "/user-inferences/\(key)/resolve"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list:    return .get
        case .resolve: return .put
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let includeResolved):
            return includeResolved ? [URLQueryItem(name: "includeResolved", value: "true")] : nil
        case .resolve:
            return nil
        }
    }
}
