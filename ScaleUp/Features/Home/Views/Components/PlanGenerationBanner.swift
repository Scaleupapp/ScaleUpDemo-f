import SwiftUI

// MARK: - LEGACY V1 — slated for removal

/// **DEPRECATED — Legacy V1 surface.**
/// Used only by v1 HomeView. v2 Home polls plan readiness inline.
/// Scheduled for removal after 2026-06-15.

@MainActor
@Observable
@available(*, deprecated, message: "Legacy V1 — v2 Home polls plan inline (see LEGACY_V1.md)")
final class PlanGenerationBannerViewModel {
    enum BannerState { case hidden, generating, ready }
    var state: BannerState = .hidden
    var planId: String?

    private var pollTask: Task<Void, Never>?
    private let service = PlanService.shared

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !(Task.isCancelled) {
                guard let self else { return }
                do {
                    let status = try await self.service.fetchStatus()
                    switch status.status {
                    case "ready", "completed":
                        self.state = .ready
                        self.planId = status.planId
                        return
                    case "generating", "pending":
                        self.state = .generating
                    case "no_diagnostic", "failed":
                        self.state = .hidden
                        return
                    default:
                        self.state = .hidden
                    }
                } catch {
                    // transient error — keep polling
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func dismiss() {
        state = .hidden
        stopPolling()
    }
}

struct PlanGenerationBanner: View {
    @State private var viewModel = PlanGenerationBannerViewModel()
    let onTapReady: () -> Void

    var body: some View {
        Group {
            switch viewModel.state {
            case .hidden:
                EmptyView()
            case .generating:
                generatingView
            case .ready:
                readyView
            }
        }
        .task { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
    }

    private var generatingView: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(ColorTokens.gold)
            Text("Building your personalized plan…")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ColorTokens.surface.opacity(0.5))
        )
        .padding(.horizontal, Spacing.lg)
    }

    private var readyView: some View {
        Button(action: { viewModel.dismiss(); onTapReady() }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("Your plan is ready 🎉")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Text("View →")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTokens.gold.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ColorTokens.gold.opacity(0.30), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
