import SwiftUI

// MARK: - Codable shapes

struct V2ActivitiesData: Codable {
    let summary: V2ActivitiesSummary?
    let recent: [V2ActivityRecentItem]?
    let byType: V2ActivitiesByType?
}

struct V2ActivitiesSummary: Codable {
    let totalQuizzes: Int?
    let totalInterviews: Int?
    let totalContentWatched: Int?
    let totalAITutorSessions: Int?
    let totalMinutes: Int?
    let thisWeek: V2ActivitiesWeekSummary?
}

struct V2ActivitiesWeekSummary: Codable {
    let quizzes: Int?
    let interviews: Int?
    let contentWatched: Int?
    let aiTutorSessions: Int?
    let totalMinutes: Int?
}

struct V2ActivityRecentItem: Codable, Identifiable, Hashable {
    let type: String?
    let id: String
    let title: String?
    let topic: String?
    let score: Int?
    let linkedToObjective: Bool?
    let completedAt: String?
    let durationMin: Int?
    let messageCount: Int?
}

struct V2ActivitiesByType: Codable {
    let quizzes: V2ActivityQuizStats?
    let interviews: V2ActivityInterviewStats?
    let content: V2ActivityContentStats?
    let ai_tutor: V2ActivityAITutorStats?
}

/// Quiz analytics. Backend returns `trend` as an array of data points and a
/// separate `direction` string ("improving" / "declining" / "stable"). We
/// expose both since the spec calls the categorical value the "trend".
struct V2ActivityQuizStats: Codable {
    let trend: [V2ActivityQuizTrendPoint]?
    let direction: String?
    let averageScore: Int?
    let avgScoreByTopic: [V2ActivityQuizTopicAvg]?
    let totalMinutes: Int?
}

struct V2ActivityQuizTrendPoint: Codable, Hashable {
    let date: String?
    let score: Int?
}

struct V2ActivityQuizTopicAvg: Codable, Hashable {
    let topic: String?
    let avgScore: Int?
    let attempts: Int?
}

struct V2ActivityInterviewStats: Codable {
    let averageScore: Int?
    let breakdownByType: [V2ActivityInterviewBreakdown]?
    let totalMinutes: Int?
}

struct V2ActivityInterviewBreakdown: Codable, Hashable {
    let type: String?
    let count: Int?
    let avgScore: Int?
}

struct V2ActivityContentStats: Codable {
    let totalCompleted: Int?
    let totalMinutes: Int?
    let inProgress: Int?
}

struct V2ActivityAITutorStats: Codable {
    let totalSessions: Int?
    let totalMessages: Int?
}

// MARK: - Filter

enum V2ActivityFilter: String, CaseIterable, Identifiable {
    case all, quiz, interview, content, ai_tutor

    var id: String { rawValue }
    var chipLabel: String {
        switch self {
        case .all: return "All"
        case .quiz: return "Quizzes"
        case .interview: return "Interviews"
        case .content: return "Content"
        case .ai_tutor: return "AI Tutor"
        }
    }

    func matches(_ raw: String?) -> Bool {
        guard self != .all else { return true }
        return rawValue == (raw ?? "")
    }
}

// MARK: - View model

@Observable
@MainActor
final class V2ActivitiesViewModel {
    var data: V2ActivitiesData?
    var isLoading: Bool = false
    var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp: V2APIResponse<V2ActivitiesData> = try await V2APIClient.shared.get("/you/activities")
            data = resp.data
            error = nil
        } catch {
            self.error = "Could not load activities."
        }
    }
}

// MARK: - Main view

struct V2ActivitiesDetailView: View {
    @State private var vm = V2ActivitiesViewModel()
    @State private var didLoad = false
    @State private var filter: V2ActivityFilter = .all

