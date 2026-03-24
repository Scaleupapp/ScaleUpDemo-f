import SwiftUI

struct DailyChallengeCarousel: View {
    let challenges: [DailyChallenge]
    let upcomingEvents: [LiveEvent]
    let stats: CompetitionStats?

    @Environment(ObjectiveContext.self) private var objectiveContext

    @State private var currentPage = 0

    private var totalPages: Int {
        challenges.count + upcomingEvents.count
    }

    var body: some View {
        if totalPages > 0 {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(challenges.enumerated()), id: \.element.id) { index, challenge in
                            challengeCard(challenge)
                                .containerRelativeFrame(.horizontal)
                                .id(index)
                        }

                        ForEach(Array(upcomingEvents.enumerated()), id: \.element.id) { index, event in
                            liveEventCard(event)
                                .containerRelativeFrame(.horizontal)
                                .id(challenges.count + index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: Binding(
                    get: { currentPage as Int? },
                    set: { currentPage = $0 ?? 0 }
                ))
                .frame(height: 180)

                if totalPages > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Active Challenge Card

    private func challengeCard(_ challenge: DailyChallenge) -> some View {
        let isCompleted = challenge.isCompletedByUser

        return Group {
            if isCompleted {
                completedChallengeCard(challenge)
            } else {
                activeChallengeCard(challenge)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private func activeChallengeCard(_ challenge: DailyChallenge) -> some View {
        let objective = objectiveContext.activeObjective
        let isGoalTopic = objective?.targetRole?.localizedCaseInsensitiveContains(challenge.topic) == true
            || objective?.targetSkill?.localizedCaseInsensitiveContains(challenge.topic) == true
            || objective?.objectiveType?.localizedCaseInsensitiveContains(challenge.topic) == true

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\u{26A1} Today's Challenge")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFFD700))

                Spacer()

                if isGoalTopic {
                    Text("Your Goal")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: 0xFFD700))
                        .clipShape(Capsule())
                }
            }

            Text(challenge.topic)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("15 Qs \u{00B7} \(challenge.participantCount) playing \u{00B7} Ends midnight")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()

            NavigationLink(value: challenge) {
                HStack(spacing: 6) {
                    Text("Take the Challenge")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0xFFD700), Color(hex: 0xFFA500)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: 0xFFD700).opacity(0.5), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Completed Challenge Card

    private func completedChallengeCard(_ challenge: DailyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Completed")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color(hex: 0x22C55E))

                Spacer()

                if let score = challenge.userScore {
                    Text("\(Int(score)) pts")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFFD700))
                }
            }

            Text(challenge.topic)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let stats = stats, stats.challengeStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("\(stats.challengeStreak) day streak")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            NavigationLink(value: LeaderboardDestination()) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11))
                    Text("View Results")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: 0x22C55E))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: 0x22C55E).opacity(0.5), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Live Event Card

    private func liveEventCard(_ event: LiveEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: 0x8B5CF6))
                        .frame(width: 6, height: 6)
                    Text("LIVE EVENT")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                }
                .foregroundStyle(Color(hex: 0x8B5CF6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: 0x8B5CF6).opacity(0.15))
                .clipShape(Capsule())

                Spacer()

                Text("\(event.participantCount) joined")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Text(event.topic)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(countdownText(for: event))
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x8B5CF6).opacity(0.8))

            Spacer()

            NavigationLink(value: event) {
                HStack(spacing: 6) {
                    Text("Join")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: 0x8B5CF6))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: 0x8B5CF6).opacity(0.5), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Helpers

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    private func countdownText(for event: LiveEvent) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: event.scheduledAt) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: event.scheduledAt) else {
                return "Starting soon"
            }
            return formatCountdown(to: date)
        }
        return formatCountdown(to: date)
    }

    private func formatCountdown(to date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return "Starting now" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "Starts in \(hours)h \(minutes)m"
        } else {
            return "Starts in \(minutes)m"
        }
    }
}

