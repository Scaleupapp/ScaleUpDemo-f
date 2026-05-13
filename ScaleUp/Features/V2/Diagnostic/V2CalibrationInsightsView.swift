import SwiftUI

/// V2 Calibration + Trajectory Insights (mockup screen 04).
///
/// Honest mirror — you-said-vs-you-actually + behavioral patterns + trajectory + top 3 actions.
/// Fetches from GET /api/v2/diagnostic/:attemptId/insights.
struct V2CalibrationInsightsView: View {
    @State private var vm = V2CalibrationInsightsViewModel()
    @Binding var path: NavigationPath
    var attemptId: String?

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

        HStack(spacing: 10) {
            calibCol(label: "You said", entries: data.calibration.selfRated.map { ($0.topic, $0.level) })
            calibCol(label: "You actually", entries: data.calibration.actual.map { ($0.topic, "\($0.scorePct)%") }, isActual: true)
        }
        .padding(.bottom, 18)

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
            // Land on home with v2 flag still on
            V2FeatureFlag.shared.v2OnboardingEnabled = false
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

    private func calibCol(label: String, entries: [(String, String)], isActual: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
            ForEach(entries, id: \.0) { entry in
                HStack {
                    Text(entry.0).font(V2Theme.small).foregroundStyle(ColorTokens.textSecondary)
                    Spacer()
                    Text(entry.1).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isActual ? actualColor(entry.1) : ColorTokens.textPrimary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .v2Card(padding: 12)
    }

    private func actualColor(_ v: String) -> Color {
        if let pct = Int(v.replacingOccurrences(of: "%", with: "")) {
            if pct < 50 { return ColorTokens.warning }
            if pct >= 65 { return ColorTokens.success }
        }
        return ColorTokens.textPrimary
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
