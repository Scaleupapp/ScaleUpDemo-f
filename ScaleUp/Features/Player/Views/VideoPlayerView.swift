import SwiftUI
import AVFoundation

struct VideoPlayerView: View {
    let player: AVPlayer?
    @Binding var isPlaying: Bool
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

    var body: some View {
        if isFullscreen {
            videoContent
                .background(Color.black)
                .ignoresSafeArea()
        } else {
            videoContent
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 0))
        }
    }

    // MARK: - Video Content

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

            // Controls overlay
            if showControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) {
                showControls.toggle()
            }
            if showControls { scheduleHideControls() }
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)

            // Top bar - speed control
            VStack {
                HStack {
                    Spacer()

                    // Speed button
                    Button {
                        onSpeedTap()
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
                .padding(.horizontal, Spacing.md)
                .padding(.top, isFullscreen ? Spacing.lg : Spacing.sm)

                Spacer()
            }

            // Center controls - skip back / play / skip forward
            HStack(spacing: Spacing.xxl) {
                // Skip back 10s
                Button {
                    onSeekRelative(-10)
                    scheduleHideControls()
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: isFullscreen ? 34 : 28))
                        .foregroundStyle(.white.opacity(0.9))
                }

                // Play/Pause
                Button {
                    isPlaying.toggle()
                    scheduleHideControls()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isFullscreen ? 54 : 44))
                        .foregroundStyle(.white)
                }

                // Skip forward 10s
                Button {
                    onSeekRelative(10)
                    scheduleHideControls()
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: isFullscreen ? 34 : 28))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            // Bottom progress bar
            VStack {
                Spacer()

                HStack(spacing: Spacing.sm) {
                    Text(formatTime(currentTime))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.25))
                                .frame(height: isScrubbing ? 5 : 3)

                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorTokens.gold)
                                .frame(
                                    width: geo.size.width * (duration > 0 ? currentTime / duration : 0),
                                    height: isScrubbing ? 5 : 3
                                )

                            // Scrub handle
                            if isScrubbing {
                                Circle()
                                    .fill(ColorTokens.gold)
                                    .frame(width: 14, height: 14)
                                    .offset(x: geo.size.width * (duration > 0 ? currentTime / duration : 0) - 7)
                            }
                        }
                        .frame(height: 20)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isScrubbing = true
                                    let fraction = max(0, min(1, value.location.x / geo.size.width))
                                    onSeek(fraction)
                                }
                                .onEnded { _ in
                                    isScrubbing = false
                                    scheduleHideControls()
                                }
                        )
                    }
                    .frame(height: 20)

                    Text(formatTime(duration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)

                    // Fullscreen toggle button
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
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, isFullscreen ? Spacing.lg : Spacing.sm)
            }
        }
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
