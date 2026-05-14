import SwiftUI

/// V2 Home — the STRUCTURED DAY.
///
/// Not one hero card — a set of plan-aligned tasks for today. The user picks
/// what fits their energy/time. Each task can be started (routes to the v1
/// detail screen) or skipped (the next task from the week slots in). A
/// Reshuffle brings skipped tasks back.
struct V2HomeView: View {
    @State private var vm = V2HomeViewModel()
    @Environment(V2TaskRouter.self) private var taskRouter

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
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            ObjectivePill(label: vm.data?.objectiveLabel ?? "Set your objective")
            Spacer()
            Button {
                // TODO: notifications
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

        // Trajectory bar
        if let traj = data.trajectory {
            trajectorySection(traj: traj, weekProgress: data.weekProgress)
                .padding(.bottom, 22)
        }

        // The structured day
        if !vm.visibleTasks.isEmpty {
            todayHeader(data: data)
            ForEach(vm.visibleTasks) { task in
                taskCard(task)
                    .padding(.bottom, 10)
            }

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

    // MARK: - Task card

    private func taskCard(_ task: V2HomeData.Task) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Mark-done checkmark — tap-completion, explicit + always available
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

                    // Why this — predicted-impact line
                    Text(task.whyText)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.success)
                        .padding(.top, 2)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    taskRouter.open(taskType: task.taskType, payload: task.payload, title: task.title)
                } label: {
                    HStack {
                        Image(systemName: "play.fill").font(.system(size: 11))
                        Text("Begin")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
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
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(ColorTokens.surfaceElevated.opacity(0.5))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: V2Theme.cardRadius).fill(ColorTokens.surface))
        .overlay(RoundedRectangle(cornerRadius: V2Theme.cardRadius).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d.lowercased() {
        case "hard": return ColorTokens.warning
        case "easy": return ColorTokens.success
        default:     return ColorTokens.textSecondary
        }
    }

    // MARK: - Trajectory

    private func trajectorySection(traj: V2HomeData.Trajectory, weekProgress: V2HomeData.WeekProgress?) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.surface)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [ColorTokens.gold, ColorTokens.goldLight],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(traj.today) / 100.0, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                if let wp = weekProgress {
                    Text("Week \(wp.week) of \(wp.totalWeeks) · \(wp.done)/\(wp.total) done")
                } else {
                    Text("\(traj.today)% ready")
                }
                Spacer()
                Text("▲ \(traj.weeklyDelta)% / week")
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Text("Target \(traj.targetReadiness)%")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Fallbacks

    private func dayDoneSection(data: V2HomeData) -> some View {
        VStack(spacing: 14) {
            Text("🎉").font(.system(size: 40))
            Text(data.message ?? "You're done for now.")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            if (data.skippedCount ?? 0) > 0 {
                Button("Reshuffle skipped tasks") { Task { await vm.reshuffle() } }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTokens.gold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
        .preferredColorScheme(.dark)
}
