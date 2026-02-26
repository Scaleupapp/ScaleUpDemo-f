import Foundation
import OSLog

// MARK: - API Client

/// The main HTTP client for communicating with the ScaleUp backend.
///
/// Features:
/// - async/await based on `URLSession`
/// - Automatic `Bearer` token injection via `TokenProviding`
/// - 401 interception with actor-based token refresh & request retry
/// - Typed error mapping to `APIError`
/// - Debug logging of requests and responses
final class APIClient: Sendable {

    // MARK: - Configuration

    static let baseURL = URL(string: "http://localhost:5001/api/v1")!

    // MARK: - Properties

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let tokenProvider: TokenProviding?
    private let tokenInterceptor: TokenInterceptor?
    private let logger = Logger(subsystem: "com.scaleup.app", category: "APIClient")

    // MARK: - Singleton

    /// Shared instance. Configure with `APIClient.configure(tokenProvider:)` at launch.
    static let shared = APIClient()

    /// Configurable token provider set once at app launch.
    nonisolated(unsafe) private static var _configuredTokenProvider: (any TokenProviding)?

    /// Call once during app startup to wire the token provider.
    static func configure(tokenProvider: TokenProviding) {
        _configuredTokenProvider = tokenProvider
    }

    // MARK: - Init

    init(tokenProvider: TokenProviding? = nil) {
        let resolvedProvider = tokenProvider ?? APIClient._configuredTokenProvider

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.urlCache = URLCache(
            memoryCapacity: 10_485_760,  // 10 MB
            diskCapacity: 52_428_800     // 50 MB
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy

        self.session = URLSession(configuration: configuration)

        let enc = JSONEncoder()
        // Backend uses camelCase — no key strategy conversion needed.
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        self.tokenProvider = resolvedProvider
        self.tokenInterceptor = resolvedProvider.map { TokenInterceptor(tokenProvider: $0) }
    }

    // MARK: - Public: Typed Response

    /// Performs the request and decodes `APIResponse<T>.data` into `T`.
    /// - Throws: `APIError` on failure.
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await performRequest(endpoint, allowRetry: true)

        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)

            guard apiResponse.success, let payload = apiResponse.data else {
                let detail = apiResponse.error
                throw APIError.badRequest(detail?.details ?? apiResponse.message)
            }

