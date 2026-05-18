import SwiftUI
import Charts

// MARK: - V2 Plan Detail
//
// "Give me confidence the system has planned the right things" surface.
// Driven by GET /api/v2/you/plan/detail (deterministic, no LLM in path).
// Sections: objective + write-up, summary, readiness projection chart,
// milestones, phases, weeks (collapsible w/ tappable tasks), topic coverage,
// completed history.

struct V2PlanDetailView: View {
    @Environment(V2TaskRouter.self) private var taskRouter
    @State private var vm = V2PlanDetailViewModel()
    @State private var expandedWeeks: Set<Int> = []
    @State private var didLoad = false

    public init() {}

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if vm.isLoading && vm.data == nil {
                ProgressView().tint(ColorTokens.gold)
            } else if vm.data == nil, let err = vm.error {
                errorState(err)
            } else if let data = vm.data {
                ScrollView {
                    VStack(alignment: .leading, spacing: V2Theme.pad) {
                        objectiveHeader(data.objective)
                        if let s = data.summary { progressCard(s) }
                        if let weeks = data.weeks, !weeks.isEmpty,
                           let target = data.summary?.targetReadiness {
                            projectionCard(weeks: weeks,
                                           targetReadiness: target,
                                           milestones: data.milestones ?? [])
                        }
                        if let ms = data.milestones, !ms.isEmpty {
                            milestonesCard(ms)
                        }
                        if let ps = data.phases, !ps.isEmpty {
                            phasesSection(ps)
                        }
                        if let ws = data.weeks, !ws.isEmpty {
                            weeksSection(ws)
                        }
                        if let tc = data.topicCoverage, !tc.isEmpty {
                            topicCoverageCard(tc)
                        }
                        if let hist = data.completedHistory, !hist.isEmpty {
                            completedHistoryCard(hist)
                        }
                    }
                    .padding(.horizontal, V2Theme.pad)
                    .padding(.vertical, V2Theme.pad)
                }
                .refreshable { await vm.load() }
            } else {
                emptyState
            }
        }
        .navigationTitle("My plan")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if !didLoad {
                didLoad = true
                await vm.load()
                // Auto-expand the current week.
                if let cur = vm.data?.weeks?.first(where: { $0.isCurrent == true })?.week {
                    expandedWeeks.insert(cur)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func objectiveHeader(_ obj: V2PlanObjective?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR OBJECTIVE").v2Eyebrow()
            Text(obj?.label ?? "Your objective")
                .font(V2Theme.h1)
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let writeUp = obj?.writeUp, !writeUp.isEmpty {
                Text(writeUp)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Progress

    @ViewBuilder
    private func progressCard(_ s: V2PlanSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROGRESS").v2Eyebrow()

            // Headline readiness numbers
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(s.currentReadiness ?? 0)%")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(ColorTokens.gold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("\(s.targetReadiness ?? 0)% target")
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
            }
            if let proj = s.projectedReadiness {
                let projColor: Color = (s.onTrack == true)
                    ? ColorTokens.success
                    : (s.weeksLateVsDeadline ?? 0) > 0 ? ColorTokens.warning : ColorTokens.textSecondary
                Text("Projected \(proj)% at completion")
                    .font(V2Theme.small)
                    .foregroundStyle(projColor)
            }

            // Counts row
            HStack(spacing: 14) {
                countChip(icon: "checkmark.circle.fill", value: "\(s.completedTasks ?? 0)", label: "done", color: ColorTokens.success)
                countChip(icon: "xmark.circle.fill", value: "\(s.skippedTasks ?? 0)", label: "skipped", color: ColorTokens.textTertiary)
                countChip(icon: "list.bullet", value: "\(s.remainingTasks ?? 0)", label: "remaining", color: ColorTokens.gold)
            }

            // Invested vs planned hours
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textSecondary)
                Text("Invested \(formatHours(s.investedHours ?? 0)) of ~\(formatHours(s.estimatedTotalHours ?? 0)) planned")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            // Pace warning
            if let late = s.weeksLateVsDeadline, late > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.warning)
                    Text("Behind by \(late) wk\(late == 1 ? "" : "s") at current pace")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.warning)
                }
            } else if s.onTrack == true {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.success)
                    Text("On track for your goal")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.success)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2Card()
    }

    private func countChip(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
            Text(label)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Readiness projection chart

    private struct ProjectionPoint: Identifiable {
        let id = UUID()
        let week: Int
        let readiness: Int
    }

    @ViewBuilder
    private func projectionCard(weeks: [V2PlanWeek],
                                targetReadiness: Int,
                                milestones: [V2PlanMilestone]) -> some View {
        let points: [ProjectionPoint] = weeks.compactMap {
            guard let w = $0.week, let r = $0.expectedReadinessAtEnd else { return nil }
            return ProjectionPoint(week: w, readiness: r)
        }
        let currentWeek = weeks.first(where: { $0.isCurrent == true })?.week

        VStack(alignment: .leading, spacing: 10) {
            Text("READINESS PROJECTION").v2Eyebrow()
            if points.isEmpty {
                Text("Not enough data to project yet.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
            } else {
                Chart {
                    ForEach(points) { p in
                        AreaMark(
                            x: .value("Week", p.week),
                            y: .value("Readiness", p.readiness)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ColorTokens.gold.opacity(0.45), ColorTokens.gold.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                        LineMark(
                            x: .value("Week", p.week),
                            y: .value("Readiness", p.readiness)
                        )
                        .foregroundStyle(ColorTokens.gold)
                        .lineStyle(StrokeStyle(lineWidth: 2.2))
                        .interpolationMethod(.monotone)
                    }
                    // Target line
                    RuleMark(y: .value("Target", targetReadiness))
                        .foregroundStyle(ColorTokens.success.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Target \(targetReadiness)%")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(ColorTokens.success)
                        }
                    // Current week marker
                    if let cw = currentWeek,
                       let p = points.first(where: { $0.week == cw }) {
                        PointMark(
                            x: .value("Week", p.week),
                            y: .value("Readiness", p.readiness)
                        )
                        .foregroundStyle(ColorTokens.gold)
                        .symbolSize(120)
                    }
                    // Milestone verticals
                    ForEach(milestones) { m in
                        if let w = m.week {
                            RuleMark(x: .value("Milestone", w))
                                .foregroundStyle(ColorTokens.textTertiary.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: 1)) { v in
                        AxisGridLine().foregroundStyle(ColorTokens.surfaceElevated.opacity(0.4))
                        AxisValueLabel {
                            if let w = v.as(Int.self) {
                                Text("W\(w)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                        AxisGridLine().foregroundStyle(ColorTokens.surfaceElevated.opacity(0.4))
                        AxisValueLabel {
                            if let n = v.as(Int.self) {
                                Text("\(n)%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2Card()
    }

    // MARK: - Milestones

    @ViewBuilder
    private func milestonesCard(_ milestones: [V2PlanMilestone]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MILESTONES").v2Eyebrow()
            VStack(spacing: 10) {
                ForEach(milestones) { m in
                    milestoneRow(m)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2Card()
    }

    private func milestoneRow(_ m: V2PlanMilestone) -> some View {
        let isHit = m.isHit == true
        let isCurrent = m.isCurrent == true
        let iconName = isHit ? "checkmark.circle.fill" : (isCurrent ? "circle.dotted" : "circle")
        let iconColor: Color = isHit ? ColorTokens.success : (isCurrent ? ColorTokens.gold : ColorTokens.textTertiary)
        return HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Week \(m.week ?? 0) · \(m.label ?? "")")
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(isCurrent ? ColorTokens.gold : ColorTokens.textPrimary)
                    .lineLimit(2)
                Text("Expected readiness \(m.expectedReadiness ?? 0)%")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrent ? ColorTokens.gold.opacity(0.08) : Color.clear)
        )
    }

    // MARK: - Phases

    @ViewBuilder
    private func phasesSection(_ phases: [V2PlanPhase]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PHASES").v2Eyebrow()
            VStack(spacing: 10) {
                ForEach(phases) { p in
                    phaseCard(p)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phaseCard(_ p: V2PlanPhase) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(p.name?.uppercased() ?? "PHASE") · \(weekRangeLabel(p.weeks))")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(ColorTokens.gold)
            if let focus = p.focus, !focus.isEmpty {
                Text(focus)
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let rationale = p.rationale, !rationale.isEmpty {
                Text(rationale)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2Card(padding: 14)
    }

    private func weekRangeLabel(_ weeks: [Int]?) -> String {
        guard let weeks = weeks, !weeks.isEmpty else { return "" }
        if weeks.count == 1 { return "Week \(weeks[0])" }
        return "Weeks \(weeks.first!)-\(weeks.last!)"
    }

    // MARK: - Weeks (collapsible)

    @ViewBuilder
    private func weeksSection(_ weeks: [V2PlanWeek]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEKS").v2Eyebrow()
            VStack(spacing: 10) {
                ForEach(weeks) { w in
                    weekCard(w)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weekCard(_ w: V2PlanWeek) -> some View {
        let weekNum = w.week ?? 0
        let isExpanded = expandedWeeks.contains(weekNum)
        let isCurrent = w.isCurrent == true

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.18)) {
                    if isExpanded { expandedWeeks.remove(weekNum) }
                    else { expandedWeeks.insert(weekNum) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(width: 14)
                    Text("Week \(weekNum)")
                        .font(V2Theme.h3)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("· \(w.done ?? 0)/\(w.total ?? 0) done")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Spacer()
                    statusBadge(status: w.status, isCurrent: isCurrent)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if let topics = w.focusTopics, !topics.isEmpty {
                        Text("Focus: \(topics.map(prettyTopic).joined(separator: ", "))")
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    if let er = w.expectedReadinessAtEnd {
                        Text("Expected readiness at end: \(er)%")
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    if let notes = w.notes, !notes.isEmpty {
                        Text(notes)
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Divider().background(ColorTokens.surfaceElevated.opacity(0.4))
                    if let tasks = w.tasks, !tasks.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(tasks) { task in
                                taskRow(task)
                            }
                        }
                    } else {
                        Text("No tasks scheduled.")
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .padding(.top, 12)
            }
        }
        .v2Card(padding: 14)
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .strokeBorder(isCurrent ? ColorTokens.gold.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    private func statusBadge(status: String?, isCurrent: Bool) -> some View {
        let label: String
        let color: Color
        if isCurrent {
            label = "CURRENT"; color = ColorTokens.gold
        } else {
            switch status {
            case "done":         label = "DONE";     color = ColorTokens.success
            case "in_progress":  label = "ACTIVE";   color = ColorTokens.gold
            default:             label = "PLANNED";  color = ColorTokens.textTertiary
            }
        }
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Task row

    private func taskRow(_ task: V2PlanTask) -> some View {
        let status = task.status ?? "pending"
        let isComplete = status == "complete"
        let isSkipped = status == "skipped"
        let tappable = !isSkipped && hasRoutablePayload(task)

        let statusIcon: String = isComplete ? "checkmark.circle.fill"
            : isSkipped ? "xmark.circle.fill" : "circle"
        let statusColor: Color = isComplete ? ColorTokens.success
            : isSkipped ? ColorTokens.textTertiary : ColorTokens.gold.opacity(0.7)

        return Button {
            guard tappable else { return }
            Haptics.light()
            openTask(task)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(statusColor)
                Text(taskTypeEmoji(task.type))
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title ?? "Task")
                        .font(V2Theme.bodyMedium)
                        .foregroundStyle(isComplete || isSkipped ? ColorTokens.textSecondary : ColorTokens.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(taskTypeLabel(task.type))
                            .font(V2Theme.small)
                            .fontWeight(.semibold)
                            .tracking(0.4)
                            .foregroundStyle(ColorTokens.gold)
                        if let m = task.estimatedMinutes {
                            Text("·")
                                .font(V2Theme.small)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text("\(m) min")
                                .font(V2Theme.small)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        if let d = task.difficulty, !d.isEmpty {
                            Text("·")
                                .font(V2Theme.small)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text(d)
                                .font(V2Theme.small)
                                .foregroundStyle(difficultyColor(d))
                        }
                    }
                }
                Spacer()
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
    }

    private func difficultyColor(_ d: String) -> Color {
        // Mirrors `V2HomeView.difficultyColor` so Home and Plan Detail
        // render task difficulty with identical color semantics.
        switch d.lowercased() {
        case "hard": return ColorTokens.warning
        case "easy": return ColorTokens.success
        default:     return ColorTokens.textSecondary
        }
    }

    private func hasRoutablePayload(_ task: V2PlanTask) -> Bool {
        guard let p = task.payload else { return false }
        switch task.type {
        case "watch", "listen", "read": return p.contentId != nil
        case "quiz":                    return p.quizId != nil || (task.topic?.isEmpty == false)
        case "interview":               return true
        case "external":                return p.url != nil
        case "compete":                 return true
        default:                        return false
        }
    }

    // Bridge V2PlanTaskPayload -> V2HomeData.Payload (the router's expected type).
    private func bridgePayload(_ p: V2PlanTaskPayload?, topic: String?) -> V2HomeData.Payload {
        V2HomeData.Payload(
            contentId: p?.contentId,
            quizId: p?.quizId,
            interviewId: p?.interviewId,
            url: p?.url,
            weekNumber: nil,
            challengeId: p?.challengeId,
            topic: topic
        )
    }

    private func openTask(_ task: V2PlanTask) {
        let bridged = bridgePayload(task.payload, topic: task.topic)
        taskRouter.open(
            taskType: task.type ?? "",
            payload: bridged,
            title: task.title ?? "Task",
            taskId: task.taskId,
            topic: task.topic
        )
    }

    private func openCompleted(_ item: V2PlanCompletedHistoryItem) {
        // Completed history doesn't carry a full payload — surface as an
        // unavailable route so the user gets a clear "this resource is no
        // longer linkable" sheet rather than a silent no-op.
        guard let type = item.type else { return }
        let bridged = V2HomeData.Payload(
            contentId: nil, quizId: nil, interviewId: nil, url: nil,
            weekNumber: nil, challengeId: nil, topic: item.topic
        )
        taskRouter.open(
            taskType: type,
            payload: bridged,
            title: item.title ?? "Task",
            taskId: item.taskId,
            topic: item.topic
        )
    }

    // MARK: - Topic coverage

    @ViewBuilder
    private func topicCoverageCard(_ coverage: [V2PlanTopicCoverage]) -> some View {
        let sorted = coverage.sorted { ($0.totalMinutes ?? 0) > ($1.totalMinutes ?? 0) }
        VStack(alignment: .leading, spacing: 12) {
            Text("TOPIC COVERAGE").v2Eyebrow()
            VStack(spacing: 14) {
                ForEach(sorted) { tc in
                    topicCoverageRow(tc)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2Card()
    }

    private func topicCoverageRow(_ tc: V2PlanTopicCoverage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tc.displayName ?? prettyTopic(tc.topic ?? ""))
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text("\(tc.taskCount ?? 0) tasks · ~\(tc.totalMinutes ?? 0) min")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            HStack(spacing: 6) {
                Text("\(tc.currentMastery ?? 0)%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(width: 32, alignment: .leading)
                masteryBar(current: tc.currentMastery ?? 0, expected: tc.expectedMastery ?? 0)
                Text("\(tc.expectedMastery ?? 0)%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    private func masteryBar(current: Int, expected: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.surfaceElevated.opacity(0.6))
                Capsule()
                    .fill(ColorTokens.gold.opacity(0.35))
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, expected))) / 100)
                Capsule()
                    .fill(ColorTokens.gold)
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, current))) / 100)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Completed history

    @ViewBuilder
    private func completedHistoryCard(_ history: [V2PlanCompletedHistoryItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPLETED HISTORY").v2Eyebrow()
            VStack(spacing: 8) {
                ForEach(history) { item in
                    completedRow(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2Card()
    }

    private func completedRow(_ item: V2PlanCompletedHistoryItem) -> some View {
        Button {
            Haptics.light()
            openCompleted(item)
        } label: {
            HStack(spacing: 10) {
                Text(shortDate(item.completedAt))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 44, alignment: .leading)
                Text(taskTypeEmoji(item.type))
                    .font(.system(size: 14))
                Text(item.title ?? "Task")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let score = item.score {
                    Text("\(score)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(score >= 70 ? ColorTokens.success : ColorTokens.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((score >= 70 ? ColorTokens.success : ColorTokens.warning).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty / error

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.gold.opacity(0.7))
            Text("Plan not ready yet")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Set an objective to generate your plan.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.warning)
            Text(msg)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
            Button("Try again") { Task { await vm.load() } }
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Formatting helpers

    private func formatHours(_ h: Double) -> String {
        if h == h.rounded() { return "\(Int(h))h" }
        return String(format: "%.1fh", h)
    }

    private func taskTypeEmoji(_ type: String?) -> String {
        switch type {
        case "watch":     return "🎥"
        case "listen":    return "🎧"
        case "read":      return "📖"
        case "quiz":      return "🧠"
        case "interview": return "🎙"
        case "external":  return "🔗"
        case "compete":   return "🏆"
        case "reflection": return "📝"
        case "compass_review": return "🧭"
        default:          return "•"
        }
    }

    /// Uppercase short label for a task type. Mirrors the style used in
    /// `V2HomeView.heroTaskCard` so Plan Detail and Home feel like one system.
    private func taskTypeLabel(_ type: String?) -> String {
        switch (type ?? "").lowercased() {
        case "watch":      return "VIDEO"
        case "read":       return "READ"
        case "listen":     return "LISTEN"
        case "quiz":       return "QUIZ"
        case "interview":  return "INTERVIEW"
        case "compete":    return "CHALLENGE"
        case "reflection": return "REFLECT"
        case "external":   return "LINK"
        case "":           return "TASK"
        default:           return (type ?? "").uppercased()
        }
    }

    private func prettyTopic(_ key: String) -> String {
        key.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private func shortDate(_ iso: String?) -> String {
        guard let iso = iso else { return "" }
        let date = Self.isoFormatter.date(from: iso) ?? Self.isoFormatterNoFrac.date(from: iso)
        guard let d = date else { return "" }
        return Self.shortDateFormatter.string(from: d)
    }
}
