import SwiftUI

// MARK: - Recommended Row

struct RecommendedRow: View {
    let items: [Content]
    var seeAllAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Recommended For You", seeAllAction: seeAllAction)

            HorizontalCarousel(items: items) { content in
                NavigationLink(value: content) {
                    ContentCard(
                        title: content.title,
                        creatorName: content.creator.firstName + " " + content.creator.lastName,
                        domain: content.domain,
                        thumbnailURL: content.resolvedThumbnailURL,
                        duration: content.duration,
                        rating: content.averageRating > 0 ? content.averageRating : nil,
                        viewCount: content.viewCount > 0 ? content.viewCount : nil,
                        isNew: isNewContent(content)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isNewContent(_ content: Content) -> Bool {
        guard let published = content.publishedAt else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: published) else { return false }
        return date.timeIntervalSinceNow > -7 * 24 * 60 * 60 // Within last 7 days
    }
}
