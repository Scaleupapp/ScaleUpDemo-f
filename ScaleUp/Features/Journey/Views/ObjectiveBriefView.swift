import SwiftUI

struct ObjectiveBriefView: View {
    let objectiveId: String

    @State private var briefResponse: ObjectiveBriefResponse?
    @State private var isLoading = true
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var selectedCompetency: ObjectiveCompetency?
    @State private var isOverviewExpanded = false
    @State private var selectedInsightTab = 0
    @State private var generatingAssessments: Set<String> = []
    @State private var generatedAssessments: Set<String> = []
    @State private var gapQuizzes: [String: Quiz] = [:]  // competency name (lowercased) -> quiz

    private let objectiveService = ObjectiveService()
    private let quizService = QuizService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                loadingState
            } else if let brief = briefResponse {
                briefContent(brief)
            } else if isAnalyzing {
                analyzingState
            } else {
                noAnalysisState
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadBrief()
        }
    }

    // MARK: - Brief Content

    private func briefContent(_ brief: ObjectiveBriefResponse) -> some View {
        let hasAnalysis = (brief.competencies != nil && !(brief.competencies?.isEmpty ?? true)) ||
                          (brief.brief?.overview != nil && !(brief.brief?.overview?.isEmpty ?? true))

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                header(brief)

                if !hasAnalysis {
                    inlineAnalyzeCTA
                }

                // Collapsible overview
                if let overview = brief.brief?.overview, !overview.isEmpty {
                    overviewSection(overview)
                }

                // Competency grid (hero section)
                if let comps = brief.competencies, !comps.isEmpty {
                    competencyGridSection(comps, assessmentStrategy: brief.assessmentStrategy)
                }

                // Content coverage (with per-competency content mapping)
                if let coverage = brief.contentCoverage {
                    coverageSection(coverage, competencies: brief.competencies)
                }

                // Tabbed insights
                insightsSection(brief.brief)

                Spacer().frame(height: Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .sheet(item: $selectedCompetency) { comp in
            competencyDetailSheet(comp, assessmentStrategy: briefResponse?.assessmentStrategy)
        }
    }

    // MARK: - Header

    private func header(_ brief: ObjectiveBriefResponse) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                }
                Spacer()
            }

            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: objectiveIcon(brief.objective?.objectiveType))
                    .font(.system(size: 30))
                    .foregroundStyle(ColorTokens.gold)
            }

            Text(brief.objective?.goalTitle ?? "Your Objective")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if let level = brief.objective?.currentLevel {
                    metaChip(icon: "chart.bar.fill", text: level.capitalized)
                }
                if let timeline = brief.objective?.timeline {
                    metaChip(icon: "calendar", text: timeline.replacingOccurrences(of: "_", with: " "))
                }
            }

            if let analyzedAt = brief.analyzedAt {
                Text("Analyzed \(analyzedAt, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(ColorTokens.gold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ColorTokens.gold.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Collapsible Overview

    private func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("What This Means", icon: "lightbulb.fill")

            Text(overview)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(4)
                .lineLimit(isOverviewExpanded ? nil : 3)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isOverviewExpanded.toggle()
                }
            } label: {
                Text(isOverviewExpanded ? "Show less" : "Read more")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Competency Grid (Hero Section)

    private func competencyGridSection(_ competencies: [ObjectiveCompetency], assessmentStrategy: AssessmentStrategy?) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let sorted = competencies.sorted { ($0.weight ?? 0) > ($1.weight ?? 0) }

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                sectionHeader("Skills You Need", icon: "chart.bar.xaxis")
                Spacer()
                Text("\(competencies.count) skills")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Overall readiness bar
            overallReadinessBar(competencies)

            // Category breakdown
            categoryBreakdown(competencies)

            // 2-column grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(sorted) { comp in
                    Button {
                        selectedCompetency = comp
                    } label: {
                        competencyGridCard(comp)
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
    }

    private func overallReadinessBar(_ competencies: [ObjectiveCompetency]) -> some View {
        let scores = competencies.compactMap { $0.currentScore }
        let avgScore = scores.isEmpty ? 0 : Int(scores.reduce(0, +) / Double(scores.count))

        return VStack(spacing: 6) {
            HStack {
                Text("Overall Readiness")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(avgScore)%")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(ColorTokens.gold)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(ColorTokens.surfaceElevated)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(ColorTokens.gold)
                        .frame(width: geo.size.width * CGFloat(avgScore) / 100)
                }
            }
            .frame(height: 8)
        }
        .padding(Spacing.sm)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func categoryBreakdown(_ competencies: [ObjectiveCompetency]) -> some View {
        let coreCount = competencies.filter { $0.category == "core" }.count
        let advancedCount = competencies.filter { $0.category == "advanced" }.count
        let softCount = competencies.filter { $0.category == "soft_skill" }.count

        return HStack(spacing: 12) {
            if coreCount > 0 {
                categoryChip(count: coreCount, label: "core", color: ColorTokens.gold)
            }
            if advancedCount > 0 {
                categoryChip(count: advancedCount, label: "advanced", color: .purple)
            }
            if softCount > 0 {
                categoryChip(count: softCount, label: "soft", color: .cyan)
            }
            Spacer()
        }
    }

    private func categoryChip(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func competencyGridCard(_ comp: ObjectiveCompetency) -> some View {
        let score = Int(comp.currentScore ?? 0)
        let catColor = categoryColor(comp.category)

        return VStack(spacing: 8) {
            ProgressRing(
                score: score,
                label: "",
                size: 44,
                lineWidth: 4,
                showLabel: false,
                animated: true
            )

            Text(comp.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)

            // Weight dots
            if let w = comp.weight {
                HStack(spacing: 2) {
                    ForEach(0..<min(w, 10), id: \.self) { i in
                        Circle()
                            .fill(i < w ? catColor : catColor.opacity(0.2))
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(catColor.opacity(0.3), lineWidth: 1)
                        .frame(width: nil)
                        .clipped()
                        .mask(
                            HStack {
                                Rectangle().frame(width: 3)
                                Spacer()
                            }
                        )
                )
        )
    }

    // MARK: - Coverage (per-competency content mapping)

    private func coverageSection(_ coverage: ContentCoverage, competencies: [ObjectiveCompetency]?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Content Coverage", icon: "square.grid.2x2.fill")

            let coveredCount = coverage.covered?.count ?? 0
            let gapCount = coverage.gaps?.count ?? 0
            let total = coveredCount + gapCount

            // Overall coverage bar
            if total > 0 {
                HStack(spacing: 4) {
                    Text("\(coveredCount)/\(total) skills covered")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(gapCount) gaps")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(gapCount > 0 ? .orange : .green)
                }

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.green)
                            .frame(width: total > 0 ? geo.size.width * CGFloat(coveredCount) / CGFloat(total) : 0)
                        if gapCount > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.orange.opacity(0.4))
                        }
                    }
                }
                .frame(height: 8)
            }

            // Per-competency content mapping
            if let comps = competencies {
                let compsWithContent = comps.filter { !($0.contentItems?.isEmpty ?? true) }
                let compsWithoutContent = comps.filter { ($0.contentItems?.isEmpty ?? true) }

                if !compsWithContent.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(compsWithContent) { comp in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(categoryColor(comp.category))
                                        .frame(width: 6, height: 6)
                                    Text(comp.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(comp.contentItems?.count ?? 0) items")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }

                                // Horizontal scroll of mini content cards
                                if let items = comp.contentItems, !items.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(items) { item in
                                                NavigationLink(value: Content(
                                                    id: item.id, creatorId: nil, title: item.title,
                                                    description: nil, contentType: .video,
                                                    contentURL: nil, thumbnailURL: item.thumbnailUrl,
                                                    duration: item.duration, sourceType: nil,
                                                    sourceAttribution: nil, domain: nil, topics: nil,
                                                    tags: nil, difficulty: nil, aiData: nil,
                                                    status: nil, viewCount: nil, likeCount: nil,
                                                    commentCount: nil, saveCount: nil,
                                                    averageRating: nil, ratingCount: nil,
                                                    publishedAt: nil, createdAt: nil
                                                )) {
                                                    miniContentCard(item)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Gap competencies with strategies + actions
                if !compsWithoutContent.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Gaps — No content yet")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)

                        ForEach(compsWithoutContent) { comp in
                            gapCompetencyCard(comp, strategy: coverage.gapStrategies?.first { $0.competency == comp.name })
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
    }

    private func miniContentCard(_ item: CompetencyContentItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 100, height: 56)

                if let url = item.thumbnailUrl, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .frame(width: 100, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Text(item.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)

            if let duration = item.duration {
                Text("\(duration / 60) min")
                    .font(.system(size: 9))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    // MARK: - Gap Competency Card

    private func gapCompetencyCard(_ comp: ObjectiveCompetency, strategy: GapStrategy?) -> some View {
        let existingQuiz = gapQuizzes[comp.name.lowercased()]
        let isGenerating = generatingAssessments.contains(comp.name)
        let isGenerated = generatedAssessments.contains(comp.name)

        return VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: gapStrategyIcon(strategy?.strategy))
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(comp.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(gapStrategyLabel(strategy?.strategy))
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer(minLength: 0)
            }

            if let quiz = existingQuiz, quiz.status == .completed {
                // State: Quiz completed — show score + actions
                gapCompletedState(quiz: quiz, comp: comp, isGenerating: isGenerating)
            } else if let quiz = existingQuiz, quiz.status == .ready || quiz.status == .delivered {
                // State: Quiz ready — take it now
                gapReadyState(quiz: quiz)
            } else if isGenerated {
                // State: Just generated in this session
                gapJustGeneratedState()
            } else {
                // State: No quiz — generate one
                gapGenerateState(comp: comp, isGenerating: isGenerating)
            }
        }
        .padding(10)
        .background(ColorTokens.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func gapCompletedState(quiz: Quiz, comp: ObjectiveCompetency, isGenerating: Bool) -> some View {
        VStack(spacing: 8) {
            // Completed row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Assessment Completed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("\(quiz.totalQuestions) questions • \(quiz.topic.capitalized)")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 8) {
                NavigationLink(value: quiz) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                        Text("View Results")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ColorTokens.gold.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await generateGapAssessment(comp) }
                } label: {
                    HStack(spacing: 4) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.5).tint(.white)
                        } else {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                        }
                        Text(isGenerating ? "Generating..." : "Retake")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ColorTokens.surfaceElevated)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ColorTokens.border, lineWidth: 1))
                    )
                }
                .disabled(isGenerating)
                .buttonStyle(.plain)
            }
        }
    }

    private func gapReadyState(quiz: Quiz) -> some View {
        NavigationLink(value: quiz) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                Text("Take Assessment")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(quiz.totalQuestions) Qs")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .foregroundStyle(ColorTokens.gold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTokens.gold.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func gapJustGeneratedState() -> some View {
        NavigationLink(value: QuizListDestination()) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("Assessment Ready — View Quizzes")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func gapGenerateState(comp: ObjectiveCompetency, isGenerating: Bool) -> some View {
        Button {
            Task { await generateGapAssessment(comp) }
        } label: {
            HStack(spacing: 6) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(ColorTokens.gold)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                }
                Text(isGenerating ? "Generating..." : "Generate Assessment")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isGenerating ? ColorTokens.textTertiary : ColorTokens.gold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTokens.gold.opacity(isGenerating ? 0.05 : 0.1))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ColorTokens.gold.opacity(isGenerating ? 0.1 : 0.25), lineWidth: 1))
            )
        }
        .disabled(isGenerating)
        .buttonStyle(.plain)
    }

    // MARK: - Tabbed Insights

    private func insightsSection(_ brief: ObjectiveBriefContent?) -> some View {
        let tabs = insightTabs(brief)

        return Group {
            if !tabs.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Insights")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    // Tab pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tabs.indices, id: \.self) { index in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedInsightTab = index
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: tabs[index].icon)
                                            .font(.system(size: 10))
                                        Text(tabs[index].title)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(selectedInsightTab == index ? .black : ColorTokens.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedInsightTab == index ? ColorTokens.gold : ColorTokens.surfaceElevated)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Content area
                    let safeIndex = min(selectedInsightTab, tabs.count - 1)
                    Text(tabs[safeIndex].content)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineSpacing(4)
                        .id(safeIndex)
                        .transition(.opacity)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ColorTokens.surface)
                )
            }
        }
    }

    private struct InsightTab {
        let title: String
        let icon: String
        let content: String
    }

    private func insightTabs(_ brief: ObjectiveBriefContent?) -> [InsightTab] {
        var tabs: [InsightTab] = []
        if let criteria = brief?.successCriteria, !criteria.isEmpty {
            tabs.append(InsightTab(title: "Ready Looks Like", icon: "target", content: criteria))
        }
        if let dayToDay = brief?.dayToDay, !dayToDay.isEmpty {
            tabs.append(InsightTab(title: "Day-to-Day", icon: "clock.fill", content: dayToDay))
        }
        if let challenges = brief?.challenges, !challenges.isEmpty {
            tabs.append(InsightTab(title: "Challenges", icon: "exclamationmark.triangle.fill", content: challenges))
        }
        if let context = brief?.industryContext, !context.isEmpty {
            tabs.append(InsightTab(title: "Industry", icon: "building.2.fill", content: context))
        }
        return tabs
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ColorTokens.gold)
            Text("Loading skill map...")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var analyzingState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(ColorTokens.gold)
            }

            Text("Analyzing Your Objective...")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("Our AI is building a personalized competency framework for your goal. This takes about 15-30 seconds.")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var noAnalysisState: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "brain.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.gold)
            }

            Text("Ready to Analyze")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Text("Let our AI analyze your objective and build a personalized competency map with skill assessments.")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await analyzeObjective() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Analyze My Objective")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ColorTokens.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Inline Analyze CTA

    private var inlineAnalyzeCTA: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.1))
                    .frame(width: 56, height: 56)
                if isAnalyzing {
                    ProgressView()
                        .tint(ColorTokens.gold)
                } else {
                    Image(systemName: "brain.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(ColorTokens.gold)
                }
            }

            Text(isAnalyzing ? "Analyzing..." : "Analysis Not Available")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Text(isAnalyzing
                 ? "This may take up to 30 seconds. Please wait..."
                 : "Run an AI analysis to unlock your personalized competency map, assessment strategy, and detailed skill breakdown.")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.error)
                    .multilineTextAlignment(.center)
            }

            if !isAnalyzing {
                Button {
                    errorMessage = nil
                    Task { await analyzeObjective() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Analyze My Objective")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Competency Detail Sheet (with merged assessment strategy)

    private func competencyDetailSheet(_ comp: ObjectiveCompetency, assessmentStrategy: AssessmentStrategy?) -> some View {
        // Find matching assessment recommendation
        let matchingRec = assessmentStrategy?.recommended?.first { $0.competency.lowercased() == comp.name.lowercased() }

        return NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Header with ProgressRing
                        VStack(spacing: Spacing.sm) {
                            ProgressRing(
                                score: Int(comp.currentScore ?? 0),
                                label: "",
                                size: 80,
                                lineWidth: 6,
                                showLabel: false,
                                animated: true
                            )

                            Text(comp.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 8) {
                                if let category = comp.category {
                                    metaChip(icon: "tag.fill", text: category.replacingOccurrences(of: "_", with: " ").capitalized)
                                }
                                if let weight = comp.weight {
                                    metaChip(icon: "scalemass.fill", text: "\(weight)/10")
                                }
                                if let level = comp.currentLevel, level != "not_started" {
                                    metaChip(icon: "chart.line.uptrend.xyaxis", text: level.replacingOccurrences(of: "_", with: " ").capitalized)
                                }
                            }
                        }
                        .padding(.top, Spacing.md)

                        // Description
                        if let desc = comp.description, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                sectionHeader("About", icon: "info.circle.fill")
                                Text(desc)
                                    .font(.system(size: 13))
                                    .foregroundStyle(ColorTokens.textSecondary)
                                    .lineSpacing(4)
                            }
                            .padding(Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(ColorTokens.surface)
                            )
                        }

                        // Assessment Strategy (merged from standalone section)
                        if let rec = matchingRec {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                sectionHeader("Assessment", icon: "checkmark.seal.fill")

                                VStack(alignment: .leading, spacing: 8) {
                                    if let type = rec.assessmentType {
                                        HStack(spacing: 6) {
                                            Image(systemName: assessmentTypeIcon(type))
                                                .font(.system(size: 12))
                                            Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundStyle(ColorTokens.gold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(ColorTokens.gold.opacity(0.12))
                                        .clipShape(Capsule())
                                    }

                                    if let reasoning = rec.reasoning, !reasoning.isEmpty {
                                        Text(reasoning)
                                            .font(.system(size: 12))
                                            .foregroundStyle(ColorTokens.textTertiary)
                                            .lineSpacing(3)
                                    }
                                }
                            }
                            .padding(Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(ColorTokens.surface)
                            )
                        }

                        // Prerequisites
                        if let prereqs = comp.prerequisites, !prereqs.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                sectionHeader("Prerequisites", icon: "arrow.triangle.branch")

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(prereqs, id: \.self) { prereq in
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.green)
                                            Text(prereq)
                                                .font(.system(size: 13))
                                                .foregroundStyle(ColorTokens.textSecondary)
                                        }
                                    }
                                }
                            }
                            .padding(Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(ColorTokens.surface)
                            )
                        }

                        // Proficiency Levels
                        if let levels = comp.proficiencyLevels, !levels.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                sectionHeader("Proficiency Ladder", icon: "ladder")

                                VStack(spacing: 6) {
                                    ForEach(levels.sorted(by: { $0.level < $1.level })) { level in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("\(level.level)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(.black)
                                                .frame(width: 24, height: 24)
                                                .background(proficiencyColor(level.level))
                                                .clipShape(Circle())

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(level.title)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                if let desc = level.description, !desc.isEmpty {
                                                    Text(desc)
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(ColorTokens.textTertiary)
                                                        .lineSpacing(2)
                                                }
                                            }

                                            Spacer(minLength: 0)
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
                        }

                        // Recommended Assessment Types
                        if let types = comp.assessmentTypes, !types.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                sectionHeader("Assessment Types", icon: "list.clipboard.fill")

                                FlowLayout(spacing: 6) {
                                    ForEach(types, id: \.self) { type in
                                        HStack(spacing: 4) {
                                            Image(systemName: assessmentTypeIcon(type))
                                                .font(.system(size: 10))
                                            Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundStyle(ColorTokens.gold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(ColorTokens.gold.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(ColorTokens.surface)
                            )
                        }

                        Spacer().frame(height: Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedCompetency = nil }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func proficiencyColor(_ level: Int) -> Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        case 3: return ColorTokens.gold
        case 4: return .green
        case 5: return .cyan
        default: return ColorTokens.textTertiary
        }
    }

    // MARK: - Actions

    private func loadBrief() async {
        isLoading = true
        do {
            async let briefTask = objectiveService.getObjectiveBrief(id: objectiveId)
            async let quizzesTask = quizService.fetchAllQuizzes()

            let response = try await briefTask
            briefResponse = response

            // Load existing quizzes and map to gap competencies by topic name
            if let quizzes = try? await quizzesTask {
                var mapping: [String: Quiz] = [:]
                for quiz in quizzes {
                    let topicKey = quiz.topic.lowercased()
                    // Keep the most recent quiz per topic
                    if mapping[topicKey] == nil {
                        mapping[topicKey] = quiz
                    }
                }
                gapQuizzes = mapping
            }
        } catch {
            briefResponse = nil
        }
        isLoading = false
    }

    private func analyzeObjective() async {
        isAnalyzing = true
        do {
            _ = try await objectiveService.analyzeObjective(id: objectiveId)

            var attempt = 0
            while attempt < 5 {
                try? await Task.sleep(for: .milliseconds(Int(pow(2.0, Double(attempt)) * 500)))
                if let response = try? await objectiveService.getObjectiveBrief(id: objectiveId) {
                    let hasData = (response.competencies != nil && !(response.competencies?.isEmpty ?? true)) ||
                                  (response.brief?.overview != nil && !(response.brief?.overview?.isEmpty ?? true))
                    if hasData {
                        briefResponse = response
                        isAnalyzing = false
                        return
                    }
                }
                attempt += 1
            }

            let response = try await objectiveService.getObjectiveBrief(id: objectiveId)
            briefResponse = response
        } catch {
            errorMessage = "Analysis failed. Please try again."
        }
        isAnalyzing = false
    }

    private func generateGapAssessment(_ comp: ObjectiveCompetency) async {
        let name = comp.name
        generatingAssessments.insert(name)

        do {
            let response = try await quizService.requestQuiz(
                topic: name,
                questionCount: (comp.weight ?? 5) >= 8 ? 10 : 7,
                assessmentType: comp.assessmentTypes?.first ?? "mixed",
                objectiveId: briefResponse?.objective?.id,
                isSkillAssessment: true
            )

            print("[ObjectiveBrief] Quiz request sent for \(name), triggerId=\(response.triggerId ?? "nil"), status=\(response.status ?? "nil")")

            // Poll for quiz generation
            if let triggerId = response.triggerId {
                for i in 0..<30 {
                    try await Task.sleep(for: .seconds(3))
                    let status = try await quizService.checkTriggerStatus(triggerId: triggerId)
                    print("[ObjectiveBrief] Poll \(i): status=\(status.status ?? "nil") for \(name)")
                    if status.status == "generated" {
                        generatingAssessments.remove(name)
                        generatedAssessments.insert(name)
                        Haptics.success()

                        // Refresh quiz list so the new quiz shows up with proper state
                        if let quizzes = try? await quizService.fetchAllQuizzes() {
                            var mapping = gapQuizzes
                            for quiz in quizzes {
                                let topicKey = quiz.topic.lowercased()
                                if mapping[topicKey] == nil || quiz.createdAt ?? .distantPast > mapping[topicKey]?.createdAt ?? .distantPast {
                                    mapping[topicKey] = quiz
                                }
                            }
                            gapQuizzes = mapping
                            generatedAssessments.remove(name) // Let gapQuizzes state drive the UI now
                        }
                        return
                    }
                    if status.status == "failed" {
                        print("[ObjectiveBrief] Quiz generation failed for \(name)")
                        break
                    }
                }
            }
        } catch {
            print("[ObjectiveBrief] Error generating assessment for \(name): \(error)")
        }

        generatingAssessments.remove(name)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.gold)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func categoryColor(_ category: String?) -> Color {
        switch category {
        case "core": return ColorTokens.gold
        case "advanced": return .purple
        case "soft_skill": return .cyan
        default: return ColorTokens.textTertiary
        }
    }

    private func objectiveIcon(_ type: String?) -> String {
        switch type {
        case "exam_preparation": return "doc.text.fill"
        case "interview_preparation": return "person.fill.questionmark"
        case "upskilling": return "arrow.up.circle.fill"
        case "career_switch": return "arrow.triangle.swap"
        case "academic_excellence": return "graduationcap.fill"
        case "casual_learning": return "book.fill"
        default: return "target"
        }
    }

    private func assessmentTypeIcon(_ type: String?) -> String {
        switch type {
        case "knowledge_recall": return "brain.head.profile"
        case "applied_scenario": return "theatermasks.fill"
        case "situational_judgment": return "person.fill.questionmark"
        case "framework_application": return "square.grid.3x3.fill"
        case "case_study": return "doc.text.magnifyingglass"
        case "competency_gate": return "flag.checkered"
        case "exam_style": return "doc.text.fill"
        case "mixed": return "shuffle"
        default: return "checkmark.circle.fill"
        }
    }

    private func gapStrategyIcon(_ strategy: String?) -> String {
        switch strategy {
        case "assessment_only": return "checkmark.square.fill"
        case "practice": return "figure.walk"
        case "external": return "link"
        default: return "book.fill"
        }
    }

    private func gapStrategyLabel(_ strategy: String?) -> String {
        switch strategy {
        case "assessment_only": return "Test & learn through assessments"
        case "practice": return "Practice with scenarios"
        case "external": return "External resources + self-study"
        default: return "Self-study materials"
        }
    }
}
