import SwiftUI

struct CalibrationSequenceView: View {
    @State private var session = CalibrationSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if case .inProgress = session.state {
                            Button("Cancel") { dismiss() }
                        } else if case .error = session.state {
                            Button("Close") { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        // Show per-step live timer when in progress; otherwise title
                        if case .inProgress(let stepIndex) = session.state,
                           let drill = session.drills[safe: stepIndex],
                           let startedAt = session.startedAt(stepIndex: stepIndex) {
                            DrillTimerBadge(
                                startedAt: startedAt,
                                totalSeconds: drill.timeBudgetMinutes * 60
                            )
                        } else {
                            Text(navTitle)
                                .font(.headline)
                        }
                    }
                }
        }
        .task {
            if case .loading = session.state {
                await session.start()
            }
        }
        .interactiveDismissDisabled(session.state == .submitting)
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .loading:
            loadingView
        case .inProgress(let stepIndex):
            inProgressView(stepIndex: stepIndex)
        case .submitting:
            DrillSubmittingView()
        case .result(let result):
            CalibrationResultView(result: result) {
                dismiss()
            }
        case .error(let msg):
            errorView(msg)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Setting up your calibration…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inProgressView(stepIndex: Int) -> some View {
        VStack(spacing: 0) {
            CalibrationProgressBar(
                current: stepIndex + 1,
                total: session.drills.count
            )

            calibrationInputAdapter(stepIndex: stepIndex)
        }
    }

    @ViewBuilder
    private func calibrationInputAdapter(stepIndex: Int) -> some View {
        if let drill = session.drills[safe: stepIndex] {
            let context = DrillContext(from: drill)
            let isLast = stepIndex == session.drills.count - 1
            let label = isLast ? "Submit calibration" : "Next →"
            let startedAt = session.startedAt(stepIndex: stepIndex)

            switch drill.drillSubtype {
            case .prompt:
                PromptDrillInputView(
                    context: context,
                    startedAt: startedAt,
                    submitLabel: label,
                    onSubmit: { sub in Task { await session.submitStep(sub) } }
                )
                .id(stepIndex)
            case .verify:
                VerifyDrillInputView(
                    context: context,
                    startedAt: startedAt,
                    submitLabel: label,
                    onSubmit: { sub in Task { await session.submitStep(sub) } }
                )
                .id(stepIndex)
            case .decompose:
                DecomposeDrillInputView(
                    context: context,
                    startedAt: startedAt,
                    submitLabel: label,
                    onSubmit: { sub in Task { await session.submitStep(sub) } }
                )
                .id(stepIndex)
            case .refactor:
                ContentUnavailableView(
                    "Unsupported step",
                    systemImage: "questionmark.circle",
                    description: Text("Refactor drills aren't part of Phase A calibration.")
                )
            }
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Calibration didn't start")
                .font(.headline)
            Text(msg)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var navTitle: String {
        switch session.state {
        case .loading, .submitting: return "Calibration"
        case .inProgress:           return "Calibration"
        case .result:               return "Your baseline"
        case .error:                return ""
        }
    }
}

// MARK: - Safe subscript

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