    public init() {}

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            content
        }
        .navigationTitle("All activities")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !didLoad {
                didLoad = true
                await vm.load()
            }
        }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.data == nil {
            VStack(spacing: 12) {
                ProgressView().tint(ColorTokens.gold)
                Text("Loading your activity…")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.error, vm.data == nil {
            emptyState(icon: "exclamationmark.triangle", title: err, hint: "Pull to retry")
        } else if let data = vm.data {
            ScrollView {
                VStack(alignment: .leading, spacing: V2Theme.gap) {
                    heroCard(summary: data.summary)
                    thisWeekCard(week: data.summary?.thisWeek)
                    filterStrip
                    recentSection(items: filteredRecent(from: data.recent ?? []))
                    breakdownSection(byType: data.byType)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.vertical, V2Theme.gap)
            }
        }
    }

    private func filteredRecent(from items: [V2ActivityRecentItem]) -> [V2ActivityRecentItem] {
        guard filter != .all else { return items }
        return items.filter { filter.matches($0.type) }
    }

    // MARK: hero

    @ViewBuilder
    private func heroCard(summary: V2ActivitiesSummary?) -> some View {
        let totalDone = heroTotalDone(summary)
        let totalMinutes = summary?.totalMinutes ?? 0
        let weekDone = heroWeekDone(summary)
        let subtitle = "\(formatMinutes(totalMinutes)) invested · \(weekDone) this week"

        VStack(alignment: .leading, spacing: 8) {
            Text("HEADLINE")
                .v2Eyebrow()
            heroHeadline(total: totalDone)
            Text(subtitle)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    private func heroHeadline(total: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(total)")
                .font(V2Theme.h1)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("things done")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func heroTotalDone(_ summary: V2ActivitiesSummary?) -> Int {
        let q = summary?.totalQuizzes ?? 0
        let i = summary?.totalInterviews ?? 0
        let c = summary?.totalContentWatched ?? 0
        let t = summary?.totalAITutorSessions ?? 0
        return q + i + c + t
    }

    private func heroWeekDone(_ summary: V2ActivitiesSummary?) -> Int {
        let q = summary?.thisWeek?.quizzes ?? 0
        let i = summary?.thisWeek?.interviews ?? 0
        let c = summary?.thisWeek?.contentWatched ?? 0
        let t = summary?.thisWeek?.aiTutorSessions ?? 0
        return q + i + c + t
    }

    // MARK: this week

    @ViewBuilder
    private func thisWeekCard(week: V2ActivitiesWeekSummary?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK SO FAR")
                .v2Eyebrow()
            HStack(spacing: 0) {
                weekChip(emoji: "🧠", value: week?.quizzes ?? 0, suffix: "quizzes")
                weekDivider
                weekChip(emoji: "🎙", value: week?.interviews ?? 0, suffix: "interviews")
                weekDivider
                weekChip(emoji: "🎥", value: week?.contentWatched ?? 0, suffix: "videos")
                weekDivider
                weekChip(emoji: "⏱", value: week?.totalMinutes ?? 0, suffix: "min")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    private var weekDivider: some View {
        Rectangle()
            .fill(V2Theme.cardBorder)
            .frame(width: 1, height: 26)
            .padding(.horizontal, 4)
    }

    private func weekChip(emoji: String, value: Int, suffix: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(emoji).font(.system(size: 14))
                Text("\(value)")
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            Text(suffix)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: filter

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("FILTER")
                    .v2Eyebrow(ColorTokens.textTertiary)
                    .padding(.trailing, 4)
                ForEach(V2ActivityFilter.allCases) { f in
                    Button {
                        filter = f
                    } label: {
                        Text(f.chipLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(filter == f ? ColorTokens.background : ColorTokens.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(filter == f ? ColorTokens.gold : ColorTokens.surface)
                            )
                            .overlay(
                                Capsule().strokeBorder(V2Theme.cardBorder, lineWidth: filter == f ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: recent

    @ViewBuilder
    private func recentSection(items: [V2ActivityRecentItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT")
                .v2Eyebrow()
            if items.isEmpty {
                Text("Nothing here yet — start a quiz or watch a clip.")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                            .fill(ColorTokens.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                            .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        recentRow(item)
                    }
                }
            }
        }
    }

    private func recentRow(_ item: V2ActivityRecentItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(timestampLine(for: item.completedAt))
                    .v2Eyebrow(ColorTokens.textTertiary)
                Text("·")
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("\(emoji(for: item.type)) \(typeLabel(for: item.type))")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(ColorTokens.textSecondary)
                if let topic = item.topic, !topic.isEmpty {
                    Text("· \(topic)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if let title = item.title, !title.isEmpty {
                Text(title)
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
            }
            HStack(spacing: 8) {
                if let score = item.score {
                    Text("scored \(score)%")
                        .font(V2Theme.small)
                        .foregroundStyle(scoreColor(score))
                }
                if let mins = item.durationMin, mins > 0 {
                    Text("· \(mins) min")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                if let mc = item.messageCount, mc > 0 {
                    Text("· \(mc) messages")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            if item.linkedToObjective == true {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.gold)
                    Text("Linked to your objective")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: breakdown

    @ViewBuilder
    private func breakdownSection(byType: V2ActivitiesByType?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BREAKDOWN BY TYPE")
                .v2Eyebrow()

            quizzesCard(stats: byType?.quizzes)
            interviewsCard(stats: byType?.interviews)
            contentCard(stats: byType?.content)
            aiTutorCard(stats: byType?.ai_tutor)
        }
    }

    @ViewBuilder
    private func quizzesCard(stats: V2ActivityQuizStats?) -> some View {
        breakdownCard(title: "QUIZZES") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: trendIcon(stats?.direction))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(trendColor(stats?.direction))
                    Text("Trend: \(trendWord(stats?.direction))")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                let avg = stats?.averageScore.map { "\($0)%" } ?? "—"
                let count = stats?.trend?.count ?? 0
                Text("Avg \(avg) · \(count) recorded")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                if let topics = stats?.avgScoreByTopic, !topics.isEmpty {
                    Text("By topic:")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.top, 2)
                    let lines = topics.prefix(4).compactMap { t -> String? in
                        guard let topic = t.topic else { return nil }
                        let score = t.avgScore ?? 0
                        let attempts = t.attempts ?? 0
                        return "\(topic) \(score)% (\(attempts))"
                    }
                    Text(lines.joined(separator: " · "))
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func interviewsCard(stats: V2ActivityInterviewStats?) -> some View {
        breakdownCard(title: "INTERVIEWS") {
            VStack(alignment: .leading, spacing: 6) {
                let avg = stats?.averageScore.map { "\($0)%" } ?? "—"
                let total = (stats?.breakdownByType ?? []).reduce(0) { $0 + ($1.count ?? 0) }
                Text("Avg \(avg) · \(total) done")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let rows = stats?.breakdownByType, !rows.isEmpty {
                    let lines = rows.prefix(4).compactMap { r -> String? in
                        guard let type = r.type else { return nil }
                        let avg = r.avgScore.map { "\($0)%" } ?? "—"
                        let count = r.count ?? 0
                        return "\(type.replacingOccurrences(of: "_", with: " ").capitalized) \(avg) (\(count))"
                    }
                    Text("By type: \(lines.joined(separator: " · "))")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func contentCard(stats: V2ActivityContentStats?) -> some View {
        breakdownCard(title: "CONTENT WATCHED") {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(stats?.totalCompleted ?? 0) done · \(stats?.totalMinutes ?? 0) min")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let inProgress = stats?.inProgress, inProgress > 0 {
                    Text("\(inProgress) in progress")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func aiTutorCard(stats: V2ActivityAITutorStats?) -> some View {
        breakdownCard(title: "AI TUTOR") {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(stats?.totalSessions ?? 0) sessions · \(stats?.totalMessages ?? 0) messages")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }

    private func breakdownCard<Body: View>(title: String, @ViewBuilder body: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .v2Eyebrow(ColorTokens.gold)
            body()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: empty state

    private func emptyState(icon: String, title: String, hint: String?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(title)
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            if let hint = hint {
                Text(hint)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(V2Theme.pad)
    }

    // MARK: format helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let rem = minutes % 60
        if rem == 0 {
            return "\(hours) hr\(hours == 1 ? "" : "s")"
        }
        return "\(hours)h \(rem)m"
    }

    private func emoji(for type: String?) -> String {
        switch type ?? "" {
        case "quiz": return "🧠"
        case "interview": return "🎙"
        case "content": return "🎥"
        case "ai_tutor": return "💬"
        default: return "•"
        }
    }

    private func typeLabel(for type: String?) -> String {
        switch type ?? "" {
        case "quiz": return "Quiz"
        case "interview": return "Interview"
        case "content": return "Content"
        case "ai_tutor": return "AI Tutor"
        default: return "Activity"
        }
    }

    private func timestampLine(for iso: String?) -> String {
        guard let date = V2CompassDate.parse(iso) else { return "" }
        let cal = Calendar.current
        let timeF = DateFormatter()
        timeF.dateFormat = "HH:mm"
        let timeStr = timeF.string(from: date)
        if cal.isDateInToday(date) { return "Today, \(timeStr)" }
        if cal.isDateInYesterday(date) { return "Yesterday, \(timeStr)" }
        let dayF = DateFormatter()
        dayF.dateFormat = "MMM d"
        return "\(dayF.string(from: date)), \(timeStr)"
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return ColorTokens.success }
        if score >= 60 { return ColorTokens.gold }
        return ColorTokens.warning
    }

    private func trendIcon(_ direction: String?) -> String {
        switch (direction ?? "").lowercased() {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private func trendColor(_ direction: String?) -> Color {
        switch (direction ?? "").lowercased() {
        case "improving": return ColorTokens.gold
        case "declining": return ColorTokens.error
        default: return ColorTokens.textSecondary
        }
    }

    private func trendWord(_ direction: String?) -> String {
        switch (direction ?? "").lowercased() {
        case "improving": return "improving"
        case "declining": return "declining"
        case "stable": return "steady"
        default: return "flat"
        }
    }
}
