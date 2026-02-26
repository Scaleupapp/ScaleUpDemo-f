import Foundation

@Observable
@MainActor
final class AuthManager {
    private let apiClient: APIClient
    private let tokenManager: TokenManager

    private(set) var currentUser: User?
    private(set) var isLoading = false

    init(apiClient: APIClient, tokenManager: TokenManager) {
        self.apiClient = apiClient
        self.tokenManager = tokenManager
    }

    // MARK: - Auth Check on Launch

    func checkAuthOnLaunch() async {
        guard tokenManager.hasTokens else { return }

        do {
            let user: User = try await apiClient.request(
                UserEndpoints.me()
            )
            currentUser = user
        } catch {
            // Token invalid — clear and go to login
            tokenManager.clearTokens()
            currentUser = nil
        }
    }

    // MARK: - Login

    func handleAuthSuccess(accessToken: String, refreshToken: String, user: User) {
        tokenManager.storeTokens(access: accessToken, refresh: refreshToken)
        currentUser = user
    }

    // MARK: - Logout

    func logout() async {
        try? await apiClient.requestVoid(AuthEndpoints.logout())
        tokenManager.clearTokens()
        currentUser = nil
    }

    // MARK: - Handle Unauthorized

    func handleUnauthorized() {
        tokenManager.clearTokens()
        currentUser = nil
    }

    // MARK: - Update User

    func updateCurrentUser(_ user: User) {
        currentUser = user
    }
}
