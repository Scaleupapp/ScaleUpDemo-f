import SwiftUI
import AVFoundation

struct VideoPlayerView: View {
    let player: AVPlayer?
    @Binding var isPlaying: Bool
    let isVideoReady: Bool
    let isBuffering: Bool
    let currentTime: Double
    let duration: Double
    let playbackSpeed: Float
    let onSeek: (Double) -> Void
    let onSeekRelative: (Double) -> Void
    let onSpeedTap: () -> Void
    var isFullscreen: Bool = false
    var onFullscreen: (() -> Void)? = nil

    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isScrubbing = false
    @State private var scrubPosition: Double?  // Separate scrub tracking

    var body: some View {
        if isFullscreen {
            videoContent
                .background(Color.black)
                .ignoresSafeArea()
        } else {
            videoContent
                .aspectRatio(16/9, contentMode: .fit)
        }
    }

    // MARK: - Video Content

    private var displayTime: Double {
        scrubPosition ?? currentTime
    }

    private var displayProgress: Double {
        duration > 0 ? displayTime / duration : 0
    }

    private var videoContent: some View {
        ZStack {
            // Video layer
            if let player {
                VideoLayer(player: player)
                    .ignoresSafeArea(edges: isFullscreen ? .all : .horizontal)
            } else {
                ZStack {
                    ColorTokens.surface
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            // Loading / buffering indicator
            if !isVideoReady || isBuffering {
                ZStack {
                    if !isVideoReady {
                        Color.black.opacity(0.6)
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Loading video...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    } else if isBuffering {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                    }
                }
            }

            // Controls overlay (only when video is ready)
            if isVideoReady {
                controlsLayer
            }
        }
    }

    // MARK: - Controls Layer

    private var controlsLayer: some View {
        ZStack {
            // Tap area to show/hide controls — only the center area
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                    if showControls { scheduleHideControls() }
                }

            if showControls {
                // Dimmed background
                Color.black.opacity(0.45)
                    .allowsHitTesting(false)

                // Top bar
                topBar

                // Center playback controls
                centerControls

                // Bottom progress bar — always interactive
                bottomBar
            } else {
                // Even when controls hidden, show thin progress line
                VStack {
                    Spacer()
                    progressBarMinimal
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: showControls)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    onSpeedTap()
                    scheduleHideControls()
                } label: {
                    Text(speedLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, isFullscreen ? 48 : Spacing.md)
            .padding(.top, isFullscreen ? Spacing.lg : Spacing.sm)
            Spacer()
        }
    }

    // MARK: - Center Controls

    private var centerControls: some View {
        HStack(spacing: Spacing.xxl) {
            Button {
                onSeekRelative(-10)
                scheduleHideControls()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: isFullscreen ? 34 : 28))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Button {
                isPlaying.toggle()
                scheduleHideControls()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: isFullscreen ? 54 : 44))
                    .foregroundStyle(.white)
            }

            Button {
                onSeekRelative(10)
                scheduleHideControls()
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: isFullscreen ? 34 : 28))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    // MARK: - Bottom Bar (Progress + Time)

    private var bottomBar: some View {
        VStack {
            Spacer()
            HStack(spacing: Spacing.sm) {
                Text(formatTime(displayTime))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
                    .frame(width: 40, alignment: .leading)

                scrubBar

                Text(formatTime(duration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)

                if let onFullscreen {
                    Button {
                        onFullscreen()
                    } label: {
                        Image(systemName: isFullscreen
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                    }
                }
            }
            .padding(.horizontal, isFullscreen ? 48 : Spacing.md)
            .padding(.bottom, isFullscreen ? Spacing.lg : Spacing.sm)
        }
    }

    // MARK: - Scrub Bar

    private var scrubBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.25))
                    .frame(height: isScrubbing ? 6 : 3)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(ColorTokens.gold)
                    .frame(
                        width: max(0, geo.size.width * displayProgress),
                        height: isScrubbing ? 6 : 3
                    )

                // Scrub handle (always visible, bigger when scrubbing)
                Circle()
                    .fill(ColorTokens.gold)
                    .frame(width: isScrubbing ? 16 : 10, height: isScrubbing ? 16 : 10)
                    .offset(x: max(0, min(geo.size.width - 10, geo.size.width * displayProgress - 5)))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle().size(width: geo.size.width, height: 44))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        scrubPosition = fraction * duration
                        // Cancel auto-hide while scrubbing
                        hideControlsTask?.cancel()
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        onSeek(fraction)
                        isScrubbing = false
                        scrubPosition = nil
                        scheduleHideControls()
                    }
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        scrubPosition = fraction * duration
                        hideControlsTask?.cancel()
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        onSeek(fraction)
                        isScrubbing = false
                        scrubPosition = nil
                        scheduleHideControls()
                    }
            )
        }
        .frame(height: 44)
    }

    // MARK: - Minimal progress (when controls hidden)

    private var progressBarMinimal: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.15))
                Rectangle()
                    .fill(ColorTokens.gold)
                    .frame(width: geo.size.width * displayProgress)
            }
        }
        .frame(height: 2)
    }

    // MARK: - Helpers

    private var speedLabel: String {
        if playbackSpeed == 1.0 { return "1x" }
        if playbackSpeed == floor(playbackSpeed) { return "\(Int(playbackSpeed))x" }
        return String(format: "%.2gx", playbackSpeed)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

// MARK: - AVPlayer UIViewRepresentable

private struct VideoLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
