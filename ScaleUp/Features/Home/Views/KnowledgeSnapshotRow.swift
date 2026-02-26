import SwiftUI

// MARK: - Knowledge Snapshot Row

struct KnowledgeSnapshotRow: View {
    let topics: [TopicMastery]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Knowledge") {
                // See All action — future navigation
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(topics, id: \.topic) { mastery in
                        KnowledgeBar(
                            topic: mastery.topic,
                            score: Int(mastery.score),
                            level: mastery.level.rawValue,
                            trend: mastery.trend.rawValue
                        )
                        .frame(width: 200)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }
}
