import SwiftUI
import Charts

/// V2 Home — the STRUCTURED DAY.
///
/// Six-section flow in order:
///   1. Readiness card — where am I + on-track badge + trajectory + streak
///   2. Weekly insight — what to focus on this week and why
///   3. Focus today — hero task + compact next-up rows
///   4. Get Ahead — collapsed chip → sheet
///   5. Pending from previous days — only when non-empty
///   6. For You — always-on content rail at the bottom
struct V2HomeView: View {
    @State private var vm = V2HomeViewModel()
    @State private var showNotifications = false
    /// Which task is the expanded hero in the active+next-up deck. Tapping
    /// a "next up" row swaps it into this slot.
    @State private var activeTaskIndex: Int = 0
    /// Local UI set: taskIds for which the completion button has been tapped.
    @State private var completing: Set<String> = []
    /// Controls the info popover on the trajectory card's target %.
    @State private var showTargetInfo = false
    /// Controls the Get Ahead full-list sheet.
    @State private var showGetAheadSheet = false
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
        // Greeting — just the name, no action hint (insight card handles "what to focus on")
        VStack(alignment: .leading, spacing: 4) {
            Text(data.greeting)
                .font(V2Theme.h1)
                .foregroundStyle(ColorTokens.textPrimary)

            // Status line ONLY when there's no insight card to take its place
            // (e.g., no_objective / plan_brewing fallback states). When an
            // insight is present, it's the canonical "why this week matters"
            // surface — duplicating the status line on top of it confuses the
            // user about which message to trust.
            if (data.weeklyInsight ?? "").isEmpty {
                Text(data.statusLine)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(.bottom, 22)

        // ── Section 1: Consolidated readiness card ──
        if let traj = data.trajectory {
            readinessCard(traj: traj, weekProgress: data.weekProgress,
                          streak: data.streak, days: data.weekActivity ?? [])
                .padding(.bottom, 22)
        }

        // ── Section 2: Weekly insight ──
        if let insight = data.weeklyInsight, !insight.isEmpty {
            insightCard(insight: insight)
                .padding(.bottom, 22)
        }

        // Backlog banner — behind by weeks or carryover count
        if (data.behindByWeeks ?? 0) > 0 || (data.pendingPriorCount ?? 0) > 0 {
            backlogBanner(behind: data.behindByWeeks ?? 0,
                          pendingCount: data.pendingPriorCount ?? 0)
                .padding(.bottom, 14)
        }

        // ── Section 3: Focus today ──
        if !vm.visibleTasks.isEmpty {
            todayHeader(data: data)
            activeTaskDeck(tasks: vm.visibleTasks)

            // Reshuffle affordance
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

            // ── Section 5: Pending from previous days (only when non-empty) ──
            if let pending = data.pendingPriorTasks, !pending.isEmpty {
                pendingPriorSection(tasks: pending)
                    .padding(.top, 22)
            }

            // ── Section 4: Get Ahead — collapsed chip by default ──
            if let getAhead = data.getAheadTasks, !getAhead.isEmpty {
                getAheadChip(tasks: getAhead, week: data.getAheadWeek)
                    .padding(.top, 22)
            }

            // ── Section 6: For You ──
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

    // MARK: - Section 1: Consolidated readiness card

    private func readinessCard(
        traj: V2HomeData.Trajectory,
        weekProgress: V2HomeData.WeekProgress?,
        streak: V2HomeData.Streak?,
        days: [V2HomeData.WeekDayActivity]
    ) -> some View {
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
            // ── Row 1: eyebrow + pace badge ──
            HStack(alignment: .firstTextBaseline) {
                Text("READINESS")
                    .v2Eyebrow()
                Spacer()
                paceBadge(traj: traj)
            }

            // ── Row 2: hero number + target ──
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(traj.today)%")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                HStack(spacing: 4) {
                    Text("\(traj.targetReadiness)%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                    Button { showTargetInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTargetInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why \(traj.targetReadiness)%?")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("80% is the readiness threshold to crush your goal at a high success rate. Higher is great but not required — most top performers don't max every competency. You can keep grinding past 80% if you want.")
                                .font(.system(size: 13))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: 280)
                        .presentationCompactAdaptation(.popover)
                    }
                }
                Text("target")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // ── Chart (contextual, not the lead) ──
            HStack {
                Text("% ready over time")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                Spacer()
            }
            .padding(.bottom, 2)

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { idx, point in
                    AreaMark(
                        x: .value("When", idx),
                        y: .value("Readiness", point.value)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [ColorTokens.gold.opacity(0.28), ColorTokens.gold.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("When", idx),
                        y: .value("Readiness", point.value)
                    )
                    .foregroundStyle(ColorTokens.gold)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                    PointMark(
                        x: .value("When", idx),
                        y: .value("Readiness", point.value)
                    )
                    .foregroundStyle(ColorTokens.gold)
                    .symbolSize(idx == 0 ? 50 : 25)
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
            .frame(height: 80)

            Divider()
                .background(V2Theme.cardBorder)

            // ── Projected ETA line — adaptive pace context ──
            projectedEtaLine(traj: traj)

            // ── Footer row: week progress + streak + velocity ──
            HStack(spacing: 0) {
                if let wp = weekProgress {
                    Text("Week \(wp.week) of \(wp.totalWeeks)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text(" · ")
                        .foregroundStyle(ColorTokens.textTertiary)
                        .font(.system(size: 11))
                    Text("\(wp.done)/\(wp.total) done")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text(" · ")
                        .foregroundStyle(ColorTokens.textTertiary)
                        .font(.system(size: 11))
                }

                // Streak
                if let s = streak, s.current > 0 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.gold)
                    Text(" \(s.current)-day streak")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                } else {
                    Text("No streak yet")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                // Velocity badge — source-labelled
                velocityBadge(traj: traj)
            }

            // ── Week dots (Mon–Sun) — compact, inside card ──
            if !days.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 3) {
                            Circle()
                                .fill(day.hadActivity
                                      ? ColorTokens.gold
                                      : (day.isToday ? ColorTokens.gold.opacity(0.25) : ColorTokens.surfaceElevated))
                                .frame(width: 7, height: 7)
                                .overlay(
                                    Circle()
                                        .strokeBorder(day.isToday ? ColorTokens.gold : Color.clear, lineWidth: 1.5)
                                        .frame(width: 11, height: 11)
                                )
                            Text(day.label)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(day.isToday ? ColorTokens.textPrimary : ColorTokens.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Pace badge (top-right of readiness card)

    @ViewBuilder
    private func paceBadge(traj: V2HomeData.Trajectory) -> some View {
        // Fall back to the legacy onTrack bool when the new field is absent.
        let category = traj.paceCategory ?? (traj.onTrack ? "on_track" : "behind")
        switch category {
        case "ahead":
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Ahead of pace")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(ColorTokens.success)
        case "behind":
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Behind pace")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(ColorTokens.warning)
        default: // "on_track"
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("On track")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(ColorTokens.success)
        }
    }

    // MARK: - Projected ETA line (below chart, above footer)

    @ViewBuilder
    private func projectedEtaLine(traj: V2HomeData.Trajectory) -> some View {
        if traj.targetHit == true {
            // Already at or above target — prompt for a stretch goal
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.gold)
                Text("You've hit your \(traj.targetReadiness)% goal. Push for more?")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.top, 6)
        } else if traj.paceCategory == "ahead",
                  let early = traj.earlyByWeeks, early > 0,
                  let etaString = formattedEta(traj.projectedTargetDate) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.success)
                Text("At your pace, hitting \(traj.targetReadiness)% by \(etaString) — \(early) week\(early == 1 ? "" : "s") early")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.success)
            }
            .padding(.top, 6)
        } else if traj.paceCategory == "behind",
                  let weeks = traj.weeksToTarget, weeks > 0 {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.warning)
                Text("At your pace, hitting \(traj.targetReadiness)% in ~\(weeks) week\(weeks == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.warning)
            }
            .padding(.top, 6)
        }
        // on_track with no special signal: render nothing — the chart speaks for itself
    }

    /// Parses an ISO 8601 date string into a short "MMM d" display string (e.g., "Aug 17").
    /// Returns nil on parse failure — callers gate display on non-nil result.
    private func formattedEta(_ isoString: String?) -> String? {
        guard let s = isoString else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: s) ?? {
            // Retry without fractional seconds (backend may omit them)
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return plain.date(from: s)
        }()
        guard let d = date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    @ViewBuilder
    private func velocityBadge(traj: V2HomeData.Trajectory) -> some View {
        // Tasks are binary (done or not), so display whole numbers. Rounding
        // 1.8 → 2 reads as "about 2 tasks per week" which is what the user
        // actually understands. Decimal precision was confusing.
        let isMeasured = traj.velocitySource == "measured"
        if isMeasured, let real = traj.realTasksPerWeek {
            let rounded = max(1, Int(real.rounded()))
            Text("▲ ~\(rounded) task\(rounded == 1 ? "" : "s")/wk")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
        } else {
            let rounded = max(1, Int(traj.weeklyDelta.rounded()))
            Text("≈ ~\(rounded) pt\(rounded == 1 ? "" : "s")/wk (est.)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Section 2: Weekly insight card

    private func insightCard(insight: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.gold)
                .padding(.top, 2)
            Text(insight)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.gold.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(ColorTokens.gold.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Today header (count + total time)

    private func todayHeader(data: V2HomeData) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TODAY")
                .v2Eyebrow()
            Spacer()
            if let total = data.totalDurationMin {
                Text("\(vm.visibleTasks.count) \(vm.visibleTasks.count == 1 ? "task" : "tasks") · ~\(total) min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(.bottom, 10)
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
                    guard !completing.contains(task.taskId) else { return }
                    completing.insert(task.taskId)
                    Task { await vm.markComplete(task.taskId) }
                } label: {
                    Image(systemName: completing.contains(task.taskId)
                          ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(completing.contains(task.taskId)
                                         ? ColorTokens.success : ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(completing.contains(task.taskId))

                VStack(alignment: .leading, spacing: 4) {
                    Text(typeLabelFor(task.taskType))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(typeColorFor(task.taskType))
                    HStack(spacing: 6) {
                        Text(task.icon)
                        Text(task.title)
                            .font(V2Theme.bodyMedium)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    HStack(spacing: 8) {
                        Text("\(task.durationMin) min")
                        if !task.subtitle.isEmpty { Text("· \(task.subtitle)") }
                        Text("· \(difficultyLabel(task.difficulty))")
                            .foregroundStyle(difficultyColor(task.difficulty))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)

                    // Impact line — no truncation
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
                .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1)
        )
    }

    // Next-up rows: no chevron, type label + title + duration on tap = promote to hero
    private func nextUpRow(_ task: V2HomeData.Task, atIndex idx: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                activeTaskIndex = idx
            }
        } label: {
            HStack(spacing: 12) {
                Button {
                    guard !completing.contains(task.taskId) else { return }
                    completing.insert(task.taskId)
                    Task { await vm.markComplete(task.taskId) }
                } label: {
                    Image(systemName: completing.contains(task.taskId)
                          ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(completing.contains(task.taskId)
                                         ? ColorTokens.success : ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(completing.contains(task.taskId))

                Text(task.icon)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 1) {
                    Text(typeLabelFor(task.taskType))
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(typeColorFor(task.taskType))
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text("\(task.durationMin) min · \(difficultyLabel(task.difficulty))")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                // No chevron — clean, less clutter
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

    // MARK: - Pending from previous days

    private func pendingPriorSection(tasks: [V2HomeData.Task]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PENDING").v2Eyebrow()
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(typeLabelFor(task.taskType))
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(typeColorFor(task.taskType))
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text("\(task.durationMin) min · \(difficultyLabel(task.difficulty))")
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

    // MARK: - Section 4: Get Ahead — single chip, full list in sheet

    @ViewBuilder
    private func getAheadChip(tasks: [V2HomeData.Task], week: Int?) -> some View {
        Button {
            showGetAheadSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(ColorTokens.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GET AHEAD")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(ColorTokens.gold)
                    Text("\(tasks.count) \(tasks.count == 1 ? "task" : "tasks")\(week.map { " from Week \($0)" } ?? "") ready when you are")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(12)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showGetAheadSheet) {
            getAheadFullSheet(tasks: tasks, week: week)
        }
    }

    private func getAheadFullSheet(tasks: [V2HomeData.Task], week: Int?) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tasks) { task in
                        pendingPriorRow(task)
                    }
                }
                .padding(V2Theme.pad)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle(week.map { "Week \($0) — Get Ahead" } ?? "Get Ahead")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Section 6: For You rail

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

        if let getAhead = data.getAheadTasks, !getAhead.isEmpty {
            getAheadChip(tasks: getAhead, week: data.getAheadWeek)
                .padding(.bottom, 18)
        }

        wantMoreSection
    }

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

    // MARK: - Want More (day_done fallback)

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

    // MARK: - Extra content helpers

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

    // MARK: - Utilities

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
