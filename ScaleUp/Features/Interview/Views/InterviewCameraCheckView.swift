import SwiftUI
import AVFoundation

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Camera Check View

struct InterviewCameraCheckView: View {
    @Bindable var viewModel: InterviewViewModel
    @State private var cameraAuthorized = false
    @State private var micAuthorized = false
    @State private var cameraSession: AVCaptureSession?
    @State private var showPermissionDenied = false

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Camera preview area
                cameraPreviewSection

                // Checklist
                checklistSection

                // Warning if camera denied
                if showPermissionDenied {
                    cameraWarning
                }

                Spacer()

                // Ready button
                readyButton
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .task {
            await checkPermissions()
        }
        .onDisappear {
            cameraSession?.stopRunning()
        }
    }

    // MARK: - Camera Preview

    private var cameraPreviewSection: some View {
        VStack(spacing: Spacing.md) {
            Text("Pre-Interview Check")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)

            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(ColorTokens.surface)
                    .frame(height: 260)

                if let session = cameraSession, cameraAuthorized {
                    CameraPreviewView(session: session)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                        .frame(height: 260)
                } else {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(showPermissionDenied ? "Camera access denied" : "Setting up camera...")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(spacing: Spacing.md) {
            checkItem(
                icon: "camera.fill",
                text: "Camera monitors for integrity during the interview",
                isReady: cameraAuthorized,
                isOptional: true
            )

            checkItem(
                icon: "mic.fill",
                text: "Microphone will be used for voice conversation",
                isReady: micAuthorized,
                isOptional: false
            )

            checkItem(
                icon: "headphones",
                text: "Use headphones for best audio quality",
                isReady: true,
                isOptional: true
            )
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func checkItem(icon: String, text: String, isReady: Bool, isOptional: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isReady ? ColorTokens.success : ColorTokens.textTertiary)
                .frame(width: 24)

            Text(text)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)

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

    // MARK: - Camera Warning

    private var cameraWarning: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.warning)
            Text("Camera is optional but recommended for integrity monitoring. You can still proceed.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.warning)
        }
        .padding(Spacing.sm)
        .background(ColorTokens.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
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
        // Camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraStatus {
        case .authorized:
            cameraAuthorized = true
            setupCameraPreview()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
            if granted { setupCameraPreview() }
            else { showPermissionDenied = true }
        default:
            showPermissionDenied = true
        }

        // Microphone
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

    private func setupCameraPreview() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)
        cameraSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
}
