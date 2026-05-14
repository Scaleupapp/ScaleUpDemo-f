import SwiftUI

/// V2 "You" — deep analytics & profile screen.
///
/// Pushed from the You tab's "My progress & analytics" row. Shows everything
/// the learner has done: lifetime counts, quiz performance trend, time
/// invested, learning velocity, per-topic mastery, cognitive fingerprint,
/// recent activity, and achievements. Backed by GET /api/v2/you/analytics.
struct V2YouAnalyticsView: View {
    @State private var vm = V2YouViewModel()

    var body: some View {
        ScrollView {
            if vm.analyticsLoading && vm.analytics == nil {
                loadingState
            } else if let a = vm.analytics {
                content(a)
            } else {
                errorState
            }
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("Progress & analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.analytics == nil { await vm.loadAnalytics() } }
        .refreshable { await vm.loadAnalytics() }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ a: V2YouAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            countsGrid(a.counts)
            quizPerformance(a.quizPerformance)
            timeInvested(a.timeInvested)
            velocity(a.velocity, streak: a.streak)
            if !a.masteryMap.isEmpty { masteryMap(a.masteryMap) }
            if !a.strengths.isEmpty || !a.weaknesses.isEmpty {
                strengthsWeaknesses(strengths: a.strengths, weaknesses: a.weaknesses)
            }
            if hasCognitive(a.cognitive) { cognitive(a.cognitive) }
            if !a.recentActivity.isEmpty { recentActivity(a.recentActivity) }
            if !a.achievements.isEmpty { achievements(a.achievements) }
            Spacer().frame(height: 60)
        }
        .padding(.horizontal, V2Theme.pad)
        .padding(.top, 16)
    }

    // MARK: - Lifetime counts

    private func countsGrid(_ c: V2YouAnalytics.Counts) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Lifetime")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                countCell(value: c.quizzesTaken, label: "Quizzes")
                countCell(value: c.contentCompleted, label: "Lessons")
                countCell(value: c.interviewsTaken, label: "Interviews")
                countCell(value: c.topicsCovered, label: "Topics")
                countCell(value: c.compassConversations, label: "Compass chats")
            }
        }
    }

    private func countCell(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quiz performance

    private func quizPerformance(_ q: V2YouAnalytics.QuizPerformance) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Quiz performance")
                Spacer()
                directionBadge(q.direction)
            }
            if q.trend.isEmpty {
                Text("Take a quiz to start tracking your trend.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.vertical, 8)
            } else {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(q.trend.enumerated()), id: \.offset) { _, point in
                        VStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ColorTokens.gold.opacity(0.85))
                                .frame(height: max(4, CGFloat(point.score) * 0.8))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 88, alignment: .bottom)
                if let avg = q.averageScore {
                    Text("Average score: \(avg)%")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
        .cardWrap()
    }

    private func directionBadge(_ direction: String) -> some View {
        let (label, color, icon): (String, Color, String) = {
            switch direction {
            case "improving": return ("Improving", ColorTokens.success, "arrow.up.right")
            case "declining": return ("Declining", ColorTokens.warning, "arrow.down.right")
            default: return ("Stable", ColorTokens.textTertiary, "arrow.right")
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Time invested

    private func timeInvested(_ t: V2YouAnalytics.TimeInvested) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Time invested")
            HStack(spacing: 0) {
                timeCell(minutes: t.totalMinutes, label: "Total", accent: true)
                divider
                timeCell(minutes: t.contentMinutes, label: "Learning")
                divider
                timeCell(minutes: t.interviewMinutes, label: "Interviews")
            }
        }
        .cardWrap()
    }

    private func timeCell(minutes: Int, label: String, accent: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(formatDuration(minutes))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accent ? ColorTokens.gold : ColorTokens.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Velocity

    private func velocity(_ v: V2YouAnalytics.Velocity, streak: V2YouOverview.StreakBlock) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Momentum")
            VStack(spacing: 0) {
                metricRow(label: "Topics per week", value: String(format: "%.1f", v.topicsPerWeek))
                divider
                metricRow(label: "Avg score change", value: signed(v.avgScoreImprovement))
                divider
                metricRow(label: "Overall knowledge", value: "\(v.overallScore)%")
                divider
                metricRow(label: "Current streak", value: streak.current == 1 ? "1 day" : "\(streak.current) days")
                divider
                metricRow(label: "Longest streak", value: streak.longest == 1 ? "1 day" : "\(streak.longest) days")
            }
        }
        .cardWrap()
    }

    // MARK: - Mastery map

    private func masteryMap(_ entries: [V2YouAnalytics.MasteryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Topic mastery")
            VStack(spacing: 12) {
                ForEach(entries) { e in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(e.topic.capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .lineLimit(1)
                            if e.trend != "stable" {
                                Image(systemName: e.trend == "improving" ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(e.trend == "improving" ? ColorTokens.success : ColorTokens.warning)
                            }
                            Spacer()
                            Text("\(e.score)%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(masteryColor(e.score))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(ColorTokens.surfaceElevated)
                                Capsule()
                                    .fill(masteryColor(e.score))
                                    .frame(width: max(4, geo.size.width * CGFloat(e.score) / 100))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .cardWrap()
    }

    private func masteryColor(_ score: Int) -> Color {
        if score >= 70 { return ColorTokens.success }
        if score >= 40 { return ColorTokens.gold }
        return ColorTokens.warning
    }

    // MARK: - Strengths & weaknesses

    private func strengthsWeaknesses(strengths: [String], weaknesses: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !strengths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Strengths")
                    chipWrap(strengths, color: ColorTokens.success)
                }
            }
            if !weaknesses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Focus areas")
                    chipWrap(weaknesses, color: ColorTokens.warning)
                }
            }
        }
        .cardWrap()
    }

    private func chipWrap(_ items: [String], color: Color) -> some View {
        FlexibleWrap(items: items) { item in
            Text(item.capitalized)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    // MARK: - Cognitive fingerprint

    private func hasCognitive(_ c: V2YouAnalytics.Cognitive) -> Bool {
        c.bestTime != nil || c.preferredFormat != nil || c.sessionStyle != nil || c.learnerType != nil
    }

    private func cognitive(_ c: V2YouAnalytics.Cognitive) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("How you learn")
            VStack(spacing: 0) {
                if let bt = c.bestTime, let block = bt.block {
                    metricRow(label: "Best time of day", value: "\(block.capitalized) (+\(bt.scoreLift)pp)")
                    divider
                }
                if let fmt = c.preferredFormat {
                    metricRow(label: "Preferred format", value: fmt.capitalized)
                    divider
                }
                if let ss = c.sessionStyle {
                    metricRow(label: "Session style", value: "\(ss.style.replacingOccurrences(of: "_", with: " ").capitalized) · \(ss.medianMinutes)m")
                    divider
                }
                if let lt = c.learnerType {
                    metricRow(label: "Learner type", value: lt.replacingOccurrences(of: "_", with: " ").capitalized)
                }
            }
        }
        .cardWrap()
    }

    // MARK: - Recent activity

    private func recentActivity(_ items: [V2YouAnalytics.ActivityEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Recent activity")
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Text(activityIcon(item.type))
                            .font(.system(size: 13))
                            .frame(width: 30, height: 30)
                            .background(ColorTokens.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text((item.title ?? item.type).capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text(relativeDate(item.at))
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        Spacer()
                        if let detail = item.detail {
                            Text(detail)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }
                    .padding(.vertical, 10)
                    if item.id != items.last?.id { divider }
                }
            }
        }
        .cardWrap()
    }

    private func activityIcon(_ type: String) -> String {
        switch type {
        case "quiz": return "📝"
        case "content": return "📺"
        case "interview": return "🎤"
        default: return "•"
        }
    }

    // MARK: - Achievements

    private func achievements(_ items: [V2YouAnalytics.Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Achievements")
            FlexibleWrap(items: items.map { $0.label }) { label in
                HStack(spacing: 5) {
                    Image(systemName: "rosette").font(.system(size: 10))
                    Text(label).font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(ColorTokens.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(ColorTokens.gold.opacity(0.10))
                .overlay(Capsule().strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Shared bits

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(ColorTokens.textTertiary)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .padding(.vertical, 11)
    }

    private var divider: some View {
        Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
    }

    private func signed(_ v: Double) -> String {
        let rounded = (v * 10).rounded() / 10
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func relativeDate(_ iso: String?) -> String {
        guard let iso = iso else { return "" }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date = date else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading your analytics…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.warning)
            Text(vm.analyticsError ?? "Couldn't load your analytics.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await vm.loadAnalytics() } }
                .buttonStyle(.bordered)
                .tint(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .padding(.horizontal, 24)
    }
}

// MARK: - Card wrapper

private extension View {
    func cardWrap() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Flexible wrap layout

private struct FlexibleWrap<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack { V2YouAnalyticsView() }
        .preferredColorScheme(.dark)
}
