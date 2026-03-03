import SwiftUI

@Observable
@MainActor
final class CreatorViewModel {

    var creator: Creator?
    var content: [Content] = []
    var isLoading = false
    var isFollowing: Bool = false
    var isFollowLoading: Bool = false
    var localFollowersCount: Int = 0

    private let contentService = ContentService()
    private let userService = UserService()

    func loadCreator(id: String) async {
        isLoading = true

        if let c = try? await contentService.fetchCreator(id: id) {
            creator = c
            isFollowing = c.isFollowing ?? false
            localFollowersCount = c.followersCount ?? 0
        }

        if let items = try? await contentService.fetchCreatorContent(creatorId: id) {
            content = items
        }

        // Mock fallback
        if creator == nil {
            creator = Creator(
                id: id, firstName: "Creator", lastName: nil, username: nil,
                profilePicture: nil, bio: "Content creator on ScaleUp. Passionate about teaching and learning.",
                tier: .core, followersCount: 5200, contentCount: 24, averageRating: 4.5
            )
            localFollowersCount = 5200
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

        do {
            if wasFollowing {
                try await userService.unfollow(userId: creator.id)
            } else {
                try await userService.follow(userId: creator.id)
            }
        } catch {
            // Revert on failure
            isFollowing = wasFollowing
            localFollowersCount += wasFollowing ? 1 : -1
        }

        isFollowLoading = false
    }
}
