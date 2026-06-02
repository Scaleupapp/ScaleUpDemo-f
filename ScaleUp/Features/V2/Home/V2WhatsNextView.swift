import SwiftUI

/// The "what's next" chooser after the Ready moment (and from the persistent gold
/// ring). Three paths; prove-it is objective-aware via ready.proveIt.
struct V2WhatsNextView: View {
    let ready: V2YouOverview.ReadinessBlock.ReadyBlock
    let onDeeper: () -> Void
    let onWider: () -> Void
    let onProve: (_ route: String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("You're ready. Where to now?")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(ColorTokens.textPrimary)
                        .padding(.bottom, 4)
                    pathCard(icon: "arrow.up", title: "Go deeper", subtitle: "Raise the bar to Exceptional and keep climbing.") { onDeeper() }
                    pathCard(icon: "arrow.left.arrow.right", title: "Go wider", subtitle: "Start a new goal.") { onWider() }
                    pathCard(icon: "checkmark.seal", title: ready.proveIt?.label ?? "Go prove it",
                             subtitle: (ready.proveIt?.comingSoonProof ?? false) ? "Shareable proof card coming soon." : "Show the world you're ready.") {
                        onProve(ready.proveIt?.route ?? "proof")
                    }
                }.padding(20)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("What's next").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundStyle(ColorTokens.gold) } }
        }
    }

    private func pathCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(ColorTokens.gold).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(ColorTokens.textPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(ColorTokens.textSecondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(ColorTokens.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ColorTokens.surfaceElevated.opacity(0.7), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
