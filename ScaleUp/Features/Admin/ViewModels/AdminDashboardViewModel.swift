import SwiftUI

// MARK: - Admin Dashboard View Model

@Observable
@MainActor
final class AdminDashboardViewModel {

    // MARK: - Published State

    var stats: AdminStatsResponse?
    var isLoading: Bool = false
    var error: APIError?

    // MARK: - Dependencies

    private let adminService: AdminService
    private let hapticManager: HapticManager

    // MARK: - Init

    init(adminService: AdminService, hapticManager: HapticManager) {
        self.adminService = adminService
        self.hapticManager = hapticManager
    }

    // MARK: - Load Stats

    /// Fetches admin dashboard statistics from the API.
    func loadStats() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let response = try await adminService.stats()
            self.stats = response
            hapticManager.success()
        } catch let apiError as APIError {
            self.error = apiError
            hapticManager.error()
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            hapticManager.error()
        }

        isLoading = false
    }

    // MARK: - Refresh

    /// Refreshes dashboard statistics without showing the loading indicator.
    func refresh() async {
        error = nil

        do {
            let response = try await adminService.stats()
            self.stats = response
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    var totalUsers: Int {
        stats?.totalUsers ?? 0
    }

    var totalContent: Int {
        stats?.totalContent ?? 0
    }

    var totalCreators: Int {
        stats?.totalCreators ?? 0
    }

    var activeJourneys: Int {
        stats?.activeJourneys ?? 0
    }
}
