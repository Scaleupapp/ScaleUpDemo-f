import SwiftUI

// MARK: - Strengths & Weaknesses View

/// Combined detail view for strengths and weaknesses.
/// Strengths use green accents with score bars; weaknesses use red accents with "Strengthen" CTA buttons.
struct StrengthsWeaknessesView: View {

    let viewModel: KnowledgeProfileViewModel

    @State private var selectedWeakness: String?

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {

                    // Strengths Section
                    if !viewModel.topStrengths.isEmpty {
                        strengthsSection
                    }

                    // Weaknesses Section
                    if !viewModel.topWeaknesses.isEmpty {
                        weaknessesSection
                    }

                    // Gap Content for Selected Weakness
                    if let selectedWeakness, !filteredGapContent.isEmpty {
                        gapContentForWeakness(topicName: selectedWeakness)
                    }

                    // Bottom spacing
                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationTitle("Strengths & Weaknesses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Strengths Section

    private var strengthsSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Your Strengths")

            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.topStrengths, id: \.self) { strength in
                    strengthRow(topic: strength)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func strengthRow(topic: String) -> some View {
        let score = viewModel.scoreForTopic(topic)

        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.success)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(topic)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Spacer()

                    if score > 0 {
                        Text("\(score)/100")
                            .font(Typography.mono)
                            .foregroundStyle(ColorTokens.success)
                    }
                }

                // Score bar
                if score > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ColorTokens.surfaceElevatedDark)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [ColorTokens.success.opacity(0.7), ColorTokens.success],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * (Double(score) / 100))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.success.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(ColorTokens.success.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Weaknesses Section

    private var weaknessesSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Areas to Improve")

            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.topWeaknesses, id: \.self) { weakness in
                    weaknessRow(topic: weakness)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func weaknessRow(topic: String) -> some View {
        let score = viewModel.scoreForTopic(topic)
        let isSelected = selectedWeakness == topic

        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.error)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(topic)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Spacer()

                    if score > 0 {
                        Text("\(score)/100")
                            .font(Typography.mono)
                            .foregroundStyle(ColorTokens.error)
                    }
                }

                // Score bar
                if score > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ColorTokens.surfaceElevatedDark)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [ColorTokens.error.opacity(0.7), ColorTokens.error],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * (Double(score) / 100))
                        }
                    }
                    .frame(height: 6)
                }
            }

            // Strengthen CTA
            Button {
                withAnimation(Animations.standard) {
                    if selectedWeakness == topic {
                        selectedWeakness = nil
                    } else {
                        selectedWeakness = topic
                    }
                }
            } label: {
                Text(isSelected ? "Showing" : "Strengthen")
                    .font(Typography.micro)
                    .foregroundStyle(isSelected ? .white : ColorTokens.error)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        isSelected
                            ? ColorTokens.error
                            : ColorTokens.error.opacity(0.15)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(
            isSelected
                ? ColorTokens.error.opacity(0.1)
                : ColorTokens.error.opacity(0.04)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(
                    isSelected
                        ? ColorTokens.error.opacity(0.4)
                        : ColorTokens.error.opacity(0.12),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Gap Content for Weakness

    private var filteredGapContent: [Content] {
        guard let selectedWeakness else { return [] }
        return viewModel.gapRecommendationsForTopic(selectedWeakness)
    }

    @ViewBuilder
    private func gapContentForWeakness(topicName: String) -> some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Content for \(topicName)")

            HorizontalCarousel(items: filteredGapContent) { content in
                ContentCard(
                    title: content.title,
                    creatorName: content.creator.firstName + " " + content.creator.lastName,
                    domain: content.domain,
                    thumbnailURL: content.resolvedThumbnailURL,
                    duration: content.duration,
                    rating: content.averageRating > 0 ? content.averageRating : nil,
                    viewCount: content.viewCount > 0 ? content.viewCount : nil
                )
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
