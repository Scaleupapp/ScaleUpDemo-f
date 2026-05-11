import SwiftUI

// MARK: - Models (frontend-only DTOs mirroring backend insights JSON)

struct DiagnosticTopicResult: Identifiable, Hashable {
    var id: String { canonicalName }
    let canonicalName: String
    let displayName: String
    let selfRating: String        // "Novice" | "Familiar" | "Proficient" | "Expert"
    let measuredScore: Int        // 0-100
    let measuredBand: String
    let calibrationDelta: Int
    let calibrationClass: String  // "well-calibrated" | "overestimates" | "undersells"
    let questionsAsked: Int
    let topicTakeaway: String
    let strongestMoment: String?
    let stretchMoment: String?
    let missedDifficulties: [String]
    let timeTakenSec: Int
    let correctCount: Int
    let totalCount: Int

    /// Pretty-printed time spent on this topic ("2m 14s" or "47s").
    var timeTakenLabel: String {
        let total = max(0, timeTakenSec)
        if total >= 60 {
            let m = total / 60
            let s = total % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(total)s"
    }
    var accuracyPct: Int? {
        guard totalCount > 0 else { return nil }
        return Int(round(100.0 * Double(correctCount) / Double(totalCount)))
    }
}

extension DiagnosticTopicResult {
    var classColor: Color {
        switch calibrationClass {
        case "well-calibrated": return ColorTokens.success
        case "overestimates":   return ColorTokens.warning
        case "undersells":      return ColorTokens.info
        default:                return ColorTokens.textSecondary
        }
    }
    var selfRatingMidpoint: Int {
        switch selfRating.lowercased() {
        case "novice":     return 15
        case "familiar":   return 42
        case "proficient": return 67
        case "expert":     return 90
        default:           return 50
        }
    }
}

// MARK: - HeroCard

struct HeroCard: View {
    let heroSentence: String
    var onShareTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                Text(heroSentence)
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let onShareTap {
                    Button(action: onShareTap) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ColorTokens.gold)
                            .padding(8)
                            .background(Circle().fill(ColorTokens.gold.opacity(0.12)))
                    }
                    .accessibilityLabel("Share results")
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.heroGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(ColorTokens.gold.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - CalibrationCard

struct CalibrationCard: View {
    let summarySentence: String
    let detailSentence: String
    let topics: [DiagnosticTopicResult]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(summarySentence)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(detailSentence)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(3)

            VStack(spacing: 8) {
                ForEach(topics) { t in
                    deltaBand(for: t)
                }
            }
            .padding(.top, 4)

            // Legend. Without this the row of half-filled bars is gibberish —
            // user can't tell what the dots mean or why some bars are green
            // vs gold. Pairs the dot styles to copy.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle().fill(ColorTokens.textSecondary).frame(width: 8, height: 8)
                    Text("Your self-rating")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                HStack(spacing: 8) {
                    Circle().fill(ColorTokens.gold).frame(width: 10, height: 10)
                    Text("Measured score")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Capsule().fill(ColorTokens.warning.opacity(0.6)).frame(width: 14, height: 4)
                        Text("Overestimated")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Capsule().fill(ColorTokens.info.opacity(0.6)).frame(width: 14, height: 4)
                        Text("Underestimated")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.surface)
        )
    }

    private func deltaBand(for t: DiagnosticTopicResult) -> some View {
        GeometryReader { geo in
            let lo = CGFloat(min(t.selfRatingMidpoint, t.measuredScore)) / 100.0
            let hi = CGFloat(max(t.selfRatingMidpoint, t.measuredScore)) / 100.0
            let bandX = geo.size.width * lo
            let bandW = max(2, geo.size.width * (hi - lo))

            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.surfaceElevated).frame(height: 6)
                Capsule().fill(t.classColor.opacity(0.5))
                    .frame(width: bandW, height: 6)
                    .offset(x: bandX)
                Circle().fill(ColorTokens.textSecondary)
                    .frame(width: 8, height: 8)
                    .offset(x: geo.size.width * CGFloat(t.selfRatingMidpoint) / 100.0 - 4)
                Circle().fill(t.classColor)
                    .frame(width: 10, height: 10)
                    .offset(x: geo.size.width * CGFloat(t.measuredScore) / 100.0 - 5)
            }
        }
        .frame(height: 14)
        .accessibilityLabel("\(t.displayName): self-rated \(t.selfRating), measured \(t.measuredScore)")
    }
}

// MARK: - PatternCard
// NOTE: The stored property holding the card body copy is named `text` (not `body`)
// to avoid collision with SwiftUI's `View.body` computed property requirement.

