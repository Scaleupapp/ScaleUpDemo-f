import SwiftUI

// MARK: - Recalibration Results View

struct RecalibrationResultsView: View {
    let attemptId: String
    let onDone: () -> Void

    @Environment(AppState.self) private var appState
    @State private var results: RecalibrationResultsDTO?
    @State private var loading = true
    @State private var error: String?
    @State private var animateBars = false

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if loading {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(ColorTokens.gold)
            } else if let error {
                errorView(error)
            } else if let results {
                mainContent(results)
            }
        }
        .task {
            await fetchResults()
        }
    }

    // MARK: - Fetch

    private func fetchResults() async {
        loading = true
        do {
            results = try await APIClient.shared.request(RecalibrationResultsEndpoint(attemptId: attemptId))
            if let growth = results?.recalibrationGrowth {
                let count = growth.growthBars.count
                let biggest = growth.biggestJump?.delta ?? 0
                AnalyticsService.shared.track(.recalibrationCompleted(topicsRetested: count, biggestGrowth: biggest))
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            animateBars = true
        }
    }

    // MARK: - Main Content

    private func mainContent(_ dto: RecalibrationResultsDTO) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                heroSection(dto)

                if let growth = dto.recalibrationGrowth, !growth.growthBars.isEmpty {
                    growthBarsSection(growth.growthBars)
                }

                if let growth = dto.recalibrationGrowth, !growth.newGaps.isEmpty {
                    newGapsSection(growth.newGaps)
                }

                planRebalanceSection

                nextStepCard(dto)

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
        }
    }

    // MARK: - Hero

    private func heroSection(_ dto: RecalibrationResultsDTO) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44))
                .foregroundStyle(ColorTokens.gold)

            if let jump = dto.recalibrationGrowth?.biggestJump {
                VStack(spacing: Spacing.xs) {
                    Text("Biggest growth")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Text(jump.canonicalName)
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("+\(String(format: "%.0f", jump.delta)) pts")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.gold)
                }
            } else if let summary = dto.recalibrationGrowth?.summary {
                Text(summary)
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Recalibration complete")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(ColorTokens.gold.opacity(0.35), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Growth Bars

    private func growthBarsSection(_ bars: [GrowthBar]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Topic Growth")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: Spacing.md) {
                ForEach(bars) { bar in
                    GrowthBarRow(bar: bar, animate: animateBars)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - New Gaps

    private func newGapsSection(_ gaps: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text("New gaps detected")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("These topics showed up as gaps in your recalibration.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(gaps, id: \.self) { gap in
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                        Text(gap)
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.orange.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Plan Rebalance Preview

    private var planRebalanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Your plan has been rebalanced")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Based on your growth, ScaleUp has updated your weekly allocation to reflect your new strengths and remaining gaps.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(3)

            Button {
                onDone()
                appState.selectedTab = .journey
            } label: {
                HStack(spacing: 8) {
                    Text("Go to plan")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.buttonPrimaryText)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.buttonPrimaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(ColorTokens.gold)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Next Step Card

    @ViewBuilder private func nextStepCard(_ dto: RecalibrationResultsDTO) -> some View {
        let gapTopic: String? = dto.recalibrationGrowth?.newGaps.first
            ?? dto.recalibrationGrowth?.growthBars.min(by: { $0.newScore < $1.newScore })?.canonicalName
        if let gap = gapTopic {
            NextStepCard(lead: "Your biggest remaining gap is", highlight: gap, actionTitle: "Practice it now") {
                NextStepCoordinator.shared.fire(.launchQuiz(topic: gap))
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.warning)
            Text("Couldn't load results")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Done") { onDone() }
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.gold)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Growth Bar Row

struct GrowthBarRow: View {
    let bar: GrowthBar
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(bar.canonicalName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text(deltaLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(bar.delta >= 0 ? ColorTokens.success : .orange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.surfaceElevated)
                        .frame(height: 10)

                    // New score gold bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.goldGradient)
                        .frame(
                            width: animate ? geo.size.width * clampedNew : 0,
                            height: 10
                        )
                        .animation(
                            UIAccessibility.isReduceMotionEnabled
                                ? .none
                                : .easeOut(duration: 0.55),
                            value: animate
                        )

                    // Old score white marker
                    if clampedOld > 0 {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 2, height: 14)
                            .offset(x: geo.size.width * clampedOld - 1)
                    }
                }
            }
            .frame(height: 14)

            if let shift = bar.bandShift {
                Text(shift)
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private var clampedOld: Double {
        min(max(bar.oldScore / 100.0, 0), 1)
    }

    private var clampedNew: Double {
        min(max(bar.newScore / 100.0, 0), 1)
    }

    private var deltaLabel: String {
        let sign = bar.delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", bar.delta)) pts"
    }
}

// MARK: - Endpoint

private struct RecalibrationResultsEndpoint: Endpoint {
    let attemptId: String
    var path: String { "/diagnostic/attempts/\(attemptId)/results" }
    var method: HTTPMethod { .get }
}
