import SwiftUI

struct ContentRow: View {
    let title: String
    let items: [Content]
    var cardWidth: CGFloat = 200
    var seeAllAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Text(title)
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if let action = seeAllAction {
                    Button {
                        action()
                    } label: {
                        Text("See All")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.gold)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            ContentCard(content: item, width: cardWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }
}
