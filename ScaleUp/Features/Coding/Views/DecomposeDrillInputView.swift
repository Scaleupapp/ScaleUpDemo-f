import SwiftUI

struct DecomposeDrillInputView: View {
    let context: DrillContext
    let startedAt: Date?        // nil = don't show timer
    let submitLabel: String
    let onSubmit: (DrillSubmission) -> Void

    @State private var steps: [DecompositionStep] = []

    // Min 3 (UX nudge); Max 10 (backend Joi max)
    private let minSteps = 3
    private let maxSteps = 10

    private var codeBlocks: [CodeBlock] {
        CodeBlock.parse(from: context.brief)
    }

    private var proseBrief: String {
        CodeBlock.stripCodeBlocks(from: context.brief)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                briefCard
                stepsList

                Color.clear.frame(height: 24) // bottom inset for sticky submit bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            submitBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
        .onAppear {
            if steps.isEmpty {
                steps = [DecompositionStep(step: "", rationale: "")]
            }
        }
    }

    // MARK: - Brief card

    @ViewBuilder
    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("The ticket", systemImage: "ticket")
                .font(.subheadline.weight(.semibold))

            if !proseBrief.isEmpty {
                Text(proseBrief)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !codeBlocks.isEmpty {
                CodeViewer(blocks: codeBlocks)
            } else if proseBrief.isEmpty {
                // Brief has no code blocks and no prose — show raw text
                Text(context.brief)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Steps list

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your decomposition")
                    .font(.headline)
                Spacer()
                Text("\(steps.count) / \(maxSteps)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

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

            if steps.count < maxSteps {
                Button {
                    withAnimation {
                        steps.append(DecompositionStep(step: "", rationale: ""))
                    }
                } label: {
                    Label("Add step", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            } else {
                Text("Max \(maxSteps) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Submit bar

    private var submitBar: some View {
        Button {
            guard canSubmit else { return }
            let normalized = steps.map { step -> DecompositionStep in
                var copy = step
                copy.step = step.step.trimmingCharacters(in: .whitespacesAndNewlines)
                copy.rationale = step.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
                return copy
            }
            onSubmit(.decompose(steps: normalized))
        } label: {
            HStack {
                if canSubmit {
                    Text("\(submitLabel) (\(steps.count) steps)")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                } else {
                    Text(disabledLabel)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.25))
            .foregroundStyle(canSubmit ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        steps.count >= minSteps &&
        steps.count <= maxSteps &&
        steps.allSatisfy { isValid($0) }
    }

    private func isValid(_ s: DecompositionStep) -> Bool {
        let stepText = s.step.trimmingCharacters(in: .whitespacesAndNewlines)
        let rationale = s.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        return !stepText.isEmpty && !rationale.isEmpty
    }

    private var disabledLabel: String {
        if steps.count < minSteps {
            let needed = minSteps - steps.count
            return "Add \(needed) more step\(needed > 1 ? "s" : "")"
        }
        let incomplete = steps.filter { !isValid($0) }.count
        if incomplete > 0 {
            return "Fill in \(incomplete) row\(incomplete > 1 ? "s" : "")"
        }
        return submitLabel
    }
}
