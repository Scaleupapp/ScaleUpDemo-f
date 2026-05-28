import SwiftUI

/// Replay scrubber (spec §7.4). Loads the replay descriptor (presigned
/// URLs for the event stream + snapshot index + evaluator-flagged moments)
/// and lets the learner scrub a timeline. Per spec, "watchable in 5–10 min."
///
/// Snapshots render the code at any moment. Flagged moments are tap-able.
struct CapstoneReplayView: View {
    let sessionId: String
    @Environment(\.dismiss) private var dismiss

    @State private var replay: CapstoneReplay?
    @State private var loading = true
    @State private var error: String?
    @State private var scrubT: Double = 0
    @State private var loadedSnapshot: CapstoneSnapshotPayload?
    @State private var loadingSnapshot = false

    struct CapstoneSnapshotPayload: Codable, Sendable {
        let tSeconds: Int
        let files: [SnapshotFile]

        struct SnapshotFile: Codable, Sendable, Identifiable {
            let path: String
            let content: String
            var id: String { path }
        }

        enum CodingKeys: String, CodingKey {
            case tSeconds = "t_seconds"
            case files
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Replay")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView("Preparing replay…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = error {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                Text("Couldn't load replay").font(.headline)
                Text(err).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let r = replay {
            VStack(spacing: 16) {
                scrubber(replay: r)
                snapshotView
                if !r.flaggedMoments.isEmpty { flaggedList(r) }
            }
            .padding(.top, 12)
        }
    }

    private func scrubber(replay r: CapstoneReplay) -> some View {
        VStack(spacing: 6) {
            Slider(value: $scrubT, in: 0...Double(max(1, r.durationSeconds))) { editing in
                if !editing { Task { await loadSnapshotAt(time: Int(scrubT), replay: r) } }
            }
            HStack {
                Text(formatTime(Int(scrubT))).font(.caption.monospacedDigit())
                Spacer()
                Text(formatTime(r.durationSeconds)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var snapshotView: some View {
        if loadingSnapshot {
            ProgressView().frame(maxWidth: .infinity).padding()
        } else if let snap = loadedSnapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(snap.files) { f in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(f.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.tint)
                            Text(f.content)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        } else {
            Text("Drag the slider to load a snapshot.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.top, 20)
        }
    }

    private func flaggedList(_ r: CapstoneReplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flagged moments").font(.headline).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(r.flaggedMoments) { m in
                        Button {
                            scrubT = Double(m.tSeconds)
                            Task { await loadSnapshotAt(time: m.tSeconds, replay: r) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatTime(m.tSeconds)).font(.caption.monospacedDigit())
                                Text(m.label).font(.subheadline.weight(.medium)).lineLimit(2)
                            }
                            .padding(12)
                            .background(Color.accentColor.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: 220, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func load() async {
        loading = true
        do {
            let r = try await CapstoneService.shared.getReplay(sessionId: sessionId)
            await MainActor.run {
                replay = r
                loading = false
            }
            if let firstSnap = r.snapshots.first {
                scrubT = Double(firstSnap.tSeconds)
                await loadSnapshotAt(time: firstSnap.tSeconds, replay: r)
            }
        } catch {
            await MainActor.run {
                self.error = "Replay isn't available yet. Recording artifacts may still be processing."
                self.loading = false
            }
        }
    }

    private func loadSnapshotAt(time: Int, replay: CapstoneReplay) async {
        // Find the snapshot whose t_seconds is the largest ≤ requested time.
        guard let target = replay.snapshots.last(where: { $0.tSeconds <= time }) ?? replay.snapshots.first else {
            return
        }
        guard let url = URL(string: target.snapshotUrl) else { return }
        await MainActor.run { loadingSnapshot = true }
        defer { Task { await MainActor.run { loadingSnapshot = false } } }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let snap = try JSONDecoder().decode(CapstoneSnapshotPayload.self, from: data)
            await MainActor.run { loadedSnapshot = snap }
        } catch {
            // ignore — keep the previous snapshot rendered
        }
    }

    private func formatTime(_ t: Int) -> String {
        String(format: "%d:%02d", t / 60, t % 60)
    }
}
