import SwiftUI

struct GapsView: View {
    @State private var gaps: [KnowledgeGap] = []
    @State private var gapContent: [Content] = []
    @State private var isLoading = false

    private let knowledgeService = KnowledgeService()
    private let recommendationService = RecommendationService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading && gaps.isEmpty {
                ProgressView()
                    .tint(ColorTokens.gold)
            } else if gaps.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.md) {
                        ForEach(gaps) { gap in
                            gapCard(gap)
                        }

                        Spacer().frame(height: Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            }
        }
        .navigationTitle("Knowledge Gaps")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Content.self) { content in
            PlayerView(contentId: content.id)
        }
        .navigationDestination(for: QuizListDestination.self) { _ in
            QuizListView()
        }
        .task {
            await loadGaps()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.success)
            Text("No Knowledge Gaps!")
                .font(Typography.titleMedium)
                .foregroundStyle(.white)
            Text("You're doing great across all topics.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func gapCard(_ gap: KnowledgeGap) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gap.topic.capitalized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    if let level = gap.level {
                        Text(level.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                Spacer()

                // Score
                ZStack {
                    Circle()
                        .fill(.orange.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Text("\(gap.scoreValue)%")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            // Suggestion
            if let suggestion = gap.suggestion {
                Text(suggestion)
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.surfaceElevated)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.orange)
                        .frame(width: geo.size.width * CGFloat(gap.scoreValue) / 100)
                }
            }
            .frame(height: 6)

            // Recommended content
            let related = gapContent.filter { $0.topics?.contains(gap.topic) ?? false }
            if !related.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)

                    ForEach(related.prefix(3)) { content in
                        NavigationLink(value: content) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ColorTokens.gold)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(content.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    if let duration = content.duration {
                                        Text(formatDuration(duration))
                                            .font(.system(size: 10))
                                            .foregroundStyle(ColorTokens.textTertiary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(ColorTokens.gold)
                            }
                            .padding(8)
                            .background(ColorTokens.gold.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Quiz CTA
            NavigationLink(value: QuizListDestination()) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                    Text("Take a Quiz")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(ColorTokens.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func loadGaps() async {
        isLoading = true

        async let gapsTask: [KnowledgeGap]? = {
            try? await self.knowledgeService.getGaps()
        }()
        async let contentTask: [Content]? = {
            try? await self.recommendationService.getGapContent(limit: 10)
        }()

        let (g, c) = await (gapsTask, contentTask)
        gaps = g ?? mockGaps
        gapContent = c ?? mockContent

        isLoading = false
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(mins) min"
    }

    private var mockGaps: [KnowledgeGap] {
        [
            KnowledgeGap(topic: "Roadmapping", score: 35, level: "beginner", quizzesTaken: 1, suggestion: "Focus on roadmap frameworks and prioritization techniques"),
            KnowledgeGap(topic: "Prioritization", score: 40, level: "beginner", quizzesTaken: 1, suggestion: "Study RICE, ICE, and weighted scoring methods")
        ]
    }

    private var mockContent: [Content] {
        [
            Content(id: "gc1", creatorId: nil, title: "Roadmapping 101", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1500, sourceType: .youtube, sourceAttribution: nil, domain: "Product Management", topics: ["Roadmapping"], tags: nil, difficulty: .beginner, aiData: nil, status: .published, viewCount: 4200, likeCount: 280, commentCount: 18, saveCount: 150, averageRating: 4.7, ratingCount: 67, publishedAt: Date(), createdAt: nil),
            Content(id: "gc2", creatorId: nil, title: "RICE Framework Masterclass", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1200, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: ["Prioritization"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 3100, likeCount: 190, commentCount: 12, saveCount: 95, averageRating: 4.5, ratingCount: 42, publishedAt: Date(), createdAt: nil)
        ]
    }
}
