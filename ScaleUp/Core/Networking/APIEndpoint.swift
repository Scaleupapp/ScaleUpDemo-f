import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - Endpoint

struct Endpoint {
    let path: String
    let method: HTTPMethod
    var body: (any Encodable)?
    var queryItems: [URLQueryItem]?
    var requiresAuth: Bool = true

    // MARK: - Convenience Initializers

    static func get(_ path: String, queryItems: [URLQueryItem]? = nil, requiresAuth: Bool = true) -> Endpoint {
        Endpoint(path: path, method: .get, queryItems: queryItems, requiresAuth: requiresAuth)
    }

    static func post(_ path: String, body: (any Encodable)? = nil, requiresAuth: Bool = true) -> Endpoint {
        Endpoint(path: path, method: .post, body: body, requiresAuth: requiresAuth)
    }

    static func put(_ path: String, body: (any Encodable)? = nil, requiresAuth: Bool = true) -> Endpoint {
        Endpoint(path: path, method: .put, body: body, requiresAuth: requiresAuth)
    }

    static func delete(_ path: String, body: (any Encodable)? = nil, requiresAuth: Bool = true) -> Endpoint {
        Endpoint(path: path, method: .delete, body: body, requiresAuth: requiresAuth)
    }
}
