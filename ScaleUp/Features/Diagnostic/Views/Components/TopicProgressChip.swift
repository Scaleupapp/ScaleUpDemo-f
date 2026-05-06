import SwiftUI

// MARK: - Topic Progress Chip
//
// Plan 3a Task 9: small capsule shown at the top of the diagnostic quiz
// flow. Communicates per-topic progress like:
//   "3 of 7 topics • on Stakeholder Mgmt"
//
// The chip is intentionally light-weight — colour tokens and typography
// from the design system, smooth opacity/move transition when the
// `currentIndex` changes so a topic switch reads as a fluid update.
//
struct TopicProgressChip: View {
    let currentIndex: Int
    let totalCount: Int
    let currentTopicName: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text("\(currentIndex + 1) of \(totalCount) topics")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textSecondary)

            Text("•")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)

            Text("on \(currentTopicName)")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.gold)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceElevated)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTokens.border, lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Topic \(currentIndex + 1) of \(totalCount), \(currentTopicName)"
        )
    }
}

#Preview("Default") {
    ZStack {
        ColorTokens.background.ignoresSafeArea()
        TopicProgressChip(
            currentIndex: 2,
            totalCount: 7,
            currentTopicName: "Stakeholder Mgmt"
        )
    }
}

#Preview("First Topic") {
    ZStack {
        ColorTokens.background.ignoresSafeArea()
        TopicProgressChip(
            currentIndex: 0,
            totalCount: 5,
            currentTopicName: "Strategy"
        )
    }
}
