import SwiftUI
import AVFoundation

/// Placement-context interview take screen.
///
/// Gates AVAudioSession mic permission before calling vm.attachSession.
/// On grant  → attachSession(sessionId:systemInstruction:) → InterviewSessionView.
/// On denial → static error screen with Settings link + Close.
///
/// RESULTS: does NOT auto-dismiss on .results — shows a Done overlay so the
/// student can read their score before closing.
///
/// ERROR: in the placement context the InterviewSessionView's built-in
/// ".error → Try Again → .setup" flow would open the D2C setup form which
/// is wrong here. We overlay a Placement-specific Retry / Close layer instead.
struct PlacementInterviewTakeView: View {
    let start: AssessmentStartResult
    let onComplete: () -> Void

    @State private var vm = InterviewViewModel()
    @State private var micState: MicState = .checking
    @State private var showResultsOverlay = false
    @State private var showPlacementError: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(V2NavState.self) private var v2Nav
    @Environment(V2TaskRouter.self) private var taskRouter
    @Environment(AppState.self) private var appState

    private enum MicState {
        case checking
        case granted
        case denied
    }

    var body: some View {
        ZStack {
            switch micState {
            case .checking:
                checkingView

            case .denied:
                micDeniedView

            case .granted:
                interviewBody
            }
        }
        .task { await requestMicPermission() }
    }

    // MARK: - Checking mic

    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ColorTokens.gold)
            Text("Checking microphone access…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    }

    // MARK: - Mic denied

    private var micDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.error)
            Text("Microphone access needed")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("ScaleUp needs microphone access to conduct the AI interview. Please enable it in Settings → Privacy → Microphone.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ColorTokens.gold)
            Button("Close") { dismiss() }
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    }

    // MARK: - Interview body + overlays

    private var interviewBody: some View {
        ZStack {
            InterviewSessionView(viewModel: vm)
                .environment(v2Nav)
                .environment(taskRouter)
                .environment(appState)
                .onChange(of: vm.state) { _, newState in
                    if case .results = newState {
                        // Do NOT auto-dismiss — show overlay so student reads results.
                        showResultsOverlay = true
                        onComplete()
                    }
                    // Override .error in placement context: capture it and show our overlay.
                    if case .error(let msg) = newState {
                        showPlacementError = msg
                    }
                }

            // Results overlay — student taps Done to dismiss.
            if showResultsOverlay {
                placementResultsDoneButton
            }

            // Error overlay — Retry or Close.
            if let errMsg = showPlacementError {
                placementErrorOverlay(errMsg)
            }
        }
    }

    // MARK: - Results "Done" overlay

    private var placementResultsDoneButton: some View {
        VStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(ColorTokens.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ColorTokens.gold)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Error overlay (placement context — no .setup redirect)

    private func placementErrorOverlay(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text("Interview error")
                    .font(V2Theme.h2)
                    .foregroundStyle(.white)
                Text(message)
                    .font(V2Theme.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                HStack(spacing: 16) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())

                    Button("Retry") {
                        showPlacementError = nil
                        Task {
                            // Re-attach to the same backend session.
                            await vm.attachSession(
                                sessionId: start.engine.sessionId ?? "",
                                systemInstruction: start.meta?.systemInstruction ?? ""
                            )
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ColorTokens.gold.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Mic permission

    private func requestMicPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            micState = .granted
            await attachSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            micState = granted ? .granted : .denied
            if granted { await attachSession() }
        default:
            micState = .denied
        }
    }

    private func attachSession() async {
        guard let sessionId = start.engine.sessionId, !sessionId.isEmpty else {
            showPlacementError = "Interview session ID is missing. Please try again."
            return
        }
        await vm.attachSession(
            sessionId: sessionId,
            systemInstruction: start.meta?.systemInstruction ?? ""
        )
    }
}
