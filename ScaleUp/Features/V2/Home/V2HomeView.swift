import SwiftUI
import Charts

/// V2 Home — the STRUCTURED DAY.
///
/// Not one hero card — a set of plan-aligned tasks for today. The user picks
/// what fits their energy/time. Each task can be started (routes to the v1
/// detail screen) or skipped (the next task from the week slots in). A
/// Reshuffle brings skipped tasks back.
struct V2HomeView: View {
    @State private var vm = V2HomeViewModel()
    @State private var showNotifications = false
    /// Which task is the expanded hero in the active+next-up deck. Tapping
    /// a "next up" row swaps it into this slot.
    @State private var activeTaskIndex: Int = 0
    @Environment(V2TaskRouter.self) private var taskRouter
    @Environment(V2NavState.self) private var nav

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if let data = vm.data {
                        contentSection(data: data)
                    } else if vm.isLoading {
                        loadingSection
                    } else {
                        errorSection
                    }
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.bottom, 120)
            }
            .background(ColorTokens.background.ignoresSafeArea())
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onReceive(NotificationCenter.default.publisher(for: .v2PlanTaskCompleted)) { _ in
            // A task the router auto-completed — refresh so the day reflects it.
            Task { await vm.load() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            ObjectivePill(label: vm.data?.objectiveLabel ?? "Set your objective")
            Spacer()
            Button {
                showNotifications = true
            } label: {
                ZStack {
                    Circle()
                        .fill(ColorTokens.surface)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
            .sheet(isPresented: $showNotifications) {
                NavigationStack {
                    NotificationListView()
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    // MARK: - Main content

    @ViewBuilder
    private func contentSection(data: V2HomeData) -> some View {
        // Greeting
        VStack(alignment: .leading, spacing: 6) {
            Text(data.greeting)
                .font(V2Theme.h1)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(data.statusLine)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.bottom, 20)

        // Trajectory curve — the hero
        if let traj = data.trajectory {
            trajectoryCard(traj: traj, weekProgress: data.weekProgress)
                .padding(.bottom, 16)
        }

        // Streak + weekly rhythm
        if data.streak != nil || data.weekActivity != nil {
            streakStrip(streak: data.streak, days: data.weekActivity ?? [])
                .padding(.bottom, 22)
        }

        // Backlog banner — surfaced above the day when the user is behind on
        // the calendar (plan.createdAt vs current visible week). Tells the
        // user the truth instead of pretending today's set covers everything.
        if (data.behindByWeeks ?? 0) > 0 || (data.pendingPriorCount ?? 0) > 0 {
            backlogBanner(behind: data.behindByWeeks ?? 0,
                          pendingCount: data.pendingPriorCount ?? 0)
                .padding(.bottom, 14)
        }

        // The structured day — active task + compact "next up" rows
        if !vm.visibleTasks.isEmpty {
            todayHeader(data: data)
            activeTaskDeck(tasks: vm.visibleTasks)

            // Reshuffle affordance — only when there are skipped tasks to bring back
            if (data.skippedCount ?? 0) > 0 {
                Button {
                    Task { await vm.reshuffle() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Bring back \(data.skippedCount ?? 0) skipped \((data.skippedCount ?? 0) == 1 ? "task" : "tasks")")
                    }
                    .font(V2Theme.small.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(ColorTokens.gold)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Text("Pick what fits your energy. Skip anything — your plan stays on track.")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            // Pending-from-previous-days carryover — explicit section so the
            // user sees the backlog, not just today's slice. Tappable to open
            // the same way today's tasks do.
            if let pending = data.pendingPriorTasks, !pending.isEmpty {
                pendingPriorSection(tasks: pending)
                    .padding(.top, 26)
            }

            // Always-on "get ahead" set from next week — gives the user
            // *something* to do once today's set is finished without needing
            // a refresh. Renders below today's set + carryover.
            if let getAhead = data.getAheadTasks, !getAhead.isEmpty {
                getAheadSection(tasks: getAhead, week: data.getAheadWeek)
                    .padding(.top, 22)
            }

            // Always-on "for you" recommendations — surfaces extra content
            // even when the user has tasks, so Home never feels empty.
            if !vm.extraContent.isEmpty {
                forYouSection
                    .padding(.top, 28)
            }

        } else if data.fallback == "day_done" {
            dayDoneSection(data: data)
        } else if data.fallback == "plan_brewing" {
            planBrewingFallback
        } else if data.fallback == "no_objective" {
            noObjectiveFallback
        } else {
            // All visible tasks optimistically skipped this session.
            VStack(spacing: 12) {
                Text("That's the set for now.")
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)
                Button("Reshuffle") { Task { await vm.reshuffle() } }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTokens.gold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Today header (count + total time)

    private func todayHeader(data: V2HomeData) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .v2Eyebrow()
            Spacer()
            if let total = data.totalDurationMin {
                Text("\(vm.visibleTasks.count) \(vm.visibleTasks.count == 1 ? "thing" : "things") · ~\(total) min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(.bottom, 10)
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d.lowercased() {
        case "hard": return ColorTokens.warning
        case "easy": return ColorTokens.success
        default:     return ColorTokens.textSecondary
        }
    }

    // MARK: - Trajectory card — readiness curve + week progress

    private func trajectoryCard(traj: V2HomeData.Trajectory, weekProgress: V2HomeData.WeekProgress?) -> some View {
        // Build curve points: prefer server-sent points, else synthesize from
        // today / 30d / 90d / target so there's always *something* to draw.
        let points: [(label: String, value: Int)] = {
            if let pts = traj.points, !pts.isEmpty {
                return pts.map { ($0.whenLabel, $0.readiness) }
            }
            return [
                ("Today",  traj.today),
                ("30d",    traj.in30Days),
                ("Target", traj.atTargetDate),
            ]
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("READINESS")
                    .v2Eyebrow()
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: traj.onTrack ? "arrow.up.right" : "exclamationmark.triangle")
                        .font(.system(size: 9, weight: .bold))
                    Text(traj.onTrack ? "On track" : "Behind pace")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(traj.onTrack ? ColorTokens.success : ColorTokens.warning)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(traj.today)%")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("\(traj.targetReadiness)%")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("target")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Curve
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { idx, point in
                    AreaMark(
                        x: .value("When", idx),
                        y: .value("Readiness", point.value)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [ColorTokens.gold.opacity(0.35), ColorTokens.gold.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("When", idx),
                        y: .value("Readiness", point.value)
                    )
                    .foregroundStyle(ColorTokens.gold)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    PointMark(
                        x: .value("When", idx),
                        y: .value("Readiness", point.value)
                    )
                    .foregroundStyle(ColorTokens.gold)
                    .symbolSize(idx == 0 ? 60 : 30)
                }
            }
            .chartXAxis {
                AxisMarks(values: Array(0..<points.count)) { v in
                    if let i = v.as(Int.self), i < points.count {
                        AxisValueLabel {
                            Text(points[i].label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...100)
            .frame(height: 110)

            if let wp = weekProgress {
                HStack(spacing: 8) {
                    Text("Week \(wp.week) of \(wp.totalWeeks)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text("·")
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("\(wp.done)/\(wp.total) done")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Spacer()
                    Text("▲ \(traj.weeklyDelta)% / week")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Streak strip — weekly rhythm + streak chip

    private func streakStrip(streak: V2HomeData.Streak?, days: [V2HomeData.WeekDayActivity]) -> some View {
        HStack(spacing: 12) {
            // Streak chip
            if let s = streak, s.current > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(s.current == 1 ? "1-day streak" : "\(s.current)-day streak")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(ColorTokens.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(ColorTokens.gold.opacity(0.12)))
                .overlay(Capsule().strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
            } else {
                Text("Start a streak today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            // Weekly grid Mon→Sun
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(day.hadActivity
                                  ? ColorTokens.gold
                                  : (day.isToday ? ColorTokens.gold.opacity(0.25) : ColorTokens.surfaceElevated))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .strokeBorder(day.isToday ? ColorTokens.gold : Color.clear, lineWidth: 1.5)
                                    .frame(width: 12, height: 12)
                            )
                        Text(day.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(day.isToday ? ColorTokens.textPrimary : ColorTokens.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Active task deck — hero + compact "next up" rows

    @ViewBuilder
    private func activeTaskDeck(tasks: [V2HomeData.Task]) -> some View {
        let clampedActive = min(max(0, activeTaskIndex), max(0, tasks.count - 1))
        let active = tasks[clampedActive]
        let others = tasks.enumerated().filter { $0.offset != clampedActive }

        VStack(spacing: 0) {
            heroTaskCard(active)
                .padding(.bottom, 14)

            if !others.isEmpty {
                HStack {
                    Text("NEXT UP")
                        .v2Eyebrow()
                    Spacer()
                }
                .padding(.bottom, 8)

                VStack(spacing: 8) {
                    ForEach(others, id: \.offset) { idx, task in
                        nextUpRow(task, atIndex: idx)
                    }
                }
            }
        }
    }

    private func heroTaskCard(_ task: V2HomeData.Task) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    Task { await vm.markComplete(task.taskId) }
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.icon)
                        Text(task.title)
                            .font(V2Theme.bodyMedium)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    HStack(spacing: 8) {
                        Text("\(task.durationMin) min")
                        if !task.subtitle.isEmpty { Text("· \(task.subtitle)") }
                        Text("· \(task.difficulty.capitalized)")
                            .foregroundStyle(difficultyColor(task.difficulty))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)

                    Text(task.whyText)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.success)
                        .padding(.top, 4)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    taskRouter.open(taskType: task.taskType, payload: task.payload, title: task.title, taskId: task.taskId, topic: task.primaryTopic)
                } label: {
                    HStack {
                        Image(systemName: "play.fill").font(.system(size: 11))
                        Text("Begin")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(ColorTokens.gold)
                    .foregroundStyle(ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await vm.skip(task) }
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(ColorTokens.surfaceElevated.opacity(0.5))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .fill(LinearGradient(
                    colors: [ColorTokens.surface, ColorTokens.surface.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .strokeBorder(ColorTokens.gold.opacity(0.35), lineWidth: 1)
        )
    }

    private func nextUpRow(_ task: V2HomeData.Task, atIndex idx: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                activeTaskIndex = idx
            }
        } label: {
            HStack(spacing: 12) {
                Button {
                    Task { await vm.markComplete(task.taskId) }
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)

                Text(task.icon)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text("\(task.durationMin) min · \(task.difficulty.capitalized)")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTokens.surface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fallbacks

    @ViewBuilder
    private func dayDoneSection(data: V2HomeData) -> some View {
        VStack(spacing: 10) {
            Text("🎉").font(.system(size: 36))
            Text(data.message ?? "You're done for the day.")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text("Want to push further? Here's more, picked from what you've been learning.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            if (data.skippedCount ?? 0) > 0 {
                Button("Reshuffle skipped tasks") { Task { await vm.reshuffle() } }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)

        // Get-ahead — most action-oriented thing on a finished day.
        if let getAhead = data.getAheadTasks, !getAhead.isEmpty {
            getAheadSection(tasks: getAhead, week: data.getAheadWeek)
                .padding(.bottom, 18)
        }

        wantMoreSection
    }

    /// Banner shown when the user is behind their plan. Honest about the
    /// backlog — not framed as cheerful "you're on track".
    private func backlogBanner(behind: Int, pendingCount: Int) -> some View {
        let parts: [String] = {
            var p: [String] = []
            if behind > 0 { p.append(behind == 1 ? "1 week behind" : "\(behind) weeks behind") }
            if pendingCount > 0 { p.append("\(pendingCount) carryover \(pendingCount == 1 ? "task" : "tasks")") }
            return p
        }()
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ColorTokens.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Catching up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(parts.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ColorTokens.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ColorTokens.warning.opacity(0.35), lineWidth: 1)
        )
    }

    /// "Pending from previous days" — carryover tasks the user hasn't done
    /// yet. Rendered as compact tappable rows below today's set.
    private func pendingPriorSection(tasks: [V2HomeData.Task]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PENDING FROM PREVIOUS DAYS").v2Eyebrow()
                Spacer()
                Text("\(tasks.count) \(tasks.count == 1 ? "task" : "tasks")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            VStack(spacing: 8) {
                ForEach(Array(tasks.enumerated()), id: \.element.taskId) { _, task in
                    pendingPriorRow(task)
                }
            }
        }
    }

    private func pendingPriorRow(_ task: V2HomeData.Task) -> some View {
        Button {
            taskRouter.open(
                taskType: task.taskType,
                payload: task.payload,
                title: task.title,
                taskId: task.taskId,
                topic: task.primaryTopic
            )
        } label: {
            HStack(spacing: 10) {
                Text(task.icon).font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text("\(task.durationMin) min · \(task.difficulty.capitalized)")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ColorTokens.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// "Get ahead" — next week's first 3 tasks, always available so the user
    /// has an action item even after today's set is done.
    private func getAheadSection(tasks: [V2HomeData.Task], week: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("GET AHEAD").v2Eyebrow()
                if let w = week {
                    Text("· Week \(w)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
            }
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    pendingPriorRow(task)
                }
            }
        }
    }

    /// Always-on "for you" rail — content suggestions surfaced alongside
    /// today's tasks, so Home has browsable material even on a light day.
    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FOR YOU").v2Eyebrow()
                Spacer()
                Button {
                    nav.selectedTab = .learn
                } label: {
                    Text("See all →")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 8) {
                ForEach(vm.extraContent) { item in
                    extraContentRow(item)
                }
            }
        }
    }

    /// "Want more?" — recommendations + CTAs to keep going beyond the planned day.
    private var wantMoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WANT MORE?").v2Eyebrow()
                Spacer()
                if vm.isLoadingExtras {
                    ProgressView().scaleEffect(0.7).tint(ColorTokens.gold)
                }
            }

            if !vm.extraContent.isEmpty {
                VStack(spacing: 8) {
                    ForEach(vm.extraContent) { item in
                        extraContentRow(item)
                    }
                }
                .padding(.bottom, 4)
            }

            HStack(spacing: 8) {
                Button {
                    nav.compassSheetOpen = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold))
                        Text("Generate a quiz")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(ColorTokens.gold)
                    .foregroundStyle(ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    nav.selectedTab = .learn
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical.fill").font(.system(size: 11, weight: .semibold))
                        Text("Browse Learn")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(ColorTokens.surface)
                    .foregroundStyle(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .task { await vm.loadExtrasIfNeeded() }
    }

    private func extraContentRow(_ item: Content) -> some View {
        Button {
            taskRouter.open(
                taskType: "watch",
                payload: .init(contentId: item.id, quizId: nil, interviewId: nil, url: nil),
                title: item.title,
                taskId: nil,
                topic: item.topics?.first
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: contentIcon(item))
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 32, height: 32)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text(contentMeta(item))
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func contentIcon(_ item: Content) -> String {
        switch item.contentType {
        case .video:       return "play.fill"
        case .notes:       return "doc.text.fill"
        case .article:     return "newspaper.fill"
        case .infographic: return "chart.bar.doc.horizontal.fill"
        }
    }

    private func contentMeta(_ item: Content) -> String {
        var parts: [String] = []
        if let d = item.duration, d > 0 { parts.append("\(d / 60) min") }
        if let topic = item.topics?.first, !topic.isEmpty { parts.append(topic.capitalized) }
        else if let domain = item.domain, !domain.isEmpty { parts.append(domain.capitalized) }
        return parts.joined(separator: " · ")
    }

    private var planBrewingFallback: some View {
        VStack(spacing: 12) {
            ProgressView().tint(ColorTokens.gold)
            Text("Your plan is being personalized.")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("This usually takes under a minute — pull to refresh.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var noObjectiveFallback: some View {
        VStack(spacing: 14) {
            Text("Let's set up your goal")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("About 10 minutes. Worth it.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading your day…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var errorSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.warning)
            Text(vm.error ?? "Something went wrong.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await vm.load() } }
                .buttonStyle(.bordered)
                .tint(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Objective Pill

private struct ObjectivePill: View {
    let label: String
    var body: some View {
        HStack(spacing: 8) {
            Text("🎯").font(.system(size: 12))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(ColorTokens.surface))
        .overlay(Capsule().strokeBorder(V2Theme.cardBorder, lineWidth: 1))
    }
}

#Preview {
    V2HomeView()
        .environment(V2TaskRouter())
        .environment(V2NavState())
        .preferredColorScheme(.dark)
}
