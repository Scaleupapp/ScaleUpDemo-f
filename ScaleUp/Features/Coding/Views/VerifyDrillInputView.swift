import SwiftUI

struct VerifyDrillInputView: View {
    let context: DrillContext
    let startedAt: Date?        // nil = don't show timer
    let submitLabel: String
    let onSubmit: (DrillSubmission) -> Void

    @State private var locations: [BugLocation] = []

    // Min explanation chars matches backend Joi validator (5)
    private let minExplanationChars = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                codeSection
                locationsList

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
    }

    // MARK: - Code section

    private var codeSection: some View {
        BriefCard(
            label: "Review this code",
            systemImage: "doc.text.magnifyingglass",
            brief: context.brief,
            style: .collapsible(defaultExpanded: true)
        )
    }

    // MARK: - Bug locations list

    private var locationsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bugs you found")
                    .font(.headline)
                Spacer()
                Text("\(locations.count) \(locations.count == 1 ? "bug" : "bugs")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if locations.isEmpty {
                emptyStateCard
            } else {
                ForEach($locations) { $location in
                    if let index = locations.firstIndex(where: { $0.id == location.id }) {
                        BugLocationRow(location: $location, index: index) {
                            withAnimation {
                                locations.removeAll { $0.id == location.id }
                            }
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
            .controlSize(.regular)
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No bugs marked yet")
                .font(.subheadline.weight(.medium))
            Text("Spot a bug? Tap below to add a location.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Submit bar

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
            HStack {
                if canSubmit {
                    Text("\(submitLabel) (\(locations.count) \(locations.count == 1 ? "bug" : "bugs"))")
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
        !locations.isEmpty && locations.allSatisfy { isValid($0) }
    }

    private func isValid(_ loc: BugLocation) -> Bool {
        let file = loc.file.trimmingCharacters(in: .whitespaces)
        let explanation = loc.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        return !file.isEmpty && loc.line > 0 && explanation.count >= minExplanationChars
    }

    private var disabledLabel: String {
        if locations.isEmpty { return "Add at least one bug location" }
        let incomplete = locations.filter { !isValid($0) }.count
        if incomplete > 0 {
            return "Fill in \(incomplete) row\(incomplete > 1 ? "s" : "")"
        }
        return submitLabel
    }
}
