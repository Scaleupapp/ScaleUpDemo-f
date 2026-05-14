import SwiftUI

/// V2 Objective Setup — Step 1 of onboarding.
///
/// Free-text entry + live catalog typeahead. On Continue, the text goes to
/// the v2 NLU parser (/api/v2/objective/parse) and the result routes to the
/// confirmation gate. Nothing is hardcoded — popular goals + suggestions all
/// come from the ObjectiveCatalog.
struct V2ObjectiveSetupView: View {
    @Environment(V2OnboardingState.self) private var state
    @Binding var path: NavigationPath

    @State private var goalText: String = ""
    @State private var suggestions: [V2CatalogEntry] = []
    @State private var popular: [V2CatalogEntry] = []
    @State private var isParsing = false
    @State private var parseError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardProgressBar(currentStep: 1, totalSteps: 4)
                    .padding(.bottom, 22)

                Text("What's your goal?")
                    .font(V2Theme.h1)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Tell us in your own words — a role, an exam, a skill. We'll figure out the rest.")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                // Free-text input
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ColorTokens.textTertiary)
                    TextField("e.g. SDE placement at Google", text: $goalText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { Task { await parseAndContinue() } }
                        .onChange(of: goalText) { _, newValue in
                            scheduleSearch(newValue)
                        }
                    if !goalText.isEmpty {
                        Button { goalText = ""; suggestions = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(ColorTokens.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ColorTokens.surfaceElevated, lineWidth: 1.5))

                // Live typeahead suggestions
                if !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions) { entry in
                            Button {
                                goalText = entry.name
                                suggestions = []
                            } label: {
                                HStack {
                                    Text(catalogIcon(entry.type))
                                    Text(entry.name)
                                        .font(V2Theme.body)
                                        .foregroundStyle(ColorTokens.textPrimary)
                                    Spacer()
                                    Text(entry.type.capitalized)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            if entry.id != suggestions.last?.id {
                                Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorTokens.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                    .padding(.top, 8)
                }

                Text("Try: \"crack CAT 2026\" · \"switch from service to product\" · \"master AI/ML\"")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                // Popular goals — from the catalog, not hardcoded
                if !popular.isEmpty && suggestions.isEmpty {
                    Text("Popular goals".uppercased())
                        .font(.system(size: 10, weight: .semibold)).tracking(1)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.bottom, 10)

                    VStack(spacing: 8) {
                        ForEach(popular) { entry in
                            Button {
                                goalText = entry.name
                            } label: {
                                HStack {
                                    Text(catalogIcon(entry.type))
                                    Text(entry.name)
                                        .font(V2Theme.body)
                                        .foregroundStyle(ColorTokens.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 11))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .v2Card(padding: 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 24)
                }

                if let parseError = parseError {
                    Text(parseError)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.warning)
                        .padding(.bottom, 12)
                }

                Button {
                    Task { await parseAndContinue() }
                } label: {
                    HStack {
                        if isParsing {
                            ProgressView().tint(ColorTokens.background)
                        } else {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(goalText.trimmingCharacters(in: .whitespaces).isEmpty ? ColorTokens.surfaceElevated : ColorTokens.gold)
                    .foregroundStyle(goalText.trimmingCharacters(in: .whitespaces).isEmpty ? ColorTokens.textTertiary : ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(goalText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task {
            // Load popular goals from the catalog (no hardcoding).
            popular = (try? await V2OnboardingService.shared.popular(limit: 6)) ?? []
        }
    }

    // MARK: - Typeahead (debounced)

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { suggestions = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            let results = (try? await V2OnboardingService.shared.suggest(query: q, limit: 8)) ?? []
            if !Task.isCancelled {
                await MainActor.run { suggestions = results }
            }
        }
    }

    // MARK: - Parse + route

    private func parseAndContinue() async {
        let text = goalText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isParsing = true
        parseError = nil
        defer { isParsing = false }
        do {
            let result = try await V2OnboardingService.shared.parseObjective(text)
            state.rawGoalText = text
            state.applyParse(result)
            path.append(V2OnboardingRoute.confirm)
        } catch {
            parseError = "Couldn't process that. Check your connection and try again."
        }
    }

    private func catalogIcon(_ type: String) -> String {
        switch type {
        case "role": return "💼"
        case "exam": return "📝"
        case "skill": return "⚡"
        case "company": return "🏢"
        case "college_prep": return "🎓"
        default: return "🎯"
        }
    }
}

// MARK: - Onboarding routes + progress bar

enum V2OnboardingRoute: Hashable {
    case confirm
    case topicSelection
    case topicProficiency
}

struct OnboardProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                Capsule()
                    .fill(idx < currentStep ? ColorTokens.gold
                          : (idx == currentStep ? ColorTokens.gold.opacity(0.5) : ColorTokens.surfaceElevated))
                    .frame(height: 3)
            }
        }
    }
}
