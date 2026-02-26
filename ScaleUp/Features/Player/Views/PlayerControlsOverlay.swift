import SwiftUI

// MARK: - Player Controls Overlay

/// Semi-transparent overlay displayed on top of the video player.
/// Contains play/pause, skip ±10s, progress slider, time labels,
/// playback speed, mute/unmute, and a close button.
/// Auto-hides after 3 seconds of no interaction.
struct PlayerControlsOverlay: View {

    let isPlaying: Bool
    let currentTime: Double
    let duration: Double
    let isVisible: Bool
    let isMuted: Bool
    let isFullscreen: Bool
    let playbackSpeedLabel: String

    var onPlayPause: () -> Void
    var onSeek: (Double) -> Void
    var onClose: () -> Void
    var onTap: () -> Void
    var onSkipForward: () -> Void
    var onSkipBackward: () -> Void
    var onToggleMute: () -> Void
    var onSelectSpeed: (Float) -> Void
    var onToggleFullscreen: () -> Void

    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    var body: some View {
        ZStack {
            // Tappable area to toggle controls visibility
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }

            if isVisible {
                controlsContent
                    .transition(.opacity)
            }
        }
        .animation(Animations.standard, value: isVisible)
    }

    // MARK: - Controls Content

    private var controlsContent: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.45)
                .allowsHitTesting(false)

            // Top bar: Speed (left) + Close (right)
            VStack {
                HStack {
                    speedButton
                    Spacer()
                    closeButton
                }
                .padding(.top, Spacing.sm)
                .padding(.horizontal, Spacing.sm)

                Spacer()
            }

            // Center: Skip backward, Play/Pause, Skip forward
            centerControls

            // Bottom: Progress bar, time labels, mute
            VStack {
                Spacer()
                bottomBar
            }
        }
    }

    // MARK: - Speed Button

    private var speedButton: some View {
        Menu {
            ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                Button {
                    onSelectSpeed(speed)
                } label: {
                    Text(speed == 1.0 ? "Normal" : "\(String(format: "%g", speed))x")
                }
            }
        } label: {
            Text(playbackSpeedLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Center Controls (Skip Back, Play/Pause, Skip Forward)

    private var centerControls: some View {
        HStack(spacing: Spacing.xxxl) {
            // Skip backward 10s
            Button(action: onSkipBackward) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 64, height: 64)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .offset(x: isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)

            // Skip forward 10s
            Button(action: onSkipForward) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Bar (Slider + Times + Mute)

    private var bottomBar: some View {
        VStack(spacing: Spacing.xs) {
            // Progress slider
            Slider(
                value: Binding(
                    get: { isSeeking ? seekValue : (duration > 0 ? currentTime : 0) },
                    set: { newValue in
                        isSeeking = true
                        seekValue = newValue
                    }
                ),
                in: 0...max(duration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        onSeek(seekValue)
                        isSeeking = false
                    }
                }
            )
            .tint(ColorTokens.primary)

            // Time labels + mute + fullscreen
            HStack(spacing: Spacing.sm) {
                Text(formatTime(isSeeking ? seekValue : currentTime))
                    .font(Typography.mono)
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                // Mute / Unmute
                Button(action: onToggleMute) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Text(formatTime(duration))
                    .font(Typography.mono)
                    .foregroundStyle(.white.opacity(0.6))

                // Fullscreen toggle
                Button(action: onToggleFullscreen) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Time Formatting

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
