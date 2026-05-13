import SwiftUI

/// V2 "You" Tab — replaces v1 Profile + Progress.
///
/// Above-fold: avatar + readiness ring + 4 facts (week / streak / top gap / time).
/// Below-fold: collapsed sections (Plan, Progress, Objectives, Compass, Content, Settings).
struct V2YouView: View {
    @State private var vm = V2YouViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if vm.isLoading && vm.data == nil {
                    loadingState
                } else if let data = vm.data {
                    loadedContent(data: data)
                } else {
                    errorState
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - Loaded content

    @ViewBuilder
    private func loadedContent(data: V2YouOverview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerProfile(user: data.user)

            readinessRing(readiness: data.readiness)
                .padding(.vertical, 20)

            statsBlock(data: data)

            Divider().background(V2Theme.cardBorder).padding(.vertical, 18)

            Text("More about you".uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.bottom, 6)

            sectionsList(weekProgress: data.weekProgress, isCreator: data.flags.isCreator, isAdmin: data.flags.isAdmin)

            if !data.flags.isCreator {
                creatorCTA
            }

            Spacer().frame(height: 100)
        }
        .padding(.horizontal, V2Theme.pad)
        .padding(.top, 16)
    }

    private func headerProfile(user: V2YouOverview.UserBlock) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [ColorTokens.surfaceElevated, ColorTokens.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                if let urlStr = user.avatarURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Text(user.initial).font(.system(size: 22, weight: .bold)).foregroundStyle(ColorTokens.gold)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    Text(user.initial).font(.system(size: 22, weight: .bold)).foregroundStyle(ColorTokens.gold)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.system(size: 17, weight: .bold)).foregroundStyle(ColorTokens.textPrimary)
                Text("Edit profile").font(V2Theme.small).foregroundStyle(ColorTokens.textTertiary)
            }
            Spacer()
        }
    }

    private func readinessRing(readiness: V2YouOverview.ReadinessBlock) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.surfaceElevated, lineWidth: 9)
                    .frame(width: 130, height: 130)
                Circle()
                    .trim(from: 0, to: CGFloat(readiness.score) / 100.0)
                    .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(readiness.score)").font(.system(size: 32, weight: .bold))
                        Text("%").font(.system(size: 18, weight: .bold)).foregroundStyle(ColorTokens.textSecondary)
                    }
                    Text("READINESS")
                        .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            Text(readiness.onTrackText)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(ColorTokens.gold)
            if let weeks = readiness.weeksRemaining {
                Text("\(weeks) week\(weeks == 1 ? "" : "s") remaining")
                    .font(.system(size: 11)).foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statsBlock(data: V2YouOverview) -> some View {
        VStack(spacing: 0) {
            if let wp = data.weekProgress {
                statRow(label: "This week", value: "\(wp.done) of \(wp.total) done", accent: true)
                divider
            }
            statRow(label: "Streak", value: streakLabel(data.streak.current))
            if let gap = data.topGap {
                divider
                statRow(label: "Top gap", value: gap.topic, trailing: "→ \(gap.ctaLabel)")
            }
            divider
            statRow(label: "Time invested", value: "\(data.timeInvested.hours) hour\(data.timeInvested.hours == 1 ? "" : "s")")
        }
    }

    private func streakLabel(_ n: Int) -> String {
        switch n {
        case 0: return "Start one today"
        case 1: return "1 day"
        default: return "\(n) days"
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

    private func sectionsList(weekProgress: V2YouOverview.WeekProgressBlock?, isCreator: Bool, isAdmin: Bool) -> some View {
        VStack(spacing: 0) {
            sectionRow(icon: "📊", label: "My progress & analytics")
            if let wp = weekProgress {
                sectionRow(icon: "🎯", label: "My plan", meta: "Week \(wp.week)")
            } else {
                sectionRow(icon: "🎯", label: "My plan")
            }
            sectionRow(icon: "🎓", label: "My objectives", meta: "1 active")
            sectionRow(icon: "🧭", label: "My Compass activity")
            sectionRow(icon: "📺", label: "My content")
            sectionRow(icon: "⚙️", label: "Settings")
            if isCreator {
                sectionRow(icon: "🎬", label: "Creator hub")
            }
            if isAdmin {
                sectionRow(icon: "🛠️", label: "Admin tools")
            }
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

    // MARK: - Loading / Error states

    private var loadingState: some View {
        VStack(spacing: 18) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading your overview…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.warning)
            Text(vm.error ?? "Couldn't load your overview.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await vm.load() } }
                .buttonStyle(.bordered)
                .tint(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .padding(.horizontal, 24)
    }
}

#Preview { V2YouView().preferredColorScheme(.dark) }
