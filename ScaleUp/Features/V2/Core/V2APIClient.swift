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

    // MARK: - Internals

    private enum APIVersion { case v1, v2 }
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
        }
    }

    /// v2 — decodes into V2APIResponse<T>
    private func request<T: Codable, B: Codable>(version: APIVersion, method: String, path: String, body: B?) async throws -> V2APIResponse<T> {
        let data = try await rawData(version: version, method: method, path: path, body: body)
        return try JSONDecoder().decode(V2APIResponse<T>.self, from: data)
    }

    /// v1 — decodes T directly (v1 endpoints don't use the envelope)
    private func rawRequest<T: Codable, B: Codable>(version: APIVersion, method: String, path: String, body: B?) async throws -> T {
        let data = try await rawData(version: version, method: method, path: path, body: body)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func rawData<B: Codable>(version: APIVersion, method: String, path: String, body: B?) async throws -> Data {
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
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw V2APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
}

enum V2APIError: Error {
    case invalidURL
    case serverError(Int)
    case decodingFailed
}
