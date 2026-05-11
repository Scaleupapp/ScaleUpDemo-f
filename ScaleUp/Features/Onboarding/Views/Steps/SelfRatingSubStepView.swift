import SwiftUI

struct SelfRatingSubStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var expandedAnchor: String?    // "<canonical>:<level>"

    private var topicsToRate: [SuggestedTopic] {
        viewModel.allDisplayableTopics.filter { viewModel.selectedCanonicals.contains($0.canonicalName) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                header
                ForEach(topicsToRate) { topic in
                    topicCard(topic)
                }
                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .background(ColorTokens.background)
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            Text("How would you rate yourself?")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text("Be honest — we'll calibrate against this in your diagnostic.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.isOnRatingSubStep = false }
            } label: {
                Label("Edit topics", systemImage: "chevron.left")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.gold)
            }
        }
        .padding(.top, Spacing.lg)
    }

    private func topicCard(_ topic: SuggestedTopic) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(topic.name).font(Typography.bodyBold).foregroundStyle(ColorTokens.textPrimary)
                if topic.isFutureProofing {
                    Text("✦").foregroundStyle(ColorTokens.gold)
                }
                Spacer()
            }
            HStack(spacing: Spacing.sm) {
                ForEach(ProficiencyLevel.allCases) { level in
                    ratingChip(level: level, topic: topic)
                }
            }
            if let anchor = expandedAnchor, anchor.hasPrefix(topic.canonicalName + ":") {
                let levelRaw = String(anchor.split(separator: ":").last ?? "")
                if let level = ProficiencyLevel(rawValue: levelRaw) {
                    Text(level.anchorExample)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(Spacing.sm)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func ratingChip(level: ProficiencyLevel, topic: SuggestedTopic) -> some View {
        let isSelected = viewModel.topicSelfRatings[topic.canonicalName] == level
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.setRating(level, for: topic)
                expandedAnchor = "\(topic.canonicalName):\(level.rawValue)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if expandedAnchor == "\(topic.canonicalName):\(level.rawValue)" {
                    withAnimation(.easeOut(duration: 0.25)) { expandedAnchor = nil }
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: level.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(level.displayName).font(Typography.caption)
            }
            .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? ColorTokens.gold : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

}
