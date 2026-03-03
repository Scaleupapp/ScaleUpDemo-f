import SwiftUI

struct ProfileStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Spacer().frame(height: Spacing.lg)

                // Avatar placeholder
                ZStack {
                    Circle()
                        .fill(ColorTokens.surfaceElevated)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 2)
                        )

                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)

                // Heading
                VStack(spacing: Spacing.sm) {
                    Text("Let's set up your profile")
                        .font(Typography.displayMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Confirm your name to get started")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Form fields
                VStack(spacing: Spacing.md) {
                    ScaleUpTextField(
                        label: "First Name",
                        icon: "person.fill",
                        text: $viewModel.firstName,
                        autocapitalization: .words
                    )

                    ScaleUpTextField(
                        label: "Last Name (optional)",
                        icon: "person",
                        text: $viewModel.lastName,
                        autocapitalization: .words
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}
