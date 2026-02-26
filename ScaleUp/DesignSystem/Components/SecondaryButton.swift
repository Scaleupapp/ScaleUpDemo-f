import SwiftUI

struct SecondaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(Typography.bodyBold)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(ColorTokens.primary)
                }
            }
            .foregroundStyle(ColorTokens.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.clear)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(ColorTokens.primary, lineWidth: 1.5)
            )
            .opacity(isDisabled ? 0.5 : 1)
        }
        .disabled(isLoading || isDisabled)
    }
}
