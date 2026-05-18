import SwiftUI
import Charts

/// V2 Home — the PLAN COCKPIT.
///
/// Section flow (top → bottom):
///   1. Header strip       — inline greeting + objective pill + bell
///   2. Status bar         — eyebrow + "{current}% → {target}% needed" + conditional sub-line
///                            (tap → full trajectory chart sheet)
///   3. TODAY              — hero task card + "ALSO TODAY · n more" compact rows
///   4. YOUR PLAN          — multi-week dots strip + cursor + streak/cohort footer
///   5. PENDING / GET AHEAD / PUSH HARDER — 3-chip row, tap to expand inline
///   6. FOR YOU            — small content rail → routes to Learn
struct V2HomeView: View {
    @State private var vm = V2HomeViewModel()
    @State private var showNotifications = false
    /// Local UI set: taskIds for which the completion button has been tapped.
    @State private var completing: Set<String> = []
    /// Controls the trajectory drill-down sheet (presented when the user taps
    /// the status bar).
    @State private var showTrajectorySheet = false
    /// Controls the info popover for the "what does readiness mean" hint.
    @State private var showReadinessInfo = false
    /// Tap "Talk to Coach to recalibrate" → opens Compass Coach sheet.
    @State private var showCoachSheet = false
    /// YOUR PLAN tap → presents the full multi-week timeline as a sheet.
    @State private var showPlanSheet = false
    /// Which of the three lower chips (pending / get-ahead / push-harder) is
    /// currently expanded inline. Only one at a time — tapping another
    /// collapses the current and opens the new.
    @State private var expandedChip: HomeChip?
    @Environment(V2TaskRouter.self) private var taskRouter
    @Environment(V2NavState.self) private var nav
    @Environment(AppState.self) private var appState

