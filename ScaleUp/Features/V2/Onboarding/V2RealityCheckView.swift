import SwiftUI

/// V2 Reality Check — required-time computed (mockup screen 02).
///
/// Calls POST /api/v2/objective/required-time to fetch the honest hours/week
/// for the user's objective + timeline + proficiency.
struct V2RealityCheckView: View {
    @Environment(V2OnboardingState.self) private var state
    @State private var vm = V2RealityCheckViewModel()
    @State private var saving: Bool = false
    @State private var saveError: String?
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardProgressBar(currentStep: 3, totalSteps: 4)
                    .padding(.bottom, 22)

                Text("Reality check".uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.bottom, 10)

                Text("Here's what it actually takes")
                    .font(V2Theme.h1)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.bottom, 14)

                if let label = vm.data?.baselineLabel {
                    Text("For ")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                    + Text(label).font(V2Theme.bodyMedium).foregroundStyle(ColorTokens.gold)
                    + Text(", based on your inputs:").font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
                } else if vm.isLoading {
                    Text("Computing your honest baseline…")
                        .font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
                }

                if vm.isLoading && vm.data == nil {
                    loadingCard
                        .padding(.vertical, 22)
                } else if let data = vm.data {
                    bigNumberCard(data: data)
                        .padding(.vertical, 22)
                } else {
                    errorCard
                        .padding(.vertical, 22)
                }

                Text("We don't pretend the impossible is possible. Choose honestly:")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.bottom, 14)

                if let data = vm.data {
                    pathCard(
                        color: ColorTokens.success,
                        badge: "✓",
                        title: "I can commit to \(data.paths.commit.hoursPerWeek) hrs/week",
                        sub: data.paths.commit.label,
                        isPrimary: true
                    ) {
                        Task { await pickPathAndSave(hours: data.paths.commit.hoursPerWeek) }
                    }
                    pathCard(
                        color: ColorTokens.warning,
                        badge: "⚠",
                        title: "I can do less — adjust",
                        sub: data.paths.lessTime.timelineLabel
                    ) {
                        Task { await pickPathAndSave(hours: data.paths.lessTime.hoursPerWeek) }
                    }
                    pathCard(
                        color: ColorTokens.gold,
                        badge: "↑",
                        title: "I can do more — faster path",
                        sub: data.paths.moreTime.timelineLabel
                    ) {
                        Task { await pickPathAndSave(hours: data.paths.moreTime.hoursPerWeek) }
                    }
                    if !data.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(data.warnings, id: \.self) { w in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(ColorTokens.warning)
                                    Text(w).font(V2Theme.small)
                                        .foregroundStyle(ColorTokens.warning)
                                }
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.warning.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ColorTokens.warning.opacity(0.25), lineWidth: 1))
                        .padding(.top, 14)
                    }
                }

                Text("No silent acceptance of unrealistic combinations.\nYou always see the tradeoff.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .overlay {
            if saving {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().tint(ColorTokens.gold)
                        Text("Saving your plan…")
                            .font(V2Theme.body)
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(RoundedRectangle(cornerRadius: 16).fill(ColorTokens.surface))
                }
            }
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .task {
            // Call the v2 required-time endpoint with the user's specific objective
            // captured in V2OnboardingState — falls back to defaults if not yet set.
            let req = state.requiredTimeBody()
            await vm.load(
                objectiveType: req.objectiveType,
                specifics: req.specifics,
                timeline: req.timeline,
                currentLevel: req.currentLevel
            )
        }
        .refreshable {
            let req = state.requiredTimeBody()
            await vm.load(
                objectiveType: req.objectiveType,
                specifics: req.specifics,
                timeline: req.timeline,
                currentLevel: req.currentLevel
            )
        }
    }

    /// User picked a commitment path → save the objective to v1 → route to insights.
    /// On save failure we keep them on this screen with an alert and retry chance.
    @MainActor
    private func pickPathAndSave(hours: Int) async {
        state.chosenWeeklyHours = hours
        saving = true
        defer { saving = false }
        let body = state.objectiveSaveBody(weeklyCommitHours: hours)
        do {
            let id = try await V2ObjectiveSaveService.shared.saveObjective(body: body)
            state.savedObjectiveId = id
            path.append(V2OnboardingRoute.calibrationInsights)
        } catch {
            saveError = "We couldn't save your goal. Check your connection and try again."
        }
    }

    private func bigNumberCard(data: V2RequiredTimeResponse) -> some View {
        VStack(spacing: 8) {
            Text("You'll need to invest".uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(1)
                .foregroundStyle(ColorTokens.textTertiary)
            Text("\(data.requiredHoursPerWeek)")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(ColorTokens.gold)
            Text("hours per week")
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("≈ \(String(format: "%.1f", data.requiredHoursPerDay)) hours / day if studying daily")
                .font(V2Theme.small).foregroundStyle(ColorTokens.textTertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(V2Theme.heroGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1)
        )
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(ColorTokens.gold)
            Text("Working out your honest hours…")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(V2Theme.heroGradient)
        )
    }

    private var errorCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24)).foregroundStyle(ColorTokens.warning)
            Text(vm.error ?? "Computation failed.")
                .font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.load() } }
                .buttonStyle(.bordered).tint(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 20).fill(ColorTokens.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
    }

    private func pathCard(color: Color, badge: String, title: String, sub: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(badge)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(V2Theme.h3)
                        .foregroundStyle(isPrimary ? color : ColorTokens.textPrimary)
                    Text(sub)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .fill(isPrimary ? color.opacity(0.06) : ColorTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .strokeBorder(isPrimary ? color : V2Theme.cardBorder, lineWidth: isPrimary ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }
}

#Preview {
    NavigationStack {
        V2RealityCheckView(path: .constant(NavigationPath()))
    }
    .preferredColorScheme(.dark)
}
