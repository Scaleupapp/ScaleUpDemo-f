import SwiftUI

struct PrimaryButton: View {
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
                        .tint(.white)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(ColorTokens.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .opacity(isDisabled ? 0.5 : 1)
        }
        .disabled(isLoading || isDisabled)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.5), trigger: isLoading)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PrimaryButton(title: "Get Started") {}
        PrimaryButton(title: "Loading...", isLoading: true) {}
        PrimaryButton(title: "Disabled", isDisabled: true) {}
    }
    .padding()
    .background(ColorTokens.backgroundDark)
}
