import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - Endpoint Protocol

protocol Endpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var requiresAuth: Bool { get }
    var queryItems: [URLQueryItem]? { get }
}

extension Endpoint {
    var requiresAuth: Bool { true }
    var queryItems: [URLQueryItem]? { nil }
}
