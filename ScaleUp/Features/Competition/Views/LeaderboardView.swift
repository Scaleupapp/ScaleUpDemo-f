import SwiftUI

struct LeaderboardView: View {
    @State private var viewModel = LeaderboardViewModel()
    @State private var selectedScope: LeaderboardScope = .thisWeek
    @State private var selectedFilter: LeaderboardFilter = .global
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum LeaderboardScope: String, CaseIterable {
        case thisWeek = "This Week"
        case allTime = "All Time"
    }

    enum LeaderboardFilter: String, CaseIterable {
        case global = "Global"
        case byTopic = "By Topic"
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filterControls
                leaderboardContent
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadAll()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Circle())
            }

            Spacer()

            Text("Leaderboard")
                .font(Typography.titleLarge)
                .foregroundStyle(.white)

            Spacer()

            // Balance spacer
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Filter Controls

    private var filterControls: some View {
        VStack(spacing: Spacing.sm) {
            // Global / By Topic segmented control
            Picker("Filter", selection: $selectedFilter) {
                ForEach(LeaderboardFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.lg)

            // This Week / All Time
            Picker("Scope", selection: $selectedScope) {
                ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Content

    private var leaderboardContent: some View {
        Group {
            if viewModel.isLoading && viewModel.weeklyBoard == nil {
                loadingState
            } else if let board = viewModel.weeklyBoard {
                leaderboardList(board)
            } else if let error = viewModel.error {
                errorState(error)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Leaderboard List

    private func leaderboardList(_ board: WeeklyLeaderboard) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Pinned "You" row at top
                if let currentUserId = appState.currentUser?.id,
                   let myEntry = board.entries.first(where: { $0.userId.id == currentUserId }) {
                    yourRow(entry: myEntry, rank: entryRank(myEntry, in: board.entries))
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                }

                // Week info
                weekInfoBar(board)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                // All entries
                ForEach(Array(sortedEntries(board.entries).enumerated()), id: \.element.id) { index, entry in
                    let rank = index + 1
                    leaderboardRow(entry: entry, rank: rank)
                        .padding(.horizontal, Spacing.lg)
                }
            }
            .padding(.bottom, Spacing.xxxl)
        }
        .refreshable {
            await viewModel.loadAll()
        }
    }

    // MARK: - Your Row (Pinned)

    private func yourRow(entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            rankBadge(rank)

            avatarView(user: entry.userId, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("You")
                        .font(Typography.bodySmallBold)
                        .foregroundStyle(.white)

                    Text("(Your Position)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                }

                Text("\(entry.challengesCompleted) challenges")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            Text("\(Int(entry.totalHandicappedScore))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.gold)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.gold.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Leaderboard Row

    private func leaderboardRow(entry: LeaderboardEntry, rank: Int) -> some View {
        let isCurrentUser = entry.userId.id == appState.currentUser?.id

        return HStack(spacing: Spacing.sm) {
            rankBadge(rank)

            avatarView(user: entry.userId, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "You" : entry.userId.displayName)
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(isCurrentUser ? ColorTokens.gold : .white)
                    .lineLimit(1)

                Text("\(entry.challengesCompleted) challenges")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            Text("\(Int(entry.totalHandicappedScore))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? ColorTokens.gold : .white)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? ColorTokens.gold.opacity(0.06) : Color.clear)
        )
    }

    // MARK: - Rank Badge

    private func rankBadge(_ rank: Int) -> some View {
        Group {
            if rank <= 3 {
                Text(rankEmoji(rank))
                    .font(.system(size: 22))
                    .frame(width: 32)
            } else {
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(width: 32)
            }
        }
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "\u{1F947}"  // gold medal
        case 2: return "\u{1F948}"  // silver medal
        case 3: return "\u{1F949}"  // bronze medal
        default: return "\(rank)"
        }
    }

    // MARK: - Avatar

    private func avatarView(user: LeaderboardUser, size: CGFloat) -> some View {
        Group {
            if let pic = user.profilePicture, let url = URL(string: pic) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        avatarPlaceholder(user: user, size: size)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                avatarPlaceholder(user: user, size: size)
            }
        }
    }

    private func avatarPlaceholder(user: LeaderboardUser, size: CGFloat) -> some View {
        Circle()
            .fill(ColorTokens.surfaceElevated)
            .frame(width: size, height: size)
            .overlay(
                Text(String(user.displayName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            )
    }

    // MARK: - Week Info

    private func weekInfoBar(_ board: WeeklyLeaderboard) -> some View {
        HStack {
            Text("\(board.participantCount) participants")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()

            if board.finalized {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                    Text("Finalized")
                        .font(Typography.caption)
                }
                .foregroundStyle(ColorTokens.success)
            } else {
                Text(board.topic)
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            ProgressView()
                .tint(ColorTokens.gold)
            Text("Loading leaderboard...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.warning)
            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadAll() }
            }
            .font(Typography.bodySmallBold)
            .foregroundStyle(ColorTokens.gold)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "list.number")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("No leaderboard data yet")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
            Text("Complete challenges to appear on the board!")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func sortedEntries(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        entries.sorted { $0.totalHandicappedScore > $1.totalHandicappedScore }
    }

    private func entryRank(_ entry: LeaderboardEntry, in entries: [LeaderboardEntry]) -> Int {
        let sorted = sortedEntries(entries)
        return (sorted.firstIndex(where: { $0.id == entry.id }) ?? 0) + 1
    }
}
