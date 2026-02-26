import SwiftUI

struct SectionHeader: View {
    let title: String
    var seeAllAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Spacer()

            if let seeAllAction {
                Button(action: seeAllAction) {
                    Text("See All")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.primary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}
