import SwiftUI

/// Full-screen "You're ready" moment — a gold medallion (Seal). Shown once on Home
/// when readyState.isReady && !momentSeen. Primary CTA opens What's-next; either
/// dismissal calls onSeen (POST /you/ready/seen) and flips Home to the gold ring.
struct V2ReadyMomentView: View {
    let ready: V2YouOverview.ReadinessBlock.ReadyBlock
    let onWhatsNext: () -> Void
    let onSeen: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RadialGradient(colors: [ColorTokens.surfaceElevated, ColorTokens.background],
                           center: .top, startRadius: 20, endRadius: 520).ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Text("YOU'VE EARNED IT")
                    .font(.system(size: 11, weight: .bold)).tracking(2)
                    .foregroundStyle(ColorTokens.textSecondary)
                medallion
                VStack(spacing: 4) {
                    Text(ready.summary?.objectiveLabel ?? "Your goal")
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(ColorTokens.textPrimary)
                    if let s = ready.summary {
                        Text("\(s.competenciesStrong) of \(s.competenciesTotal) skills strong · \(s.assessmentsCount) assessments")
                            .font(.system(size: 12)).foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                Spacer()
                Button { onSeen(); onWhatsNext() } label: {
                    Text("See what's next →")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(ColorTokens.background)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(ColorTokens.gold).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).padding(.horizontal, 24)
                Button { onSeen(); dismiss() } label: {
                    Text("Maybe later").font(.system(size: 13)).foregroundStyle(ColorTokens.textTertiary)
                }.buttonStyle(.plain).padding(.bottom, 20)
            }
        }
    }

    private var medallion: some View {
        ZStack {
            Circle().fill(AngularGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark, ColorTokens.goldLight], center: .center))
                .frame(width: 150, height: 150).shadow(color: ColorTokens.gold.opacity(0.45), radius: 26)
            Circle().fill(ColorTokens.background).frame(width: 124, height: 124)
            VStack(spacing: 2) {
                Text("★").font(.system(size: 26)).foregroundStyle(ColorTokens.gold)
                Text("READY").font(.system(size: 11, weight: .bold)).tracking(1.5).foregroundStyle(ColorTokens.gold)
                Text("\(ready.summary?.score ?? ready.readinessAtReady ?? 0)%")
                    .font(.system(size: 26, weight: .heavy)).foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }
}
