import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState

    @State private var showLogin = false
    @State private var showRegister = false
    @State private var showPhoneAuth = false

    @State private var appeared = false
    @State private var glowPhase: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                // Animated ambient glow
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.3)
                    let radius = 250 + Foundation.sin(glowPhase) * 30

                    context.addFilter(.blur(radius: 100))
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 1.5
                        )),
                        with: .color(ColorTokens.gold.opacity(0.06 + Foundation.sin(glowPhase) * 0.02))
                    )
                }
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                        glowPhase = .pi * 2
                    }
                }

                VStack(spacing: 0) {
                    Spacer()

                    // Logo + Tagline
                    VStack(spacing: Spacing.xl) {
                        ScaleUpLogo(fontSize: 42)
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.8)

                        VStack(spacing: Spacing.md) {
                            Text("Learn with purpose.\nAchieve with proof.")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)

                            Text("AI-powered learning that adapts to your goals,\nmeasures your mastery, and gets you there faster.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(ColorTokens.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 15)
                        }
                    }

                    Spacer().frame(height: 60)

                    // Feature pills
                    HStack(spacing: 10) {
                        featurePill(icon: "target", text: "Goal-Driven")
                        featurePill(icon: "brain.head.profile", text: "AI Quizzes")
                        featurePill(icon: "chart.line.uptrend.xyaxis", text: "Track Mastery")
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                    Spacer()

                    // CTA buttons
                    VStack(spacing: 12) {
                        Button {
                            Haptics.medium()
                            showRegister = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("Get Started")
                                    .font(.system(size: 17, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(ColorTokens.buttonPrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(ColorTokens.goldGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: ColorTokens.gold.opacity(0.3), radius: 12, y: 4)
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                        Button {
                            Haptics.selection()
                            showPhoneAuth = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Sign in with Phone OTP")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(ColorTokens.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(ColorTokens.gold.opacity(0.4), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)

                        Button {
                            Haptics.selection()
                            showLogin = true
                        } label: {
                            Text("Already have an account? **Sign In with Email**")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, 50)
                }
            }
            .navigationDestination(isPresented: $showLogin) {
                LoginView()
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
            .navigationDestination(isPresented: $showPhoneAuth) {
                PhoneAuthView()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Feature Pill

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(ColorTokens.surface)
                .overlay(
                    Capsule()
                        .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
