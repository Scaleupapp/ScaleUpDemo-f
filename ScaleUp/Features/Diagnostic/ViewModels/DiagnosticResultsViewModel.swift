import Foundation
import SwiftUI

@MainActor
final class DiagnosticResultsViewModel: ObservableObject {
    @Published private(set) var phase: Phase = .generating
    @Published private(set) var hero: String = ""
    @Published private(set) var calibrationSummary: String = ""
    @Published private(set) var calibrationDetail: String = ""
    @Published private(set) var patterns: [String] = []
    @Published private(set) var planHeadline: String = ""
    @Published private(set) var topics: [DiagnosticTopicResult] = []
    @Published private(set) var overallScore: Int = 0
    @Published var showShareSheet: Bool = false
    @Published var shareImage: UIImage? = nil

    enum Phase { case generating, ready }

    private let attemptId: String
    private let service: DiagnosticService
    private var pollTask: Task<Void, Never>?

    init(attemptId: String, service: DiagnosticService = DiagnosticService()) {
        self.attemptId = attemptId
        self.service = service
    }

    func start() {
        MixpanelDiagnostic.insightsGenerationStarted(attemptId: attemptId)
        pollTask?.cancel()
        pollTask = Task { await pollUntilReady() }
    }

    private func pollUntilReady() async {
        var attempts = 0
        let maxAttempts = 18
        while !Task.isCancelled, attempts < maxAttempts {
            attempts += 1
            do {
                let resp = try await service.getResults(attemptId: attemptId)
                if (resp.insightsStatus == "completed" || resp.insightsStatus == "fallback"), let i = resp.insights {
                    apply(results: resp.results, insights: i)
                    let latency = attempts * 1000
                    if resp.insightsStatus == "fallback" {
                        MixpanelDiagnostic.insightsGenerationFallback(reason: "server", latencyMs: latency)
                    } else {
                        MixpanelDiagnostic.insightsGenerationCompleted(latencyMs: latency)
                    }
                    phase = .ready
                    MixpanelDiagnostic.diagnosticResultsViewed(attemptId: attemptId)
                    return
                }
            } catch {
                // swallow; will retry
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func apply(results: [DiagnosticResultDTO], insights: DiagnosticInsightsDTO) {
        hero = insights.hero
        calibrationDetail = insights.calibration
        patterns = insights.patterns
        planHeadline = insights.planHeadline

        let wellCount = results.filter { $0.calibrationClass == "well-calibrated" }.count
        calibrationSummary = "Well-calibrated on \(wellCount) of \(results.count) topics"
        overallScore = results.isEmpty ? 0 : results.map { $0.score }.reduce(0, +) / results.count

        topics = results.map { r in
            let canonical = r.canonicalCompetency ?? r.competency
            return DiagnosticTopicResult(
                canonicalName: canonical,
                displayName: r.displayName ?? r.competency,
                selfRating: r.selfRating ?? "Familiar",
                measuredScore: r.score,
                measuredBand: r.band,
                calibrationDelta: r.calibrationDelta,
                calibrationClass: r.calibrationClass,
                questionsAsked: r.questionsAsked,
                topicTakeaway: insights.topicTakeaways[canonical] ?? "",
                strongestMoment: r.strongestMoment,
                stretchMoment: r.stretchMoment,
                missedDifficulties: r.missedDifficulties ?? []
            )
        }
    }

    func onTopicExpanded(_ canonicalName: String) {
        MixpanelDiagnostic.diagnosticTopicCardExpanded(topicCanonical: canonicalName)
    }

    func onReplayOpened() {
        MixpanelDiagnostic.diagnosticReplaySectionOpened(attemptId: attemptId)
    }

    func onHeroRevealCompleted() {
        MixpanelDiagnostic.diagnosticHeroRevealCompleted(attemptId: attemptId)
    }

    func onResultsShared(destination: String?) {
        MixpanelDiagnostic.diagnosticResultsShared(attemptId: attemptId, shareDestination: destination)
    }
}
