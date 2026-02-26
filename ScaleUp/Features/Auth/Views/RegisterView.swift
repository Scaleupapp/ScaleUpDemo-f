import SwiftUI

// MARK: - Register View

/// Registration form with first name, last name, email, and password.
struct RegisterView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    // MARK: - Navigation

    let onSignIn: () -> Void

    // MARK: - State

    @State private var viewModel: RegisterViewModel?

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

                        // MARK: Submit
                        PrimaryButton(
                            title: "Create Account",
                            isLoading: vm.isLoading
                        ) {
                            Task { await vm.register(appState: appState) }
                        }

                        // MARK: Sign In Link
                        signInLink
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ColorTokens.backgroundDark, for: .navigationBar)
        .loadingOverlay(isPresented: viewModel?.isLoading ?? false)
        .onAppear {
            if viewModel == nil {
                viewModel = RegisterViewModel(
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
            Text("Create Account")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Start your learning journey today")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Form

    @ViewBuilder
    private func formSection(_ vm: RegisterViewModel) -> some View {
        VStack(spacing: Spacing.md) {
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
                placeholder: "Create a password (min 8 characters)",
                text: Binding(
                    get: { vm.password },
                    set: { vm.password = $0 }
                ),
                icon: "lock.fill",
                isSecure: true,
                errorMessage: vm.passwordError,
                textContentType: .newPassword
            )
        }
    }

    // MARK: - Sign In Link

    private var signInLink: some View {
        HStack {
            Spacer()
            Text("Already have an account?")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
            Button {
                onSignIn()
            } label: {
                Text("Sign In")
                    .font(Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.primary)
            }
            Spacer()
        }
        .padding(.top, Spacing.sm)
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
