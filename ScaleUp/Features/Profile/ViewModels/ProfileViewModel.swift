import SwiftUI

// MARK: - Profile View Model

@Observable
@MainActor
final class ProfileViewModel {

    // MARK: - State

    var user: User?
    var isLoading = false
    var error: APIError?
    var showEditSheet = false
    var showSettings = false

    // MARK: - Activity Tab

    enum ActivityTab: String, CaseIterable {
        case objectives = "Objectives"
        case liked = "Liked"
        case saved = "Saved"
        case history = "History"
        case playlists = "Playlists"
    }

    var selectedTab: ActivityTab = .objectives

    // MARK: - Activity Data

    var objectives: [Objective] = []
    var likedContent: [Content] = []
    var savedContent: [Content] = []
    var historyContent: [ContentProgress] = []
    var playlists: [Playlist] = []

    var isLoadingActivity = false
    var showAddObjective = false

    // MARK: - Dependencies

    private let userService: UserService
    private let contentService: ContentService
    private let progressService: ProgressService
    private let socialService: SocialService
    private let objectiveService: ObjectiveService
    private let hapticManager: HapticManager

    // MARK: - Init

    init(
        userService: UserService,
        contentService: ContentService,
        progressService: ProgressService,
        socialService: SocialService,
        objectiveService: ObjectiveService,
        hapticManager: HapticManager
    ) {
        self.userService = userService
        self.contentService = contentService
        self.progressService = progressService
        self.socialService = socialService
        self.objectiveService = objectiveService
        self.hapticManager = hapticManager
    }

    // MARK: - Load Profile

    /// Fetches the current user's full profile from the API.
    func loadProfile() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let fetchedUser = try await userService.getMe()
            self.user = fetchedUser
        } catch let apiError as APIError {
            self.error = apiError
            hapticManager.error()
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            hapticManager.error()
        }

        isLoading = false
    }

    // MARK: - Load Activity Data

    /// Loads data for the currently selected activity tab.
    func loadActivityData() async {
        isLoadingActivity = true
        switch selectedTab {
        case .objectives:
            if objectives.isEmpty { await loadObjectives() }
        case .liked:
            if likedContent.isEmpty { await loadLikedContent() }
        case .saved:
            if savedContent.isEmpty { await loadSavedContent() }
        case .history:
            if historyContent.isEmpty { await loadHistory() }
        case .playlists:
            if playlists.isEmpty { await loadPlaylists() }
        }
        isLoadingActivity = false
    }

    /// Forces a reload of the current tab's data.
    func reloadCurrentTab() async {
        isLoadingActivity = true
        switch selectedTab {
        case .objectives: await loadObjectives()
        case .liked: await loadLikedContent()
        case .saved: await loadSavedContent()
        case .history: await loadHistory()
        case .playlists: await loadPlaylists()
        }
        isLoadingActivity = false
    }

    private func loadObjectives() async {
        do {
            objectives = try await objectiveService.list()
        } catch {
            // Non-critical
        }
    }

    private func loadLikedContent() async {
        do {
            likedContent = try await contentService.likedContent(limit: 50)
        } catch {
            // Non-critical
        }
    }

    private func loadSavedContent() async {
        do {
            savedContent = try await contentService.savedContent(limit: 50)
        } catch {
            // Non-critical
        }
    }

    private func loadHistory() async {
        do {
            historyContent = try await progressService.history(limit: 50)
        } catch {
            // Non-critical
        }
    }

    private func loadPlaylists() async {
        do {
            playlists = try await socialService.playlists()
        } catch {
            // Non-critical
        }
    }

    // MARK: - Objective Actions

    func createObjective(
        objectiveType: ObjectiveType,
        timeline: Timeline,
        currentLevel: Difficulty,
        weeklyCommitHours: Int,
        specifics: [String: String]? = nil
    ) async {
        do {
            let newObjective = try await objectiveService.create(
                objectiveType: objectiveType,
                timeline: timeline,
                currentLevel: currentLevel,
                weeklyCommitHours: weeklyCommitHours,
                specifics: specifics
            )
            objectives.insert(newObjective, at: 0)
            hapticManager.success()
        } catch {
            hapticManager.error()
        }
    }

    func pauseObjective(_ objective: Objective) async {
        do {
            try await objectiveService.pause(id: objective.id)
            await loadObjectives()
            hapticManager.success()
        } catch {
            hapticManager.error()
        }
    }

    func resumeObjective(_ objective: Objective) async {
        do {
            try await objectiveService.resume(id: objective.id)
            await loadObjectives()
            hapticManager.success()
        } catch {
            hapticManager.error()
        }
    }

    func setPrimaryObjective(_ objective: Objective) async {
        do {
            try await objectiveService.setPrimary(id: objective.id)
            await loadObjectives()
            hapticManager.success()
        } catch {
            hapticManager.error()
        }
    }

    // MARK: - Refresh (Pull-to-Refresh)

    /// Refreshes profile data without showing the loading indicator.
    func refresh() async {
        error = nil

        do {
            let fetchedUser = try await userService.getMe()
            self.user = fetchedUser
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        await reloadCurrentTab()
    }

    // MARK: - Update User

    /// Updates the local user after an edit completes.
    func applyUpdatedUser(_ updatedUser: User) {
        self.user = updatedUser
    }

    // MARK: - Computed Properties

    var displayName: String {
        guard let user else { return "" }
        return "\(user.firstName) \(user.lastName)"
    }

    var usernameDisplay: String? {
        guard let username = user?.username, !username.isEmpty else { return nil }
        return "@\(username)"
    }

    var memberSinceFormatted: String? {
        guard let user else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: user.createdAt) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: user.createdAt) else { return nil }
            return formatMemberSince(date)
        }
        return formatMemberSince(date)
    }

    private func formatMemberSince(_ date: Date) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM yyyy"
        return "Member since \(displayFormatter.string(from: date))"
    }

    var roleBadgeText: String {
        switch user?.role {
        case .creator: return "Creator"
        case .admin: return "Admin"
        default: return "Learner"
        }
    }

    var isCreator: Bool {
        user?.role == .creator
    }

    /// Items for the currently selected activity tab.
    var currentTabItemCount: Int {
        switch selectedTab {
        case .objectives: return objectives.count
        case .liked: return likedContent.count
        case .saved: return savedContent.count
        case .history: return historyContent.count
        case .playlists: return playlists.count
        }
    }
}
