import SwiftUI

// MARK: - LEGACY V1 — slated for removal

/// **DEPRECATED — Legacy V1 surface.**
/// Used only by v1 HomeView. Replaced by inline plan status on V2HomeView.
/// Scheduled for removal after 2026-06-15.

@available(*, deprecated, message: "Legacy V1 — use V2HomeView's plan status (see LEGACY_V1.md)")
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
