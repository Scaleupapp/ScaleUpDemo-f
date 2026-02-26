import SwiftUI

// MARK: - Quiz History View

struct QuizHistoryView: View {
    @Environment(DependencyContainer.self) private var dependencies

    @State private var attempts: [QuizAttempt] = []
    @State private var isLoading = false
    @State private var error: APIError?
    @State private var selectedAttempt: QuizAttempt?

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if isLoading && attempts.isEmpty {
                historySkeleton
            } else if let error, attempts.isEmpty {
                ErrorStateView(
                    message: error.localizedDescription,
                    retryAction: {
                        Task { await loadHistory() }
                    }
                )
            } else if attempts.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Quiz History",
                    subtitle: "Completed quizzes will appear here."
                )
            } else {
                historyList
            }
        }
        .navigationTitle("Quiz History")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if attempts.isEmpty {
                await loadHistory()
            }
        }
        .sheet(item: $selectedAttempt) { attempt in
            QuizResultsView(quizId: attempt.quizId, preloadedAttempt: attempt)
                .environment(dependencies)
        }
    }

    // MARK: - History List

    private var historyList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.sm) {
                ForEach(sortedAttempts) { attempt in
                    Button {
                        selectedAttempt = attempt
                    } label: {
                        historyRow(attempt: attempt)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            await loadHistory()
        }
    }

    // MARK: - History Row

    private func historyRow(attempt: QuizAttempt) -> some View {
        HStack(spacing: Spacing.md) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(scoreColor(attempt.score?.percentage ?? 0).opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: (attempt.score?.percentage ?? 0) / 100)
                    .stroke(scoreColor(attempt.score?.percentage ?? 0), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(attempt.score?.percentage ?? 0))%")
                    .font(Typography.micro)
                    .foregroundStyle(scoreColor(attempt.score?.percentage ?? 0))
            }
            .frame(width: 44, height: 44)

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text("Quiz \(attempt.quizId.prefix(8))...")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(1)

                Text(formatDate(attempt.completedAt ?? attempt.startedAt))
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            Spacer()

            // Score details
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text("\(attempt.score?.correct ?? 0)/\(attempt.score?.total ?? 0)")
                        .font(Typography.mono)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                }

                // Trend arrow
                if let comparison = attempt.analysis?.comparisonToPrevious,
                   let trend = comparison.trend {
                    HStack(spacing: 2) {
                        Image(systemName: trendIcon(trend))
                            .font(.system(size: 10))
                        if let improvement = comparison.improvement {
                            Text("\(Int(abs(improvement)))%")
                                .font(Typography.micro)
                        }
                    }
                    .foregroundStyle(trendColor(trend))
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Skeleton

    private var historySkeleton: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonLoader(height: 72, cornerRadius: CornerRadius.medium)
                        .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Load

    private func loadHistory() async {
        isLoading = true
        error = nil

        do {
            attempts = try await dependencies.quizService.history()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Computed

    private var sortedAttempts: [QuizAttempt] {
        attempts.sorted { a, b in
            let dateA = a.completedAt ?? a.startedAt
            let dateB = b.completedAt ?? b.startedAt
            return dateA > dateB
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ percentage: Double) -> Color {
        switch percentage {
        case 80...100: return ColorTokens.success
        case 60..<80: return ColorTokens.primary
        case 40..<60: return ColorTokens.warning
        default: return ColorTokens.error
        }
    }

    private func trendIcon(_ trend: Trend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .improving: return ColorTokens.success
        case .declining: return ColorTokens.error
        case .stable: return ColorTokens.info
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatRelativeDate(date)
        }
        return formatRelativeDate(date)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}
