import Foundation

// MARK: - V2 Home Data Models

/// Decoded shape from GET /api/v2/plan/today — the STRUCTURED DAY.
struct V2HomeData: Codable {
    let greeting: String
    let statusLine: String
    let objectiveLabel: String?
    let trajectory: Trajectory?
    let weekProgress: WeekProgress?
    let streak: Streak?
    let weekActivity: [WeekDayActivity]?
    let topGap: TopGap?
    let todaysTasks: [Task]?
    let totalDurationMin: Int?
    let hasMoreThisWeek: Bool?
    let skippedCount: Int?
    let fallback: String?
    let message: String?
    /// How many weeks behind the user is vs the calendar (plan.createdAt vs
    /// the current visible week). 0 = on/ahead of schedule.
    let behindByWeeks: Int?
    /// Carry-over tasks still in the current week's pool but not in today's
    /// set. Rendered as "PENDING FROM PREVIOUS DAYS" on Home.
    let pendingPriorTasks: [Task]?
    let pendingPriorCount: Int?
    /// First 3 tasks from the next week — surfaced so the user always has a
    /// "Get ahead" option once today's set is done.
    let getAheadTasks: [Task]?
    let getAheadWeek: Int?
    /// Single-paragraph insight from the backend describing what to focus on
    /// this week and why. Surfaced just below the readiness card.
    let weeklyInsight: String?

    struct Trajectory: Codable {
        let today: Int
        let in30Days: Int
        let atTargetDate: Int
        let targetReadiness: Int
        let timelineWeeks: Int
        /// Was `Int` until 7b50b6a (backend). Now Double — backend rounds to
        /// one decimal place ('1.8 tasks/wk') so the iOS decoder must accept
        /// fractional values. Decoding as Int silently fails the whole
        /// V2HomeData decode → vm.data stays nil → "Couldn't load your day".
        let weeklyDelta: Double
        let onTrack: Bool
        let headline: String?
        /// Curve points the backend returns for the readiness line chart.
        let points: [TrajectoryPoint]?
        /// "measured" | "estimated" — labels the velocity source on the card.
        let velocitySource: String?
        /// Tasks/week calculated from real activity; nil when estimated.
        let realTasksPerWeek: Double?

        // MARK: Adaptive trajectory fields (all optional — absent in legacy responses)

        /// "ahead" | "on_track" | "behind" — supersedes onTrack in display.
        let paceCategory: String?
        /// Weeks at current pace until hitting targetReadiness.
        let weeksToTarget: Int?
        /// ISO 8601 date string when projected to hit target. Nil when delta=0.
        /// Stored as String to avoid needing a custom JSONDecoder date strategy.
        let projectedTargetDate: String?
        /// Non-null when paceCategory='ahead' and original timeline exists.
        /// How many weeks ahead of the original plan.
        let earlyByWeeks: Int?
        /// True when currentReadiness >= targetReadiness.
        let targetHit: Bool?

        struct TrajectoryPoint: Codable, Identifiable {
            let whenLabel: String
            let readiness: Int
            let weeks: Int
            var id: String { whenLabel }
        }
    }

    struct WeekProgress: Codable {
        let done: Int
        let total: Int
        let week: Int
        let totalWeeks: Int
    }

    struct Streak: Codable {
        let current: Int
        let longest: Int
    }

    struct WeekDayActivity: Codable, Identifiable {
        let label: String
        let hadActivity: Bool
        let isToday: Bool
        // Labels repeat (T, S) so include position context via array index in the view.
        var id: String { "\(label)-\(isToday)-\(hadActivity)" }
    }

    struct TopGap: Codable {
        let topic: String
        let score: Int
        let band: String?
    }

    /// One task in the structured day. Unified shape — no more hero/alternative split.
    struct Task: Codable, Identifiable {
        let taskId: String
        let taskType: String
        let icon: String
        let title: String
        let subtitle: String
        let durationMin: Int
        let difficulty: String
        let primaryTopic: String?
        let reason: String
        let payload: Payload?
        let impact: Impact?

        var id: String { taskId }

