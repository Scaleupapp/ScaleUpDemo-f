import Foundation

// MARK: - Dashboard Service

/// Service layer wrapping dashboard-related API calls.
final class DashboardService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Get Dashboard

    /// Fetches the user's personalized dashboard data.
    func getDashboard() async throws -> DashboardResponse {
        let response: DashboardResponse = try await apiClient.request(
            DashboardEndpoints.getDashboard()
        )
        return response
    }
}
