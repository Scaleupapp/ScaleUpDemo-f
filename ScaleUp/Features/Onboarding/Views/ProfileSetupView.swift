import SwiftUI

struct ProfileSetupView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // MARK: - Avatar Placeholder
                avatarPlaceholder
                    .padding(.top, Spacing.xl)

                // MARK: - Name Fields
                VStack(spacing: Spacing.md) {
                    TextFieldStyled(
                        label: "First Name",
                        placeholder: "Enter your first name",
                        text: $viewModel.firstName,
                        icon: "person.fill",
                        textContentType: .givenName,
                        autocapitalization: .words
                    )

                    TextFieldStyled(
                        label: "Last Name",
                        placeholder: "Enter your last name",
                        text: $viewModel.lastName,
                        icon: "person.fill",
                        textContentType: .familyName,
                        autocapitalization: .words
                    )
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Avatar Placeholder

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.surfaceElevatedDark)
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(
                            ColorTokens.primary.opacity(0.3),
                            lineWidth: 2
                        )
                )

            VStack(spacing: Spacing.xs) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.textTertiaryDark)

                Text("Add Photo")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            // Photo picker will be implemented later
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ColorTokens.backgroundDark.ignoresSafeArea()
        ProfileSetupView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
