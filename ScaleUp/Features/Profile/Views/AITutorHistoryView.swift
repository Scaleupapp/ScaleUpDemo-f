import SwiftUI

// MARK: - AI Tutor History View

struct AITutorHistoryView: View {
    @State private var conversations: [TutorConversationSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteAlert = false
    @State private var conversationToDelete: TutorConversationSummary?
    @State private var selectedConversation: TutorConversationSummary?
    @State private var showChat = false
    @State private var chatViewModel = AITutorViewModel()

    private let service = AITutorService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading && conversations.isEmpty {
                ProgressView()
                    .tint(ColorTokens.gold)
            } else if conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .navigationTitle("AI Tutor History")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadConversations()
        }
        .alert("Delete Conversation", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let conv = conversationToDelete {
                    Task { await deleteConversation(conv) }
                }
            }
        } message: {
            Text("Delete this conversation? This can't be undone.")
        }
        .sheet(isPresented: $showChat) {
            if let conv = selectedConversation {
                AITutorSheetView(
                    contentId: conv.contentId,
                    contentTitle: conv.contentTitle ?? "Content",
                    viewModel: chatViewModel
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: showChat) {
            if !showChat {
                // Refresh list when chat is dismissed
                Task { await loadConversations() }
            }
        }
    }

    // MARK: - List

    private var conversationList: some View {
        List {
            ForEach(conversations) { conv in
                Button {
                    chatViewModel = AITutorViewModel()
                    selectedConversation = conv
                    showChat = true
                } label: {
                    conversationCard(conv)
                }
                .buttonStyle(.plain)
                .listRowBackground(ColorTokens.surface)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        conversationToDelete = conv
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    // MARK: - Conversation Card

    private func conversationCard(_ conv: TutorConversationSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title
            Text(conv.contentTitle ?? "Conversation")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)

            // Domain + tier
            HStack(spacing: Spacing.sm) {
                if let domain = conv.contentDomain, !domain.isEmpty {
                    Text(domain.capitalized)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                tierBadge(conv.tutorTier)
            }

            // Last message preview
            if let last = conv.lastMessage {
                Text(last.preview)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(2)
            }

            // Meta
            HStack(spacing: Spacing.xs) {
                Text("\(conv.messageCount) messages")
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiary)

                Text("•")
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiary)

                Text(conv.timeAgo)
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Tier Badge

    private func tierBadge(_ tier: TutorTier) -> some View {
        HStack(spacing: 2) {
            Image(systemName: tier == .full ? "sparkles" : "exclamationmark.circle")
                .font(.system(size: 8))
            Text(tier == .full ? "Full" : "Limited")
                .font(Typography.micro)
        }
        .foregroundStyle(tier == .full ? ColorTokens.gold : ColorTokens.warning)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background((tier == .full ? ColorTokens.gold : ColorTokens.warning).opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)

            Text("No AI Tutor conversations yet")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Start a conversation while watching any video")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }

    // MARK: - Actions

    private func loadConversations() async {
        isLoading = true
        do {
            conversations = try await service.listConversations()
        } catch {
            print("[AITutor] Load conversations failed: \(error)")
            errorMessage = "Could not load conversations"
        }
        isLoading = false
    }

    private func deleteConversation(_ conv: TutorConversationSummary) async {
        do {
            try await service.deleteConversation(contentId: conv.contentId)
            conversations.removeAll { $0.id == conv.id }
            Haptics.success()
        } catch {
            print("[AITutor] Delete conversation failed: \(error)")
            Haptics.error()
        }
    }
}
