import SwiftUI

// MARK: - Phone OTP View

/// Two-phase view: phone number input, then OTP verification.
/// If the user is new after verification, collects name before proceeding.
struct PhoneOTPView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var viewModel: PhoneOTPViewModel?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView {
                if let vm = viewModel {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        // MARK: Header
                        headerSection(vm)

                        // MARK: Error Banner
                        if let errorMessage = vm.errorMessage {
                            errorBanner(errorMessage)
                        }

                        // MARK: Content
                        switch vm.step {
                        case .phone:
                            phoneInputSection(vm)
                        case .otp:
                            if vm.showNameInput {
                                nameInputSection(vm)
                            } else {
                                otpInputSection(vm)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ColorTokens.backgroundDark, for: .navigationBar)
        .loadingOverlay(isPresented: viewModel?.isLoading ?? false)
        .onAppear {
            if viewModel == nil {
                viewModel = PhoneOTPViewModel(
                    authService: dependencies.authService,
                    authManager: dependencies.authManager,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
    }

    // MARK: - Header

    private func headerSection(_ vm: PhoneOTPViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(headerTitle(vm))
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(headerSubtitle(vm))
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    private func headerTitle(_ vm: PhoneOTPViewModel) -> String {
        switch vm.step {
        case .phone:
            return "Phone Sign In"
        case .otp:
            return vm.showNameInput ? "Almost There" : "Verify OTP"
        }
    }

    private func headerSubtitle(_ vm: PhoneOTPViewModel) -> String {
        switch vm.step {
        case .phone:
            return "We'll send you a one-time code to verify your number"
        case .otp:
            if vm.showNameInput {
                return "Tell us your name to complete sign up"
            }
            let maskedPhone = maskPhone(vm.phone)
            return "Enter the 6-digit code sent to \(maskedPhone)"
        }
    }

    // MARK: - Phone Input

    private func phoneInputSection(_ vm: PhoneOTPViewModel) -> some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.sm) {
                // Country code prefix
                Text("+91")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .frame(width: 52, height: 52)
                    .background(ColorTokens.surfaceDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
                    )

                TextFieldStyled(
                    label: "",
                    placeholder: "Enter phone number",
                    text: Binding(
                        get: { vm.phone },
                        set: { vm.phone = $0 }
                    ),
                    icon: "phone.fill",
                    errorMessage: vm.phoneError,
                    keyboardType: .phonePad,
                    textContentType: .telephoneNumber
                )
            }

            PrimaryButton(
                title: "Send OTP",
                isLoading: vm.isLoading
            ) {
                Task { await vm.sendOTP() }
            }
        }
    }

    // MARK: - OTP Input

    private func otpInputSection(_ vm: PhoneOTPViewModel) -> some View {
        VStack(spacing: Spacing.lg) {
            OTPInputView(
                otp: Binding(
                    get: { vm.otp },
                    set: { vm.otp = $0 }
                ),
                errorMessage: vm.otpError
            )

            // Countdown / Resend
            HStack {
                Spacer()
                if vm.countdownSeconds > 0 {
                    Text("Resend in \(vm.countdownSeconds)s")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                } else {
                    Button {
                        Task { await vm.resendOTP() }
                    } label: {
                        Text("Resend OTP")
                            .font(Typography.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(ColorTokens.primary)
                    }
                }
                Spacer()
            }

            PrimaryButton(
                title: "Verify",
                isLoading: vm.isLoading,
                isDisabled: vm.otp.count != 6
            ) {
                Task { await vm.verifyOTP(appState: appState) }
            }
        }
    }

    // MARK: - Name Input (New User)

    private func nameInputSection(_ vm: PhoneOTPViewModel) -> some View {
        VStack(spacing: Spacing.lg) {
            TextFieldStyled(
                label: "First Name",
                placeholder: "Enter your first name",
                text: Binding(
                    get: { vm.firstName },
                    set: { vm.firstName = $0 }
                ),
                icon: "person.fill",
                errorMessage: vm.firstNameError,
                textContentType: .givenName
            )

            TextFieldStyled(
                label: "Last Name (Optional)",
                placeholder: "Enter your last name",
                text: Binding(
                    get: { vm.lastName },
                    set: { vm.lastName = $0 }
                ),
                icon: "person.fill",
                textContentType: .familyName
            )

            PrimaryButton(
                title: "Continue",
                isLoading: vm.isLoading
            ) {
                Task { await vm.verifyOTP(appState: appState) }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.error)
            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.error)
            Spacer()
        }
        .padding(Spacing.md)
        .background(ColorTokens.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Helpers

    private func maskPhone(_ phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 4 else { return phone }
        let last4 = digits.suffix(4)
        let masked = String(repeating: "*", count: max(0, digits.count - 4))
        return "+91 \(masked)\(last4)"
    }
}
