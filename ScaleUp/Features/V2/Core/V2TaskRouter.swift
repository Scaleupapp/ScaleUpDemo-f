import SwiftUI

// MARK: - V2 completion notifications

/// Posted by the v1 detail screens when a task-bearing resource finishes.
/// V2TaskRouter listens for these and flips the matching plan task to complete.
extension Notification.Name {
    /// userInfo: ["contentId": String]
    static let v2ContentCompleted = Notification.Name("v2ContentCompleted")
    /// userInfo: ["quizId": String]
    static let v2QuizCompleted = Notification.Name("v2QuizCompleted")
    /// userInfo: ["sessionId": String]
    static let v2InterviewCompleted = Notification.Name("v2InterviewCompleted")
    /// userInfo: [] — posted by ChallengeViewModel when a competition session ends.
    static let v2CompetitionCompleted = Notification.Name("v2CompetitionCompleted")
    /// userInfo: ["taskId": String] — emitted by the router after a plan task is marked complete.
    static let v2PlanTaskCompleted = Notification.Name("v2PlanTaskCompleted")
}

/// Routes a v2 task tap into the correct v1 detail screen.
///
/// V2HomeView, V2YouView, and the Compass "Start" action all send users through
/// this single router so the rules live in one place. Falls back to a generic
/// "task detail unavailable" sheet when the task lacks a payload.
///
/// It also owns auto-completion: when a task is opened with a `taskId`, the
/// router remembers it, listens for the v1 completion notification, and POSTs
/// `/plan/task/:id/complete` so the user never has to manually tick off a task
/// they just finished.
@MainActor
@Observable
final class V2TaskRouter {

    /// Active route — driving sheet/cover presentation in V2RootView.
    var route: Route?

    /// The plan task currently open (if launched from a plan). Used to
    /// auto-complete once the underlying v1 resource reports done.
    private var activeTask: ActiveTask?

    private struct ActiveTask {
        let taskId: String
        let taskType: String
        let resourceId: String?   // contentId / quizId — nil for interview
    }

    enum Route: Identifiable, Equatable {
        case content(contentId: String, title: String)
        case quiz(quizId: String)
        /// Quiz task with no pre-baked quizId — request one for this topic.
        case quizByTopic(topic: String)
        case interview(scenarioId: String?)
        case competition
        /// Direct-start of a specific daily challenge — bypasses the hub
        /// landing page. Used when the task payload carries a challengeId
        /// (synthetic bonus-compete tasks always do; plan-generated compete
        /// tasks may not, in which case we fall back to .competition).
        case challengeAttempt(challengeId: String, topic: String)
        case external(url: URL)
        /// Weekly Compass review — opens Compass in review_week mode.
        case compassReview(weekNumber: Int, taskId: String?)
        case unavailable(message: String)

        var id: String {
            switch self {
            case .content(let id, _):  return "content-\(id)"
            case .quiz(let id):        return "quiz-\(id)"
            case .quizByTopic(let t):  return "quiztopic-\(t)"
            case .interview(let id):   return "interview-\(id ?? "default")"
            case .competition:         return "competition"
            case .challengeAttempt(let id, _): return "challenge-\(id)"
            case .external(let url):   return "external-\(url.absoluteString)"
            case .compassReview(let w, _): return "compass-review-\(w)"
            case .unavailable(let m):  return "unavailable-\(m)"
            }
        }
    }

    init() {
        registerCompletionObservers()
    }

