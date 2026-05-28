import SwiftUI

/// Weekly capstone milestone card surfaced on the V2 Home tab.
///
/// Loads `/capstones/summary` on mount. Renders one of:
///   - .available  → tappable card that opens CapstonePreflightView with the
///                   suggested bundle (the "Surprise me" picker)
///   - .inProgress → status nudge ("finish your capstone on your laptop")
///   - .levelUp    → celebration when the learner's difficulty just bumped
///   - .hidden     → no card; the user isn't eligible / no bundle / network failure
///
/// Self-healing: any failure path collapses to EmptyView so Home is never
/// broken for users without a coding objective.
struct CapstoneMilestoneCard: View {

    @State private var loadState: LoadState = .loading

    private let service: CapstoneService

    init(service: CapstoneService = .shared) {
        self.service = service
    }

    enum LoadState {
        case loading
        case available(role: String, difficulty: String, summaryLine: String)
        case inProgress(sessionId: String, summaryLine: String)
        case levelUp(newDifficulty: String)
        case hidden
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                loadingPlaceholder
            case .available(let role, let difficulty, let summaryLine):
                availableCard(role: role, difficulty: difficulty, summaryLine: summaryLine)
            case .inProgress(_, let summaryLine):
                inProgressCard(summaryLine: summaryLine)
            case .levelUp(let newDifficulty):
                levelUpCard(newDifficulty: newDifficulty)
            case .hidden:
                EmptyView()
            }
        }
        .task { await load() }
    }

    // MARK: - Available state

    private func availableCard(role: String, difficulty: String, summaryLine: String) -> some View {
        NavigationLink {
            CapstoneLibraryView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.caption.weight(.semibold))
                    Text("Weekly capstone")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(difficulty.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.tint)

                Text(summaryLine)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    badge(text: role.uppercased())
                    badge(text: "60–90 min")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - In-progress state

    private func inProgressCard(summaryLine: String) -> some View {
        NavigationLink {
            CapstoneLibraryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Capstone in progress")
                        .font(.subheadline.weight(.semibold))
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Level-up celebration

    private func levelUpCard(newDifficulty: String) -> some View {
        NavigationLink {
            CapstoneLibraryView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                    Text("You leveled up")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.tint)

                Text("Your last capstone moved you to **\(newDifficulty.capitalized)** difficulty. Want to take the next one?")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .foregroundStyle(.primary)

                HStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.15), Color(.secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading placeholder

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.tertiarySystemBackground))
            .frame(height: 96)
            .redacted(reason: .placeholder)
    }

    // MARK: - Reusable

    private func badge(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
    }

    // MARK: - Load

    private func load() async {
        do {
            let summary = try await service.summary()
            guard summary.eligible else {
                loadState = .hidden
                return
            }
            if let inProgress = summary.inProgress {
                loadState = .inProgress(
                    sessionId: inProgress.sessionId,
                    summaryLine: summary.summaryLine
                )
                return
            }
            // Level-up: last graded session was at a lower difficulty than current.
            if let last = summary.recentCapstones.first,
               let lastDiff = last.difficulty?.rawValue,
               let current = summary.currentDifficulty?.rawValue,
               difficultyIsHigher(current, than: lastDiff) {
                loadState = .levelUp(newDifficulty: current)
                return
            }
            // Available — milestone cadence is open.
            let nextAvailable = summary.nextAvailableAt ?? Date()
            if nextAvailable <= Date() {
                let role = summary.roleTrack?.rawValue ?? "swe"
                let difficulty = summary.currentDifficulty?.rawValue ?? "easy"
                loadState = .available(role: role, difficulty: difficulty, summaryLine: summary.summaryLine)
            } else {
                loadState = .hidden
            }
        } catch {
            loadState = .hidden
        }
    }

    private func difficultyIsHigher(_ a: String, than b: String) -> Bool {
        let order = ["easy", "medium", "hard", "staff_plus"]
        guard let ai = order.firstIndex(of: a), let bi = order.firstIndex(of: b) else { return false }
        return ai > bi
    }
}
