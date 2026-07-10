import SwiftUI

/// Step 3 of the placement first-login hook — a fast, real win. We seed the
/// student's first objective competency into the EXISTING private-practice
/// infrastructure (`CompassInlineQuizModel` + `CompassInlineQuizCard`, the same
/// single-topic generate→answer→AI-feedback flow Compass uses) as a one-question
/// check. Finishing lights a "day 1 / readiness unlocking" delight moment.
///
/// Both the primary "Go to my homepage" CTA and "Skip for now" finish the hook
/// via `AppState.finishPlacementOnboarding()` (marks onboarded, routes Home).
struct PlacementFirstWinView: View {
    @Environment(AppState.self) private var appState

    @State private var model: CompassInlineQuizModel?
    @State private var isPreparing = true
    @State private var didFinish = false
    @State private var isFinishing = false

    private var isDone: Bool { model?.phase == .done }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            content
        }
        .task { await prepare() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: Spacing.xl)

                Text("STEP 3 OF 3").v2Eyebrow()
                    .padding(.bottom, Spacing.sm)

                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ColorTokens.background)
                }
                .padding(.bottom, Spacing.lg)

                Text("A 2-minute win")
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Answer one quick question and get instant AI feedback — a taste of how you'll practise here, and your first step toward placement readiness.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)

                practiceArea
                    .padding(.top, Spacing.xl)

                if isDone {
                    delightCard
                        .padding(.top, Spacing.lg)
                }

                Spacer(minLength: Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: - Practice area (reused inline-quiz infra)

    @ViewBuilder
    private var practiceArea: some View {
        if let model {
            CompassInlineQuizCard(model: model) {
                // Fires once when the check reaches .done or .failed.
                guard !didFinish else { return }
                didFinish = true
                if model.phase == .done { Haptics.success() }
            }
        } else if isPreparing {
            HStack(spacing: Spacing.sm) {
                ProgressView().tint(ColorTokens.gold)
                Text("Setting up your first question…")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        } else {
            // Couldn't seed a topic at all — never block the student.
            Text("You can start practising anytime from your homepage.")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Delight moment

    private var delightCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ColorTokens.gold)
                Text("Day 1 — streak started")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            Text("Nice work. That's your first win — your placement readiness is unlocking. Keep practising and it'll climb from here.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.gold.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Go to my homepage", icon: "house.fill", isLoading: isFinishing) {
                Haptics.success()
                finish()
            }
            if !isDone {
                Button {
                    guard !isFinishing else { return }
                    finish()
                } label: {
                    Text("Skip for now")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.plain)
                .disabled(isFinishing)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .background(ColorTokens.background)
    }

    // MARK: - Actions

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        Task { await appState.finishPlacementOnboarding() }
    }

    /// Derives the seed topic from the student's first objective competency and
    /// spins up the existing single-topic inline-quiz session at one question.
    private func prepare() async {
        guard model == nil else { return }
        let payload = await PlacementOnboardingApi.shared.fetch()
        let topic = payload?.competencies?.first?.name
            ?? payload?.objectiveLabel
            ?? "Aptitude"
        let m = CompassInlineQuizModel(topic: topic, questionCount: 1, beforeScore: nil)
        model = m
        isPreparing = false
        await m.begin()
    }
}
