import SwiftUI
import AVFoundation
import UIKit

struct VoiceAnswerResult {
    let transcription: String
    let overallScore: Int
    let band: String
    let feedback: String
    let audioUrl: String
}

struct DiagnosticVoiceAnswerView: View {
    let questionId: String
    let questionText: String
    let canonicalCompetency: String
    let onComplete: (VoiceAnswerResult) -> Void
    let onFallbackToTyped: () -> Void

    @StateObject private var recorder = VoiceRecorder()
    @State private var isProcessing = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text(questionText)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            WaveformView(samples: recorder.audioSamples, isRecording: recorder.isRecording)
                .frame(height: 80)
                .padding(.horizontal, Spacing.lg)

            Text(formatDuration(recorder.duration))
                .font(Typography.captionBold)
                .foregroundStyle(recorder.duration >= 60 ? ColorTokens.error : ColorTokens.textSecondary)

            HStack(spacing: Spacing.lg) {
                if recorder.isRecording {
                    Button(action: { recorder.stop() }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(ColorTokens.error)
                    }
                    .accessibilityLabel("Stop recording")
                } else if recorder.audioURL != nil {
                    Button(action: submit) {
                        Text("Submit").font(Typography.bodyBold)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.vertical, Spacing.md)
                            .background(ColorTokens.gold)
                            .foregroundStyle(ColorTokens.buttonPrimaryText)
                            .clipShape(Capsule())
                    }
                    .disabled(isProcessing)
                    Button(action: { recorder.reset() }) {
                        Text("Re-record").font(Typography.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .disabled(isProcessing)
                } else {
                    Button(action: { recorder.start() }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .accessibilityLabel("Start recording")
                }
            }

            Button(action: {
                if let reason = error {
                    MixpanelDiagnostic.trackVoiceFailedFallbackTyped(
                        questionId: questionId,
                        reason: reason
                    )
                }
                onFallbackToTyped()
            }) {
                Text("Prefer to type?")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .underline()
            }

            if isProcessing {
                ProgressView("Transcribing & scoring…")
                    .padding(.top, Spacing.md)
            }

            if let error {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.error)
                    .padding(.horizontal, Spacing.lg)
            }
        }
        .padding(Spacing.lg)
    }

    private func submit() {
        guard let url = recorder.audioURL else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isProcessing = true
        error = nil
        Task {
            do {
                let result = try await VoiceUploadAPI.upload(
                    audioURL: url,
                    questionText: questionText,
                    canonicalCompetency: canonicalCompetency
                )
                await MainActor.run {
                    isProcessing = false
                    onComplete(result)
                }
            } catch let err {
                await MainActor.run {
                    isProcessing = false
                    error = "Couldn't process voice. Try recording again or type your answer."
                    print("[VoiceAnswer] error:", err)
                }
            }
        }
    }

    private func formatDuration(_ s: Double) -> String {
        let secs = Int(s)
        return String(format: "0:%02d", secs)
    }
}

// MARK: - VoiceRecorder

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var duration: Double = 0
    @Published var audioSamples: [Float] = []
    @Published var audioURL: URL?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        isRecording = true
        duration = 0
        audioSamples = []
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.duration += 0.1
                self.recorder?.updateMeters()
                let level = self.recorder?.averagePower(forChannel: 0) ?? -80
                self.audioSamples.append(max(0, (Float(level) + 80) / 80))
                if self.audioSamples.count > 80 { self.audioSamples.removeFirst() }
                if self.duration >= 60 { self.stop() }
            }
        }
    }

    func stop() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        audioURL = recorder?.url
    }

    func reset() {
        recorder = nil
        audioURL = nil
        audioSamples = []
        duration = 0
    }
}

// MARK: - WaveformView

struct WaveformView: View {
    let samples: [Float]
    let isRecording: Bool

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(samples.indices, id: \.self) { i in
                    Capsule()
                        .fill(isRecording ? ColorTokens.gold : ColorTokens.textTertiary)
                        .frame(width: 3, height: max(4, CGFloat(samples[i]) * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - VoiceUploadAPI
// Plan 3a Task 11: real multipart upload to BE V2 voice endpoint.
// POST /diagnostic/voice/upload with multipart fields:
//   - audio (file, m4a)
//   - questionText (text)
//   - canonicalCompetency (text)
// Auth token (if available) is read from KeychainManager.

enum VoiceUploadAPI {
    private static let baseURL = URL(string: "https://api.scaleupapp.club/api/v1")!

    /// Decoded shape of `data` field inside the standard APIResponse envelope.
    private struct VoiceUploadData: Decodable {
        let audioUrl: String
        let transcription: String
        let overallScore: Int
        let band: String
        let feedback: String
    }

    private struct Envelope: Decodable {
        let success: Bool
        let message: String?
        let data: VoiceUploadData?
    }

    static func upload(
        audioURL: URL,
        questionText: String,
        canonicalCompetency: String,
        authToken: String? = nil
    ) async throws -> VoiceAnswerResult {
        let endpoint = baseURL.appendingPathComponent("/diagnostic/voice/upload")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Auth: prefer caller-provided token, otherwise fall back to keychain.
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let token = await KeychainManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let audioData = try Data(contentsOf: audioURL)
        var body = Data()
        let crlf = "\r\n"

        // questionText
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"questionText\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append("\(questionText)\(crlf)".data(using: .utf8)!)

        // canonicalCompetency
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"canonicalCompetency\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append("\(canonicalCompetency)\(crlf)".data(using: .utf8)!)

        // audio
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "VoiceUploadAPI",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: "Voice upload failed with status \(code)"]
            )
        }

        // Try standard envelope first; fall back to flat shape if needed.
        let decoder = JSONDecoder()
        if let env = try? decoder.decode(Envelope.self, from: data),
           env.success, let payload = env.data {
            return VoiceAnswerResult(
                transcription: payload.transcription,
                overallScore: payload.overallScore,
                band: payload.band,
                feedback: payload.feedback,
                audioUrl: payload.audioUrl
            )
        }
        let payload = try decoder.decode(VoiceUploadData.self, from: data)
        return VoiceAnswerResult(
            transcription: payload.transcription,
            overallScore: payload.overallScore,
            band: payload.band,
            feedback: payload.feedback,
            audioUrl: payload.audioUrl
        )
    }
}

#Preview {
    DiagnosticVoiceAnswerView(
        questionId: "preview-question-id",
        questionText: "Tell me about a time you led a cross-functional team through a difficult decision.",
        canonicalCompetency: "stakeholder-management",
        onComplete: { _ in },
        onFallbackToTyped: { }
    )
}
