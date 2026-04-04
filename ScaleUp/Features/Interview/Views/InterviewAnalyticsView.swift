import SwiftUI
import Charts

struct InterviewAnalyticsView: View {
    @State private var analytics: InterviewAnalytics?
    @State private var isLoading = true
    private let service = InterviewService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if let analytics {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        overviewGrid(analytics)
                        scoreTrendChart(analytics.scoreTrend)
                        dimensionBarChart(analytics.dimensionAverages)
                        weakestAreaCard(analytics)
                        typeBreakdownSection(analytics.typeBreakdown)
                        Spacer().frame(height: Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 36))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("No analytics data yet")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("Complete a few interviews to see your trends")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .navigationTitle("Interview Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAnalytics() }
    }

    // MARK: - Overview 2x2 Grid

    private func overviewGrid(_ data: InterviewAnalytics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statCard(value: "\(data.totalInterviews)", label: "Total Interviews", icon: "mic.fill", color: .cyan)
            statCard(value: "\(data.averageScore)", label: "Avg Score", icon: "star.fill", color: ColorTokens.gold)
            statCard(value: "\(data.interviewsThisWeek)", label: "This Week", icon: "calendar", color: .green)
            statCard(value: "\(data.interviewsThisMonth)", label: "This Month", icon: "calendar.badge.clock", color: .orange)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Score Trend Line Chart

    private func scoreTrendChart(_ data: [InterviewScorePoint]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Score Trend — Last 10 Interviews")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            if data.isEmpty {
                Text("No score data yet")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(data) { point in
                    if let date = point.date {
                        AreaMark(
                            x: .value("Date", date),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(ColorTokens.gold.opacity(0.15))

                        LineMark(
                            x: .value("Date", date),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(ColorTokens.gold)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", date),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(ColorTokens.gold)
                        .symbolSize(24)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Dimension Bar Chart

    private func dimensionBarChart(_ dims: DimensionAverages) -> some View {
        let dimensions: [(String, Double, Color)] = [
            ("Communication", dims.communication, .cyan),
            ("Content", dims.content, ColorTokens.gold),
            ("Structure", dims.structure, .purple),
            ("Confidence", dims.confidence, .green)
        ]

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Dimension Averages")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            Chart(dimensions, id: \.0) { name, value, color in
                BarMark(
                    x: .value("Dimension", name),
                    y: .value("Score", value)
                )
                .foregroundStyle(color)
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center) {
                    Text(String(format: "%.0f", value))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(ColorTokens.textSecondary)
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .frame(height: 180)
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Weakest Area Card

    @ViewBuilder
    private func weakestAreaCard(_ data: InterviewAnalytics) -> some View {
        if let weakest = data.weakestDimension {
            let score = scoreForDimension(weakest, averages: data.dimensionAverages)

            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.warning.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.warning)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weakest Area")
                        .font(Typography.captionBold)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text(weakest.capitalized)
                        .font(Typography.bodyBold)
                        .foregroundStyle(.white)
                    Text("Average: \(String(format: "%.0f", score))/100")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.warning)
                }

                Spacer()

                Text(String(format: "%.0f", score))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.warning)
            }
            .padding(Spacing.lg)
            .background(ColorTokens.warning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ColorTokens.warning.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func scoreForDimension(_ name: String, averages: DimensionAverages) -> Double {
        switch name.lowercased() {
        case "communication": return averages.communication
        case "content": return averages.content
        case "structure": return averages.structure
        case "confidence": return averages.confidence
        default: return 0
        }
    }

    // MARK: - Type Breakdown

    private func typeBreakdownSection(_ types: [TypeCount]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("By Interview Type")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            if types.isEmpty {
                Text("No interview data yet")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.vertical, Spacing.md)
            } else {
                ForEach(types) { item in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: item.type.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(item.type.color)
                            .frame(width: 24)

                        Text(item.type.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)

                        Spacer()

                        Text("\(item.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(item.type.color)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Load

    private func loadAnalytics() async {
        analytics = try? await service.fetchAnalytics()
        isLoading = false
    }
}
