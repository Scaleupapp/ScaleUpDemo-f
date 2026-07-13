import SwiftUI

/// V2 Interview Home — destination for the "Practice interview" Compass chip.
///
/// Shows the user's interview history (per session — type, target, score),
/// any in-progress session to resume, and a single entry point to start a
/// new mock. Replaces the bare "Compass spawns InterviewSessionView" path.
struct V2InterviewHomeView: View {
    let onClose: () -> Void
    let onStartNew: () -> Void

    @State private var sessions: [InterviewSessionSummary] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var presentedSessionId: String?

    /// Agentic layer #4 (flag `interview_coach`) — probed independently of
    /// session history so a 404 (flag off) only hides this one card instead
    /// of failing the whole screen.
    private enum ProgramProbe {
        case loading
        case unavailable
        case none
        case active(InterviewProgram)
    }
    @State private var programProbe: ProgramProbe = .loading
    @State private var showProgramSheet = false

    private let service = InterviewService()

    private struct IdentifiedString: Identifiable, Hashable {
        let value: String
        var id: String { value }
    }

    private var inProgress: InterviewSessionSummary? {
        sessions.first { $0.status == .in_progress }
    }
    private var history: [InterviewSessionSummary] {
        sessions.filter { $0.status == .completed || $0.status == .evaluated }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading && sessions.isEmpty {
                        ProgressView().tint(ColorTokens.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else {
                        intro
                        programEntryCard
                        if let p = inProgress { inProgressCard(p) }
                        if !history.isEmpty { historySection }
                        if inProgress == nil && history.isEmpty { emptyState }
                        startNewButton
                        Spacer().frame(height: 40)
                    }
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Practice interviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
            .refreshable { await load() }
            .navigationDestination(item: Binding(
                get: { presentedSessionId.map(IdentifiedString.init) },
                set: { presentedSessionId = $0?.value }
            )) { wrap in
                V2InterviewSessionLauncher(sessionId: wrap.value)
            }
            .sheet(isPresented: $showProgramSheet) {
                InterviewProgramView(
                    onClose: { showProgramSheet = false },
                    onStartInterview: {
                        showProgramSheet = false
                        onClose()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onStartNew()
                        }
                    }
                )
            }
        }
        .task { await load() }
        .task { await loadProgramProbe() }
    }

    // MARK: - Sections

    /// "Start a program" / "Your program" — agentic layer #4 entry point.
    /// Hidden entirely while loading or when the backend 404s (flag off).
    @ViewBuilder
    private var programEntryCard: some View {
        switch programProbe {
        case .loading, .unavailable:
            EmptyView()
        case .none:
            Button {
                showProgramSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.gold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start a program")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("A coached multi-week plan for one target role")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(12)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        case .active(let program):
            Button {
                showProgramSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.gold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your program")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("Week \(program.weekStrip.current) of \(program.weekStrip.total)\(program.target.role.map { " \u{00B7} \($0)" } ?? "")")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("Open \u{2192}")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(12)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var intro: some View {
        Text("Mock interviews — voice or text, scored with feedback. Stale sessions are auto-cleared.")
            .font(V2Theme.small)
            .foregroundStyle(ColorTokens.textSecondary)
    }

    private func inProgressCard(_ s: InterviewSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("IN PROGRESS").v2Eyebrow()
                Spacer()
            }
            .padding(.bottom, 8)
            Button {
                presentedSessionId = s.id
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.gold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(typeLabel(s.interviewType))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text(metaLine(s))
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                    Text("Open →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(12)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORY").v2Eyebrow()
            VStack(spacing: 0) {
                ForEach(history.prefix(20)) { s in
                    Button {
                        presentedSessionId = s.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(typeLabel(s.interviewType))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .lineLimit(1)
                                Text(metaLine(s))
                                    .font(.system(size: 10))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            Spacer()
                            if let score = s.overallScore {
                                Text("\(score)/100")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(scoreColor(score))
                            } else {
                                Text(s.status == .evaluated ? "—" : "Pending")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .padding(.leading, 4)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var startNewButton: some View {
        Button {
            onClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onStartNew()
            }
        } label: {
            HStack {
                Image(systemName: "mic.fill")
                Text("Start a new interview")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(ColorTokens.gold)
            .foregroundStyle(ColorTokens.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🎙️").font(.system(size: 28))
            Text("No interviews yet")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Start a mock — voice or text. You'll get detailed feedback after.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func load() async {
        isLoading = true
        do {
            sessions = try await service.listSessions(page: 1, limit: 30)
        } catch {
            self.error = "Couldn't load your interviews."
        }
        isLoading = false
    }

    /// Probes GET /interview-program independently of session history.
    /// Degrades invisibly on 404 (flag off) or any other error — this card
    /// simply doesn't render, the rest of the screen is unaffected.
    private func loadProgramProbe() async {
        do {
            if let program = try await InterviewProgramService.fetch() {
                programProbe = .active(program)
            } else {
                programProbe = .none
            }
        } catch {
            programProbe = .unavailable
        }
    }

    private func typeLabel(_ t: InterviewType) -> String {
        switch t {
        case .mba_admissions:      return "MBA Admissions"
        case .placement_hr:        return "Placement · HR"
        case .placement_technical: return "Placement · Technical"
        case .case_study:          return "Case study"
        case .behavioral:          return "Behavioral"
        }
    }

    private func metaLine(_ s: InterviewSessionSummary) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        let date = (s.startedAt ?? s.createdAt).map { f.string(from: $0) } ?? "—"
        var parts: [String] = [date]
        if let role = s.targetRole, !role.isEmpty { parts.append(role) }
        if let company = s.targetCompany, !company.isEmpty { parts.append("@ \(company)") }
        parts.append(s.difficulty.displayName)
        return parts.joined(separator: " · ")
    }

    private func scoreColor(_ s: Int) -> Color {
        if s < 50 { return ColorTokens.warning }
        if s >= 70 { return ColorTokens.success }
        return ColorTokens.textPrimary
    }
}
