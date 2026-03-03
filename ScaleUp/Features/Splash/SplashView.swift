import SwiftUI

struct SplashView: View {
    @Environment(AppState.self) private var appState

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.92
    @State private var taglineOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            // Soft ambient glow behind logo
            RadialGradient(
                colors: [ColorTokens.gold.opacity(0.07), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 220
            )
            .ignoresSafeArea()
            .opacity(glowOpacity)

            VStack(spacing: Spacing.lg) {
                Spacer()

                // Logo
                ScaleUpLogo(fontSize: 44)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                // Tagline
                Text("Learn with purpose. Achieve your goals.")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .opacity(taglineOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            // Logo: fade in + subtle scale up
            withAnimation(.easeOut(duration: 0.7)) {
                logoOpacity = 1
                logoScale = 1
            }

            // Glow
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                glowOpacity = 1
            }

            // Tagline
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                taglineOpacity = 1
            }

            // Auth check → transition
            Task {
                try? await Task.sleep(for: .seconds(2))
                await appState.checkAuth()
                if appState.launchState == .splash {
                    appState.launchState = .welcome
                }
            }
        }
    }
}
