import SwiftUI

struct InterestsView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // MARK: - Selection Count
                selectionCount

                // MARK: - Suggested Topics
                suggestedTopicsSection

                // MARK: - Selected Summary
                if !allSelectedTags.isEmpty {
                    selectedSummary
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - All Selected Tags (combined)

    private var allSelectedTags: [String] {
        Array(Set(viewModel.selectedSkills + viewModel.selectedTopics))
    }

    // MARK: - Selection Count

    private var selectionCount: some View {
        HStack(spacing: Spacing.sm) {
            let count = allSelectedTags.count
            let minimum = 3

            Image(systemName: count >= minimum ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(count >= minimum ? ColorTokens.success : ColorTokens.warning)

            Text("\(count) selected")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            if count < minimum {
                Text("(minimum \(minimum))")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
        }
    }

    // MARK: - Suggested Topics Section

    private var suggestedTopicsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Suggested Topics")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Based on your objective, we think you'll enjoy these")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)

            TagCloud(
                availableTags: viewModel.suggestedTopics,
                selectedTags: $viewModel.selectedTopics,
                allowCustom: true
            )
        }
    }

    // MARK: - Selected Summary

    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Your Interests")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()

                Button {
                    withAnimation(Animations.standard) {
                        viewModel.selectedSkills.removeAll()
                        viewModel.selectedTopics.removeAll()
                    }
                } label: {
                    Text("Clear All")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.error)
                }
            }

            FlowLayout(spacing: Spacing.sm) {
                ForEach(allSelectedTags, id: \.self) { tag in
                    selectedTagChip(tag: tag)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
        )
    }

    private func selectedTagChip(tag: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(tag)
                .font(Typography.bodySmall)
                .foregroundStyle(.white)

            Button {
                withAnimation(Animations.quick) {
                    viewModel.selectedTopics.removeAll { $0 == tag }
                    viewModel.selectedSkills.removeAll { $0 == tag }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .background(ColorTokens.primary)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ColorTokens.backgroundDark.ignoresSafeArea()
        InterestsView(viewModel: {
            let vm = OnboardingViewModel()
            vm.selectedObjectiveType = .upskilling
            vm.targetSkill = "Product Management"
            return vm
        }())
    }
    .preferredColorScheme(.dark)
}
