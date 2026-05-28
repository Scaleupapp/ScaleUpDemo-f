import SwiftUI

/// Pre-flight checklist before the learner pairs to a laptop (spec §7.2 step 2).
/// Tap "Start on laptop" → POST /capstones/start → show pairing code on next screen.
struct CapstonePreflightView: View {
    let bundle: CapstoneLibraryEntry
    let onClose: () -> Void

    @State private var checks: PreflightChecks = .init()
    @State private var starting = false
    @State private var startResponse: CapstoneStartResponse?
    @State private var error: String?

    struct PreflightChecks {
        var laptopReady = false
        var quietBlock = false
        var networkOk = false

        var allOk: Bool { laptopReady && quietBlock && networkOk }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    checklist

                    integrityBanner

                    Spacer(minLength: 16)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                startButton
                    .padding(20)
                    .background(.regularMaterial)
            }
            .navigationTitle("Pre-flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onClose() } label: { Image(systemName: "xmark") }
                }
            }
            .alert("Couldn't start", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .sheet(item: Binding(
                get: { startResponse },
                set: { startResponse = $0 }
            )) { resp in
                CapstonePairView(bundle: bundle, startResponse: resp, onClose: onClose)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bundle.brief)
                .font(.body)
                .lineLimit(4)
            HStack(spacing: 8) {
                badge(bundle.difficulty.rawValue.capitalized)
                badge("\(bundle.timeBudgetMinutes) min")
                badge(bundle.language)
            }
            if let parallel = bundle.interviewParallel {
                Label(parallel, systemImage: "briefcase.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .padding(.top, 4)
            }
        }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Before you start")
                .font(.headline)
            row("Your laptop is open and connected to power", isOn: $checks.laptopReady)
            row("You have \(bundle.timeBudgetMinutes) minutes uninterrupted", isOn: $checks.quietBlock)
            row("Stable Wi-Fi (capstones need network for Compass + tests)", isOn: $checks.networkOk)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Anti-cheat banner — spec §13.3. Honest framing beats arms race.
    private var integrityBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.tint)
            Text("This session is recorded. You can use Compass freely; outside AI tools defeat the purpose and will lower your integrity score.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ text: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(text).font(.subheadline)
        }
        .tint(.accentColor)
    }

    private var startButton: some View {
        Button {
            Task { await start() }
        } label: {
            HStack(spacing: 8) {
                if starting { ProgressView().tint(.white) }
                Text("Start on laptop")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(checks.allOk && !starting ? Color.accentColor : Color.gray.opacity(0.3))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!checks.allOk || starting)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Color.gray.opacity(0.15)))
    }

    private func start() async {
        starting = true
        defer { starting = false }
        do {
            startResponse = try await CapstoneService.shared.start(bundleId: bundle.bundleId)
        } catch CapstoneServiceError.noCodingTrackForObjective {
            error = "Coding capstones aren't available for your current objective."
        } catch CapstoneServiceError.notACapstone {
            error = "This bundle isn't a capstone — only daily drills are available."
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't start. Try again."
        }
    }
}

// Identifiable conformance so .sheet(item:) accepts CapstoneStartResponse.
extension CapstoneStartResponse: Identifiable {
    public var id: String { sessionId }
}
