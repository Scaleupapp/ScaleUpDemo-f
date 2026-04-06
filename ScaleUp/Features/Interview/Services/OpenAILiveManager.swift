import Foundation
import AVFoundation

// MARK: - Interview Turn (shared enum)

enum InterviewTurn: Equatable {
    case aiSpeaking
    case readyCheck
    case waitingToAnswer
    case userRecording
    case processing
}

// MARK: - Audio IO (NOT MainActor — runs on audio thread)

/// Handles mic capture, resampling, and playback on background threads.
/// Completely decoupled from MainActor to avoid dispatch_assert_queue crashes.
final class AudioIO: @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    var isSending = false
    var onAudioChunk: ((String) -> Void)?  // base64 PCM16
    var onAudioLevel: ((Float) -> Void)?
    private var lastLevelTime = Date.distantPast

    func start() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            throw OpenAIError.audioSetupFailed("No audio input available.")
        }

        let srcRate = hwFormat.sampleRate
        let dstRate: Double = 24000

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

            guard self.isSending else { return }

            // Resample to 24kHz PCM16
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

            let base64 = pcmData.base64EncodedString()
            self.onAudioChunk?(base64)
        }

        engine.prepare()
        try engine.start()
        player.play()

        self.audioEngine = engine
        self.playerNode = player
    }

    func playAudio(_ data: Data) {
        guard data.count > 1, let player = playerNode else { return }
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!
        let frameCount = UInt32(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress, let ch = buffer.int16ChannelData else { return }
            memcpy(ch[0], base, data.count)
        }
        player.scheduleBuffer(buffer)
    }

    func stop() {
        isSending = false
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
    }
}

// MARK: - OpenAI Realtime Manager

@Observable @MainActor
final class OpenAILiveManager {
    var isConnected = false
    var turn: InterviewTurn = .processing
    var transcript: [TranscriptEntry] = []
    var error: String?
    var currentQuestion: String = ""
    var audioLevel: Float = 0
    var questionCount = 0
    var answerDuration: TimeInterval = 0
    var liveTranscription: String = ""
    private(set) var greetingDone = false

    private var webSocket: URLSessionWebSocketTask?
    private let audioIO = AudioIO()
    private var interviewStartTime = Date()
    private var answerStartTime = Date()
    private var answerTimer: Timer?

    // MARK: - Start Session