            return payload
        } catch let error as APIError {
            throw error
        } catch {
            let responseStr = String(data: data, encoding: .utf8) ?? "<binary>"
            print("‼️ DECODE ERROR for \(endpoint.path): \(error)")
            print("‼️ RAW RESPONSE: \(String(responseStr.prefix(3000)))")
            logger.error("Decoding error for \(endpoint.path): \(error) — Raw: \(responseStr.prefix(2000))")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Public: Optional Response

    /// Performs the request and decodes `APIResponse<T>.data` into `T?`.
    /// Returns `nil` when the backend sends `success: true` with `data: null`
    /// (e.g. GET /journey when no journey exists yet).
    func requestOptional<T: Decodable>(_ endpoint: Endpoint) async throws -> T? {
        let data = try await performRequest(endpoint, allowRetry: true)

        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)

            guard apiResponse.success else {
                let detail = apiResponse.error
                throw APIError.badRequest(detail?.details ?? apiResponse.message)
            }

            return apiResponse.data
        } catch let error as APIError {
            throw error
        } catch {
            let responseStr = String(data: data, encoding: .utf8) ?? "<binary>"
            print("‼️ DECODE ERROR for \(endpoint.path): \(error)")
            print("‼️ RAW RESPONSE: \(String(responseStr.prefix(3000)))")
            logger.error("Decoding error for \(endpoint.path): \(error) — Raw: \(responseStr.prefix(2000))")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Public: Flat Paginated Response

    /// Performs the request and decodes a flat paginated response where `data` is an array
    /// and `pagination` sits at the top level alongside `data`.
    /// Returns a `PaginatedData<T>` for uniform consumption.
    func requestFlatPaginated<T: Decodable>(_ endpoint: Endpoint) async throws -> PaginatedData<T> {
        let data = try await performRequest(endpoint, allowRetry: true)

        do {
            let apiResponse = try decoder.decode(APIFlatPaginatedResponse<T>.self, from: data)

            guard apiResponse.success else {
                let detail = apiResponse.error
                throw APIError.badRequest(detail?.details ?? apiResponse.message)
            }

            return PaginatedData(
                items: apiResponse.data ?? [],
                pagination: apiResponse.pagination
            )
        } catch let error as APIError {
            throw error
        } catch {
            let responseStr = String(data: data, encoding: .utf8) ?? "<binary>"
            print("‼️ FLAT PAGINATED DECODE ERROR for \(endpoint.path): \(error)")
            print("‼️ RAW RESPONSE: \(String(responseStr.prefix(3000)))")
            logger.error("Flat paginated decoding error for \(endpoint.path): \(error) — Raw: \(responseStr.prefix(2000))")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Public: Paginated Response

    /// Performs the request and decodes paginated `APIResponse<PaginatedData<T>>.data.items` into `[T]`.
    /// Use this when the backend wraps the array in `{ items: [...], pagination: {...} }`.
    func requestPaginated<T: Decodable>(_ endpoint: Endpoint) async throws -> [T] {
        let data = try await performRequest(endpoint, allowRetry: true)

        do {
            let apiResponse = try decoder.decode(APIResponse<PaginatedData<T>>.self, from: data)

            guard apiResponse.success, let payload = apiResponse.data else {
                let detail = apiResponse.error
                throw APIError.badRequest(detail?.details ?? apiResponse.message)
            }

            return payload.items
        } catch let error as APIError {
            throw error
        } catch {
            let responseStr = String(data: data, encoding: .utf8) ?? "<binary>"
            print("‼️ PAGINATED DECODE ERROR for \(endpoint.path): \(error)")
            print("‼️ RAW RESPONSE: \(String(responseStr.prefix(3000)))")
            logger.error("Paginated decoding error for \(endpoint.path): \(error) — Raw: \(responseStr.prefix(2000))")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Public: Void Response

    /// Performs the request expecting no data payload (only `success` / `message`).
    /// - Throws: `APIError` on failure.
    func requestVoid(_ endpoint: Endpoint) async throws {
        let data = try await performRequest(endpoint, allowRetry: true)

        do {
            let apiResponse = try decoder.decode(APIVoidResponse.self, from: data)

            guard apiResponse.success else {
                let detail = apiResponse.error
                throw APIError.badRequest(detail?.details ?? apiResponse.message)
            }
        } catch let error as APIError {
            throw error
        } catch {
            // If decoding the void wrapper itself fails, treat as decoding error.
            logger.error("Void response decoding error: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Internal: Perform Request

    /// Builds, executes, and validates the URL request. Handles 401 retry logic.
    private func performRequest(_ endpoint: Endpoint, allowRetry: Bool) async throws -> Data {
        var urlRequest = try buildURLRequest(for: endpoint)

        // Inject Bearer token if needed.
        if endpoint.requiresAuth, let token = await tokenProvider?.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        logRequest(urlRequest)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(0, "Invalid response type")
        }

        logResponse(httpResponse, data: data)

        // Happy path
        if (200...299).contains(httpResponse.statusCode) {
            return data
        }

        // 304 Not Modified — URLSession with URLCache should return cached data transparently,
        // but if the body is empty, return a minimal valid JSON object to avoid decode crashes.
        if httpResponse.statusCode == 304 {
            return data.isEmpty ? Data("{}".utf8) : data
        }

        // 401 — attempt token refresh and retry once.
        if httpResponse.statusCode == 401, allowRetry, let interceptor = tokenInterceptor {
            logger.info("Received 401 — attempting token refresh")
            do {
                _ = try await interceptor.validAccessToken()
                // Retry the original request with the new token.
                return try await performRequest(endpoint, allowRetry: false)
            } catch {
                logger.error("Token refresh failed: \(error.localizedDescription)")
                throw APIError.unauthorized
            }
        }

        // Map status code to typed error.
        let errorDetail = try? decoder.decode(APIResponse<EmptyBody>.self, from: data).error
        throw APIError.from(statusCode: httpResponse.statusCode, detail: errorDetail)
    }

    // MARK: - URL Request Builder

    private func buildURLRequest(for endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        components?.queryItems = endpoint.queryItems?.isEmpty == false ? endpoint.queryItems : nil

        guard let url = components?.url else {
            throw APIError.badRequest("Invalid URL for path: \(endpoint.path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

    // MARK: - Logging

    private func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        logger.debug("➡️ \(method) \(url)")
        if let body = request.httpBody, let json = String(data: body, encoding: .utf8) {
            logger.debug("   Body: \(json)")
        }
        #endif
    }

    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
        let status = response.statusCode
        let url = response.url?.absoluteString ?? "?"
        logger.debug("⬅️ \(status) \(url)")
        if let json = String(data: data, encoding: .utf8)?.prefix(1000) {
            logger.debug("   Response: \(json)")
        }
        #endif
    }
}

// MARK: - Helpers

/// Empty Decodable used when we only need to inspect `APIResponse.error`.
private struct EmptyBody: Decodable {}

/// Type-erased Encodable wrapper so `Endpoint.body` (any Encodable) can be encoded.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        self._encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
