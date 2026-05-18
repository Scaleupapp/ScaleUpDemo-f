import SwiftUI

/// V2 Competition Home — destination for the "Compete" Compass chip and the
/// landing screen when Home surfaces a competition as today's task.
///
/// Calls GET /competitions/relevant and renders one of three states:
///   - building   → "today's challenge is being prepared" waiting screen
///                  (cron hasn't fired, or the topic pool is being filled)
///   - available  → entry card + meta + "Start" → CompetitionHubView
///   - played     → "you already played today" + leaderboard CTA
///
/// Surfaces the next live event below in all states.
struct V2CompetitionHomeView: View {
    let onClose: () -> Void

    @State private var status: Status = .loading
    @State private var todayChallenge: TodayChallenge?
    @State private var nextLiveEvent: LiveEvent?
    @State private var objectiveTopic: String?
    @State private var topicMatch = false
    @State private var cohortMemberCount: Int = 0
    @State private var cohortPlayedToday: Int = 0
    @State private var loadError: String?
    @State private var showCompetitionHub = false
    /// Set non-nil to launch the actual challenge attempt (full-screen),
    /// distinct from showCompetitionHub which opens the leaderboard landing.
    @State private var startedChallenge: StartedChallenge?

    private struct StartedChallenge: Identifiable {
        let id: String
        let topic: String
    }
    @State private var history: [HistoryItem] = []

    /// Auto-refresh interval when status is "building" — the cron seeds at
    /// 00:00 IST, so a user who lands here pre-cron should auto-recover
    /// without manually pulling to refresh.
    @State private var autoRefreshTask: Task<Void, Never>?

    private enum Status: String, Codable { case loading, building, available, played }

    private struct TodayChallenge: Codable {
        let _id: String
        let title: String?
        let topic: String?
        let difficulty: String?
        let questionCount: Int?
        let durationSeconds: Int?
    }

    private struct LiveEvent: Codable {
        let _id: String
        let scheduledFor: Date?
        let title: String?
        let topic: String?
    }

    /// /api/v1/competition/relevant wraps payload in { success, data, message }
    /// — V2APIClient.getV1 returns the raw response so we decode that shape.
    private struct V1Envelope: Codable {
        let success: Bool
        let data: RelevantResponse?
        let message: String?
    }
    private struct RelevantResponse: Codable {
        let status: String
        let objectiveTopic: String?
        let topicMatch: Bool?
        let cohortMemberCount: Int?
        let cohortPlayedToday: Int?
        let todayChallenge: TodayChallenge?
        let nextLiveEvent: LiveEvent?
    }

    // MARK: - History models

