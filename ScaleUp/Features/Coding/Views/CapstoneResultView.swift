import SwiftUI

/// Capstone result screen (spec §8.2): 6-dim rubric, strengths, gaps,
/// interview parallel, integrity confidence. Polls /result until graded
/// when entering in non-graded state.
struct CapstoneResultView: View {
    let sessionId: String
    let onClose: () -> Void

    @State private var state: ViewState = .loading
    @State private var pollTask: Task<Void, Never>?
    @State private var showReplay = false
    @State private var showVoiceReflection = false
    @State private var retryInFlight = false
    @State private var retryError: String?

    enum ViewState {
        case loading
        case pending(CapstoneSessionStatus)
        case graded(CapstoneResult)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            content
                .padding(20)
                .navigationTitle("Capstone result")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { onClose() }
                    }
                }
                .onAppear { startPolling() }
                .onDisappear { pollTask?.cancel() }
                .sheet(isPresented: $showReplay) {
                    CapstoneReplayView(sessionId: sessionId)
                }
                .sheet(isPresented: $showVoiceReflection) {
                    CapstoneVoiceReflectionView(sessionId: sessionId) {
                        showVoiceReflection = false
                        startPolling() // re-fetch in case re-score lands
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .pending(let s):
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.2)
                Text(s.displayLabel).font(.headline)
                Text("We'll push a notification when it's ready. Usually 3–10 minutes.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .graded(let result):
            graded(result)
        case .error(let msg):
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                Text("Couldn't load result").font(.headline)
                Text(msg).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func graded(_ result: CapstoneResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scoreCard(result)
                if let rationale = result.overallRationale, !rationale.isEmpty {
                    overallRationaleSection(rationale)
                }
                if let ts = result.testSummary, hasTestSummary(ts) {
                    testSummarySection(ts)
                }
                rubricSection(result)
                if let notes = result.evidenceNotes, !notes.isEmpty {
                    evidenceNotesSection(notes)
                }
                strengthsGapsSection(result)
                integritySection(result)
                if let parallel = result.interviewParallel, !parallel.isEmpty {
                    interviewParallel(parallel)
                }
                nextStepCard(result)
                actionButtons(result)
                Spacer(minLength: 60)
            }
        }
    }

    /// Why this OVERALL score — names the weighting + what drove it, so a
    /// learner who felt they "did well" understands what cost them points.
    private func overallRationaleSection(_ rationale: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.caption.weight(.semibold))
                Text("WHY THIS SCORE").font(.caption.weight(.bold)).tracking(1.2)
            }
            .foregroundStyle(.tint)
            Text(rationale)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
    }

    private func hasTestSummary(_ ts: CapstoneTestSummary) -> Bool {
        (ts.visibleTotal ?? 0) > 0 || (ts.hiddenTotal ?? 0) > 0
    }

    /// Visible vs hidden test split — the deterministic driver behind the
    /// correctness score (and the usual reason "I passed everything I saw but
    /// still scored low": hidden edge-case tests failed).
    private func testSummarySection(_ ts: CapstoneTestSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tests").font(.headline)
            HStack(spacing: 10) {
                testPill(label: "Visible", passed: ts.visiblePassed, total: ts.visibleTotal)
                testPill(label: "Hidden", passed: ts.hiddenPassed, total: ts.hiddenTotal)
                if let lint = ts.lintPassed {
                    HStack(spacing: 5) {
                        Image(systemName: lint ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(lint ? .green : .orange)
                        Text("Lint").font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Color(.tertiarySystemBackground)))
                }
            }
            if (ts.hiddenTotal ?? 0) > 0, (ts.hiddenPassed ?? 0) < (ts.hiddenTotal ?? 0) {
                Text("Hidden tests check edge cases you couldn't see while coding. Missing them is the usual reason a confident attempt still scores below expectation.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func testPill(label: String, passed: Int?, total: Int?) -> some View {
        let p = passed ?? 0
        let t = total ?? 0
        let allPass = t > 0 && p == t
        HStack(spacing: 5) {
            Image(systemName: allPass ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                .foregroundStyle(allPass ? .green : (t > 0 ? .orange : .secondary))
            Text("\(label) \(p)/\(t)").font(.caption.weight(.medium)).monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color(.tertiarySystemBackground)))
    }

    /// Detailed analysis — the LLM scorer's narrative explanation of why
    /// these scores. Cites specific files, test names, Compass turns.
    private func evidenceNotesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.magnifyingglass")
                    .font(.caption.weight(.semibold))
                Text("DETAILED ANALYSIS")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
            }
            .foregroundStyle(.tint)
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func scoreCard(_ result: CapstoneResult) -> some View {
        VStack(spacing: 4) {
            Text("Overall")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(result.overallScore)")
                    .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                Text("/ 100").font(.title3).foregroundStyle(.secondary)
            }
            verdict(for: result.overallScore)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func verdict(for s: Int) -> some View {
        let (text, color): (String, Color) = {
            switch s {
            case 85...:   return ("Excellent work", .green)
            case 70..<85: return ("Solid attempt", .blue)
            case 50..<70: return ("Getting there", .orange)
            default:      return ("Room to grow", .red)
            }
        }()
        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(color)
    }

    private func rubricSection(_ result: CapstoneResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How you did").font(.headline)
            VStack(spacing: 16) {
                ForEach(result.dimensionRows) { row in
                    RubricBar(
                        dimension: row.id,
                        score: row.score,
                        weightPct: row.weightPct,
                        why: row.why,
                        toImprove: row.toImprove
                    )
                }
            }
        }
        .padding(16).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func strengthsGapsSection(_ result: CapstoneResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !result.strengths.isEmpty {
                Text("Strengths").font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.strengths, id: \.self) { s in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(s).font(.subheadline)
                        }
                    }
                }
            }
            if !result.gaps.isEmpty {
                Text("Gaps").font(.subheadline.weight(.semibold)).padding(.top, 6)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.gaps, id: \.self) { g in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.orange)
                            Text(g).font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding(16).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func integritySection(_ result: CapstoneResult) -> some View {
        let (label, color): (String, Color) = {
            switch result.integrityConfidence {
            case "high":   return ("High integrity confidence", .green)
            case "medium": return ("Medium integrity confidence", .orange)
            default:       return ("Low integrity confidence", .red)
            }
        }()
        return HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.medium))
                if result.anchorDriftDetected == true {
                    Text("This score was aligned to a deterministic baseline and is queued for a quick human review — it may be adjusted slightly.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func interviewParallel(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "briefcase.fill").foregroundStyle(.tint).padding(.top, 2)
            Text(text).font(.subheadline)
        }
        .padding(14).background(Color.accentColor.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private func nextStepCard(_ result: CapstoneResult) -> some View {
        if let gap = result.gaps.first {
            NextStepCard(
                lead: "Strengthen your weakest area:",
                highlight: gap,
                actionTitle: "Practice with a drill"
            ) {
                NextStepCoordinator.shared.fire(.launchDrill(subtype: nil))
                onClose()
            }
        }
    }

    private func actionButtons(_ result: CapstoneResult) -> some View {
        VStack(spacing: 10) {
            Button {
                showVoiceReflection = true
            } label: {
                Label("Record 60-sec reflection", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button {
                showReplay = true
            } label: {
                Label("Watch replay", systemImage: "play.rectangle.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if let bundleId = result.bundleId {
                Button {
                    Task { await retry(bundleId: bundleId) }
                } label: {
                    HStack {
                        if retryInFlight {
                            ProgressView().tint(.white)
                            Text("Starting…")
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Try this capstone again")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(retryInFlight)

                if let retryError {
                    Text(retryError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 4)
    }

    private func retry(bundleId: String) async {
        retryInFlight = true
        retryError = nil
        defer { retryInFlight = false }
        do {
            _ = try await CapstoneService.shared.retry(bundleId: bundleId)
            // Close the result sheet — the new session's pairing flow will start
            // from CapstoneLibrary / Compass coding home. The user already saw
            // their result; this dismissal is the same UX as the existing flow.
            onClose()
        } catch CapstoneServiceError.invalidTransition {
            retryError = "You have a session in progress. Finish or abort it first."
        } catch {
            retryError = "Couldn't start a retry. Try again."
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        state = .loading
        pollTask = Task {
            for _ in 0..<240 { // ~20 min worst case
                if Task.isCancelled { return }
                do {
                    let r = try await CapstoneService.shared.pollResult(sessionId: sessionId)
                    switch r {
                    case .graded(let g):
                        await MainActor.run { state = .graded(g) }
                        return
                    case .pending(let s):
                        await MainActor.run { state = .pending(s) }
                    }
                } catch {
                    await MainActor.run { state = .error("Couldn't load. Pull to refresh later.") }
                    return
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
}
