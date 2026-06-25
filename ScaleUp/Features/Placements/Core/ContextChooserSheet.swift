import SwiftUI

/// One-time experience chooser for dual-context users (those who have BOTH a
/// college placement enrollment AND their own personal objective).
///
/// Presented only while `userContext?.needsContextChoice == true`. Tapping a
/// card calls `appState.switchContext(to:)`, which records the choice, adopts
/// the new persona, and re-routes the shell — so `needsContextChoice` flips to
/// false on the next context and this sheet dismisses itself.
///
/// Invisible to non-dual users: their `/me/context` response carries none of the
/// dual fields, so this is never shown.
struct ContextChooserSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isSwitching = false

    private var institutionName: String {
        appState.userContext?.placement?.institution.name ?? "Placement"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // Header
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "rectangle.2.swap")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ColorTokens.background)
            }
            .padding(.bottom, 18)

            Text("Choose your experience")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            Text("You're enrolled in a placement program and you also have your own goal. Pick where to start — you can switch anytime.")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 28)

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                choiceCard(
                    context: "placement",
                    icon: "building.columns.fill",
                    title: institutionName,
                    subtitle: "Placement program"
                )
                choiceCard(
                    context: "personal",
                    icon: "target",
                    title: "Personal",
                    subtitle: "Your own goals"
                )
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }

    private func choiceCard(context: String, icon: String, title: String, subtitle: String) -> some View {
        Button {
            guard !isSwitching else { return }
            Haptics.selection()
            Task {
                isSwitching = true
                await appState.switchContext(to: context)
                isSwitching = false
                dismiss()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.gold.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(ColorTokens.gold)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                Spacer(minLength: 0)
                if isSwitching {
                    ProgressView().tint(ColorTokens.gold)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(ColorTokens.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1, antialiased: true)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isSwitching)
    }
}
