import SwiftUI

struct CompetitionHubView: View {
    @Environment(ObjectiveContext.self) private var objectiveContext
    @State private var challenges: [DailyChallenge] = []
    @State private var events: [LiveEvent] = []
    @State private var objectiveTopic: String? = nil
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var joiningEventId: String?

    private let service = CompetitionService()
    private let gold = Color(hex: 0xFFD700)
    private let purple = Color(hex: 0x8B5CF6)

    // MARK: - Filtered & Grouped

    private var myChallenge: DailyChallenge? {
        guard let topic = objectiveTopic?.lowercased() else { return nil }
        return challenges.first { $0.topic.lowercased() == topic }
    }

    private var otherChallenges: [DailyChallenge] {
        let myTopic = objectiveTopic?.lowercased()
        return challenges.filter { $0.topic.lowercased() != myTopic }
    }

    private var filteredOtherChallenges: [DailyChallenge] {
        guard !searchText.isEmpty else { return otherChallenges }
        return otherChallenges.filter { $0.topic.localizedCaseInsensitiveContains(searchText) }
    }

    private var myEvent: LiveEvent? {
        guard let topic = objectiveTopic?.lowercased() else { return nil }
        return events.first { $0.topic.lowercased() == topic }
    }

    private var otherEvents: [LiveEvent] {
        let myTopic = objectiveTopic?.lowercased()
        return events.filter { $0.topic.lowercased() != myTopic }
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(gold)
            } else {
                ScrollView {
                    VStack(spacing: Spacing.lg) {

                        // My Objective Challenge (pinned top)
                        if let challenge = myChallenge {
                            myObjectiveSection(challenge)
                        }

                        // Leaderboard
                        leaderboardLink

                        // Search
                        if otherChallenges.count > 3 {
                            searchBar
                        }

                        // Other Challenges
                        if !filteredOtherChallenges.isEmpty {
                            otherChallengesSection
                        }

                        // Live Events
                        if !events.isEmpty {
                            liveEventsSection
                        }

                        if challenges.isEmpty && events.isEmpty {
                            emptyState
                        }

                        Spacer().frame(height: 20)
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
        .task { await loadData() }
    }

    // MARK: - My Objective Challenge (Hero Card)

    private func myObjectiveSection(_ challenge: DailyChallenge) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(gold)
                Text("YOUR CHALLENGE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(gold)
            }
            .padding(.horizontal, Spacing.lg)

            if challenge.isCompletedByUser {
                // Completed state - show score, link to leaderboard
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
                                .foregroundStyle(gold)
                        }
                    }

                    Text(titleCase(challenge.topic))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    NavigationLink {
                        LeaderboardView()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 11))
                            Text("View Leaderboard")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(hex: 0x22C55E))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ColorTokens.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: 0x22C55E).opacity(0.4), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, Spacing.lg)
            } else {
                NavigationLink(value: challenge) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(titleCase(challenge.topic))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        Text("15 Questions \u{00B7} \(challenge.participantCount) playing")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)

                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("Take the Challenge")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(gold)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ColorTokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(gold.opacity(0.4), lineWidth: 1.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)
            }

            // My live event (if exists)
            if let event = myEvent {
                eventRow(event, isMyObjective: true)
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardLink: some View {
        NavigationLink {
            LeaderboardView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
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

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textTertiary)
            TextField("Search challenges...", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
        }
        .padding(10)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Other Challenges

    private var otherChallengesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("ALL CHALLENGES")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.horizontal, Spacing.lg)

            ForEach(filteredOtherChallenges) { challenge in
                NavigationLink(value: challenge) {
                    challengeRow(challenge)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func challengeRow(_ challenge: DailyChallenge) -> some View {
        let isCompleted = challenge.isCompletedByUser
        return HStack(spacing: Spacing.md) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "bolt.fill")
                .font(.system(size: 18))
                .foregroundStyle(isCompleted ? .green : gold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleCase(challenge.topic))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(isCompleted ? "Completed" : "\(challenge.participantCount) playing")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()

            if !isCompleted {
                Text("Play")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(gold)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Live Events

    private var liveEventsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("UPCOMING LIVE EVENTS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(purple)
                .padding(.horizontal, Spacing.lg)

            ForEach(otherEvents) { event in
                eventRow(event, isMyObjective: false)
            }
        }
    }

    private func eventRow(_ event: LiveEvent, isMyObjective: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 18))
                .foregroundStyle(purple)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(titleCase(event.topic))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if isMyObjective {
                        Text("Your Goal")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(gold)
                            .clipShape(Capsule())
                    }
                }
                Text(eventDateLabel(event))
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()

            if event.isJoinedByUser {
                NavigationLink(value: event) {
                    Text("Joined")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(purple.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(purple.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await joinEvent(event) }
                } label: {
                    if joiningEventId == event.id {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 40)
                            .padding(.vertical, 5)
                    } else {
                        Text("Join")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                    }
                }
                .background(purple)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(joiningEventId == event.id)
            }
        }
        .padding(12)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, Spacing.lg)
    }

    private func joinEvent(_ event: LiveEvent) async {
        joiningEventId = event.id
        do {
            _ = try await service.joinLiveEvent(id: event.id)
            events = (try? await service.fetchUpcomingEvents()) ?? events
        } catch {
            // Silently fail — user can try again
        }
        joiningEventId = nil
    }

    // MARK: - Empty

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

    // MARK: - Helpers

    private func titleCase(_ text: String) -> String {
        text.split(separator: " ").map { word in
            let lower = word.lowercased()
            // Keep small words lowercase unless first
            return String(lower.prefix(1).uppercased() + lower.dropFirst())
        }.joined(separator: " ")
    }

    private func eventDateLabel(_ event: LiveEvent) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: event.scheduledAt)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: event.scheduledAt)
        }
        guard let eventDate = date else { return "\(event.participantCount) joined" }

        let calendar = Calendar.current
        let displayFormatter = DateFormatter()

        if calendar.isDateInToday(eventDate) {
            displayFormatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(eventDate) {
            displayFormatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            displayFormatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        }

        return displayFormatter.string(from: eventDate) + " \u{00B7} \(event.participantCount) joined"
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        async let c: [DailyChallenge] = { (try? await service.fetchTodayChallenges()) ?? [] }()
        async let e: [LiveEvent] = { (try? await service.fetchUpcomingEvents()) ?? [] }()
        async let t: String? = { try? await service.fetchPrimaryObjectiveTopic() }()
        challenges = await c
        events = await e
        objectiveTopic = await t
        isLoading = false
    }
}
