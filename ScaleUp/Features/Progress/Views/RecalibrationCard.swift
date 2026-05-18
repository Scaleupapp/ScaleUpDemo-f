import SwiftUI

// MARK: - Recalibration Card
//
// Shown on the Progress tab when the user is eligible for recalibration.
// Gold-bordered elevated surface — "See how much you've grown" pitch.

// MARK: - LEGACY V1 — slated for removal
/// **DEPRECATED — Legacy V1 surface.** Used only by v1 ProgressTabView.
/// Scheduled for removal after 2026-06-15. See LEGACY_V1.md.
@available(*, deprecated, message: "Legacy V1 — see LEGACY_V1.md")
struct RecalibrationCard: View {
    let eligibility: RecalibrationEligibility
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)

                Text("Ready to see your growth?")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()
            }

            Text("See how much you have grown since your last diagnostic. A short re-test shows your real improvement.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.md) {
                if let count = eligibility.eligibleTopics?.count, count > 0 {
                    statChip(value: "\(count)", label: count == 1 ? "topic" : "topics")
                }
                if let mins = eligibility.expectedDurationMin {
                    statChip(value: "~\(mins)", label: "min")
                }
                Spacer()
            }

            Button {
                Haptics.light()
                onTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Start recalibration")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(ColorTokens.gold)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ColorTokens.gold.opacity(0.45), lineWidth: 1.5)
        )
    }

    private func statChip(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.gold)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ColorTokens.gold.opacity(0.10))
        .clipShape(Capsule())
    }
}
