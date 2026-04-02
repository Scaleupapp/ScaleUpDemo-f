import SwiftUI
import Charts

struct NotesAnalyticsView: View {
    @State private var analytics: NotesAnalytics?
    @State private var isLoading = true
    private let notesService = NotesService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if let analytics {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        overviewGrid(analytics.overview)
                        viewsChart(analytics.viewsOverTime)
                        topNotesSection(analytics.topNotes)
                        domainSection(analytics.domainBreakdown)
                        Spacer().frame(height: Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            } else {
                Text("No analytics data")
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .navigationTitle("Notes Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAnalytics() }
    }

    // MARK: - Overview 2x2 Grid

    private func overviewGrid(_ o: AnalyticsOverview) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statCard(value: "\(o.totalViews)", label: "Total Views", icon: "eye", color: ColorTokens.gold)
            statCard(value: "\(o.totalSaves)", label: "Total Saves", icon: "bookmark", color: .cyan)
            statCard(value: "\(o.totalLikes)", label: "Total Likes", icon: "heart", color: .red)
            statCard(value: "\(o.avgQualityScore)", label: "Avg Quality", icon: "star", color: .orange)
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

    // MARK: - Views Over Time Chart

    private func viewsChart(_ data: [ViewDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Views — Last 30 Days")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            if data.isEmpty {
                Text("No view data yet")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(data) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Views", point.views)
                    )
                    .foregroundStyle(ColorTokens.gold.opacity(0.2))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Views", point.views)
                    )
                    .foregroundStyle(ColorTokens.gold)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Top Notes

    private func topNotesSection(_ notes: [TopNote]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Top Performing Notes")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            if notes.isEmpty {
                Text("No notes data yet")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.vertical, Spacing.md)
            } else {
                ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                    HStack(spacing: 10) {
                        Text("#\(index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ColorTokens.gold)
                            .frame(width: 24)

                        Text(note.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 9))
                            Text("\(note.viewCount)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Domain Breakdown

    private func domainSection(_ domains: [DomainStat]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("By Domain")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            if domains.isEmpty {
                Text("No domain data yet")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.vertical, Spacing.md)
            } else {
                ForEach(domains) { d in
                    HStack {
                        Text(d.domain.capitalized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(d.noteCount) notes")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("·")
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("\(d.totalViews) views")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Load

    private func loadAnalytics() async {
        analytics = try? await notesService.fetchAnalytics()
        isLoading = false
    }
}
