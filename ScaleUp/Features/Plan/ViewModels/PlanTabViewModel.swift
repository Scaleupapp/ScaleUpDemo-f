import Foundation

// MARK: - Load State

enum PlanErrorKind {
    /// User hasn't finished the diagnostic yet — plan can't be built.
    case diagnosticIncomplete
    /// Backend tried to build the plan and failed (planGenerationStatus = "failed").
    case planGenerationFailed
    /// Network / decode / unexpected error while loading.
    case loadFailed
}

enum PlanLoadState {
    case idle
    case loading
    case ready(PlanDTO)
    case generating
    case error(PlanErrorKind, String)
}

// MARK: - Plan Tab View Model

@Observable
@MainActor
final class PlanTabViewModel {

    var loadState: PlanLoadState = .idle
    var mastery: APIPlanMastery?

    private let service = PlanService.shared

    func load() async {
        loadState = .loading

        do {
            let status = try await service.fetchStatus()

            switch status.status {
            case "ready", "completed":
                let plan = try await service.fetchCurrent()
                loadState = .ready(plan)
                if plan.source == .template {
                    AnalyticsService.shared.track(.planGenerationFallback(reason: "server_template"))
                }
                // Best-effort mastery load — section just hides if it fails.
                do { mastery = try await service.fetchMastery() } catch { mastery = nil }
            case "generating", "pending":
                loadState = .generating
            case "failed":
                loadState = .error(.planGenerationFailed, "Something went wrong building your plan. Tap below to try again.")
                AnalyticsService.shared.track(.planGenerationFallback(reason: "server_failed"))
            case "no_diagnostic":
                loadState = .error(.diagnosticIncomplete, "Take your 7-minute diagnostic to unlock your personalized plan.")
                AnalyticsService.shared.track(.planGenerationFallback(reason: "no_diagnostic"))
            default:
                loadState = .generating
            }
        } catch {
            loadState = .error(.loadFailed, error.localizedDescription)
        }
    }

    func retry() async {
        await load()
    }
}

extension PlanTabViewModel {
    /// Returns the tasks of the smallest week index that still has any pending or in_progress task.
    /// Mirrors backend `findCurrentWeekIndex` so the UI shows what the user should be doing now.
    func currentWeekTasks(in plan: PlanDTO) -> (weekNumber: Int, weekLabel: String, tasks: [APIPlanTask])? {
        let weeks = plan.weeklySchedule
        for week in weeks {
            let tasks = week.tasks ?? []
            if tasks.contains(where: { $0.progress.status == .pending || $0.progress.status == .inProgress }) {
                return (week.weekNumber, week.weekLabel, tasks)
            }
        }
        if let last = weeks.last {
            return (last.weekNumber, last.weekLabel, last.tasks ?? [])
        }
        return nil
    }
}
