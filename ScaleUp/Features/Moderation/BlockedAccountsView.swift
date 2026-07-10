import SwiftUI

/// Lists the accounts the user has blocked and lets them unblock.
struct BlockedAccountsView: View {
    @State private var blocked: [BlockedUser] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if blocked.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "hand.raised.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("No blocked accounts")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text("People you block won't see your content, and you won't see theirs.")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(blocked) { user in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                if let u = user.username, !u.isEmpty {
                                    Text("@\(u)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                            }
                            Spacer()
                            Button("Unblock") { Task { await unblock(user) } }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.gold)
                                .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(ColorTokens.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Blocked Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        blocked = (try? await ModerationService.shared.listBlocked()) ?? []
        isLoading = false
    }

    private func unblock(_ user: BlockedUser) async {
        do {
            try await ModerationService.shared.unblockUser(user.id)
            blocked.removeAll { $0.id == user.id }
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }
}
