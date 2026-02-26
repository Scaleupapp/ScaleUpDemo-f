import Foundation

protocol TokenProviding: Sendable {
    var accessToken: String? { get }
    func refreshAccessToken() async throws -> String
}

@Observable
final class TokenManager: @unchecked Sendable, TokenProviding {
    private let keychainManager: KeychainManager
    private weak var apiClientRef: APIClient?

    private(set) var accessToken: String?
    private var refreshToken: String?

    private let refreshLock = TokenRefreshLock()

    init(keychainManager: KeychainManager) {
        self.keychainManager = keychainManager
        loadTokens()
    }

    func setAPIClient(_ client: APIClient) {
        self.apiClientRef = client
    }

    // MARK: - Token Storage

    func storeTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
        try? keychainManager.save(access, for: .accessToken)
        try? keychainManager.save(refresh, for: .refreshToken)
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        keychainManager.deleteAll()
    }

    private func loadTokens() {
        accessToken = keychainManager.loadString(for: .accessToken)
        refreshToken = keychainManager.loadString(for: .refreshToken)
    }

    var hasTokens: Bool {
        accessToken != nil && refreshToken != nil
    }

    // MARK: - Token Refresh

    func refreshAccessToken() async throws -> String {
        try await refreshLock.refresh { [weak self] in
            guard let self, let refreshToken = self.refreshToken else {
                throw APIError.unauthorized
            }

            // Make direct URLSession call to avoid circular dependency
            let url = URL(string: "http://localhost:5001/api/v1/auth/refresh-token")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["refreshToken": refreshToken]
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown(0, "Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                self.clearTokens()
                throw APIError.unauthorized
            }

            struct RefreshResponse: Decodable {
                let success: Bool
                let data: TokenData

                struct TokenData: Decodable {
                    let accessToken: String
                    let refreshToken: String
                }
            }

            let decoded = try JSONDecoder().decode(RefreshResponse.self, from: data)
            self.storeTokens(access: decoded.data.accessToken, refresh: decoded.data.refreshToken)
            return decoded.data.accessToken
        }
    }
}

// MARK: - Token Refresh Lock (Actor)

private actor TokenRefreshLock {
    private var isRefreshing = false
    private var waitingContinuations: [CheckedContinuation<String, Error>] = []

    func refresh(using refreshBlock: @Sendable () async throws -> String) async throws -> String {
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                waitingContinuations.append(continuation)
            }
        }

        isRefreshing = true

        do {
            let newToken = try await refreshBlock()
            let waiting = waitingContinuations
            waitingContinuations = []
            isRefreshing = false

            for continuation in waiting {
                continuation.resume(returning: newToken)
            }

            return newToken
        } catch {
            let waiting = waitingContinuations
            waitingContinuations = []
            isRefreshing = false

            for continuation in waiting {
                continuation.resume(throwing: error)
            }

            throw error
        }
    }
}
