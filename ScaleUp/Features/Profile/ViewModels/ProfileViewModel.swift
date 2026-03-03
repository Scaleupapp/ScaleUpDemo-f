import SwiftUI

@Observable
@MainActor
final class ProfileViewModel {

    // MARK: - State

    var user: User?
    var creatorProfile: CreatorProfileData?
    var applicationStatus: CreatorApplication?
    var objectives: [UserObjective] = []
    var likedContent: [Content] = []
    var savedContent: [Content] = []
    var viewHistory: [ContentProgress] = []
    var isLoading = false
    var errorMessage: String?

    var showEditSheet = false
    var showSettings = false

    // MARK: - Services

    private let userService = UserService()
    private let objectiveService = ObjectiveService()
    private let creatorService = CreatorService()

    // MARK: - Computed

    var isCreator: Bool {
        user?.role == .creator
    }

    var isAdmin: Bool {
        user?.role == .admin
    }

    var memberSince: String {
        guard let date = user?.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "Member since \(formatter.string(from: date))"
    }

    // MARK: - Load Profile

    func loadProfile() async {
        isLoading = true
        errorMessage = nil

        async let userTask: User? = {
            try? await self.userService.fetchMe()
        }()
        async let objectivesTask: [UserObjective]? = {
            try? await self.objectiveService.list()
        }()

        let (fetchedUser, fetchedObjectives) = await (userTask, objectivesTask)

        user = fetchedUser
        objectives = fetchedObjectives ?? []

        // Load creator-specific data
        if user?.role == .creator {
            creatorProfile = try? await creatorService.fetchMyProfile()
        } else if user?.role == .consumer {
            applicationStatus = try? await creatorService.fetchMyApplication()
        }

        isLoading = false
    }

    // MARK: - Load Tabbed Content

    func loadLikedContent() async {
        likedContent = (try? await userService.fetchLikedContent()) ?? []
    }

    func loadSavedContent() async {
        savedContent = (try? await userService.fetchSavedContent()) ?? []
    }

    func loadViewHistory() async {
        viewHistory = (try? await userService.fetchViewHistory()) ?? []
    }

    // MARK: - Objective Actions

    func pauseObjective(_ id: String) async {
        do {
            try await objectiveService.pause(id: id)
            Haptics.success()
            objectives = (try? await objectiveService.list()) ?? objectives
        } catch {
            Haptics.error()
        }
    }

    func resumeObjective(_ id: String) async {
        do {
            try await objectiveService.resume(id: id)
            Haptics.success()
            objectives = (try? await objectiveService.list()) ?? objectives
        } catch {
            Haptics.error()
        }
    }

    func setPrimaryObjective(_ id: String) async {
        do {
            try await objectiveService.setPrimary(id: id)
            Haptics.success()
            objectives = (try? await objectiveService.list()) ?? objectives
        } catch {
            Haptics.error()
        }
    }

    // MARK: - Update User (after edit)

    func applyUpdatedUser(_ updated: User) {
        user = updated
    }
}
