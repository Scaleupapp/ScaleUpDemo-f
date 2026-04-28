import SwiftUI

// MARK: - Reusable Rating Option Row

struct RatingOptionRow: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Leading indicator circle
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? ColorTokens.gold : ColorTokens.border,
                            lineWidth: isSelected ? 2 : 1.5
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(ColorTokens.gold)
                            .frame(width: 12, height: 12)
                    }
                }

                Text(label)
                    .font(Typography.bodySmall)
                    .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isSelected ? ColorTokens.gold.opacity(0.10) : ColorTokens.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(
                                isSelected ? ColorTokens.gold : Color.clear,
                                lineWidth: isSelected ? 1.5 : 0
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Diagnostic Self Rating View

struct DiagnosticSelfRatingView: View {
    let viewModel: DiagnosticViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.sm) {
                Text("How would you rate yourself?")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)

                Text("Honest answers help us skip what you know and focus on your real gaps.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.lg)

            // Competency list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    ForEach(viewModel.competencies) { competency in
                        competencyCard(competency)
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }

            // Continue button
            VStack(spacing: 0) {
                Divider()
                    .background(ColorTokens.divider)

                PrimaryButton(
                    title: "Continue",
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.canSubmitSelfRatings
                ) {
                    Task { await viewModel.submitSelfRatings() }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(ColorTokens.background)
        }
    }

    // MARK: - Competency Card

    private func competencyCard(_ competency: DiagnosticCompetency) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Topic header
            Text(competency.name)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            // Vertical rating rows
            VStack(spacing: Spacing.xs) {
                ForEach(DiagnosticSelfRating.allCases) { rating in
                    RatingOptionRow(
                        label: rating.displayLabel,
                        isSelected: viewModel.selfRatings[competency.name] == rating
                    ) {
                        viewModel.setRating(rating, for: competency.name)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            viewModel.selfRatings[competency.name] != nil
                                ? ColorTokens.gold.opacity(0.35)
                                : ColorTokens.border,
                            lineWidth: 1
                        )
                )
        )
    }
}
