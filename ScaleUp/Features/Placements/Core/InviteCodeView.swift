import SwiftUI

/// Screen where a student redeems the 6-digit invite code their college sent
/// them, enrolling into their placement cohort.
///
/// On "Join" it calls `appState.redeemInviteCode(code)`. On success the shell
/// has already re-routed into the placement experience, so this just dismisses.
/// On failure it surfaces an inline error and leaves the field intact.
struct InviteCodeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isSubmitting = false
    @State private var showError = false

    private var isValid: Bool { code.count == 6 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            // Header icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "ticket.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ColorTokens.background)
            }
            .padding(.bottom, 18)

            Text("Join your college programme")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Text("Enter the 6-digit code from your invite")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 28)

            Spacer(minLength: 28)

            // Code field
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimary)
                .tracking(8)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            showError ? ColorTokens.error.opacity(0.6)
                                      : ColorTokens.gold.opacity(0.25),
                            lineWidth: 1, antialiased: true
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .onChange(of: code) { _, newValue in
                    // Keep digits only, cap at 6.
                    let digits = String(newValue.filter(\.isNumber).prefix(6))
                    if digits != newValue { code = digits }
                    if showError { showError = false }
                }

            // Inline error
            if showError {
                Text("That code is invalid or already used.")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.error)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 28)
                    .transition(.opacity)
            }

            Spacer(minLength: 24)

            // Join button
            Button {
                join()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(ColorTokens.background)
                    }
                    Text("Join")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(ColorTokens.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(isValid && !isSubmitting ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!isValid || isSubmitting)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func join() {
        guard isValid, !isSubmitting else { return }
        Haptics.selection()
        Task {
            isSubmitting = true
            let ok = await appState.redeemInviteCode(code)
            isSubmitting = false
            if ok {
                Haptics.success()
                dismiss()
            } else {
                Haptics.error()
                withAnimation { showError = true }
            }
        }
    }
}
