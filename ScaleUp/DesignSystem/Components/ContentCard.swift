import SwiftUI

struct ContentCard: View {
    let content: Content
    var width: CGFloat = 200
    var progress: Double? = nil

    private var height: CGFloat { width * 9 / 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Thumbnail with overlays
            thumbnailImage
                .frame(width: width, height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 3) {
                        contentTypeBadge
                        if content.isNew {
                            Text("NEW")
                                .font(Typography.micro)
                                .foregroundStyle(ColorTokens.buttonPrimaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ColorTokens.gold)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(6)
                }
                .overlay(alignment: .bottomTrailing) {
                    if !content.overlayBadge.isEmpty {
                        Text(content.overlayBadge)
                            .font(Typography.micro)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let progress, progress > 0 {
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(ColorTokens.gold)
                                    .frame(width: geo.size.width * progress, height: 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

            // Title
            Text(content.title)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)

            // Creator
            if let creator = content.creatorId {
                HStack(spacing: 4) {
                    Text(creator.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)

                    if let tier = creator.tier {
                        TierBadge(tier: tier, compact: true)
                    }
                }
            }
        }
        .frame(width: width)
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let url = content.thumbnailURL, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    thumbnailPlaceholder
                default:
                    SkeletonLoader()
                }
            }
        } else {
            thumbnailPlaceholder
        }
    }

    private var contentTypeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: content.contentType.badgeIcon)
                .font(.system(size: 9, weight: .bold))
            Text(content.contentType.badgeLabel)
                .font(.system(size: 10, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(content.contentType.badgeColor)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            ColorTokens.surfaceElevated
            Image(systemName: content.contentType == .video ? "play.rectangle.fill" : "doc.text.fill")
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
}
