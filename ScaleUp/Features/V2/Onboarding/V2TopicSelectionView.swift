import SwiftUI

/// V2 Topic Selection — Step 3 of onboarding.
///
/// Fetches the suggested topic list for the objective (v1
/// /onboarding/topics/suggest, LLM-backed + cached in TopicTaxonomy) and lets
/// the user add / remove topics before committing. The GenAI topic the
/// backend injects is marked and pinned (can't be removed — it's universal).
struct V2TopicSelectionView: View {
    @Environment(V2OnboardingState.self) private var state
    @Binding var path: NavigationPath

    @State private var isLoading = true
    @State private var error: String?
    @State private var newTopic: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardProgressBar(currentStep: 3, totalSteps: 4)
                    .padding(.bottom, 22)

                Text("Your topics")
                    .font(V2Theme.h1)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("These are the topics we'll build your plan around. Add or remove anything — it's your roadmap.")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                if isLoading {
                    loadingState
                } else if let error = error {
                    errorState(error)
                } else {
                    topicList
                    addTopicField
                        .padding(.top, 16)

                    Button {
                        path.append(V2OnboardingRoute.topicProficiency)
                    } label: {
                        HStack {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(state.selectedTopics.isEmpty ? ColorTokens.surfaceElevated : ColorTokens.gold)
                        .foregroundStyle(state.selectedTopics.isEmpty ? ColorTokens.textTertiary : ColorTokens.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.selectedTopics.isEmpty)
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .task { await loadTopics() }
    }

    // MARK: - Topic list

    private var topicList: some View {
        VStack(spacing: 8) {
            ForEach(state.selectedTopics) { topic in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(topic.name)
                                .font(V2Theme.bodyMedium)
                                .foregroundStyle(ColorTokens.textPrimary)
                            if topic.isGenAITopic == true {
                                Text("FUTURE-READY")
                                    .font(.system(size: 8, weight: .bold)).tracking(0.6)
                                    .foregroundStyle(ColorTokens.gold)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(ColorTokens.gold.opacity(0.15)))
                            }
                            if topic.userAdded == true {
                                Text("ADDED")
                                    .font(.system(size: 8, weight: .bold)).tracking(0.6)
                                    .foregroundStyle(ColorTokens.success)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(ColorTokens.success.opacity(0.15)))
                            }
                        }
                        Text(topic.description)
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .lineLimit(2)
                    }
                    Spacer()
                    // GenAI topic is universal — can't remove it.
                    if topic.isGenAITopic == true {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                    } else {
                        Button {
                            removeTopic(topic)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .v2Card(padding: 0)
            }
        }
    }

    private var addTopicField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .foregroundStyle(ColorTokens.gold)
            TextField("Add a topic of your own…", text: $newTopic)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { addCustomTopic() }
            if !newTopic.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add") { addCustomTopic() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(ColorTokens.gold)
            Text("Building your topic list…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28)).foregroundStyle(ColorTokens.warning)
            Text(msg)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await loadTopics() } }
                .buttonStyle(.bordered)
                .tint(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Logic

    private func loadTopics() async {
        // If we've already loaded (e.g. user came back), don't refetch.
        if !state.selectedTopics.isEmpty {
            isLoading = false
            return
        }
        isLoading = true
        error = nil
        do {
            let resp = try await V2OnboardingService.shared.suggestTopics(for: state)
            state.suggestedTopics = resp.topics
            state.selectedTopics = resp.topics
        } catch {
            self.error = "Couldn't load topics for this objective. Check your connection."
        }
        isLoading = false
    }

    private func removeTopic(_ topic: V2SuggestedTopic) {
        state.selectedTopics.removeAll { $0.canonicalName == topic.canonicalName }
        state.topicProficiency[topic.canonicalName] = nil
    }

    private func addCustomTopic() {
        let name = newTopic.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let canonical = name.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        // Avoid duplicates
        guard !state.selectedTopics.contains(where: { $0.canonicalName == canonical }) else {
            newTopic = ""
            return
        }
        let topic = V2SuggestedTopic(
            name: name,
            canonicalName: canonical,
            description: "Added by you",
            baseDifficulty: "intermediate",
            isFutureProofing: false,
            sortOrder: (state.selectedTopics.map { $0.sortOrder ?? 0 }.max() ?? 0) + 1,
            isGenAITopic: false,
            userAdded: true
        )
        state.selectedTopics.append(topic)
        newTopic = ""
    }
}