    private enum HomeChip: String, Identifiable {
        case pending, getAhead, pushHarder
        var id: String { rawValue }
    }

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
            Task { await vm.load() }
        }
        // Status-bar drill-down: tap the readiness line → see the full
        // trajectory chart in a sheet. Keeps Home clean.
        .sheet(isPresented: $showTrajectorySheet) {
            if let traj = vm.data?.trajectory {
                NavigationStack {
                    TrajectorySheetView(traj: traj)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        // YOUR PLAN tap → full multi-week timeline as a sheet.
        .sheet(isPresented: $showPlanSheet) {
            if let sched = vm.data?.planSchedule {
                NavigationStack {
                    PlanScheduleSheetView(
                        sched: sched,
                        weekProgress: vm.data?.weekProgress,
                        streak: vm.data?.streak
                    )
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        // "Open Coach to recalibrate" tap on the status warning.
        .sheet(isPresented: $showCoachSheet) {
            V2CompassSheetView(
                currentScreen: .home,
                coachContext: CompassCoachContext(scope: nil, topic: nil)
            )
            .environment(taskRouter)
            .environment(appState)
            .environment(nav)
        }
    }

    // MARK: - Header strip (inline greeting + objective pill + bell)

    private var header: some View {
        HStack(spacing: 10) {
            Text(inlineGreeting)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            ObjectivePill(label: vm.data?.objectiveLabel ?? "Set your objective")
            Button {
                showNotifications = true
            } label: {
                ZStack {
                    Circle()
                        .fill(ColorTokens.surface)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12))
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
        .padding(.bottom, 16)
    }

    /// Compact, inline greeting — "Hi, Claude." — derived from the backend's
    /// "Hi, X." string. Falls back gracefully if shape differs.
    private var inlineGreeting: String {
        let raw = vm.data?.greeting ?? "Hi."
        // Backend always returns "Hi, {firstName}." — keep as-is.
        return raw
    }

    // MARK: - Main content

    @ViewBuilder
    private func contentSection(data: V2HomeData) -> some View {
        // 2. Status bar (REPLACES the big readiness card)
        if let traj = data.trajectory {
            statusBar(traj: traj, data: data)
                .padding(.bottom, 22)
        }

        // 3. TODAY — hero + compact rows
        if !vm.visibleTasks.isEmpty {
            todaySection(data: data, tasks: vm.visibleTasks)
                .padding(.bottom, 22)
        } else if data.fallback == "day_done" {
            dayDoneCompactSection(data: data)
                .padding(.bottom, 22)
        } else if data.fallback == "plan_brewing" {
            planBrewingFallback
                .padding(.bottom, 22)
        } else if data.fallback == "no_objective" {
            noObjectiveFallback
                .padding(.bottom, 22)
        } else {
            emptyTodaySection
                .padding(.bottom, 22)
        }

        // 4. YOUR PLAN — multi-week timeline (only when we have schedule data)
        if let sched = data.planSchedule, !sched.isEmpty {
            planTimelineSection(sched: sched, weekProgress: data.weekProgress, streak: data.streak)
                .padding(.bottom, 22)
        }

        // 5. PENDING / GET AHEAD / PUSH HARDER — 3-chip row + inline expansion
        chipRow(data: data)
            .padding(.bottom, 22)

        // 6. FOR YOU
        if !vm.extraContent.isEmpty {
            forYouSection
                .padding(.bottom, 8)
        }
    }

    // MARK: - 2. Status bar

    @ViewBuilder
    private func statusBar(traj: V2HomeData.Trajectory, data: V2HomeData) -> some View {
        let eyebrow = "\(data.objectiveName ?? "GOAL") READINESS"

        VStack(alignment: .leading, spacing: 8) {
            // Top row: eyebrow + info icon (sibling buttons — info has its
            // own tap target, not nested inside the readiness button).
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow)
                    .v2Eyebrow()
                Spacer()
                Button {
                    showReadinessInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showReadinessInfo) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What is readiness?")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("Readiness is how prepared you are to crush your goal. It's a score from 0–100% based on your diagnostic results and weekly progress.")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.textSecondary)
                            Text("80% is the threshold most people need to hit their target. Above that, your odds of success climb sharply.")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.textSecondary)
                            Spacer()
                            Button { showReadinessInfo = false } label: {
                                Text("Got it")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ColorTokens.background)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(ColorTokens.gold)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                        .presentationDetents([.fraction(0.35)])
                        .presentationDragIndicator(.visible)
                    }
                }

            // Big-numbers row IS the trajectory tap target — separate from
            // the sub-line below so the "Open Coach" link gets its own tap.
            Button {
                showTrajectorySheet = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(traj.today)%")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("\(traj.targetReadiness)% needed")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            statusSubLine(traj: traj)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    /// Conditional sub-line under the status numbers. Only renders when
    /// actionable — on-track silently shows nothing so the card stays small.
    @ViewBuilder
    private func statusSubLine(traj: V2HomeData.Trajectory) -> some View {
        if traj.targetHit == true {
            statusSubRow(icon: "checkmark.circle.fill",
                         color: ColorTokens.success,
                         text: "You've hit your goal. Push for more?")
        } else if traj.paceCategory == "ahead",
                  let early = traj.earlyByWeeks, early > 0 {
            statusSubRow(icon: "bolt.fill",
                         color: ColorTokens.success,
                         text: "Ahead of pace — projected \(early) week\(early == 1 ? "" : "s") early")
        } else if traj.projectedAfterDeadline == true,
                  let late = traj.weeksLateVsDeadline, late > 0 {
            statusSubRow(icon: "exclamationmark.triangle.fill",
                         color: ColorTokens.warning,
                         text: "Behind: at this pace, \(late) wk\(late == 1 ? "" : "s") past deadline.",
                         actionLabel: "Open Coach to recalibrate →",
                         action: { showCoachSheet = true })
        } else if traj.paceCategory == "behind",
                  let weeks = traj.weeksToTarget, weeks > 0 {
            statusSubRow(icon: "clock.fill",
                         color: ColorTokens.warning,
                         text: "\(weeks) wk\(weeks == 1 ? "" : "s") to hit target at this pace.",
                         actionLabel: "Open Coach to plan a push →",
                         action: { showCoachSheet = true })
        }
        // On-track with no other signal — render nothing. Less noise.
    }

    private func statusSubRow(
        icon: String,
        color: Color,
        text: String,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                    .padding(.top, 1)
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            if let label = actionLabel, let action = action {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.leading, 17)
            }
        }
    }

    // MARK: - 3. TODAY

    @ViewBuilder
    private func todaySection(data: V2HomeData, tasks: [V2HomeData.Task]) -> some View {
        let weekday = currentWeekdayShort()
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY · \(weekday)").v2Eyebrow()
                Spacer()
                if let total = data.totalDurationMin {
                    Text("\(tasks.count) · ~\(total) min")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            heroTaskCard(tasks[0])

            if tasks.count > 1 {
                let rest = Array(tasks.dropFirst())
                HStack {
                    Text("ALSO TODAY · \(rest.count) more").v2Eyebrow(ColorTokens.textTertiary)
                    Spacer()
                }
                .padding(.top, 4)

                VStack(spacing: 8) {
                    ForEach(rest) { task in
                        compactTaskRow(task)
                    }
                }
            }
        }
    }

    private var emptyTodaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY").v2Eyebrow()
            Text("All done for today — see Pending or Get Ahead below.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func heroTaskCard(_ task: V2HomeData.Task) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(typeColorFor(task.taskType).opacity(0.15))
                        .frame(width: 56, height: 56)
                    Text(task.icon).font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(typeLabelFor(task.taskType))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(typeColorFor(task.taskType))
                    Text(task.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text("\(task.durationMin) min")
                        if !task.subtitle.isEmpty { Text("· \(task.subtitle)") }
                        Text("· \(difficultyLabel(task.difficulty))")
                            .foregroundStyle(difficultyColor(task.difficulty))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer(minLength: 0)
            }

            Text(task.whyText)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.success)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    taskRouter.open(taskType: task.taskType,
                                    payload: task.payload,
                                    title: task.title,
                                    taskId: task.taskId,
                                    topic: task.primaryTopic)
                } label: {
                    HStack {
                        Image(systemName: "play.fill").font(.system(size: 12))
                        Text("Start").font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(ColorTokens.gold)
                    .foregroundStyle(ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await vm.skip(task) }
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(ColorTokens.surfaceElevated.opacity(0.5))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .fill(LinearGradient(
                    colors: [ColorTokens.surface, ColorTokens.surface.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .strokeBorder(ColorTokens.gold.opacity(0.30), lineWidth: 1)
        )
    }

    /// Compact "also today" row — minimal, tappable, opens via taskRouter.
    private func compactTaskRow(_ task: V2HomeData.Task) -> some View {
        Button {
            taskRouter.open(taskType: task.taskType,
                            payload: task.payload,
                            title: task.title,
                            taskId: task.taskId,
                            topic: task.primaryTopic)
        } label: {
            HStack(spacing: 10) {
                Text(task.icon).font(.system(size: 16))
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(task.durationMin) min")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(ColorTokens.surface.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. THIS WEEK (compact card; tap → full multi-week sheet)

    /// Collapsed Home card — current week only. Tapping opens the full
    /// multi-week schedule sheet (`PlanScheduleSheetView`) so the dense
    /// timeline stays out of the way until the user asks for it.
    private func planTimelineSection(
        sched: [V2HomeData.PlanWeek],
        weekProgress: V2HomeData.WeekProgress?,
        streak: V2HomeData.Streak?
    ) -> some View {
        let currentWeek = sched.first(where: { $0.isCurrent == true }) ?? sched.first
        return Button { showPlanSheet = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("THIS WEEK").v2Eyebrow()
                    Spacer()
                    if let wp = weekProgress {
                        Text("Week \(wp.week) of \(wp.totalWeeks)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                if let wk = currentWeek {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(wk.done) of \(wk.total) done")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        if let skipped = wk.skipped, skipped > 0 {
                            Text("· \(skipped) skipped")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        Spacer()
                    }

                    // One inline row of dots for THIS week's task count
                    // (capped at 10 dots for layout sanity on big weeks).
                    let dots = min(wk.total, 10)
                    let filled = min(wk.done, dots)
                    HStack(spacing: 5) {
                        ForEach(0..<dots, id: \.self) { i in
                            Circle()
                                .fill(i < filled ? ColorTokens.gold : ColorTokens.surfaceElevated)
                                .frame(width: 8, height: 8)
                        }
                        Spacer(minLength: 0)
                    }
                }

                // Footer row — streak + "view all weeks" hint.
                HStack(spacing: 10) {
                    if let s = streak, s.current > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.gold)
                            Text("\(s.current)-day streak")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("Tap for all weeks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .fill(ColorTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func planWeekColumn(_ wk: V2HomeData.PlanWeek) -> some View {
        // Render `total` dots, first `done` filled. Cap dots displayed at 8 so
        // very long weeks don't blow up the strip width.
        let maxDots = min(wk.total, 8)
        let doneVisible = min(wk.done, maxDots)
        let isCurrent = wk.isCurrent == true
        return VStack(spacing: 6) {
            Text("W\(wk.week)")
                .font(.system(size: 10, weight: isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent ? ColorTokens.gold : ColorTokens.textTertiary)
            VStack(spacing: 3) {
                ForEach(0..<maxDots, id: \.self) { i in
                    Circle()
                        .fill(i < doneVisible ? ColorTokens.gold : ColorTokens.surfaceElevated)
                        .frame(width: 6, height: 6)
                }
            }
            if isCurrent {
                Rectangle()
                    .fill(ColorTokens.gold)
                    .frame(width: 18, height: 2)
                    .clipShape(Capsule())
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 18, height: 2)
            }
        }
    }

    // MARK: - 5. 3-chip row (PENDING / GET AHEAD / PUSH HARDER)

    @ViewBuilder
    private func chipRow(data: V2HomeData) -> some View {
        let pendingCount = data.pendingPriorCount ?? 0
        let pending = data.pendingPriorTasks ?? []
        let getAhead = data.getAheadTasks ?? []
        let bonus = data.bonusTasks ?? []

        let showPending = pendingCount > 0 && !pending.isEmpty
        let showGetAhead = !getAhead.isEmpty
        // Push Harder always renders — even with no bonus tasks it shows a
        // "no bonus picks right now" empty-state when expanded.
        let showPush = true

        VStack(alignment: .leading, spacing: 10) {
            // Three chips on one row — each with a captioned subtitle so the
            // user knows what tapping it does (Pending vs Get Ahead vs Push).
            HStack(alignment: .top, spacing: 10) {
                if showPending {
                    chipWithCaption(
                        label: "PENDING (\(pendingCount))",
                        caption: "Catch up from earlier",
                        icon: "pin.fill",
                        tint: ColorTokens.warning,
                        chip: .pending
                    )
                }
                if showGetAhead {
                    chipWithCaption(
                        label: "GET AHEAD",
                        caption: data.getAheadWeek.map { "Start Week \($0) early" } ?? "Start next week early",
                        icon: "arrow.up.right",
                        tint: ColorTokens.gold,
                        chip: .getAhead
                    )
                }
                if showPush {
                    chipWithCaption(
                        label: "PUSH HARDER",
                        caption: "Bonus picks & challenges",
                        icon: "plus",
                        tint: ColorTokens.success,
                        chip: .pushHarder
                    )
                }
                Spacer(minLength: 0)
            }

            // Inline expansion — animated reveal.
            if let expanded = expandedChip {
                expandedChipBody(expanded, pending: pending, getAhead: getAhead, bonus: bonus,
                                 getAheadWeek: data.getAheadWeek)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Chip + caption block — vertical stack of the chip pill and a one-line
    /// caption directly beneath so the affordance is self-explanatory.
    private func chipWithCaption(
        label: String,
        caption: String,
        icon: String,
        tint: Color,
        chip: HomeChip
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            chipButton(label: label, icon: icon, tint: tint, chip: chip)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chipButton(label: String, icon: String, tint: Color, chip: HomeChip) -> some View {
        let isOpen = expandedChip == chip
        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                expandedChip = isOpen ? nil : chip
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(isOpen ? ColorTokens.background : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isOpen ? tint : tint.opacity(0.10))
            )
            .overlay(
                Capsule().strokeBorder(tint.opacity(isOpen ? 0 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func expandedChipBody(
        _ chip: HomeChip,
        pending: [V2HomeData.Task],
        getAhead: [V2HomeData.Task],
        bonus: [V2HomeData.Task],
        getAheadWeek: Int?
    ) -> some View {
        switch chip {
        case .pending:
            VStack(spacing: 6) {
                ForEach(pending) { compactTaskRow($0) }
            }
        case .getAhead:
            VStack(alignment: .leading, spacing: 6) {
                if let w = getAheadWeek {
                    Text("From Week \(w)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                ForEach(getAhead) { compactTaskRow($0) }
            }
        case .pushHarder:
            if bonus.isEmpty {
                Text("No bonus picks right now. Pull to refresh.")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(bonus) { compactTaskRow($0) }
                }
            }
        }
    }

    // MARK: - 6. FOR YOU

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FOR YOU · Quick picks from Learn").v2Eyebrow()
                Spacer()
                Button {
                    nav.selectedTab = .learn
                } label: {
                    Text("More →")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.extraContent) { item in
                        extraContentCard(item)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func extraContentCard(_ item: Content) -> some View {
        Button {
            taskRouter.open(
                taskType: "watch",
                payload: .init(contentId: item.id, quizId: nil, interviewId: nil, url: nil, weekNumber: nil, challengeId: nil, topic: nil),
                title: item.title,
                taskId: nil,
                topic: item.topics?.first
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: contentIcon(item))
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(contentMeta(item))
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 160, alignment: .leading)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fallbacks (day_done / plan_brewing / no_objective)

    @ViewBuilder
    private func dayDoneCompactSection(data: V2HomeData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY").v2Eyebrow()
            Text(data.message ?? "You're done for today.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
            if (data.skippedCount ?? 0) > 0 {
                Button("Bring back skipped tasks") { Task { await vm.reshuffle() } }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.top, 2)
            }
        }
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

    // MARK: - Utilities

    private func currentWeekdayShort() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: Date())
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d.lowercased() {
        case "hard": return ColorTokens.warning
        case "easy": return ColorTokens.success
        default:     return ColorTokens.textSecondary
        }
    }

    private func difficultyLabel(_ diff: String) -> String {
        switch diff.lowercased() {
        case "easy":   return "Easy"
        case "medium": return "Standard"
        case "hard":   return "Challenging"
        default:       return diff.capitalized
        }
    }

    private func typeLabelFor(_ taskType: String) -> String {
        switch taskType.lowercased() {
        case "quiz":        return "QUIZ"
        case "compete":     return "COMPETE"
        case "interview":   return "MOCK INTERVIEW"
        case "watch":       return "WATCH"
        case "read":        return "READ"
        case "external":    return "EXTERNAL LINK"
        case "reflection":  return "REFLECTION"
        default:            return taskType.uppercased()
        }
    }

    private func typeColorFor(_ taskType: String) -> Color {
        switch taskType.lowercased() {
        case "quiz":        return ColorTokens.gold
        case "compete":     return ColorTokens.warning
        case "interview":   return ColorTokens.info
        case "watch":       return ColorTokens.success
        case "read":        return ColorTokens.textSecondary
        default:            return ColorTokens.textTertiary
        }
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
}

// MARK: - Trajectory Sheet (drill-down from status bar tap)

/// Full readiness trajectory chart, presented in a sheet when the user taps the
/// compact status bar on Home. Keeps Home clean while giving casual users
/// access to the detail.
// MARK: - PlanScheduleSheetView (full multi-week timeline drill-down)

/// Sheet host for the dense multi-week schedule. Mirrors the column-strip
/// pattern the Home card used before it was collapsed to "THIS WEEK only".
private struct PlanScheduleSheetView: View {
    let sched: [V2HomeData.PlanWeek]
    let weekProgress: V2HomeData.WeekProgress?
    let streak: V2HomeData.Streak?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let wp = weekProgress {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Week \(wp.week) of \(wp.totalWeeks)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("\(wp.done) of \(wp.total) tasks done this week")
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }

                Text("ALL WEEKS").v2Eyebrow()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(sched) { wk in
                            VStack(spacing: 8) {
                                Text("W\(wk.week)")
                                    .font(.system(size: 12, weight: wk.isCurrent == true ? .bold : .medium))
                                    .foregroundStyle(wk.isCurrent == true ? ColorTokens.gold : ColorTokens.textTertiary)
                                VStack(spacing: 4) {
                                    let dots = min(wk.total, 10)
                                    let filled = min(wk.done, dots)
                                    ForEach(0..<dots, id: \.self) { i in
                                        Circle()
                                            .fill(i < filled ? ColorTokens.gold : ColorTokens.surfaceElevated)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                Text("\(wk.done)/\(wk.total)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ColorTokens.textSecondary)
                                if wk.isCurrent == true {
                                    Rectangle()
                                        .fill(ColorTokens.gold)
                                        .frame(width: 22, height: 2)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                if let s = streak, s.current > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.gold)
                        Text("\(s.current)-day streak · longest \(s.longest)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("Your plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(ColorTokens.gold)
            }
        }
    }
}

private struct TrajectorySheetView: View {
    let traj: V2HomeData.Trajectory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(traj.today)%")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("\(traj.targetReadiness)% target")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }

                chart
                    .frame(height: 200)

                metricsBlock
            }
            .padding(20)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("Readiness trajectory")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var points: [(label: String, value: Int)] {
        if let pts = traj.points, !pts.isEmpty {
            return pts.map { ($0.whenLabel, $0.readiness) }
        }
        return [
            ("Today",  traj.today),
            ("30d",    traj.in30Days),
            ("Target", traj.atTargetDate),
        ]
    }

    private var chart: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { idx, point in
                AreaMark(
                    x: .value("When", idx),
                    y: .value("Readiness", point.value)
                )
                .foregroundStyle(LinearGradient(
                    colors: [ColorTokens.gold.opacity(0.32), ColorTokens.gold.opacity(0.02)],
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
                .symbolSize(idx == 0 ? 70 : 35)
            }
        }
        .chartXAxis {
            AxisMarks(values: Array(0..<points.count)) { v in
                if let i = v.as(Int.self), i < points.count {
                    AxisValueLabel {
                        Text(points[i].label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
    }

    @ViewBuilder
    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            metricRow(label: "Current readiness", value: "\(traj.today)%")
            metricRow(label: "Target", value: "\(traj.targetReadiness)%")
            if let d = traj.projectedTargetDate {
                metricRow(label: "Projected to hit target", value: formatEta(d) ?? d)
            }
            if let weeks = traj.weeksToTarget {
                metricRow(label: "Weeks at current pace", value: "\(weeks)")
            }
            if let real = traj.realTasksPerWeek {
                metricRow(label: "Tasks/week (measured)", value: String(format: "%.1f", real))
            } else {
                metricRow(label: "Tasks/week (est.)", value: String(format: "%.1f", traj.weeklyDelta))
            }
            if traj.projectedAfterDeadline == true, let late = traj.weeksLateVsDeadline {
                Text("At this pace you'd hit target ~\(late) week\(late == 1 ? "" : "s") past your deadline. Push harder or extend the timeline.")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.warning)
                    .padding(.top, 4)
            } else if traj.targetHit == true {
                Text("You've hit your target. Stretch for more if you want.")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.success)
                    .padding(.top, 4)
            }
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }

    private func formatEta(_ iso: String) -> String? {
        let isoF = ISO8601DateFormatter()
        isoF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoF.date(from: iso) ?? {
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return plain.date(from: iso)
        }()
        guard let d = date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: d)
    }
}

// MARK: - Objective Pill

private struct ObjectivePill: View {
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Text("🎯").font(.system(size: 11))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
