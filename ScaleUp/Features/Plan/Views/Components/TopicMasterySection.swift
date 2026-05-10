import SwiftUI

struct TopicMasterySection: View {
    let mastery: APIPlanMastery
    @State private var isExpanded = false
    @State private var selectedTopicId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            if isExpanded {
                if mastery.interview.totalSessions > 0 {
                    interviewRollupCard
                }
                if !mastery.topics.isEmpty {
                    chipScroller
                }
                if let id = selectedTopicId,
                   let detail = mastery.topics.first(where: { $0.canonicalName == id }) {
                    topicDetail(detail)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            Text("YOUR PROGRESS BY TOPIC")
                .font(Typography.micro)
                .tracking(1.4)
                .foregroundStyle(ColorTokens.gold)
            Spacer()
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }
    }

    private var interviewRollupCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "mic")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("Interview practice")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text("\(mastery.interview.totalSessions) session\(mastery.interview.totalSessions == 1 ? "" : "s")")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            HStack(spacing: 12) {
                statBlock(label: "Avg score", value: String(format: "%.1f / 10", mastery.interview.averageScore))
                trendIcon(mastery.interview.trend.rawValue)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ColorTokens.surface)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1))
        )
    }

    private var chipScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mastery.topics, id: \.canonicalName) { t in
                    topicChip(t)
                        .onTapGesture {
                            withAnimation { selectedTopicId = (selectedTopicId == t.canonicalName ? nil : t.canonicalName) }
                        }
                }
            }
        }
    }

    private func topicChip(_ t: APIPlanTopicMastery) -> some View {
        let isSelected = selectedTopicId == t.canonicalName
        return HStack(spacing: 6) {
            Circle()
                .fill(levelColor(t.level))
                .frame(width: 8, height: 8)
            Text(t.displayName)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? ColorTokens.gold.opacity(0.20) : ColorTokens.gold.opacity(0.08))
                .overlay(Capsule().stroke(isSelected ? ColorTokens.gold : Color.clear, lineWidth: 1))
        )
    }

    private func topicDetail(_ t: APIPlanTopicMastery) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(t.displayName)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text(levelLabel(t.level))
                    .font(Typography.caption)
                    .foregroundStyle(levelColor(t.level))
            }
            HStack(spacing: 12) {
                statBlock(label: "Score", value: "\(Int(t.score))/100")
                statBlock(label: "Quizzes", value: "\(t.quizzesTaken)")
                statBlock(label: "Content", value: "\(t.contentConsumed)")
                if t.externalTouches > 0 {
                    statBlock(label: "External", value: "\(t.externalTouches)")
                }
                trendIcon(t.trend.rawValue)
            }
            if t.scoreHistory.count >= 2 {
                Sparkline(scores: t.scoreHistory.compactMap { $0.score })
                    .frame(height: 32)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ColorTokens.surface)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ColorTokens.gold.opacity(0.20), lineWidth: 1))
        )
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Typography.bodyBold).foregroundStyle(ColorTokens.textPrimary)
            Text(label).font(Typography.micro).foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func trendIcon(_ trend: String) -> some View {
        let iconName: String = trend == "improving" ? "arrow.up.right" : trend == "declining" ? "arrow.down.right" : "minus"
        let color: Color = trend == "improving" ? .green : trend == "declining" ? .red : ColorTokens.textSecondary
        return Image(systemName: iconName).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
    }

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "expert": return .purple
        case "advanced": return .green
        case "intermediate": return ColorTokens.gold
        case "beginner": return .orange
        default: return ColorTokens.textSecondary
        }
    }

    private func levelLabel(_ level: String) -> String {
        level.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct Sparkline: View {
    let scores: [Double]
    var body: some View {
        GeometryReader { geo in
            let maxScore = max(scores.max() ?? 100, 1)
            let minScore = scores.min() ?? 0
            let range = max(maxScore - minScore, 1)
            Path { path in
                for (i, s) in scores.enumerated() {
                    let x = scores.count == 1 ? geo.size.width / 2 : geo.size.width * Double(i) / Double(scores.count - 1)
                    let y = geo.size.height * (1.0 - (s - minScore) / range)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(ColorTokens.gold, lineWidth: 1.5)
        }
    }
}
