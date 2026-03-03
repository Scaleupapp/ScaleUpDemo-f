import SwiftUI

struct PreferencesStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Heading
                VStack(spacing: Spacing.sm) {
                    Text("How do you like to learn?")
                        .font(Typography.displayMedium)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("We'll prioritize content in your preferred format")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.top, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Style Cards
                VStack(spacing: Spacing.sm) {
                    ForEach(LearningStyle.allCases) { style in
                        styleCard(style)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    // MARK: - Style Card

    private func styleCard(_ style: LearningStyle) -> some View {
        let isSelected = viewModel.learningStyle == style

        return Button {
            Haptics.light()
            withAnimation(Motion.springSmooth) {
                viewModel.learningStyle = style
            }
        } label: {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? ColorTokens.gold.opacity(0.15) : ColorTokens.surface)
                        .frame(width: 48, height: 48)

                    Image(systemName: style.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? ColorTokens.gold : ColorTokens.textSecondary)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Text(style.displayName)
                            .font(Typography.bodyBold)
                            .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                        if style == .mix {
                            Text("Recommended")
                                .font(Typography.micro)
                                .foregroundStyle(ColorTokens.buttonPrimaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ColorTokens.gold)
                                .clipShape(Capsule())
                        }
                    }

                    Text(style.description)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .padding(Spacing.md)
            .background(isSelected ? ColorTokens.gold.opacity(0.06) : ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? ColorTokens.gold : ColorTokens.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
