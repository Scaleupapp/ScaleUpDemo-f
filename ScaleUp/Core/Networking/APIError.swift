import Foundation

// MARK: - API Error

/// Typed error enum covering all expected HTTP and client-side failure modes.
enum APIError: Error, LocalizedError {
    /// 401 - Authentication required or token expired.
    case unauthorized

    /// 400 - Bad request with an optional server message.
    case badRequest(String?)

    /// 403 - Access denied.
    case forbidden

    /// 404 - Resource not found.
    case notFound

    /// 409 - Conflict (e.g. duplicate resource) with an optional server message.
    case conflict(String?)

    /// 429 - Too many requests.
    case rateLimited

    /// 500+ - Internal server error.
    case serverError

    /// Network-level failure (no connectivity, timeout, DNS, etc.).
    case networkError(Error)

    /// JSON decoding failed.
    case decodingError(Error)

    /// Any other HTTP status code with an optional message.
    case unknown(Int, String?)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .badRequest(let message):
            return message ?? "The request was invalid. Please try again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested resource was not found."
        case .conflict(let message):
            return message ?? "A conflict occurred. The resource may already exist."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError:
            return "An internal server error occurred. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            if let decodingError = error as? DecodingError {
                return "Decoding failed: \(decodingError.detailedDescription)"
            }
            return "Failed to process the server response: \(error.localizedDescription)"
        case .unknown(let code, let message):
            return message ?? "An unexpected error occurred (HTTP \(code))."
        }
    }

    // MARK: - Factory

    /// Maps an HTTP status code and optional error detail into a typed `APIError`.
    static func from(statusCode: Int, detail: APIErrorDetail?) -> APIError {
        let message = detail?.details ?? detail?.code
        switch statusCode {
        case 400:
            return .badRequest(message)
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 409:
            return .conflict(message)
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError
        default:
            return .unknown(statusCode, message)
        }
    }
}

// MARK: - DecodingError Helpers

extension DecodingError {
    var detailedDescription: String {
        switch self {
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Missing key '\(key.stringValue)' at path: \(path.isEmpty ? "root" : path)"
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch for \(type) at path: \(path.isEmpty ? "root" : path) — \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Null value for \(type) at path: \(path.isEmpty ? "root" : path)"
        case .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Corrupted data at path: \(path.isEmpty ? "root" : path) — \(context.debugDescription)"
        @unknown default:
            return localizedDescription
        }
    }
}
