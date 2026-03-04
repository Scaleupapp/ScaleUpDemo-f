import SwiftUI

// MARK: - Coach Mark Tooltip

struct CoachMarkOverlay: View {
    let icon: String
    let title: String
    let message: String
    var showSkipAll: Bool = false
    var onDismiss: () -> Void
    var onSkipAll: (() -> Void)?

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Gold icon
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Dismiss
                Button {
                    Haptics.light()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 26, height: 26)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Circle())
                }
            }

            if showSkipAll {
                Button {
                    Haptics.selection()
                    onSkipAll?()
                } label: {
                    Text("Skip all tips")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .underline()
                }
                .padding(.leading, 48)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: ColorTokens.gold.opacity(0.15), radius: 12, y: 4)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .onAppear {
            withAnimation(Motion.springBouncy.delay(0.3)) {
                isVisible = true
            }
        }
    }

    private func dismiss() {
        withAnimation(Motion.easeOut) {
            isVisible = false
        }
        // Let animation finish before callback
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            onDismiss()
        }
    }
}

// MARK: - Inline Feature Tooltip (lighter weight, for specific elements)

struct FeatureTooltip: View {
    let icon: String
    let text: String

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.gold)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(ColorTokens.surface)
                .overlay(
                    Capsule()
                        .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .onAppear {
            withAnimation(Motion.springBouncy.delay(0.5)) {
                isVisible = true
            }
        }
    }
}
