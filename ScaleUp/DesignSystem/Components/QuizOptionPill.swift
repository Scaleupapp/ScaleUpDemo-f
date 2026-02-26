import SwiftUI

struct QuizOptionPill: View {
    let label: String // "A", "B", "C", "D"
    let text: String
    let state: OptionState

    enum OptionState {
        case `default`
        case selected
        case correct
        case wrong
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Label circle
            ZStack {
                Circle()
                    .fill(labelBackground)
                    .frame(width: 36, height: 36)

                if state == .selected {
                    Circle()
                        .stroke(ColorTokens.primary.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)
                        .scaleEffect(state == .selected ? 1 : 0.8)
                }

                Text(label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(labelForeground)
            }
            .frame(width: 44, height: 44)

            Text(text)
                .font(Typography.body)
                .foregroundStyle(textColor)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            // State indicator
            if state == .correct {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.success)
                    .transition(.scale.combined(with: .opacity))
            } else if state == .wrong {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.error)
                    .transition(.scale.combined(with: .opacity))
            } else if state == .selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.primary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(borderColor, lineWidth: state == .default ? 1 : 2)
        )
        .scaleEffect(state == .selected ? 1.02 : 1.0)
        .animation(Animations.spring, value: state)
        .sensoryFeedback(.selection, trigger: state)
    }

    private var backgroundColor: Color {
        switch state {
        case .default: return ColorTokens.surfaceDark
        case .selected: return ColorTokens.primary.opacity(0.1)
        case .correct: return ColorTokens.success.opacity(0.08)
        case .wrong: return ColorTokens.error.opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch state {
        case .default: return ColorTokens.surfaceElevatedDark
        case .selected: return ColorTokens.primary
        case .correct: return ColorTokens.success
        case .wrong: return ColorTokens.error
        }
    }

    private var labelBackground: Color {
        switch state {
        case .default: return ColorTokens.surfaceElevatedDark
        case .selected: return ColorTokens.primary
        case .correct: return ColorTokens.success
        case .wrong: return ColorTokens.error
        }
    }

    private var labelForeground: Color {
        state == .default ? ColorTokens.textSecondaryDark : .white
    }

    private var textColor: Color {
        state == .default ? ColorTokens.textSecondaryDark : ColorTokens.textPrimaryDark
    }
}
