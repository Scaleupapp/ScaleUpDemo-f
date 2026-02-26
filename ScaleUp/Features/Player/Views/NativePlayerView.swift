import SwiftUI
import AVKit

// MARK: - Native Player View

/// UIViewControllerRepresentable wrapping AVPlayerViewController for direct video URLs.
/// Reports playback state, current time, and duration back to SwiftUI bindings.
struct NativePlayerView: UIViewControllerRepresentable {

    let videoURL: String

    /// Optional position (in seconds) to resume playback from.
    var startPosition: Double = 0

    /// Bindings to expose player state to the parent view.
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double

    /// Playback configuration
    var playbackSpeed: Float = 1.0
    var isMuted: Bool = false

    /// Callbacks for state transitions.
    var onTimeUpdate: ((Double, Double) -> Void)?
    var onVideoEnded: (() -> Void)?

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        playerViewController.showsPlaybackControls = false
        playerViewController.videoGravity = .resizeAspect
        playerViewController.view.backgroundColor = .black
        playerViewController.allowsPictureInPicturePlayback = false

        guard let url = URL(string: videoURL) else {
            return playerViewController
        }

        let player = AVPlayer(url: url)
        playerViewController.player = player

        context.coordinator.player = player
        context.coordinator.playerViewController = playerViewController
        context.coordinator.setupObservers()

        return playerViewController
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        guard let player = context.coordinator.player else { return }

        // Sync play/pause state
        if isPlaying && player.timeControlStatus != .playing {
            player.play()
        } else if !isPlaying && player.timeControlStatus == .playing {
            player.pause()
        }

        // Sync playback speed
        if player.rate != 0 && player.rate != playbackSpeed {
            player.rate = playbackSpeed
        }
        player.defaultRate = playbackSpeed

        // Sync mute
        player.isMuted = isMuted
    }

    static func dismantleUIViewController(
        _ uiViewController: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        coordinator.cleanup()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {

        var parent: NativePlayerView
        var player: AVPlayer?
        weak var playerViewController: AVPlayerViewController?

        private var timeObserver: Any?
        private var statusObserver: NSKeyValueObservation?
        private var endObserver: NSObjectProtocol?
        private var hasSeekToStart = false

        init(parent: NativePlayerView) {
            self.parent = parent
            super.init()
        }

        // MARK: - Setup

        func setupObservers() {
            guard let player else { return }

            // Periodic time observer — fires every second
            let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: interval,
                queue: .main
            ) { [weak self] time in
                guard let self else { return }
                let ct = time.seconds
                let dur = player.currentItem?.duration.seconds ?? 0

                guard ct.isFinite, dur.isFinite, dur > 0 else { return }

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.parent.currentTime = ct
                    self.parent.duration = dur
                    self.parent.onTimeUpdate?(ct, dur)
                }
            }

            // Observe player status to know when it is ready to play
            statusObserver = player.currentItem?.observe(
                \.status,
                options: [.new]
            ) { [weak self] item, _ in
                guard let self else { return }
                if item.status == .readyToPlay {
                    Task { @MainActor [weak self] in
                        guard let self else { return }

                        let dur = item.duration.seconds
                        if dur.isFinite {
                            self.parent.duration = dur
                        }

                        // Seek to start position if specified
                        if !self.hasSeekToStart && self.parent.startPosition > 0 {
                            self.hasSeekToStart = true
                            let seekTime = CMTime(
                                seconds: self.parent.startPosition,
                                preferredTimescale: CMTimeScale(NSEC_PER_SEC)
                            )
                            await player.seek(to: seekTime)
                        }
                    }
                }
            }

            // Listen for video end notification
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.parent.isPlaying = false
                    self.parent.onVideoEnded?()
                }
            }
        }

        // MARK: - Player Controls

        func play() {
            player?.play()
        }

        func pause() {
            player?.pause()
        }

        func seek(to seconds: Double) {
            let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: time)
        }

        // MARK: - Cleanup

        func cleanup() {
            if let timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            timeObserver = nil
            statusObserver?.invalidate()
            statusObserver = nil

            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            endObserver = nil

            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }
}
