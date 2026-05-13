import SwiftUI

/// V2 Calibration + Trajectory Insights (mockup screen 04).
///
/// Honest mirror — you-said-vs-you-actually + behavioral patterns + trajectory + top 3 actions.
/// Fetches from GET /api/v2/diagnostic/:attemptId/insights.
struct V2CalibrationInsightsView: View {
    @State private var data: InsightsData = .sample
    @Binding var path: NavigationPath

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

                // Baseline readiness
                VStack(spacing: 4) {
                    Text("Your baseline readiness".uppercased())
                        .font(.system(size: 10, weight: .semibold)).tracking(1)
                        .foregroundStyle(ColorTokens.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(data.baselineReadiness)")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(ColorTokens.warning)
                        Text("%").font(.system(size: 28, weight: .bold))
                            .foregroundStyle(ColorTokens.warning.opacity(0.7))
                    }
                    Text(data.baselineSub)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 20).fill(V2Theme.heroGradient))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(ColorTokens.warning.opacity(0.3), lineWidth: 1))
                .padding(.bottom, 18)

                // Calibration gap
                Text("Calibration gap").font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary).padding(.bottom, 8)
                HStack(spacing: 10) {
                    calibCol(label: "You said", entries: data.youSaid)
                    calibCol(label: "You actually", entries: data.youActually, isActual: true)
                }
                .padding(.bottom, 18)

                // Patterns
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

                // Trajectory
                Text("Where you'll be").font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary).padding(.bottom, 8)
                VStack(spacing: 0) {
                    trajRow(label: "TODAY", value: "\(data.trajectoryNow)%", color: ColorTokens.warning)
                    trajDivider
                    trajRow(label: "30 DAYS (AT 25 HRS/WK)", value: "\(data.trajectory30)%", color: ColorTokens.success)
                    trajDivider
                    trajRow(label: "WEEK 24 (TARGET)", value: "\(data.trajectoryTarget)%+", color: ColorTokens.gold)
                }
                .padding(.vertical, 4)
                .v2Card(padding: 0)
                .padding(.bottom, 18)

                // Top 3 actions
                Text("3 things that move you fastest").font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary).padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(data.topActions.enumerated()), id: \.offset) { idx, action in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1).").foregroundStyle(ColorTokens.gold).fontWeight(.bold)
                            Text(action).font(V2Theme.body).foregroundStyle(ColorTokens.textPrimary)
                        }
                    }
                }
                .padding(14)
                .v2Card(padding: 14)
                .padding(.bottom, 22)

                Button {
                    // TODO: dismiss to home / set flag
                    V2FeatureFlag.shared.v2OnboardingEnabled = false // exit onboarding for now
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

                Text("Your plan is being personalized while you explore.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 60)
        }
        .background(ColorTokens.background.ignoresSafeArea())
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

private struct InsightsData {
    let baselineReadiness: Int
    let baselineSub: String
    let youSaid: [(String, String)]
    let youActually: [(String, String)]
    let patterns: [String]
    let trajectoryNow: Int
    let trajectory30: Int
    let trajectoryTarget: Int
    let topActions: [String]

    static let sample = InsightsData(
        baselineReadiness: 32,
        baselineSub: "For SDE @ Google in 6 months",
        youSaid: [("DP", "Proficient"), ("Graphs", "Intermediate"), ("OS", "Beginner")],
        youActually: [("DP", "30%"), ("Graphs", "42%"), ("OS", "68%")],
        patterns: [
            "You rush quantitative questions (18s avg, accuracy drops).",
            "You over-think case questions (4 min avg, accuracy holds).",
            "After 2 wrong in a row, your next 3 are 60% likely to be wrong.",
        ],
        trajectoryNow: 32,
        trajectory30: 58,
        trajectoryTarget: 80,
        topActions: [
            "Deliberate slowdown on quant — read fully before picking",
            "Focus DP from foundation — your gap there is highest leverage",
            "Active recovery technique when you get 2 wrong",
        ]
    )
}

#Preview {
    NavigationStack {
        V2CalibrationInsightsView(path: .constant(NavigationPath()))
    }
    .preferredColorScheme(.dark)
}
