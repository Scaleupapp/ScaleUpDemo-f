import SwiftUI

/// V2 Home — One-Hero design.
///
/// Layout (top to bottom):
///   1. Objective pill + notification bell (compact header)
///   2. Warm greeting + status line
///   3. Slim trajectory bar (today / weekly delta / target)
///   4. "Today · 25 min" eyebrow
///   5. ONE hero task card with predicted impact ("why this matters")
///   6. Two soft alternative buttons (5-min quick / show alternatives)
///   7. Calm closing line
///
/// No carousels, no stacking banners, no streak flames on Home.
struct V2HomeView: View {
    @State private var vm = V2HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if let data = vm.data {
                        contentSection(data: data)
                    } else if vm.isLoading {
                        loadingSection
                    } else {
                        errorSection
                    }
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.bottom, 120)
            }
            .background(ColorTokens.background.ignoresSafeArea())
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            ObjectivePill(label: vm.data?.objectiveLabel ?? "Set your objective")
            Spacer()
            Button {
                // TODO: notifications
            } label: {
                ZStack {
                    Circle()
                        .fill(ColorTokens.surface)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Circle()
                        .fill(ColorTokens.gold)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(ColorTokens.surface, lineWidth: 2))
                        .offset(x: 9, y: -9)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    // MARK: - Main content

    @ViewBuilder
    private func contentSection(data: V2HomeData) -> some View {
        // Greeting
        VStack(alignment: .leading, spacing: 6) {
            Text(data.greeting)
                .font(V2Theme.h1)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(data.statusLine)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.bottom, 22)

        // Trajectory bar
        if let traj = data.trajectory {
            trajectorySection(traj: traj, weekProgress: data.weekProgress)
                .padding(.bottom, 22)
        }

        if let hero = data.hero {
            Text("Today · \(hero.durationMin) min")
                .v2Eyebrow()
                .padding(.bottom, 10)

            heroCard(hero: hero)
                .padding(.bottom, 14)

            HStack(spacing: 8) {
                Button { /* TODO short alternative */ } label: {
                    Text("⏱ Only 5 min?")
                        .font(V2Theme.small.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ColorTokens.surfaceElevated.opacity(0.5))
                )
                .foregroundStyle(ColorTokens.textPrimary)

                Button { vm.showAlternatives.toggle() } label: {
                    Text(vm.showAlternatives ? "↑ Hide alternatives" : "↓ Show alternatives")
                        .font(V2Theme.small.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ColorTokens.surfaceElevated.opacity(0.5))
                )
                .foregroundStyle(ColorTokens.textPrimary)
            }
            .padding(.top, 6)

            if vm.showAlternatives, !data.alternatives.isEmpty {
                alternativesSection(items: data.alternatives)
                    .padding(.top, 18)
            }

            Text("One job at a time.\nWe picked this for you so you don't have to.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 26)
        } else if data.fallback == "plan_brewing" {
            planBrewingFallback
        } else if data.fallback == "no_objective" {
            VStack(spacing: 14) {
                Text("Let's set up your goal")
                    .font(V2Theme.h2)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("About 10 minutes. Worth it.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
                Button("Start") { /* TODO: route */ }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTokens.gold)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Hero card

    private func heroCard(hero: V2HomeData.Hero) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hero.icon)
                .font(.system(size: 36))
                .padding(.bottom, 14)

            Text(hero.title)
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)

            if !hero.subtitle.isEmpty {
                Text(hero.subtitle)
                    .font(V2Theme.h3)
                    .fontWeight(.medium)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.top, 2)
            }

            HStack(spacing: 12) {
                Label("\(hero.durationMin) min", systemImage: "clock")
                Text("·")
                Label(hero.author, systemImage: "person.fill")
                Text("·")
                Label(hero.difficulty.capitalized, systemImage: "flame.fill")
                    .foregroundStyle(difficultyColor(hero.difficulty))
            }
            .font(.system(size: 11))
            .foregroundStyle(ColorTokens.textSecondary)
            .padding(.top, 14)
            .padding(.bottom, 18)

            // Why this matters
            VStack(alignment: .leading, spacing: 6) {
                Text("Why this matters today")
                    .v2Eyebrow(ColorTokens.success)
                Text(hero.whyText)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTokens.success.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(ColorTokens.success.opacity(0.25), lineWidth: 1)
                    )
            )
            .padding(.bottom, 20)

            Button {
                // TODO: route into task
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Begin")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(ColorTokens.gold)
                .foregroundStyle(ColorTokens.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(V2Theme.heroGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1)
        )
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d.lowercased() {
        case "hard": return ColorTokens.warning
        case "easy": return ColorTokens.success
        default:     return ColorTokens.textSecondary
        }
    }

    // MARK: - Trajectory

    private func trajectorySection(traj: V2HomeData.Trajectory, weekProgress: V2HomeData.WeekProgress?) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.surface)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.gold, ColorTokens.goldLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(traj.today) / 100.0, height: 6)
                        .shadow(color: ColorTokens.gold.opacity(0.4), radius: 6)
                }
            }
            .frame(height: 6)

            HStack {
                if let wp = weekProgress {
                    Text("Week \(wp.week) of \(wp.totalWeeks)")
                } else {
                    Text("\(traj.today)% ready")
                }
                Spacer()
                Text("▲ \(traj.weeklyDelta)% / week")
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Text("Target \(traj.targetReadiness)%")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Alternatives

    private func alternativesSection(items: [V2HomeData.Alternative]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("If not, try one of these")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.bottom, 4)

            ForEach(items) { item in
                HStack(spacing: 14) {
                    Text(item.icon)
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                        .background(ColorTokens.surfaceElevated.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(V2Theme.bodyMedium)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("\(item.durationMin) min · \(item.reason)")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ColorTokens.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Loading / fallback / error

    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(ColorTokens.gold)
            Text("Loading your day…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var planBrewingFallback: some View {
        VStack(spacing: 12) {
            Text("✨")
                .font(.system(size: 40))
            Text("Your plan is being personalized.")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Meanwhile, here's content relevant to your goal.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var errorSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.warning)
            Text(vm.error ?? "Something went wrong.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
            Button("Try again") { Task { await vm.load() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Objective Pill

private struct ObjectivePill: View {
    let label: String
    var body: some View {
        HStack(spacing: 8) {
            Text("🎯")
                .font(.system(size: 12))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(ColorTokens.surface)
        )
        .overlay(
            Capsule().strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    let view = V2HomeView()
    return view
        .preferredColorScheme(.dark)
        .onAppear {
            // Preview-only: surface the sample so the canvas renders.
            // Production users see real backend data.
        }
}
