import Foundation

/// Client wrapper around the /api/coding/* endpoints. All methods main-actor
/// because they're called from SwiftUI views and update @Observable state.
@MainActor
final class DrillService {
    static let shared = DrillService()
    private let client = V2APIClient.shared

    // MARK: - Daily drill

    /// GET /api/coding/drills/today
    /// Throws `.calibrationRequired` if the backend returns 404 with that error code.
    /// Throws `.noDrillAvailable` for any other 404.
    func fetchTodayDrill() async throws -> DrillTodayResponse {
        do {
            return try await client.getCoding("/drills/today")
        } catch V2APIError.httpError(let status, let data) where status == 404 {
            if let errorBody = try? JSONDecoder().decode(CodingErrorBody.self, from: data),
               errorBody.error == "calibration_required" {
                throw DrillServiceError.calibrationRequired
            }
            throw DrillServiceError.noDrillAvailable
        }
    }

    /// POST /api/coding/drills/:bundleId/start
    func startDrill(bundleId: String) async throws -> DrillStartResponse {
        try await client.postCoding("/drills/\(bundleId)/start", body: EmptyPostBody())
    }

    /// POST /api/coding/drills/:bundleId/submit
    func submitDrill(bundleId: String, body: DrillSubmitBody) async throws -> DrillSubmitResponse {
        try await client.postCoding("/drills/\(bundleId)/submit", body: body)
    }

    /// GET /api/coding/drills/:bundleId/result
    ///
    /// Returns `.pending` if the backend is still grading (HTTP 202),
    /// or `.graded` once grading is complete (HTTP 200).
    func pollResult(bundleId: String) async throws -> DrillResultPoll {
        let (data, status) = try await client.rawCodingData(method: "GET", path: "/drills/\(bundleId)/result")

        if status == 200 {
            // Graded — decode full result
            let graded = try JSONDecoder().decode(DrillResultGradedResponse.self, from: data)
            return .graded(graded)
        } else {
            // 202 — decode pending/in-progress shape
            let pending = try JSONDecoder().decode(DrillResultPendingResponse.self, from: data)
            return .pending(pending)
        }
    }

    // MARK: - Calibration

    /// POST /api/coding/drills/calibration/start
    func startCalibration() async throws -> CalibrationStartResponse {
        try await client.postCoding("/drills/calibration/start", body: EmptyPostBody())
    }

    /// POST /api/coding/drills/calibration/:calibrationId/submit
    func submitCalibration(calibrationId: String, body: CalibrationSubmitBody) async throws -> CalibrationSubmitResponse {
        try await client.postCoding("/drills/calibration/\(calibrationId)/submit", body: body)
    }

    /// GET /api/coding/drills/calibration/:calibrationId/result
    func pollCalibrationResult(calibrationId: String) async throws -> CalibrationResultResponse {
        try await client.getCoding("/drills/calibration/\(calibrationId)/result")
    }
}

// MARK: - Supporting types

enum DrillResultPoll: Sendable {
    case pending(DrillResultPendingResponse)
    case graded(DrillResultGradedResponse)
}

enum DrillServiceError: Error, Sendable {
    case calibrationRequired
    case noDrillAvailable
    case invalidResponse
}

private struct EmptyPostBody: Codable {}

private struct CodingErrorBody: Codable {
    let error: String
}
