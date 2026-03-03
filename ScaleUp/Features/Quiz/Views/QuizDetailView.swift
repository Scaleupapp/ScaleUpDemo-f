import SwiftUI

struct QuizDetailView: View {
    let quiz: Quiz
    @State private var showSession = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Hero section
                    heroSection

                    // Quick stats
                    statsGrid

                    // Difficulty breakdown
                    difficultySection

                    // Topics covered
                    if !uniqueConcepts.isEmpty {
                        topicsSection
                    }

                    // Expiry warning
                    if let expiryText = quiz.expiresInText {
                        expiryBanner(expiryText)
                    }

                    // Start button
                    startButton

                    Spacer().frame(height: Spacing.xxxl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showSession) {
            QuizSessionView(quiz: quiz)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            // Back button
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

            // Icon
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: quiz.type.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.gold)
            }

            // Type badge
            HStack(spacing: 4) {
                Image(systemName: quiz.type.icon)
                    .font(.system(size: 10))
                Text(quiz.type.displayName)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(ColorTokens.gold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(ColorTokens.gold.opacity(0.12))
            .clipShape(Capsule())

            // Title
            Text(quiz.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Topic
            Text(quiz.topic.capitalized)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statBox(value: "\(quiz.totalQuestions)", label: "Questions", icon: "list.bullet")
            statBox(value: "~\(quiz.estimatedMinutes)m", label: "Duration", icon: "clock")
            statBox(value: "\(quiz.timePerQuestionSeconds)s", label: "Per Question", icon: "timer")
        }
    }

    private func statBox(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.gold)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Difficulty

    private var difficultySection: some View {
        let dist = quiz.difficultyDistribution

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Difficulty Mix")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                difficultyBar(label: "Easy", count: dist.easy, color: .green, total: quiz.totalQuestions)
                difficultyBar(label: "Medium", count: dist.medium, color: .orange, total: quiz.totalQuestions)
                difficultyBar(label: "Hard", count: dist.hard, color: .red, total: quiz.totalQuestions)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
        )
    }

    private func difficultyBar(label: String, count: Int, color: Color, total: Int) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(width: 28)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 28, height: total > 0 ? geo.size.height * CGFloat(count) / CGFloat(total) : 0)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 40)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Topics

    private var uniqueConcepts: [String] {
        let concepts = quiz.questions.compactMap { $0.concept }
        return Array(Set(concepts)).sorted()
    }

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Topics Covered")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)

            FlowLayout(spacing: 6) {
                ForEach(uniqueConcepts, id: \.self) { concept in
                    Text(concept)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Expiry Banner

    private func expiryBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 14))
                .foregroundStyle(.orange)

            Text("Expires in \(text)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            Haptics.medium()
            showSession = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: quiz.status == .inProgress ? "play.fill" : "bolt.fill")
                    .font(.system(size: 14))
                Text(quiz.status == .inProgress ? "Continue Quiz" : "Start Quiz")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ColorTokens.gold)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// FlowLayout is defined in InterestsStepView.swift and shared across the app
