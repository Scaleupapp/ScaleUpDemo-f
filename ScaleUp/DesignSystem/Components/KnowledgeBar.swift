import SwiftUI

struct KnowledgeBar: View {
    let topic: String
    let score: Int // 0-100
    let level: String
    var trend: String? // "improving", "stable", "declining"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(topic)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()

                Text("\(score)/100")
                    .font(Typography.mono)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.surfaceElevatedDark)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.progressGradient)
                        .frame(width: geo.size.width * (Double(score) / 100))
                }
            }
            .frame(height: 8)

            HStack(spacing: Spacing.xs) {
                Text(level.capitalized)
                    .font(Typography.caption)
                    .foregroundStyle(levelColor)

                if let trend {
                    Text(trendIcon(trend))
                        .font(Typography.caption)
                    Text(trend)
                        .font(Typography.caption)
                        .foregroundStyle(trendColor(trend))
                }
            }
        }
        .padding(Spacing.sm)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    private var levelColor: Color {
        switch level.lowercased() {
        case "expert": return ColorTokens.anchorGold
        case "advanced": return ColorTokens.primary
        case "intermediate": return ColorTokens.info
        case "beginner": return ColorTokens.textSecondaryDark
        default: return ColorTokens.textTertiaryDark
        }
    }

    private func trendIcon(_ trend: String) -> String {
        switch trend.lowercased() {
        case "improving": return "↑"
        case "declining": return "↓"
        default: return "→"
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend.lowercased() {
        case "improving": return ColorTokens.success
        case "declining": return ColorTokens.error
        default: return ColorTokens.textSecondaryDark
        }
    }
}
