import SwiftUI

/// Structured manual objective picker — the safety-net fallback.
///
/// Reached from the confirmation gate via "Let me fix it" (green/long-tail)
/// or "Pick from what we cover" (rejected). Lets the user pick an objective
/// type and a catalog-backed target with a typeahead — deterministic, no NLU.
struct V2ManualObjectivePicker: View {
    @Environment(V2OnboardingState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Binding var path: NavigationPath

    @State private var selectedType: V2ObjectiveType = .interviewPreparation
    @State private var query: String = ""
    @State private var results: [V2CatalogEntry] = []
    @State private var picked: V2CatalogEntry?
    @State private var company: String = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Pick your objective")
                        .font(V2Theme.h2)
                        .foregroundStyle(ColorTokens.textPrimary)

                    // Objective type
                    field("I'm working toward") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(V2ObjectiveType.allCases, id: \.self) { t in
                                    Button {
                                        selectedType = t
                                        picked = nil
                                        results = []
                                        query = ""
                                    } label: {
                                        Text(t.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(Capsule().fill(selectedType == t ? ColorTokens.gold.opacity(0.15) : ColorTokens.surface))
                                            .overlay(Capsule().strokeBorder(selectedType == t ? ColorTokens.gold : V2Theme.cardBorder, lineWidth: 1))
                                            .foregroundStyle(selectedType == t ? ColorTokens.gold : ColorTokens.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Catalog typeahead for the target
                    field(targetLabel) {
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.textTertiary)
                                TextField(targetPlaceholder, text: $query)
                                    .font(V2Theme.body)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .autocorrectionDisabled()
                                    .onChange(of: query) { _, q in scheduleSearch(q) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surface))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))

                            if !results.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(results) { entry in
                                        Button {
                                            picked = entry
                                            query = entry.name
                                            results = []
                                        } label: {
                                            HStack {
                                                Text(entry.name).font(V2Theme.body).foregroundStyle(ColorTokens.textPrimary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surface))
                                .padding(.top, 6)
                            }
                        }
                    }

                    // Company (optional) — only for interview prep
                    if selectedType == .interviewPreparation {
                        field("Target company (optional)") {
                            TextField("e.g. Google", text: $company)
                                .font(V2Theme.body)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surface))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                        }
                    }

                    Button {
                        applyAndContinue()
                    } label: {
                        Text("Use this objective")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(canContinue ? ColorTokens.gold : ColorTokens.surfaceElevated)
                            .foregroundStyle(canContinue ? ColorTokens.background : ColorTokens.textTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)
                }
                .padding(V2Theme.pad)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    private var canContinue: Bool {
        picked != nil || !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var targetLabel: String {
        switch selectedType {
        case .interviewPreparation, .careerSwitch: return "Target role"
        case .competitiveExam:                     return "Which exam"
        case .upskilling:                          return "Which skill"
        case .academicExcellence:                  return "Course / subject"
        }
    }
    private var targetPlaceholder: String {
        switch selectedType {
        case .interviewPreparation, .careerSwitch: return "Search roles…"
        case .competitiveExam:                     return "Search exams…"
        case .upskilling:                          return "Search skills…"
        case .academicExcellence:                  return "Type your course…"
        }
    }
    private var catalogTypeFilter: String {
        switch selectedType {
        case .interviewPreparation, .careerSwitch: return "role"
        case .competitiveExam:                     return "exam"
        case .upskilling:                          return "skill"
        case .academicExcellence:                  return "college_prep"
        }
    }

    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            let r = (try? await V2OnboardingService.shared.suggest(query: trimmed, type: catalogTypeFilter, limit: 8)) ?? []
            if !Task.isCancelled { await MainActor.run { results = r } }
        }
    }

    private func applyAndContinue() {
        // Clear any prior NLU-derived specifics, then set from the manual pick.
        state.objectiveType = selectedType
        state.targetRole = ""; state.targetCompany = ""; state.examName = ""
        state.targetSkill = ""; state.fromDomain = ""; state.toDomain = ""

        let value = picked?.name ?? query.trimmingCharacters(in: .whitespaces)
        switch selectedType {
        case .interviewPreparation:
            state.targetRole = value
            state.targetCompany = company.trimmingCharacters(in: .whitespaces)
        case .careerSwitch:
            state.toDomain = value
        case .competitiveExam:
            state.examName = value
        case .upskilling:
            state.targetSkill = value
        case .academicExcellence:
            state.targetSkill = value
        }
        // Manual pick is treated as a confirmed green objective.
        state.parseResult = nil
        dismiss()
        path.append(V2OnboardingRoute.topicSelection)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
            content()
        }
    }
}
