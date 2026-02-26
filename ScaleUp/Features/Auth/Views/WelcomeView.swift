import SwiftUI

// MARK: - Welcome View

/// Full-bleed dark welcome screen with logo, tagline, and auth CTAs.
struct WelcomeView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    // MARK: - Navigation Callbacks

    let onLogin: () -> Void
    let onRegister: () -> Void
    let onPhoneOTP: () -> Void

    // MARK: - State

    @State private var isGoogleLoading = false
    @State private var errorMessage: String?
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: Logo & Tagline
                heroSection

                Spacer()

                // MARK: CTAs
                ctaSection

                Spacer()
                    .frame(height: Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(Animations.smooth) {
                logoScale = 1.0
                contentOpacity = 1.0
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(ColorTokens.heroGradient)
                .scaleEffect(logoScale)

            Text("ScaleUp")
                .font(Typography.displayLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Learn with purpose. Grow with proof.")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .opacity(contentOpacity)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: Spacing.sm) {
            // Error banner
            if let errorMessage {
                errorBanner(errorMessage)
            }

            // Get Started
            PrimaryButton(title: "Get Started") {
                onRegister()
            }

            // Sign In
            SecondaryButton(title: "Sign In") {
                onLogin()
            }

            // Continue with Google
            socialButton(
                title: "Continue with Google",
                icon: "g.circle.fill",
                isLoading: isGoogleLoading
            ) {
                Task { await handleGoogleSignIn() }
            }

            // Continue with Phone
            socialButton(
                title: "Continue with Phone",
                icon: "phone.fill",
                isLoading: false
            ) {
                onPhoneOTP()
            }
        }
        .opacity(contentOpacity)
    }

    // MARK: - Social Button

    private func socialButton(
        title: String,
        icon: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(ColorTokens.textPrimaryDark)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                }
                Text(title)
                    .font(Typography.bodyBold)
            }
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.error)
            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.error)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Google Sign In

    private func handleGoogleSignIn() async {
        isGoogleLoading = true
        errorMessage = nil
        defer { isGoogleLoading = false }

        do {
            let googleManager = GoogleSignInManager()
            let idToken = try await googleManager.signIn()

            let response = try await dependencies.authService.googleAuth(idToken: idToken)

            dependencies.authManager.handleAuthSuccess(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user
            )

            appState.currentUser = response.user
            dependencies.hapticManager.success()

            if response.user.onboardingComplete {
                appState.authStatus = .authenticated
            } else {
                appState.authStatus = .onboarding
            }
        } catch {
            errorMessage = error.localizedDescription
            dependencies.hapticManager.error()
        }
    }
}
