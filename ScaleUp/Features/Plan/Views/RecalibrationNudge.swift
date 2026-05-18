import SwiftUI

// MARK: - Recalibration Nudge
//
// Inline alert shown on the Plan tab when the user is eligible for
// recalibration. Dismisses persistently via @AppStorage — won't reappear
// once the user taps ×. The Progress-tab RecalibrationCard is separate
// and unaffected by this dismissal.

// MARK: - LEGACY V1 — slated for removal

/// **DEPRECATED — Legacy V1 surface.**
/// Used only by v1 PlanTabView. v2 surfaces recalibration via Compass.
/// Scheduled for removal after 2026-06-15.

@available(*, deprecated, message: "Legacy V1 — v2 recalibration is Compass-driven (see LEGACY_V1.md)")
struct RecalibrationNudge: View {
    let eligibility: RecalibrationEligibility
    let onTap: () -> Void

    @AppStorage("recalibrationNudgeDismissed") private var dismissed = false

    var body: some View {
        if !dismissed {
            nudgeContent
        }
    }

    private var nudgeContent: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)

            VStack(alignment: .leading, spacing: 3) {
                Text("Ready to see your growth?")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: 6) {
                    if let mins = eligibility.expectedDurationMin {
                        Text("~\(mins) min")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Button {
                        Haptics.light()
                        onTap()
                    } label: {
                        Text("Take it now")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    dismissed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(6)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
