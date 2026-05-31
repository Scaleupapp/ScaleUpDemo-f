import SwiftUI

struct V2CodingMasteryView: View {
    /// Controls which parts render so the same view can back two hub segments:
    ///  - .practiceOnly → drill CTAs + recent drill attempts (the "do" tab)
    ///  - .progressOnly → stats + per-skill mastery bars (the "Progress" tab)
    ///  - .full         → everything (standalone, e.g. previews)
    enum Mode { case full, practiceOnly, progressOnly }
    var mode: Mode = .full

    @State private var state: LoadState = .loading
    @State private var todayStatus: TodayDrillStatus = .unknown
    @State private var showDrillModal = false
    @State private var showCalibration = false
    @State private var showPracticeAnotherSheet = false
    @State private var pendingRequest: PracticeRequest? = nil        // queued across sheet transitions
    @State private var requestedDrillSession: DrillSession? = nil    // sheet(item:) driver
    @State private var isRequestingDrill = false                     // overlay while in-flight
    @State private var requestErrorMessage: String? = nil            // shown on failure
    @State private var showCapstoneLibrary = false                   // capstone entry point (WS6)
    @State private var capstoneResultId: IdentifiedString? = nil     // present a graded capstone's result

    struct IdentifiedString: Identifiable, Hashable {
        let value: String
        var id: String { value }
    }

    struct PracticeRequest: Equatable {
        let subtype: DrillSubtype?
        let difficulty: DrillDifficulty?
    }

    enum LoadState {
        case loading
        case empty
        case loaded(CodingMasteryResponse)
        case error(String)
    }

    /// Tracks whether today's daily drill quota is consumed. Drives whether we
    /// show the gold "Take today's drill" button or the "done for today" card.
    /// `.unknown` is the initial state — we don't gate the button on it so a
    /// network blip doesn't hide a perfectly-good CTA.
    enum TodayDrillStatus: Equatable {
        case unknown
        case available
        case completedToday(nextAt: Date?)
    }

    var body: some View {
        // When hosted in V2CodingHubView the hub owns the nav title ("Coding"),
        // so only the standalone (.full) variant sets its own title.
        if mode == .full {
            scrollBody
                .navigationTitle("Coding mastery")
                .navigationBarTitleDisplayMode(.large)
        } else {
            scrollBody
        }
    }

