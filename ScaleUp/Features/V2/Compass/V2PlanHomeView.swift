import SwiftUI

/// V2 Plan Home — destination for the "Plan my days" Compass chip.
///
/// Today's set (the same one the Home tab uses) plus this week's remaining
/// tasks, with reshuffle and a jump-to-Home CTA. Avoids the bare
/// "switch tabs and hope they get it" behaviour.
struct V2PlanHomeView: View {
    let onClose: () -> Void
    let onViewFullHome: () -> Void

    @Environment(V2TaskRouter.self) private var taskRouter
    @State private var data: V2HomeData?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isReshuffling = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading && data == nil {
                        ProgressView().tint(ColorTokens.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if let data = data {
                        intro(data)
                        if let traj = data.trajectory {
                            weekSummary(traj: traj, weekProgress: data.weekProgress)
                        }
                        if let tasks = data.todaysTasks, !tasks.isEmpty {
                            todaySection(tasks: tasks, total: data.totalDurationMin ?? 0)
                        }
                        if (data.skippedCount ?? 0) > 0 {
                            reshuffleButton(count: data.skippedCount ?? 0)
                        }
                        viewFullHomeButton
                        Spacer().frame(height: 40)
                    } else if let err = error {
                        Text(err)
                            .font(V2Theme.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    }
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Your plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
            .refreshable { await load() }
        }
        .task { await load() }
    }

    // MARK: - Sections

    private func intro(_ d: V2HomeData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(d.statusLine)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func weekSummary(traj: V2HomeData.Trajectory, weekProgress: V2HomeData.WeekProgress?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("THIS WEEK").v2Eyebrow()
                Spacer()
                if let wp = weekProgress {
                    Text("Week \(wp.week) of \(wp.totalWeeks)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            HStack(spacing: 14) {
                statTile(value: "\(traj.today)%", label: "ready", accent: ColorTokens.gold)
                if let wp = weekProgress {
                    statTile(value: "\(wp.done)/\(wp.total)", label: "done", accent: ColorTokens.textPrimary)
                }
                statTile(value: "▲ \(traj.weeklyDelta)%", label: "/ week", accent: ColorTokens.success)
            }
        }
        .padding(14)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: V2Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    private func statTile(value: String, label: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todaySection(tasks: [V2HomeData.Task], total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY").v2Eyebrow()
                Spacer()
                Text("\(tasks.count) things · ~\(total) min")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            VStack(spacing: 8) {
                ForEach(tasks) { t in
                    Button {
                        taskRouter.open(
                            taskType: t.taskType,
                            payload: t.payload,
                            title: t.title,
                            taskId: t.taskId,
                            topic: t.primaryTopic
                        )
                    } label: {
                        HStack(spacing: 10) {
                            Text(t.icon)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .lineLimit(1)
                                Text("\(t.durationMin) min · \(t.difficulty.capitalized)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.gold)
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
            }
        }
    }

    private func reshuffleButton(count: Int) -> some View {
        Button {
            Task { await reshuffle() }
        } label: {
            HStack {
                if isReshuffling {
                    ProgressView().tint(ColorTokens.gold)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text("Bring back \(count) skipped \(count == 1 ? "task" : "tasks")")
            }
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(ColorTokens.gold)
            .background(ColorTokens.gold.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isReshuffling)
    }

    private var viewFullHomeButton: some View {
        Button {
            onClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onViewFullHome()
            }
        } label: {
            HStack {
                Image(systemName: "house.fill")
                Text("View your Home")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(ColorTokens.gold)
            .foregroundStyle(ColorTokens.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Network

    private func load() async {
        isLoading = true
        error = nil
        do {
            let resp: V2APIResponse<V2HomeData> = try await V2APIClient.shared.get("/plan/today")
            data = resp.data
        } catch {
            self.error = "Couldn't load your plan. Pull to refresh."
        }
        isLoading = false
    }

    private func reshuffle() async {
        isReshuffling = true
        struct Empty: Codable {}
        struct Resp: Codable { let reshuffled: Bool? }
        let _: V2APIResponse<Resp>? = try? await V2APIClient.shared.post("/plan/reshuffle", body: Empty())
        await load()
        isReshuffling = false
    }
}
