import Foundation

// MARK: - Dashboard Endpoints

enum DashboardEndpoints {

    static func getDashboard() -> Endpoint {
        .get("/dashboard")
    }
}
