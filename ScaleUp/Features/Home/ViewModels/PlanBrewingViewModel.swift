import Foundation

// MARK: - Brewing Visibility

enum PlanBrewingVisibility {
    case hidden
    case brewing
    case ready
}

// MARK: - Plan Brewing View Model

@Observable
@MainActor
final class PlanBrewingViewModel {

    var visibility: PlanBrewingVisibility = .hidden

    private var pollingTask: Task<Void, Never>?
    private let service = PlanService.shared

    func start() {
        Task {
            await checkStatus()
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func checkStatus() async {
        do {
            let status = try await service.fetchStatus()

            switch status.status {
            case "generating", "pending":
                visibility = .brewing
                AnalyticsService.shared.track(.planBrewingSeen)
                startPolling()
            case "ready", "completed":
                visibility = .hidden
            default:
                visibility = .hidden
            }
        } catch {
            visibility = .hidden
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }

                do {
                    let status = try await service.fetchStatus()
                    if status.status == "ready" || status.status == "completed" {
                        visibility = .ready
                        AnalyticsService.shared.track(.planGenerationCompleted)
                        pollingTask?.cancel()
                        break
                    }
                } catch {
                    break
                }
            }
        }
    }
}
