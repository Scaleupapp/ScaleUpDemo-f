import SwiftUI

struct DiagnosticSelfRatingView: View {
    let viewModel: DiagnosticViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.sm) {
                Text("How would you rate yourself on each topic?")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)

                Text("There are no wrong answers. This helps us start at the right level.")
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

    private func competencyCard(_ competency: DiagnosticCompetency) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(competency.name)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(DiagnosticSelfRating.allCases) { rating in
                        ratingChip(rating, for: competency.name)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
        )
    }

    private func ratingChip(_ rating: DiagnosticSelfRating, for competency: String) -> some View {
        let isSelected = viewModel.selfRatings[competency] == rating

        return Button {
            viewModel.setRating(rating, for: competency)
        } label: {
            Text(rating.displayLabel)
                .font(Typography.bodySmallBold)
                .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.full)
                        .fill(isSelected ? ColorTokens.gold : ColorTokens.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.full)
                                .stroke(
                                    isSelected ? ColorTokens.gold : ColorTokens.border,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}
