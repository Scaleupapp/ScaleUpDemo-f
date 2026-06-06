import SwiftUI

struct DiagnosticResultsView: View {
    let attemptId: String
    var onSeePlanTap: () -> Void

    @StateObject private var vm: DiagnosticResultsViewModel

    init(attemptId: String, onSeePlanTap: @escaping () -> Void) {
        self.attemptId = attemptId
        self.onSeePlanTap = onSeePlanTap
        self._vm = StateObject(wrappedValue: DiagnosticResultsViewModel(attemptId: attemptId))
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            switch vm.phase {
            case .generating:
                InsightsGeneratingView(isReady: false)
            case .ready:
                resultsScroll.transition(.opacity)
            }
        }
        .onAppear { vm.start() }
    }

    private var resultsScroll: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Top: data-first summary band (overall score, band, time)
                summaryBand
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)

                // Hero takeaway — short headline, no share top-right.
                HeroCard(heroSentence: vm.hero, onShareTap: nil)
                    .padding(.horizontal, Spacing.lg)

                // Performance breakdown (accuracy by difficulty + counts).
                if let stats = vm.stats {
                    performanceCard(stats)
                        .padding(.horizontal, Spacing.lg)
                }

                // Calibration overview with legend.
                CalibrationCard(
                    summarySentence: vm.calibrationSummary,
                    detailSentence: vm.calibrationDetail,
                    topics: vm.topics
                )
                .padding(.horizontal, Spacing.lg)

                // Focus areas: lowest-scoring topics, surfaced first.
                if let focus = focusTopic {
                    focusCard(focus).padding(.horizontal, Spacing.lg)
                }

                sectionHeader("By topic")
                ForEach(vm.topics) { t in
                    TopicComparisonBarCard(topic: t, onExpand: vm.onTopicExpanded(_:))
                        .padding(.horizontal, Spacing.lg)
                }

                if !vm.patterns.isEmpty {
                    sectionHeader("Patterns we noticed")
                    ForEach(Array(vm.patterns.enumerated()), id: \.offset) { idx, p in
                        PatternCard(title: "Pattern \(idx + 1)", text: p, icon: patternIcon(for: idx))
                            .padding(.horizontal, Spacing.lg)
                    }
                }

                planPreview.padding(.horizontal, Spacing.lg)
                seePlanButton
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)

                nextStepCard
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxl)
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Summary band (overall score, band, time)

    private var summaryBand: some View {
        let band = dominantBandLabel
        let totalSec = vm.stats?.totalTimeSec ?? 0
        return HStack(spacing: Spacing.sm) {
            statTile(value: "\(vm.overallScore)", label: "Overall", color: ColorTokens.gold)
            statTile(value: band, label: "Level", color: bandColor(band))
            statTile(value: formatDuration(totalSec), label: "Time", color: ColorTokens.textPrimary)
            statTile(value: "\(vm.stats?.totalQuestions ?? vm.topics.reduce(0) { $0 + $1.totalCount })", label: "Questions", color: ColorTokens.textPrimary)
        }
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.border.opacity(0.6), lineWidth: 1)
                )
        )
    }

    // MARK: - Performance breakdown

    private func performanceCard(_ stats: DiagnosticStatsDTO) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(ColorTokens.gold)
                    .font(.system(size: 13, weight: .semibold))
                Text("How you performed")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            VStack(spacing: Spacing.sm) {
                difficultyRow(label: "Easy",   bucket: stats.accuracyByDifficulty.easy,   color: ColorTokens.success)
                difficultyRow(label: "Medium", bucket: stats.accuracyByDifficulty.medium, color: ColorTokens.warning)
                difficultyRow(label: "Hard",   bucket: stats.accuracyByDifficulty.hard,   color: ColorTokens.error)
            }

            HStack(spacing: Spacing.lg) {
                Label("\(formatDuration(stats.totalTimeSec)) total", systemImage: "clock")
                Label("\(stats.avgSecPerQuestion)s avg", systemImage: "speedometer")
            }
            .font(Typography.caption)
            .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
    }

    private func difficultyRow(label: String, bucket: DiagnosticAccuracyBucketDTO, color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .font(Typography.bodySmall)
                .frame(width: 60, alignment: .leading)
                .foregroundStyle(ColorTokens.textPrimary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.surfaceElevated).frame(height: 8)
                    Capsule()
                        .fill(color)
                        .frame(width: bucket.total > 0 ? geo.size.width * CGFloat(bucket.correct) / CGFloat(bucket.total) : 0, height: 8)
                }
            }
            .frame(height: 8)
            Text(bucket.total > 0 ? "\(bucket.correct)/\(bucket.total)" : "—")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Focus card (lowest-scoring topic)

    private var focusTopic: DiagnosticTopicResult? {
        // Lowest score AND user was over-confident → highest-impact focus.
        let overestimates = vm.topics.filter { $0.calibrationClass == "overestimates" || $0.calibrationClass == "over-confident" }
        if let pick = overestimates.min(by: { $0.measuredScore < $1.measuredScore }) {
            return pick
        }
        return vm.topics.min(by: { $0.measuredScore < $1.measuredScore })
    }

    private func focusCard(_ t: DiagnosticTopicResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .foregroundStyle(ColorTokens.gold)
                    .font(.system(size: 13, weight: .semibold))
                Text("Where to focus first")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            Text(t.displayName)
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Scored \(t.measuredScore)/100 (\(t.measuredBand)) — biggest unlock if you close this gap first.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.gold.opacity(0.45), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private var dominantBandLabel: String {
        let counts = Dictionary(grouping: vm.topics, by: { $0.measuredBand }).mapValues { $0.count }
        let band = counts.max(by: { $0.value < $1.value })?.key ?? "novice"
        return band.prefix(1).uppercased() + band.dropFirst()
    }

    private func bandColor(_ band: String) -> Color {
        switch band.lowercased() {
        case "expert":       return .purple
        case "proficient":   return ColorTokens.success
        case "familiar":     return ColorTokens.gold
        case "novice":       return ColorTokens.warning
        default:             return ColorTokens.textPrimary
        }
    }

    private func formatDuration(_ totalSec: Int) -> String {
        let s = max(0, totalSec)
        if s >= 60 {
            let m = s / 60
            let rem = s % 60
            return rem == 0 ? "\(m)m" : "\(m)m \(rem)s"
        }
        return "\(s)s"
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text).font(Typography.titleMedium).foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Your plan").font(Typography.titleMedium).foregroundStyle(ColorTokens.textPrimary)
            Text(vm.planHeadline)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(3)
            HStack {
                Image(systemName: "hourglass").foregroundStyle(ColorTokens.gold)
                Text("Your full plan is brewing — usually a minute or two")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.top, 2)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
    }

    @ViewBuilder private var nextStepCard: some View {
        if let gap = focusTopic {
            NextStepCard(lead: "Start with your biggest gap:", highlight: gap.displayName, actionTitle: "Practice it now") {
                NextStepCoordinator.shared.fire(.launchQuiz(topic: gap.canonicalName))
            }
        }
    }

    private var seePlanButton: some View {
        Button(action: onSeePlanTap) {
            Text("See your plan")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Capsule().fill(ColorTokens.gold))
        }
    }

    private func patternIcon(for idx: Int) -> String {
        ["chart.line.uptrend.xyaxis", "scope", "lightbulb.fill", "target"][idx % 4]
    }
}
