import Foundation

// MARK: - V2 Home Data Models

/// Decoded shape from GET /api/v2/plan/today — the STRUCTURED DAY.
struct V2HomeData: Codable {
    let greeting: String
    let statusLine: String
    let objectiveLabel: String?
    let trajectory: Trajectory?
    let weekProgress: WeekProgress?
    let todaysTasks: [Task]?
    let totalDurationMin: Int?
    let hasMoreThisWeek: Bool?
    let skippedCount: Int?
    let fallback: String?
    let message: String?

    struct Trajectory: Codable {
        let today: Int
        let in30Days: Int
        let atTargetDate: Int
        let targetReadiness: Int
        let timelineWeeks: Int
        let weeklyDelta: Int
        let onTrack: Bool
        let headline: String?
    }

    struct WeekProgress: Codable {
        let done: Int
        let total: Int
        let week: Int
        let totalWeeks: Int
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

    /// taskIds the user has tapped Skip on this session — hidden optimistically
    /// while the network call settles.
    private var pendingSkips: Set<String> = []

    /// Set true only in #Preview / debug.
    var usePreviewSample = false

    /// The tasks to actually render — today's set minus optimistic skips.
    var visibleTasks: [V2HomeData.Task] {
        (data?.todaysTasks ?? []).filter { !pendingSkips.contains($0.taskId) }
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
        } catch let e {
            self.error = Self.friendlyError(e)
            self.data = nil
        }
        isLoading = false
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

    /// Tap-completion — flips the plan task to complete (called when the user
    /// finishes a task in its detail screen, or via the row's Done affordance).
    func markComplete(_ taskId: String) async {
        struct Empty: Codable {}
        do {
            let _: V2APIResponse<SkipResponse> =
                try await V2APIClient.shared.post("/plan/task/\(taskId)/complete", body: Empty())
            await load()
        } catch {
            // Non-fatal — a later load() will reconcile.
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
                onTrack: true, headline: nil
            ),
            weekProgress: .init(done: 3, total: 7, week: 11, totalWeeks: 24),
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
            message: nil
        )
    }
}
