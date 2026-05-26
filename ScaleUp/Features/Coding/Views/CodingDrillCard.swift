import SwiftUI

/// Self-contained card that loads today's coding drill on mount and renders
/// one of three states:
///   - .drillAvailable  → tappable drill card that opens DrillModalView
///   - .calibrationRequired → gradient card prompting the 6-min calibration
///   - .hidden / .loading → EmptyView or skeleton placeholder
///
/// Best-effort silent: any load failure (network down, no coding objective,
/// no bundle available) collapses to EmptyView so Home is never broken.
struct CodingDrillCard: View {

    @State private var loadState: LoadState = .loading
    @State private var showDrillModal = false
    @State private var showCalibrationModal = false

    private let service: DrillService

    init(service: DrillService = .shared) {
        self.service = service
    }

    enum LoadState {
        case loading
        case drillAvailable(DrillTodayResponse)
        case calibrationRequired
        case hidden  // network failure, no coding objective, or no bundle
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                loadingPlaceholder
            case .drillAvailable(let drill):
                drillCard(drill)
            case .calibrationRequired:
                calibrationCard
            case .hidden:
                EmptyView()
            }
        }
        .task { await loadDrill() }
        .sheet(isPresented: $showDrillModal) {
            DrillModalView()
                .onDisappear {
                    // Refetch after dismissal — user may have just completed
                    // today's quota, so we want to update the card state.
                    Task { await loadDrill() }
                }
        }
        .sheet(isPresented: $showCalibrationModal) {
            CalibrationSequenceView()
                .onDisappear {
                    Task { await loadDrill() }
                }
        }
    }

    // MARK: - Drill card

    private func drillCard(_ drill: DrillTodayResponse) -> some View {
        Button {
            DrillAnalytics.trackCardTapped(drill: drill)
            showDrillModal = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption.weight(.semibold))
                    Text("Today's coding drill")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(drill.timeBudgetMinutes) min")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.tint)

                Text(drill.brief)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    badge(text: drill.drillSubtype.displayName)
                    badge(text: drill.difficulty.rawValue.capitalized)
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
        .onAppear {
            DrillAnalytics.trackCardShown(drill: drill)
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Calibration card

    private var calibrationCard: some View {
        Button {
            DrillAnalytics.trackCalibrationCardTapped()
            showCalibrationModal = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                    Text("New: coding practice for your objective")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.tint)

                Text("Take a 6-min calibration to see where you stand.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack {
                    Text("Start →")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            DrillAnalytics.trackCalibrationCardShown()
        }
    }

    // MARK: - Loading placeholder (skeleton — same shape as the drill card)

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 140, height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 200, height: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .redacted(reason: .placeholder)
    }

    // MARK: - Loading

    private func loadDrill() async {
        do {
            let drill = try await service.fetchTodayDrill()
            loadState = .drillAvailable(drill)
        } catch DrillServiceError.calibrationRequired {
            loadState = .calibrationRequired
        } catch DrillServiceError.noDrillAvailable {
            loadState = .hidden
        } catch {
            // Network failure, no coding objective, anything else — silently hide
            // so Home never breaks for users who can't use this feature.
            loadState = .hidden
        }
    }
}
