import Foundation

// MARK: - Dashboard Service

actor DashboardService {

    private let api = APIClient.shared

    func fetchDashboard() async throws -> Dashboard {
        try await api.request(DashboardEndpoints.dashboard)
    }

    func fetchTodayPlan() async throws -> DailyPlan {
        try await api.request(DashboardEndpoints.todayPlan)
    }

    func fetchContinueWatching(limit: Int = 10) async throws -> [ContentProgress] {
        try await api.request(DashboardEndpoints.progressHistory(limit: limit))
    }
}

// MARK: - Endpoints

private enum DashboardEndpoints: Endpoint {
    case dashboard
    case todayPlan
    case progressHistory(limit: Int)

    var path: String {
        switch self {
        case .dashboard: return "/dashboard"
        case .todayPlan: return "/journey/today"
        case .progressHistory: return "/progress/history"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .progressHistory(let limit):
            return [URLQueryItem(name: "limit", value: "\(limit)")]
        default:
            return nil
        }
    }
}
