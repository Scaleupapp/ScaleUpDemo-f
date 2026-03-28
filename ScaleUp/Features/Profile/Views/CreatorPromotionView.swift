import SwiftUI

@Observable
@MainActor
final class CreatorPromotionViewModel {
    var creators: [Creator] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    // Promotion sheet state
    var showPromoteSheet = false
    var showDemoteConfirm = false
    var targetCreator: Creator?
    var targetTier: String = ""
    var promotionReason = ""

    private let adminService = AdminService()
    private let creatorService = CreatorService()

    var filteredCreators: [Creator] {
        if searchText.isEmpty { return creators }
        let query = searchText.lowercased()
        return creators.filter {
            $0.displayName.lowercased().contains(query) ||
            ($0.domain ?? "").lowercased().contains(query) ||
            ($0.username ?? "").lowercased().contains(query)
        }
    }

    var anchorCreators: [Creator] { filteredCreators.filter { $0.tier == .anchor } }
    var coreCreators: [Creator] { filteredCreators.filter { $0.tier == .core } }
    var risingCreators: [Creator] { filteredCreators.filter { $0.tier == .rising } }

    func loadCreators() async {
        isLoading = true
        errorMessage = nil
        do {
            creators = try await adminService.fetchCreators()
        } catch {
            // Fallback to public search if admin endpoint fails (non-admin user)
            creators = (try? await creatorService.searchCreators()) ?? []
            if creators.isEmpty {
                errorMessage = "Failed to load creators"
            }
        }
        isLoading = false
    }

    func promote() async {
        guard let creator = targetCreator, !promotionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await adminService.promoteCreator(userId: creator.id, tier: targetTier, reason: promotionReason)
            Haptics.success()
            promotionReason = ""
            showPromoteSheet = false
            await loadCreators()
        } catch {
            errorMessage = "Failed to update tier"
            Haptics.error()
        }
    }

    func demote() async {
        guard let creator = targetCreator else { return }
        do {
            try await adminService.promoteCreator(userId: creator.id, tier: targetTier, reason: "Demoted by admin")
            Haptics.success()
            showDemoteConfirm = false
            await loadCreators()
        } catch {
            errorMessage = "Failed to demote creator"
            Haptics.error()
        }
    }

    func nextTier(for tier: CreatorTier?) -> String? {
        switch tier {
        case .rising: return "core"
        case .core: return "anchor"
        case .anchor: return nil // can't promote anchor
        default: return "core"
        }
    }

    func previousTier(for tier: CreatorTier?) -> String? {
        switch tier {
        case .anchor: return "core"
        case .core: return "rising"
        case .rising: return nil
        default: return nil
        }
    }
}

