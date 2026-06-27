import Foundation

/// Generic v2 API response envelope: { success: Bool, data: T, message: String? }
struct V2APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?
}

/// API client for the v2 onboarding flow.
///
/// Handles BOTH:
///   - `/api/v2/*` endpoints (wrapped in V2APIResponse) via get()/post()
///   - `/api/v1/*` endpoints (raw, unwrapped) via getV1()/postV1()
/// because the v2 onboarding still reuses proven v1 endpoints
/// (/onboarding/topics/suggest, /onboarding/complete).
@MainActor
final class V2APIClient {
    static let shared = V2APIClient()
    private init() {}

    // MARK: - v2 (wrapped envelope)

    func get<T: Codable>(_ path: String) async throws -> V2APIResponse<T> {
        try await request(version: .v2, method: "GET", path: path, body: Optional<EmptyBody>.none)
    }

    func post<T: Codable, B: Codable>(_ path: String, body: B) async throws -> V2APIResponse<T> {
        try await request(version: .v2, method: "POST", path: path, body: body)
    }

    func delete<T: Codable>(_ path: String) async throws -> V2APIResponse<T> {
        try await request(version: .v2, method: "DELETE", path: path, body: Optional<EmptyBody>.none)
    }

    // MARK: - v1 (raw, unwrapped response)

    func getV1<T: Codable>(_ path: String) async throws -> T {
        try await rawRequest(version: .v1, method: "GET", path: path, body: Optional<EmptyBody>.none)
    }

    func postV1<T: Codable, B: Codable>(_ path: String, body: B) async throws -> T {
        try await rawRequest(version: .v1, method: "POST", path: path, body: body)
    }

    func putV1<T: Codable, B: Codable>(_ path: String, body: B) async throws -> T {
        try await rawRequest(version: .v1, method: "PUT", path: path, body: body)
    }

    // MARK: - Coding (raw, no envelope — /api/coding/* endpoints)

    func getCoding<T: Codable>(_ path: String) async throws -> T {
        try await rawRequest(version: .coding, method: "GET", path: path, body: Optional<EmptyBody>.none)
    }

    func postCoding<T: Codable, B: Codable>(_ path: String, body: B) async throws -> T {
        try await rawRequest(version: .coding, method: "POST", path: path, body: body)
    }

    /// Returns both decoded value and HTTP status code.
    /// Used for 202-returning endpoints (drill submit, calibration submit,
    /// polling result while not graded) where the caller branches on status.
    func getCodingWithStatus<T: Codable>(_ path: String) async throws -> (T, Int) {
        try await rawRequestWithStatus(version: .coding, method: "GET", path: path, body: Optional<EmptyBody>.none)
    }

    func postCodingWithStatus<T: Codable, B: Codable>(_ path: String, body: B) async throws -> (T, Int) {
        try await rawRequestWithStatus(version: .coding, method: "POST", path: path, body: body)
    }

    /// Returns raw Data + HTTP status without decoding. Used by DrillService.pollResult
    /// to branch on 200 (graded) vs 202 (pending) and decode into different types.
    func rawCodingData(method: String, path: String) async throws -> (Data, Int) {
        try await rawDataWithStatus(version: .coding, method: method, path: path, body: Optional<EmptyBody>.none)
    }

    /// Same as `rawCodingData(method:path:)` but accepts a body for POSTs that
    /// need a body but want to decode with a custom JSONDecoder (e.g.
    /// JSONDecoder.capstoneDecoder which understands ISO8601 strings).
    func rawCodingData<B: Codable>(method: String, path: String, body: B) async throws -> (Data, Int) {
        try await rawDataWithStatus(version: .coding, method: method, path: path, body: body)
    }

    // MARK: - Internals

    private enum APIVersion { case v1, v2, coding }
    private struct EmptyBody: Codable {}

    private func baseURL(for version: APIVersion) -> String {
        // Production backend — must match the v1 APIClient. An optional
        // API_BASE_URL Info.plist key can override it for local dev, but the
        // default is production so device / TestFlight builds work without
        // any extra config. (Previously defaulted to localhost, which made
        // every /api/v2 call fail silently on real devices.)
        let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let v1Base = (configured?.isEmpty == false ? configured! : "https://api.scaleupapp.club/api/v1")
        switch version {
        case .v1: return v1Base
        case .v2: return v1Base.replacingOccurrences(of: "/api/v1", with: "/api/v2")
        case .coding: return v1Base.replacingOccurrences(of: "/api/v1", with: "/api/coding")
        }
    }

