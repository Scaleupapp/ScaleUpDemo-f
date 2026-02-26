import SwiftUI

// MARK: - User Management View Model

@Observable
@MainActor
final class UserManagementViewModel {

    // MARK: - Published State

    var users: [User] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var error: APIError?
    var searchText: String = ""
    var selectedRoleFilter: UserRole? = nil
    var currentPage: Int = 1
    var hasMore: Bool = true

    /// Tracks the user ID currently being acted upon (ban/unban).
    var actionInProgressUserId: String?

    /// Alert state for ban/unban confirmation.
    var showBanConfirmation: Bool = false
    var userToBan: User?

    var showUnbanConfirmation: Bool = false
    var userToUnban: User?

    // MARK: - Dependencies

    private let adminService: AdminService
    private let hapticManager: HapticManager

    // MARK: - Search Debounce

    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(adminService: AdminService, hapticManager: HapticManager) {
        self.adminService = adminService
        self.hapticManager = hapticManager
    }

    // MARK: - Load Users

    /// Fetches the first page of users with current filters applied.
    func loadUsers() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        currentPage = 1

        do {
            let response = try await adminService.users(
                page: currentPage,
                limit: 20,
                role: selectedRoleFilter?.rawValue,
                search: searchText.isEmpty ? nil : searchText
            )
            self.users = response.items
            self.hasMore = (response.pagination?.hasMore ?? false)
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Load More

    /// Fetches the next page of users and appends to the existing list.
    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true

        let nextPage = currentPage + 1

        do {
            let response = try await adminService.users(
                page: nextPage,
                limit: 20,
                role: selectedRoleFilter?.rawValue,
                search: searchText.isEmpty ? nil : searchText
            )
            self.users.append(contentsOf: response.items)
            self.currentPage = nextPage
            self.hasMore = (response.pagination?.hasMore ?? false)
        } catch {
            // Silently fail on pagination — existing data remains visible
        }

        isLoadingMore = false
    }

    // MARK: - Search Users (Debounced)

    /// Triggers a debounced search. Cancels any pending search task.
    func searchUsers() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await loadUsers()
        }
    }

    // MARK: - Filter by Role

    /// Applies a role filter and reloads users.
    func filterByRole(_ role: UserRole?) async {
        selectedRoleFilter = role
        await loadUsers()
    }

    // MARK: - Ban User

    /// Bans a user by ID and updates the local list.
    func banUser(id: String) async {
        actionInProgressUserId = id

        do {
            try await adminService.ban(userId: id)
            if let index = users.firstIndex(where: { $0.id == id }) {
                // Reload the user list to get fresh data
                await loadUsers()
            }
            hapticManager.success()
        } catch {
            hapticManager.error()
        }

        actionInProgressUserId = nil
    }

    // MARK: - Unban User

    /// Unbans a user by ID and updates the local list.
    func unbanUser(id: String) async {
        actionInProgressUserId = id

        do {
            try await adminService.unban(userId: id)
            if let index = users.firstIndex(where: { $0.id == id }) {
                await loadUsers()
            }
            hapticManager.success()
        } catch {
            hapticManager.error()
        }

        actionInProgressUserId = nil
    }
}
