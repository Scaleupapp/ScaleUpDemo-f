import SwiftUI

struct PlanBrewingPill: View {
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(ColorTokens.gold)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Text("Your plan is brewing — usually ~45s")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(ColorTokens.surfaceElevated)
                    .overlay(
                        Capsule()
                            .stroke(ColorTokens.gold.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear { isPulsing = true }
    }
}