        var whyText: String {
            if let i = impact, let from = i.expectedFrom, let to = i.expectedTo {
                return "\(i.whyText ?? "") After this, ~\(to)% on \(primaryTopic ?? "this topic"), up from \(from)%."
            }
            return impact?.whyText ?? reason
        }

        struct Impact: Codable {
            let expectedFrom: Int?
            let expectedTo: Int?
            let expectedGain: Int?
            let whyText: String?
            let scope: String?
        }
    }

    /// Routing payload — tells iOS which v1 detail screen to push.
    struct Payload: Codable {
        let contentId: String?
        let quizId: String?
        let interviewId: String?
        let url: String?
    }
}

// MARK: - View Model

@Observable
@MainActor
final class V2HomeViewModel {
    var data: V2HomeData?
    var isLoading = false
    var error: String?

    /// Bonus recommendations shown only when the day_done fallback fires —
    /// "you're done; here's more if you want". Lazily fetched.
    var extraContent: [Content] = []
    var isLoadingExtras = false

    private let contentService = ContentService()

    /// taskIds the user has tapped Skip on this session — hidden optimistically
    /// while the network call settles.
    private var pendingSkips: Set<String> = []

    /// taskIds the user has tapped Complete on this session — hidden
    /// optimistically before the server round-trip resolves.
    private var pendingCompletes: Set<String> = []

    /// Set true only in #Preview / debug.
    var usePreviewSample = false

    /// The tasks to actually render — today's set minus optimistic skips and
    /// optimistic completes.
    var visibleTasks: [V2HomeData.Task] {
        (data?.todaysTasks ?? []).filter {
            !pendingSkips.contains($0.taskId) && !pendingCompletes.contains($0.taskId)
        }
    }

    func load() async {
        if usePreviewSample {
            data = Self.sampleData
            return
        }
        isLoading = true
        error = nil
        do {
            let response: V2APIResponse<V2HomeData> = try await V2APIClient.shared.get("/plan/today")
            data = response.data
            pendingSkips.removeAll()
            pendingCompletes.removeAll()
        } catch let e {
            self.error = Self.friendlyError(e)
            self.data = nil
        }
        isLoading = false

        // Always-on "for you" content rail — surfaced under the task list so
        // the user can grab something to watch even when their plan tasks are
        // all videos/quizzes they don't feel like doing right now.
        Task { await loadExtrasIfNeeded() }
    }

    /// Skip a task — optimistic hide, then persist. The next `load()` reflects
    /// the server state (the skipped task drops out, the next one slots in).
    func skip(_ task: V2HomeData.Task) async {
        pendingSkips.insert(task.taskId)
        struct Empty: Codable {}
        do {
            let _: V2APIResponse<SkipResponse> =
                try await V2APIClient.shared.post("/plan/task/\(task.taskId)/skip", body: Empty())
            // Refresh so the next task from the week slots into the set.
            await load()
        } catch {
            // Roll back the optimistic hide on failure.
            pendingSkips.remove(task.taskId)
        }
    }

    /// Tap-completion — optimistically hides the task immediately, then
    /// persists to the backend. Rolls back the hide on failure.
    func markComplete(_ taskId: String) async {
        pendingCompletes.insert(taskId)
        struct Empty: Codable {}
        do {
            let _: V2APIResponse<SkipResponse> =
                try await V2APIClient.shared.post("/plan/task/\(taskId)/complete", body: Empty())
            // load() clears pendingCompletes after a successful fetch.
            await load()
        } catch {
            // Roll back the optimistic hide on failure.
            pendingCompletes.remove(taskId)
        }
    }

    /// Reshuffle — un-skip the week's skipped tasks and re-fetch the set.
    func reshuffle() async {
        struct Empty: Codable {}
        do {
            let _: V2APIResponse<SkipResponse> =
                try await V2APIClient.shared.post("/plan/reshuffle", body: Empty())
            pendingSkips.removeAll()
            await load()
        } catch {
            // ignore — user can pull-to-refresh
        }
    }

