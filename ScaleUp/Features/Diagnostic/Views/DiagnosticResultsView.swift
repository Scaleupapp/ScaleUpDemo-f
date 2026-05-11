import SwiftUI

struct DiagnosticResultsView: View {
    let attemptId: String
    var onSeePlanTap: () -> Void

    @StateObject private var vm: DiagnosticResultsViewModel
    @AppStorage private var heroRevealed: Bool
    @State private var showHero: Bool = false

    init(attemptId: String, onSeePlanTap: @escaping () -> Void) {
        self.attemptId = attemptId
        self.onSeePlanTap = onSeePlanTap
        self._vm = StateObject(wrappedValue: DiagnosticResultsViewModel(attemptId: attemptId))
        self._heroRevealed = AppStorage(wrappedValue: false, "diagnostic_hero_revealed_\(attemptId)")
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            switch vm.phase {
            case .generating:
                InsightsGeneratingView(isReady: false)
            case .ready:
                if showHero && !heroRevealed {
                    HeroStoryRevealView(
                        heroSentence: vm.hero,
                        surpriseSentence: mostStrikingSentence(),
                        planSentence: firstSentence(of: vm.planHeadline),
                        overallScore: vm.overallScore,
                        onDone: {
                            heroRevealed = true
                            withAnimation(.easeInOut(duration: 0.4)) { showHero = false }
                            vm.onHeroRevealCompleted()
                        }
                    )
                    .transition(.opacity)
                } else {
                    resultsScroll.transition(.opacity)
                }
            }
        }
        .onAppear { vm.start() }
        .onChange(of: vm.phase) { _, newPhase in
            if newPhase == .ready && !heroRevealed { showHero = true }
        }
        .sheet(isPresented: $vm.showShareSheet, onDismiss: { vm.shareImage = nil }) {
            if let img = vm.shareImage {
                ShareSheet(activityItems: [img]) { destination in
                    vm.onResultsShared(destination: destination)
                }
            }
        }
    }

    private var resultsScroll: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                HeroCard(heroSentence: vm.hero, onShareTap: triggerShare)
                    .padding(.horizontal, Spacing.lg)

                CalibrationCard(
                    summarySentence: vm.calibrationSummary,
                    detailSentence: vm.calibrationDetail,
                    topics: vm.topics
                )
                .padding(.horizontal, Spacing.lg)

                ForEach(vm.topics) { t in
                    TopicComparisonBarCard(topic: t, onExpand: vm.onTopicExpanded(_:))
                        .padding(.horizontal, Spacing.lg)
                }

                if !vm.patterns.isEmpty {
                    sectionHeader("Patterns we noticed")
                    ForEach(Array(vm.patterns.enumerated()), id: \.offset) { idx, p in
                        PatternCard(title: "Pattern \(idx + 1)", text: p, icon: patternIcon(for: idx))
                            .padding(.horizontal, Spacing.lg)
                    }
                }

                // Replay disclosure is hidden until the per-question playback
                // surface ships — showing the empty "loads here" stub was
                // shipping a TODO into production. Reinstate once the data
                // pipeline + per-question view exist.
                planPreview.padding(.horizontal, Spacing.lg)
                seePlanButton
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.xxl)
            }
            .padding(.top, Spacing.md)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text).font(Typography.titleMedium).foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private var replayDisclosure: some View {
        DisclosureGroup {
            Text("Question-by-question replay loads here.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.vertical, Spacing.sm)
        } label: {
            HStack {
                Image(systemName: "play.rectangle").foregroundStyle(ColorTokens.gold)
                Text("Review your answers").font(Typography.bodyBold).foregroundStyle(ColorTokens.textPrimary)
            }
            .onTapGesture { vm.onReplayOpened() }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Your plan").font(Typography.titleMedium).foregroundStyle(ColorTokens.textPrimary)
            Text(vm.planHeadline)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(3)
            HStack {
                Image(systemName: "hourglass").foregroundStyle(ColorTokens.gold)
                Text("Your full plan is brewing — usually a minute or two")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.top, 2)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
    }

    private var seePlanButton: some View {
        Button(action: onSeePlanTap) {
            Text("See your plan")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Capsule().fill(ColorTokens.gold))
        }
    }

    private func mostStrikingSentence() -> String {
        guard let t = vm.topics.max(by: { abs($0.calibrationDelta) < abs($1.calibrationDelta) }) else {
            return vm.calibrationDetail
        }
        return t.topicTakeaway.isEmpty ? vm.calibrationDetail : t.topicTakeaway
    }

    private func firstSentence(of s: String) -> String {
        if let dot = s.firstIndex(of: ".") { return String(s[...dot]) }
        return s
    }

    private func patternIcon(for idx: Int) -> String {
        ["chart.line.uptrend.xyaxis", "scope", "lightbulb.fill", "target"][idx % 4]
    }

    private func triggerShare() {
        let card = ShareableSummaryCard(
            heroSentence: vm.hero,
            topics: Array(vm.topics.sorted { abs($0.calibrationDelta) > abs($1.calibrationDelta) }.prefix(3))
        )
        if let image = ShareableSummaryCardGenerator.render(card) {
            vm.shareImage = image
            vm.showShareSheet = true
        }
    }
}
