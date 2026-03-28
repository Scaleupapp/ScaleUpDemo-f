import SwiftUI

@Observable
@MainActor
final class CreatorViewModel {

    var creator: Creator?
    var content: [Content] = []
    var isLoading = false
    var errorMessage: String?
    var isFollowing: Bool = false
    var isFollowLoading: Bool = false
    var localFollowersCount: Int = 0

    private let contentService = ContentService()
    private let userService = UserService()

    func loadCreator(id: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let c = try await contentService.fetchCreator(id: id)
            creator = c
            isFollowing = c.isFollowing ?? false
            localFollowersCount = c.followersCount ?? 0
        } catch {
            errorMessage = "Could not load creator profile"
        }

        if let items = try? await contentService.fetchCreatorContent(creatorId: id) {
            content = items
        }

        isLoading = false
    }

    func toggleFollow() async {
        guard let creator = creator, !isFollowLoading else { return }

        isFollowLoading = true
        let wasFollowing = isFollowing

        // Optimistic update
        isFollowing.toggle()
        localFollowersCount += isFollowing ? 1 : -1
        Haptics.light()

        do {
            if wasFollowing {
                try await userService.unfollow(userId: creator.id)
            } else {
                try await userService.follow(userId: creator.id)
            }
        } catch let error as APIError {
            switch error {
            case .conflict(_):
                // Already following — correct state
                isFollowing = true
                if !wasFollowing { /* count already incremented */ }
            case .notFound where wasFollowing:
                // Not following — correct state
                isFollowing = false
                if wasFollowing { /* count already decremented */ }
            default:
                isFollowing = wasFollowing
                localFollowersCount += wasFollowing ? 1 : -1
                Haptics.error()
            }
        } catch {
            isFollowing = wasFollowing
            localFollowersCount += wasFollowing ? 1 : -1
            Haptics.error()
        }

        isFollowLoading = false
    }
}