struct PatternCard: View {
    let title: String
    let text: String   // renamed from `body` to avoid SwiftUI View.body collision
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 28, height: 28)
                .background(Circle().fill(ColorTokens.gold.opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .tracking(0.5)
                Text(text)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineSpacing(3)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
    }
}

// MARK: - TopicComparisonBarCard

struct TopicComparisonBarCard: View {
    let topic: DiagnosticTopicResult
    @State private var animatedSelf: CGFloat = 0
    @State private var animatedMeasured: CGFloat = 0
    @State private var displayedScore: Int = 0
    @State private var isExpanded: Bool = false
    var onExpand: ((String) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            bars
            if topic.totalCount > 0 {
                topicStatsStrip
            }
            if !topic.topicTakeaway.isEmpty {
                Text(topic.topicTakeaway)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineSpacing(3)
            }
            if isExpanded { expandedDetail }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(topic.classColor.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { toggleExpand() }
        .onAppear { animateBars() }
    }

    private var header: some View {
        HStack {
            Text(topic.displayName)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Text(topic.measuredBand)
                .font(Typography.captionBold)
                .foregroundStyle(topic.classColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(topic.classColor.opacity(0.15)))
        }
    }

    private var bars: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            barView(label: "Your rating", widthRatio: animatedSelf, color: ColorTokens.textSecondary, scoreText: topic.selfRating)
            barView(label: "Measured", widthRatio: animatedMeasured, color: topic.classColor, scoreText: "\(displayedScore)")
        }
    }

    /// Per-topic stat strip: correct/total, time spent, accuracy %. Gives the
    /// user something concrete beyond the abstract "Familiar vs 33" framing.
    private var topicStatsStrip: some View {
        HStack(spacing: Spacing.lg) {
            statChip(icon: "checkmark.circle", text: "\(topic.correctCount)/\(topic.totalCount) right")
            statChip(icon: "clock", text: topic.timeTakenLabel)
            if let pct = topic.accuracyPct {
                statChip(icon: "percent", text: "\(pct)% acc")
            }
        }
        .padding(.top, 2)
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func barView(label: String, widthRatio: CGFloat, color: Color, scoreText: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.surfaceElevated).frame(height: 10)
                    Capsule().fill(color).frame(width: max(4, geo.size.width * widthRatio), height: 10)
                }
            }.frame(height: 10)
            Text(scoreText).font(Typography.captionBold).foregroundStyle(color)
        }
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !topic.missedDifficulties.isEmpty {
                detailRow(icon: "questionmark.circle", label: "Missed difficulties", value: topic.missedDifficulties.joined(separator: ", "))
            }
            if let s = topic.strongestMoment {
                detailRow(icon: "star.fill", label: "Strongest moment", value: s)
            }
            if let s = topic.stretchMoment {
                detailRow(icon: "arrow.up.right.circle", label: "Stretch moment", value: s)
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).foregroundStyle(ColorTokens.gold).font(.system(size: 12, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
                Text(value).font(Typography.bodySmall).foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }

    private func toggleExpand() {
        withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
        if isExpanded { onExpand?(topic.canonicalName) }
        Haptics.light()
    }

    private func animateBars() {
        let selfRatio = CGFloat(topic.selfRatingMidpoint) / 100.0
        let measuredRatio = CGFloat(topic.measuredScore) / 100.0
        if reduceMotion {
            animatedSelf = selfRatio
            animatedMeasured = measuredRatio
            displayedScore = topic.measuredScore
            return
        }
        withAnimation(.easeOut(duration: 1.0)) {
            animatedSelf = selfRatio
            animatedMeasured = measuredRatio
        }
        let steps = 30
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * (1.0 / Double(steps))) {
                displayedScore = Int(Double(topic.measuredScore) * Double(i) / Double(steps))
            }
        }
    }
}

// MARK: - ShareableSummaryCard

struct ShareableSummaryCard: View {
    let heroSentence: String
    let topics: [DiagnosticTopicResult]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("ScaleUp")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
                    .tracking(1.2)
                Spacer()
                Text("Calibration check")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            Text(heroSentence)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineSpacing(3)
            VStack(spacing: 8) {
                ForEach(topics.prefix(3)) { t in
                    HStack {
                        Text(t.displayName).font(Typography.bodySmall).foregroundStyle(ColorTokens.textSecondary)
                        Spacer()
                        Text("\(t.measuredScore)").font(Typography.captionBold).foregroundStyle(t.classColor)
                    }
                }
            }
            HStack {
                Spacer()
                Text("scaleupapp.club")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 360, height: 360)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.heroGradient)
        )
    }
}
