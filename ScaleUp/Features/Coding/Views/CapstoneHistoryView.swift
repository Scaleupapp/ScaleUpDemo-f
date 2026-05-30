import SwiftUI

/// Full chronological history of every graded capstone for this learner.
/// Headline stats up top (total / best / mean / current level), then a
/// scrollable list with per-row retry. Reached from the You-tab Coding
/// stats card and from the Compass-tab Coding home's "See all attempts".
struct CapstoneHistoryView: View {
    let onClose: (() -> Void)?

    @State private var response: CapstoneHistoryResponse?
    @State private var isLoading = true
    @State private var error: String?
    @State private var retryBusy: String?
    @State private var shareURL: String?
    @State private var sharing = false

    private let service = CapstoneService.shared

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if isLoading && response == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let response {
                content(response)
            } else if let error {
                errorState(message: error)
            } else {
                emptyState
            }
        }
        .navigationTitle("All capstones")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await makeShareLink() }
                } label: {
                    if sharing { ProgressView() } else { Image(systemName: "square.and.arrow.up") }
                }
                .disabled(sharing || (response?.items.isEmpty ?? true))
            }
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onClose)
                }
            }
        }
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let url = shareURL {
                ShareSheet(activityItems: [
                    "Here's my ScaleUp coding profile — graded capstone results: \(url)"
                ])
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func makeShareLink() async {
        sharing = true
        defer { sharing = false }
        do {
            shareURL = try await service.createShareLink()
        } catch {
            self.error = "Couldn't create a share link. Try again."
        }
    }

    private func content(_ data: CapstoneHistoryResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statsHeader(data.stats)
                weeklyChart(data.weeklySeries)

                if data.items.isEmpty {
                    emptyState
                } else {
                    Text("ATTEMPTS")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    VStack(spacing: 10) {
                        ForEach(data.items) { row in
                            historyRow(row)
                        }
                    }
                    if data.items.count < data.pagination.total {
                        Text("\(data.items.count) of \(data.pagination.total) shown")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(20)
        }
    }

    // MARK: - Stats header

    private func statsHeader(_ s: CapstoneHistoryStats) -> some View {
        HStack(spacing: 10) {
            statCell(label: "Attempts", value: "\(s.totalAttempts)", tone: .neutral)
            statCell(label: "Best", value: s.bestScore.map { "\($0)" } ?? "—", tone: .gold)
            statCell(label: "Avg", value: s.meanScore.map { "\($0)" } ?? "—", tone: .neutral)
            statCell(
                label: "Level",
                value: s.currentDifficulty.map { $0.capitalized } ?? "—",
                tone: .info
            )
        }
    }

    private enum StatTone { case neutral, gold, info }

    private func statCell(label: String, value: String, tone: StatTone) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(tone == .gold ? Color.accentColor : Color.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Weekly chart

    private func weeklyChart(_ series: [CapstoneWeeklyPoint]) -> some View {
        let totalCount = series.reduce(0) { $0 + $1.count }
        return VStack(alignment: .leading, spacing: 8) {
            Text("LAST 8 WEEKS")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            if totalCount == 0 {
                Text("No graded capstones in the last 8 weeks yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(series) { p in
                        weeklyBar(p)
                    }
                }
                .frame(height: 72)
                HStack(spacing: 0) {
                    Text("8w ago")
                    Spacer()
                    Text("This week")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func weeklyBar(_ p: CapstoneWeeklyPoint) -> some View {
        let height = CGFloat(p.meanScore ?? 0) * 0.72
        return VStack(spacing: 3) {
            Text(p.meanScore.map { "\($0)" } ?? "—")
                .font(.system(size: 8))
                .foregroundStyle(p.count == 0 ? Color.secondary : Color.accentColor)
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color(.tertiarySystemBackground))
                    .frame(maxWidth: .infinity, maxHeight: 72)
                if p.count > 0 {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(maxWidth: .infinity, maxHeight: max(2, height))
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text("\(p.count)")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - History row

    private func historyRow(_ row: CapstoneHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let score = row.overallScore {
                    Text("\(score)")
                        .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(.tint)
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if row.isRetry {
                    badge(text: "RETRY", tint: .secondary)
                }
                if let d = row.difficulty {
                    badge(text: d.capitalized, tint: .secondary)
                }
                if let track = row.roleTrack {
                    badge(text: track.uppercased(), tint: .secondary)
                }
            }

            Text(row.bundleBriefPreview)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack {
                Text(row.gradedAt.map(relative) ?? "—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if let bundleId = row.bundleId {
                    Button {
                        Task { await retry(bundleId: bundleId) }
                    } label: {
                        HStack(spacing: 4) {
                            if retryBusy == bundleId {
                                ProgressView().scaleEffect(0.65)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Try again")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(retryBusy != nil)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func badge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(Color(.tertiarySystemBackground)))
            .foregroundStyle(tint)
    }

    private func relative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: Date())
    }

    // MARK: - Empty / error

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("No capstones yet")
                .font(.headline)
            Text("Start a capstone from the Compass tab to see results here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text("Couldn't load history")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .padding(32)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        error = nil
        do {
            let r = try await service.history(limit: 100, offset: 0)
            self.response = r
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func retry(bundleId: String) async {
        retryBusy = bundleId
        defer { retryBusy = nil }
        do {
            _ = try await service.retry(bundleId: bundleId)
            await load()
        } catch CapstoneServiceError.invalidTransition {
            self.error = "Finish or abort your in-progress capstone first."
        } catch {
            self.error = error.localizedDescription
        }
    }
}
