import SwiftUI

struct ConsumptionHistoryView: View {
    @State private var history: [ContentProgress] = []
    @State private var isLoading = false
    @State private var currentPage = 1

    private let knowledgeService = KnowledgeService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading && history.isEmpty {
                ProgressView()
                    .tint(ColorTokens.gold)
            } else if history.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(history) { item in
                            NavigationLink(value: item.content ?? Content.placeholder(id: item.contentId)) {
                                historyRow(item)
                            }
                            .buttonStyle(.plain)
                        }

                        // Load more
                        if history.count >= currentPage * 20 {
                            Button {
                                Task { await loadMore() }
                            } label: {
                                Text("Load More")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ColorTokens.gold)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(ColorTokens.gold.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        Spacer().frame(height: Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            }
        }
        .navigationTitle("Learning History")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Content.self) { content in
            ContentDestinationView(content: content)
        }
        .task {
            await loadHistory()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "clock.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("No History Yet")
                .font(Typography.titleMedium)
                .foregroundStyle(.white)
            Text("Start consuming content to build your history.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func historyRow(_ item: ContentProgress) -> some View {
        HStack(spacing: Spacing.sm) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 72, height: 48)

                if let url = item.content?.thumbnailURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .frame(width: 72, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Progress overlay
                if let pct = item.percentageCompleted, pct < 100 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(.black.opacity(0.5))
                                Rectangle()
                                    .fill(ColorTokens.gold)
                                    .frame(width: geo.size.width * CGFloat(pct) / 100)
                            }
                        }
                        .frame(height: 3)
                    }
                    .frame(width: 72, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Completion badge
                if item.isCompleted == true {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.success)
                        .background(
                            Circle()
                                .fill(ColorTokens.background)
                                .frame(width: 18, height: 18)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.content?.title ?? "Content")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let pct = item.percentageCompleted {
                        Text(pct >= 100 ? "Completed" : "\(pct)% done")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(pct >= 100 ? ColorTokens.success : ColorTokens.gold)
                    }

                    if let time = item.totalTimeSpent {
                        Text(formatDuration(time))
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    if let topic = item.content?.topics?.first {
                        Text(topic)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(ColorTokens.gold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ColorTokens.gold.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
        )
    }

    private func loadHistory() async {
        isLoading = true
        currentPage = 1

        let result = try? await knowledgeService.getHistory(page: 1, limit: 20)
        history = result ?? mockHistory

        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        let result = try? await knowledgeService.getHistory(page: currentPage, limit: 20)
        if let newItems = result {
            history.append(contentsOf: newItems)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(mins)m"
    }

    private var mockHistory: [ContentProgress] {
        [
            ContentProgress(
                contentId: "h1", currentPosition: 1200, totalDuration: 1200, percentageCompleted: 100,
                isCompleted: true, totalTimeSpent: 1200, sessionCount: 1,
                content: Content(id: "h1", creatorId: nil, title: "Understanding Product-Market Fit", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1200, sourceType: .youtube, sourceAttribution: nil, domain: "Product Management", topics: ["Product-Market Fit"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 5200, likeCount: 340, commentCount: 28, saveCount: 190, averageRating: 4.6, ratingCount: 89, publishedAt: Date(), createdAt: nil)
            ),
            ContentProgress(
                contentId: "h2", currentPosition: 810, totalDuration: 1800, percentageCompleted: 45,
                isCompleted: false, totalTimeSpent: 810, sessionCount: 2,
                content: Content(id: "h2", creatorId: nil, title: "Customer Discovery Interviews", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1800, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: ["User Research"], tags: nil, difficulty: .beginner, aiData: nil, status: .published, viewCount: 3100, likeCount: 210, commentCount: 15, saveCount: 120, averageRating: 4.8, ratingCount: 56, publishedAt: Date(), createdAt: nil)
            ),
            ContentProgress(
                contentId: "h3", currentPosition: 600, totalDuration: 600, percentageCompleted: 100,
                isCompleted: true, totalTimeSpent: 600, sessionCount: 1,
                content: Content(id: "h3", creatorId: nil, title: "Metrics That Matter: North Star & KPIs", description: nil, contentType: .article, contentURL: nil, thumbnailURL: nil, duration: 600, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: ["Metrics"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 2400, likeCount: 150, commentCount: 8, saveCount: 90, averageRating: 4.5, ratingCount: 34, publishedAt: Date(), createdAt: nil)
            )
        ]
    }
}

// MARK: - Content Placeholder Extension

extension Content {
    static func placeholder(id: String) -> Content {
        Content(id: id, creatorId: nil, title: "Content", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: nil, sourceType: .original, sourceAttribution: nil, domain: nil, topics: nil, tags: nil, difficulty: nil, aiData: nil, status: .published, viewCount: nil, likeCount: nil, commentCount: nil, saveCount: nil, averageRating: nil, ratingCount: nil, publishedAt: nil, createdAt: nil)
    }
}
