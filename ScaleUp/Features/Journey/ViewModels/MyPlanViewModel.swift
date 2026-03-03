import SwiftUI

@Observable
@MainActor
final class MyPlanViewModel {

    // MARK: - State

    var dashboard: JourneyDashboard?
    var userObjective: Objective?
    var nextActions: [NextActionItem] = []
    var objectiveCompetencies: [ObjectiveCompetency] = []
    var isLoading = false
    var errorMessage: String?
    var hasActiveJourney = false
    var isGenerating = false
    var showAddMilestone = false

    // Week detail
    var selectedWeek: Int?
    var weekResponse: WeekResponse?
    var isLoadingWeek = false

    private let journeyService = JourneyService()
    private let dashboardService = DashboardService()
    private let recommendationService = RecommendationService()
    private let objectiveService = ObjectiveService()

    // MARK: - Goal / Objective (prefers journey objective, falls back to user objective)

    var objective: JourneyObjective? { dashboard?.objective }

    var goalTitle: String {
        if let obj = objective { return obj.goalTitle }
        if let role = userObjective?.targetRole { return "Become a \(role)" }
        if let skill = userObjective?.targetSkill { return "Master \(skill)" }
        return userObjective?.objectiveType?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Learning Goal"
    }

    var timelineDisplay: String {
        if let obj = objective { return obj.timelineDisplay }
        if let days = userObjective?.daysRemaining {
            if days <= 0 { return "Target reached" }
            if days < 7 { return "\(days) days left" }
            if days < 30 { return "\(days / 7) weeks left" }
            return "\(days / 30) months left"
        }
        return userObjective?.timeline?.replacingOccurrences(of: "_", with: " ") ?? ""
    }

    var currentLevel: String { objective?.currentLevel?.capitalized ?? "" }
    var weeklyHours: Int { objective?.weeklyCommitHours ?? 0 }
    var objectiveId: String? { userObjective?.id }

    // MARK: - Pace

    var pace: JourneyPace? { dashboard?.pace }
    var paceStatus: String { pace?.statusDisplay ?? "On track" }
    var paceIcon: String { pace?.statusIcon ?? "checkmark.circle.fill" }

    var paceColor: Color {
        switch pace?.status {
        case "ahead": return ColorTokens.success
        case "on_track": return ColorTokens.gold
        case "behind": return .orange
        case "at_risk": return .red
        default: return ColorTokens.gold
        }
    }

    // MARK: - Phase

    var currentPhase: JourneyPhaseSnapshot? { dashboard?.currentPhase }
    var phases: [JourneyPhaseSnapshot] { dashboard?.phases ?? [] }

    var phaseProgress: String {
        let completed = phases.filter { $0.status == "completed" }.count
        return "\(completed + 1) of \(phases.count)"
    }

    // MARK: - Journey

    var journeyTitle: String {
        dashboard?.journey?.title ?? "My Learning Plan"
    }

    var currentWeek: Int {
        dashboard?.journey?.currentWeek ?? 1
    }

    var totalWeeks: Int {
        dashboard?.journey?.totalWeeks ?? 1
    }

    /// Match a phase_completion milestone to its corresponding phase
    func matchingPhase(for milestone: Milestone) -> JourneyPhaseSnapshot? {
        guard milestone.type == "phase_completion" else { return nil }
        let title = milestone.title.lowercased()
        return phases.first { phase in
            title.contains(phase.name.lowercased())
        }
    }

    /// Get milestones that belong to a specific phase (by scheduledWeek range)
    func milestonesForPhase(_ phase: JourneyPhaseSnapshot) -> [Milestone] {
        let phasesCount = max(phases.count, 1)
        let weeksPerPhase = max(totalWeeks / phasesCount, 1)
        let order = phase.order ?? 0
        let phaseStartWeek = order * weeksPerPhase + 1
        let phaseEndWeek = (order + 1) * weeksPerPhase

        return milestones.filter { milestone in
            if milestone.type == "phase_completion",
               milestone.title.lowercased().contains(phase.name.lowercased()) {
                return true
            }
            if let week = milestone.scheduledWeek {
                return week >= phaseStartWeek && week <= phaseEndWeek
            }
            return false
        }
    }

