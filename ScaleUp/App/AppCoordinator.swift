import SwiftUI

struct AppCoordinator: View {
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var dependencies

    var body: some View {
        Group {
            switch appState.authStatus {
            case .loading:
                SplashView()
            case .unauthenticated:
                AuthCoordinator()
            case .onboarding:
                OnboardingContainerView()
            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeOut(duration: 0.3), value: appState.authStatus)
        .task {
            await checkAuthOnLaunch()
        }
    }

    private func checkAuthOnLaunch() async {
        let authManager = dependencies.authManager

        // Allow splash animation to play
        try? await Task.sleep(for: .seconds(2.0))

        await authManager.checkAuthOnLaunch()

        if let user = authManager.currentUser {
            appState.currentUser = user
            if user.onboardingComplete {
                appState.authStatus = .authenticated
            } else {
                appState.authStatus = .onboarding
            }
        } else {
            appState.authStatus = .unauthenticated
        }
    }
}

// MARK: - Splash View

private struct SplashView: View {
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -30
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 12
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 8
    @State private var glowRadius: CGFloat = 0
    @State private var glowOpacity: Double = 0
    @State private var particleOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            // Radial glow behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ColorTokens.primary.opacity(0.3),
                            ColorTokens.primary.opacity(0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .opacity(glowOpacity)
                .blur(radius: glowRadius)

            VStack(spacing: 0) {
                Spacer()

                // Logo with ring
                ZStack {
                    // Outer gradient ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    ColorTokens.primary,
                                    ColorTokens.primaryLight,
                                    ColorTokens.error.opacity(0.7),
                                    ColorTokens.primary
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Logo icon circle
                    ZStack {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, ColorTokens.primaryLight],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [ColorTokens.primary, ColorTokens.primaryDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .clipShape(Circle())
                    .shadow(color: ColorTokens.primary.opacity(0.5), radius: 20, y: 4)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .rotationEffect(.degrees(logoRotation))

                // App name
                Text("ScaleUp")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, ColorTokens.primaryLight.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                    .padding(.top, Spacing.lg)

                // Tagline
                Text("Level Up Your Knowledge")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .opacity(taglineOpacity)
                    .offset(y: taglineOffset)
                    .padding(.top, Spacing.xs)

                Spacer()

                // Floating dots
                HStack(spacing: Spacing.lg) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(ColorTokens.primary.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .opacity(particleOpacity)
                .padding(.bottom, Spacing.xxl + Spacing.md)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        // Phase 1: Logo spring in
        withAnimation(.spring(duration: 0.7, bounce: 0.35)) {
            logoScale = 1.0
            logoOpacity = 1.0
            logoRotation = 0
        }

        // Phase 2: Ring expands
        withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.2)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }

        // Phase 3: Text slides up
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            textOpacity = 1.0
            textOffset = 0
        }

        // Phase 4: Tagline fades in
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            taglineOpacity = 1.0
            taglineOffset = 0
        }

        // Phase 5: Glow + dots
        withAnimation(.easeInOut(duration: 0.8).delay(0.7)) {
            glowRadius = 30
            glowOpacity = 0.6
            particleOpacity = 1.0
        }

        // Phase 6: Gentle glow pulse loop
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(1.2)) {
            glowRadius = 40
            glowOpacity = 0.35
        }
    }
}
