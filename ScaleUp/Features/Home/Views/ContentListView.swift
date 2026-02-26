import SwiftUI
import NukeUI

// MARK: - Content List View

/// Full-screen list view shown when "See All" is tapped from a Home section.
struct ContentListView: View {
    let title: String
    let items: [Content]

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark.ignoresSafeArea()

            if items.isEmpty {
                Text("No content available")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                ContentListRow(content: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ColorTokens.backgroundDark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: Content.self) { content in
            ContentDetailView(contentId: content.id)
        }
    }
}

// MARK: - Content List Row

private struct ContentListRow: View {
    let content: Content

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                if let thumbnailURL = content.resolvedThumbnailURL, let url = URL(string: thumbnailURL) {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(ColorTokens.surfaceElevatedDark)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(ColorTokens.surfaceElevatedDark)
                        .overlay {
                            Image(systemName: "play.circle")
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }
                }

                // Duration
                if let duration = content.duration {
                    Text(formatDuration(duration))
                        .font(Typography.micro)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }
            .frame(width: 140, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            // Metadata
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(content.title)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(2)

                Text(content.creator.firstName + " " + content.creator.lastName)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                HStack(spacing: Spacing.sm) {
                    if content.viewCount > 0 {
                        Text("\(formatCount(content.viewCount)) views")
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                    Text(content.domain)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.primary)
                }
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes >= 60 {
            return String(format: "%d:%02d:%02d", minutes / 60, minutes % 60, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
