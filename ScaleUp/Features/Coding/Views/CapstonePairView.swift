import SwiftUI
import CoreImage.CIFilterBuiltins

/// Pairing screen — shows the 6-digit code + QR + email-link CTA, polls
/// /status until backend reports `ready`, then auto-advances to the Live
/// screen.
struct CapstonePairView: View {
    let bundle: CapstoneLibraryEntry
    let startResponse: CapstoneStartResponse
    let onClose: () -> Void

    @State private var currentStatus: CapstoneSessionStatus
    @State private var pollTask: Task<Void, Never>?
    @State private var showLive = false

    init(bundle: CapstoneLibraryEntry, startResponse: CapstoneStartResponse, onClose: @escaping () -> Void) {
        self.bundle = bundle
        self.startResponse = startResponse
        self.onClose = onClose
        self._currentStatus = State(initialValue: startResponse.status)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerCopy

                    codeDisplay

                    qrCode

                    statusBadge

                    Text("Open `app.scaleup.app/capstone` on your laptop. The code expires \(relativeExpiry).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 24)
                }
                .padding(.top, 24)
            }
            .navigationTitle("Pair laptop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .destructive) {
                        Task { try? await CapstoneService.shared.control(sessionId: startResponse.sessionId, action: .abort) }
                        onClose()
                    }
                }
            }
            .onAppear { startPolling() }
            .onDisappear { pollTask?.cancel() }
            .fullScreenCover(isPresented: $showLive) {
                CapstoneLiveView(
                    bundle: bundle,
                    sessionId: startResponse.sessionId,
                    timeBudgetSeconds: startResponse.timeBudgetSeconds,
                    onClose: onClose
                )
            }
        }
    }

    private var headerCopy: some View {
        VStack(spacing: 6) {
            Text("Open your laptop")
                .font(.title2.weight(.semibold))
            Text("Go to **app.scaleup.app/capstone** and enter the code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private var codeDisplay: some View {
        Text(formattedCode)
            .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
            .tracking(8)
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel("Pairing code \(startResponse.pairingCode)")
    }

    private var qrCode: some View {
        Group {
            if let img = generateQR(for: startResponse.pairingCode) {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ProgressView().frame(width: 220, height: 220)
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            switch currentStatus {
            case .provisioning, .scheduled:
                ProgressView().scaleEffect(0.8)
                Text(currentStatus.displayLabel).font(.subheadline)
            case .ready:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Paired — opening session…").font(.subheadline)
            case .aborted, .expired:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(currentStatus.displayLabel).font(.subheadline)
            default:
                Text(currentStatus.displayLabel).font(.subheadline)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Capsule().fill(Color.gray.opacity(0.15)))
    }

    // MARK: - QR

    private func generateQR(for code: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(code.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            for _ in 0..<150 {  // poll for up to ~5 min (longer than the 10-min code TTL)
                if Task.isCancelled { return }
                do {
                    let s = try await CapstoneService.shared.getStatus(sessionId: startResponse.sessionId)
                    await MainActor.run { currentStatus = s.status }
                    if s.status == .ready || s.status == .in_progress || s.status == .paused {
                        await MainActor.run { showLive = true }
                        return
                    }
                    if [.aborted, .expired, .graded].contains(s.status) { return }
                } catch {
                    // Continue — transient failures shouldn't stop the poll.
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    // MARK: - Formatting helpers

    private var formattedCode: String {
        // "123456" → "123 456"
        let s = startResponse.pairingCode
        guard s.count == 6 else { return s }
        return "\(s.prefix(3)) \(s.suffix(3))"
    }

    private var relativeExpiry: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: startResponse.expiresAt, relativeTo: Date())
    }
}
