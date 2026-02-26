import SwiftUI

// MARK: - Follow List View Model

@Observable
@MainActor
final class FollowListViewModel {

    // MARK: - Mode

    enum Mode: String, CaseIterable {
        case followers = "Followers"
        case following = "Following"
    }

    // MARK: - State

    var users: [PublicUser] = []
    var isLoading = false
    var isLoadingMore = false
    var error: APIError?
    var hasMore = true
    var currentPage = 1

    // MARK: - Follow/Unfollow State

    /// Tracks user IDs that are currently being toggled (follow/unfollow in progress).
    var togglingUserIds: Set<String> = []

    /// Tracks user IDs that the current user is following (for optimistic UI).
    var followingUserIds: Set<String> = []

    // MARK: - Dependencies

    private let socialService: SocialService
    private let hapticManager: HapticManager

    private let pageLimit = 20

    // MARK: - Init

    init(socialService: SocialService, hapticManager: HapticManager) {
        self.socialService = socialService
        self.hapticManager = hapticManager
    }

    // MARK: - Load Users

    /// Loads the first page of followers or following.
    func loadUsers(userId: String, mode: Mode) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        currentPage = 1
        users = []
        hasMore = true

        do {
            let paginated = try await fetchPage(userId: userId, mode: mode, page: 1)
            self.users = paginated.items
            self.hasMore = (paginated.pagination?.hasMore ?? false)
            self.currentPage = 1
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Load More (Pagination)

    /// Loads the next page and appends results.
    func loadMore(userId: String, mode: Mode) async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true

        let nextPage = currentPage + 1

        do {
            let paginated = try await fetchPage(userId: userId, mode: mode, page: nextPage)
            self.users.append(contentsOf: paginated.items)
            self.hasMore = (paginated.pagination?.hasMore ?? false)
            self.currentPage = nextPage
        } catch {
            // Silently fail on pagination — user can scroll to retry
        }

        isLoadingMore = false
    }

    // MARK: - Toggle Follow

    /// Follows or unfollows a user with optimistic UI.
    func toggleFollow(userId: String) async {
        guard !togglingUserIds.contains(userId) else { return }
        togglingUserIds.insert(userId)

        let isCurrentlyFollowing = followingUserIds.contains(userId)

        // Optimistic update
        if isCurrentlyFollowing {
            followingUserIds.remove(userId)
        } else {
            followingUserIds.insert(userId)
        }
        hapticManager.selection()

        do {
            if isCurrentlyFollowing {
                try await socialService.unfollow(userId: userId)
            } else {
                try await socialService.follow(userId: userId)
            }
        } catch {
            // Revert on failure
            if isCurrentlyFollowing {
                followingUserIds.insert(userId)
            } else {
                followingUserIds.remove(userId)
            }
            hapticManager.error()
        }

        togglingUserIds.remove(userId)
    }

    // MARK: - Private Helpers

    private func fetchPage(userId: String, mode: Mode, page: Int) async throws -> PaginatedData<PublicUser> {
        switch mode {
        case .followers:
            return try await socialService.followers(userId: userId, page: page, limit: pageLimit)
        case .following:
            return try await socialService.following(userId: userId, page: page, limit: pageLimit)
        }
    }
}
