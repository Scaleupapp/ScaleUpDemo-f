import SwiftUI
import UIKit
import Combine

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

    /// Background grade-poll task for submitted-but-not-graded sessions.
    @State private var gradePollTask: Task<Void, Never>?

    /// Injected from PlacementsMainTabView — needed by PlacementInterviewTakeView.
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
        // Refresh on app foreground
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await load() }
        }
        .onDisappear { gradePollTask?.cancel() }
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
                        let syncResult = await sync(assessmentSessionId: start.assessmentSessionId)
                        await load()
                        if let status = syncResult?.status, status != "graded" {
                            startGradePoll(assessmentSessionId: start.assessmentSessionId)
                        }
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
        )) { start in
            PlacementCapstonePairView(
                start: start,
                onClose: {
                    Task {
                        let syncResult = await sync(assessmentSessionId: start.assessmentSessionId)
                        activeStart = nil
                        await load()
                        if let status = syncResult?.status, status != "graded" {
                            startGradePoll(assessmentSessionId: start.assessmentSessionId)
                        }
                    }
                }
            )
        }
    }

    // MARK: - Actions

    private func handleTap(row: PlacementAssessmentRow) {
        let status = row.session?.status
        // Guard: graded, submitted, and expired are terminal — no action.
        guard status != "graded", status != "submitted", status != "expired" else { return }

        // Auto-clear any previous start error.
        startError = nil

        // Guard: in_progress — resume (re-present) rather than starting a new session.
        if status == "in_progress" {
            // We don't have the original AssessmentStartResult anymore.
            // Block re-tap and rely on sync poll + foreground refresh.
            // The row already shows "In progress" label.
            return
        }

        startingId = row.id
        Task {
            defer { startingId = nil }
            do {
                let result = try await api.startAssessment(row.id)
                activeStart = result
            } catch {
                startError = friendlyError(error, for: row)
            }
        }
    }

    /// Maps API errors to learner-friendly strings.
    private func friendlyError(_ error: Error, for row: PlacementAssessmentRow) -> String {
        // V2APIError path (used by V2APIClient — the PlacementsAssessmentsApi client)
        if let v2Err = error as? V2APIError {
            if let code = v2Err.extractCode() {
                switch code {
                case "NOT_OPEN":    return "This assessment hasn't opened yet."
                case "CLOSED":      return "This assessment is closed."
                case "NOT_ENROLLED": return "You're not enrolled in this cohort."
                default:            break
                }
            }
            // 403 without a code
            if case .httpError(403, _) = v2Err {
                return "You're not enrolled in this cohort."
            }
            if case .httpError(409, _) = v2Err {
                return "This assessment is not available right now."
            }
        }
        // Legacy APIError path (fallback)
        if let apiErr = error as? APIError {
            switch apiErr {
            case .forbidden: return "You're not enrolled in this cohort."
            case .conflictWithCode(let code, _, _):
                switch code {
                case "NOT_OPEN":    return "This assessment hasn't opened yet."
                case "CLOSED":      return "This assessment is closed."
                case "NOT_ENROLLED": return "You're not enrolled in this cohort."
                default:            break
                }
            default:
                break
            }
        }
        return "Could not start assessment: \(error.localizedDescription)"
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

    @discardableResult
    private func sync(assessmentSessionId: String) async -> AssessmentSyncResult? {
        // Best-effort: ignore errors; return result so caller can inspect status.
        return try? await api.syncSession(assessmentSessionId)
    }

    // MARK: - Submitted-not-graded background poll

    /// Polls listAssessments every 20 s up to 5 min until any session shows
    /// "graded". Cancels if the view disappears (onDisappear cancels gradePollTask).
    private func startGradePoll(assessmentSessionId: String) {
        gradePollTask?.cancel()
        gradePollTask = Task {
            for _ in 0..<15 {   // 15 × 20 s = 5 min
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                // Try a direct sync first.
                if let result = try? await api.syncSession(assessmentSessionId),
                   result.status == "graded" {
                    await load()
                    return
                }
                // Also reload the list (catches server-driven status changes).
                await load()
                // Check if any row is now graded for this session.
                let anyGraded = rows.contains { r in
                    r.session?.id == assessmentSessionId && r.session?.status == "graded"
                }
                if anyGraded { return }
            }
        }
    }
}

// MARK: - Row Card

private struct AssessmentRowCard: View {
    let row: PlacementAssessmentRow
    let isStarting: Bool
    let onTap: () -> Void

    private var statusLabel: String {
        switch row.session?.status {
        case "graded":
            if let score = row.session?.result?.score {
                return "Graded — \(Int(score.rounded()))%"
            }
            return "Graded"
        case "submitted":   return "Submitted — grading…"
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
        return s != "graded" && s != "submitted" && s != "expired" && s != "in_progress"
    }

    private var typeIcon: String {
        switch row.assessment.type {
        case "interview": return "mic.fill"
        case "capstone":  return "laptopcomputer"
        default:          return "checklist"
        }
    }

    /// Human-readable window subtitle, e.g. "Opens 25 Jun · Closes 28 Jun"
    private var windowLabel: String? {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        var parts: [String] = []
        if let s = row.assessment.opensAt,
           let d = ISO8601DateFormatter().date(from: s) {
            parts.append("Opens \(fmt.string(from: d))")
        }
        if let s = row.assessment.closesAt,
           let d = ISO8601DateFormatter().date(from: s) {
            parts.append("Closes \(fmt.string(from: d))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

                    if let window = windowLabel {
                        Text(window)
                            .font(V2Theme.tiny)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

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
        .opacity((!isActionable && row.session?.status != "in_progress") ? 0.6 : 1.0)
    }
}

// MARK: - AssessmentStartResult: Identifiable

extension AssessmentStartResult: Identifiable {
    var id: String { assessmentSessionId }
}
