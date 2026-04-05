import SwiftUI
import AVFoundation

struct InterviewLiveView: View {
    @Bindable var viewModel: InterviewViewModel
    @State private var showEndConfirm = false
    @State private var showTranscript = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var showingStarter = true
    @State private var countdownValue = 3
    @State private var countdownScale: CGFloat = 0.5
    @State private var countdownOpacity: Double = 0
    @State private var showCountdown = false

    private var turn: InterviewTurn { viewModel.geminiManager.turn }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.bottom, Spacing.sm)

                // Scrollable middle section
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Current question card (only during Q&A)
                        if viewModel.geminiManager.greetingDone,
                           !viewModel.geminiManager.currentQuestion.isEmpty {
                            currentQuestionCard
                        }

                        // Center state indicator
                        centerIndicator
                            .frame(minHeight: 180)
                    }
                    .padding(.top, Spacing.md)
                }

                // Action buttons — always at bottom, never blocked
                actionSection
                    .padding(.top, Spacing.sm)

                bottomControls
            }

            if showingStarter {
                starterOverlay
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

            if viewModel.geminiManager.greetingDone {
                Text("Q\(viewModel.questionCount)/~10")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ColorTokens.gold.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Current Question Card

    private var currentQuestionCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 12))
                Text("Question \(viewModel.questionCount)")
                    .font(Typography.captionBold)
            }
            .foregroundStyle(ColorTokens.gold)

            Text(viewModel.geminiManager.currentQuestion)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Center Indicator

    @ViewBuilder
    private var centerIndicator: some View {
        switch turn {
        case .aiSpeaking:
            aiSpeakingIndicator
        case .readyCheck:
            readyCheckIndicator
        case .waitingToAnswer:
            waitingToAnswerIndicator
        case .userRecording:
            recordingIndicator
        case .processing:
            processingIndicator
        }
    }

    private var aiSpeakingIndicator: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 88, height: 88)
                    .scaleEffect(pulseScale * 0.9)

                Circle()
                    .fill(ColorTokens.gold.opacity(0.25))
                    .frame(width: 60, height: 60)

                Image(systemName: "waveform")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }
            .onDisappear { pulseScale = 1.0 }

            Text(viewModel.geminiManager.greetingDone ? "Interviewer is speaking..." : "The interviewer is greeting you...")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var readyCheckIndicator: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.08))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(ColorTokens.success.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(ColorTokens.success)
            }

            Text("The interviewer is ready for you")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Tap below when you're ready to start")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var waitingToAnswerIndicator: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(ColorTokens.success.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: "mic.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(ColorTokens.success)
            }

            Text("Ready when you are")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.success)
        }
    }

    private var recordingIndicator: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.06))
                    .frame(
                        width: 100 + normalizedAudioLevel * 60,
                        height: 100 + normalizedAudioLevel * 60
                    )
                    .animation(.easeOut(duration: 0.1), value: normalizedAudioLevel)

                Circle()
                    .fill(ColorTokens.success.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: "waveform")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(ColorTokens.success)
            }

            VStack(spacing: 4) {
                Text("Recording your answer...")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.success)

                Text(formatDuration(viewModel.geminiManager.answerDuration))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(ColorTokens.success)
            }
        }
    }

    private var processingIndicator: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 88, height: 88)

                ProgressView()
                    .tint(ColorTokens.gold)
                    .scaleEffect(1.5)
            }

            Text("Preparing next question...")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var normalizedAudioLevel: CGFloat {
        CGFloat(min(viewModel.geminiManager.audioLevel / 0.08, 1.0))
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Action Section

    @ViewBuilder
    private var actionSection: some View {
        switch turn {
        case .readyCheck:
            VStack(spacing: Spacing.sm) {
                Button {
                    Haptics.medium()
                    viewModel.geminiManager.confirmReady()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("I'm Ready — Let's Begin")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(ColorTokens.success)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.geminiManager.declineAndExit()
                    // ViewModel will handle navigation back
                } label: {
                    Text("Not Now — Come Back Later")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)

        case .waitingToAnswer:
            Button {
                Haptics.medium()
                viewModel.geminiManager.startAnswering()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Tap to Start Answering")
                        .font(Typography.bodyBold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(ColorTokens.success)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)

        case .userRecording:
            Button {
                Haptics.medium()
                viewModel.geminiManager.finishAnswering()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Done — Send Answer")
                        .font(Typography.bodyBold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(ColorTokens.info)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)

        default:
            EmptyView()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                if viewModel.proctor.cameraEnabled {
                    cameraPill
                }

                Spacer()

                if viewModel.geminiManager.greetingDone {
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
            }

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
            if viewModel.proctor.cameraEnabled {
                CameraStatusView(authorized: true)
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

    // MARK: - Starter Overlay

    private var starterOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color(hex: 0x0A0A0F)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()
                if showCountdown {
                    countdownDisplay
                } else {
                    starterContent
                }
                Spacer()
            }
        }
        .transition(.opacity)
        .onAppear { startStarterSequence() }
    }

    private var starterContent: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(viewModel.selectedType.color.opacity(0.12))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(viewModel.selectedType.color.opacity(0.06))
                    .frame(width: 160, height: 160)
                Image(systemName: viewModel.selectedType.icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(viewModel.selectedType.color)
            }

            VStack(spacing: Spacing.sm) {
                Text("Your Interview is About to Begin")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("\(viewModel.selectedType.displayName) \u{2022} \(viewModel.selectedDifficulty.displayName)")
                    .font(Typography.bodySmall)
                    .foregroundStyle(viewModel.selectedType.color)
            }

            if !viewModel.targetRole.isEmpty {
                VStack(spacing: 4) {
                    Text(viewModel.targetRole)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    if !viewModel.targetCompany.isEmpty {
                        Text("at \(viewModel.targetCompany)")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(ColorTokens.surfaceElevated.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Quick Tips")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
                    .tracking(1)

                ForEach(Array(tipsForType(viewModel.selectedType).enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text("\(index + 1).")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ColorTokens.gold)
                            .frame(width: 18, alignment: .trailing)
                        Text(tip)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .padding(.horizontal, Spacing.xl)
        }
    }

    private var countdownDisplay: some View {
        Text("\(countdownValue)")
            .font(.system(size: 96, weight: .heavy, design: .rounded))
            .foregroundStyle(viewModel.selectedType.color)
            .scaleEffect(countdownScale)
            .opacity(countdownOpacity)
    }

    private func startStarterSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(Motion.easeOut) { showCountdown = true }
            animateCountdownDigit()
        }
    }

    private func animateCountdownDigit() {
        guard countdownValue > 0 else {
            withAnimation(.easeInOut(duration: 0.3)) { showingStarter = false }
            return
        }
        countdownScale = 0.5
        countdownOpacity = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            countdownScale = 1.0
            countdownOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.25)) {
                countdownOpacity = 0
                countdownScale = 1.3
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            countdownValue -= 1
            animateCountdownDigit()
        }
    }

    private func tipsForType(_ type: InterviewType) -> [String] {
        switch type {
        case .mba_admissions:
            return ["Be specific with examples", "Show self-awareness", "Know your career goals clearly"]
        case .placement_hr:
            return ["Use the STAR method", "Be authentic about strengths/weaknesses", "Research the company"]
        case .placement_technical:
            return ["Think aloud while solving", "Ask clarifying questions", "Structure before coding"]
        case .case_study:
            return ["Structure your approach first", "Use frameworks (4Ps, SWOT)", "Quantify when possible"]
        case .behavioral:
            return ["Use specific examples, not hypotheticals", "Focus on YOUR contribution", "Reflect on learnings"]
        }
    }
}
