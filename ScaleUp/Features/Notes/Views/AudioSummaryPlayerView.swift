import SwiftUI
import AVFoundation

struct AudioSummaryPlayerView: View {
    let contentId: String

    @State private var status: AudioState = .idle
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?

    private let notesService = NotesService()

    enum AudioState {
        case idle, generating, ready, error
    }

    var body: some View {
        Group {
            switch status {
            case .idle:
                Button {
                    Task { await generateAndLoad() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "headphones")
                        Text("Listen to Summary")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.cyan.opacity(0.1))
                    .clipShape(Capsule())
                }

            case .generating:
                HStack(spacing: 6) {
                    ProgressView().tint(.cyan).scaleEffect(0.7)
                    Text("Generating audio...")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

            case .ready:
                HStack(spacing: 10) {
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.cyan)
                    }

                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.cyan)
                                    .frame(width: geo.size.width * progress, height: 3)
                            }
                        }
                        .frame(height: 3)

                        HStack {
                            Text(formatTime(duration * progress))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(ColorTokens.textTertiary)
                            Spacer()
                            Text(formatTime(duration))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            case .error:
                Text("Audio unavailable")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private func generateAndLoad() async {
        status = .generating

        // Try to get existing audio first
        if let audio = try? await notesService.getAudioSummary(contentId: contentId) {
            await setupPlayer(url: audio.url)
            return
        }

        // Generate
        try? await notesService.generateAudioSummary(contentId: contentId)

        // Poll for completion
        for _ in 0..<30 {
            try? await Task.sleep(for: .seconds(2))
            if let statusResp = try? await notesService.getAudioStatus(contentId: contentId) {
                if statusResp.status == "ready" {
                    if let audio = try? await notesService.getAudioSummary(contentId: contentId) {
                        await setupPlayer(url: audio.url)
                        return
                    }
                } else if statusResp.status == "failed" {
                    status = .error
                    return
                }
            }
        }
        status = .error
    }

    @MainActor
    private func setupPlayer(url: String) {
        guard let audioURL = URL(string: url) else { status = .error; return }
        let playerItem = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: playerItem)
        AnalyticsService.shared.track(.audioSummaryPlayed(contentId: contentId))

        // Observe duration
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let item = player?.currentItem else { return }
            let dur = item.duration.seconds
            if dur.isFinite && dur > 0 {
                duration = dur
                progress = time.seconds / dur
            }
        }

        // Observe end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            isPlaying = false
            progress = 0
            player?.seek(to: .zero)
        }

        status = .ready
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
