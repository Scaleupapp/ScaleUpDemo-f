import SwiftUI

/// V2 Coding Home — destination for the "Coding capstone" Compass chip.
///
/// Single place for everything related to the learner's coding journey:
///   - One-line status (eligibility / next available / in-progress)
///   - Current mastery axes
///   - Last 5 graded capstones (tap → result)
///   - Single "Start a capstone" CTA (uses /request smart-pick when ready)
///   - Retry-from-history if a graded session is tapped
struct V2CodingHomeView: View {
    let onClose: () -> Void
    /// When hosted inside V2CodingHubView, the hub already provides the
    /// NavigationStack, title and Close button, and the Progress segment owns
    /// the mastery view — so we render bare content and skip the duplicate
    /// mastery section.
    var embedded: Bool = false

    @State private var summary: APICapstoneSummary?
    @State private var track: CapstoneTrackResponse?
    @State private var isLoading = true
    @State private var error: String?
    @State private var pickingNew = false
    @State private var pendingBundle: CapstoneLibraryEntry?
    @State private var presentedSessionId: String?
    @State private var showGenerator = false

    private let service = CapstoneService.shared

    private struct IdentifiedString: Identifiable, Hashable {
        let value: String
        var id: String { value }
    }

    var body: some View {
        Group {
            if embedded {
                core
            } else {
                NavigationStack {
                    core
                        .navigationTitle("Coding capstones")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close", action: onClose)
                            }
                        }
                }
            }
        }
        .task { await load() }
    }

    private var core: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading && summary == nil {
                    ProgressView().tint(ColorTokens.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if let summary, !summary.eligible {
                    ineligibleState(summary: summary)
                } else if let summary {
                    intro(summary: summary)
                    if let inProgress = summary.inProgress {
                        inProgressCard(inProgress, line: summary.summaryLine)
                    }
                    if let t = track, t.enrolled == true, let steps = t.steps, !steps.isEmpty {
                        trackSection(t, steps: steps)
                    }
                    // Mastery lives in the hub's Progress segment when embedded.
                    if !embedded, let mastery = summary.mastery {
                        masterySection(mastery)
                    }
                    if !summary.recentCapstones.isEmpty {
                        historySection(summary.recentCapstones)
                    }
                    startNewButton(summary: summary)
                    generateButton()
                    // Full paginated history + the recruiter share link.
                    NavigationLink {
                        CapstoneHistoryView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("All capstones & share")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2)
                        }
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    Spacer().frame(height: 40)
                } else if let error {
                    errorState(message: error)
                }
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 16)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .refreshable { await load() }
        .sheet(isPresented: $pickingNew) {
            if let bundle = pendingBundle {
                CapstonePreflightView(bundle: bundle, onClose: { pickingNew = false })
            } else {
                ProgressView().tint(ColorTokens.gold).padding(40)
            }
        }
        .sheet(isPresented: $showGenerator) {
            CapstoneGeneratorSheet(
                onClose: { showGenerator = false },
                onReady: { entry in
                    // Dismiss the generator and hand the freshly-built,
                    // already-proven capstone straight to Preflight.
                    showGenerator = false
                    pendingBundle = entry
                    pickingNew = true
                }
            )
        }
    }

    // MARK: - Sections

    private func intro(summary: APICapstoneSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.summaryLine)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
            if let track = summary.roleTrack, let diff = summary.currentDifficulty {
                Text("Track: \(track.rawValue.uppercased()) · Current level: \(diff.rawValue.capitalized)")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    private func inProgressCard(_ inProgress: APICapstoneSummaryInProgress, line: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("In progress", systemImage: "laptopcomputer.and.iphone")
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.gold)
            Text(line)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(inProgress.expiresAt.map { "Status: \(inProgress.status). Expires \($0.shortRelative())." }
                 ?? "Status: \(inProgress.status). Open your laptop to begin.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V2Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func masterySection(_ mastery: APICapstoneSummaryMastery) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current mastery")
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.textSecondary)
            VStack(spacing: 6) {
                masteryRow(label: "Prompting", value: mastery.prompting)
                masteryRow(label: "Verification", value: mastery.verification)
                masteryRow(label: "Decomposition", value: mastery.decomposition)
                masteryRow(label: "Refactoring", value: mastery.refactoring)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V2Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func masteryRow(label: String, value: Float?) -> some View {
        let v = max(0, min(10, value ?? 0))
        return HStack(spacing: 10) {
            Text(label)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textPrimary)
                .frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(V2Theme.cardBg.opacity(0.6))
                    Capsule().fill(ColorTokens.gold)
                        .frame(width: geo.size.width * CGFloat(v / 10))
                }
            }
            .frame(height: 6)
            Text(String(format: "%.1f", v))
                .font(V2Theme.small.monospacedDigit())
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func historySection(_ rows: [APICapstoneSummaryRecentEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent capstones")
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.textSecondary)
            VStack(spacing: 6) {
                ForEach(rows, id: \.sessionId) { row in
                    historyRow(row)
                }
            }
        }
    }

    private func historyRow(_ row: APICapstoneSummaryRecentEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.overallScore.map { String(format: "%.1f / 10", $0) } ?? "— / 10")
                    .font(V2Theme.bodyMedium.monospacedDigit())
                    .foregroundStyle(ColorTokens.gold)
                if let d = row.difficulty {
                    Text(d.rawValue.capitalized)
                        .font(V2Theme.tiny)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(V2Theme.cardBg.opacity(0.6))
                        .clipShape(Capsule())
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                Spacer()
                Text(row.gradedAt.map { $0.shortRelative() } ?? "")
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            if let preview = row.bundleBriefPreview, !preview.isEmpty {
                Text(preview)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
            }
            if let bundleId = row.bundleId {
                Button {
                    Task { await retry(bundleId: bundleId) }
                } label: {
                    Label("Try this one again", systemImage: "arrow.clockwise")
                        .font(V2Theme.tiny)
                        .foregroundStyle(ColorTokens.gold)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V2Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func startNewButton(summary: APICapstoneSummary) -> some View {
        let availableNow = (summary.nextAvailableAt ?? Date()) <= Date()
        let label = summary.inProgress != nil ? "Resume on your laptop"
                   : availableNow ? "Start a capstone"
                   : "Next available soon"
        return Button {
            Task { await pickNext() }
        } label: {
            HStack {
                Spacer()
                Image(systemName: "play.circle.fill")
                Text(label).font(V2Theme.h3)
                Spacer()
            }
            .padding(.vertical, 14)
            .foregroundStyle(ColorTokens.background)
            .background(availableNow && summary.inProgress == nil ? ColorTokens.gold : ColorTokens.gold.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!availableNow || summary.inProgress != nil)
    }

    private func generateButton() -> some View {
        VStack(spacing: 6) {
            Button {
                showGenerator = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                    Text("Generate a custom capstone").font(V2Theme.bodyMedium)
                    Spacer()
                }
                .padding(.vertical, 12)
                .foregroundStyle(ColorTokens.gold)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorTokens.gold.opacity(0.55), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            Text("Paste a job description — we'll build and prove a capstone aimed at exactly that.")
                .font(V2Theme.tiny)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func ineligibleState(summary: APICapstoneSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.title2)
                .foregroundStyle(ColorTokens.gold)
            Text(summary.summaryLine)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Set or switch your primary objective in You → Objective to unlock coding capstones.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V2Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couldn't load capstone status")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(message)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
            Button("Retry") { Task { await load() } }
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.gold)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V2Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        error = nil
        do {
            let s = try await service.summary()
            self.summary = s
        } catch {
            self.error = error.localizedDescription
        }
        // Track is best-effort; never blocks the summary.
        if let t = try? await service.track() { self.track = t }
        isLoading = false
    }

    // MARK: - Track section

    @ViewBuilder
    private func trackSection(_ t: CapstoneTrackResponse, steps: [CapstoneTrackStep]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(t.title ?? "Your track", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Text("\(steps.filter { $0.status == "completed" }.count)/\(steps.count)")
                    .font(V2Theme.small.monospacedDigit())
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            ForEach(steps) { step in
                trackStepRow(step)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V2Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func trackStepRow(_ step: CapstoneTrackStep) -> some View {
        let isActive = step.status == "active"
        let isDone = step.status == "completed"
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : isActive ? "play.circle.fill" : "lock.circle")
                .foregroundStyle(isDone ? Color.green : isActive ? ColorTokens.gold : ColorTokens.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.briefPreview.isEmpty ? "Step \(step.index + 1)" : step.briefPreview)
                    .font(V2Theme.small)
                    .foregroundStyle(isActive || isDone ? ColorTokens.textPrimary : ColorTokens.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let d = step.difficulty {
                    Text(d.capitalized + (step.overallScore != nil ? " · \(step.overallScore!)/100" : ""))
                        .font(V2Theme.tiny)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            Spacer()
            if isActive {
                Button("Start") { Task { await startStep(step) } }
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.gold)
            }
        }
    }

    private func startStep(_ step: CapstoneTrackStep) async {
        // Reuse requestNext's preview shape isn't right here; build a minimal
        // library entry from the step and hand to Preflight via pickingNew.
        do {
            let library = try await service.listLibrary()
            if let match = library.first(where: { $0.bundleId == step.bundleId }) {
                self.pendingBundle = match
                self.pickingNew = true
            } else {
                self.error = "This step isn't available right now."
            }
        } catch {
            self.error = "Couldn't open this step."
        }
    }

    private func pickNext() async {
        do {
            let bundle = try await service.requestNext()
            self.pendingBundle = bundle
            self.pickingNew = true
        } catch {
            self.error = "No capstone available right now. Try again after your next graded session."
        }
    }

    private func retry(bundleId: String) async {
        do {
            _ = try await service.retry(bundleId: bundleId)
            await load()
        } catch CapstoneServiceError.invalidTransition {
            self.error = "Finish or abort your in-progress capstone first."
        } catch {
            self.error = "Couldn't start a retry. Try again."
        }
    }
}

// MARK: - Date convenience

private extension Date {
    func shortRelative() -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
}
