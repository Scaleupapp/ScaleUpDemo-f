import SwiftUI

/// Placement Home — the institution-driven landing for placement users.
///
/// Shows the college + cohort context, placement readiness (reusing the V2
/// `/plan/today` data), the locked institutional objective, and a placement
/// season countdown. Reuses `V2HomeViewModel` for readiness/objective so the
/// numbers match the rest of the app exactly.
struct PlacementsHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var homeVM = V2HomeViewModel()

    private var placement: PlacementContext? { appState.userContext?.placement }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                readinessCard
                objectiveCard
                deadlineCard
                nextStepsCard
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 8)
            .padding(.bottom, 120) // clear the tab bar + Compass FAB
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .task { await homeVM.load() }
        .refreshable { await homeVM.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Placements").v2Eyebrow()
            Text(placement?.institution.name ?? "Your College")
                .font(V2Theme.h1)
                .foregroundStyle(ColorTokens.textPrimary)
            if let cohort = placement?.cohort {
                Text("\(cohort.label) · \(cohort.yearLabel)")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Readiness

    private var readinessCard: some View {
        HStack(spacing: 16) {
            readinessRing(homeVM.data?.trajectory?.today)
            VStack(alignment: .leading, spacing: 6) {
                Text("Placement readiness").v2Eyebrow()
                Text(readinessSubtitle)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .v2Card()
    }

    private var readinessSubtitle: String {
        if homeVM.isLoading && homeVM.data == nil { return "Calculating your readiness…" }
        guard let today = homeVM.data?.trajectory?.today else {
            return "Complete your diagnostic to see how placement-ready you are."
        }
        if let target = homeVM.data?.trajectory?.targetReadiness, target > 0 {
            return "You're at \(today)% — your cohort target is \(target)%. Keep going."
        }
        return "You're at \(today)% placement readiness."
    }

    @ViewBuilder
    private func readinessRing(_ value: Int?) -> some View {
        ZStack {
            Circle().stroke(ColorTokens.surfaceElevated, lineWidth: 9)
            if let value {
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, value))) / 100)
                    .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text(value.map { "\($0)" } ?? "—")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("READY")
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .frame(width: 92, height: 92)
    }

    // MARK: - Locked objective

    private var objectiveCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 34, height: 34)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Your objective").v2Eyebrow()
                Text(objectiveName)
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Set by \(placement?.institution.name ?? "your college") · locked")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .v2Card()
    }

    private var objectiveName: String {
        if let name = homeVM.data?.objectiveName, !name.isEmpty { return name }
        if let label = homeVM.data?.objectiveLabel, !label.isEmpty { return label }
        return "Placement readiness"
    }

    // MARK: - Deadline

    private var deadlineCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 34, height: 34)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Placement season").v2Eyebrow()
                Text(deadlineHeadline)
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let date = PlacementDate.medium(placement?.placementSeason.deadline) {
                    Text("Target: \(date)")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .v2Card()
    }

    private var deadlineHeadline: String {
        guard let days = PlacementDate.daysUntil(placement?.placementSeason.deadline) else {
            return "Your TPO will set the timeline"
        }
        if days > 1 { return "\(days) days to go" }
        if days == 1 { return "1 day to go" }
        if days == 0 { return "Placement season is here" }
        return "Placement season underway"
    }

    // MARK: - Assessments section

    private var nextStepsCard: some View {
        PlacementsAssessmentsView()
            .v2Card()
    }
}
