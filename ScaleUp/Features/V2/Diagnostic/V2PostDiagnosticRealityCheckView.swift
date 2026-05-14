import SwiftUI

/// V2 Reality Check — shown AFTER the diagnostic.
///
/// The objective was already saved (during onboarding) with a COMPUTED weekly
/// commitment. This screen reviews that number — now diagnostic-informed — and
/// lets the user adjust it before the plan generates. On continue, routes to
/// the Calibration insights screen.
///
/// Self-contained: fetches the user's primary objective (V2OnboardingState is
/// gone by this point — different view tree).
struct V2PostDiagnosticRealityCheckView: View {
    /// The diagnostic attempt — needed to trigger plan generation (the v2 order
    /// is Diagnostic → Reality Check → Plan Creation, so plan gen fires HERE).
    let attemptId: String
    let onContinue: () -> Void

    @State private var objective: V2ActiveObjective?
    @State private var required: V2RequiredTimeResponse?
    @State private var chosenHours: Int?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Reality check".uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.bottom, 10)

                Text("Here's what it'll take")
                    .font(V2Theme.h1)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.bottom, 14)

                if isLoading {
                    loadingCard.padding(.vertical, 22)
                } else if let required = required {
                    loadedContent(required)
                } else {
                    errorCard.padding(.vertical, 22)
                }
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .task { await load() }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ required: V2RequiredTimeResponse) -> some View {
        Text("Based on your goal, timeline, and your diagnostic — here's the honest weekly commitment for ")
            .font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
        + Text(required.baselineLabel).font(V2Theme.bodyMedium).foregroundStyle(ColorTokens.gold)
        + Text(":").font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)

        // Big computed number
        VStack(spacing: 8) {
            Text("We've set your commitment at".uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(1)
                .foregroundStyle(ColorTokens.textTertiary)
            Text("\(chosenHours ?? required.requiredHoursPerWeek)")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(ColorTokens.gold)
            Text("hours per week")
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("≈ \(dayString(chosenHours ?? required.requiredHoursPerWeek)) hours / day")
                .font(V2Theme.small).foregroundStyle(ColorTokens.textTertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(V2Theme.heroGradient))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1))
        .padding(.vertical, 22)

        if !required.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(required.warnings, id: \.self) { w in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11)).foregroundStyle(ColorTokens.warning)
                        Text(w).font(V2Theme.small).foregroundStyle(ColorTokens.warning)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.warning.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ColorTokens.warning.opacity(0.25), lineWidth: 1))
            .padding(.bottom, 18)
        }

        Text("Can you commit to this?")
            .font(V2Theme.h3)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.bottom, 12)

        // Keep (the computed default)
        pathCard(color: ColorTokens.success, badge: "✓",
                 title: "Yes — \(required.requiredHoursPerWeek) hrs/week works",
                 sub: required.paths.commit.label,
                 isPrimary: chosenHours == nil || chosenHours == required.requiredHoursPerWeek) {
            chosenHours = required.requiredHoursPerWeek
        }
        // Less
        pathCard(color: ColorTokens.warning, badge: "⚠",
                 title: "I can do less — \(required.paths.lessTime.hoursPerWeek) hrs/week",
                 sub: required.paths.lessTime.timelineLabel,
                 isPrimary: chosenHours == required.paths.lessTime.hoursPerWeek) {
            chosenHours = required.paths.lessTime.hoursPerWeek
        }
        // More
        pathCard(color: ColorTokens.gold, badge: "↑",
                 title: "I can do more — \(required.paths.moreTime.hoursPerWeek) hrs/week",
                 sub: required.paths.moreTime.timelineLabel,
                 isPrimary: chosenHours == required.paths.moreTime.hoursPerWeek) {
            chosenHours = required.paths.moreTime.hoursPerWeek
        }

        if let error = error {
            Text(error).font(V2Theme.small).foregroundStyle(ColorTokens.warning).padding(.top, 8)
        }

        Button {
            Task { await confirmAndContinue() }
        } label: {
            HStack {
                if isSaving { ProgressView().tint(ColorTokens.background) }
                else { Text("Continue") }
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(ColorTokens.gold)
            .foregroundStyle(ColorTokens.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .padding(.top, 18)
    }

    // MARK: - States

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(ColorTokens.gold)
            Text("Working out your honest hours…")
                .font(V2Theme.small).foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(40)
        .background(RoundedRectangle(cornerRadius: 20).fill(V2Theme.heroGradient))
    }

    private var errorCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24)).foregroundStyle(ColorTokens.warning)
            Text(error ?? "Couldn't compute your hours.")
                .font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.bordered).tint(ColorTokens.gold)
                Button("Skip for now") { onContinue() }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .frame(maxWidth: .infinity).padding(28)
        .background(RoundedRectangle(cornerRadius: 20).fill(ColorTokens.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
    }

    private func pathCard(color: Color, badge: String, title: String, sub: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(badge).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(V2Theme.h3)
                        .foregroundStyle(isPrimary ? color : ColorTokens.textPrimary)
                    Text(sub).font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .fill(isPrimary ? color.opacity(0.06) : ColorTokens.surface))
            .overlay(RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                .strokeBorder(isPrimary ? color : V2Theme.cardBorder, lineWidth: isPrimary ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }

    // MARK: - Logic

    private func load() async {
        isLoading = true
        error = nil
        do {
            let obj = try await V2OnboardingService.shared.fetchPrimaryObjective()
            objective = obj
            // Recompute required time from the saved objective.
            let req = V2RequiredTimeRequest(
                objectiveType: obj.objectiveType,
                specifics: obj.specificsDict,
                timeline: obj.timeline,
                currentLevel: obj.currentLevel ?? "intermediate"
            )
            let resp: V2APIResponse<V2RequiredTimeResponse> =
                try await V2APIClient.shared.post("/objective/required-time", body: req)
            required = resp.data
            // Default selection = the saved/computed commitment.
            chosenHours = obj.weeklyCommitHours ?? resp.data.requiredHoursPerWeek
        } catch {
            self.error = "Couldn't load your commitment details."
        }
        isLoading = false
    }

    private func confirmAndContinue() async {
        isSaving = true
        defer { isSaving = false }

        // 1. If the user changed the weekly hours, persist the change.
        if let objId = objective?.objectiveId,
           let hours = chosenHours,
           hours != objective?.weeklyCommitHours {
            do {
                try await V2OnboardingService.shared.updateWeeklyHours(objectiveId: objId, hours: hours)
            } catch {
                self.error = "Couldn't save your change — continuing with the original."
            }
        }

        // 2. NOW trigger plan generation — this is the v2 order:
        //    Diagnostic → Reality Check → Plan Creation. The diagnostic-finish
        //    deferred this; the user confirming their commitment kicks it off.
        do {
            _ = try await V2OnboardingService.shared.triggerPlanGeneration(attemptId: attemptId)
        } catch {
            // Non-fatal — the Plan Creation screen polls + can retry.
            print("[V2RealityCheck] plan generation trigger failed: \(error)")
        }

        // 3. Advance to Calibration insights → Plan Creation.
        onContinue()
    }

    private func dayString(_ weekly: Int) -> String {
        String(format: "%.1f", Double(weekly) / 7.0)
    }
}
