import Foundation

// MARK: - API Response Wrapper

struct APIResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let success: Bool
    let message: String?
    let data: T?
    let pagination: Pagination?
}

struct Pagination: Decodable, Sendable {
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
    let hasNextPage: Bool
    let hasPrevPage: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try Self.decodeFlexibleInt(container, key: .total)
        page = try Self.decodeFlexibleInt(container, key: .page)
        limit = try Self.decodeFlexibleInt(container, key: .limit)
        totalPages = try Self.decodeFlexibleInt(container, key: .totalPages)
        hasNextPage = try container.decode(Bool.self, forKey: .hasNextPage)
        hasPrevPage = try container.decode(Bool.self, forKey: .hasPrevPage)
    }

    private enum CodingKeys: String, CodingKey {
        case total, page, limit, totalPages, hasNextPage, hasPrevPage
    }

    private static func decodeFlexibleInt(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Int {
        if let intVal = try? container.decode(Int.self, forKey: key) {
            return intVal
        }
        let stringVal = try container.decode(String.self, forKey: key)
        guard let parsed = Int(stringVal) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Cannot parse '\(stringVal)' as Int")
        }
        return parsed
    }
}

// MARK: - API Client

actor APIClient {
    static let shared = APIClient()

    private let baseURL = "http://15.207.72.150:5000/api/v1"
    private let session: URLSession
    private let decoder: JSONDecoder

    private var isRefreshing = false
    private var pendingRequests: [CheckedContinuation<Data, Error>] = []

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: dateString) { return date }

            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: dateString) { return date }

            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Cannot decode date: \(dateString)"
            )
        }
    }

    // MARK: - Public API

    func request<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        body: (any Encodable & Sendable)? = nil
    ) async throws -> T {
        let data = try await performRequest(endpoint, body: body)
        let response = try decoder.decode(APIResponse<T>.self, from: data)

        guard response.success, let result = response.data else {
            throw APIError.badRequest(response.message ?? "Request failed")
        }
        return result
    }

    func requestRaw(_ endpoint: Endpoint, body: (any Encodable & Sendable)? = nil) async throws -> APIResponse<EmptyData> {
        let data = try await performRequest(endpoint, body: body)
        return try decoder.decode(APIResponse<EmptyData>.self, from: data)
    }

    func requestRawData(_ endpoint: Endpoint, body: (any Encodable & Sendable)? = nil) async throws -> Data {
        try await performRequest(endpoint, body: body)
    }

    func uploadMultipart<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        fileData: Data,
        fieldName: String,
        fileName: String,
        mimeType: String
    ) async throws -> T {
        let data = try await performMultipartRequest(
            endpoint, fileData: fileData, fieldName: fieldName,
            fileName: fileName, mimeType: mimeType
        )
        let response = try decoder.decode(APIResponse<T>.self, from: data)
        guard response.success, let result = response.data else {
            throw APIError.badRequest(response.message ?? "Upload failed")
        }
        return result
    }

    // MARK: - Request Execution

    private func performRequest(
        _ endpoint: Endpoint,
        body: (any Encodable & Sendable)?
    ) async throws -> Data {
        var urlString = "\(baseURL)\(endpoint.path)"

        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            urlString = components?.url?.absoluteString ?? urlString
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth {
            if let token = await KeychainManager.shared.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...201:
            return data
        case 401:
            if endpoint.requiresAuth {
                return try await handleUnauthorized(endpoint: endpoint, body: body)
            }
            let msg = parseMessage(from: data)
            throw APIError.badRequest(msg)
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 409:
            let msg = parseMessage(from: data)
            throw APIError.conflict(msg)
        case 429:
            throw APIError.rateLimited
        case 400:
            let msg = parseMessage(from: data)
            throw APIError.badRequest(msg)
        case 500...599:
            throw APIError.serverError
        default:
            let msg = parseMessage(from: data)
            throw APIError.unknown(httpResponse.statusCode, msg)
        }
    }

    // MARK: - Multipart Upload

    private func performMultipartRequest(
        _ endpoint: Endpoint,
        fileData: Data,
        fieldName: String,
        fileName: String,
        mimeType: String
    ) async throws -> Data {
        let urlString = "\(baseURL)\(endpoint.path)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth {
            if let token = await KeychainManager.shared.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...201:
            return data
        case 401:
            throw APIError.unauthorized
        default:
            let msg = parseMessage(from: data)
            throw APIError.badRequest(msg)
        }
    }

    // MARK: - Token Refresh

    private func handleUnauthorized(
        endpoint: Endpoint,
        body: (any Encodable & Sendable)?
    ) async throws -> Data {
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                pendingRequests.append(continuation)
            }
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await refreshToken()
            let data = try await performRequest(endpoint, body: body)

            for continuation in pendingRequests {
                continuation.resume(returning: data)
            }
            pendingRequests.removeAll()

            return data
        } catch {
            for continuation in pendingRequests {
                continuation.resume(throwing: APIError.unauthorized)
            }
            pendingRequests.removeAll()
            throw APIError.unauthorized
        }
    }

    private func refreshToken() async throws {
        guard let refreshToken = await KeychainManager.shared.refreshToken else {
            throw APIError.unauthorized
        }

        let body = RefreshTokenRequest(refreshToken: refreshToken)
        let urlString = "\(baseURL)/auth/refresh-token"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            await KeychainManager.shared.clearTokens()
            throw APIError.unauthorized
        }

        let tokenResponse = try decoder.decode(APIResponse<TokenData>.self, from: data)
        guard let tokens = tokenResponse.data else { throw APIError.unauthorized }

        await KeychainManager.shared.saveTokens(
            access: tokens.accessToken,
            refresh: tokens.refreshToken
        )
    }

    // MARK: - Helpers

    private func parseMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return "Something went wrong"
    }
}

// MARK: - Internal Models

struct EmptyData: Decodable, Sendable {}

private struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String
}

private struct TokenData: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
