import SwiftUI

struct V2CodingMasteryView: View {
    @State private var state: LoadState = .loading
    @State private var showDrillModal = false
    @State private var showCalibration = false

    enum LoadState {
        case loading
        case empty
        case loaded(CodingMasteryResponse)
        case error(String)
    }

    var body: some View {
        ScrollView {
            content
                .padding(20)
        }
        .navigationTitle("Coding mastery")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .sheet(isPresented: $showDrillModal) {
            DrillModalView()
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationSequenceView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        case .empty:
            emptyState
        case .loaded(let data):
            loadedView(data)
        case .error(let msg):
            ContentUnavailableView("Couldn't load", systemImage: "exclamationmark.triangle", description: Text(msg))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.top, 40)
            Text("Coding practice for your objective")
                .font(.title3.weight(.semibold))
            Text("Take a 6-min calibration to find your starting level, then daily 10-min drills build the meta-skills companies actually hire for.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showCalibration = true
            } label: {
                Text("Start calibration").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }

    private func loadedView(_ data: CodingMasteryResponse) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Stats card
            statsCard(data.stats)

            // Per-track mastery bars
            ForEach(data.tracks, id: \.roleTrack) { track in
                trackCard(track)
            }

            // Recent attempts
            if !data.recentAttempts.isEmpty {
                recentAttemptsList(data.recentAttempts)
            }

            // CTA
            Button {
                showDrillModal = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Take today's drill")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func statsCard(_ stats: CodingMasteryStats) -> some View {
        HStack(spacing: 16) {
            statTile(label: "Drills graded", value: "\(stats.totalDrillsGraded)")
            statTile(label: "Avg score", value: stats.averageScore.map { "\($0)" } ?? "—")
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.weight(.bold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func trackCard(_ track: CodingMasteryTrack) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(roleTrackTitle(track.roleTrack))
                    .font(.headline)
                Spacer()
                Text(track.currentDifficulty.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 10) {
                RubricBar(dimension: "prompting", score: track.axes.prompting / 10.0, feedback: nil)
                RubricBar(dimension: "verification", score: track.axes.verification / 10.0, feedback: nil)
                RubricBar(dimension: "decomposition", score: track.axes.decomposition / 10.0, feedback: nil)
                RubricBar(dimension: "refactoring", score: track.axes.refactoring / 10.0, feedback: nil)
            }

            HStack {
                Text("\(track.attemptCount) drills · confidence \(Int(track.confidence * 100))%")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recentAttemptsList(_ attempts: [CodingMasteryAttempt]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent attempts")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(attempts) { a in
                    attemptRow(a)
                    if a.id != attempts.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func attemptRow(_ a: CodingMasteryAttempt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(a.drillSubtype.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline.weight(.semibold))
                    if a.isCalibration {
                        Text("CALIBRATION").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.2)).clipShape(Capsule())
                    }
                }
                Text("\(a.difficulty?.capitalized ?? "—") · \(relativeTime(a.submittedAt))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let score = a.score {
                Text("\(score)").font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(score >= 80 ? .green : score >= 60 ? .orange : .red)
            } else {
                Text("—").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func roleTrackTitle(_ key: String) -> String {
        switch key {
        case "swe": return "Software Engineer"
        case "ds": return "Data Scientist"
        case "ai_eng": return "AI / ML Engineer"
        default: return key.uppercased()
        }
    }

    private func relativeTime(_ iso: String?) -> String {
        guard let iso = iso, let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func load() async {
        do {
            let resp: V2APIResponse<CodingMasteryResponse> = try await V2APIClient.shared.get("/you/coding-mastery")
            if resp.data.tracks.isEmpty {
                state = .empty
            } else {
                state = .loaded(resp.data)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

// MARK: - Backing models for /api/v2/you/coding-mastery

struct CodingMasteryResponse: Codable, Sendable {
    let tracks: [CodingMasteryTrack]
    let recentAttempts: [CodingMasteryAttempt]
    let stats: CodingMasteryStats

    enum CodingKeys: String, CodingKey {
        case tracks
        case recentAttempts = "recent_attempts"
        case stats
    }
}

struct CodingMasteryTrack: Codable, Sendable {
    let roleTrack: String
    let axes: CodingMasteryAxes
    let confidence: Double
    let attemptCount: Int
    let currentDifficulty: String

    enum CodingKeys: String, CodingKey {
        case roleTrack = "role_track"
        case axes
        case confidence
        case attemptCount = "attempt_count"
        case currentDifficulty = "current_difficulty"
    }
}

struct CodingMasteryAxes: Codable, Sendable {
    let prompting: Double
    let verification: Double
    let decomposition: Double
    let refactoring: Double
}

struct CodingMasteryAttempt: Codable, Sendable, Identifiable {
    let id: String
    let drillSubtype: String
    let difficulty: String?
    let roleTrack: String?
    let score: Int?
    let submittedAt: String?
    let isCalibration: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case drillSubtype = "drill_subtype"
        case difficulty
        case roleTrack = "role_track"
        case score
        case submittedAt = "submitted_at"
        case isCalibration = "is_calibration"
    }
}

struct CodingMasteryStats: Codable, Sendable {
    let totalDrillsGraded: Int
    let averageScore: Int?

    enum CodingKeys: String, CodingKey {
        case totalDrillsGraded = "total_drills_graded"
        case averageScore = "average_score"
    }
}

#Preview {
    NavigationStack { V2CodingMasteryView() }
        .preferredColorScheme(.dark)
}
