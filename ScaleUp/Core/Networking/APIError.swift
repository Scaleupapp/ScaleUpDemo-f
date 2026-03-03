import Foundation

enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case rateLimited
    case badRequest(String)
    case serverError
    case decodingError(String)
    case networkError(String)
    case unknown(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .unauthorized:
            return "Session expired. Please log in again."
        case .forbidden:
            return "You don't have access to this resource."
        case .notFound:
            return "The requested resource was not found."
        case .conflict(let msg):
            return msg
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .badRequest(let msg):
            return msg
        case .serverError:
            return "Something went wrong. Please try again."
        case .decodingError(let detail):
            return "Data error: \(detail)"
        case .networkError(let msg):
            return msg
        case .unknown(_, let msg):
            return msg
        }
    }
}
