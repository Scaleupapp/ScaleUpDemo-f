import Foundation

@Observable
final class ObjectiveContext {
    var allObjectives: [Objective] = []
    var activeObjective: Objective?
    var isSwitching = false
    var switchError: String?
    var needsJourneyGeneration = false

    private let objectiveService = ObjectiveService()

    var activeObjectiveId: String? {
        activeObjective?.id
    }

    /// Update objectives from dashboard response (call whenever dashboard loads)
    func updateFromDashboard(_ objectives: [Objective]?) {
        guard let objectives = objectives, !objectives.isEmpty else { return }
        self.allObjectives = objectives
        if activeObjective == nil || !objectives.contains(where: { $0.id == activeObjective?.id }) {
            activeObjective = objectives.first(where: { $0.isPrimary == true }) ?? objectives.first
        }
    }

    /// Switch to a different objective
    @MainActor
    func switchObjective(to objective: Objective) async {
        guard objective.id != activeObjective?.id else { return }

        isSwitching = true
        switchError = nil
        needsJourneyGeneration = false

        do {
            let result: ActivateObjectiveResponse = try await objectiveService.activate(id: objective.id)
            activeObjective = objective
            needsJourneyGeneration = result.needsGeneration ?? false
            isSwitching = false
        } catch {
            switchError = error.localizedDescription
            isSwitching = false
        }
    }

    var canSwitch: Bool {
        allObjectives.count > 1
    }

    /// Called from Profile page when user activates an objective
    func didActivateObjective(id: String) {
        if let obj = allObjectives.first(where: { $0.id == id }) {
            activeObjective = obj
        }
        // The .onChange handlers on views will trigger dashboard reloads
    }
}
