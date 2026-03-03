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

    // Description
    var isDescriptionExpanded = false
    var isAISummaryExpanded = false

    // Comments
    var comments: [Comment] = []
    var isLoadingComments = false
    var newCommentText = ""
    var isPostingComment = false
    var commentCount: Int = 0

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

    // MARK: - Load Content

    func loadContent(id: String) async {
        isLoading = true
        errorMessage = nil

        do {
            content = try await contentService.fetchContent(id: id)
            likeCount = content?.likeCount ?? 0
            saveCount = content?.saveCount ?? 0
            commentCount = content?.commentCount ?? 0

            // Load stream URL
            if let stream = try? await playerService.fetchStreamURL(contentId: id),
               let urlString = stream.resolvedURL,
               let url = URL(string: urlString) {
                setupPlayer(url: url)
            }
        } catch {
            loadMockContent(id: id)
        }

        // Load related content and comments in parallel
        async let relatedTask: () = loadRelated(id: id)
        async let commentsTask: () = loadComments(id: id)
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
        if let response = try? await playerService.fetchComments(contentId: id) {
            comments = response.comments
        }
        isLoadingComments = false
    }

    // MARK: - Player Setup

    private func setupPlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

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

        startProgressTracking()
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let player else { return }
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

        if progress >= 0.95 {
            try? await playerService.markComplete(contentId: contentId)
        }
    }

    // MARK: - Interactions

    func toggleLike() async {
        guard let id = content?.id else { return }
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        Haptics.light()

        if let response = try? await contentService.toggleLike(contentId: id) {
            isLiked = response.liked
            likeCount = response.likeCount
        }
    }

    func toggleSave() async {
        guard let id = content?.id else { return }
        isSaved.toggle()
        saveCount += isSaved ? 1 : -1
        Haptics.light()

        if let response = try? await contentService.toggleSave(contentId: id) {
            isSaved = response.saved
            saveCount = response.saveCount
        }
    }

    func rate(_ value: Int) async {
        guard let id = content?.id else { return }
        userRating = value
        Haptics.success()
        try? await contentService.rate(contentId: id, value: value)
    }

    // MARK: - Comments

    func postComment() async {
        guard let id = content?.id, !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isPostingComment = true
        Haptics.light()

        if let comment = try? await playerService.addComment(contentId: id, text: newCommentText) {
            comments.insert(comment, at: 0)
            commentCount += 1
            newCommentText = ""
        }

        isPostingComment = false
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
        player?.pause()
        player = nil
        progressTimer?.cancel()
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
