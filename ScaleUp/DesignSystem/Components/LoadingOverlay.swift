import SwiftUI

struct LoadingOverlay: View {
    var message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .tint(ColorTokens.primary)
                    .scaleEffect(1.5)

                if let message {
                    Text(message)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }
            .padding(Spacing.xl)
            .background(ColorTokens.surfaceElevatedDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
    }
}

extension View {
    func loadingOverlay(isPresented: Bool, message: String? = nil) -> some View {
        overlay {
            if isPresented {
                LoadingOverlay(message: message)
                    .transition(.opacity)
            }
        }
        .animation(Animations.standard, value: isPresented)
    }
}
