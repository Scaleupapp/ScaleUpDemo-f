import Foundation

// MARK: - LEGACY V1 — slated for removal

/// **DEPRECATED — Legacy V1 surface.**
/// Drove the "plan brewing" pill on v1 HomeView. v2's home shows plan
/// status inline; this VM is unused.
/// Scheduled for removal after 2026-06-15.

// MARK: - Brewing Visibility

enum PlanBrewingVisibility {
    case hidden
    case brewing
    case ready
}

// MARK: - Plan Brewing View Model

@Observable
@MainActor
@available(*, deprecated, message: "Legacy V1 — v2 Home shows plan status inline (see LEGACY_V1.md)")
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
