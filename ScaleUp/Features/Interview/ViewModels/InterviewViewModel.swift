import Foundation
import SwiftUI

@Observable @MainActor
final class InterviewViewModel {

    // MARK: - Setup

    var selectedType: InterviewType = .behavioral
    var targetRole = ""
    var targetCompany = ""
    var selectedDifficulty: InterviewDifficulty = .moderate
    var selectedObjectiveId: String?

    // MARK: - Session

    var sessionId: String?
    var systemInstruction: String?

    // MARK: - State Machine

    enum ViewState: Equatable {
        case setup
        case cameraCheck
        case connecting
        case interviewing
        case concluding
        case saving
        case evaluating
        case results
        case error(String)

        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.setup, .setup), (.cameraCheck, .cameraCheck), (.connecting, .connecting),
                 (.interviewing, .interviewing), (.concluding, .concluding), (.saving, .saving),
                 (.evaluating, .evaluating), (.results, .results):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    var state: ViewState = .setup

    // MARK: - Transcript & Evaluation

    var transcript: [TranscriptEntry] { geminiManager.transcript }

    var questionCount: Int {
        geminiManager.transcript
            .filter { $0.isInterviewer && $0.questionNumber != nil && $0.isFollowUp != true }
            .count
    }

    var evaluation: InterviewEvaluation?
    var fullSession: InterviewSession?

    // MARK: - Managers

    let geminiManager = GeminiLiveManager()
    let proctor = InterviewProctor()

    // MARK: - Timer

    var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    private var interviewStartTime: Date?

    private let service = InterviewService()

    // MARK: - Setup Actions

    var canStart: Bool { !targetRole.trimmingCharacters(in: .whitespaces).isEmpty }

    func proceedToCameraCheck() {
        state = .cameraCheck
    }

    // MARK: - Start Interview

    func startInterview() async {
        state = .connecting
        do {
            let response = try await service.startInterview(
                type: selectedType,
                targetRole: targetRole.trimmingCharacters(in: .whitespaces),
                targetCompany: targetCompany.isEmpty ? nil : targetCompany,
                difficulty: selectedDifficulty,
                objectiveId: selectedObjectiveId
            )

            sessionId = response.session._id
            systemInstruction = response.systemInstruction
            interviewStartTime = Date()

            try await geminiManager.startSession(systemInstruction: response.systemInstruction)

            proctor.startMonitoring(sessionId: response.session._id, startTime: interviewStartTime!)

            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.elapsedTime = Date().timeIntervalSince(self.interviewStartTime ?? Date())

                    if self.geminiManager.isInterviewComplete && self.state == .interviewing {
                        self.state = .concluding
                        try? await Task.sleep(for: .seconds(3))
                        await self.saveAndEvaluate()
                    }
                }
            }

            state = .interviewing
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - End Interview (manual)

    func endInterview() async {
        geminiManager.endSession()
        await saveAndEvaluate()
    }

    // MARK: - Save & Evaluate

    private func saveAndEvaluate() async {
        state = .saving
        timer?.invalidate()
        proctor.stopMonitoring()
        geminiManager.endSession()

        guard let sessionId else { return }

        do {
            try await service.completeInterview(sessionId: sessionId, transcript: geminiManager.transcript)
            state = .evaluating
            await pollForEvaluation()
        } catch {
            state = .error("Failed to save interview: \(error.localizedDescription)")
        }
    }

    // MARK: - Poll for Evaluation

    private func pollForEvaluation() async {
        guard let sessionId else { return }

        for _ in 0..<40 {
            try? await Task.sleep(for: .seconds(3))

            do {
                let status = try await service.getStatus(sessionId: sessionId)
                if status.status == .evaluated {
                    let session = try await service.getSession(sessionId: sessionId)
                    fullSession = session
                    evaluation = session.evaluation
                    state = .results
                    return
                }
            } catch {}
        }

        state = .error("Evaluation is taking longer than expected. Check back in Interview History.")
    }

    // MARK: - Load Existing Session (from history)

    func loadSession(_ sessionId: String) async {
        do {
            let session = try await service.getSession(sessionId: sessionId)
            self.sessionId = sessionId
            fullSession = session
            evaluation = session.evaluation
            state = .results
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Timer Display

    var elapsedString: String {
        let mins = Int(elapsedTime) / 60
        let secs = Int(elapsedTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
