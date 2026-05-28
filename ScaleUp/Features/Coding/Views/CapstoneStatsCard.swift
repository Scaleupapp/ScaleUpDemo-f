import SwiftUI

/// Self-loading card for the V2 You tab that replaces the bare "Coding
/// drills & mastery" navigation row. Renders one of:
///   - Stats block (total attempts + best + avg + current level) +
///     "All capstones" CTA → CapstoneHistoryView
///   - Empty state encouraging the first attempt
///   - Hidden when the user has no coding objective (best-effort silent)
struct CapstoneStatsCard: View {
    @State private var stats: CapstoneHistoryStats?
    @State private var loaded = false
    @State private var hidden = false

    private let service = CapstoneService.shared

    var body: some View {
        Group {
            if hidden {
                EmptyView()
            } else if !loaded {
                loadingPlaceholder
            } else if let stats {
                statsCard(stats)
            } else {
                EmptyView()
            }
        }
        .task { await load() }
    }

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.tertiarySystemBackground))
            .frame(height: 132)
            .redacted(reason: .placeholder)
    }

    private func statsCard(_ s: CapstoneHistoryStats) -> some View {
        NavigationLink {
            CapstoneHistoryView()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.caption.weight(.bold))
                    Text("Coding capstones")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.tint)

                if s.totalAttempts == 0 {
                    Text("No capstones yet. Try your first one to see how you stack up.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 10) {
                        cell(value: "\(s.totalAttempts)", label: "Attempts")
                        cell(value: s.bestScore.map { "\($0)" } ?? "—", label: "Best", accent: true)
                        cell(value: s.meanScore.map { "\($0)" } ?? "—", label: "Avg")
                        cell(value: s.currentDifficulty.map { $0.capitalized } ?? "—", label: "Level")
                    }
                }

                Text(s.totalAttempts == 0 ? "Tap to browse the library" : "Tap to view all attempts")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func cell(value: String, label: String, accent: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(accent ? Color.accentColor : Color.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private func load() async {
        do {
            let r = try await service.history(limit: 1, offset: 0)
            self.stats = r.stats
            self.loaded = true
            // No coding track or no stats → hide rather than show a misleading card.
            if r.stats.roleTrack == nil { self.hidden = true }
        } catch {
            self.hidden = true
        }
    }
}
