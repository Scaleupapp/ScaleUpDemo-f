import Foundation

// MARK: - Eligibility DTO

struct RecalibrationEligibility: Codable, Sendable {
    let eligible: Bool
    let reason: String?
    let previousAttemptId: String?
    let eligibleTopics: [String]?
    let expectedDurationMin: Int?
}

// MARK: - Start Response DTO

struct RecalibrationStartResponse: Codable, Sendable {
    let attemptId: String
    let totalEstimatedQuestions: Int
    let estimatedDurationSec: Int
    let flowType: String
}

// MARK: - Recalibration View Model

@MainActor
@Observable
final class RecalibrationViewModel {

    var eligibility: RecalibrationEligibility?
    var loading = false
    var error: String?

    func checkEligibility() async {
        loading = true
        defer { loading = false }
        do {
            eligibility = try await APIClient.shared.request(RecalibrationEligibleEndpoint())
            if eligibility?.eligible == true {
                AnalyticsService.shared.track(.recalibrationOffered)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func start() async throws -> RecalibrationStartResponse {
        AnalyticsService.shared.track(.recalibrationStarted)
        return try await APIClient.shared.request(RecalibrationStartEndpoint())
    }
}

// MARK: - Endpoints

private struct RecalibrationEligibleEndpoint: Endpoint {
    var path: String { "/diagnostic/recalibration/eligible" }
    var method: HTTPMethod { .get }
}

private struct RecalibrationStartEndpoint: Endpoint {
    var path: String { "/diagnostic/recalibration/start" }
    var method: HTTPMethod { .post }
}
