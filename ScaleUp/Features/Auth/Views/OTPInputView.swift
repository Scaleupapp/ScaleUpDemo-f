import SwiftUI

// MARK: - OTP Input View

/// Custom 6-digit OTP input with individual digit boxes, auto-advance, and paste support.
struct OTPInputView: View {
    @Binding var otp: String
    var digitCount: Int = 6
    var errorMessage: String?

    @FocusState private var focusedIndex: Int?
    @State private var digits: [String]

    // MARK: - Init

    init(otp: Binding<String>, digitCount: Int = 6, errorMessage: String? = nil) {
        self._otp = otp
        self.digitCount = digitCount
        self.errorMessage = errorMessage
        self._digits = State(initialValue: Array(repeating: "", count: digitCount))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                ForEach(0..<digitCount, id: \.self) { index in
                    digitBox(at: index)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.error)
            }
        }
        .onAppear {
            // Populate digits from initial OTP value
            syncDigitsFromOTP()
            focusedIndex = 0
        }
        .onChange(of: otp) { _, newValue in
            // Handle external changes (e.g., clearing)
            if newValue.isEmpty && !digits.allSatisfy({ $0.isEmpty }) {
                digits = Array(repeating: "", count: digitCount)
                focusedIndex = 0
            }
        }
    }

    // MARK: - Digit Box

    private func digitBox(at index: Int) -> some View {
        TextField("", text: $digits[index])
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(Typography.titleLarge)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .frame(width: 48, height: 56)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(
                        borderColor(for: index),
                        lineWidth: focusedIndex == index ? 2 : 1
                    )
            )
            .focused($focusedIndex, equals: index)
            .onChange(of: digits[index]) { oldValue, newValue in
                handleDigitChange(at: index, oldValue: oldValue, newValue: newValue)
            }
    }

    // MARK: - Border Color

    private func borderColor(for index: Int) -> Color {
        if errorMessage != nil {
            return ColorTokens.error
        }
        if focusedIndex == index {
            return ColorTokens.primary
        }
        return ColorTokens.surfaceElevatedDark
    }

    // MARK: - Input Handling

    private func handleDigitChange(at index: Int, oldValue: String, newValue: String) {
        // Handle paste: if user pastes a multi-digit string
        if newValue.count > 1 {
            let pastedDigits = newValue.filter(\.isNumber)
            handlePaste(pastedDigits, startingAt: index)
            return
        }

        // Only allow numeric input
        let filtered = newValue.filter(\.isNumber)
        if filtered != newValue {
            digits[index] = filtered
            return
        }

        // Update the combined OTP string
        syncOTPFromDigits()

        // Auto-advance to next field
        if !filtered.isEmpty && index < digitCount - 1 {
            focusedIndex = index + 1
        }
    }

    // MARK: - Paste Support

    private func handlePaste(_ text: String, startingAt startIndex: Int) {
        let characters = Array(text.prefix(digitCount - startIndex))

        for (offset, char) in characters.enumerated() {
            let targetIndex = startIndex + offset
            if targetIndex < digitCount {
                digits[targetIndex] = String(char)
            }
        }

        // Trim the current field if it had extra characters
        digits[startIndex] = String(digits[startIndex].prefix(1))

        syncOTPFromDigits()

        // Focus the next empty field or the last field
        let nextEmpty = digits.firstIndex(where: { $0.isEmpty })
        focusedIndex = nextEmpty ?? digitCount - 1
    }

    // MARK: - Sync Helpers

    private func syncOTPFromDigits() {
        otp = digits.joined()
    }

    private func syncDigitsFromOTP() {
        let chars = Array(otp)
        for i in 0..<digitCount {
            digits[i] = i < chars.count ? String(chars[i]) : ""
        }
    }
}
