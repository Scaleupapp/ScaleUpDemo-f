import SwiftUI

/// Placement-context capstone pairing screen.
///
/// Shown after POST /me/assessments/:id/start returns type == "capstone".
/// Reuses `CapstonePairingCodePanel` (purely presentational) and polls
/// `syncSession(assessmentSessionId)` every 20 s until status == "graded"
/// (capstone is graded async after the laptop session completes).
///
/// We do NOT reuse CapstonePairView because it requires a CapstoneLibraryEntry
/// bundle and calls CapstoneService (different domain + different sessionId).
struct PlacementCapstonePairView: View {
    let start: AssessmentStartResult
    let onClose: () -> Void

    @State private var syncStatus: String?       // last status from syncSession
    @State private var pollTask: Task<Void, Never>?
    @State private var showDone = false

    private let api = PlacementsAssessmentsApi.shared

    /// The web URL where students enter their code on a laptop.
    private var laptopURL: String {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CAPSTONE_WEB_URL") as? String, !v.isEmpty {
            return v
        }
        return "scaleup-web-seven.vercel.app/capstone"
    }

    var body: some View {
        NavigationStack {
            Group {
                if showDone {
                    doneView
                } else if let pairingCode = start.meta?.pairingCode,
                          let expiresAtStr = start.meta?.expiresAt,
                          let expiresAt = ISO8601DateFormatter().date(from: expiresAtStr) {
                    pairingContent(pairingCode: pairingCode, expiresAt: expiresAt)
                } else {
                    missingCodeView
                }
            }
            .navigationTitle("Pair your laptop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", role: .cancel) {
                        pollTask?.cancel()
                        onClose()
                    }
                }
            }
        }
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - Pairing content

    private func pairingContent(pairingCode: String, expiresAt: Date) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                instructionHeader
                CapstonePairingCodePanel(
                    pairingCode: pairingCode,
                    expiresAt: expiresAt,
                    laptopURL: laptopURL
                )
                timeBudgetRow
                syncStatusRow
                Spacer(minLength: 24)
            }
            .padding(.top, 24)
        }
    }

    private var instructionHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.gold)
            Text("Open on your laptop")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Go to the URL below on your laptop and enter the pairing code to begin your capstone assessment.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var timeBudgetRow: some View {
        Group {
            if let budget = start.meta?.timeBudgetSeconds {
                let minutes = budget / 60
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("Time budget: \(minutes) minutes")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var syncStatusRow: some View {
        Group {
            if let status = syncStatus, status != "in_progress" {
                HStack(spacing: 6) {
                    Circle().fill(colorFor(status: status)).frame(width: 6, height: 6)
                    Text(labelFor(status: status))
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Waiting for laptop to connect…")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
    }

    // MARK: - Done view

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.success)
            Text("Capstone Graded")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Your capstone assessment has been submitted and graded. Close this sheet to see your result.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Done") {
                pollTask?.cancel()
                onClose()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ColorTokens.gold)
            Spacer()
        }
    }

    // MARK: - Missing code fallback

    private var missingCodeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.gold)
            Text("Open on your laptop")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("This capstone assessment must be completed on a laptop or desktop browser. Log in to scaleupapp.club to continue.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Close") {
                pollTask?.cancel()
                onClose()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ColorTokens.gold)
        }
        .padding(32)
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            // Poll up to 5 min (15 × 20 s) for a graded status
            for _ in 0..<15 {
                guard !Task.isCancelled else { return }
                if let result = try? await api.syncSession(start.assessmentSessionId) {
                    await MainActor.run { syncStatus = result.status }
                    if result.status == "graded" {
                        await MainActor.run { showDone = true }
                        return
                    }
                }
                try? await Task.sleep(nanoseconds: 20_000_000_000)  // 20 s
            }
        }
    }

    // MARK: - Helpers

    private func labelFor(status: String) -> String {
        switch status {
        case "submitted":   return "Submitted — grading in progress…"
        case "graded":      return "Graded"
        case "expired":     return "Session expired"
        default:            return status.capitalized
        }
    }

    private func colorFor(status: String) -> Color {
        switch status {
        case "graded":  return ColorTokens.success
        case "expired": return ColorTokens.textTertiary
        default:        return ColorTokens.gold
        }
    }
}
