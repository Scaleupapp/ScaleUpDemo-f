import SwiftUI

// MARK: - Quiz Detail View

struct QuizDetailView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let quiz: Quiz

    @State private var showQuizSession = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {

                    // Hero section with gradient backdrop
                    heroSection

                    // Main content
                    VStack(spacing: Spacing.lg) {

                        // Quiz info cards
                        infoSection

                        // What to expect
                        expectationSection

                        // Source content
                        if let ids = quiz.sourceContentIds, !ids.isEmpty {
                            sourceContentSection
                        }

                        // Expiry warning
                        if let expiresAt = quiz.expiresAt {
                            expiryBanner(expiresAt)
                        }

                        // Start button
                        PrimaryButton(title: "Start Quiz") {
                            showQuizSession = true
                        }
                        .padding(.horizontal, Spacing.md)

                        Spacer()
                            .frame(height: Spacing.xl)
                    }
                    .padding(.top, Spacing.lg)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showQuizSession) {
            QuizQuestionView(quizId: quiz.id)
                .environment(dependencies)
        }
        .onAppear {
            if !appeared {
                appeared = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            // Gradient backdrop
            LinearGradient(
                colors: [
                    quizTypeColor.opacity(0.3),
                    quizTypeColor.opacity(0.1),
                    ColorTokens.backgroundDark
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260)

            // Decorative circles
            Circle()
                .fill(quizTypeColor.opacity(0.08))
                .frame(width: 200, height: 200)
                .offset(x: -100, y: -40)

            Circle()
                .fill(quizTypeColor.opacity(0.05))
                .frame(width: 160, height: 160)
                .offset(x: 120, y: 20)

            VStack(spacing: Spacing.md) {
                // Type badge
                Text(quizTypeLabel)
                    .font(Typography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm + 4)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(quizTypeColor)
                    .clipShape(Capsule())

                // Icon with glow
                ZStack {
                    Circle()
                        .fill(quizTypeColor.opacity(0.15))
                        .frame(width: 110, height: 110)

                    Circle()
                        .fill(quizTypeColor.opacity(0.08))
                        .frame(width: 130, height: 130)

                    Image(systemName: quizTypeIcon)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(quizTypeColor)
                        .frame(width: 88, height: 88)
                        .background(
                            Circle()
                                .fill(ColorTokens.surfaceDark)
                        )
                        .overlay(
                            Circle()
                                .stroke(quizTypeColor.opacity(0.3), lineWidth: 2)
                        )
                }

                // Topic name
                Text(quiz.topic)
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
            .padding(.top, Spacing.md)
        }
        .clipped()
    }

    // MARK: - Info Section

    private var infoSection: some View {
        HStack(spacing: Spacing.sm) {
            infoCard(
                icon: "list.bullet",
                value: "\(quiz.totalQuestions)",
                label: "Questions",
                color: ColorTokens.primary
            )

            if let timeLimit = quiz.timeLimit {
                infoCard(
                    icon: "clock",
                    value: "\(timeLimit / 60)",
                    label: "Minutes",
                    color: ColorTokens.info
                )
            }

            if let tpq = quiz.timePerQuestion {
                infoCard(
                    icon: "timer",
                    value: "\(tpq)s",
                    label: "Per Question",
                    color: ColorTokens.warning
                )
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private func infoCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            Text(value)
                .font(Typography.monoLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Expectation Section

    private var expectationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("What to Expect")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.sm) {
                expectationRow(
                    icon: "brain.head.profile",
                    text: "Multiple choice questions to test your understanding"
                )

                expectationRow(
                    icon: "arrow.counterclockwise",
                    text: "You can skip questions and come back later"
                )

                if quiz.timePerQuestion != nil {
                    expectationRow(
                        icon: "timer",
                        text: "Timed quiz — manage your time wisely"
                    )
                }

                expectationRow(
                    icon: "chart.bar.fill",
                    text: "Get detailed analysis of your performance"
                )
            }
        }
    }

    private func expectationRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.primary)
                .frame(width: 28, height: 28)
                .background(ColorTokens.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(text)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Source Content Section

    private var sourceContentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textTertiaryDark)

                Text("Based on \(quiz.sourceContentIds?.count ?? 0) content items")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
            .padding(.horizontal, Spacing.md)

            if let ids = quiz.sourceContentIds {
                ForEach(ids, id: \.self) { contentId in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.textTertiaryDark)

                        Text(contentId)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                    .padding(Spacing.md)
                    .background(ColorTokens.surfaceDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    // MARK: - Expiry Banner

    private func expiryBanner(_ expiresAt: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.warning)

            Text("This quiz expires \(formatExpiryDate(expiresAt))")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.warning)

            Spacer()
        }
        .padding(Spacing.md)
        .background(ColorTokens.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(ColorTokens.warning.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Helpers

    private var quizTypeIcon: String {
        switch quiz.type {
        case .topicConsolidation: return "books.vertical"
        case .weeklyReview: return "calendar.badge.clock"
        case .milestoneAssessment: return "flag.checkered"
        case .retentionCheck: return "brain"
        case .onDemand: return "sparkles"
        case .playlistMastery: return "music.note.list"
        }
    }

    private var quizTypeColor: Color {
        switch quiz.type {
        case .topicConsolidation: return ColorTokens.primary
        case .weeklyReview: return ColorTokens.info
        case .milestoneAssessment: return ColorTokens.anchorGold
        case .retentionCheck: return ColorTokens.warning
        case .onDemand: return ColorTokens.success
        case .playlistMastery: return ColorTokens.primaryLight
        }
    }

    private var quizTypeLabel: String {
        switch quiz.type {
        case .topicConsolidation: return "Topic Consolidation"
        case .weeklyReview: return "Weekly Review"
        case .milestoneAssessment: return "Milestone Assessment"
        case .retentionCheck: return "Retention Check"
        case .onDemand: return "On Demand"
        case .playlistMastery: return "Playlist Mastery"
        }
    }

    private func formatExpiryDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: .now)
        }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: .now)
    }
}
