import Foundation

// MARK: - Load State

enum PlanLoadState {
    case idle
    case loading
    case ready(PlanDTO)
    case generating
    case error(String)
}

// MARK: - Plan Tab View Model

@Observable
@MainActor
final class PlanTabViewModel {

    var loadState: PlanLoadState = .idle

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
            case "generating", "pending":
                loadState = .generating
            default:
                loadState = .generating
            }
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    func retry() async {
        await load()
    }
}
