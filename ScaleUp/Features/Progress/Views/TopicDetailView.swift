import SwiftUI

struct TopicDetailView: View {
    let topic: String
    @State private var viewModel: TopicDetailViewModel

    init(topic: String) {
        self.topic = topic
        self._viewModel = State(initialValue: TopicDetailViewModel(topic: topic))
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.topicDetail == nil {
                ProgressView()
                    .tint(ColorTokens.gold)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Score Header
                        scoreHeader

                        // What This Means
                        insightCard

                        // Score History Chart
                        if !viewModel.scoreHistory.isEmpty {
                            scoreHistorySection
                        }

                        // Quiz CTA — smart routing
                        quizCTASection

                        // Recommended Content
                        if !viewModel.recommendedContent.isEmpty {
                            recommendedSection
                        }

                        Spacer().frame(height: Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            }
        }
        .navigationTitle(topic.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Content.self) { content in
            ContentDestinationView(content: content)
        }
        .navigationDestination(for: Quiz.self) { quiz in
            QuizDetailView(quiz: quiz)
        }
        .sheet(isPresented: $viewModel.showGenerateSheet) {
            generateQuizSheet
        }
        .task {
            await viewModel.loadTopicDetail()
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        HStack(spacing: Spacing.xl) {
            ProgressRing(
                score: viewModel.score,
                label: viewModel.level,
                size: 100,
                lineWidth: 9
            )

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: 6) {
                    Text(viewModel.level)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ColorTokens.gold.opacity(0.12))
                        .clipShape(Capsule())

                    if let trend = viewModel.trend {
                        HStack(spacing: 2) {
                            Image(systemName: trend.icon)
                                .font(.system(size: 10))
                            Text(trend.rawValue.capitalized)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(trendColor(trend))
                    }
                }

                infoRow(label: "Quizzes Taken", value: "\(viewModel.quizzesTaken)")

                if let lastDate = viewModel.topicDetail?.lastAssessedAt {
                    infoRow(label: "Last Assessed", value: lastDate, style: .relative)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("What This Means")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(insightText)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let nextStep = nextStepText {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.gold)
                    Text(nextStep)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(.top, 2)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.gold.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var insightText: String {
        let s = viewModel.score
        if s >= 80 {
            return "You have strong mastery of \(topic.capitalized). Focus on maintaining this through periodic reviews and advanced challenges."
        } else if s >= 60 {
            return "You have a solid foundation in \(topic.capitalized). A few more quizzes and targeted content will push you to mastery level."
        } else if s >= 40 {
            return "You're building understanding of \(topic.capitalized). Focus on the recommended content below and take quizzes to reinforce concepts."
        } else if s > 0 {
            return "You're just getting started with \(topic.capitalized). Watch the recommended content and take a quiz to establish your baseline."
        } else {
            return "No assessment data for \(topic.capitalized) yet. Take a quiz to see where you stand and get personalized recommendations."
        }
    }

    private var nextStepText: String? {
        let s = viewModel.score
        if s == 0 { return "Take your first quiz to get scored" }
        if s < 40 { return "Watch recommended content, then retake quiz" }
        if s < 60 { return "Complete \(70 - s) more points to reach Intermediate" }
        if s < 80 { return "Almost at Advanced — keep going!" }
        return nil
    }

    // MARK: - Score History

    private var scoreHistorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Score History")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                if let first = viewModel.scoreHistory.first, let last = viewModel.scoreHistory.last {
                    let delta = Int(last.score) - Int(first.score)
                    if delta > 0 {
                        Text("+\(delta)%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ColorTokens.success)
                    } else if delta < 0 {
                        Text("\(delta)%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }
            }

            // Chart
            GeometryReader { geo in
                let entries = viewModel.scoreHistory
                let maxScore: Double = 100
                let width = geo.size.width - 32 // padding for labels
                let height: CGFloat = 140
                let chartLeft: CGFloat = 28
                let chartTop: CGFloat = 10
                let stepX = entries.count > 1 ? width / CGFloat(entries.count - 1) : width

                ZStack(alignment: .topLeading) {
                    // Y-axis labels + grid lines
                    ForEach([0, 25, 50, 75, 100], id: \.self) { line in
                        let y = chartTop + height * (1 - CGFloat(line) / maxScore)

                        // Grid line
                        Path { path in
                            path.move(to: CGPoint(x: chartLeft, y: y))
                            path.addLine(to: CGPoint(x: chartLeft + width, y: y))
                        }
                        .stroke(ColorTokens.surfaceElevated, lineWidth: 1)

                        // Y label
                        Text("\(line)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .position(x: 12, y: y)
                    }

                    // Gradient fill under the line
                    if entries.count > 1 {
                        Path { path in
                            for (index, entry) in entries.enumerated() {
                                let x = chartLeft + CGFloat(index) * stepX
                                let y = chartTop + height * (1 - CGFloat(entry.score) / maxScore)
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            // Close the path at the bottom
                            let lastX = chartLeft + CGFloat(entries.count - 1) * stepX
                            path.addLine(to: CGPoint(x: lastX, y: chartTop + height))
                            path.addLine(to: CGPoint(x: chartLeft, y: chartTop + height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.gold.opacity(0.3), ColorTokens.gold.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // Line
                    if entries.count > 1 {
                        Path { path in
                            for (index, entry) in entries.enumerated() {
                                let x = chartLeft + CGFloat(index) * stepX
                                let y = chartTop + height * (1 - CGFloat(entry.score) / maxScore)
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }

                    // Dots + labels
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let x = chartLeft + CGFloat(index) * stepX
                        let y = chartTop + height * (1 - CGFloat(entry.score) / maxScore)

                        // Outer glow for last point
                        if index == entries.count - 1 {
                            Circle()
                                .fill(ColorTokens.gold.opacity(0.2))
                                .frame(width: 16, height: 16)
                                .position(x: x, y: y)
                        }

                        Circle()
                            .fill(ColorTokens.gold)
                            .frame(width: index == entries.count - 1 ? 8 : 6, height: index == entries.count - 1 ? 8 : 6)
                            .position(x: x, y: y)

                        // Score label
                        Text("\(Int(entry.score))%")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(index == entries.count - 1 ? ColorTokens.gold : ColorTokens.textSecondary)
                            .position(x: x, y: y - 14)
                    }

                    // X-axis date labels (first and last only to avoid clutter)
                    if let firstDate = entries.first?.date {
                        Text(formatChartDate(firstDate))
                            .font(.system(size: 8))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .position(x: chartLeft, y: chartTop + height + 14)
                    }
                    if entries.count > 1, let lastDate = entries.last?.date {
                        Text(formatChartDate(lastDate))
                            .font(.system(size: 8))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .position(x: chartLeft + width, y: chartTop + height + 14)
                    }
                }
            }
            .frame(height: 180)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Quiz CTA (Smart Routing)

    private var quizCTASection: some View {
        Group {
            if let quiz = viewModel.topicQuiz {
                // Existing quiz for this topic — go to quiz detail
                NavigationLink(value: quiz) {
                    quizCTAContent(
                        title: "Quiz Available: \(quiz.title)",
                        subtitle: "\(quiz.totalQuestions) questions \u{2022} ~\(quiz.estimatedMinutes) min",
                        icon: "brain.head.profile",
                        showBadge: true
                    )
                }
                .buttonStyle(.plain)
            } else {
                // No quiz — show generate option
                Button {
                    viewModel.showGenerateSheet = true
                } label: {
                    quizCTAContent(
                        title: "Test Your \(topic.capitalized) Knowledge",
                        subtitle: "Generate a personalized quiz for this topic",
                        icon: "sparkles",
                        showBadge: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quizCTAContent(title: String, subtitle: String, icon: String, showBadge: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if showBadge {
                        Text("READY")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ColorTokens.gold)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 28, height: 28)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(Circle())
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.gold.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Generate Quiz Sheet

    private var generateQuizSheet: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Header
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 36))
                                .foregroundStyle(ColorTokens.gold)

                            Text("Generate Quiz")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)

                            Text("AI will create a personalized quiz on \(topic.capitalized) based on your learning history")
                                .font(.system(size: 13))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Spacing.lg)
                        .padding(.horizontal, Spacing.lg)

                        // Topic (pre-filled, read-only display)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Topic")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textSecondary)

                            HStack {
                                Text(topic.capitalized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ColorTokens.gold)
                            }
                            .padding(12)
                            .background(ColorTokens.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Question Count
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Number of Questions")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textSecondary)

                            HStack(spacing: 8) {
                                ForEach([5, 10, 15, 20], id: \.self) { count in
                                    Button {
                                        viewModel.selectedQuestionCount = count
                                    } label: {
                                        Text("\(count)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(viewModel.selectedQuestionCount == count ? .black : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(viewModel.selectedQuestionCount == count ? ColorTokens.gold : ColorTokens.surfaceElevated)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Assessment Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assessment Type")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textSecondary)

                            VStack(spacing: 6) {
                                ForEach(AssessmentType.allCases, id: \.self) { type in
                                    topicAssessmentTypeRow(type)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Generate / Loading
                        if viewModel.isGenerating {
                            VStack(spacing: Spacing.sm) {
                                ProgressView()
                                    .tint(ColorTokens.gold)
                                Text(viewModel.generationStatus ?? "Generating...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                            .padding(.top, Spacing.sm)
                        } else {
                            Button {
                                Task { await viewModel.generateQuiz() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                    Text("Generate Quiz")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(ColorTokens.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, Spacing.lg)
                        }

                        Spacer().frame(height: Spacing.xl)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.showGenerateSheet = false }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func topicAssessmentTypeRow(_ type: AssessmentType) -> some View {
        let isSelected = viewModel.selectedAssessmentType == type
        return Button {
            viewModel.selectedAssessmentType = type
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? ColorTokens.gold : ColorTokens.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(type.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? ColorTokens.gold.opacity(0.08) : ColorTokens.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? ColorTokens.gold.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recommended Content

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Recommended to Improve")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.recommendedContent) { content in
                    NavigationLink(value: content) {
                        HStack(spacing: Spacing.sm) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(ColorTokens.surfaceElevated)
                                    .frame(width: 60, height: 42)

                                if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                                    AsyncImage(url: imageURL) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        }
                                    }
                                    .frame(width: 60, height: 42)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(4)
                                    .background(.black.opacity(0.4))
                                    .clipShape(Circle())
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(content.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    if let duration = content.duration {
                                        Text(formatDuration(duration))
                                            .font(.system(size: 11))
                                            .foregroundStyle(ColorTokens.textTertiary)
                                    }
                                    if let diff = content.difficulty {
                                        Text(diff.rawValue.capitalized)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(ColorTokens.gold)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(ColorTokens.gold.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
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
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func infoRow(label: String, value: Date, style: Text.DateStyle) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
            Spacer()
            Text(value, style: style)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .improving: return .green
        case .stable: return .orange
        case .declining: return .red
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(mins) min"
    }

    private func formatChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
