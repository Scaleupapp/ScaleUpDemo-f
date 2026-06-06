import SwiftUI

/// A consistent "Do this next →" call-to-action card shown at the bottom of
/// insight screens (quiz / interview / drill results, readiness breakdown, …).
/// It names the user's single biggest gap and offers one primary action that
/// loops them straight into the fix.
///
/// Purely presentational — the caller supplies the action, typically firing a
/// `NextStepCoordinator.Intent` and dismissing the current screen.
struct NextStepCard: View {
    var eyebrow: String = "NEXT STEP"
    /// The lead-in, e.g. "Your weakest area is".
    let lead: String
    /// The gap itself, emphasised in gold, e.g. "Recursion".
    let highlight: String
    let actionTitle: String
    var actionIcon: String? = "arrow.right"
    let action: () -> Void

    private var insight: AttributedString {
        var leadPart = AttributedString(lead + " ")
        leadPart.foregroundColor = ColorTokens.textSecondary
        var hi = AttributedString(highlight)
        hi.foregroundColor = ColorTokens.gold
        hi.font = V2Theme.bodyMedium.weight(.semibold)
        return leadPart + hi
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow).v2Eyebrow()
            Text(insight).font(V2Theme.bodyMedium)
            PrimaryButton(title: actionTitle, icon: actionIcon, action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ColorTokens.gold.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1)
        )
    }
}
