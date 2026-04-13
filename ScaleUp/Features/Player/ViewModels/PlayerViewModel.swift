import SwiftUI
import AVFoundation

@Observable
@MainActor
final class PlayerViewModel {

    // MARK: - State

    var content: Content?
    var isLoading = false
    var errorMessage: String?

    // Playback
    var isPlaying = false
    var isVideoReady = false    // True when AVPlayer has loaded video frames
    var isBuffering = false     // True while video is buffering
    var currentTime: Double = 0
    var duration: Double = 0
    var progress: Double { duration > 0 ? currentTime / duration : 0 }
    var playbackSpeed: Float = 1.0

    // Interactions
    var isLiked = false
    var isSaved = false
    var likeCount: Int = 0
    var saveCount: Int = 0
    var userRating: Int = 0

    // Related
    var relatedContent: [Content] = []

    // Up Next
    var videoDidFinish = false
    var upNextCountdown: Int = 5
    private var upNextTimer: Task<Void, Never>?

    // Description
    var isDescriptionExpanded = false
    var isAISummaryExpanded = false

    // Comments
    var comments: [Comment] = []
    var isLoadingComments = false
    var newCommentText = ""
    var isPostingComment = false
    var commentError: String?
    var commentCount: Int = 0
    var commentPage: Int = 1
    var hasMoreComments = false
    var replyingTo: Comment? = nil
    var editingComment: Comment? = nil
    var expandedReplies: [String: [Comment]] = [:]  // parentId -> replies
    var loadingReplies: Set<String> = []

    // Follow
    var isFollowingCreator = false
    var isFollowLoading = false

    // Playlists
    var playlists: [Playlist] = []
    var showPlaylistSheet = false
    var isLoadingPlaylists = false
    var newPlaylistName = ""
    var playlistAddedMessage: String?
    var playlistError: String?

    // Speed options
    let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    var showSpeedPicker = false

    // MARK: - Player

    private(set) var player: AVPlayer?
    private var timeObserver: Any?
    private var progressTimer: Task<Void, Never>?

    private let playerService = PlayerService()
    private let contentService = ContentService()
    private let userService = UserService()

    // MARK: - Load Content

    func loadContent(id: String) async {
        isLoading = true
        errorMessage = nil

        // Fetch content metadata AND stream URL in parallel (saves 2-3s)
        async let contentTask: Content? = {
            try? await self.contentService.fetchContent(id: id)
        }()
        async let streamTask: StreamResponse? = {
            try? await self.playerService.fetchStreamURL(contentId: id)
        }()
        async let relatedTask: () = loadRelated(id: id)
        async let commentsTask: () = loadComments(id: id)

        let (fetchedContent, stream) = await (contentTask, streamTask)

        if let fetchedContent {
            content = fetchedContent
            likeCount = fetchedContent.likeCount ?? 0
            saveCount = fetchedContent.saveCount ?? 0
            commentCount = fetchedContent.commentCount ?? 0
            hasFiredCompletedEvent = false

            let topic = fetchedContent.topics?.first
            AnalyticsService.shared.track(.contentStarted(
                contentId: id,
                topic: topic,
                contentType: fetchedContent.contentType.rawValue,
                source: "player"
            ))
            // Detect C2O transitions (quiz weakness → content, interview gap → content)
            AnalyticsService.shared.checkQuizWeaknessToContent(contentId: id, topic: topic)
            AnalyticsService.shared.checkInterviewGapToContent(contentId: id)

            // Fire first_content_viewed once per user lifetime (activation event)
            let defaults = UserDefaults.standard
            if !defaults.bool(forKey: "analytics.firstContentViewed.fired") {
                defaults.set(true, forKey: "analytics.firstContentViewed.fired")
                AnalyticsService.shared.track(.firstContentViewed(contentId: id, topic: topic))
            }

            // Fetch user's interaction status (liked/saved/rated) + follow status
            async let interactionTask: InteractionStatus? = {
                try? await self.contentService.fetchInteractionStatus(contentId: id)
            }()
            async let creatorTask: Creator? = {
                guard let creatorId = fetchedContent.creatorId?.id else { return nil }
                return try? await self.contentService.fetchCreator(id: creatorId)
            }()

            let (interaction, creator) = await (interactionTask, creatorTask)
            if let interaction {
                isLiked = interaction.isLiked
                isSaved = interaction.isSaved
                userRating = interaction.userRating
            }
            if let creator {
                isFollowingCreator = creator.isFollowing ?? false
            }
        } else {
            loadMockContent(id: id)
        }

        // Set up player as soon as stream URL is ready
        if let urlString = stream?.resolvedURL,
           let url = URL(string: urlString) {
            setupPlayer(url: url)
        }

        // Wait for related + comments (already started in parallel)
        _ = await (relatedTask, commentsTask)

        isLoading = false
    }

