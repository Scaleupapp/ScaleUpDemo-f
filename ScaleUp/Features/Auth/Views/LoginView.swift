import SwiftUI

// MARK: - Login View

/// Dark-themed login form with email, password, and forgot-password link.
struct LoginView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    // MARK: - Navigation

    let onForgotPassword: () -> Void

    // MARK: - State

    @State private var viewModel: LoginViewModel?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // MARK: Header
                    headerSection

                    if let vm = viewModel {
                        // MARK: Error Banner
                        if let errorMessage = vm.errorMessage {
                            errorBanner(errorMessage)
                        }

                        // MARK: Form
                        formSection(vm)

                        // MARK: Forgot Password
                        forgotPasswordLink

                        // MARK: Submit
                        PrimaryButton(
                            title: "Sign In",
                            isLoading: vm.isLoading
                        ) {
                            Task { await vm.login(appState: appState) }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ColorTokens.backgroundDark, for: .navigationBar)
        .loadingOverlay(isPresented: viewModel?.isLoading ?? false)
        .onAppear {
            if viewModel == nil {
                viewModel = LoginViewModel(
                    authService: dependencies.authService,
                    authManager: dependencies.authManager,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Welcome Back")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Sign in to continue your learning journey")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Form

    @ViewBuilder
    private func formSection(_ vm: LoginViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            TextFieldStyled(
                label: "Email",
                placeholder: "Enter your email",
                text: Binding(
                    get: { vm.email },
                    set: { vm.email = $0 }
                ),
                icon: "envelope.fill",
                errorMessage: vm.emailError,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never
            )

            TextFieldStyled(
                label: "Password",
                placeholder: "Enter your password",
                text: Binding(
                    get: { vm.password },
                    set: { vm.password = $0 }
                ),
                icon: "lock.fill",
                isSecure: true,
                errorMessage: vm.passwordError,
                textContentType: .password
            )
        }
    }

    // MARK: - Forgot Password Link

    private var forgotPasswordLink: some View {
        HStack {
            Spacer()
            Button {
                onForgotPassword()
            } label: {
                Text("Forgot Password?")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.primary)
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
}
