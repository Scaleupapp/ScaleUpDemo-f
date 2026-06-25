import SwiftUI

/// V2 root view — chooses between the v1 app and the v2 4-tab IA.
///
///   - v2 user  → V2MainTabView (the new IA)
///   - v1 user  → v1 MainTabView, untouched. If the server flagged them, a
///                one-time "try v2" prompt is offered over it.
///
/// The choice is server-driven (`V2FeatureFlag`) — there is no manual toggle.
struct V2RootView: View {
    @State private var flag = V2FeatureFlag.shared
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if flag.isEnabled {
                if appState.userContext?.isPlacement == true {
                    // Institution (placement) users get the Placements shell.
                    PlacementsMainTabView()
                } else {
                    V2MainTabView()
                }
            } else {
                MainTabView()
            }
        }
        // Dual-context chooser: shown only while a dual user has not yet chosen
        // an experience. Non-dual users never carry `needsContextChoice`, so this
        // never presents for them. Read-only binding — it dismisses once the
        // chosen context comes back with `needsContextChoice` false/absent.
        .fullScreenCover(isPresented: Binding(
            get: { appState.userContext?.needsContextChoice == true },
            set: { _ in }
        )) {
            ContextChooserSheet()
                .environment(appState)
        }
        .sheet(isPresented: Binding(
            get: { !flag.isEnabled && flag.shouldShowV2Prompt },
            set: { if !$0 { flag.shouldShowV2Prompt = false } }
        )) {
            V2InvitePrompt(
                onAccept: {
                    let ok = await flag.acceptV2()
                    if ok {
                        // Re-onboard into v2 — server already flagged them.
                        appState.launchState = .onboarding(step: 1)
                    }
                    return ok
                },
                onDismiss: {
                    await flag.recordPromptDismissed()
                }
            )
            .interactiveDismissDisabled(true)
        }
    }
}

/// The one-time "we've released a new experience" prompt shown to existing
/// users. Accepting re-onboards them into v2 (history kept); dismissing starts
/// the server-side "ask again later" cooldown.
private struct V2InvitePrompt: View {
    /// Returns true if the opt-in succeeded.
    let onAccept: () async -> Bool
    let onDismiss: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isAccepting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(ColorTokens.background)
            }
            .padding(.bottom, 22)

            Text("A new ScaleUp experience")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            Text("We've rebuilt ScaleUp around one focused daily plan, a single AI guide (Compass), and a cleaner path to your goal.")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 28)

            Text("You'll set your goal again from scratch — but everything you've learned so far stays with you.")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            if let error = error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.warning)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Task {
                        isAccepting = true
                        error = nil
                        let ok = await onAccept()
                        isAccepting = false
                        if ok {
                            dismiss()
                        } else {
                            error = "Couldn't switch you over. Check your connection and try again."
                        }
                    }
                } label: {
                    Group {
                        if isAccepting {
                            ProgressView().tint(ColorTokens.background)
                        } else {
                            Text("Try it now")
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(ColorTokens.gold)
                    .foregroundStyle(ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isAccepting)

                Button {
                    Task {
                        await onDismiss()
                        dismiss()
                    }
                } label: {
                    Text("Maybe later")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(isAccepting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}
