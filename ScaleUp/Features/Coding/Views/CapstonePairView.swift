import SwiftUI

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
        CapstonePairingCodePanel(
            pairingCode: startResponse.pairingCode,
            expiresAt: startResponse.expiresAt,
            laptopURL: laptopURL
        )
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

    private var relativeExpiry: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: startResponse.expiresAt, relativeTo: Date())
    }
}
