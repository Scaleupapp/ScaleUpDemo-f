import SwiftUI
import AVKit

struct SplashView: View {
    @Environment(AppState.self) private var appState

    @State private var taglineOpacity: Double = 0
    @State private var videoFinished = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo animation video
                SplashVideoPlayer(onFinished: {
                    videoFinished = true
                    withAnimation(.easeOut(duration: 0.5)) {
                        taglineOpacity = 1
                    }
                })
                .frame(width: 260, height: 260)

                // Tagline — tight to video, dark navy matching logo
                Text("Learn with purpose. Achieve your goals.")
                    .font(Typography.caption)
                    .foregroundStyle(Color(hex: 0x17354A))
                    .opacity(taglineOpacity)
                    .padding(.top, -70)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            // Auth check → transition after video + brief pause
            Task {
                try? await Task.sleep(for: .seconds(2.8))
                await appState.checkAuth()
                if appState.launchState == .splash {
                    appState.launchState = .welcome
                }
            }
        }
    }
}

// MARK: - Video Player

private struct SplashVideoPlayer: UIViewRepresentable {
    let onFinished: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = PlayerContainerView()
        view.backgroundColor = .white

        guard let url = Bundle.main.url(forResource: "splash_animation", withExtension: "mp4") else {
            return view
        }

        let player = AVPlayer(url: url)
        player.isMuted = true

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.white.cgColor
        view.playerLayer = playerLayer
        view.layer.addSublayer(playerLayer)

        // Observe when video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            onFinished()
        }

        player.play()

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Container that auto-sizes the player layer

private final class PlayerContainerView: UIView {
    var playerLayer: AVPlayerLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
