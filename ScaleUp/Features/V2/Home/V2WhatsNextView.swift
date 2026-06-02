import SwiftUI
import UIKit

// MARK: - URL Identifiable (for .sheet(item: $shareURL))
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Native share sheet wrapper
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// The "what's next" chooser after the Ready moment (and from the persistent gold
/// ring). Three paths; prove-it is objective-aware via ready.proveIt.
struct V2WhatsNextView: View {
    let ready: V2YouOverview.ReadinessBlock.ReadyBlock
    let onDeeper: () -> Void
    let onWider: () -> Void
    let onProve: (_ route: String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var shareURL: URL?
    @State private var publishing = false
    @State private var publishError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("You're ready. Where to now?")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(ColorTokens.textPrimary)
                        .padding(.bottom, 4)
                    pathCard(icon: "arrow.up", title: "Go deeper", subtitle: "Raise the bar to Exceptional and keep climbing.") { onDeeper() }
                    pathCard(icon: "arrow.left.arrow.right", title: "Go wider", subtitle: "Start a new goal.") { onWider() }
                    pathCard(
                        icon: publishing ? "hourglass" : "checkmark.seal",
                        title: ready.proveIt?.label ?? "Go prove it",
                        subtitle: publishing ? "Publishing…" : "Share your verified proof."
                    ) {
                        let route = ready.proveIt?.route ?? "proof"
                        if route == "interview" {
                            onProve(route)
                        } else {
                            publishAndShare()
                        }
                    }
                }.padding(20)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("What's next").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundStyle(ColorTokens.gold) } }
        }
        .sheet(item: $shareURL) { url in
            ActivityView(items: [url])
        }
        .alert("Could not share", isPresented: $publishError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again in a moment.")
        }
    }

    // MARK: - Publish + share

    private func publishAndShare() {
        guard !publishing else { return }
        publishing = true
        Task {
            struct Empty: Codable {}
            struct PubResp: Codable { let token: String; let url: String; let shareText: String? }
            do {
                let r: V2APIResponse<PubResp> = try await V2APIClient.shared.post("/you/proof/publish", body: Empty())
                if let u = URL(string: r.data.url) { shareURL = u }
            } catch {
                publishError = true
            }
            publishing = false
        }
    }

    // MARK: - Row builder

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
