import SwiftUI

struct CompetencyScoreBar: View {
    let name: String
    let score: Int
    let category: String?
    let weight: Int?
    let trend: String?

    private var categoryColor: Color {
        switch category {
        case "core": return ColorTokens.gold
        case "advanced": return .purple
        case "soft_skill": return .cyan
        default: return ColorTokens.textTertiary
        }
    }

    private var barColor: Color {
        if score >= 70 { return ColorTokens.success }
        if score >= 40 { return categoryColor }
        return .orange
    }

    private var trendIcon: String? {
        switch trend {
        case "improving": return "arrow.up.right"
        case "stable": return "arrow.right"
        case "declining": return "arrow.down.right"
        default: return nil
        }
    }

    private var trendColor: Color {
        switch trend {
        case "improving": return .green
        case "stable": return .orange
        case "declining": return .red
        default: return .clear
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 6, height: 6)

                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                // Weight dots
                if let w = weight {
                    HStack(spacing: 2) {
                        ForEach(0..<min(w, 10), id: \.self) { i in
                            Circle()
                                .fill(i < w ? categoryColor : categoryColor.opacity(0.2))
                                .frame(width: 3, height: 3)
                        }
                    }
                }

                HStack(spacing: 4) {
                    Text("\(score)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(barColor)

                    if let icon = trendIcon {
                        Image(systemName: icon)
                            .font(.system(size: 9))
                            .foregroundStyle(trendColor)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.surfaceElevated)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(score) / 100)
                }
            }
            .frame(height: 6)
        }
    }
}
