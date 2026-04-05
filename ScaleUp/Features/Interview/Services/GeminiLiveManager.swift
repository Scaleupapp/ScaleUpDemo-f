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

    /// When false, mic is captured for level detection but NOT sent to Gemini.
    var isSendingAudio = false
    var onAudioLevel: ((Float) -> Void)?
    private var lastLevelTime = Date.distantPast

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

        let capturedSession = session
        let srcRate = hwFormat.sampleRate
        let dstRate: Double = 16000

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }

            // Audio level (throttled ~10 fps)
            let now = Date()
            if now.timeIntervalSince(self.lastLevelTime) > 0.1 {
                self.lastLevelTime = now
                var sum: Float = 0
                let step = max(1, frameCount / 256)
                var count = 0
                for i in Swift.stride(from: 0, to: frameCount, by: step) {
                    let s = channelData[0][i]
                    sum += s * s
                    count += 1
                }
                let rms = sqrt(sum / Float(max(1, count)))
                self.onAudioLevel?(rms)
            }

            // Only send audio to Gemini when explicitly enabled
            guard self.isSendingAudio else { return }

            let outputCount = Int(Double(frameCount) * dstRate / srcRate)
            guard outputCount > 0 else { return }

            var pcmData = Data(count: outputCount * 2)
            pcmData.withUnsafeMutableBytes { rawBuffer in
                let ptr = rawBuffer.bindMemory(to: Int16.self)
                for i in 0..<outputCount {
                    let srcPos = Double(i) * srcRate / dstRate
                    let srcIdx = Int(srcPos)
                    let frac = Float(srcPos - Double(srcIdx))

                    let s0 = channelData[0][min(srcIdx, frameCount - 1)]
                    let s1 = channelData[0][min(srcIdx + 1, frameCount - 1)]
                    let sample = max(-1.0, min(1.0, s0 + (s1 - s0) * frac))
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
        isSendingAudio = false
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

/// Interview turn state — drives the entire UI.
enum InterviewTurn: Equatable {
    case aiSpeaking         // AI is speaking (greeting or question)
    case readyCheck         // After greeting — "Are you ready?"
    case waitingToAnswer    // After a question — user hasn't tapped yet
    case userRecording      // User tapped mic, audio flowing to Gemini
    case processing         // User tapped done, waiting for AI to respond
}

@Observable @MainActor
final class GeminiLiveManager {
    var isConnected = false
    var turn: InterviewTurn = .aiSpeaking
    var transcript: [TranscriptEntry] = []
    var error: String?
    var currentQuestion: String = ""
    var audioLevel: Float = 0
    var questionCount = 0
    var answerDuration: TimeInterval = 0

    /// Has the AI finished its greeting and user confirmed ready?
    private(set) var greetingDone = false

    private var liveSession: LiveSession?
    private let audioSender = AudioSender()
    private var interviewStartTime = Date()
    private var answerStartTime = Date()
    private var pendingAIText = ""
    private var answerTimer: Timer?

    // MARK: - Start Session

    func startSession(systemInstruction: String) async throws {
        if FirebaseApp.app() == nil {
            guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
                throw GeminiError.firebaseConfigFailed("GoogleService-Info.plist not found in app bundle.")
            }
            FirebaseApp.configure()
        }
        guard FirebaseApp.app() != nil else {
            throw GeminiError.firebaseConfigFailed("Firebase failed to initialize.")
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            throw GeminiError.audioSetupFailed("Audio session: \(error.localizedDescription)")
        }

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
        turn = .aiSpeaking

        Task { [weak self] in
            await self?.receiveResponses()
        }

        // Brief greeting only — no questions yet
        Task.detached {
            await session.sendTextRealtime(
                "Greet the candidate in 2-3 short sentences. Introduce yourself by name, mention the interview type and role. Then ask: 'Are you ready to begin?' Do NOT ask any interview questions yet. Keep it brief and warm."
            )
        }

        audioSender.onAudioLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        do {
            try audioSender.start(session: session)
        } catch {
            self.error = "Mic unavailable: \(error.localizedDescription)"
        }
    }

    // MARK: - Ready Check

    /// User confirmed they're ready — tell AI to start questioning.
    func confirmReady() {
        greetingDone = true
        turn = .processing

        Task.detached { [weak self] in
            guard let session = await self?.liveSession else { return }
            await session.sendTextRealtime(
                "The candidate is ready. Ask the first interview question now. Keep it concise and direct."
            )
        }
    }

    /// User is not ready — end session for now.
    func declineAndExit() {
        endSession()
    }

    // MARK: - Push-to-Talk Controls

    func startAnswering() {
        guard turn == .waitingToAnswer else { return }
        turn = .userRecording
        answerStartTime = Date()
        answerDuration = 0
        audioSender.isSendingAudio = true

        answerTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.answerDuration = Date().timeIntervalSince(self.answerStartTime)
            }
        }
    }

    func finishAnswering() {
        guard turn == .userRecording else { return }
        audioSender.isSendingAudio = false
        answerTimer?.invalidate()
        answerTimer = nil
        turn = .processing

        let elapsed = Date().timeIntervalSince(interviewStartTime)
        let duration = Date().timeIntervalSince(answerStartTime)
        transcript.append(TranscriptEntry(
            role: "candidate", content: "(answered via voice — \(Int(duration))s)",
            questionNumber: questionCount, isFollowUp: false,
            timestamp: elapsed, responseDuration: duration,
            createdAt: Date()
        ))

        Task.detached { [weak self] in
            guard let session = await self?.liveSession else { return }
            await session.sendTextRealtime(
                "The candidate has finished answering. Based on their response, decide: either ask a follow-up question to probe deeper, or move to the next topic. Do not repeat what they said. Be concise."
            )
        }
    }

    // MARK: - End Session

    func endSession() {
        audioSender.stop()
        answerTimer?.invalidate()
        answerTimer = nil
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
                    if turn != .aiSpeaking {
                        turn = .aiSpeaking
                    }

                    if let parts = content.modelTurn?.parts {
                        for part in parts {
                            if let inlinePart = part as? InlineDataPart,
                               inlinePart.mimeType.starts(with: "audio/pcm") {
                                audioSender.playAudio(inlinePart.data)
                            }
                            if let textPart = part as? TextPart, !textPart.text.isEmpty {
                                pendingAIText += textPart.text + "\n"
                            }
                        }
                    }

                    if content.isTurnComplete {
                        let text = pendingAIText.trimmingCharacters(in: .whitespacesAndNewlines)
                        pendingAIText = ""

                        if !greetingDone {
                            // Greeting just finished — show ready check
                            turn = .readyCheck
                        } else {
                            // Process as a question turn
                            if !text.isEmpty {
                                processCompletedAITurn(text)
                            }
                            turn = .waitingToAnswer
                        }
                    }
                }
            }
        } catch {
            self.error = "Connection lost: \(error.localizedDescription)"
            isConnected = false
        }
    }

    // MARK: - Process Completed AI Turn

    private func processCompletedAITurn(_ rawText: String) {
        // The text from Gemini native audio is internal "thinking" — NOT what was spoken.
        // Extract only candidate-facing sentences (questions, direct address).
        let cleaned = extractSpokenContent(rawText)
        let elapsed = Date().timeIntervalSince(interviewStartTime)

        let lower = cleaned.lowercased()
        let isClosing = lower.contains("concludes our interview") || lower.contains("end of our interview")
        let isFollowUp = lower.contains("elaborate") || lower.contains("tell me more") || lower.contains("can you give") || lower.contains("follow up") || lower.contains("follow-up") || lower.contains("could you expand")

        if !isFollowUp && !isClosing { questionCount += 1 }

        // Store the cleaned version (may be empty if all text was reasoning)
        let displayText = cleaned.isEmpty ? "Question \(questionCount)" : cleaned

        transcript.append(TranscriptEntry(
            role: "interviewer", content: displayText,
            questionNumber: isClosing ? nil : questionCount,
            isFollowUp: isFollowUp, timestamp: elapsed,
            responseDuration: nil, createdAt: Date()
        ))

        if !isClosing {
            currentQuestion = displayText
        }
    }

    // MARK: - Extract Spoken Content

    /// Gemini native audio model sends "thinking" text, not spoken text.
    /// This extracts only sentences likely directed at the candidate.
    private func extractSpokenContent(_ text: String) -> String {
        var cleaned = text
        // Strip markdown
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\\n\\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\\n", with: "\n")

        // Split into rough sentences
        cleaned = cleaned.replacingOccurrences(of: "\n", with: ". ")
        // Normalize sentence boundaries
        var normalized = cleaned
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "! ", with: "!\n")
        let sentences = normalized.components(separatedBy: "\n")

        let kept = sentences.compactMap { raw -> String? in
            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard s.count > 3 else { return nil }
            let lower = s.lowercased()

            // KEEP: questions (contain ?)
            if s.contains("?") { return s }

            // KEEP: sentences addressing the candidate
            let addressPatterns = [" you ", "your ", "you're", "you've", "yourself"]
            if addressPatterns.contains(where: { lower.contains($0) }) { return s }

            // KEEP: greetings
            let greetings = ["hello", "hi ", "welcome", "good morning", "good afternoon", "good evening", "nice to meet"]
            if greetings.contains(where: { lower.hasPrefix($0) || lower.contains($0) }) { return s }

            // DROP: first-person reasoning / planning
            let dropPatterns = [
                "i've ", "i'm ", "i am ", "i'll ", "i will ", "i have ",
                "my goal", "my approach", "my prompt", "my chosen", "my plan",
                "it's designed", "the goal is", "the case involves",
                "focusing on", "structured it", "to avoid repeating",
                "launching the", "defining the", "refining the", "formulating the",
                "crafting the", "preparing the", "designing the",
                "carefully avoiding", "previously used",
                "explores strategic", "incorporating",
            ]
            if dropPatterns.contains(where: { lower.contains($0) }) { return nil }

            // DROP: short header-like text without punctuation
            if s.count < 50 && !s.contains("?") && !s.contains(",") { return nil }

            // Default: keep if it seems conversational (has common words)
            return nil
        }

        return kept.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
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
