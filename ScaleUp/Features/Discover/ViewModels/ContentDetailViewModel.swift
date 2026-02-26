import SwiftUI

// MARK: - Content Detail View Model

@Observable
@MainActor
final class ContentDetailViewModel {

    // MARK: - Content

    var content: Content?
    var similarContent: [Content] = []
    var comments: [Comment] = []

    // MARK: - Interaction State

    var isLiked: Bool = false
    var isSaved: Bool = false
    var isFollowingCreator: Bool = false
    var userRating: Int = 0

    // MARK: - Counts (mutable for optimistic updates)

    var likeCount: Int = 0
    var saveCount: Int = 0
    var commentCount: Int = 0

    // MARK: - State

    var isLoading = false
    var isLoadingComments = false
    var isSubmittingComment = false
    var isAISummaryExpanded = false
    var isDescriptionExpanded = false
    var error: APIError?

    // MARK: - Comment Input

    var newCommentText: String = ""

    // MARK: - Dependencies

    private let contentService: ContentService
    private let recommendationService: RecommendationService
    private let socialService: SocialService

    // MARK: - Init

    init(contentService: ContentService, recommendationService: RecommendationService, socialService: SocialService) {
        self.contentService = contentService
        self.recommendationService = recommendationService
        self.socialService = socialService
    }

    // MARK: - Load Content

    /// Fetches the content detail, similar content, and comments.
    /// Content is critical; similar/comments load independently and fail silently.
    func loadContent(id: String) async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        // Fetch content detail (critical)
        do {
            let fetchedContent = try await contentService.getContent(id: id)
            content = fetchedContent
            likeCount = fetchedContent.likeCount
            saveCount = fetchedContent.saveCount
            commentCount = fetchedContent.commentCount
        } catch let apiError as APIError {
            error = apiError
            isLoading = false
            return
        } catch {
            self.error = .networkError(error)
            isLoading = false
            return
        }

        // Fetch similar content and comments independently (non-critical)
        do {
            similarContent = try await recommendationService.similar(id: id)
        } catch {
            print("‼️ SIMILAR CONTENT ERROR: \(error)")
        }

        do {
            let result = try await contentService.getComments(id: id, page: 1, limit: 20)
            comments = result.items
        } catch {
            print("‼️ COMMENTS ERROR: \(error)")
        }

        isLoading = false
    }

    // MARK: - Toggle Like (Optimistic)

    /// Toggles the like state with optimistic update and reverts on error.
    func toggleLike() async {
        guard let contentId = content?.id else { return }

        // Optimistic update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        do {
            try await contentService.like(id: contentId)
        } catch {
            // Revert on error
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }
    }

    // MARK: - Toggle Save (Optimistic)

    /// Toggles the save state with optimistic update and reverts on error.
    func toggleSave() async {
        guard let contentId = content?.id else { return }

        // Optimistic update
        isSaved.toggle()
        saveCount += isSaved ? 1 : -1

        do {
            try await contentService.save(id: contentId)
        } catch {
            // Revert on error
            isSaved.toggle()
            saveCount += isSaved ? 1 : -1
        }
    }

    // MARK: - Rate Content

    /// Rates the content with the given value (1-5).
    func rateContent(value: Int) async {
        guard let contentId = content?.id else { return }

        let previousRating = userRating
        userRating = value

        do {
            try await contentService.rate(id: contentId, value: value)
        } catch {
            // Revert on error
            userRating = previousRating
        }
    }

    // MARK: - Toggle Follow (Optimistic)

    /// Toggles the follow state for the content creator.
    func toggleFollow() async {
        guard let creatorId = content?.creator.id, !creatorId.isEmpty else { return }

        // Optimistic update
        isFollowingCreator.toggle()

        do {
            if isFollowingCreator {
                try await socialService.follow(userId: creatorId)
            } else {
                try await socialService.unfollow(userId: creatorId)
            }
        } catch {
            // Revert on error
            isFollowingCreator.toggle()
        }
    }

    // MARK: - Load Comments

    /// Fetches comments for the current content.
    func loadComments() async {
        guard let contentId = content?.id, !isLoadingComments else { return }

        isLoadingComments = true

        do {
            let result = try await contentService.getComments(id: contentId, page: 1, limit: 50)
            comments = result.items
        } catch {
            // Silently fail — comments are not critical
        }

        isLoadingComments = false
    }

    // MARK: - Add Comment

    /// Submits a new comment on the current content.
    func addComment() async {
        guard let contentId = content?.id else { return }

        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isSubmittingComment else { return }

        isSubmittingComment = true

        do {
            let comment = try await contentService.addComment(id: contentId, text: trimmedText)
            comments.insert(comment, at: 0)
            commentCount += 1
            newCommentText = ""
        } catch {
            // Silently fail — user can retry
        }

        isSubmittingComment = false
    }

    // MARK: - Load Similar

    /// Fetches similar content for the current content.
    func loadSimilar() async {
        guard let contentId = content?.id else { return }

        do {
            similarContent = try await recommendationService.similar(id: contentId)
        } catch {
            // Silently fail — similar content is supplementary
        }
    }
}