    private struct HistoryItem: Codable, Identifiable {
        let _id: String
        let challengeId: String?
        let title: String
        let topic: String?
        let challengeDate: Date?
        let completedAt: Date?
        let handicappedScore: Double?
        let rawScore: Double?
        let timeTakenSeconds: Int?
        let isPersonalBest: Bool?
        var id: String { _id }
    }
    private struct HistoryEnvelope: Codable {
        let success: Bool
        let data: HistoryPayload?
    }
    private struct HistoryPayload: Codable {
        let items: [HistoryItem]
        let total: Int?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    switch status {
                    case .loading:   loadingState
                    case .building:  buildingState
                    case .available: availableState
                    case .played:    playedState
                    }
                    if let evt = nextLiveEvent {
                        liveEventCard(evt)
                            .padding(.top, 8)
                    }
                    if !history.isEmpty {
                        historySection
                    }
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Compete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
            .refreshable { await load() }
            .fullScreenCover(isPresented: $showCompetitionHub) {
                NavigationStack {
                    CompetitionHubView(initialTopic: objectiveTopic)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { showCompetitionHub = false }
                            }
                        }
                }
            }
            .fullScreenCover(item: $startedChallenge) { ch in
                ChallengeSessionView(challengeId: ch.id, topic: ch.topic)
            }
        }
        .task { await load() }
        .onDisappear { autoRefreshTask?.cancel() }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily challenges — timed quizzes against the rest of the community. Different from your solo quizzes: 30 sec per question, no explanations until the end, ranked.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2).tint(ColorTokens.gold)
            Text("Loading today's competition…")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var buildingState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.10))
                    .frame(width: 90, height: 90)
                Image(systemName: "hourglass")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.gold)
                    .symbolEffect(.pulse, options: .repeating)
            }
            Text("Today's challenge is being built")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text(objectiveTopic.map { "Tuning the question pool to \(prettyTopic($0)) — usually ready within a minute." }
                 ?? "Tuning the question pool — usually ready within a minute.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(ColorTokens.gold.opacity(0.4))
                        .frame(width: 6, height: 6)
                        .scaleEffect(buildingDotScale(i))
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.15),
                            value: status
                        )
                }
            }
            .padding(.top, 4)
            Text("Auto-refreshing…")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func buildingDotScale(_ i: Int) -> CGFloat {
        // SwiftUI auto-animates due to the modifier — value just needs to change.
        1.0 + 0.5 * CGFloat(i % 2)
    }

    private var availableState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S CHALLENGE").v2Eyebrow()
                Spacer()
                if topicMatch, let topic = objectiveTopic {
                    Text("Matched to \(prettyTopic(topic))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ColorTokens.success)
                }
            }
            challengeCard(todayChallenge!)
        }
    }

    private var playedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.success)
            Text("Done for today")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("You've taken today's challenge. New one drops at midnight.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showCompetitionHub = true
            } label: {
                Text("View leaderboard →")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .overlay(
                        Capsule().strokeBorder(ColorTokens.gold.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func challengeCard(_ c: TodayChallenge) -> some View {
        Button {
            // Launch the actual timed challenge attempt (NOT the leaderboard
            // landing) — that was the broken behavior testers hit.
            startedChallenge = StartedChallenge(id: c._id, topic: c.topic ?? "")
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 38, height: 38)
                        .background(ColorTokens.gold.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.title ?? c.topic?.capitalized ?? "Daily Challenge")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(2)
                        if cohortMemberCount > 0 {
                            Text("\(cohortMemberCount) in your cohort · \(cohortPlayedToday) played today")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.gold)
                        }
                        Text(metaLine(c))
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                }
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "timer").font(.system(size: 10, weight: .semibold))
                        Text("Timed · ~30s per Q")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(ColorTokens.warning)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.fill").font(.system(size: 10, weight: .semibold))
                        Text("Ranked")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(ColorTokens.info)
                }
                Text("Start →")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ColorTokens.gold)
                    .foregroundStyle(ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 4)
            }
            .padding(14)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: V2Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .strokeBorder(ColorTokens.gold.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func liveEventCard(_ e: LiveEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NEXT LIVE EVENT").v2Eyebrow()
                Spacer()
            }
            Button {
                showCompetitionHub = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.info)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.info.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title ?? e.topic?.capitalized ?? "Live event")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(1)
                        if let when = e.scheduledFor {
                            Text(scheduledLine(when))
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(12)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func metaLine(_ c: TodayChallenge) -> String {
        var parts: [String] = []
        if let topic = c.topic, !topic.isEmpty { parts.append(prettyTopic(topic)) }
        if let qc = c.questionCount, qc > 0 { parts.append("\(qc) questions") }
        if let dur = c.durationSeconds, dur > 0 { parts.append("\(dur / 60) min") }
        if let d = c.difficulty, !d.isEmpty { parts.append(d.capitalized) }
        return parts.joined(separator: " · ")
    }

    private func scheduledLine(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM · h:mm a"
        return f.string(from: d)
    }

    private func prettyTopic(_ s: String) -> String {
        s.replacingOccurrences(of: "-", with: " ")
         .replacingOccurrences(of: "_", with: " ")
         .split(separator: " ")
         .map { $0.prefix(1).uppercased() + $0.dropFirst() }
         .joined(separator: " ")
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR PAST COMPETITIONS").v2Eyebrow()
                Spacer()
                Text("\(history.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            VStack(spacing: 8) {
                ForEach(history.prefix(10)) { item in
                    historyRow(item)
                }
            }
            if history.count > 10 {
                Text("Showing 10 of \(history.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 18)
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isPersonalBest == true ? "trophy.fill" : "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(scoreColor(item))
                .frame(width: 28, height: 28)
                .background(scoreColor(item).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text(historyMeta(item))
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let s = item.handicappedScore {
                    Text("\(Int(s.rounded())) pts")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(scoreColor(item))
                } else if let r = item.rawScore {
                    Text("\(Int(r.rounded()))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(scoreColor(item))
                } else {
                    Text("—")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                if item.isPersonalBest == true {
                    Text("PB")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
    }

    private func historyMeta(_ item: HistoryItem) -> String {
        var parts: [String] = []
        if let topic = item.topic, !topic.isEmpty { parts.append(prettyTopic(topic)) }
        if let date = item.completedAt {
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            parts.append(f.string(from: date))
        }
        return parts.joined(separator: " · ")
    }

    private func scoreColor(_ item: HistoryItem) -> Color {
        // Prefer handicappedScore; fall back to rawScore (0–100 scale).
        let score = item.handicappedScore ?? item.rawScore
        guard let s = score else { return ColorTokens.textTertiary }
        // handicappedScore sits on a ~0–35 scale; rawScore on 0–100.
        // Use rawScore thresholds when handicappedScore absent.
        let threshold: (Double, Double) = item.handicappedScore != nil ? (20, 10) : (70, 40)
        if s >= threshold.0 { return ColorTokens.success }
        if s >= threshold.1 { return ColorTokens.gold }
        return ColorTokens.warning
    }

    // MARK: - Network

    private func load() async {
        if status != .building { status = .loading }
        do {
            // Fetch /competition/relevant and /competition/history concurrently.
            async let relevantFetch: V1Envelope = V2APIClient.shared.getV1("/competition/relevant")
            async let historyFetch: HistoryEnvelope = V2APIClient.shared.getV1("/competition/history?limit=20")

            let env = try await relevantFetch
            // History is non-fatal — swallow errors so relevant still renders.
            if let histEnv = try? await historyFetch {
                history = histEnv.data?.items ?? []
            }

            guard let data = env.data else {
                status = .building
                return
            }
            todayChallenge = data.todayChallenge
            nextLiveEvent  = data.nextLiveEvent
            objectiveTopic = data.objectiveTopic
            topicMatch     = data.topicMatch ?? false
            cohortMemberCount = data.cohortMemberCount ?? 0
            cohortPlayedToday = data.cohortPlayedToday ?? 0
            status = Status(rawValue: data.status) ?? .building

            // While we're in building state, keep checking until the cron
            // catches up. Cancels itself when status flips.
            if status == .building {
                autoRefreshTask?.cancel()
                autoRefreshTask = Task { [weak _vmIdentity = NSObject()] in
                    _ = _vmIdentity
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(15))
                        if Task.isCancelled { return }
                        await load()
                    }
                }
            } else {
                autoRefreshTask?.cancel()
                autoRefreshTask = nil
            }
        } catch {
            loadError = "Couldn't load today's competition. Pull to refresh."
            status = .building
        }
    }
}