    /// Dispatch — call from Home Begin / alt rows / Compass Start.
    ///
    /// `taskId` is the v2 plan task id. Pass it from plan-driven launches
    /// (Home) so the router can auto-complete; leave nil for ad-hoc launches
    /// (Compass configurator) that aren't tied to a plan task.
    func open(taskType: String, payload: V2HomeData.Payload?, title: String, taskId: String? = nil, topic: String? = nil) {
        switch taskType {
        case "watch", "listen", "read":
            if let id = payload?.contentId {
                route = .content(contentId: id, title: title)
                setActiveTask(taskId: taskId, taskType: taskType, resourceId: id)
            } else {
                route = .unavailable(message: "This task's content isn't linked yet.")
            }

        case "quiz":
            if let id = payload?.quizId {
                route = .quiz(quizId: id)
                setActiveTask(taskId: taskId, taskType: taskType, resourceId: id)
            } else if let topic = topic, !topic.isEmpty {
                // No pre-baked quiz — generate one for the task's topic.
                route = .quizByTopic(topic: topic)
                setActiveTask(taskId: taskId, taskType: "quiz", resourceId: nil)
            } else {
                route = .unavailable(message: "Quiz isn't ready yet. Check back soon.")
            }

        case "interview":
            route = .interview(scenarioId: payload?.interviewId)
            setActiveTask(taskId: taskId, taskType: taskType, resourceId: payload?.interviewId)

        case "external":
            if let urlStr = payload?.url, let u = URL(string: urlStr) {
                route = .external(url: u)
            } else {
                route = .unavailable(message: "External link unavailable.")
            }

        case "compete":
            // Prefer a direct-start path when we have a concrete challengeId.
            // Falls back to the hub landing only when the task doesn't carry
            // one (legacy plan-generated compete tasks).
            if let chId = payload?.challengeId {
                let chTopic = payload?.topic ?? topic ?? ""
                route = .challengeAttempt(challengeId: chId, topic: chTopic)
            } else {
                route = .competition
            }
            setActiveTask(taskId: taskId, taskType: taskType, resourceId: payload?.challengeId)

        case "compass_review":
            // Weekly Compass retrospective — open V2CompassView in review_week
            // mode. Falls back to the current plan-week if the server didn't
            // pass one (defensive — should always be present).
            let week = payload?.weekNumber ?? 1
            route = .compassReview(weekNumber: week, taskId: taskId)
            // We DO NOT setActiveTask here — completion is auto-marked by the
            // V2CompassSheetView host the moment the user engages (so closing
            // the sheet without ever sending a message still counts as done,
            // matching the "lock in what you learned" framing).

        case "mock_exam", "reflection", "notes_create", "conversation":
            // Phase 2: route to dedicated v2 detail screens. For now, show stub.
            route = .unavailable(message: "Coming next: dedicated \(taskType) screen.")

        default:
            route = .unavailable(message: "Unknown task type.")
        }
    }

    /// Public mark-complete shim — used by the Compass-review sheet host to
    /// flip the synthetic `review-week-<N>` task complete when the user opens
    /// the retrospective. Idempotent server-side ($addToSet).
    func markComplete(taskId: String) {
        Task { await completePlanTask(taskId) }
    }

    func close() {
        route = nil
        activeTask = nil
    }

    // MARK: - Auto-completion

    private func setActiveTask(taskId: String?, taskType: String, resourceId: String?) {
        guard let taskId = taskId else { activeTask = nil; return }
        activeTask = ActiveTask(taskId: taskId, taskType: taskType, resourceId: resourceId)
    }

    private func registerCompletionObservers() {
        let center = NotificationCenter.default
        center.addObserver(forName: .v2ContentCompleted, object: nil, queue: .main) { [weak self] note in
            let id = note.userInfo?["contentId"] as? String
            Task { @MainActor in self?.handleCompletion(types: ["watch", "listen", "read"], resourceId: id) }
        }
        center.addObserver(forName: .v2QuizCompleted, object: nil, queue: .main) { [weak self] note in
            let id = note.userInfo?["quizId"] as? String
            Task { @MainActor in self?.handleCompletion(types: ["quiz"], resourceId: id) }
        }
        center.addObserver(forName: .v2InterviewCompleted, object: nil, queue: .main) { [weak self] _ in
            // Interview sessions mint their own id inside the v1 flow, so we
            // can't match on resourceId — but only one interview sheet is open
            // at a time, so an evaluated interview completes the active task.
            Task { @MainActor in self?.handleCompletion(types: ["interview"], resourceId: nil) }
        }
        center.addObserver(forName: .v2CompetitionCompleted, object: nil, queue: .main) { [weak self] _ in
            // Competition sessions have no pre-baked resourceId in the plan task —
            // match by type only (only one compete sheet is open at a time).
            Task { @MainActor in self?.handleCompletion(types: ["compete"], resourceId: nil) }
        }
    }

    /// Marks the active plan task complete if it matches the finished resource.
    private func handleCompletion(types: [String], resourceId: String?) {
        guard let task = activeTask, types.contains(task.taskType) else { return }
        // For content/quiz we have a precise id to match; interview matches by type.
        if let resourceId = resourceId, let taskResource = task.resourceId, resourceId != taskResource {
            return
        }
        let taskId = task.taskId
        activeTask = nil
        Task { await completePlanTask(taskId) }
    }

    private func completePlanTask(_ taskId: String) async {
        struct Empty: Codable {}
        struct CompleteResponse: Codable { let taskId: String?; let status: String? }
        do {
            let _: V2APIResponse<CompleteResponse> =
                try await V2APIClient.shared.post("/plan/task/\(taskId)/complete", body: Empty())
            NotificationCenter.default.post(
                name: .v2PlanTaskCompleted,
                object: nil,
                userInfo: ["taskId": taskId]
            )
        } catch {
            // Non-fatal — the user can still tick the task manually, and the
            // next Home load() reconciles against server state.
        }
    }
}
