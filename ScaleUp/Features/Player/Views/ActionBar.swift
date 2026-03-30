import SwiftUI

struct ActionBar: View {
    let isLiked: Bool
    let isSaved: Bool
    let likeCount: Int
    let saveCount: Int
    let userRating: Int
    let onLike: () -> Void
    let onSave: () -> Void
    let onRate: (Int) -> Void
    let onShare: () -> Void
    let onPlaylist: () -> Void

    @State private var showRatingPicker = false

    var body: some View {
        HStack(spacing: 0) {
            // Like
            actionButton(
                icon: isLiked ? "heart.fill" : "heart",
                label: formatCount(likeCount),
                isActive: isLiked,
                action: onLike
            )

            // Save
            actionButton(
                icon: isSaved ? "bookmark.fill" : "bookmark",
                label: formatCount(saveCount),
                isActive: isSaved,
                action: onSave
            )

            // Rate
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showRatingPicker.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: userRating > 0 ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(userRating > 0 ? ColorTokens.gold : ColorTokens.textSecondary)

                    Text(userRating > 0 ? "\(userRating)/5" : "Rate")
                        .font(Typography.micro)
                        .foregroundStyle(userRating > 0 ? ColorTokens.gold : ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Playlist
            actionButton(
                icon: "text.badge.plus",
                label: "Playlist",
                isActive: false,
                action: onPlaylist
            )

            // Share
            actionButton(
                icon: "square.and.arrow.up",
                label: "Share",
                isActive: false,
                action: onShare
            )
        }
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .confirmationDialog("Rate this content", isPresented: $showRatingPicker) {
            ForEach(1...5, id: \.self) { star in
                Button(String(repeating: "★", count: star) + String(repeating: "☆", count: 5 - star)) {
                    onRate(star)
                }
            }
        }
    }

    // MARK: - Action Button

    private func actionButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? ColorTokens.gold : ColorTokens.textSecondary)

                Text(label)
                    .font(Typography.micro)
                    .foregroundStyle(isActive ? ColorTokens.gold : ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
        return "\(count)"
    }
}
