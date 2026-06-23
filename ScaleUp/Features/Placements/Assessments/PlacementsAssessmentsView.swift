import SwiftUI

// MARK: - Main Assessments Section

/// Section displayed on the Placements Home screen, listing all scheduled
/// assessments for the student and providing a tap-to-take action for each.
struct PlacementsAssessmentsView: View {
    @State private var rows: [PlacementAssessmentRow] = []
    @State private var isLoading = false
    @State private var loadError: String?

    /// Sheet state: which assessment the student just started.
    @State private var activeStart: AssessmentStartResult?
    @State private var startError: String?
    @State private var startingId: String?   // which card shows a spinner

    /// Injected from PlacementsMainTabView — needed by InterviewSessionView's sub-views.
    @Environment(V2NavState.self) private var v2Nav
    @Environment(V2TaskRouter.self) private var taskRouter
    @Environment(AppState.self) private var appState

    private let api = PlacementsAssessmentsApi.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scheduled assessments").v2Eyebrow()

            if isLoading && rows.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(ColorTokens.gold)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let loadError {
                Text(loadError)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.vertical, 8)
            } else if rows.isEmpty {
                Text("Assessments scheduled by your placement office will appear here. In the meantime, keep building readiness with Compass and your daily plan.")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(rows) { row in
                    AssessmentRowCard(
                        row: row,
                        isStarting: startingId == row.id,
                        onTap: { handleTap(row: row) }
                    )
                }
            }

            if let startError {
                Text(startError)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.error)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await load() }
        // MCQ sheet
        .sheet(item: Binding(
            get: { activeStart.flatMap { $0.engine.type == "mcq" ? $0 : nil } },
            set: { if $0 == nil { activeStart = nil } }
        )) { start in
            if let quizId = start.engine.quizId {
                PlanTaskQuizLoaderSheet(quizId: quizId) {
                    Task {
                        await sync(assessmentSessionId: start.assessmentSessionId)
                        await load()
                    }
                }
            } else {
                // quizId missing — show fallback
                VStack(spacing: 16) {
                    Text("MCQ assessment is not configured yet.")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Button("Close") { activeStart = nil }
                }
                .padding()
            }
        }
        // Interview sheet
        .sheet(item: Binding(
            get: { activeStart.flatMap { $0.engine.type == "interview" ? $0 : nil } },
            set: { if $0 == nil { activeStart = nil } }
        )) { start in
            PlacementInterviewTakeView(
                start: start,
                onComplete: {
                    Task {
                        await sync(assessmentSessionId: start.assessmentSessionId)
                        await load()
                    }
                }
            )
            .environment(v2Nav)
            .environment(taskRouter)
            .environment(appState)
        }
        // Capstone sheet
        .sheet(item: Binding(
            get: { activeStart.flatMap { $0.engine.type == "capstone" ? $0 : nil } },
            set: { if $0 == nil { activeStart = nil } }
        )) { _ in
            VStack(spacing: 20) {
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
                Button("Got it") { activeStart = nil }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.background)
        }
    }

    // MARK: - Actions

    private func handleTap(row: PlacementAssessmentRow) {
        let status = row.session?.status
        // Only allow starting if not already graded or submitted
        guard status != "graded", status != "submitted" else { return }

        startError = nil
        startingId = row.id
        Task {
            defer { startingId = nil }
            do {
                let result = try await api.startAssessment(row.id)
                activeStart = result
            } catch {
                startError = "Could not start assessment: \(error.localizedDescription)"
            }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            rows = try await api.listAssessments()
        } catch {
            loadError = "Could not load assessments."
        }
        isLoading = false
    }

    private func sync(assessmentSessionId: String) async {
        // Best-effort: ignore errors
        _ = try? await api.syncSession(assessmentSessionId)
    }
}

// MARK: - Row Card

private struct AssessmentRowCard: View {
    let row: PlacementAssessmentRow
    let isStarting: Bool
    let onTap: () -> Void

    private var statusLabel: String {
        switch row.session?.status {
        case "graded":      return "Graded"
        case "submitted":   return "Submitted"
        case "in_progress": return "In progress"
        case "scheduled":   return "Not started"
        case "expired":     return "Expired"
        default:            return "Not started"
        }
    }

    private var statusColor: Color {
        switch row.session?.status {
        case "graded":      return ColorTokens.success
        case "submitted":   return ColorTokens.gold
        case "in_progress": return .orange
        case "expired":     return ColorTokens.textTertiary
        default:            return ColorTokens.textTertiary
        }
    }

    private var isActionable: Bool {
        let s = row.session?.status
        return s != "graded" && s != "submitted" && s != "expired"
    }

    private var typeIcon: String {
        switch row.assessment.type {
        case "interview": return "mic.fill"
        case "capstone":  return "laptopcomputer"
        default:          return "checklist"
        }
    }

    var body: some View {
        Button(action: { if isActionable { onTap() } }) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: typeIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 34, height: 34)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.assessment.title)
                        .font(V2Theme.h3)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(row.assessment.type.uppercased())
                        .font(V2Theme.tiny)
                        .foregroundStyle(ColorTokens.textTertiary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(statusLabel)
                            .font(V2Theme.small)
                            .foregroundStyle(statusColor)
                    }
                }

                Spacer(minLength: 0)

                if isStarting {
                    ProgressView()
                        .tint(ColorTokens.gold)
                        .scaleEffect(0.8)
                } else if isActionable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(16)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isActionable || isStarting)
        .opacity(!isActionable ? 0.6 : 1.0)
    }
}

// MARK: - Interview Take View

/// Inline launcher that holds an `InterviewViewModel`, renders `InterviewSessionView`,
/// and calls `vm.attachSession(...)` on appear. On sheet dismiss the caller syncs
/// the assessment session.
struct PlacementInterviewTakeView: View {
    let start: AssessmentStartResult
    let onComplete: () -> Void

    @State private var vm = InterviewViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        InterviewSessionView(viewModel: vm)
            .task {
                await vm.attachSession(
                    sessionId: start.engine.sessionId ?? "",
                    systemInstruction: start.meta?.systemInstruction ?? ""
                )
            }
            .onChange(of: vm.state) { _, newState in
                if case .results = newState {
                    onComplete()
                    dismiss()
                }
            }
    }
}

// MARK: - AssessmentStartResult: Identifiable

extension AssessmentStartResult: Identifiable {
    var id: String { assessmentSessionId }
}
