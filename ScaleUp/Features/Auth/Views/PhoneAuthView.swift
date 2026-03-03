import SwiftUI

struct PhoneAuthView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Text(viewModel.otpSent ? "Enter OTP" : "Phone Sign In")
                            .font(Typography.displayMedium)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text(viewModel.otpSent
                             ? "We sent a 6-digit code to +91\(viewModel.phone)"
                             : "We'll send you a one-time code")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.xl)

                    if viewModel.otpSent {
                        otpEntryView
                    } else {
                        phoneEntryView
                    }

                    Spacer().frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if viewModel.otpSent {
                        viewModel.otpSent = false
                        viewModel.otp = ""
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Circle())
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.otpSent)
    }

    // MARK: - Phone Entry

    private var phoneEntryView: some View {
        VStack(spacing: Spacing.lg) {
            // Phone input with country prefix
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Phone Number")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)

                HStack(spacing: Spacing.sm) {
                    // Country code
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

    private var otpEntryView: some View {
        VStack(spacing: Spacing.lg) {
            // OTP boxes
            OTPInputView(code: $viewModel.otp)

            // Resend
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
                title: "Verify",
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isOTPValid
            ) {
                Task {
                    if let authData = await viewModel.verifyOTP() {
                        await appState.handleAuthSuccess(authData)
                    }
                }
            }
        }
    }

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

// MARK: - OTP Input View

struct OTPInputView: View {
    @Binding var code: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Hidden text field for actual input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .onChange(of: code) {
                    if code.count > 6 {
                        code = String(code.prefix(6))
                    }
                }

            // Visual boxes
            HStack(spacing: Spacing.sm) {
                ForEach(0..<6, id: \.self) { index in
                    let char = index < code.count
                        ? String(code[code.index(code.startIndex, offsetBy: index)])
                        : ""

                    Text(char)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .frame(width: 48, height: 56)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .stroke(
                                    index == code.count
                                        ? ColorTokens.gold
                                        : index < code.count
                                            ? ColorTokens.gold.opacity(0.3)
                                            : ColorTokens.border,
                                    lineWidth: index == code.count ? 2 : 1
                                )
                        )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            isFocused = true
        }
    }
}