    /// Loaded on demand when the user lands on the day_done state, so we can
     /// surface "want more?" suggestions instead of just a celebration screen.
    func loadExtrasIfNeeded() async {
        guard extraContent.isEmpty, !isLoadingExtras else { return }
        isLoadingExtras = true
        let recs = (try? await contentService.fetchRecommendations(limit: 6)) ?? []
        extraContent = Array(recs.prefix(3))
        isLoadingExtras = false
    }

    private struct SkipResponse: Codable {
        let taskId: String?
        let status: String?
        let reshuffled: Bool?
    }

    private static func friendlyError(_ e: Error) -> String {
        if let apiErr = e as? V2APIError {
            switch apiErr {
            case .invalidURL:         return "Couldn't reach ScaleUp. Check your connection."
            case .serverError(let s) where s == 401: return "Please sign in again."
            case .serverError(let s): return "Server issue (\(s)). Try again in a moment."
            case .decodingFailed:     return "We got a response but couldn't read it."
            }
        }
        return "Couldn't load your day. Pull to refresh."
    }

    static var sampleData: V2HomeData {
        .init(
            greeting: "Hi, Nirpeksh.",
            statusLine: "You're on track for August. 74% ready, 11 weeks to go.",
            objectiveLabel: "SDE @ Google · 6mo",
            trajectory: .init(
                today: 74, in30Days: 80, atTargetDate: 85,
                targetReadiness: 80, timelineWeeks: 24, weeklyDelta: 6,
                onTrack: true, headline: nil, points: nil,
                velocitySource: "estimated", realTasksPerWeek: nil,
                paceCategory: "on_track", weeksToTarget: 12,
                projectedTargetDate: "2026-08-17T00:00:00Z",
                earlyByWeeks: nil, targetHit: false
            ),
            weekProgress: .init(done: 3, total: 7, week: 11, totalWeeks: 24),
            streak: .init(current: 3, longest: 7),
            weekActivity: [
                .init(label: "M", hadActivity: true, isToday: false),
                .init(label: "T", hadActivity: true, isToday: false),
                .init(label: "W", hadActivity: true, isToday: true),
                .init(label: "T", hadActivity: false, isToday: false),
                .init(label: "F", hadActivity: false, isToday: false),
                .init(label: "S", hadActivity: false, isToday: false),
                .init(label: "S", hadActivity: false, isToday: false),
            ],
            topGap: .init(topic: "dynamic-programming", score: 30, band: "novice"),
            todaysTasks: [
                .init(taskId: "t1", taskType: "watch", icon: "📺",
                      title: "Dynamic Programming — Memoization", subtitle: "Striver",
                      durationMin: 22, difficulty: "hard", primaryTopic: "DP",
                      reason: "Closes your top gap", payload: nil,
                      impact: .init(expectedFrom: 30, expectedTo: 36, expectedGain: 6,
                                    whyText: "Closes your top gap.", scope: "topic")),
                .init(taskId: "t2", taskType: "quiz", icon: "🧠",
                      title: "Quiz: last week's funnel topics", subtitle: "",
                      durationMin: 5, difficulty: "easy", primaryTopic: "Funnels",
                      reason: "Quick retention check", payload: nil, impact: nil),
                .init(taskId: "t3", taskType: "interview", icon: "🎙️",
                      title: "Behavioral interview practice", subtitle: "",
                      durationMin: 30, difficulty: "medium", primaryTopic: "Behavioral",
                      reason: "For Google L4", payload: nil, impact: nil),
                .init(taskId: "t4", taskType: "reflection", icon: "📝",
                      title: "Recap your Week 2 notes", subtitle: "",
                      durationMin: 10, difficulty: "easy", primaryTopic: "Review",
                      reason: "Spaced repetition due", payload: nil, impact: nil),
            ],
            totalDurationMin: 67,
            hasMoreThisWeek: true,
            skippedCount: 0,
            fallback: nil,
            message: nil,
            behindByWeeks: 0,
            pendingPriorTasks: nil,
            pendingPriorCount: 0,
            getAheadTasks: nil,
            getAheadWeek: nil,
            weeklyInsight: "Dynamic Programming is your biggest gap this week — you're at 30% readiness on DP vs. 74% overall. One focused session on memoization patterns can close ~6 points and unblock the tree/graph problems that follow in Week 12."
        )
    }
}
