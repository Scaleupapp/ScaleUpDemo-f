import SwiftUI

/// Learner-facing "generate a custom capstone" flow. Paste a job description
/// (or a topic), pick a difficulty, and the backend generates + validates a
/// bespoke capstone. Because generation runs a full sandbox proof + a
/// cross-model review, it takes ~1-3 min — we poll and show progress, then
/// hand off to Preflight when it's ready.
struct CapstoneGeneratorSheet: View {
    let onClose: () -> Void
    /// Called with the ready bundle so the caller can present Preflight.
    let onReady: (CapstoneLibraryEntry) -> Void

    @State private var jobDescription = ""
    @State private var difficulty: DrillDifficulty? = nil
    @State private var phase: Phase = .input
    @State private var statusLabel = ""
    @State private var errorText: String?
    @State private var pollTask: Task<Void, Never>?

    enum Phase { case input, working, failed }

    private let service = CapstoneService.shared

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .input: inputForm
                case .working: workingView
                case .failed: failedView
                }
            }
            .navigationTitle("Generate a capstone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { pollTask?.cancel(); onClose() }
                }
            }
        }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - Input

    private var inputForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Paste a job description or describe what you want to practise")
                        .font(.subheadline.weight(.semibold))
                    Text("We'll build a real, graded capstone aimed at exactly that — proven to work before you start it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $jobDescription)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topLeading) {
                        if jobDescription.isEmpty {
                            Text("e.g. \"Backend SDE at a payments company — REST APIs, idempotency, Postgres…\"")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty").font(.subheadline.weight(.semibold))
                    Picker("Difficulty", selection: $difficulty) {
                        Text("Auto (your level)").tag(DrillDifficulty?.none)
                        Text("Easy").tag(DrillDifficulty?.some(.easy))
                        Text("Medium").tag(DrillDifficulty?.some(.medium))
                        Text("Hard").tag(DrillDifficulty?.some(.hard))
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    Task { await start() }
                } label: {
                    Text("Generate")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSubmit)

                Text("Takes about 1–3 minutes. We generate it, run its tests in a sandbox to prove the solution works, and have a second AI review it for fairness before you ever see it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
        }
    }

    private var canSubmit: Bool {
        jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    // MARK: - Working

    private var workingView: some View {
        VStack(spacing: 18) {
            ProgressView().scaleEffect(1.3)
            Text(statusLabel.isEmpty ? "Working…" : statusLabel)
                .font(.headline)
            Text("This takes about 1–3 minutes. You don't have to wait here — we'll notify you the moment it's ready, and it'll show up under Capstones. Feel free to keep using the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button {
                // Leave the screen — the server keeps building and a push fires
                // on completion. (If you stay, it hands off to Preflight live.)
                pollTask?.cancel()
                onClose()
            } label: {
                Text("Done — notify me when it's ready")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle).foregroundStyle(.orange)
            Text("Couldn't build that one")
                .font(.headline)
            Text(errorText ?? "Generation didn't pass our quality checks. Try a clearer or more specific description.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Try again") { phase = .input; errorText = nil }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    // MARK: - Flow

    private func start() async {
        phase = .working
        statusLabel = "Submitting…"
        do {
            let initial = try await service.generateCapstone(
                jobDescription: jobDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                topicHint: nil,
                difficulty: difficulty
            )
            poll(requestId: initial.requestId)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Couldn't start generation. Try again."
            phase = .failed
        }
    }

    private func poll(requestId: String) {
        pollTask?.cancel()
        pollTask = Task {
            for _ in 0..<150 { // up to ~5 min at 2s (covers the cross-check convergence rounds)
                if Task.isCancelled { return }
                do {
                    let s = try await service.generationStatus(requestId: requestId)
                    await MainActor.run { statusLabel = humanLabel(s.status) }
                    if s.status == "ready", let b = s.bundle {
                        await MainActor.run { onReady(b.toLibraryEntry()) }
                        return
                    }
                    if s.status == "failed" {
                        await MainActor.run {
                            errorText = s.error
                            phase = .failed
                        }
                        return
                    }
                } catch {
                    // transient — keep polling
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            await MainActor.run {
                errorText = "Generation is taking longer than expected. Check back shortly."
                phase = .failed
            }
        }
    }

    private func humanLabel(_ status: String) -> String {
        switch status {
        case "queued": return "Queued…"
        case "generating": return "Drafting your capstone…"
        case "validating": return "Running the tests in a sandbox…"
        case "cross_checking": return "Second AI reviewing for fairness…"
        case "ready": return "Ready!"
        default: return "Working…"
        }
    }
}
