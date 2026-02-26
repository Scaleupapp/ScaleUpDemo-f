import SwiftUI

// MARK: - Application Review View Model

@Observable
@MainActor
final class ApplicationReviewViewModel {

    // MARK: - Published State

    var applications: [CreatorApplication] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var error: APIError?
    var currentPage: Int = 1
    var hasMore: Bool = true

    /// Tracks the application ID currently being acted upon.
    var actionInProgressId: String?

    /// Alert state for reject confirmation.
    var showRejectAlert: Bool = false
    var applicationToReject: CreatorApplication?
    var rejectNote: String = ""

    // MARK: - Dependencies

    private let adminService: AdminService
    private let hapticManager: HapticManager

    // MARK: - Init

    init(adminService: AdminService, hapticManager: HapticManager) {
        self.adminService = adminService
        self.hapticManager = hapticManager
    }

    // MARK: - Load Applications

    /// Fetches the first page of creator applications.
    func loadApplications() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        currentPage = 1

        do {
            let response = try await adminService.applications(page: currentPage, limit: 20)
            self.applications = response.items
            self.hasMore = (response.pagination?.hasMore ?? false)
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Load More

    /// Fetches the next page of applications and appends to the existing list.
    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true

        let nextPage = currentPage + 1

        do {
            let response = try await adminService.applications(page: nextPage, limit: 20)
            self.applications.append(contentsOf: response.items)
            self.currentPage = nextPage
            self.hasMore = (response.pagination?.hasMore ?? false)
        } catch {
            // Silently fail on pagination
        }

        isLoadingMore = false
    }

    // MARK: - Reject Application

    /// Rejects a creator application with an optional review note.
    func rejectApplication(id: String, note: String?) async {
        actionInProgressId = id

        do {
            try await adminService.rejectApplication(id: id, reviewNote: note)
            // Remove from the local list or update status
            if let index = applications.firstIndex(where: { $0.id == id }) {
                applications.remove(at: index)
            }
            hapticManager.success()
        } catch {
            hapticManager.error()
        }

        actionInProgressId = nil
        rejectNote = ""
    }

    // MARK: - Computed Properties

    var pendingApplications: [CreatorApplication] {
        applications.filter { $0.status == .pending }
    }

    var pendingCount: Int {
        pendingApplications.count
    }
}