    private var scrollBody: some View {
        ScrollView {
            content
                .padding(20)
        }
        .task { await load() }
        .sheet(isPresented: $showDrillModal) {
            DrillModalView()
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationSequenceView()
        }
        .sheet(isPresented: $showCapstoneLibrary) {
            CapstoneLibraryView()
        }
        .sheet(item: $capstoneResultId) { ident in
            CapstoneResultView(sessionId: ident.value, onClose: { capstoneResultId = nil })
        }
        // Picker sheet — onDismiss fires AFTER the sheet is fully gone, avoiding
        // the sheet-from-sheet race where SwiftUI would eat the second presentation.
        .sheet(isPresented: $showPracticeAnotherSheet, onDismiss: {
            if let pending = pendingRequest {
                pendingRequest = nil
                Task { await performRequest(pending) }
            }
        }) {
            PracticeAnotherSheet { subtype, difficulty in
                pendingRequest = PracticeRequest(subtype: subtype, difficulty: difficulty)
                showPracticeAnotherSheet = false  // triggers onDismiss above
            }
            .presentationDetents([.medium])
        }
        // sheet(item:) — SwiftUI handles the optional correctly, no race condition
        .sheet(item: $requestedDrillSession) { session in
            DrillModalView(preloadedSession: session)
        }
        // Error alert
        .alert("Couldn't start drill", isPresented: Binding(
            get: { requestErrorMessage != nil },
            set: { if !$0 { requestErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { requestErrorMessage = nil }
        } message: {
            Text(requestErrorMessage ?? "")
        }
        // Loading overlay while the API call is in flight
        .overlay {
            if isRequestingDrill {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("Finding a drill for you…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        case .empty:
            emptyState
        case .loaded(let data):
            loadedView(data)
        case .error(let msg):
            ContentUnavailableView("Couldn't load", systemImage: "exclamationmark.triangle", description: Text(msg))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.top, 40)
            Text("Coding practice for your objective")
                .font(.title3.weight(.semibold))
            Text("Take a 6-min calibration to find your starting level, then daily 10-min drills build the meta-skills companies actually hire for.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showCalibration = true
            } label: {
                Text("Start calibration").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }

    private func loadedView(_ data: CodingMasteryResponse) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Stats + per-skill mastery bars live in the hub's Progress segment
            // (and the standalone view). Hidden in the Practice segment.
            if mode != .practiceOnly {
                statsCard(data.stats)

                ForEach(data.tracks, id: \.roleTrack) { track in
                    trackCard(track)
                }

                // Capstone results now live in Progress alongside drills.
                let capstones = data.recentCapstones ?? []
                if !capstones.isEmpty {
                    recentCapstonesList(capstones)
                }
            }

            // Recent drill attempts — the Practice segment + standalone, not Progress.
            if mode != .progressOnly, !data.recentAttempts.isEmpty {
                recentAttemptsList(data.recentAttempts)
            }

            // The "do a drill" controls — hidden in the read-only Progress segment.
            if mode != .progressOnly {
                // CTA — gold button only when today's drill is still available.
                // After completion, swap for an informational card so the user
                // doesn't tap into the modal just to see "daily quota used".
                switch todayStatus {
                case .completedToday(let nextAt):
                    completedTodayCard(nextAt: nextAt)
                default:
                    Button {
                        showDrillModal = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Take today's drill")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button {
                    showPracticeAnotherSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Practice another")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.tint)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            // Capstones link only in the standalone view — in the hub, capstones
            // are their own segment, so this would be redundant.
            if mode == .full {
            Button {
                showCapstoneLibrary = true
            } label: {
                HStack {
                    Image(systemName: "laptopcomputer.and.iphone")
                    Text("Browse capstones")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.primary)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            } // end if mode == .full (Browse capstones)
        }
    }

    private func completedTodayCard(nextAt: Date?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's drill complete")
                    .font(.subheadline.weight(.semibold))
                Text(nextDrillCopy(nextAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func nextDrillCopy(_ nextAt: Date?) -> String {
        guard let date = nextAt else {
            return "Come back tomorrow for the next one — or tap Practice another to keep going."
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let rel = formatter.localizedString(for: date, relativeTo: Date())
        return "Next drill unlocks \(rel). Tap Practice another to keep going."
    }

    private func performRequest(_ req: PracticeRequest) async {
        isRequestingDrill = true
        defer { isRequestingDrill = false }

        do {
            let body = DrillRequestBody(
                drillSubtype: req.subtype,
                difficulty: req.difficulty,
                topicHint: nil
            )
            let resp = try await DrillService.shared.requestDrill(body: body)
            let session = DrillSession(
                preloadedDrill: resp.toTodayResponse(),
                preloadedAttemptId: resp.attemptId
            )
            requestedDrillSession = session
            AnalyticsService.shared.track(.codingExtraDrillRequested(source: "mastery_view"))
        } catch {
            requestErrorMessage = humanReadableError(error)
            print("[performRequest] failed: \(error)")
        }
    }

    private func humanReadableError(_ error: Error) -> String {
        if let svc = error as? DrillServiceError {
            switch svc {
            case .calibrationRequired:
                return "Take the 6-minute calibration first so we can pitch drills at your level."
            case .dailyQuotaUsed(let nextAt):
                if let date = nextAt {
                    let f = RelativeDateTimeFormatter(); f.unitsStyle = .full
                    return "You've already done today's drill — next one unlocks \(f.localizedString(for: date, relativeTo: Date()))."
                }
                return "You've already done today's drill — come back tomorrow."
            case .noDrillAvailable:
                return "We're out of fresh drills for this combination — try another type or difficulty."
            case .invalidResponse:
                return "Got an unexpected response from the server. Try again in a moment."
            }
        }
        if case V2APIError.httpError(let status, let data) = error {
            if status == 404, let body = try? JSONDecoder().decode([String: String].self, from: data) {
                switch body["error"] {
                case "no_coding_track_for_objective":
                    return "Coding practice isn't available for your current objective."
                case "no_drill_available":
                    return "We're out of fresh drills for this combination — try another type or difficulty."
                case "calibration_required":
                    return "Take the 6-minute calibration first so we can pitch drills at your level."
                case "daily_quota_used":
                    return "You've already done today's drill — come back tomorrow."
                default:
                    break
                }
            }
            return "Server returned \(status). Try again in a moment."
        }
        return error.localizedDescription
    }

    private func statsCard(_ stats: CodingMasteryStats) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                statTile(label: "Drills graded", value: "\(stats.totalDrillsGraded)")
                statTile(label: "Avg drill", value: stats.averageScore.map { "\($0)" } ?? "—")
            }
            if (stats.totalCapstonesGraded ?? 0) > 0 {
                HStack(spacing: 16) {
                    statTile(label: "Capstones graded", value: "\(stats.totalCapstonesGraded ?? 0)")
                    statTile(label: "Avg capstone", value: stats.averageCapstoneScore.map { "\($0)" } ?? "—")
                }
            }
        }
    }

    private func recentCapstonesList(_ capstones: [CodingMasteryCapstone]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent capstones")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(capstones) { c in
                    Button {
                        capstoneResultId = IdentifiedString(value: c.id)
                    } label: {
                        capstoneRow(c)
                    }
                    .buttonStyle(.plain)
                    if c.id != capstones.last?.id { Divider() }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func capstoneRow(_ c: CodingMasteryCapstone) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text((c.title?.isEmpty == false) ? c.title! : "Capstone")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(c.difficulty?.capitalized ?? "—") · \(relativeTime(c.gradedAt))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let score = c.overallScore {
                Text("\(score)").font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(score >= 80 ? .green : score >= 60 ? .orange : .red)
                Text("/100").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("—").font(.subheadline).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.weight(.bold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func trackCard(_ track: CodingMasteryTrack) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(roleTrackTitle(track.roleTrack))
                    .font(.headline)
                Spacer()
                Text(track.currentDifficulty.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 10) {
                RubricBar(dimension: "prompting", score: track.axes.prompting / 10.0, feedback: nil)
                RubricBar(dimension: "verification", score: track.axes.verification / 10.0, feedback: nil)
                RubricBar(dimension: "decomposition", score: track.axes.decomposition / 10.0, feedback: nil)
                RubricBar(dimension: "refactoring", score: track.axes.refactoring / 10.0, feedback: nil)
            }

            HStack {
                Text("\(track.attemptCount) drills · confidence \(Int(track.confidence * 100))%")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recentAttemptsList(_ attempts: [CodingMasteryAttempt]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent attempts")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(attempts) { a in
                    attemptRow(a)
                    if a.id != attempts.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func attemptRow(_ a: CodingMasteryAttempt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(a.drillSubtype.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline.weight(.semibold))
                    if a.isCalibration {
                        Text("CALIBRATION").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.2)).clipShape(Capsule())
                    }
                }
                Text("\(a.difficulty?.capitalized ?? "—") · \(relativeTime(a.submittedAt))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let score = a.score {
                Text("\(score)").font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(score >= 80 ? .green : score >= 60 ? .orange : .red)
            } else {
                Text("—").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func roleTrackTitle(_ key: String) -> String {
        switch key {
        case "swe": return "Software Engineer"
        case "ds": return "Data Scientist"
        case "ai_eng": return "AI / ML Engineer"
        default: return key.uppercased()
        }
    }

    private func relativeTime(_ iso: String?) -> String {
        guard let iso = iso, let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func load() async {
        do {
            let resp: V2APIResponse<CodingMasteryResponse> = try await V2APIClient.shared.get("/you/coding-mastery")
            todayStatus = await probeTodayDrillStatus()
            if resp.data.tracks.isEmpty && (resp.data.recentCapstones ?? []).isEmpty {
                state = .empty
            } else {
                state = .loaded(resp.data)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Probes /drills/today to discover whether the daily quota is used.
    /// Never throws — degrades to `.unknown` so the CTA defaults to visible
    /// if the probe fails (better UX than hiding a working button on a glitch).
    private func probeTodayDrillStatus() async -> TodayDrillStatus {
        do {
            _ = try await DrillService.shared.fetchTodayDrill()
            return .available
        } catch DrillServiceError.dailyQuotaUsed(let nextAt) {
            return .completedToday(nextAt: nextAt)
        } catch {
            return .unknown
        }
    }
}

// MARK: - Backing models for /api/v2/you/coding-mastery

struct CodingMasteryResponse: Codable, Sendable {
    let tracks: [CodingMasteryTrack]
    let recentAttempts: [CodingMasteryAttempt]
    let recentCapstones: [CodingMasteryCapstone]?   // capstone results now surface here too
    let stats: CodingMasteryStats

    enum CodingKeys: String, CodingKey {
        case tracks
        case recentAttempts = "recent_attempts"
        case recentCapstones = "recent_capstones"
        case stats
    }
}

/// A graded capstone shown in the Progress tab alongside drills. `overallScore`
/// is 0..100 (drills are too).
struct CodingMasteryCapstone: Codable, Sendable, Identifiable {
    let id: String
    let bundleId: String?
    let title: String?
    let difficulty: String?
    let roleTrack: String?
    let overallScore: Int?
    let integrityConfidence: String?
    let gradedAt: String?
    let isRetry: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case bundleId = "bundle_id"
        case title
        case difficulty
        case roleTrack = "role_track"
        case overallScore = "overall_score"
        case integrityConfidence = "integrity_confidence"
        case gradedAt = "graded_at"
        case isRetry = "is_retry"
    }
}

struct CodingMasteryTrack: Codable, Sendable {
    let roleTrack: String
    let axes: CodingMasteryAxes
    let confidence: Double
    let attemptCount: Int
    let currentDifficulty: String

    enum CodingKeys: String, CodingKey {
        case roleTrack = "role_track"
        case axes
        case confidence
        case attemptCount = "attempt_count"
        case currentDifficulty = "current_difficulty"
    }
}

struct CodingMasteryAxes: Codable, Sendable {
    let prompting: Double
    let verification: Double
    let decomposition: Double
    let refactoring: Double
}

struct CodingMasteryAttempt: Codable, Sendable, Identifiable {
    let id: String
    let drillSubtype: String
    let difficulty: String?
    let roleTrack: String?
    let score: Int?
    let submittedAt: String?
    let isCalibration: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case drillSubtype = "drill_subtype"
        case difficulty
        case roleTrack = "role_track"
        case score
        case submittedAt = "submitted_at"
        case isCalibration = "is_calibration"
    }
}

struct CodingMasteryStats: Codable, Sendable {
    let totalDrillsGraded: Int
    let averageScore: Int?
    let totalCapstonesGraded: Int?
    let averageCapstoneScore: Int?

    enum CodingKeys: String, CodingKey {
        case totalDrillsGraded = "total_drills_graded"
        case averageScore = "average_score"
        case totalCapstonesGraded = "total_capstones_graded"
        case averageCapstoneScore = "average_capstone_score"
    }
}

// MARK: - PracticeAnotherSheet

struct PracticeAnotherSheet: View {
    let onConfirm: (DrillSubtype?, DrillDifficulty?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSubtype: DrillSubtype? = nil
    @State private var selectedDifficulty: DrillDifficulty? = nil

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Custom practice")
                    .font(.title3.weight(.semibold))

                Text("Pick what you want to practice. Leave fields blank to let us pick based on your weakest area + current difficulty.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Subtype picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drill type").font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        subtypeChip(nil, label: "Auto", icon: "sparkles")
                        subtypeChip(.prompt, label: "Prompt", icon: "text.bubble")
                        subtypeChip(.verify, label: "Bug Hunt", icon: "magnifyingglass")
                        subtypeChip(.decompose, label: "Decompose", icon: "list.number")
                    }
                }

                // Difficulty picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty").font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        difficultyChip(nil, label: "Auto")
                        difficultyChip(.easy, label: "Easy")
                        difficultyChip(.medium, label: "Medium")
                        difficultyChip(.hard, label: "Hard")
                    }
                }

                Spacer()

                Button {
                    onConfirm(selectedSubtype, selectedDifficulty)
                } label: {
                    Text("Start drill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func subtypeChip(_ value: DrillSubtype?, label: String, icon: String) -> some View {
        let isSelected = selectedSubtype == value
        return Button {
            selectedSubtype = value
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func difficultyChip(_ value: DrillDifficulty?, label: String) -> some View {
        let isSelected = selectedDifficulty == value
        return Button {
            selectedDifficulty = value
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { V2CodingMasteryView() }
        .preferredColorScheme(.dark)
}