    private func loadRelated(id: String) async {
        if let related = try? await contentService.fetchSimilar(contentId: id) {
            relatedContent = related
        }
    }

    private func loadComments(id: String) async {
        isLoadingComments = true
        commentError = nil
        commentPage = 1
        do {
            let response = try await playerService.fetchComments(contentId: id, page: 1)
            comments = response.comments
            hasMoreComments = response.pagination?.hasNextPage ?? false
        } catch {
            print("[Comments] loadComments failed: \(error)")
            commentError = "Could not load comments"
        }
        isLoadingComments = false
    }

    func loadMoreComments() async {
        guard hasMoreComments, let id = content?.id else { return }
        commentPage += 1
        do {
            let response = try await playerService.fetchComments(contentId: id, page: commentPage)
            comments.append(contentsOf: response.comments)
            hasMoreComments = response.pagination?.hasNextPage ?? false
        } catch {
            commentPage -= 1
        }
    }

    // MARK: - Player Setup

    private var statusObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?

    private func setupPlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 5 // Buffer 5 seconds ahead
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        isVideoReady = false
        isBuffering = true

        // Observe when video is ready to play (has loaded first frames)
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isVideoReady = true
                    self.isBuffering = false
                case .failed:
                    self.isVideoReady = false
                    self.isBuffering = false
                    self.errorMessage = "Video failed to load"
                default:
                    break
                }
            }
        }

        // Observe buffering state — playbackLikelyToKeepUp
        bufferObservation = playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if item.isPlaybackLikelyToKeepUp {
                    self.isBuffering = false
                }
            }
        }

        // Observe buffer empty — player stalled
        bufferEmptyObservation = playerItem.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if item.isPlaybackBufferEmpty && self.isPlaying {
                    self.isBuffering = true
                }
            }
        }

        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds
                if let dur = self.player?.currentItem?.duration.seconds, dur.isFinite {
                    self.duration = dur
                }
            }
        }

        // Observe video end for "Up Next"
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleVideoEnd()
            }
        }

        startProgressTracking()
    }

    private func handleVideoEnd() {
        isPlaying = false
        videoDidFinish = true

        guard !relatedContent.isEmpty else { return }

        // Start countdown for auto-play next
        upNextCountdown = 5
        upNextTimer?.cancel()
        upNextTimer = Task { @MainActor [weak self] in
            while let self, self.upNextCountdown > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.upNextCountdown -= 1
            }
        }
    }

    func cancelUpNext() {
        upNextTimer?.cancel()
        videoDidFinish = false
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let player, isVideoReady else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
            player.rate = playbackSpeed
        }
        isPlaying.toggle()
    }

    func seek(to fraction: Double) {
        guard let player, duration > 0 else { return }
        let time = CMTime(seconds: fraction * duration, preferredTimescale: 600)
        player.seek(to: time)
    }

    func seekRelative(seconds: Double) {
        guard let player else { return }
        let newTime = max(0, min(duration, currentTime + seconds))
        let time = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: time)
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }

    // MARK: - Progress Tracking

    private func startProgressTracking() {
        progressTimer?.cancel()
        progressTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                await self?.sendProgressUpdate()
            }
        }
    }

    private func sendProgressUpdate() async {
        guard let contentId = content?.id else { return }
        let _ = try? await playerService.updateProgress(
            contentId: contentId,
            currentPosition: Int(currentTime),
            totalDuration: Int(duration),
            timeSpent: Int(currentTime)
        )

        if progress >= 0.95 && !hasFiredCompletedEvent {
            hasFiredCompletedEvent = true
            try? await playerService.markComplete(contentId: contentId)
            AnalyticsService.shared.track(.contentCompleted(
                contentId: contentId,
                topic: content?.topics?.first,
                durationSeconds: Int(duration)
            ))
            // Seed the content→quiz transition window
            AnalyticsService.shared.recordContentCompleted(contentId: contentId)
        }
    }

    // Guard to prevent contentCompleted firing twice for the same content
    private var hasFiredCompletedEvent = false

    // MARK: - Interactions

    func toggleLike() async {
        guard let id = content?.id else { return }
        let willLike = !isLiked
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        Haptics.light()

        if let response = try? await contentService.toggleLike(contentId: id) {
            isLiked = response.liked
            likeCount = response.likeCount
        }
        if willLike {
            AnalyticsService.shared.track(.contentLiked(contentId: id))
        }
    }

    func toggleSave() async {
        guard let id = content?.id else { return }
        let willSave = !isSaved
        isSaved.toggle()
        saveCount += isSaved ? 1 : -1
        Haptics.light()

        if let response = try? await contentService.toggleSave(contentId: id) {
            isSaved = response.saved
            saveCount = response.saveCount
        }
        if willSave {
            AnalyticsService.shared.track(.contentSaved(contentId: id))
        }
    }

    func toggleFollowCreator() async {
        guard let creatorId = content?.creatorId?.id, !isFollowLoading else { return }
        isFollowLoading = true
        let wasFollowing = isFollowingCreator

        // Optimistic update
        isFollowingCreator.toggle()
        Haptics.light()

        do {
            if wasFollowing {
                try await userService.unfollow(userId: creatorId)
            } else {
                try await userService.follow(userId: creatorId)
            }
        } catch {
            let desc = "\(error)"
            if desc.contains("Already following") || desc.contains("conflict") {
                isFollowingCreator = true
            } else if desc.contains("Not following") && wasFollowing {
                isFollowingCreator = false
            } else {
                isFollowingCreator = wasFollowing
                Haptics.error()
            }
        }

        isFollowLoading = false
    }

    func rate(_ value: Int) async {
        guard let id = content?.id else { return }
        userRating = value
        Haptics.success()
        try? await contentService.rate(contentId: id, value: value)
        AnalyticsService.shared.track(.contentRated(contentId: id, rating: value))
    }

    func trackCreatorFollowed() {
        guard let creatorId = content?.creatorId?.id else { return }
        if isFollowingCreator {
            AnalyticsService.shared.track(.creatorFollowed(creatorId: creatorId))
        } else {
            AnalyticsService.shared.track(.creatorUnfollowed(creatorId: creatorId))
        }
    }

    // MARK: - Comments

    func postComment() async {
        guard let id = content?.id, !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isPostingComment = true
        commentError = nil
        Haptics.light()

        do {
            if let editing = editingComment {
                // Edit existing comment
                let updated = try await playerService.editComment(commentId: editing.id, text: newCommentText)
                if let idx = comments.firstIndex(where: { $0.id == editing.id }) {
                    comments[idx] = updated
                }
                editingComment = nil
            } else {
                // New comment or reply
                let parentId = replyingTo?.id
                let comment = try await playerService.addComment(contentId: id, text: newCommentText, parentId: parentId)

                if let parentId, var replies = expandedReplies[parentId] {
                    replies.append(comment)
                    expandedReplies[parentId] = replies
                    // Update reply count on parent
                    if let idx = comments.firstIndex(where: { $0.id == parentId }) {
                        let old = comments[idx]
                        comments[idx] = Comment(id: old.id, userId: old.userId, contentId: old.contentId, parentId: old.parentId, text: old.text, likeCount: old.likeCount, isEdited: old.isEdited, replyCount: (old.replyCount ?? 0) + 1, createdAt: old.createdAt, updatedAt: old.updatedAt)
                    }
                } else {
                    comments.insert(comment, at: 0)
                }
                commentCount += 1
                replyingTo = nil
            }
            newCommentText = ""
            Haptics.success()
        } catch {
            print("[Comments] postComment failed: \(error)")
            commentError = "Failed to post comment. Please try again."
            Haptics.error()
        }

        isPostingComment = false
    }

    func deleteComment(_ comment: Comment) async {
        do {
            try await playerService.deleteComment(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            // Also remove from replies
            for (key, var replies) in expandedReplies {
                replies.removeAll { $0.id == comment.id }
                expandedReplies[key] = replies
            }
            commentCount = max(0, commentCount - 1)
            Haptics.success()
        } catch {
            commentError = "Could not delete comment"
            Haptics.error()
        }
    }

    func toggleCommentLike(_ comment: Comment) async {
        do {
            let response = try await playerService.toggleCommentLike(commentId: comment.id)
            if let idx = comments.firstIndex(where: { $0.id == comment.id }) {
                var updated = comments[idx]
                updated.isLikedByMe = response.liked
                comments[idx] = Comment(id: updated.id, userId: updated.userId, contentId: updated.contentId, parentId: updated.parentId, text: updated.text, likeCount: response.likeCount, isEdited: updated.isEdited, replyCount: updated.replyCount, createdAt: updated.createdAt, updatedAt: updated.updatedAt)
                comments[idx].isLikedByMe = response.liked
            }
            Haptics.light()
        } catch {
            Haptics.error()
        }
    }

    func loadReplies(for comment: Comment) async {
        guard !loadingReplies.contains(comment.id) else { return }
        loadingReplies.insert(comment.id)
        do {
            let response = try await playerService.fetchReplies(commentId: comment.id)
            expandedReplies[comment.id] = response.replies
        } catch {
            print("[Comments] loadReplies failed: \(error)")
        }
        loadingReplies.remove(comment.id)
    }

    func startReply(to comment: Comment) {
        replyingTo = comment
        editingComment = nil
        newCommentText = ""
    }

    func startEdit(_ comment: Comment) {
        editingComment = comment
        replyingTo = nil
        newCommentText = comment.text
    }

    func cancelReplyOrEdit() {
        replyingTo = nil
        editingComment = nil
        newCommentText = ""
    }

    // MARK: - Playlists

    func loadPlaylists() async {
        isLoadingPlaylists = true
        playlistError = nil
        do {
            playlists = try await playerService.fetchMyPlaylists()
        } catch {
            print("[Playlist] loadPlaylists failed: \(error)")
            playlistError = "Could not load playlists"
        }
        isLoadingPlaylists = false
    }

    func addToPlaylist(_ playlist: Playlist) async {
        guard let contentId = content?.id else {
            playlistError = "Content not available"
            return
        }
        playlistError = nil

        do {
            _ = try await playerService.addToPlaylist(playlistId: playlist.id, contentId: contentId)
            Haptics.success()
            playlistAddedMessage = "Added to \(playlist.title)"
            showPlaylistSheet = false

            Task {
                try? await Task.sleep(for: .seconds(2))
                playlistAddedMessage = nil
            }
        } catch let error as APIError {
            if case .conflict(let msg) = error {
                Haptics.light()
                playlistError = msg.contains("already") ? "Content already added in this playlist" : msg
            } else {
                Haptics.error()
                playlistError = "Failed to add to playlist"
            }
            print("[Playlist] addToPlaylist failed: \(error)")
        } catch {
            print("[Playlist] addToPlaylist failed: \(error)")
            Haptics.error()
            playlistError = "Failed to add to playlist"
        }
    }

    func createAndAddToPlaylist() async {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            playlistError = "Enter a playlist name"
            return
        }
        playlistError = nil

        do {
            let playlist = try await playerService.createPlaylist(title: name)

            // Add current content if available
            if let contentId = content?.id {
                _ = try await playerService.addToPlaylist(playlistId: playlist.id, contentId: contentId)
                playlistAddedMessage = "Created \"\(name)\" and added"
            } else {
                playlistAddedMessage = "Created \"\(name)\""
            }

            newPlaylistName = ""
            showPlaylistSheet = false
            Haptics.success()

            // Refresh playlists list
            await loadPlaylists()

            Task {
                try? await Task.sleep(for: .seconds(2))
                playlistAddedMessage = nil
            }
        } catch {
            print("[Playlist] createAndAddToPlaylist failed: \(error)")
            Haptics.error()
            playlistError = "Failed to create playlist"
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        statusObservation?.invalidate()
        bufferObservation?.invalidate()
        bufferEmptyObservation?.invalidate()
        statusObservation = nil
        bufferObservation = nil
        bufferEmptyObservation = nil
        endObserver = nil
        player?.pause()
        player = nil
        progressTimer?.cancel()
        upNextTimer?.cancel()
        isVideoReady = false
        isBuffering = false
        videoDidFinish = false
    }

    // MARK: - Mock

    private func loadMockContent(id: String) {
        let creator = Creator(
            id: "c1", firstName: "Sarah", lastName: "Johnson", username: "sarahj",
            profilePicture: nil, bio: "Product leader, 10+ years at FAANG. Teaching the next generation.",
            tier: .anchor, followersCount: 12400, contentCount: 45, averageRating: 4.7
        )

        content = Content(
            id: id, creatorId: creator,
            title: "Product Strategy Fundamentals: Building Your First Roadmap",
            description: "In this comprehensive guide, we'll cover everything you need to know about building a product roadmap from scratch. You'll learn about prioritization frameworks, stakeholder alignment, and how to communicate your roadmap effectively.\n\nTopics covered:\n• RICE scoring framework\n• OKR alignment\n• Stakeholder mapping\n• Timeline visualization\n• Iteration and feedback loops",
            contentType: .video, contentURL: nil, thumbnailURL: nil,
            duration: 1245, sourceType: .original, sourceAttribution: nil,
            domain: "Product Management", topics: ["Strategy", "Roadmapping", "Prioritization"],
            tags: ["PM", "strategy", "roadmap", "product"],
            difficulty: .intermediate,
            aiData: AIData(
                summary: "A step-by-step guide to building effective product roadmaps. Covers RICE scoring, OKR alignment, and stakeholder communication strategies.",
                keyConcepts: [
                    KeyConcept(concept: "RICE Framework", description: "Reach, Impact, Confidence, Effort scoring", timestamp: "3:24", importance: 5),
                    KeyConcept(concept: "Stakeholder Mapping", description: "Identifying and managing stakeholders", timestamp: "8:15", importance: 4),
                    KeyConcept(concept: "OKR Alignment", description: "Connecting roadmap to company objectives", timestamp: "14:02", importance: 5)
                ],
                prerequisites: ["Basic product management concepts", "Understanding of agile methodology"],
                qualityScore: 85
            ),
            status: .published,
            viewCount: 14200, likeCount: 890, commentCount: 45, saveCount: 320,
            averageRating: 4.6, ratingCount: 156,
            publishedAt: Date().addingTimeInterval(-86400 * 3), createdAt: nil
        )

        likeCount = content?.likeCount ?? 0
        saveCount = content?.saveCount ?? 0
        commentCount = content?.commentCount ?? 0
        duration = Double(content?.duration ?? 0)

        // Mock comments
        comments = [
            Comment(id: "mc1", userId: CommentUser(id: "u1", firstName: "Alex", lastName: "Kim", username: "alexk", profilePicture: nil), contentId: id, parentId: nil, text: "Great breakdown of RICE framework! Really helped me understand prioritization.", likeCount: 12, isEdited: false, createdAt: Date().addingTimeInterval(-3600), updatedAt: nil),
            Comment(id: "mc2", userId: CommentUser(id: "u2", firstName: "Priya", lastName: "Sharma", username: "priyas", profilePicture: nil), contentId: id, parentId: nil, text: "The OKR alignment section was exactly what I needed for my team's quarterly planning.", likeCount: 8, isEdited: false, createdAt: Date().addingTimeInterval(-7200), updatedAt: nil),
            Comment(id: "mc3", userId: CommentUser(id: "u3", firstName: "Jordan", lastName: nil, username: "jordan_pm", profilePicture: nil), contentId: id, parentId: nil, text: "Can you do a follow-up on how to handle competing stakeholder priorities?", likeCount: 5, isEdited: false, createdAt: Date().addingTimeInterval(-86400), updatedAt: nil)
        ]
    }
}
