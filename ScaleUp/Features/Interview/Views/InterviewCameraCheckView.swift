import SwiftUI
import AVFoundation

// MARK: - Camera Preview UIViewRepresentable

// Simple camera status indicator (no live preview to avoid AVCaptureSession crashes)
struct CameraStatusView: View {
    let authorized: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)

            VStack(spacing: 8) {
                Image(systemName: authorized ? "checkmark.circle.fill" : "camera.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(authorized ? .green : ColorTokens.gold)

                Text(authorized ? "Camera Ready" : "Camera Access Needed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Camera Check View

struct InterviewCameraCheckView: View {
    @Bindable var viewModel: InterviewViewModel
    @State private var micAuthorized = false

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Spacer().frame(height: Spacing.xl)

                    // Header
                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(ColorTokens.gold.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Image(systemName: "checklist")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(ColorTokens.gold)
                        }

                        Text("Pre-Interview Check")
                            .font(Typography.titleLarge)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text("Make sure everything is set before you begin")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }

                    // Checklist
                    checklistSection

                    Spacer().frame(height: Spacing.md)

                    // Ready button
                    readyButton
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .task {
            await checkPermissions()
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(spacing: Spacing.md) {
            checkItem(
                icon: "mic.fill",
                text: "Microphone will be used for voice conversation",
                isReady: micAuthorized,
                isOptional: false
            )

            checkItem(
                icon: "wifi",
                text: "Ensure stable internet — avoid switching networks during the interview",
                isReady: true,
                isOptional: false
            )

            checkItem(
                icon: "speaker.slash.fill",
                text: "Find a quiet environment with minimal background noise",
                isReady: true,
                isOptional: false
            )

            checkItem(
                icon: "headphones",
                text: "Use headphones for best audio quality",
                isReady: true,
                isOptional: true
            )

            checkItem(
                icon: "battery.75percent",
                text: "Keep your device charged — interview may last 15-20 minutes",
                isReady: true,
                isOptional: true
            )
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func checkItem(icon: String, text: String, isReady: Bool, isOptional: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isReady ? ColorTokens.success : ColorTokens.textTertiary)
                .frame(width: 24)
                .padding(.top, 2)

            Text(text)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if isReady {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.success)
            } else if isOptional {
                Text("Optional")
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ColorTokens.warning.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.error)
            }
        }
    }

    // MARK: - Ready Button

    private var readyButton: some View {
        Button {
            Haptics.medium()
            Task { await viewModel.startInterview() }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 16))
                Text("I'm Ready")
                    .font(Typography.bodyBold)
            }
            .foregroundStyle(micAuthorized ? ColorTokens.buttonPrimaryText : ColorTokens.buttonDisabledText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(micAuthorized ? ColorTokens.gold : ColorTokens.buttonDisabledBg)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .disabled(!micAuthorized)
        .buttonStyle(.plain)
    }

    // MARK: - Permissions

    private func checkPermissions() async {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch micStatus {
        case .authorized:
            micAuthorized = true
        case .notDetermined:
            micAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            micAuthorized = false
        }
    }
}
