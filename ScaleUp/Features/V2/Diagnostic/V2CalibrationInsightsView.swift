import SwiftUI

/// V2 Calibration + Trajectory Insights (mockup screen 04).
///
/// Honest mirror — you-said-vs-you-actually + behavioral patterns + trajectory + top 3 actions.
/// Fetches from GET /api/v2/diagnostic/:attemptId/insights.
struct V2CalibrationInsightsView: View {
    @State private var vm = V2CalibrationInsightsViewModel()
    @Binding var path: NavigationPath
    var attemptId: String?
    /// Set by the post-diagnostic bridge — advances to the Plan Creation step.
    /// When nil (standalone use), the "Got it" button just exits.
    var onContinueToPlanCreation: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text("Diagnostic complete".uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.bottom, 10)

                Text("Here's where you actually are.")
                    .font(V2Theme.h1).foregroundStyle(ColorTokens.textPrimary)
                Text("Honest mirror. No softening.")
                    .font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
                    .padding(.top, 6).padding(.bottom, 20)

                if vm.isLoading && vm.data == nil {
                    loadingState.padding(.vertical, 40)
                } else if let data = vm.data {
                    loadedContent(data: data)
                } else {
                    errorState
                }
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 60)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .task {
            if let id = attemptId {
                await vm.load(attemptId: id)
            } else {
                await vm.loadLatestAttempt()
            }
        }
    }

    @ViewBuilder
    private func loadedContent(data: V2InsightsData) -> some View {
        // Baseline readiness
        VStack(spacing: 4) {
            Text("Your baseline readiness".uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(1)
                .foregroundStyle(ColorTokens.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(data.baseline.readiness)")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(baselineColor(data.baseline.readiness))
                Text("%").font(.system(size: 28, weight: .bold))
                    .foregroundStyle(baselineColor(data.baseline.readiness).opacity(0.7))
            }
            Text(data.baseline.headline)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(V2Theme.heroGradient))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(baselineColor(data.baseline.readiness).opacity(0.3), lineWidth: 1))
        .padding(.bottom, 18)

        // Calibration gap
        Text("Calibration gap").font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary).padding(.bottom, 8)

        if !data.calibration.summary.isEmpty {
            Text(data.calibration.summary)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.bottom, 10)
        }

        // One row per topic — self-rating and measured score side by side so
        // they're actually comparable (was two unaligned columns).
        VStack(spacing: 0) {
            HStack {
                Text("TOPIC").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(ColorTokens.textTertiary)
                Spacer()
                Text("YOU SAID").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 90, alignment: .trailing)
                Text("SCORED").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 90, alignment: .trailing)
            }
            .padding(.bottom, 8)

            ForEach(mergedCalibrationRows(data), id: \.topic) { row in
                HStack {
                    Text(row.topic.replacingOccurrences(of: "-", with: " ").capitalized)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(row.said)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(width: 90, alignment: .trailing)
                    scoredCell(row)
                        .frame(width: 90, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
                }
            }

            Text("Baseline readiness is the average of your measured scores.")
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            if mergedCalibrationRows(data).contains(where: { $0.notTested }) {
                Text("Topics marked \"Not tested\" had no questions in the available pool when you took the diagnostic — your readiness only averages measured topics. Re-take the diagnostic later as more questions become available.")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .v2Card(padding: 12)
        .padding(.bottom, 18)

        // Per-section performance — score / accuracy / time / questions
        if let perf = data.performance, !perf.isEmpty {
            Text("How you did per section").font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary).padding(.bottom, 8)
            VStack(spacing: 0) {
                // Column headers
                HStack {
                    Text("TOPIC").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Spacer()
                    Text("SCORE").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 50, alignment: .trailing)
                    Text("ACC").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 50, alignment: .trailing)
                    Text("AVG").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.bottom, 8)

                ForEach(perf) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.topic.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(V2Theme.small)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .lineLimit(1)
                            Text("\(p.questionsAnswered) q\(p.questionsAnswered == 1 ? "" : "s")\(p.band.map { " · \($0.capitalized)" } ?? "")")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        Spacer()
                        Text(p.score.map { "\($0)%" } ?? "—")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(scoreColor(p.score))
                            .frame(width: 50, alignment: .trailing)
                        Text("\(p.accuracyPct)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .frame(width: 50, alignment: .trailing)
                        Text(formatTime(p.avgTimeSec))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
                    }
                }

                Text("Score = engine's assessed level (0-100). Accuracy = % correct. Avg = avg time per question.")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .padding(12)
            .v2Card(padding: 12)
            .padding(.bottom, 18)
        }

        // Patterns
        if !data.patterns.isEmpty {
            Text("Patterns we noticed").font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(data.patterns, id: \.self) { p in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·").foregroundStyle(ColorTokens.textTertiary)
                        Text(p).font(V2Theme.body).foregroundStyle(ColorTokens.textPrimary)
                    }
                }
            }
            .padding(14)
            .v2Card(padding: 14)
            .padding(.bottom, 18)
        }

        // Trajectory
        if let traj = data.trajectory {
            Text("Where you'll be").font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary).padding(.bottom, 8)
            VStack(spacing: 0) {
                trajRow(label: "TODAY", value: "\(traj.today)%", color: baselineColor(traj.today))
                trajDivider
                trajRow(label: "30 DAYS", value: "\(traj.in30Days)%", color: ColorTokens.success)
                trajDivider
                trajRow(label: "TARGET (WEEK \(traj.timelineWeeks))", value: "\(traj.atTargetDate)%", color: ColorTokens.gold)
            }
            .padding(.vertical, 4)
            .v2Card(padding: 0)
            .padding(.bottom, 18)
        }

        // Top 3 actions
        if !data.topActions.isEmpty {
            Text("3 things that move you fastest").font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(data.topActions, id: \.rank) { action in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(action.rank).").foregroundStyle(ColorTokens.gold).fontWeight(.bold)
                            Text(action.title).font(V2Theme.body).foregroundStyle(ColorTokens.textPrimary)
                        }
                        Text(action.reason)
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.leading, 20)
                    }
                }
            }
            .padding(14)
            .v2Card(padding: 14)
            .padding(.bottom, 22)
        }

        Button {
            // Order: Diagnostic → Reality Check → [this: Calibration] → Plan Creation.
            // Advance to the Plan Creation screen. If we're not in a flow with a
            // plan-creation route (e.g. opened standalone), fall back to exit.
            if let onContinue = onContinueToPlanCreation {
                onContinue()
            } else {
                NotificationCenter.default.post(name: .v2OnboardingExit, object: nil)
            }
        } label: {
            Text("Got it — let's start")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(ColorTokens.gold)
                .foregroundStyle(ColorTokens.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)

        Text(data.planHeadline)
            .font(V2Theme.small)
            .foregroundStyle(ColorTokens.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 10)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(ColorTokens.gold)
            Text("Generating your insights…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 30)).foregroundStyle(ColorTokens.warning)
            Text(vm.error ?? "Couldn't load insights.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            if let id = vm.attemptId {
                Button("Retry") { Task { await vm.load(attemptId: id) } }
                    .buttonStyle(.bordered).tint(ColorTokens.gold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func baselineColor(_ pct: Int) -> Color {
        if pct < 40 { return ColorTokens.warning }
        if pct < 65 { return ColorTokens.gold }
        return ColorTokens.success
    }

    private func scoreColor(_ score: Int?) -> Color {
        guard let s = score else { return ColorTokens.textTertiary }
        if s < 50 { return ColorTokens.warning }
        if s >= 65 { return ColorTokens.success }
        return ColorTokens.textPrimary
    }

    private func formatTime(_ seconds: Int) -> String {
        if seconds <= 0 { return "—" }
        if seconds >= 60 { return "\(seconds / 60)m\(seconds % 60 > 0 ? " \(seconds % 60)s" : "")" }
        return "\(seconds)s"
    }

    /// One comparable row per topic — merges the self-rating and the
    /// measured score, keyed by topic, so they line up.
    private struct CalibRow {
        let topic: String
        let said: String
        /// Raw 0-100 integer from the backend. Nil when no questions were
        /// attempted (e.g. pool was empty). Distinct from notTested.
        let scoredPercent: Int?
        /// True when the backend had no questions for this topic in the pool.
        let notTested: Bool
    }

    private func mergedCalibrationRows(_ data: V2InsightsData) -> [CalibRow] {
        var byTopic: [String: (said: String, scoredPercent: Int?, notTested: Bool)] = [:]
        for s in data.calibration.selfRated {
            byTopic[s.topic, default: (said: "—", scoredPercent: nil, notTested: false)].said = s.level.capitalized
        }
        for a in data.calibration.actual {
            if a.notTested == true {
                byTopic[a.topic, default: (said: "—", scoredPercent: nil, notTested: false)].notTested = true
            } else if let pct = a.scorePct {
                byTopic[a.topic, default: (said: "—", scoredPercent: nil, notTested: false)].scoredPercent = pct
            }
        }
        return byTopic
            .sorted { ($0.value.scoredPercent ?? -1) < ($1.value.scoredPercent ?? -1) }
            .map { topic, v in
                CalibRow(topic: topic, said: v.said, scoredPercent: v.scoredPercent, notTested: v.notTested)
            }
    }

    // MARK: - Scored band helpers

    private enum ScoredBand: String {
        case novice = "Novice"
        case familiar = "Familiar"
        case proficient = "Proficient"
        case expert = "Expert"

        /// Maps a 0-100 percent to a self-rating band, matching the diagnostic
        /// engine's PLAN_BY_RATING bucket boundaries.
        static func from(percent: Int) -> ScoredBand {
            switch percent {
            case 0...25:  return .novice
            case 26...50: return .familiar
            case 51...75: return .proficient
            default:      return .expert
            }
        }

        /// Numeric rank for comparing against `youSaid`.
        var rank: Int {
            switch self {
            case .novice:     return 0
            case .familiar:   return 1
            case .proficient: return 2
            case .expert:     return 3
            }
        }
    }

    private func bandRank(from youSaid: String?) -> Int? {
        guard let raw = youSaid?.lowercased() else { return nil }
        switch raw {
        case "novice":     return 0
        case "familiar":   return 1
        case "proficient": return 2
        case "expert":     return 3
        default:           return nil
        }
    }

    private func bandColor(_ band: ScoredBand) -> Color {
        switch band {
        case .novice:     return ColorTokens.warning
        case .familiar:   return ColorTokens.textPrimary
        case .proficient: return ColorTokens.info
        case .expert:     return ColorTokens.success
        }
    }

    @ViewBuilder
    private func scoredCell(_ row: CalibRow) -> some View {
        if row.notTested {
            Text("Not tested")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        } else if let pct = row.scoredPercent {
            let band = ScoredBand.from(percent: pct)
            let youSaidRank = bandRank(from: row.said)
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    Text(band.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(bandColor(band))
                    if let yr = youSaidRank {
                        alignmentIndicator(scored: band.rank, youSaid: yr)
                    }
                }
                Text("\(pct)%")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        } else {
            Text("—")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    @ViewBuilder
    private func alignmentIndicator(scored: Int, youSaid: Int) -> some View {
        let delta = scored - youSaid
        if delta > 0 {
            Image(systemName: "arrow.up")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ColorTokens.success)
        } else if delta < 0 {
            Image(systemName: "arrow.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ColorTokens.warning)
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ColorTokens.gold)
        }
    }

    private func trajRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
            Spacer()
            Text(value).font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var trajDivider: some View {
        Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
    }
}

#Preview {
    NavigationStack {
        V2CalibrationInsightsView(path: .constant(NavigationPath()))
    }
    .preferredColorScheme(.dark)
}
