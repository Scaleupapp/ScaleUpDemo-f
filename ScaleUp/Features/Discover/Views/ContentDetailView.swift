import SwiftUI

// Non-video content detail (articles, infographics)
struct ContentDetailView: View {
    let content: Content

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Header image
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(ColorTokens.surfaceElevated)
                            .aspectRatio(16/9, contentMode: .fit)

                        Image(systemName: content.contentType == .article ? "doc.text.fill" : "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .padding(.horizontal, Spacing.lg)

                    // Title
                    Text(content.title)
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .padding(.horizontal, Spacing.lg)

                    // Creator
                    if let creator = content.creatorId {
                        HStack(spacing: Spacing.sm) {
                            CreatorAvatar(creator: creator, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(creator.displayName)
                                    .font(Typography.bodyBold)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                if let tier = creator.tier {
                                    TierBadge(tier: tier)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }

                    // Description
                    if let desc = content.description, !desc.isEmpty {
                        Text(desc)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.horizontal, Spacing.lg)
                    }

                    // Tags
                    if let tags = content.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.xs) {
                                ForEach(tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(Typography.caption)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ColorTokens.surfaceElevated)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                        }
                    }

                    Spacer().frame(height: Spacing.xxl)
                }
                .padding(.top, Spacing.md)
            }
        }
        .navigationTitle(content.contentType == .article ? "Article" : "Content")
        .navigationBarTitleDisplayMode(.inline)
    }
}
