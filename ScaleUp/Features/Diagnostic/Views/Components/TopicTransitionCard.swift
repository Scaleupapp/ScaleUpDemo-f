import SwiftUI

// MARK: - Topic Transition Card
//
// Plan 3a Task 9: full-width card shown for ~1 second when the diagnostic
// engine moves the user from one competency topic to the next.
//
// Wording: "Nice — moving to <Strategy>" with a sparkles icon.
// The card auto-dismisses by calling `onComplete` after 1 second.
//
struct TopicTransitionCard: View {
    let nextTopicName: String
    let onComplete: () -> Void

    /// Canonical names arrive kebab-cased ("verbal-reasoning"). Show them
    /// human-readable.
    private var displayName: String {
        nextTopicName
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .symbolEffect(.pulse, options: .repeating)

            Text("Nice — moving to \(displayName)")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.lg)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onAppear {
            // ~2.2s — long enough to actually read, short enough not to drag.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                onComplete()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Moving to \(displayName)")
    }
}

#Preview("Default") {
    ZStack {
        ColorTokens.background.ignoresSafeArea()
        TopicTransitionCard(nextTopicName: "Strategy") {}
    }
}

#Preview("Long Topic Name") {
    ZStack {
        ColorTokens.background.ignoresSafeArea()
        TopicTransitionCard(nextTopicName: "Stakeholder Management") {}
    }
}
