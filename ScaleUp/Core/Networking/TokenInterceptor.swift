import Foundation

// MARK: - Token Refresh Coordinator

/// Actor-based coordinator that serializes token refresh attempts.
///
/// When multiple concurrent requests receive a 401, only **one** refresh call
/// is made. All other callers are suspended via continuations and resumed once
/// the refresh completes (or fails).
actor TokenInterceptor {

    // MARK: - Properties

    private let tokenProvider: TokenProviding

    /// Whether a refresh is currently in flight.
    private var isRefreshing = false

    /// Continuations of callers waiting for the in-flight refresh to finish.
    private var pendingContinuations: [CheckedContinuation<String, Error>] = []

    // MARK: - Init

    init(tokenProvider: TokenProviding) {
        self.tokenProvider = tokenProvider
    }

    // MARK: - Public API

    /// Returns a valid access token, refreshing if necessary.
    ///
    /// - If no refresh is in progress, initiates one and suspends the caller
    ///   until it completes.
    /// - If a refresh is already in progress, the caller is queued and will be
    ///   resumed with the new token (or error) once the refresh finishes.
    func validAccessToken() async throws -> String {
        if isRefreshing {
            // A refresh is already in-flight; park this caller.
            return try await withCheckedThrowingContinuation { continuation in
                pendingContinuations.append(continuation)
            }
        }

        // First caller triggers the refresh.
        isRefreshing = true

        do {
            let newToken = try await tokenProvider.refreshAccessToken()
            resumePending(with: .success(newToken))
            isRefreshing = false
            return newToken
        } catch {
            resumePending(with: .failure(error))
            isRefreshing = false
            throw error
        }
    }

    // MARK: - Helpers

    /// Resumes all queued continuations with the given result and clears the queue.
    private func resumePending(with result: Result<String, Error>) {
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(with: result)
        }
    }
}
