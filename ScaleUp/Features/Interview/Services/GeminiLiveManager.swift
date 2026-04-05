import Foundation
import AVFoundation
import FirebaseCore
import FirebaseAI

// MARK: - Gemini Live Manager

@Observable @MainActor
final class GeminiLiveManager {
    var isConnected = false
    var isAISpeaking = false
    var isUserSpeaking = false
    var transcript: [TranscriptEntry] = []
    var error: String?

    private var liveSession: LiveSession?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var questionCount = 0
    private var interviewStartTime = Date()
    private var lastAIFinishTime = Date()

    // MARK: - Start Session

    func startSession(systemInstruction: String) async throws {
        // Step 1: Firebase
        if FirebaseApp.app() == nil {
            guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
                throw GeminiError.firebaseConfigFailed("GoogleService-Info.plist not found in app bundle.")
            }
            FirebaseApp.configure()
        }
        guard FirebaseApp.app() != nil else {
            throw GeminiError.firebaseConfigFailed("Firebase failed to initialize.")
        }

        // Step 2: Audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            throw GeminiError.audioSetupFailed("Audio session setup failed: \(error.localizedDescription)")
        }

        // Step 3: Gemini Live model
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
            modelName: "gemini-2.5-flash-native-audio-preview-12-2025",
            generationConfig: LiveGenerationConfig(
                responseModalities: [.audio],
                speech: SpeechConfig(voiceName: "Puck")
            ),
            systemInstruction: ModelContent(role: "system", parts: systemInstruction)
        )

        // Step 4: Connect
        let session: LiveSession
        do {
            session = try await model.connect()
        } catch {
            throw GeminiError.connectionFailed(error.localizedDescription)
        }

        liveSession = session
        isConnected = true
        interviewStartTime = Date()

        // Step 5: Receive AI responses (background task)
        Task { [weak self] in
            await self?.receiveResponses()
        }

        // Step 6: Start mic capture (can fail gracefully)
        do {
            try startMicCapture()
        } catch {
            // Mic failed but we can still receive AI audio — don't crash
            self.error = "Microphone unavailable: \(error.localizedDescription)"
        }
    }

    // MARK: - End Session

    func endSession() {
        // Stop audio engine safely
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            if let player = playerNode {
                player.stop()
                engine.detach(player)
            }
        }
        audioEngine = nil
        playerNode = nil

        // Close Gemini session
        Task {
            await liveSession?.close()
        }
        liveSession = nil
        isConnected = false
    }

    // MARK: - Mic Capture → Gemini

    private func startMicCapture() throws {
        let engine = AVAudioEngine()
        self.audioEngine = engine

        // Setup player node for AI audio output
        let player = AVAudioPlayerNode()
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        self.playerNode = player

        // Get mic input format
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            throw GeminiError.audioSetupFailed("No audio input available.")
        }

        // Capture a reference to the live session outside the closure
        // to avoid accessing @MainActor-isolated self from the audio thread
        let session = self.liveSession

        // Install mic tap — this closure runs on an audio thread, NOT main actor
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }

            // Convert float samples to 16-bit PCM
            var pcmData = Data(count: frameCount * 2)
            pcmData.withUnsafeMutableBytes { rawBuffer in
                let int16Ptr = rawBuffer.bindMemory(to: Int16.self)
                for i in 0..<frameCount {
                    let sample = max(-1.0, min(1.0, channelData[0][i]))
                    int16Ptr[i] = Int16(sample * Float(Int16.max))
                }
            }

            // Send on a detached task to avoid MainActor isolation issues
            Task.detached {
                try? await session?.sendAudioRealtime(pcmData)
            }
        }

        // Start engine
        engine.prepare()
        try engine.start()
        player.play()
    }

    // MARK: - Receive Responses

    private func receiveResponses() async {
        guard let session = liveSession else { return }

        do {
            for try await message in session.responses {
                await MainActor.run { [weak self] in
                    guard let self else { return }

                    if case let .content(content) = message.payload {
                        self.isAISpeaking = true
                        self.isUserSpeaking = false

                        // Handle audio + text from model turn
                        if let parts = content.modelTurn?.parts {
                            for part in parts {
                                if let inlinePart = part as? InlineDataPart,
                                   inlinePart.mimeType.starts(with: "audio/pcm") {
                                    self.playAudioData(inlinePart.data)
                                }
                                if let textPart = part as? TextPart, !textPart.text.isEmpty {
                                    self.handleAIText(textPart.text)
                                }
                            }
                        }

                        if content.isTurnComplete {
                            self.isAISpeaking = false
                            self.lastAIFinishTime = Date()
                        }
                    }
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.error = "Interview connection lost: \(error.localizedDescription)"
                self?.isConnected = false
            }
        }
    }

    // MARK: - Audio Playback

    private func playAudioData(_ data: Data) {
        guard data.count > 1 else { return }
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!
        let frameCount = UInt32(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            if let channelData = buffer.int16ChannelData {
                memcpy(channelData[0], baseAddress, data.count)
            }
        }

        playerNode?.scheduleBuffer(buffer)
    }

    // MARK: - Handle AI Text

    func handleAIText(_ text: String) {
        guard !text.isEmpty else { return }

        let isClosing = text.contains("concludes our interview") || text.contains("end of our interview")
        let elapsed = Date().timeIntervalSince(interviewStartTime)

        let lower = text.lowercased()
        let isFollowUp = lower.contains("elaborate") || lower.contains("tell me more") ||
            lower.contains("can you give") || lower.contains("could you explain")

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
        guard !text.isEmpty else { return }
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
        guard let last = transcript.last else { return false }
        return last.role == "interviewer" &&
            (last.content.contains("concludes our interview") || last.content.contains("end of our interview"))
    }
}

// MARK: - Error Types

enum GeminiError: LocalizedError {
    case firebaseConfigFailed(String)
    case connectionFailed(String)
    case audioSetupFailed(String)

    var errorDescription: String? {
        switch self {
        case .firebaseConfigFailed(let msg): return "Firebase setup failed: \(msg)"
        case .connectionFailed(let msg): return "Could not connect to AI interviewer: \(msg)"
        case .audioSetupFailed(let msg): return "Audio setup failed: \(msg)"
        }
    }
}
