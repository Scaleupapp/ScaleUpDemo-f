import SwiftUI

struct TopicChipView: View {
    let topic: SuggestedTopic
    let isSelected: Bool
    let onToggle: () -> Void
    let onInfo: () -> Void

    @State private var bumping = false

    var body: some View {
        HStack(spacing: 6) {
            if topic.isFutureProofing {
                Text("✦ Future-proofing")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(topic.name)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText.opacity(0.8) : ColorTokens.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(isSelected ? ColorTokens.gold : Color.clear)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1))
        .scaleEffect(bumping ? 0.94 : 1)
        .onTapGesture {
            Haptics.selection()
            withAnimation(.easeOut(duration: 0.12)) { bumping = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { bumping = false }
                onToggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(topic.name)\(topic.isFutureProofing ? ", future proofing" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
