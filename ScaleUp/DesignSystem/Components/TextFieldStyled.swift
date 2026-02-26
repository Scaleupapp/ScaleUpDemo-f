import SwiftUI

struct TextFieldStyled: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var isSecure: Bool = false
    var errorMessage: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .sentences

    @State private var isSecureVisible = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isFocused ? ColorTokens.primary : ColorTokens.textTertiaryDark)
                        .frame(width: 20)
                }

                Group {
                    if isSecure && !isSecureVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textContentType(textContentType)
                            .textInputAutocapitalization(autocapitalization)
                    }
                }
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .focused($isFocused)

                if isSecure {
                    Button {
                        isSecureVisible.toggle()
                    } label: {
                        Image(systemName: isSecureVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 52)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(
                        errorMessage != nil ? ColorTokens.error :
                            isFocused ? ColorTokens.primary : ColorTokens.surfaceElevatedDark,
                        lineWidth: 1
                    )
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.error)
            }
        }
    }
}
