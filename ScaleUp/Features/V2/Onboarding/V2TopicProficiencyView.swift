import SwiftUI

/// V2 Topic Proficiency — Step 4 of onboarding (the last step before diagnostic).
///
/// User self-rates each selected topic (novice → expert). On Continue:
///   1. compute required hours via /api/v2/objective/required-time
///   2. save the objective via v1 /onboarding/complete with the COMPUTED hours
///      + topicsOfInterest + topicSelfRatings
///   3. advance the app to the diagnostic
///
/// The Reality Check screen appears AFTER the diagnostic (the computed hours
/// are reviewed there, diagnostic-informed) — not here.
struct V2TopicProficiencyView: View {
    @Environment(V2OnboardingState.self) private var state
    @Environment(AppState.self) private var appState
    @Binding var path: NavigationPath

    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardProgressBar(currentStep: 4, totalSteps: 4)
                    .padding(.bottom, 22)

                Text("How well do you know these?")
                    .font(V2Theme.h1)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Be honest — this tunes your baseline. The diagnostic will check it next.")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                VStack(spacing: 10) {
                    ForEach(state.selectedTopics) { topic in
                        topicRatingCard(topic)
                    }
                }

                if let saveError = saveError {
                    Text(saveError)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.warning)
                        .padding(.top, 14)
                }

                Button {
                    Task { await saveAndAdvance() }
                } label: {
                    HStack {
                        if saving {
                            ProgressView().tint(ColorTokens.background)
                            Text("Setting up your plan…")
                        } else {
                            Text("Continue to assessment")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(allRated ? ColorTokens.gold : ColorTokens.surfaceElevated)
                    .foregroundStyle(allRated ? ColorTokens.background : ColorTokens.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!allRated || saving)
                .padding(.top, 24)

                Text("\(ratedCount) of \(state.selectedTopics.count) rated")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.background.ignoresSafeArea())
    }

    // MARK: - Topic rating card

    private func topicRatingCard(_ topic: V2SuggestedTopic) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(topic.name)
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            HStack(spacing: 6) {
                ForEach(V2Proficiency.allCases, id: \.self) { prof in
                    Button {
                        state.topicProficiency[topic.canonicalName] = prof
                    } label: {
                        Text(prof.label)
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(state.topicProficiency[topic.canonicalName] == prof
                                          ? ColorTokens.gold.opacity(0.18) : ColorTokens.surfaceElevated.opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(state.topicProficiency[topic.canonicalName] == prof
                                                  ? ColorTokens.gold : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(state.topicProficiency[topic.canonicalName] == prof
                                             ? ColorTokens.gold : ColorTokens.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .v2Card(padding: 0)
    }

    // MARK: - Derived

    private var ratedCount: Int {
        state.selectedTopics.filter { state.topicProficiency[$0.canonicalName] != nil }.count
    }
    private var allRated: Bool {
        !state.selectedTopics.isEmpty && ratedCount == state.selectedTopics.count
    }

    // MARK: - Save + advance

    private func saveAndAdvance() async {
        saving = true
        saveError = nil
        defer { saving = false }
        do {
            // 1. Compute required hours (not asked — computed).
            let required = try await V2OnboardingService.shared.computeRequiredTime(for: state)
            let computedHours = required.requiredHoursPerWeek
            state.computedWeeklyHours = computedHours

            // 2. Save the objective with the computed hours + topics + proficiency.
            let resp = try await V2OnboardingService.shared.completeOnboarding(
                state: state,
                weeklyCommitHours: computedHours
            )
            state.savedObjectiveId = resp.userObjectiveId

            // 3. Advance the app to the diagnostic. The post-diagnostic flow
            //    (Reality Check → Calibration) is handled by V2DiagnosticResultsBridge.
            appState.launchState = .diagnostic
        } catch {
            saveError = "Couldn't save your objective. Check your connection and try again."
        }
    }
}
