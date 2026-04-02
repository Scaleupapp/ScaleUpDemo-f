import SwiftUI

struct ContentCardWide: View {
    let content: Content

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail
            thumbnailImage
                .aspectRatio(16/9, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

            // Text overlay
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(content.title)
                    .font(Typography.titleMedium)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let creator = content.creatorId {
                    HStack(spacing: Spacing.sm) {
                        CreatorAvatar(creator: creator, size: 24)
                        Text(creator.displayName)
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        if let tier = creator.tier {
                            TierBadge(tier: tier)
                        }
                    }
                }

                HStack(spacing: Spacing.md) {
                    if !content.overlayBadge.isEmpty {
                        Label(content.overlayBadge, systemImage: "clock")
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if let views = content.viewCount, views > 0 {
                        Label(formatCount(views), systemImage: "eye")
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(Spacing.md)
        }
        .overlay(alignment: .topLeading) {
            contentTypeBadge
                .padding(Spacing.sm)
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if content.contentType == .notes {
            NotesThumbnail(title: content.title, domain: content.domain, pageCount: content.pageCount)
        } else if let url = content.thumbnailURL, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                case .failure:
                    placeholder
                default:
                    SkeletonLoader()
                }
            }
        } else {
            placeholder
        }
    }

    private var contentTypeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: content.contentType.badgeIcon)
                .font(.system(size: 10, weight: .bold))
            Text(content.contentType.badgeLabel)
                .font(.system(size: 11, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(content.contentType.badgeColor)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }

    private var placeholder: some View {
        ZStack {
            if content.contentType == .notes {
                notesPlaceholder
            } else {
                ColorTokens.surfaceElevated
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var notesPlaceholder: some View {
        NotesThumbnail(title: content.title, domain: content.domain, pageCount: content.pageCount)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
