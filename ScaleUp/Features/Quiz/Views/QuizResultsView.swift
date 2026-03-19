import SwiftUI

struct QuizResultsView: View {
    let quizId: String
    var attempt: QuizAttempt?

    @State private var viewModel = QuizResultsViewModel()
    @State private var showScoreAnimation = false
    @State private var showDetails = false
    @State private var navigateToContentId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading {
                loadingState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Score Hero
                        scoreHero

                        // Quick Stats
                        quickStats

                        // Topic Breakdown
                        if !viewModel.topicBreakdown.isEmpty {
                            topicBreakdownSection
                        }

                        // Competency Breakdown (Claude-evaluated)
                        if !viewModel.competencyBreakdown.isEmpty {
                            competencyBreakdownSection
                        }

                        // Strengths & Weaknesses
                        strengthsWeaknessesSection

                        // Missed Concepts
                        if let missed = viewModel.analysis?.missedConcepts, !missed.isEmpty {
                            missedConceptsSection(missed)
                        }

                        // Competency Progress
                        if let competency = viewModel.competency {
                            competencySection(competency)
                        }

                        // Journey Impact
                        if let impact = viewModel.journeyImpact {
                            journeyImpactSection(impact)
                        }

                        // Next Actions
                        if !viewModel.nextActions.isEmpty {
                            nextActionsSection
                        }

                        // Bottom actions
                        bottomActions

                        Spacer().frame(height: Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: Binding(
            get: { navigateToContentId != nil },
            set: { if !$0 { navigateToContentId = nil } }
        )) {
            if let contentId = navigateToContentId {
                PlayerView(contentId: contentId)
            }
        }
        .task {
            if let attempt {
                viewModel.loadFromAttempt(attempt, quiz: nil)
            } else {
                await viewModel.loadResults(quizId: quizId)
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                showScoreAnimation = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                showDetails = true
            }
        }
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        VStack(spacing: Spacing.md) {
            // Close button
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Circle())
                }
                Spacer()
            }

            // Score ring
            ZStack {
                Circle()
                    .stroke(ColorTokens.surfaceElevated, lineWidth: 8)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: showScoreAnimation ? viewModel.scorePercentage / 100 : 0)
                    .stroke(
                        viewModel.scoreColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: showScoreAnimation)

                VStack(spacing: 2) {
                    Text("\(Int(viewModel.scorePercentage))%")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(viewModel.scoreColor)

                    Text(viewModel.scoreGrade)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .scaleEffect(showScoreAnimation ? 1.0 : 0.5)
                .opacity(showScoreAnimation ? 1.0 : 0)
            }

            // Comparison
            if let comparison = viewModel.analysis?.comparisonToPrevious {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.trendIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(viewModel.trendColor)

                    if let improvement = comparison.improvement {
                        Text(improvement >= 0 ? "+\(Int(improvement))%" : "\(Int(improvement))%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(viewModel.trendColor)
                    }

                    Text("from last attempt")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(viewModel.trendColor.opacity(0.1))
                .clipShape(Capsule())
            }

            // Confidence badge
            if let confidence = viewModel.analysis?.confidenceScore {
                HStack(spacing: 4) {
                    Image(systemName: confidenceIcon(confidence))
                        .font(.system(size: 11))
                    Text("Confidence: \(confidenceLabel(confidence))")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(confidenceColor(confidence))
            }
        }
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: 10) {
            if let score = viewModel.score {
                miniStat(value: "\(score.correct)", label: "Correct", color: .green)
                miniStat(value: "\(score.incorrect)", label: "Wrong", color: .red)
                miniStat(value: "\(score.skipped)", label: "Skipped", color: .orange)
            }
            miniStat(value: viewModel.formattedTotalTime, label: "Time", color: ColorTokens.gold)
        }
        .opacity(showDetails ? 1 : 0)
    }

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Topic Breakdown

    private var topicBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Topic Performance")

            VStack(spacing: 10) {
                ForEach(viewModel.topicBreakdown) { topic in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(topic.topic.capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text("\(topic.correct)/\(topic.total)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(barColor(for: topic.percentage))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ColorTokens.surfaceElevated)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor(for: topic.percentage))
                                    .frame(width: max(0, geo.size.width * topic.percentage / 100))
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
        .clipped()
        .opacity(showDetails ? 1 : 0)
    }

    // MARK: - Strengths & Weaknesses

    private var strengthsWeaknessesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Strengths
            if let strengths = viewModel.analysis?.strengths, !strengths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Text("Strengths")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(strengths, id: \.self) { strength in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                                Text(strength)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.green)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            // Weaknesses
            if let weaknesses = viewModel.analysis?.weaknesses, !weaknesses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text("Areas to Improve")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(weaknesses, id: \.self) { weakness in
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.forward")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                                Text(weakness)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.orange)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
        .clipped()
        .opacity(showDetails ? 1 : 0)
    }

    // MARK: - Missed Concepts

    private func missedConceptsSection(_ concepts: [MissedConcept]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Review These Concepts")

            VStack(spacing: 8) {
                ForEach(concepts) { concept in
                    Button {
                        handleMissedConceptTap(concept)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(.red.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(concept.concept)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)

                                if let suggestion = concept.suggestion {
                                    Text(suggestion)
                                        .font(.system(size: 11))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                        .lineLimit(2)
                                }

                                if let timestamp = concept.timestamp {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 11))
                                        Text("Jump to \(timestamp)")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundStyle(ColorTokens.gold)
                                    .padding(.top, 2)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ColorTokens.surfaceElevated)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
        .opacity(showDetails ? 1 : 0)
    }

    // MARK: - Competency Progress

    private func competencySection(_ competency: CompetencyData) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Your \(competency.topic?.capitalized ?? "") Level")

            HStack(spacing: Spacing.md) {
                // Level badge
                VStack(spacing: 4) {
                    Text(competency.level?.capitalized ?? "—")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                    Text("Level")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(width: 80)

                VStack(alignment: .leading, spacing: 4) {
                    // Score bar
                    HStack {
                        Text("Score")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Spacer()
                        Text("\(Int(competency.score ?? 0))%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ColorTokens.gold)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorTokens.surfaceElevated)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorTokens.gold)
                                .frame(width: geo.size.width * (competency.score ?? 0) / 100)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(competency.quizzesTaken ?? 0) quizzes taken")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Spacer()
                        if let trend = competency.trend {
                            HStack(spacing: 2) {
                                Image(systemName: trend == "improving" ? "arrow.up.right" : "minus")
                                    .font(.system(size: 9))
                                Text(trend.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(trend == "improving" ? .green : .orange)
                        }
                    }
                }
            }

            // Score history mini chart
            if let history = competency.scoreHistory, history.count >= 2 {
                scoreHistoryChart(history)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
        .opacity(showDetails ? 1 : 0)
    }

    private func scoreHistoryChart(_ history: [ScoreHistoryEntry]) -> some View {
        GeometryReader { geo in
            let maxScore = history.map(\.score).max() ?? 100
            let minScore = max(0, (history.map(\.score).min() ?? 0) - 10)
            let range = max(1, maxScore - minScore)
            let inset: CGFloat = 6

            Path { path in
                for (index, entry) in history.enumerated() {
                    let x = inset + (geo.size.width - inset * 2) * CGFloat(index) / CGFloat(max(1, history.count - 1))
                    let y = inset + (geo.size.height - inset * 2) * (1 - (entry.score - minScore) / range)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            ForEach(Array(history.enumerated()), id: \.offset) { index, entry in
                let x = inset + (geo.size.width - inset * 2) * CGFloat(index) / CGFloat(max(1, history.count - 1))
                let y = inset + (geo.size.height - inset * 2) * (1 - (entry.score - minScore) / range)

                Circle()
                    .fill(index == history.count - 1 ? ColorTokens.gold : ColorTokens.surfaceElevated)
                    .stroke(ColorTokens.gold, lineWidth: 2)
                    .frame(width: 8, height: 8)
                    .position(x: x, y: y)
            }
        }
        .frame(height: 60)
        .clipped()
        .padding(.top, 4)
    }

    // MARK: - Journey Impact

    private func journeyImpactSection(_ impact: JourneyImpact) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Journey Impact")

            HStack(spacing: Spacing.md) {
                if let week = impact.currentWeek, let total = impact.totalWeeks {
                    VStack(spacing: 2) {
                        Text("Week \(week)/\(total)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Journey")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                if let progress = impact.overallProgress {
                    VStack(spacing: 2) {
                        Text("\(Int(progress))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Progress")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if let hint = impact.adaptationHint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
        .opacity(showDetails ? 1 : 0)
    }

    // MARK: - Next Actions

    private var nextActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("What's Next")

            VStack(spacing: 8) {
                ForEach(viewModel.nextActions) { action in
                    Button {
                        handleNextAction(action)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: actionIcon(action.type))
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.gold)
                                .frame(width: 32, height: 32)
                                .background(ColorTokens.gold.opacity(0.12))
                                .clipShape(Circle())

                            Text(action.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(10)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
        .opacity(showDetails ? 1 : 0)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Back to Quizzes")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                appState.selectedTab = .home
                NotificationCenter.default.post(name: .dismissQuizSession, object: nil)
            } label: {
                Text("Back to Home")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .opacity(showDetails ? 1 : 0)
    }

    // MARK: - Competency Breakdown

    private var competencyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Competency Analysis")

            VStack(spacing: 10) {
                ForEach(viewModel.competencyBreakdown) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text(item.competency)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 8)

                            if let level = item.level {
                                Text(level.capitalized)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(competencyLevelColor(level))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(competencyLevelColor(level).opacity(0.15))
                                    .clipShape(Capsule())
                                    .layoutPriority(1)
                            }
                        }

                        HStack(spacing: Spacing.sm) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(ColorTokens.surfaceElevated)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(barColor(for: item.percentage ?? 0))
                                        .frame(width: max(0, geo.size.width * (item.percentage ?? 0) / 100))
                                }
                            }
                            .frame(height: 8)

                            Text("\(item.correct ?? 0)/\(item.total ?? 0)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(barColor(for: item.percentage ?? 0))
                                .frame(width: 30, alignment: .trailing)
                        }

                        if let textAvg = item.textScoreAvg, textAvg > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 9))
                                Text("Text Score: \(Int(textAvg))%")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    .padding(10)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
        .clipped()
        .opacity(showDetails ? 1 : 0)
    }

    private func competencyLevelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "expert", "proficient": return .green
        case "competent": return ColorTokens.gold
        case "foundational": return .orange
        case "awareness": return .red
        default: return ColorTokens.textTertiary
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
    }

    private func barColor(for percentage: Double) -> Color {
        if percentage >= 80 { return .green }
        if percentage >= 50 { return .orange }
        return .red
    }

    private func confidenceIcon(_ score: Int) -> String {
        if score >= 70 { return "brain.fill" }
        if score >= 50 { return "brain" }
        return "questionmark.circle"
    }

    private func confidenceLabel(_ score: Int) -> String {
        if score >= 70 { return "High" }
        if score >= 50 { return "Moderate" }
        return "Low (possible guessing)"
    }

    private func confidenceColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    private func actionIcon(_ type: String) -> String {
        switch type {
        case "study_weak_areas": return "book.fill"
        case "continue_journey": return "map.fill"
        case "explore_topic": return "safari.fill"
        default: return "arrow.right.circle.fill"
        }
    }

    // MARK: - Action Handlers

    private func handleMissedConceptTap(_ concept: MissedConcept) {
        if let contentId = concept.contentId {
            navigateToContentId = contentId
        } else if let sourceId = viewModel.quiz?.sourceContentIds?.first {
            navigateToContentId = sourceId
        }
    }

    private func handleNextAction(_ action: QuizNextAction) {
        switch action.type {
        case "study_weak_areas":
            if let contentId = action.contentId {
                navigateToContentId = contentId
            } else {
                // Go back to quizzes to retake
                dismiss()
            }
        case "continue_journey":
            // Dismiss to go back, user can navigate to My Plan tab
            dismiss()
        case "explore_topic":
            if let contentId = action.contentId {
                navigateToContentId = contentId
            } else {
                // Dismiss — user can go to Discover tab
                dismiss()
            }
        default:
            dismiss()
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ColorTokens.gold)
            Text("Loading results...")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }
}
