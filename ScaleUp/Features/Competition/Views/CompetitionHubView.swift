import SwiftUI

struct CompetitionHubView: View {
    @State private var challenges: [DailyChallenge] = []
    @State private var events: [LiveEvent] = []
    @State private var isLoading = true

    private let service = CompetitionService()
    private let gold = Color(hex: 0xFFD700)

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(gold)
            } else {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        if !challenges.isEmpty {
                            todayChallengesSection
                        }

                        leaderboardLink

                        if !events.isEmpty {
                            upcomingEventsSection
                        }

                        if challenges.isEmpty && events.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.top, Spacing.md)
                }
            }
        }
        .navigationTitle("Competitions")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: DailyChallenge.self) { challenge in
            ChallengeSessionView(challengeId: challenge.id, topic: challenge.topic)
        }
        .navigationDestination(for: LiveEvent.self) { event in
            LiveEventLobbyView(event: event)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Today's Challenges

    private var todayChallengesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("TODAY'S CHALLENGES")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(gold)
                .padding(.horizontal, Spacing.lg)

            ForEach(challenges) { challenge in
                NavigationLink(value: challenge) {
                    challengeRow(challenge)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func challengeRow(_ challenge: DailyChallenge) -> some View {
        let isCompleted = challenge.status == "completed"
        return HStack(spacing: Spacing.md) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "bolt.fill")
                .font(.system(size: 20))
                .foregroundStyle(isCompleted ? .green : gold)

            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.topic)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(isCompleted ? "Completed" : "\(challenge.participantCount) playing")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()

            if !isCompleted {
                Text("Play")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(gold)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Leaderboard Link

    private var leaderboardLink: some View {
        NavigationLink {
            LeaderboardView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(gold)

                Text("Leaderboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.md)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Upcoming Events

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("UPCOMING LIVE EVENTS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color(hex: 0x8B5CF6))
                .padding(.horizontal, Spacing.lg)

            ForEach(events) { event in
                NavigationLink(value: event) {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: 0x8B5CF6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.topic)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(event.participantCount) joined")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }

                        Spacer()

                        Text("Join")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(hex: 0x8B5CF6))
                            .clipShape(Capsule())
                    }
                    .padding(Spacing.md)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundStyle(gold.opacity(0.4))
            Text("No challenges today")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
            Text("Check back tomorrow!")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.top, 60)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        async let c: [DailyChallenge] = {
            (try? await service.fetchTodayChallenges()) ?? []
        }()
        async let e: [LiveEvent] = {
            (try? await service.fetchUpcomingEvents()) ?? []
        }()
        challenges = await c
        events = await e
        isLoading = false
    }
}
