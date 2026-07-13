import SwiftUI

// Dispatcher — renders the right card view for a decoded payload.
struct CompassCardView: View {
    let card: CompassCard
    var body: some View {
        switch card.payload {
        case .readiness(let p):          CompassReadinessCard(payload: p)
        case .activityResult(let p):     CompassActivityResultCard(payload: p)
        case .topicDetail(let p):        CompassTopicDetailCard(payload: p)
        case .weakTopics(let topics):    CompassWeakTopicsCard(topics: topics)
        case .recentActivity(let items): CompassRecentActivityCard(items: items)
        case .tutoringResult(let p):     CompassTutoringResultCard(payload: p)
        case .agentProposal(let p):      CompassAgentProposalCard(payload: p)
        case .unknown:                   EmptyView()
        }
    }
}

private struct CardShell<Content: View>: View {
    let title: String; let systemImage: String; @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.caption.weight(.semibold)).foregroundStyle(ColorTokens.gold)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(ColorTokens.gold)
            }
            content()
        }
        .padding(12)
        .background(ColorTokens.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ColorTokens.gold.opacity(0.2), lineWidth: 1))
    }
}

private func scoreText(_ v: Double?) -> String { v == nil ? "—" : String(Int(v!.rounded())) }

struct CompassReadinessCard: View {
    let payload: CompassReadinessPayload
    var body: some View {
        CardShell(title: "Readiness", systemImage: "scope") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(scoreText(payload.value))%").font(.title2.weight(.bold)).foregroundStyle(ColorTokens.textPrimary)
                if let t = payload.target { Text("/ target \(scoreText(t))%").font(.caption).foregroundStyle(ColorTokens.textSecondary) }
            }
            ForEach(payload.topDraggers) { d in
                HStack { Text(d.name).font(.subheadline).foregroundStyle(ColorTokens.textPrimary); Spacer(); Text("\(scoreText(d.score))%").font(.subheadline).foregroundStyle(ColorTokens.textSecondary) }
            }
            if !payload.note.isEmpty { Text(payload.note).font(.caption).foregroundStyle(ColorTokens.textSecondary) }
        }
    }
}

struct CompassActivityResultCard: View {
    let payload: CompassActivityResultPayload
    var body: some View {
        CardShell(title: payload.title, systemImage: "checkmark.seal") {
            Text(payload.scoreLabel).font(.title3.weight(.bold)).foregroundStyle(ColorTokens.textPrimary)
            ForEach(payload.dimensions) { dim in
                HStack { Text(dim.name.capitalized).font(.subheadline).foregroundStyle(ColorTokens.textPrimary); Spacer(); Text(scoreText(dim.score)).font(.subheadline).foregroundStyle(ColorTokens.textSecondary) }
            }
            if let imp = payload.highlights.improvements.first { Text("Improve: \(imp)").font(.caption).foregroundStyle(ColorTokens.textSecondary) }
        }
    }
}

struct CompassTopicDetailCard: View {
    let payload: CompassTopicDetailPayload
    var body: some View {
        CardShell(title: payload.topic.capitalized, systemImage: "chart.line.uptrend.xyaxis") {
            HStack(spacing: 8) {
                Text("\(scoreText(payload.score))%").font(.title3.weight(.bold)).foregroundStyle(ColorTokens.textPrimary)
                if let level = payload.level { Text(level.capitalized).font(.caption).foregroundStyle(ColorTokens.textSecondary) }
                if let trend = payload.trend { Text(trend).font(.caption).foregroundStyle(ColorTokens.textSecondary) }
            }
            ForEach(payload.misconceptions) { m in Text("• \(m.explanation)").font(.caption).foregroundStyle(ColorTokens.textSecondary) }
        }
    }
}

