import SwiftUI

struct ScoreBar: View {
    let topic: String
    let score: Int
    let level: String?
    let trend: Trend?
    var showTrend: Bool = true

    private var barColor: Color {
        if score >= 70 { return ColorTokens.success }
        if score >= 40 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(topic.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()

                HStack(spacing: 4) {
                    Text("\(score)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(barColor)

                    if showTrend, let trend {
                        Image(systemName: trend.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(trendColor(trend))
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
            .frame(height: 8)
        }
    }

    private func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .improving: return .green
        case .stable: return .orange
        case .declining: return .red
        }
    }
}
