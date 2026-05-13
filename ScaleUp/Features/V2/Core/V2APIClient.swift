import Foundation

/// Generic v2 API response envelope: { success: Bool, data: T, message: String? }
struct V2APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?
}

/// Thin wrapper around the existing v1 APIClient — just changes the base path to `/api/v2`
/// and provides simple convenience methods. Reuses v1's auth-token injection.
@MainActor
final class V2APIClient {
    static let shared = V2APIClient()
    private init() {}

    func get<T: Codable>(_ path: String) async throws -> V2APIResponse<T> {
        try await request(method: "GET", path: path, body: Optional<EmptyBody>.none)
    }

    func post<T: Codable, B: Codable>(_ path: String, body: B) async throws -> V2APIResponse<T> {
        try await request(method: "POST", path: path, body: body)
    }

    private struct EmptyBody: Codable {}

    private func request<T: Codable, B: Codable>(method: String, path: String, body: B?) async throws -> V2APIResponse<T> {
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              !baseURLString.isEmpty else {
            // Fallback to dev endpoint
            return try await makeRequest(urlString: "http://localhost:3000/api/v2\(path)", method: method, body: body)
        }
        // v1 base URL ends with /api/v1 — rewrite to /api/v2
        let v2Base = baseURLString.replacingOccurrences(of: "/api/v1", with: "/api/v2")
        return try await makeRequest(urlString: "\(v2Base)\(path)", method: method, body: body)
    }

    private func makeRequest<T: Codable, B: Codable>(urlString: String, method: String, body: B?) async throws -> V2APIResponse<T> {
        guard let url = URL(string: urlString) else { throw V2APIError.invalidURL }

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
        return try JSONDecoder().decode(V2APIResponse<T>.self, from: data)
    }
}

enum V2APIError: Error {
    case invalidURL
    case serverError(Int)
    case decodingFailed
}
