import SwiftUI

/// Placement-context drill take screen.
///
/// Shown after POST /me/assessments/:id/start returns engine.type == "drill".
/// The backend has already created the DrillAttempt (status in_progress).
/// We drive THAT attempt (engine.sessionId) — we do NOT start a new one.
/// Submit: POST /api/coding/drills/:attemptId/submit
/// Poll:   GET  /api/coding/drills/:attemptId/result
///
/// Approach: thin PlacementDrillTakeView wrapper reusing
/// PromptDrillInputView / VerifyDrillInputView / DecomposeDrillInputView
/// (identical to how PlacementCapstonePairView reuses CapstonePairingCodePanel).
struct PlacementDrillTakeView: View {
    let start: AssessmentStartResult
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: PlacementDrillPhase = .brief
    @State private var startedAt: Date?

    private let api = PlacementsAssessmentsApi.shared

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(navTitle)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if case .result = phase {
                            EmptyView()
                        } else {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .brief:
            briefView
        case .input:
            inputView
        case .submitting:
            DrillSubmittingView()
        case .result(let grade):
            DrillResultView(grade: grade) {
                onComplete()
                dismiss()
            }
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - Brief

    private var briefView: some View {
        let meta = start.meta
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Badge row
                HStack(spacing: 8) {
                    if let subtypeRaw = meta?.drillSubtype,
                       let subtype = DrillSubtype(rawValue: subtypeRaw) {
                        Label(subtype.displayName, systemImage: subtype.iconName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    if let minutes = meta?.timeBudgetMinutes {
                        Label("\(minutes) min", systemImage: "clock")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    Label("Placement", systemImage: "building.2")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                        .foregroundStyle(.orange)
                }

                if let brief = meta?.brief, !brief.isEmpty {
                    let codeBlocks = CodeBlock.parse(from: brief)
                    let prose = CodeBlock.stripCodeBlocks(from: brief)
                    if !prose.isEmpty {
                        Text(prose)
                            .font(.body)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !codeBlocks.isEmpty {
                        CodeViewer(blocks: codeBlocks)
                    } else if prose.isEmpty {
                        Text(brief)
                            .font(.body)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let criteria = meta?.acceptanceCriteria, !criteria.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What we're looking for")
                            .font(.headline)
                        ForEach(criteria, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.tint)
                                Text(item)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                startedAt = Date()
                phase = .input
            }) {
                HStack(spacing: 8) {
                    Text("Start")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    // MARK: - Input

    @ViewBuilder
    private var inputView: some View {
        let meta = start.meta
        let subtype = meta?.drillSubtype.flatMap { DrillSubtype(rawValue: $0) } ?? .prompt
        let ctx = DrillContext(
            brief: meta?.brief ?? "",
            drillSubtype: subtype,
            language: nil,
            timeBudgetMinutes: meta?.timeBudgetMinutes ?? 15,
            acceptanceCriteria: meta?.acceptanceCriteria
        )

        switch subtype {
        case .prompt:
            PromptDrillInputView(
                context: ctx,
                startedAt: startedAt,
                submitLabel: "Submit for grading",
                onSubmit: { sub in Task { await submitDrill(sub, subtype: subtype) } }
            )
        case .verify:
            VerifyDrillInputView(
                context: ctx,
                startedAt: startedAt,
                submitLabel: "Submit for grading",
                onSubmit: { sub in Task { await submitDrill(sub, subtype: subtype) } }
            )
        case .decompose:
            DecomposeDrillInputView(
                context: ctx,
                startedAt: startedAt,
                submitLabel: "Submit for grading",
                onSubmit: { sub in Task { await submitDrill(sub, subtype: subtype) } }
            )
        case .refactor:
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Unsupported drill type")
                    .font(.headline)
                Text("Refactor drills are not supported in this version.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Nav title

    private var navTitle: String {
        switch phase {
        case .brief:      return "Drill Assessment"
        case .input:      return start.meta?.drillSubtype.flatMap { DrillSubtype(rawValue: $0) }?.displayName ?? "Drill"
        case .submitting: return "Grading"
        case .result:     return "Drill Result"
        case .error:      return "Error"
        }
    }

    // MARK: - Submit + Poll

    private func submitDrill(_ submission: DrillSubmission, subtype: DrillSubtype) async {
        guard let attemptId = start.engine.sessionId else {
            phase = .error("No attempt ID — cannot submit.")
            return
        }

        phase = .submitting

        let body = DrillSubmitBody(drillSubtype: subtype, submission: submission)
        do {
            _ = try await api.submitPlacementDrill(attemptId: attemptId, body: body)
        } catch {
            phase = .error("Failed to submit: \(error.localizedDescription)")
            return
        }

        // Poll for result every 2 s, up to 30 s (15 attempts)
        for attempt in 0..<15 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            do {
                let result = try await api.pollPlacementDrillResult(attemptId: attemptId)
                switch result {
                case .graded(let graded):
                    phase = .result(graded)
                    return
                case .pending:
                    continue
                }
            } catch {
                if attempt == 14 {
                    phase = .error("Grading is taking longer than expected.")
                    return
                }
            }
        }
        phase = .error("Grading timed out. Please check back later.")
    }
}

// MARK: - Phase enum

private enum PlacementDrillPhase {
    case brief
    case input
    case submitting
    case result(DrillResultGradedResponse)
    case error(String)
}
