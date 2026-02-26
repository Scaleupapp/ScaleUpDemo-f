import SwiftUI

struct HorizontalCarousel<Content: View, Item: Identifiable>: View {
    let items: [Item]
    let spacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    init(
        items: [Item],
        spacing: CGFloat = Spacing.sm,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }
}
