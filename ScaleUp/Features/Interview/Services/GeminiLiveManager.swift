import Foundation
import AVFoundation
import FirebaseCore
import FirebaseAI

// MARK: - Audio Sender (NOT MainActor — runs on audio thread)

/// Handles mic capture and audio sending on a background queue.
/// Completely decoupled from MainActor to avoid dispatch_assert_queue crashes.
final class AudioSender: @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private weak var session: LiveSession?
    private let queue = DispatchQueue(label: "com.scaleup.audiosender")
    var onAudioData: ((Data) -> Void)?

    func start(session: LiveSession) throws {
        self.session = session

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            throw GeminiError.audioSetupFailed("No audio input available.")
        }

        // Capture session ref — closure is NOT @MainActor
        let capturedSession = session
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }

            var pcmData = Data(count: frameCount * 2)
            pcmData.withUnsafeMutableBytes { rawBuffer in
                let ptr = rawBuffer.bindMemory(to: Int16.self)
                for i in 0..<frameCount {
                    let sample = max(-1.0, min(1.0, channelData[0][i]))
                    ptr[i] = Int16(sample * Float(Int16.max))
                }
            }

            Task.detached(priority: .userInitiated) {
                try? await capturedSession.sendAudioRealtime(pcmData)
            }
        }

        engine.prepare()
        try engine.start()
        player.play()

        self.audioEngine = engine
        self.playerNode = player
    }

    func playAudio(_ data: Data) {
        guard data.count > 1 else { return }
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!
        let frameCount = UInt32(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress, let ch = buffer.int16ChannelData else { return }
            memcpy(ch[0], base, data.count)
        }
        playerNode?.scheduleBuffer(buffer)
    }

    func stop() {
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
        session = nil
    }
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
    private let audioSender = AudioSender()
    private var questionCount = 0
    private var interviewStartTime = Date()
    private var lastAIFinishTime = Date()

    // MARK: - Start Session

    func startSession(systemInstruction: String) async throws {
        // Firebase
        if FirebaseApp.app() == nil {
            guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
                throw GeminiError.firebaseConfigFailed("GoogleService-Info.plist not found in app bundle.")
            }
            FirebaseApp.configure()
        }
        guard FirebaseApp.app() != nil else {
            throw GeminiError.firebaseConfigFailed("Firebase failed to initialize.")
        }

        // Audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            throw GeminiError.audioSetupFailed("Audio session: \(error.localizedDescription)")
        }

        // Gemini
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
            modelName: "gemini-2.5-flash-native-audio-preview-12-2025",
            generationConfig: LiveGenerationConfig(
                responseModalities: [.audio],
                speech: SpeechConfig(voiceName: "Puck")
            ),
            systemInstruction: ModelContent(role: "system", parts: systemInstruction)
        )

        let session: LiveSession
        do {
            session = try await model.connect()
        } catch {
            throw GeminiError.connectionFailed(error.localizedDescription)
        }

        liveSession = session
        isConnected = true
        interviewStartTime = Date()

        // Start receiving AI responses
        Task { [weak self] in
            await self?.receiveResponses()
        }

        // Send initial text prompt to trigger the AI to start speaking
        Task.detached {
            await session.sendTextRealtime("Please begin the interview. Introduce yourself and ask the first question.")
        }

        // Start mic on background — completely isolated from MainActor
        do {
            try audioSender.start(session: session)
        } catch {
            self.error = "Mic unavailable: \(error.localizedDescription)"
        }
    }

    // MARK: - End Session

    func endSession() {
        audioSender.stop()
        Task { await liveSession?.close() }
        liveSession = nil
        isConnected = false
    }

    // MARK: - Receive Responses

    private func receiveResponses() async {
        guard let session = liveSession else { return }
        do {
            for try await message in session.responses {
                if case let .content(content) = message.payload {
                    isAISpeaking = true
                    isUserSpeaking = false

                    if let parts = content.modelTurn?.parts {
                        for part in parts {
                            if let inlinePart = part as? InlineDataPart,
                               inlinePart.mimeType.starts(with: "audio/pcm") {
                                audioSender.playAudio(inlinePart.data)
                            }
                            if let textPart = part as? TextPart, !textPart.text.isEmpty {
                                handleAIText(textPart.text)
                            }
                        }
                    }

                    if content.isTurnComplete {
                        isAISpeaking = false
                        lastAIFinishTime = Date()
                    }
                }
            }
        } catch {
            self.error = "Connection lost: \(error.localizedDescription)"
            isConnected = false
        }
    }

    // MARK: - Transcript

    func handleAIText(_ text: String) {
        guard !text.isEmpty else { return }
        let isClosing = text.contains("concludes our interview") || text.contains("end of our interview")
        let elapsed = Date().timeIntervalSince(interviewStartTime)
        let lower = text.lowercased()
        let isFollowUp = lower.contains("elaborate") || lower.contains("tell me more") || lower.contains("can you give")

        if !isFollowUp && !isClosing { questionCount += 1 }

        transcript.append(TranscriptEntry(
            role: "interviewer", content: text,
            questionNumber: isClosing ? nil : questionCount,
            isFollowUp: isFollowUp, timestamp: elapsed,
            responseDuration: nil, createdAt: Date()
        ))
    }

    func recordUserResponse(_ text: String) {
        guard !text.isEmpty else { return }
        let elapsed = Date().timeIntervalSince(interviewStartTime)
        let responseTime = Date().timeIntervalSince(lastAIFinishTime)

        transcript.append(TranscriptEntry(
            role: "candidate", content: text,
            questionNumber: questionCount, isFollowUp: false,
            timestamp: elapsed, responseDuration: responseTime,
            createdAt: Date()
        ))
    }

    var isInterviewComplete: Bool {
        guard let last = transcript.last else { return false }
        return last.role == "interviewer" &&
            (last.content.contains("concludes our interview") || last.content.contains("end of our interview"))
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case firebaseConfigFailed(String)
    case connectionFailed(String)
    case audioSetupFailed(String)

    var errorDescription: String? {
        switch self {
        case .firebaseConfigFailed(let m): return "Firebase setup failed: \(m)"
        case .connectionFailed(let m): return "Could not connect to AI interviewer: \(m)"
        case .audioSetupFailed(let m): return "Audio setup failed: \(m)"
        }
    }
}