    func startSession(systemInstruction: String, token: String) async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview") else {
            throw OpenAIError.connectionFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: request)
        ws.resume()
        webSocket = ws
        isConnected = true
        interviewStartTime = Date()
        turn = .aiSpeaking

        // Audio level callback
        audioIO.onAudioLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        // Audio chunk callback — send to WebSocket
        audioIO.onAudioChunk = { [weak self] base64 in
            guard let self else { return }
            let ws = self.webSocket
            Task.detached {
                try? await ws?.send(.string("{\"type\":\"input_audio_buffer.append\",\"audio\":\"\(base64)\"}"))
            }
        }

        // Start audio engine (runs on its own thread, no MainActor)
        try audioIO.start()

        // Start receive loop
        Task { [weak self] in
            await self?.receiveLoop()
        }

        // Wait for WebSocket handshake + session.created
        try await Task.sleep(for: .seconds(1))

        // Configure session — ensure English voice and audio output
        try await webSocket?.send(.string(
            "{\"type\":\"session.update\",\"session\":{\"voice\":\"alloy\",\"modalities\":[\"audio\",\"text\"],\"input_audio_format\":\"pcm16\",\"output_audio_format\":\"pcm16\",\"input_audio_transcription\":{\"model\":\"whisper-1\"}}}"
        ))

        // Small delay for session.update to process
        try await Task.sleep(for: .milliseconds(500))

        // Trigger AI greeting
        try await webSocket?.send(.string(
            "{\"type\":\"response.create\",\"response\":{\"modalities\":[\"audio\",\"text\"],\"instructions\":\"Speak in English. Greet the candidate in 2-3 short sentences. Introduce yourself by name, mention the interview type and role. Then ask: Are you ready to begin? Do NOT ask any interview questions yet.\"}}"
        ))
    }

    // MARK: - Ready Check

    func confirmReady() {
        greetingDone = true
        turn = .processing

        Task {
            try? await webSocket?.send(.string(
                "{\"type\":\"response.create\",\"response\":{\"modalities\":[\"audio\",\"text\"],\"instructions\":\"The candidate is ready. Ask the first interview question now. Keep it to 2-3 sentences. After asking, call the report_question_meta function.\"}}"
            ))
        }
    }

    func declineAndExit() {
        endSession()
    }

    // MARK: - Push-to-Talk

    func startAnswering() {
        guard turn == .waitingToAnswer else { return }
        turn = .userRecording
        answerStartTime = Date()
        answerDuration = 0
        liveTranscription = ""
        audioIO.isSending = true

        answerTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.answerDuration = Date().timeIntervalSince(self.answerStartTime)
            }
        }
    }

    func finishAnswering() {
        guard turn == .userRecording else { return }
        audioIO.isSending = false
        answerTimer?.invalidate()
        answerTimer = nil
        turn = .processing

        Task {
            try? await webSocket?.send(.string("{\"type\":\"input_audio_buffer.commit\"}"))
            try? await webSocket?.send(.string(
                "{\"type\":\"response.create\",\"response\":{\"modalities\":[\"audio\",\"text\"],\"instructions\":\"The candidate has finished answering. Based on their response, ask a follow-up or move to the next question. Keep it to 2-3 sentences. Call report_question_meta after asking.\"}}"
            ))
        }
    }

    // MARK: - End Session

    func endSession() {
        audioIO.stop()
        answerTimer?.invalidate()
        answerTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
    }

    // MARK: - WebSocket Receive

    private func receiveLoop() async {
        guard let ws = webSocket else { return }
        do {
            while true {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    guard let data = text.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let type = json["type"] as? String else { continue }
                    await handleEvent(type: type, json: json)

                case .data(let data):
                    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let type = json["type"] as? String else { continue }
                    await handleEvent(type: type, json: json)

                @unknown default:
                    break
                }
            }
        } catch {
            self.error = "Connection lost: \(error.localizedDescription)"
            isConnected = false
        }
    }

    // MARK: - Event Handling

    private func handleEvent(type: String, json: [String: Any]) async {
        // Debug: log all event types
        if type != "response.audio.delta" {
            print("[OpenAI] Event: \(type)")
        }

        switch type {

        case "response.audio.delta":
            if turn != .aiSpeaking { turn = .aiSpeaking }
            if let audioB64 = json["delta"] as? String,
               let audioData = Data(base64Encoded: audioB64) {
                audioIO.playAudio(audioData)
            }

        case "response.audio_transcript.done":
            if let text = json["transcript"] as? String, !text.isEmpty {
                let elapsed = Date().timeIntervalSince(interviewStartTime)
                transcript.append(TranscriptEntry(
                    role: "interviewer", content: text,
                    questionNumber: questionCount > 0 ? questionCount : nil,
                    isFollowUp: false, timestamp: elapsed,
                    responseDuration: nil, createdAt: Date()
                ))
                currentQuestion = text
            }

        case "conversation.item.input_audio_transcription.completed":
            if let text = json["transcript"] as? String, !text.isEmpty {
                liveTranscription = text
                if let lastIdx = transcript.indices.last,
                   transcript[lastIdx].role == "candidate" {
                    let old = transcript[lastIdx]
                    transcript[lastIdx] = TranscriptEntry(
                        role: "candidate", content: text,
                        questionNumber: old.questionNumber, isFollowUp: old.isFollowUp,
                        timestamp: old.timestamp, responseDuration: old.responseDuration,
                        createdAt: old.createdAt
                    )
                }
            }

        case "response.function_call_arguments.done":
            if let name = json["name"] as? String, name == "report_question_meta",
               let argsStr = json["arguments"] as? String,
               let argsData = argsStr.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {

                let qNum = args["question_number"] as? Int ?? questionCount
                let isFollowUp = args["is_follow_up"] as? Bool ?? false
                let isComplete = args["is_complete"] as? Bool ?? false
                let qText = args["question_text"] as? String

                if !isFollowUp { questionCount = qNum }
                if let qText, !qText.isEmpty { currentQuestion = qText }

                if let lastIdx = transcript.indices.reversed().first(where: { transcript[$0].role == "interviewer" }) {
                    let old = transcript[lastIdx]
                    transcript[lastIdx] = TranscriptEntry(
                        role: "interviewer", content: qText ?? old.content,
                        questionNumber: qNum, isFollowUp: isFollowUp,
                        timestamp: old.timestamp, responseDuration: nil,
                        createdAt: old.createdAt
                    )
                }

                // Acknowledge function call
                let callId = json["call_id"] as? String ?? ""
                Task {
                    try? await webSocket?.send(.string(
                        "{\"type\":\"conversation.item.create\",\"item\":{\"type\":\"function_call_output\",\"call_id\":\"\(callId)\",\"output\":\"{\\\"status\\\":\\\"recorded\\\"}\"}}"
                    ))
                }
            }

        case "response.done":
            if !greetingDone {
                turn = .readyCheck
            } else {
                turn = .waitingToAnswer
            }

        case "input_audio_buffer.committed":
            let elapsed = Date().timeIntervalSince(interviewStartTime)
            let duration = Date().timeIntervalSince(answerStartTime)
            transcript.append(TranscriptEntry(
                role: "candidate",
                content: liveTranscription.isEmpty ? "(voice response — \(Int(duration))s)" : liveTranscription,
                questionNumber: questionCount, isFollowUp: false,
                timestamp: elapsed, responseDuration: duration,
                createdAt: Date()
            ))

        case "error":
            if let errorInfo = json["error"] as? [String: Any],
               let msg = errorInfo["message"] as? String {
                self.error = msg
            }

        default:
            break
        }
    }

    var isInterviewComplete: Bool {
        guard let last = transcript.last else { return false }
        return last.role == "interviewer" &&
            (last.content.lowercased().contains("concludes our interview") ||
             last.content.lowercased().contains("end of our interview"))
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case connectionFailed(String)
    case audioSetupFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let m): return "Could not connect to AI interviewer: \(m)"
        case .audioSetupFailed(let m): return "Audio setup failed: \(m)"
        }
    }
}
