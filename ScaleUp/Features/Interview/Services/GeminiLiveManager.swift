import Foundation
import AVFoundation
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
    private var audioEngine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var questionCount = 0
    private var interviewStartTime = Date()
    private var lastAIFinishTime = Date()

    // Audio format for Gemini output: 16-bit PCM at 24kHz mono
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!

    // MARK: - Start Session

    func startSession(systemInstruction: String) async throws {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        // Create Gemini Live model
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
            modelName: "gemini-live-2.5-flash-preview",
            generationConfig: LiveGenerationConfig(
                responseModalities: [.audio],
                speech: SpeechConfig(voiceName: "Puck")
            ),
            systemInstruction: ModelContent(role: "system", parts: systemInstruction)
        )

        // Connect
        let session = try await model.connect()
        liveSession = session
        isConnected = true
        interviewStartTime = Date()

        // Setup audio playback
        setupAudioPlayer()

        // Start receiving AI responses
        Task { await receiveResponses() }

        // Start streaming mic audio
        startMicCapture()
    }

    // MARK: - End Session

    func endSession() {
        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        playerNode?.stop()

        Task {
            await liveSession?.close()
        }
        liveSession = nil
        isConnected = false
    }

    // MARK: - Audio Player Setup

    private func setupAudioPlayer() {
        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: outputFormat)
        playerNode = player
    }

    // MARK: - Mic Capture → Gemini

    private func startMicCapture() {
        let inputNode = audioEngine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // Convert to 16-bit PCM data and send to Gemini
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            var pcmData = Data(count: frameCount * 2) // 16-bit = 2 bytes per sample
            pcmData.withUnsafeMutableBytes { rawBuffer in
                let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
                for i in 0..<frameCount {
                    let sample = max(-1.0, min(1.0, channelData[0][i]))
                    int16Buffer[i] = Int16(sample * Float(Int16.max))
                }
            }

            Task { @MainActor [weak self] in
                guard let self, self.isConnected else { return }
                self.isUserSpeaking = true
                await self.liveSession?.sendAudioRealtime(pcmData)
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
        playerNode?.play()
    }

    // MARK: - Receive Responses

    private func receiveResponses() async {
        guard let session = liveSession else { return }

        do {
            for try await message in session.responses {
                if case let .content(content) = message.payload {
                    isAISpeaking = true
                    isUserSpeaking = false

                    // Handle audio output
                    content.modelTurn?.parts.forEach { part in
                        if let inlinePart = part as? InlineDataPart,
                           inlinePart.mimeType.starts(with: "audio/pcm") {
                            playAudioData(inlinePart.data)
                        }
                        if let textPart = part as? TextPart {
                            handleAIText(textPart.text)
                        }
                    }

                    // Check for turn complete
                    if content.isTurnComplete {
                        isAISpeaking = false
                        lastAIFinishTime = Date()
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
            isConnected = false
        }
    }

    // MARK: - Audio Playback

    private func playAudioData(_ data: Data) {
        let frameCount = UInt32(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                memcpy(buffer.int16ChannelData?[0], baseAddress, data.count)
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
