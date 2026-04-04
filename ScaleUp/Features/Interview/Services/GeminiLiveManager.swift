import Foundation
import AVFoundation
import FirebaseAI

// MARK: - Gemini Live API Placeholder Types
// The Firebase AI SDK (v11.x) does not yet include the Live API.
// These stubs let the code compile. When firebase-ios-sdk ships
// the Live streaming API, replace these with the real types and
// uncomment the session logic below.

/// Placeholder for the real `LiveSession` from FirebaseAI.
final class LiveSession: @unchecked Sendable {
    func disconnect() {}
}

// MARK: - Gemini Live Manager

@Observable @MainActor
final class GeminiLiveManager {
    var isConnected = false
    var isAISpeaking = false
    var isUserSpeaking = false
    var transcript: [TranscriptEntry] = []
    var error: String?

    private var liveSession: LiveSession?
    private var audioEngine = AVAudioEngine()
    private var questionCount = 0
    private var interviewStartTime = Date()
    private var lastAIFinishTime = Date()

    // MARK: - Start Session

    func startSession(systemInstruction: String) async throws {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        // -------------------------------------------------------------------
        // TODO: Replace with real Firebase AI Live API when available.
        //
        //   let ai = FirebaseAI.firebaseAI()
        //   let model = ai.generativeModel(modelName: "gemini-2.0-flash-live")
        //   let config = LiveConnectConfig(
        //       responseModalities: [.audio],
        //       systemInstruction: ModelContent(
        //           role: "system",
        //           parts: [.text(systemInstruction)]
        //       ),
        //       speechConfig: SpeechConfig(
        //           voiceConfig: VoiceConfig(
        //               prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: "Puck")
        //           )
        //       )
        //   )
        //   liveSession = try await model.connect(config: config)
        //
        // -------------------------------------------------------------------

        liveSession = LiveSession()
        isConnected = true
        interviewStartTime = Date()

        // Start receiving AI responses (no-op until real SDK is available)
        // Task { await receiveResponses() }

        // Start streaming mic audio to Gemini
        startMicCapture()
    }

    // MARK: - End Session

    func endSession() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        liveSession?.disconnect()
        liveSession = nil
        isConnected = false
    }

    // MARK: - Mic Capture

    private func startMicCapture() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self, self.isConnected else { return }
            Task { @MainActor in
                self.isUserSpeaking = true
                // TODO: Send audio buffer to Gemini Live session
                // self.liveSession?.send(input: .audioBuffer(buffer))
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }

    // MARK: - Receive Responses (Live API)

    /// Called in a background Task to consume the async stream of server
    /// messages from the Gemini Live session. Currently stubbed.
    private func receiveResponses() async {
        guard liveSession != nil else { return }

        // TODO: Uncomment when Live API is available
        // do {
        //     for try await message in session.receive {
        //         await MainActor.run {
        //             switch message {
        //             case .setupComplete:
        //                 break
        //             case .serverContent(let content):
        //                 self.isAISpeaking = true
        //                 self.isUserSpeaking = false
        //                 if let text = content.modelTurn?.parts.compactMap({ part -> String? in
        //                     if case .text(let t) = part { return t }
        //                     return nil
        //                 }).joined(), !text.isEmpty {
        //                     self.handleAIText(text)
        //                 }
        //                 if content.turnComplete {
        //                     self.isAISpeaking = false
        //                     self.lastAIFinishTime = Date()
        //                 }
        //             default:
        //                 break
        //             }
        //         }
        //     }
        // } catch {
        //     await MainActor.run {
        //         self.error = error.localizedDescription
        //         self.isConnected = false
        //     }
        // }
    }

    // MARK: - Handle AI Text

    func handleAIText(_ text: String) {
        let isClosing = text.contains("concludes our interview") || text.contains("end of our interview")
        let elapsed = Date().timeIntervalSince(interviewStartTime)

        let isFollowUp = text.lowercased().contains("elaborate") ||
            text.lowercased().contains("tell me more") ||
            text.lowercased().contains("can you give")

        if !isFollowUp && !isClosing {
            questionCount += 1
        }

        let entry = TranscriptEntry(
            role: "interviewer",
            content: text,
            questionNumber: isClosing ? nil : questionCount,
            isFollowUp: isFollowUp,
            timestamp: elapsed,
            responseDuration: nil,
            createdAt: Date()
        )
        transcript.append(entry)
    }

    // MARK: - Record User Response

    func recordUserResponse(_ text: String) {
        let elapsed = Date().timeIntervalSince(interviewStartTime)
        let responseTime = Date().timeIntervalSince(lastAIFinishTime)

        let entry = TranscriptEntry(
            role: "candidate",
            content: text,
            questionNumber: questionCount,
            isFollowUp: false,
            timestamp: elapsed,
            responseDuration: responseTime,
            createdAt: Date()
        )
        transcript.append(entry)
    }

    // MARK: - Helpers

    var isInterviewComplete: Bool {
        transcript.last?.content.contains("concludes our interview") == true ||
        transcript.last?.content.contains("end of our interview") == true
    }
}