struct CompassWeakTopicsCard: View {
    let topics: [CompassWeakTopic]
    var body: some View {
        CardShell(title: "Weakest topics", systemImage: "exclamationmark.triangle") {
            ForEach(topics) { t in
                Button {
                    NextStepCoordinator.shared.fire(.launchQuiz(topic: t.topic))
                } label: {
                    HStack {
                        Text(t.topic.capitalized).font(.subheadline).foregroundStyle(ColorTokens.textPrimary)
                        Spacer()
                        Text("\(scoreText(t.score))%").font(.subheadline).foregroundStyle(ColorTokens.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CompassRecentActivityCard: View {
    let items: [CompassActivityItem]
    var body: some View {
        CardShell(title: "Recent activity", systemImage: "clock.arrow.circlepath") {
            ForEach(items) { it in
                HStack { Text("\(it.type.capitalized): \(it.title)").font(.subheadline).foregroundStyle(ColorTokens.textPrimary).lineLimit(1); Spacer(); if let s = it.score { Text("\(scoreText(s))").font(.subheadline).foregroundStyle(ColorTokens.textSecondary) } }
            }
        }
    }
}

struct CompassTutoringResultCard: View {
    let payload: CompassTutoringResultPayload
    var body: some View {
        CardShell(title: "Tutoring check \u{00B7} \(payload.topic.capitalized)", systemImage: "graduationcap.fill") {
            if let s = payload.checkScore {
                Text("You scored \(Int(s.rounded()))%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            HStack(spacing: 6) {
                Text("\(payload.topic.capitalized) mastery:")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                if let b = payload.beforeScore {
                    Text("\(Int(b.rounded()))%")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
                if let a = payload.afterScore {
                    Text("\(Int(a.rounded()))%")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                if let d = payload.delta, d != 0 {
                    Text(d > 0 ? "\u{2191}\(Int(d.rounded()))" : "\u{2193}\(Int(abs(d).rounded()))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(d > 0 ? .green : .red)
                }
            }
        }
    }
}

// MARK: - Agent proposal card (agentic layer #2, Compass Actions)

/// Renders a pending AgentDecision as an actionable card: title, summary,
/// consequence, ops as diff rows, and Apply/Dismiss buttons that resolve the
/// decision via POST /v2/agent/decisions/{id}/respond. Collapses into a
/// compact confirmation state on success (or 409 — already resolved).
struct CompassAgentProposalCard: View {
    let payload: CompassAgentProposalPayload

    private enum Resolution { case accepted, rejected }

    @State private var resolution: Resolution?
    /// Non-nil while a respond() call for that response value is in flight.
    @State private var submittingResponse: String?
    @State private var errorMessage: String?

    var body: some View {
        CardShell(title: "Agent proposal", systemImage: "sparkles") {
            if let resolution {
                resolvedRow(resolution)
            } else {
                Text(payload.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                if let summary = payload.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                if let consequence = payload.consequence, !consequence.isEmpty {
                    Text(consequence)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                if !payload.ops.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(payload.ops) { op in diffRow(op) }
                    }
                    .padding(.top, 2)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.error)
                }
                actionButtons
            }
        }
    }

    @ViewBuilder
    private func diffRow(_ op: CompassAgentProposalOp) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\u{2022}").foregroundStyle(ColorTokens.gold)
            Text(diffLabel(op)).font(.caption).foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func diffLabel(_ op: CompassAgentProposalOp) -> String {
        switch op.op {
        case "set_task_status":
            let statusLabel = (op.status ?? "pending").capitalized
            let taskLabel = op.taskId.map { "Task \($0.suffix(6))" } ?? "A task"
            return "\(taskLabel) \u{2192} \(statusLabel)"
        case "reset_skipped":
            return "Restore every skipped task"
        default:
            return op.op.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                // Set the in-flight flag synchronously, before the Task is
                // even scheduled — a fast double-tap can fire this closure
                // twice before an async Task body gets to run, which would
                // otherwise let both taps race past the (now-stale)
                // `submittingResponse == nil` check and POST twice.
                guard submittingResponse == nil else { return }
                submittingResponse = "accepted"
                Task { await respond("accepted") }
            } label: {
                HStack(spacing: 6) {
                    if submittingResponse == "accepted" {
                        ProgressView().tint(ColorTokens.background)
                    }
                    Text("Apply changes")
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .foregroundStyle(ColorTokens.background)
            .background(ColorTokens.gold)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(submittingResponse != nil)

            Button {
                guard submittingResponse == nil else { return }
                submittingResponse = "rejected"
                Task { await respond("rejected") }
            } label: {
                HStack(spacing: 6) {
                    if submittingResponse == "rejected" {
                        ProgressView().tint(ColorTokens.textSecondary)
                    }
                    Text("Dismiss")
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .foregroundStyle(ColorTokens.textSecondary)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ColorTokens.textTertiary.opacity(0.35), lineWidth: 1))
            .disabled(submittingResponse != nil)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func resolvedRow(_ resolution: Resolution) -> some View {
        Text(resolution == .accepted ? "Applied \u{2713}" : "Dismissed")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(resolution == .accepted ? ColorTokens.textPrimary : ColorTokens.textSecondary)
    }

    private struct RespondBody: Codable { let response: String }
    private struct RespondData: Codable { let decisionId: String; let status: String; let applied: Bool }

    private func respond(_ response: String) async {
        // `submittingResponse` is already set by the Button action (before
        // this Task was even scheduled) so double-taps can't race past it.
        errorMessage = nil
        do {
            let _: V2APIResponse<RespondData> = try await V2APIClient.shared.post(
                "/agent/decisions/\(payload.decisionId)/respond",
                body: RespondBody(response: response)
            )
            resolution = response == "accepted" ? .accepted : .rejected
        } catch V2APIError.httpError(let status, _) where status == 409 {
            // Already resolved server-side — treat as success and collapse.
            resolution = response == "accepted" ? .accepted : .rejected
        } catch {
            errorMessage = "Couldn't \(response == "accepted" ? "apply" : "dismiss") — try again."
        }
        submittingResponse = nil
    }
}
