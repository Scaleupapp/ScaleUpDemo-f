import SwiftUI

/// V2 "You" Tab — replaces v1 Profile + Progress.
///
/// Above-fold: avatar + readiness ring + 4 facts (week / streak / top gap / time).
/// Below-fold: collapsed sections (Plan, Progress, Objectives, Compass, Content, Settings).
struct V2YouView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerProfile

                    readinessRing
                        .padding(.vertical, 20)

                    statsBlock

                    Divider().background(V2Theme.cardBorder).padding(.vertical, 18)

                    Text("More about you".uppercased())
                        .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.bottom, 6)

                    sectionsList

                    creatorCTA

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
            }
            .background(ColorTokens.background.ignoresSafeArea())
        }
    }

    private var headerProfile: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [ColorTokens.surfaceElevated, ColorTokens.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                Text("N").font(.system(size: 22, weight: .bold)).foregroundStyle(ColorTokens.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Nirpeksh Nandan").font(.system(size: 17, weight: .bold)).foregroundStyle(ColorTokens.textPrimary)
                Text("Edit profile").font(V2Theme.small).foregroundStyle(ColorTokens.textTertiary)
            }
            Spacer()
        }
    }

    private var readinessRing: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.surfaceElevated, lineWidth: 9)
                    .frame(width: 130, height: 130)
                Circle()
                    .trim(from: 0, to: 0.74)
                    .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("74").font(.system(size: 32, weight: .bold))
                        Text("%").font(.system(size: 18, weight: .bold)).foregroundStyle(ColorTokens.textSecondary)
                    }
                    Text("READINESS")
                        .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            Text("On track for Aug 2026")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(ColorTokens.gold)
            Text("11 weeks remaining")
                .font(.system(size: 11)).foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsBlock: some View {
        VStack(spacing: 0) {
            statRow(label: "This week", value: "3 of 7 done", accent: true)
            divider
            statRow(label: "Streak", value: "12 days")
            divider
            statRow(label: "Top gap", value: "Estimation frameworks", trailing: "→ Fix")
            divider
            statRow(label: "Time invested", value: "67 hours")
        }
    }

    private var divider: some View {
        Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
    }

    private func statRow(label: String, value: String, accent: Bool = false, trailing: String? = nil) -> some View {
        HStack {
            Text(label).font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent ? ColorTokens.gold : ColorTokens.textPrimary)
                if let t = trailing {
                    Text(t).font(.system(size: 12)).foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var sectionsList: some View {
        VStack(spacing: 0) {
            sectionRow(icon: "📊", label: "My progress & analytics")
            sectionRow(icon: "🎯", label: "My plan", meta: "Week 3 of 24")
            sectionRow(icon: "🎓", label: "My objectives", meta: "1 active")
            sectionRow(icon: "🧭", label: "My Compass activity")
            sectionRow(icon: "📺", label: "My content", meta: "42 watched")
            sectionRow(icon: "⚙️", label: "Settings")
        }
    }

    private func sectionRow(icon: String, label: String, meta: String? = nil) -> some View {
        HStack(spacing: 14) {
            Text(icon).font(.system(size: 14))
                .frame(width: 32, height: 32)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(label).font(V2Theme.bodyMedium).foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            if let meta = meta {
                Text(meta).font(.system(size: 12)).foregroundStyle(ColorTokens.textTertiary)
            }
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
        }
    }

    private var creatorCTA: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("✦ Become a Creator")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            Text("Apply to share content with other learners.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.gold.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1, antialiased: true)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 18)
    }
}

#Preview { V2YouView().preferredColorScheme(.dark) }
