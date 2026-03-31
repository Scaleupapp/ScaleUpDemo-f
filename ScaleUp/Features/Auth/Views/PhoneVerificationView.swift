import SwiftUI

/// Post-registration phone verification screen.
/// Shown after email registration, before onboarding.
struct PhoneVerificationView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()

    private var userName: String {
        appState.currentUser?.firstName ?? ""
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "phone.badge.checkmark")
                            .font(.system(size: 40))
                            .foregroundStyle(ColorTokens.gold)
                            .padding(.bottom, Spacing.sm)

                        Text(viewModel.otpSent ? "Verify OTP" : "Add your phone number")
                            .font(Typography.displayMedium)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text(viewModel.otpSent
                             ? "Enter the 6-digit code sent to +91\(viewModel.phone)"
                             : "We'll verify it with a one-time code. This helps secure your account.")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.xl)

                    if viewModel.otpSent {
                        otpSection
                    } else {
                        phoneSection
                    }

                    // Skip
                    Button {
                        skipToOnboarding()
                    } label: {
                        Text("Skip for now")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .padding(.top, Spacing.sm)

                    Spacer().frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.otpSent)
    }

    // MARK: - Phone Entry

    private var phoneSection: some View {
        VStack(spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Phone Number")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)

                HStack(spacing: Spacing.sm) {
                    Text("+91")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 14)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                    TextField("", text: $viewModel.phone)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .keyboardType(.phonePad)
                        .tint(ColorTokens.gold)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 14)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .stroke(ColorTokens.border, lineWidth: 1)
                        )
                }
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            PrimaryButton(
                title: "Send OTP",
                icon: "arrow.right",
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isPhoneValid
            ) {
                Task { await viewModel.sendOTP() }
            }
        }
    }

    // MARK: - OTP Entry

    private var otpSection: some View {
        VStack(spacing: Spacing.lg) {
            OTPInputView(code: $viewModel.otp)

            if viewModel.otpCooldown > 0 {
                Text("Resend in \(viewModel.otpCooldown)s")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            } else {
                Button("Resend Code") {
                    Task { await viewModel.sendOTP() }
                }
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.gold)
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            PrimaryButton(
                title: "Verify & Continue",
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isOTPValid
            ) {
                // Pass firstName so backend doesn't reject "new user" phone verification
                viewModel.firstName = userName
                Task {
                    if let authData = await viewModel.verifyOTP() {
                        // Phone verified — save new tokens and go to onboarding
                        await KeychainManager.shared.saveTokens(
                            access: authData.accessToken,
                            refresh: authData.refreshToken
                        )
                        appState.currentUser = authData.user
                        let step = max(1, authData.user.onboardingStep ?? 1)
                        appState.launchState = .onboarding(step: step)
                    }
                }
            }

            // Back to phone entry
            Button {
                viewModel.otpSent = false
                viewModel.otp = ""
            } label: {
                Text("Change phone number")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    // MARK: - Skip

    private func skipToOnboarding() {
        let step = max(1, appState.currentUser?.onboardingStep ?? 1)
        appState.launchState = .onboarding(step: step)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(ColorTokens.error)
            Text(message)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.error)
            Spacer()
        }
        .padding(Spacing.sm)
        .background(ColorTokens.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}
