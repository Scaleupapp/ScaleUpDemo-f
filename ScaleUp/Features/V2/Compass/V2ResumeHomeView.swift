import SwiftUI

/// V2 Resume Home — destination for the "Build my resume" Compass chip.
///
/// Honest placeholder. ScaleUp doesn't have a resume builder yet — this is
/// where it will land once we build it. Keeping the chip routed to a
/// dedicated screen (instead of "Coming soon" inside a chat bubble) at
/// least makes the surface coherent with Quiz/Interview/Notes homes.
struct V2ResumeHomeView: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroIcon
                    Text("Resume builder")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Coming soon. Compass will craft tailored resumes from your background, your goal, and the role you're targeting.")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)

                    Text("WHAT YOU'LL BE ABLE TO DO").v2Eyebrow().padding(.top, 6)
                    VStack(spacing: 10) {
                        plannedRow("doc.text", "Import LinkedIn or upload an existing resume")
                        plannedRow("sparkles", "Generate a role-targeted version with Compass")
                        plannedRow("checkmark.shield", "ATS-friendly formatting and keyword tuning")
                        plannedRow("clock.arrow.circlepath", "Versions saved per role + per company")
                    }
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 24)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(ColorTokens.background)
        }
    }

    private func plannedRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 30, height: 30)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(text)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }
}
