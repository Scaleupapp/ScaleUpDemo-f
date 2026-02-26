import SwiftUI

// MARK: - Home View Model

@Observable
final class HomeViewModel {

    // MARK: - Published State

    var dashboardData: DashboardResponse?
    var continueWatching: [ContentProgress] = []
    var recommendations: [Content] = []
    var trendingContent: [Content] = []
    var isLoading: Bool = false
    var error: APIError?

    // MARK: - Dependencies

    private let dashboardService: DashboardService
    private let progressService: ProgressService
    private let recommendationService: RecommendationService

    // MARK: - Init

    init(
        dashboardService: DashboardService,
        progressService: ProgressService,
        recommendationService: RecommendationService
    ) {
        self.dashboardService = dashboardService
        self.progressService = progressService
        self.recommendationService = recommendationService
    }

    // MARK: - Load Dashboard

    /// Loads all dashboard data including recommendations and continue watching.
    @MainActor
    func loadDashboard() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        await loadAllData()
        isLoading = false
    }

    // MARK: - Refresh

    /// Refreshes all dashboard data.
    @MainActor
    func refresh() async {
        error = nil
        await loadAllData()
    }

    // MARK: - Load All Data (resilient)

    /// Loads each data source independently so one failure doesn't block the rest.
    @MainActor
    private func loadAllData() async {
        let ds = dashboardService
        let ps = progressService
        let rs = recommendationService

        await withTaskGroup(of: HomeDataResult.self) { group in
            group.addTask { @Sendable in
                do {
                    let dashboard = try await ds.getDashboard()
                    return .dashboard(dashboard)
                } catch {
                    print("‼️ DASHBOARD ERROR: \(error)")
                    return .failed("dashboard", error)
                }
            }
            group.addTask { @Sendable in
                do {
                    let history = try await ps.history(limit: 10)
                    return .history(history)
                } catch {
                    print("‼️ HISTORY ERROR: \(error)")
                    return .failed("history", error)
                }
            }
            group.addTask { @Sendable in
                do {
                    let recs = try await rs.feed()
                    return .recommendations(recs)
                } catch {
                    print("‼️ RECOMMENDATIONS ERROR: \(error)")
                    return .failed("recommendations", error)
                }
            }
            group.addTask { @Sendable in
                do {
                    let trending = try await rs.trending()
                    return .trending(trending)
                } catch {
                    print("‼️ TRENDING ERROR: \(error)")
                    return .failed("trending", error)
                }
            }

            for await result in group {
                switch result {
                case .dashboard(let dashboard):
                    self.dashboardData = dashboard
                case .history(let history):
                    self.continueWatching = history.filter { !$0.isCompleted }
                case .recommendations(let recs):
                    self.recommendations = recs
                case .trending(let trending):
                    self.trendingContent = trending
                case .failed(let source, let err):
                    if source == "dashboard" && self.error == nil {
                        self.error = err as? APIError ?? .unknown(0, err.localizedDescription)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    var streak: Int {
        dashboardData?.journey?.streak ?? 0
    }

    var hasActiveJourney: Bool {
        dashboardData?.journey != nil
    }

    var pendingQuizzes: Int {
        dashboardData?.pendingQuizzes ?? 0
    }

    var readinessScore: Int {
        dashboardData?.readinessScore ?? 0
    }

    var topicMasteries: [TopicMastery] {
        dashboardData?.knowledgeProfile?.topicMastery ?? []
    }

    var weeklyStats: WeeklyStats? {
        dashboardData?.weeklyStats
    }

    /// User's objective type for section title personalization
    var objectiveLabel: String? {
        dashboardData?.objectives.first?.objectiveType.displayName
    }
}

// MARK: - Home Data Result

private enum HomeDataResult: Sendable {
    case dashboard(DashboardResponse)
    case history([ContentProgress])
    case recommendations([Content])
    case trending([Content])
    case failed(String, Error)
}

// MARK: - ObjectiveType Display Name

extension ObjectiveType {
    var displayName: String {
        switch self {
        case .examPreparation: return "Exam Prep"
        case .upskilling: return "Upskilling"
        case .interviewPreparation: return "Interview Prep"
        case .networking: return "Networking"
        case .careerSwitch: return "Career Switch"
        case .academicExcellence: return "Academics"
        case .casualLearning: return "Learning"
        }
    }
}
