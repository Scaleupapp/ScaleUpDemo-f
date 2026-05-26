import SwiftUI

struct CalibrationSequenceView: View {
    @State private var session = CalibrationSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if case .inProgress = session.state {
                            Button("Cancel") {
                                dismiss()
                            }
                        } else if case .error = session.state {
                            Button("Close") {
                                dismiss()
                            }
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
            CalibrationStepWrapper(
                drill: drill,
                onSubmit: { submission in
                    Task { await session.submitStep(submission) }
                }
            )
            .id(stepIndex)  // forces fresh state per step
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
        case .inProgress: return "Calibration"
        case .result: return "Your baseline"
        case .error: return ""
        }
    }
}

// MARK: - Safe subscript

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Step wrapper (routes to per-subtype step view)

private struct CalibrationStepWrapper: View {
    let drill: CalibrationDrill
    let onSubmit: (DrillSubmission) -> Void

    var body: some View {
        switch drill.drillSubtype {
        case .prompt:
            CalibrationPromptStep(drill: drill, onSubmit: onSubmit)
        case .verify:
            CalibrationVerifyStep(drill: drill, onSubmit: onSubmit)
        case .decompose:
            CalibrationDecomposeStep(drill: drill, onSubmit: onSubmit)
        case .refactor:
            // Should not happen — backend filters refactor from Phase A calibration
            ContentUnavailableView(
                "Unsupported step",
                systemImage: "questionmark.circle",
                description: Text("Refactor drills aren't part of Phase A calibration.")
            )
        }
    }
}

// MARK: - Prompt step

private struct CalibrationPromptStep: View {
    let drill: CalibrationDrill
    let onSubmit: (DrillSubmission) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    private let minChars = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                briefCard
                editor
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            submitBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
    }

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Prompt drill", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Text(drill.brief).font(.subheadline)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your prompt").font(.headline)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .focused($focused)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 180)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.2)))
        }
    }

    private var submitBar: some View {
        Button {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= minChars else { return }
            focused = false
            onSubmit(.prompt(text: trimmed))
        } label: {
            Text(canSubmit ? "Next" : "Write at least \(minChars) characters")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.25))
                .foregroundStyle(canSubmit ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minChars
    }
}

// MARK: - Verify step

private struct CalibrationVerifyStep: View {
    let drill: CalibrationDrill
    let onSubmit: (DrillSubmission) -> Void
    @State private var locations: [BugLocation] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                briefCard
                bugsList
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            submitBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
    }

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Bug hunt", systemImage: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(drill.brief)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.vertical, 2)
            }
            .frame(maxHeight: 220)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var bugsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bugs you found").font(.headline)
            ForEach($locations) { $loc in
                if let idx = locations.firstIndex(where: { $0.id == loc.id }) {
                    BugLocationRow(location: $loc, index: idx) {
                        withAnimation {
                            locations.removeAll { $0.id == loc.id }
                        }
                    }
                }
            }
            Button {
                withAnimation {
                    locations.append(BugLocation(file: "", line: 1, explanation: ""))
                }
            } label: {
                Label("Add a bug location", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var submitBar: some View {
        Button {
            guard canSubmit else { return }
            let normalized = locations.map { loc -> BugLocation in
                var copy = loc
                copy.file = loc.file.trimmingCharacters(in: .whitespaces)
                copy.explanation = loc.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
                return copy
            }
            onSubmit(.verify(bugLocations: normalized))
        } label: {
            Text(canSubmit ? "Next" : "Add at least one bug")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.25))
                .foregroundStyle(canSubmit ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        !locations.isEmpty && locations.allSatisfy {
            !$0.file.trimmingCharacters(in: .whitespaces).isEmpty &&
            $0.line > 0 &&
            $0.explanation.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
        }
    }
}

// MARK: - Decompose step

private struct CalibrationDecomposeStep: View {
    let drill: CalibrationDrill
    let onSubmit: (DrillSubmission) -> Void
    @State private var steps: [DecompositionStep] = [
        DecompositionStep(step: "", rationale: "")
    ]

    private let minSteps = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                briefCard
                stepsList
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            submitBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
    }

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Decompose", systemImage: "list.number")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Text(drill.brief).font(.subheadline)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your decomposition").font(.headline)
                Spacer()
                Text("\(steps.count) steps")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // Use ForEach($steps) + firstIndex pattern — matches UI-B5 pattern
            ForEach($steps) { $step in
                if let idx = steps.firstIndex(where: { $0.id == step.id }) {
                    DecompositionStepRow(
                        step: $step,
                        index: idx,
                        onDelete: {
                            withAnimation {
                                steps.removeAll { $0.id == step.id }
                            }
                        },
                        canDelete: steps.count > 1
                    )
                }
            }
            Button {
                withAnimation {
                    steps.append(DecompositionStep(step: "", rationale: ""))
                }
            } label: {
                Label("Add step", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var submitBar: some View {
        Button {
            guard canSubmit else { return }
            let normalized = steps.map { s -> DecompositionStep in
                var copy = s
                copy.step = s.step.trimmingCharacters(in: .whitespacesAndNewlines)
                copy.rationale = s.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
                return copy
            }
            onSubmit(.decompose(steps: normalized))
        } label: {
            Text(submitLabel)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.25))
                .foregroundStyle(canSubmit ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        steps.count >= minSteps && steps.allSatisfy {
            !$0.step.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var submitLabel: String {
        if steps.count < minSteps {
            let needed = minSteps - steps.count
            return "Add \(needed) more step\(needed > 1 ? "s" : "")"
        }
        let incomplete = steps.filter {
            $0.step.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            $0.rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        if incomplete > 0 {
            return "Fill in \(incomplete) row\(incomplete > 1 ? "s" : "")"
        }
        return "Submit calibration"
    }
}