    /// v2 — decodes into V2APIResponse<T>
    private func request<T: Codable, B: Codable>(version: APIVersion, method: String, path: String, body: B?) async throws -> V2APIResponse<T> {
        let data = try await rawData(version: version, method: method, path: path, body: body)
        return try JSONDecoder().decode(V2APIResponse<T>.self, from: data)
    }

    /// v1/coding — decodes T directly (no envelope)
    private func rawRequest<T: Codable, B: Codable>(version: APIVersion, method: String, path: String, body: B?) async throws -> T {
        let data = try await rawData(version: version, method: method, path: path, body: body)
        return try decoder(for: version).decode(T.self, from: data)
    }

    /// v1/coding — decodes T and surfaces HTTP status code
    private func rawRequestWithStatus<T: Codable, B: Codable>(version: APIVersion, method: String, path: String, body: B?) async throws -> (T, Int) {
        let (data, status) = try await rawDataWithStatus(version: version, method: method, path: path, body: body)
        let decoded = try decoder(for: version).decode(T.self, from: data)
        return (decoded, status)
    }

    /// Returns a JSONDecoder configured for the given API namespace. The
    /// `.coding` namespace returns ISO8601 strings for every Date field, so
    /// we install a custom strategy that handles `2026-05-28T12:48:56.123Z`
    /// with and without fractional seconds. Other namespaces keep Apple's
    /// default (Date = TimeInterval since 2001), which is what their
    /// hand-rolled controllers expect.
    private func decoder(for version: APIVersion) -> JSONDecoder {
        let d = JSONDecoder()
        if version == .coding {
            let withFrac = ISO8601DateFormatter()
            withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            d.dateDecodingStrategy = .custom { decoder in
                let c = try decoder.singleValueContainer()
                let s = try c.decode(String.self)
                if let dt = withFrac.date(from: s) { return dt }
                if let dt = plain.date(from: s) { return dt }
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid ISO8601 date: \(s)")
            }
        }
        return d
    }

    private func rawData<B: Codable>(version: APIVersion, method: String, path: String, body: B?) async throws -> Data {
        let (data, _) = try await rawDataWithStatus(version: version, method: method, path: path, body: body)
        return data
    }

    private func rawDataWithStatus<B: Codable>(version: APIVersion, method: String, path: String, body: B?, allowRefresh: Bool = true) async throws -> (Data, Int) {
        guard let url = URL(string: "\(baseURL(for: version))\(path)") else { throw V2APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await KeychainManager.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw V2APIError.serverError(0)
        }
        let status = http.statusCode
        // Expired access token → refresh once and retry, mirroring the v1 APIClient.
        // Without this, EVERY v2 call (including /me/context) silently 401s after the
        // 15-minute access-token expiry — which dropped a placement student to the
        // generic D2C experience even though the v1 home (which DOES refresh) loaded.
        if status == 401, allowRefresh, await refreshAccessToken() {
            return try await rawDataWithStatus(version: version, method: method, path: path, body: body, allowRefresh: false)
        }
        // Don't throw on 202 (accepted / still processing) — let caller decide.
        // Throw on 4xx/5xx.
        if status >= 400 {
            throw V2APIError.httpError(status, data)
        }
        return (data, status)
    }

    /// Refreshes the access token using the stored refresh token. Returns true on
    /// success (new tokens saved to the Keychain). Mirrors APIClient.refreshToken.
    private func refreshAccessToken() async -> Bool {
        guard let refresh = await KeychainManager.shared.refreshToken else { return false }
        guard let url = URL(string: "\(baseURL(for: .v1))/auth/refresh-token") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct RefreshBody: Codable { let refreshToken: String }
        struct TokenData: Codable { let accessToken: String; let refreshToken: String }
        struct Wrap: Codable { let data: TokenData? }
        do {
            request.httpBody = try JSONEncoder().encode(RefreshBody(refreshToken: refresh))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            guard let tokens = try JSONDecoder().decode(Wrap.self, from: data).data else { return false }
            await KeychainManager.shared.saveTokens(access: tokens.accessToken, refresh: tokens.refreshToken)
            return true
        } catch {
            return false
        }
    }
}

enum V2APIError: Error {
    case invalidURL
    case serverError(Int)
    case decodingFailed
    /// HTTP 4xx/5xx with the raw response body for error detail extraction.
    case httpError(Int, Data)
}