    var overallProgress: Double {
        Double(dashboard?.progress?.overallPercentage ?? 0) / 100.0
    }

    var streak: Int {
        dashboard?.progress?.currentStreak ?? 0
    }

    var todayContent: [Content] {
        dashboard?.today?.contentItems ?? []
    }

    var incompleteContent: [Content] {
        todayContent.filter { $0._progress?.isCompleted != true }
    }

    var completedContent: [Content] {
        todayContent.filter { $0._progress?.isCompleted == true }
    }

    var todayStats: TodayStats? {
        dashboard?.today?.todayStats
    }

    var todayCompleted: Bool {
        dashboard?.today?.completed ?? false
    }

    var currentDayOfWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    var weekDays: [WeekStrip.DayState] {
        guard let week = dashboard?.currentWeek else {
            return (1...7).map { WeekStrip.DayState(day: $0) }
        }
        return (1...7).map { day in
            let daySummary = week.daysSummary?.first(where: { $0.day == day })
            return WeekStrip.DayState(
                day: day,
                completed: daySummary?.completed ?? false,
                hasQuiz: false,
                contentCount: daySummary?.contentCount ?? 0
            )
        }
    }

    var weekGoals: [String] {
        dashboard?.currentWeek?.goals ?? []
    }

    var topicMastery: [KnowledgeSnapshot] {
        dashboard?.topicMastery ?? []
    }

    var milestones: [Milestone] {
        dashboard?.milestones ?? []
    }

    var nextMilestone: Milestone? {
        dashboard?.nextMilestone
    }

    var primaryNextAction: NextActionItem? {
        nextActions.first
    }

    // MARK: - Load

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        // Always fetch the main dashboard (for the real objective) alongside the journey dashboard
        async let mainDashTask: Dashboard? = {
            try? await self.dashboardService.fetchDashboard()
        }()
        async let journeyDashTask: JourneyDashboard? = {
            try? await self.journeyService.getDashboard()
        }()
        async let actionsTask: NextActionsResponse? = {
            try? await self.recommendationService.getNextActions()
        }()

        let (mainDash, journeyDash, actions) = await (mainDashTask, journeyDashTask, actionsTask)

        // Store the real user objective from the main dashboard
        userObjective = mainDash?.objectives?.first(where: { $0.isPrimary == true }) ?? mainDash?.objectives?.first

        dashboard = journeyDash
        nextActions = actions?.actions ?? []
        hasActiveJourney = journeyDash?.journey?.id != nil

        print("[MyPlan] objective: \(userObjective?.targetRole ?? userObjective?.objectiveType ?? "nil"), journey: \(journeyDash?.journey?.id ?? "nil"), hasActiveJourney: \(hasActiveJourney)")

        // Fetch competencies from objective brief (non-blocking)
        if let objId = userObjective?.id {
            objectiveCompetencies = (try? await objectiveService.getCompetencies(objectiveId: objId)) ?? []
        }

        isLoading = false
    }

    func loadWeek(_ weekNumber: Int) async {
        isLoadingWeek = true
        selectedWeek = weekNumber

        weekResponse = try? await journeyService.getWeek(number: weekNumber)

        isLoadingWeek = false
    }

    func completeDay(weekNumber: Int, day: Int) async {
        _ = try? await journeyService.completeAssignment(weekNumber: weekNumber, day: day)
        await loadDashboard()
    }

    func generateJourney(objectiveId: String) async {
        isGenerating = true
        _ = try? await journeyService.generate(objectiveId: objectiveId)
        await loadDashboard()
        isGenerating = false
    }

    func addMilestone(title: String, type: String, targetScore: Int?, targetTopic: String?) async {
        _ = try? await journeyService.addMilestone(title: title, type: type, targetScore: targetScore, targetTopic: targetTopic)
        await loadDashboard()
    }

    func deleteMilestone(id: String) async {
        _ = try? await journeyService.deleteMilestone(id: id)
        await loadDashboard()
    }

    /// All journey topics for the milestone topic picker
    var journeyTopics: [String] {
        let topics = dashboard?.topicMastery?.map(\.topic) ?? []
        return topics.isEmpty ? [] : topics
    }
}
