import SwiftUI

struct SeeAllContentView: View {
    let title: String
    let items: [Content]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            contentCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }

    private func contentCard(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                placeholder(for: content)
                            }
                        }
                    } else {
                        placeholder(for: content)
                    }
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if !content.overlayBadge.isEmpty {
                    Text(content.overlayBadge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(6)
                }
            }

            Text(content.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let creator = content.creatorId {
                Text(creator.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private func placeholder(for content: Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [ColorTokens.surfaceElevated, ColorTokens.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: content.contentType == .video ? "play.fill" : "doc.text")
                .font(.system(size: 22))
                .foregroundStyle(ColorTokens.gold.opacity(0.5))
        }
    }
}
