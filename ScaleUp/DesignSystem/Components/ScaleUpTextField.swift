import SwiftUI

struct ScaleUpTextField: View {
    let label: String
    let icon: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(isFocused ? ColorTokens.gold : ColorTokens.textSecondary)

            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isFocused ? ColorTokens.gold : ColorTokens.textTertiary)
                    .frame(width: 20)

                if isSecure {
                    SecureField("", text: $text)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .focused($isFocused)
                        .tint(ColorTokens.gold)
                } else {
                    TextField("", text: $text)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .focused($isFocused)
                        .tint(ColorTokens.gold)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(isFocused ? ColorTokens.gold : ColorTokens.border, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
        }
    }
}
