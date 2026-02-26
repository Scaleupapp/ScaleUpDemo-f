import SwiftUI

// MARK: - Comments Section

/// Reusable comments component showing a comment count header,
/// an "add a comment" text field, and a threaded comment list.
/// Also used by ContentDetailView.
struct CommentsSection: View {

    let comments: [Comment]
    let commentCount: Int
    let isLoading: Bool
    let isSubmitting: Bool
    @Binding var newCommentText: String

    var currentUserId: String?
    var onSubmit: () -> Void
    var onDelete: ((Comment) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Comment count header
            commentHeader

            // Add comment field
            addCommentField

            // Comments list
            commentsList
        }
    }

    // MARK: - Comment Header

    private var commentHeader: some View {
        HStack {
            Text("Comments")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("(\(commentCount))")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Spacer()
        }
    }

    // MARK: - Add Comment Field

    private var addCommentField: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Add a comment...", text: $newCommentText)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.horizontal, Spacing.md)
                .frame(height: 40)
                .background(ColorTokens.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.full))

            if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(ColorTokens.primary)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .opacity(isSubmitting ? 0.5 : 1.0)
            }
        }
    }

    // MARK: - Comments List

    private var commentsList: some View {
        Group {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(ColorTokens.primary)
                    Spacer()
                }
                .padding(Spacing.md)
            } else if comments.isEmpty {
                Text("No comments yet. Be the first to share your thoughts!")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                    .padding(.vertical, Spacing.md)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedComments) { comment in
                        commentRow(comment)
                    }
                }
            }
        }
    }

    // MARK: - Sorted Comments

    /// Groups comments so threaded replies appear after their parent,
    /// indented with extra leading padding.
    private var sortedComments: [Comment] {
        // Separate root comments and replies
        let rootComments = comments.filter { $0.parentId == nil }
        let replies = comments.filter { $0.parentId != nil }

        var sorted: [Comment] = []

        for root in rootComments {
            sorted.append(root)
            // Append any replies to this root comment
            let childReplies = replies.filter { $0.parentId == root.id }
            sorted.append(contentsOf: childReplies)
        }

        // Append orphan replies (parentId set but parent not found in this page)
        let sortedIds = Set(sorted.map(\.id))
        let orphans = replies.filter { !sortedIds.contains($0.id) }
        sorted.append(contentsOf: orphans)

        return sorted
    }

    // MARK: - Comment Row

    private func commentRow(_ comment: Comment) -> some View {
        let isReply = comment.parentId != nil
        let isOwnComment = currentUserId != nil && comment.userId.id == currentUserId

        return HStack(alignment: .top, spacing: Spacing.sm) {
            CreatorAvatar(
                imageURL: comment.userId.profilePicture,
                name: "\(comment.userId.firstName) \(comment.userId.lastName)",
                size: 32
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("\(comment.userId.firstName) \(comment.userId.lastName)")
                        .font(Typography.bodySmall.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text(timeAgo(from: comment.createdAt))
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                Text(comment.text)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
        .padding(.leading, isReply ? Spacing.xl : 0)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isOwnComment, let onDelete {
                Button(role: .destructive) {
                    onDelete(comment)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Time Ago Helper

    private func timeAgo(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return ""
            }
            return relativeTime(from: date)
        }
        return relativeTime(from: date)
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        }
    }
}