struct CreatorPromotionView: View {
    @State private var viewModel = CreatorPromotionViewModel()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.creators.isEmpty {
                ProgressView().tint(ColorTokens.gold)
            } else if viewModel.creators.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("No creators found")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.error)
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Summary bar
                        summaryBar

                        // Anchor tier
                        if !viewModel.anchorCreators.isEmpty {
                            tierSection(
                                tier: .anchor,
                                creators: viewModel.anchorCreators,
                                isTopTier: true
                            )
                        }

                        // Core tier
                        if !viewModel.coreCreators.isEmpty {
                            tierSection(
                                tier: .core,
                                creators: viewModel.coreCreators,
                                isTopTier: false
                            )
                        }

                        // Rising tier
                        if !viewModel.risingCreators.isEmpty {
                            tierSection(
                                tier: .rising,
                                creators: viewModel.risingCreators,
                                isTopTier: false
                            )
                        }

                        if viewModel.filteredCreators.isEmpty && !viewModel.searchText.isEmpty {
                            VStack(spacing: Spacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 28))
                                    .foregroundStyle(ColorTokens.textTertiary)
                                Text("No creators match \"\(viewModel.searchText)\"")
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xl)
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
        }
        .navigationTitle("Creator Tiers")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Search creators...")
        .task {
            await viewModel.loadCreators()
        }
        .refreshable {
            await viewModel.loadCreators()
        }
        .sheet(isPresented: $viewModel.showPromoteSheet) {
            if let creator = viewModel.targetCreator {
                PromoteCreatorSheet(
                    creator: creator,
                    targetTier: viewModel.targetTier,
                    reason: $viewModel.promotionReason,
                    onPromote: { Task { await viewModel.promote() } },
                    onCancel: {
                        viewModel.promotionReason = ""
                        viewModel.showPromoteSheet = false
                    }
                )
            }
        }
        .alert("Demote Creator", isPresented: $viewModel.showDemoteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Demote", role: .destructive) {
                Task { await viewModel.demote() }
            }
        } message: {
            if let creator = viewModel.targetCreator {
                Text("Demote \(creator.displayName) from \(creator.tier?.displayName ?? "current") to \(viewModel.targetTier.capitalized) tier?")
            }
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: Spacing.md) {
            tierCount(count: viewModel.anchorCreators.count, tier: .anchor)
            tierCount(count: viewModel.coreCreators.count, tier: .core)
            tierCount(count: viewModel.risingCreators.count, tier: .rising)
        }
        .padding(.horizontal, Spacing.md)
    }

    private func tierCount(count: Int, tier: CreatorTier) -> some View {
        VStack(spacing: 4) {
            Image(systemName: tier.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tier.color)
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.textPrimary)
            Text(tier.displayName)
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Tier Section

    private func tierSection(tier: CreatorTier, creators: [Creator], isTopTier: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack(spacing: Spacing.sm) {
                Image(systemName: tier.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tier.color)
                Text(tier.displayName)
                    .font(Typography.bodyBold)
                    .foregroundStyle(tier.color)
                Text("\(creators.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tier.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(tier.color.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, Spacing.md)

            // Creator rows
            VStack(spacing: 1) {
                ForEach(creators) { creator in
                    creatorRow(creator, tier: tier, isTopTier: isTopTier)
                }
            }
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    private func creatorRow(_ creator: Creator, tier: CreatorTier, isTopTier: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            CreatorAvatar(creator: creator, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(creator.displayName)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)
                    if creator.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.info)
                    }
                }
                if let domain = creator.domain, !domain.isEmpty {
                    Text(domain.capitalized)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isTopTier {
                // Anchor — show badge, allow demote via context menu
                Text("Top Tier")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tier.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tier.color.opacity(0.12))
                    .clipShape(Capsule())
                    .contextMenu {
                        if let prev = viewModel.previousTier(for: creator.tier) {
                            Button(role: .destructive) {
                                viewModel.targetCreator = creator
                                viewModel.targetTier = prev
                                viewModel.showDemoteConfirm = true
                            } label: {
                                Label("Demote to \(prev.capitalized)", systemImage: "arrow.down.circle")
                            }
                        }
                    }
            } else {
                promotionActions(for: creator)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func promotionActions(for creator: Creator) -> some View {
        let currentTier = creator.tier ?? .rising

        HStack(spacing: Spacing.xs) {
            // Promote button
            if let next = viewModel.nextTier(for: currentTier) {
                Button {
                    viewModel.targetCreator = creator
                    viewModel.targetTier = next
                    viewModel.promotionReason = ""
                    viewModel.showPromoteSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                        Text(next.capitalized)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(currentTier == .core ? ColorTokens.gold : ColorTokens.info)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((currentTier == .core ? ColorTokens.gold : ColorTokens.info).opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
        .contextMenu {
            if let prev = viewModel.previousTier(for: currentTier) {
                Button(role: .destructive) {
                    viewModel.targetCreator = creator
                    viewModel.targetTier = prev
                    viewModel.showDemoteConfirm = true
                } label: {
                    Label("Demote to \(prev.capitalized)", systemImage: "arrow.down.circle")
                }
            }
        }
    }
}

// MARK: - Promote Creator Sheet

struct PromoteCreatorSheet: View {
    let creator: Creator
    let targetTier: String
    @Binding var reason: String
    let onPromote: () -> Void
    let onCancel: () -> Void

    @FocusState private var reasonFocused: Bool

    private var targetTierEnum: CreatorTier? {
        CreatorTier(rawValue: targetTier)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Creator info
                        VStack(spacing: Spacing.sm) {
                            CreatorAvatar(creator: creator, size: 64)

                            Text(creator.displayName)
                                .font(Typography.titleMedium)
                                .foregroundStyle(ColorTokens.textPrimary)

                            if let domain = creator.domain {
                                Text(domain.capitalized)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }

                        // Tier change visual
                        HStack(spacing: Spacing.md) {
                            tierBadge(tier: creator.tier ?? .rising, label: "Current")

                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(ColorTokens.gold)

                            if let target = targetTierEnum {
                                tierBadge(tier: target, label: "New Tier")
                            }
                        }
                        .padding(.vertical, Spacing.sm)

                        // Reason field
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Reason for Promotion")
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimary)

                            Text("Explain why this creator should be promoted. This will be recorded in their tier history.")
                                .font(Typography.micro)
                                .foregroundStyle(ColorTokens.textTertiary)

                            TextEditor(text: $reason)
                                .focused($reasonFocused)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .padding(Spacing.sm)
                                .background(ColorTokens.surface)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(reasonFocused ? ColorTokens.gold : ColorTokens.border, lineWidth: 1)
                                )
                                .foregroundStyle(ColorTokens.textPrimary)
                        }

                        // Promote button
                        Button {
                            onPromote()
                        } label: {
                            Text("Promote to \(targetTier.capitalized)")
                                .font(Typography.bodyBold)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ColorTokens.gold.opacity(0.4) : ColorTokens.gold)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                        .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("Promote Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .onAppear { reasonFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func tierBadge(tier: CreatorTier, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: tier.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tier.color)
            Text(tier.displayName)
                .font(Typography.bodyBold)
                .foregroundStyle(tier.color)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(tier.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}
