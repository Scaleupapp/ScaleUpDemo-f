import SwiftUI
import AVFoundation

struct InterviewLiveView: View {
    @Bindable var viewModel: InterviewViewModel
    @State private var showEndConfirm = false
    @State private var showTranscript = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                conversationStatus
                Spacer()
                bottomSection
            }
        }
        .alert("End Interview?", isPresented: $showEndConfirm) {
            Button("Continue", role: .cancel) {}
            Button("End Interview", role: .destructive) {
                Task { await viewModel.endInterview() }
            }
        } message: {
            Text("The AI will evaluate your responses so far. You can't resume after ending.")
        }
        .sheet(isPresented: $showTranscript) {
            transcriptSheet
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: Spacing.md) {
            // Interview type badge
            HStack(spacing: 6) {
                Image(systemName: viewModel.selectedType.icon)
                    .font(.system(size: 11))
                Text(viewModel.selectedType.displayName)
                    .font(Typography.captionBold)
            }
            .foregroundStyle(viewModel.selectedType.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(viewModel.selectedType.color.opacity(0.15))
            .clipShape(Capsule())

            Spacer()

            // Timer
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Text(viewModel.elapsedString)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ColorTokens.surfaceElevated)
            .clipShape(Capsule())

            Spacer()

            // Question counter
            Text("Q\(viewModel.questionCount)/~10")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ColorTokens.gold.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Conversation Status

    private var conversationStatus: some View {
        VStack(spacing: Spacing.xl) {
            if viewModel.geminiManager.isAISpeaking {
                aiSpeakingIndicator
            } else if viewModel.geminiManager.isUserSpeaking {
                userSpeakingIndicator
            } else {
                waitingIndicator
            }

            // Latest transcript
            if let lastEntry = viewModel.transcript.last {
                VStack(spacing: Spacing.sm) {
                    Text(lastEntry.isInterviewer ? "Interviewer" : "You")
                        .font(Typography.captionBold)
                        .foregroundStyle(lastEntry.isInterviewer ? ColorTokens.gold : ColorTokens.success)

                    Text(lastEntry.content)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, Spacing.xl)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(Motion.easeOut, value: viewModel.transcript.count)
            }
        }
    }

    // MARK: - AI Speaking Indicator

    private var aiSpeakingIndicator: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                // Outer pulsing circle
                Circle()
                    .fill(ColorTokens.gold.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)

                // Middle circle
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .scaleEffect(pulseScale * 0.9)

                // Inner circle with icon
                Circle()
                    .fill(ColorTokens.gold.opacity(0.25))
                    .frame(width: 72, height: 72)

                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }
            .onDisappear { pulseScale = 1.0 }

            Text("Interviewer is speaking...")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    // MARK: - User Speaking Indicator

    private var userSpeakingIndicator: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.1))
                    .frame(width: 120, height: 120)

                // Waveform bars
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorTokens.success)
                            .frame(width: 4, height: waveHeight(for: i))
                            .animation(
                                .easeInOut(duration: 0.4)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.1),
                                value: wavePhase
                            )
                    }
                }
            }
            .onAppear {
                wavePhase = 1
            }
            .onDisappear { wavePhase = 0 }

            Text("You're speaking...")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.success)
        }
    }

    private func waveHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [20, 32, 44, 28, 36]
        return wavePhase == 0 ? 12 : heights[index]
    }

    // MARK: - Waiting Indicator

    private var waitingIndicator: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 100, height: 100)

                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Text("Listening...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: Spacing.md) {
            // Camera preview pill + transcript button
            HStack(spacing: Spacing.md) {
                if viewModel.proctor.cameraEnabled {
                    cameraPill
                }

                Spacer()

                Button {
                    showTranscript = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 12))
                        Text("Transcript")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // End Interview button
            Button {
                Haptics.warning()
                showEndConfirm = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                    Text("End Interview")
                        .font(Typography.bodySmallBold)
                }
                .foregroundStyle(ColorTokens.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ColorTokens.error.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.error.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Camera Pill

    private var cameraPill: some View {
        ZStack {
            if let session = viewModel.proctor.activeCaptureSession {
                CameraPreviewView(session: session)
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 60, height: 80)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
            }

            // Proctoring status indicator
            if case .alert(let msg) = viewModel.proctor.currentStatus {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(ColorTokens.error)
                        .clipShape(Capsule())
                }
                .frame(width: 60, height: 80)
                .padding(.bottom, 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(proctorBorderColor, lineWidth: 2)
        )
    }

    private var proctorBorderColor: Color {
        switch viewModel.proctor.currentStatus {
        case .monitoring: return ColorTokens.success
        case .alert: return ColorTokens.error
        default: return ColorTokens.border
        }
    }

    // MARK: - Transcript Sheet

    private var transcriptSheet: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Spacing.sm) {
                            ForEach(viewModel.transcript) { entry in
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    if !entry.isInterviewer {
                                        Spacer(minLength: 60)
                                    }

                                    VStack(alignment: entry.isInterviewer ? .leading : .trailing, spacing: 4) {
                                        if entry.isInterviewer, let qNum = entry.questionNumber {
                                            Text(entry.isFollowUp == true ? "Follow-up" : "Q\(qNum)")
                                                .font(Typography.micro)
                                                .foregroundStyle(ColorTokens.gold)
                                        }

                                        Text(entry.content)
                                            .font(Typography.bodySmall)
                                            .foregroundStyle(entry.isInterviewer ? ColorTokens.textPrimary : ColorTokens.buttonPrimaryText)
                                            .padding(.horizontal, Spacing.md)
                                            .padding(.vertical, Spacing.sm)
                                            .background(entry.isInterviewer ? ColorTokens.surface : ColorTokens.gold)
                                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                                    }

                                    if entry.isInterviewer {
                                        Spacer(minLength: 60)
                                    }
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                    }
                    .onChange(of: viewModel.transcript.count) {
                        if let last = viewModel.transcript.last {
                            withAnimation(Motion.easeOut) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Live Transcript")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTranscript = false }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
