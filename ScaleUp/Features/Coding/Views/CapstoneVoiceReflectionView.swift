import SwiftUI
import AVFoundation

/// 60-second voice reflection capture (spec §7.2 step 12). Records m4a
/// AAC via AVAudioRecorder, posts to /capstones/:id/voice-reflection,
/// dismisses on success. The backend handles transcription + re-eval.
struct CapstoneVoiceReflectionView: View {
    let sessionId: String
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorder = CapstoneReflectionRecorder()
    @State private var uploading = false
    @State private var error: String?
    @State private var doneUploading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 8) {
                    Text("60-second reflection")
                        .font(.title3.weight(.semibold))
                    Text("Tell us what you learned and what you'd do differently. We'll use it to refine your reflection score.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Color.red.opacity(0.18) : Color.accentColor.opacity(0.15))
                        .frame(width: 180, height: 180)
                    Circle()
                        .stroke(recorder.isRecording ? Color.red : Color.accentColor, lineWidth: 3)
                        .frame(width: 160, height: 160)
                    Text(formatDuration(recorder.duration))
                        .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                }

                ProgressView(value: min(recorder.duration / 60, 1.0))
                    .padding(.horizontal, 32)
                    .tint(recorder.duration >= 60 ? .red : .accentColor)

                actionButton

                Spacer()
            }
            .padding(.bottom, 40)
            .navigationTitle("Voice reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        recorder.cleanup()
                        dismiss()
                    }
                }
            }
            .alert("Couldn't upload", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if uploading {
            VStack(spacing: 10) {
                ProgressView()
                Text("Uploading…").font(.subheadline).foregroundStyle(.secondary)
            }
        } else if recorder.isRecording {
            Button {
                recorder.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(width: 220).padding(.vertical, 14)
                    .background(Color.red).foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        } else if recorder.audioURL != nil {
            VStack(spacing: 10) {
                Button {
                    Task { await submit() }
                } label: {
                    Label("Submit reflection", systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(width: 240).padding(.vertical, 14)
                        .background(Color.accentColor).foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Button("Re-record") {
                    recorder.reset()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } else {
            Button {
                recorder.start()
            } label: {
                Label("Tap to record", systemImage: "mic.fill")
                    .font(.headline)
                    .frame(width: 220).padding(.vertical, 14)
                    .background(Color.accentColor).foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    private func submit() async {
        guard let url = recorder.audioURL else { return }
        uploading = true
        defer { uploading = false }
        do {
            let data = try Data(contentsOf: url)
            try await CapstoneService.shared.uploadVoiceReflection(
                sessionId: sessionId,
                audio: data,
                mimeType: "audio/m4a",
                replace: false
            )
            doneUploading = true
            recorder.cleanup()
            onDone()
            dismiss()
        } catch CapstoneServiceError.reflectionAlreadyRecorded {
            // Retry with replace=true
            do {
                let data = try Data(contentsOf: url)
                try await CapstoneService.shared.uploadVoiceReflection(
                    sessionId: sessionId,
                    audio: data,
                    mimeType: "audio/m4a",
                    replace: true
                )
                doneUploading = true
                recorder.cleanup()
                onDone()
                dismiss()
            } catch {
                self.error = "Couldn't upload the replacement reflection."
            }
        } catch {
            self.error = "Couldn't upload. Try again."
        }
    }

    private func formatDuration(_ d: Double) -> String {
        let s = Int(d)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Capstone-specific 60-sec recorder. Separate from the diagnostic
/// VoiceRecorder so changes here don't affect that feature.
final class CapstoneReflectionRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var duration: Double = 0
    @Published var audioURL: URL?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            return
        }
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("capstone-reflection-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.record()
        } catch {
            return
        }
        isRecording = true
        duration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.duration += 0.1
                if self.duration >= 60 { self.stop() }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        audioURL = recorder?.url
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func reset() {
        if let url = audioURL { try? FileManager.default.removeItem(at: url) }
        audioURL = nil
        duration = 0
    }

    func cleanup() {
        if isRecording { stop() }
        reset()
    }
}
