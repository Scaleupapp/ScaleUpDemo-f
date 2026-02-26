import SwiftUI

struct PreferencesView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // MARK: - Learning Style Cards
                learningStyleSection

                // MARK: - Weekly Hours Confirmation
                weeklyHoursSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Learning Style Section

    private var learningStyleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Preferred Learning Style")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.md),
                    GridItem(.flexible(), spacing: Spacing.md)
                ],
                spacing: Spacing.md
            ) {
                ForEach(LearningStyleItem.allItems, id: \.style) { item in
                    learningStyleCard(item: item)
                }
            }
        }
    }

    private func learningStyleCard(item: LearningStyleItem) -> some View {
        let isSelected = viewModel.selectedLearningStyle == item.style

        return Button {
            withAnimation(Animations.quick) {
                viewModel.selectedLearningStyle = item.style
            }
        } label: {
            VStack(spacing: Spacing.md) {
                Image(systemName: item.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isSelected ? ColorTokens.primary : ColorTokens.textSecondaryDark)
                    .frame(height: 40)

                VStack(spacing: Spacing.xs) {
                    Text(item.title)
                        .font(Typography.bodyBold)
                        .foregroundStyle(isSelected ? ColorTokens.textPrimaryDark : ColorTokens.textSecondaryDark)

                    Text(item.subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.sm)
            .background(
                isSelected
                    ? ColorTokens.primary.opacity(0.08)
                    : ColorTokens.surfaceDark
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isSelected ? ColorTokens.primary : ColorTokens.surfaceElevatedDark,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Weekly Hours Section

    private var weeklyHoursSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Weekly Commitment")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()

                Text("\(Int(viewModel.weeklyCommitHours)) hrs/week")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.primary)
            }

            Text("Adjust if you'd like to change from your earlier selection")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Slider(
                value: $viewModel.weeklyCommitHours,
                in: 1...40,
                step: 1
            )
            .tint(ColorTokens.primary)

            HStack {
                Text("1 hr")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                Spacer()
                Text("40 hrs")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }

            // Commitment summary card
            commitmentSummary
        }
    }

    // MARK: - Commitment Summary

    private var commitmentSummary: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "clock.fill")
                .font(.system(size: 20))
                .foregroundStyle(ColorTokens.primary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Daily Goal")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                let dailyMinutes = Int((viewModel.weeklyCommitHours / 7.0) * 60)
                if dailyMinutes >= 60 {
                    let hours = dailyMinutes / 60
                    let minutes = dailyMinutes % 60
                    if minutes > 0 {
                        Text("\(hours)h \(minutes)m per day")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                    } else {
                        Text("\(hours)h per day")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                    }
                } else {
                    Text("\(dailyMinutes)m per day")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                }
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
        )
    }
}

// MARK: - Learning Style Item

private struct LearningStyleItem {
    let style: LearningStyle
    let icon: String
    let title: String
    let subtitle: String

    static let allItems: [LearningStyleItem] = [
        LearningStyleItem(
            style: .videos,
            icon: "play.rectangle.fill",
            title: "Video",
            subtitle: "Watch and learn visually"
        ),
        LearningStyleItem(
            style: .articles,
            icon: "doc.richtext",
            title: "Articles",
            subtitle: "Read in-depth content"
        ),
        LearningStyleItem(
            style: .interactive,
            icon: "hand.tap.fill",
            title: "Interactive",
            subtitle: "Learn by doing"
        ),
        LearningStyleItem(
            style: .mix,
            icon: "square.grid.2x2.fill",
            title: "Mix of All",
            subtitle: "A bit of everything"
        )
    ]
}

// MARK: - Preview

#Preview {
    ZStack {
        ColorTokens.backgroundDark.ignoresSafeArea()
        PreferencesView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
