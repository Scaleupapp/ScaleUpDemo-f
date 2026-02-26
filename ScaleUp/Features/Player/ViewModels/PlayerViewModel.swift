import SwiftUI

// MARK: - Player View Model

@Observable
@MainActor
final class PlayerViewModel {

    // MARK: - Content State

    var content: Content?
    var similarContent: [Content] = []
    var comments: [Comment] = []

    // MARK: - Player State

    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var isPlayerReady: Bool = false
    var streamURL: String?
    var playbackSpeed: Float = 1.0
    var isMuted: Bool = false
    var isFullscreen: Bool = false

    // MARK: - Interaction State

    var isLiked: Bool = false
    var isSaved: Bool = false
    var userRating: Int = 0

    // MARK: - Counts (mutable for optimistic updates)

    var likeCount: Int = 0
    var saveCount: Int = 0
    var commentCount: Int = 0

    // MARK: - UI State

    var isControlsVisible: Bool = true
    var isAISummaryExpanded: Bool = false
    var isLoading: Bool = false
    var isLoadingComments: Bool = false
    var isSubmittingComment: Bool = false
    var error: APIError?

    // MARK: - Comment Input

    var newCommentText: String = ""

    // MARK: - Dependencies

    private let contentService: ContentService
    private let progressService: ProgressService
    private let recommendationService: RecommendationService

    // MARK: - Progress Tracking

    private let progressTracker: ProgressTracker
    private var lastSyncTime: Double = 0

    // MARK: - Auto-Hide Timer

    private var controlsHideTask: Task<Void, Never>?

    // MARK: - Init

    init(
        contentService: ContentService,
        progressService: ProgressService,
        recommendationService: RecommendationService
    ) {
        self.contentService = contentService
        self.progressService = progressService
        self.recommendationService = recommendationService
        self.progressTracker = ProgressTracker(progressService: progressService)
    }

    // MARK: - Load Content

    /// Fetches content (critical), then similar content and comments (non-critical).
    func loadContent(id: String) async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        // Critical: fetch the content detail first
        do {
            let fetchedContent = try await contentService.getContent(id: id)
            content = fetchedContent

            // Sync counts from fetched content
            likeCount = fetchedContent.likeCount
            saveCount = fetchedContent.saveCount
            commentCount = fetchedContent.commentCount

            // Fetch presigned stream URL for S3 playback
            do {
                streamURL = try await contentService.getStreamUrl(id: id)
            } catch {
                // Fall back to the raw content URL if stream endpoint fails
                streamURL = fetchedContent.contentURL
            }

            // Start progress tracking
            await progressTracker.startTracking(contentId: id)

            // Start auto-hide timer for controls
            scheduleControlsHide()
        } catch let apiError as APIError {
            error = apiError
            isLoading = false
            return
        } catch {
            self.error = .networkError(error)
            isLoading = false
            return
        }

        // Non-critical: similar content and comments — fail silently
        do {
            similarContent = try await recommendationService.similar(id: id)
        } catch {
            // Similar content is supplementary — don't block the player
        }

        do {
            let result = try await contentService.getComments(id: id, page: 1, limit: 20)
            comments = result.items
        } catch {
            // Comments are supplementary — don't block the player
        }

        isLoading = false
    }

    // MARK: - Toggle Like (Optimistic)

    func toggleLike() async {
        guard let contentId = content?.id else { return }

        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        do {
            try await contentService.like(id: contentId)
        } catch {
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }
    }

    // MARK: - Toggle Save (Optimistic)

    func toggleSave() async {
        guard let contentId = content?.id else { return }

        isSaved.toggle()
        saveCount += isSaved ? 1 : -1

        do {
            try await contentService.save(id: contentId)
        } catch {
            isSaved.toggle()
            saveCount += isSaved ? 1 : -1
        }
    }

    // MARK: - Rate Content

    func rateContent(value: Int) async {
        guard let contentId = content?.id else { return }

        let previousRating = userRating
        userRating = value

        do {
            try await contentService.rate(id: contentId, value: value)
        } catch {
            userRating = previousRating
        }
    }

    // MARK: - Add Comment

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

    // MARK: - Time Update

    /// Called from the player views whenever current time updates.
    /// Updates local state and syncs progress to the backend every 10 seconds.
    func onTimeUpdate(current: Double, total: Double) {
        currentTime = current
        duration = total

        // Sync progress via the ProgressTracker actor
        Task {
            await progressTracker.updateTime(current: current, total: total)
        }
    }

    // MARK: - Video Ended

    /// Called when the video reaches the end.
    func onVideoEnded() async {
        isPlaying = false
        isControlsVisible = true

        // Mark content as complete
        await progressTracker.stopTracking(markComplete: true)
    }

    // MARK: - Play / Pause

    func togglePlayPause() {
        isPlaying.toggle()

        // Reset auto-hide timer when user interacts
        if isPlaying {
            scheduleControlsHide()
        } else {
            // Show controls when paused
            isControlsVisible = true
            controlsHideTask?.cancel()
        }
    }

    // MARK: - Seek

    func seek(to seconds: Double) {
        currentTime = seconds
        // The actual seek is handled by the player view binding
        scheduleControlsHide()
    }

    // MARK: - Skip Forward / Backward

    func skipForward() {
        let newTime = min(currentTime + 10, duration)
        seek(to: newTime)
    }

    func skipBackward() {
        let newTime = max(currentTime - 10, 0)
        seek(to: newTime)
    }

    // MARK: - Playback Speed

    static let availableSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        scheduleControlsHide()
    }

    var playbackSpeedLabel: String {
        playbackSpeed == 1.0 ? "1x" : "\(String(format: "%g", playbackSpeed))x"
    }

    // MARK: - Mute

    func toggleMute() {
        isMuted.toggle()
        scheduleControlsHide()
    }

    // MARK: - Fullscreen

    func toggleFullscreen() {
        withAnimation(Animations.standard) {
            isFullscreen.toggle()
        }

        // Force orientation change
        if isFullscreen {
            OrientationHelper.lockLandscape()
        } else {
            OrientationHelper.lockPortrait()
        }

        scheduleControlsHide()
    }

    // MARK: - Controls Visibility

    /// Toggles controls visibility and resets the auto-hide timer.
    func toggleControls() {
        withAnimation(Animations.standard) {
            isControlsVisible.toggle()
        }

        if isControlsVisible && isPlaying {
            scheduleControlsHide()
        } else {
            controlsHideTask?.cancel()
        }
    }

    /// Schedules controls to hide after 3 seconds.
    private func scheduleControlsHide() {
        controlsHideTask?.cancel()

        controlsHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))

            guard !Task.isCancelled, isPlaying else { return }

            withAnimation(Animations.standard) {
                isControlsVisible = false
            }
        }
    }

    // MARK: - Cleanup

    /// Performs final progress sync on dismiss and resets orientation.
    func cleanup() async {
        controlsHideTask?.cancel()
        if isFullscreen {
            isFullscreen = false
            OrientationHelper.resetToDefault()
        }
        await progressTracker.stopTracking(markComplete: false)
    }

    // MARK: - Time Formatting

    /// Formats seconds into "MM:SS" format.
    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    // MARK: - Computed Properties

    /// Progress percentage from 0 to 1 for the mini progress bar.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(currentTime / duration, 1.0)
    }

    /// The YouTube video ID extracted from the content URL if source is YouTube.
    /// Delegates to Content.youtubeVideoId which handles all URL formats (S3, youtube.com, youtu.be).
    var youtubeVideoId: String? {
        content?.youtubeVideoId
    }
}
