import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// Pairing screen — shows the 6-digit code + QR + copy-link CTA, polls
/// /status until backend reports `in_progress` (the laptop has redeemed
/// the pairing code and the learner has started), then auto-advances to
/// the Live screen.
///
/// Important: we do NOT auto-advance on `ready`. Ready means the sandbox
/// is provisioned and waiting for the laptop to redeem the code — that's
/// the whole point of this screen. Advancing on `ready` would make the
/// session "auto-activate" before the learner has even opened their
/// laptop.
struct CapstonePairView: View {
    let bundle: CapstoneLibraryEntry
    let startResponse: CapstoneStartResponse
    let onClose: () -> Void

    @State private var currentStatus: CapstoneSessionStatus
    @State private var pollTask: Task<Void, Never>?
    @State private var showLive = false
    @State private var copiedFlash: CopiedKind?

    enum CopiedKind { case url, code }

    /// Where the laptop should go. Points at the deployed web IDE.
    /// Override at runtime via the `CAPSTONE_WEB_URL` Info.plist key if you
    /// move to a custom domain.
    private var laptopURL: String {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CAPSTONE_WEB_URL") as? String,
           !v.isEmpty {
            return v
        }
        return "scaleup-web-seven.vercel.app/capstone"
    }

    init(bundle: CapstoneLibraryEntry, startResponse: CapstoneStartResponse, onClose: @escaping () -> Void) {
        self.bundle = bundle
        self.startResponse = startResponse
        self.onClose = onClose
        self._currentStatus = State(initialValue: startResponse.status)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    statusHeader

                    codeDisplay

                    qrCode

                    urlPanel

                    expiryLine

                    Spacer(minLength: 24)
                }
                .padding(.top, 28)
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

    // MARK: - Status header

    private var statusHeader: some View {
        VStack(spacing: 10) {
            statusBadge
            Text(statusTitle)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(statusSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var statusTitle: String {
        switch currentStatus {
        case .scheduled, .provisioning: return "Setting up your sandbox…"
        case .ready:                    return "Open your laptop"
        case .in_progress, .paused:     return "Session live"
        case .aborted, .expired:        return currentStatus.displayLabel
        default:                        return "Pair your laptop"
        }
    }

    private var statusSubtitle: String {
        switch currentStatus {
        case .scheduled, .provisioning:
            return "We're provisioning a fresh Linux container. This usually takes a few seconds."
        case .ready:
            return "Open the URL on your laptop and enter the 6-digit code to begin. Your code expires \(relativeExpiry)."
        case .in_progress, .paused:
            return "Opening your work surface…"
        case .aborted:
            return "Session was aborted. Tap Cancel and start over."
        case .expired:
            return "Code expired. Tap Cancel and try again."
        default:
            return ""
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            switch currentStatus {
            case .scheduled, .provisioning:
                ProgressView().scaleEffect(0.85)
                Text("Provisioning").font(.footnote.weight(.medium))
            case .ready:
                Image(systemName: "laptopcomputer.and.iphone")
                Text("Waiting for laptop").font(.footnote.weight(.medium))
            case .in_progress, .paused:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Paired").font(.footnote.weight(.medium))
            case .aborted, .expired:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(currentStatus.displayLabel).font(.footnote.weight(.medium))
            default:
                Text(currentStatus.displayLabel).font(.footnote.weight(.medium))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Color(.tertiarySystemBackground)))
    }

    // MARK: - Code + copy

    private var codeDisplay: some View {
        VStack(spacing: 10) {
            Text(formattedCode)
                .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                .tracking(8)
                .padding(.vertical, 18)
                .padding(.horizontal, 32)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("Pairing code \(startResponse.pairingCode)")

            Button {
                UIPasteboard.general.string = startResponse.pairingCode
                flash(.code)
            } label: {
                Label(copiedFlash == .code ? "Code copied" : "Copy code",
                      systemImage: copiedFlash == .code ? "checkmark" : "doc.on.doc")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - URL panel — primary CTA for the laptop

    private var urlPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.tint)
                Text(laptopURL)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    UIPasteboard.general.string = "https://\(laptopURL)"
                    flash(.url)
                } label: {
                    Image(systemName: copiedFlash == .url ? "checkmark" : "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .padding(8)
                        .background(Color.accentColor.opacity(0.18))
                        .clipShape(Circle())
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy URL")
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                ShareLink(item: "Open \(laptopURL) and enter \(startResponse.pairingCode)") {
                    Label("Email / message link", systemImage: "paperplane.fill")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if copiedFlash == .url {
                Text("URL copied — paste it in your laptop's browser")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - QR

    private var qrCode: some View {
        VStack(spacing: 8) {
            Group {
                if let img = generateQR(for: "https://\(laptopURL)?code=\(startResponse.pairingCode)") {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 200, height: 200)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ProgressView().frame(width: 200, height: 200)
                }
            }
            Text("Or scan the QR with your laptop camera")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var expiryLine: some View {
        Text("Code expires \(relativeExpiry)")
            .font(.footnote)
            .foregroundStyle(.tertiary)
    }

    // MARK: - QR generator

    private func generateQR(for payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Copy flash

    private func flash(_ kind: CopiedKind) {
        withAnimation(.spring(response: 0.25)) { copiedFlash = kind }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if copiedFlash == kind { copiedFlash = nil }
                }
            }
        }
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
                    // Only advance when the laptop has actually paired AND the
                    // learner has started the timer (`in_progress` / `paused`).
                    // `ready` just means the sandbox is provisioned and waiting
                    // for the laptop to redeem the code — we MUST stay on this
                    // screen until that happens.
                    if s.status == .in_progress || s.status == .paused {
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
