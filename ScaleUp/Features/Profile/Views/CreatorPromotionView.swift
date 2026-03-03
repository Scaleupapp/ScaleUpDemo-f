import SwiftUI

@Observable
@MainActor
final class CreatorPromotionViewModel {
    var creators: [Creator] = []
    var isLoading = false
    var showPromoteConfirm = false
    var showDemoteConfirm = false
    var targetCreator: Creator?
    var targetTier: String = ""

    private let creatorService = CreatorService()
    private let adminService = AdminService()

    var anchorCreators: [Creator] { creators.filter { $0.tier == .anchor } }
    var coreCreators: [Creator] { creators.filter { $0.tier == .core } }
    var risingCreators: [Creator] { creators.filter { $0.tier == .rising } }

    func loadCreators() async {
        isLoading = true
        creators = (try? await creatorService.searchCreators()) ?? []
        isLoading = false
    }

    func changeTier(_ creator: Creator, to tier: String) async {
        do {
            try await adminService.promoteCreator(userId: creator.id, tier: tier)
            Haptics.success()
            await loadCreators()
        } catch {
            Haptics.error()
        }
    }
}

struct CreatorPromotionView: View {
    @State private var viewModel = CreatorPromotionViewModel()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if viewModel.creators.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("No creators found")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            } else {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Anchor tier
                        if !viewModel.anchorCreators.isEmpty {
                            tierSection(
                                title: "Anchor",
                                icon: "crown.fill",
                                color: Color(red: 0.85, green: 0.65, blue: 0.13),
                                creators: viewModel.anchorCreators,
                                isTopTier: true
                            )
                        }

                        // Core tier
                        if !viewModel.coreCreators.isEmpty {
                            tierSection(
                                title: "Core",
                                icon: "star.fill",
                                color: ColorTokens.gold,
                                creators: viewModel.coreCreators,
                                isTopTier: false
                            )
                        }

                        // Rising tier
                        if !viewModel.risingCreators.isEmpty {
                            tierSection(
                                title: "Rising",
                                icon: "arrow.up.right",
                                color: ColorTokens.info,
                                creators: viewModel.risingCreators,
                                isTopTier: false
                            )
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
        }
        .navigationTitle("Creator Tiers")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadCreators()
        }
        .refreshable {
            await viewModel.loadCreators()
        }
        .alert("Promote Creator", isPresented: $viewModel.showPromoteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Promote") {
                if let creator = viewModel.targetCreator {
                    Task { await viewModel.changeTier(creator, to: viewModel.targetTier) }
                }
            }
        } message: {
            if let creator = viewModel.targetCreator {
                Text("Promote \(creator.displayName) to \(viewModel.targetTier.capitalized) tier?")
            }
        }
        .alert("Demote Creator", isPresented: $viewModel.showDemoteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Demote", role: .destructive) {
                if let creator = viewModel.targetCreator {
                    Task { await viewModel.changeTier(creator, to: viewModel.targetTier) }
                }
            }
        } message: {
            if let creator = viewModel.targetCreator {
                Text("Demote \(creator.displayName) to \(viewModel.targetTier.capitalized) tier?")
            }
        }
    }

    // MARK: - Tier Section

    private func tierSection(title: String, icon: String, color: Color, creators: [Creator], isTopTier: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(Typography.bodyBold)
                    .foregroundStyle(color)
                Text("\(creators.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, Spacing.md)

            // Creator rows
            VStack(spacing: 1) {
                ForEach(creators) { creator in
                    creatorRow(creator, sectionColor: color, isTopTier: isTopTier)
                }
            }
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    private func creatorRow(_ creator: Creator, sectionColor: Color, isTopTier: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            CreatorAvatar(creator: creator, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(creator.displayName)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let domain = creator.domain, !domain.isEmpty {
                    Text(domain)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isTopTier {
                // Anchor — show "Top Tier" badge, demote in context menu
                Text("Top Tier")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(sectionColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sectionColor.opacity(0.12))
                    .clipShape(Capsule())
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.targetCreator = creator
                            viewModel.targetTier = "core"
                            viewModel.showDemoteConfirm = true
                        } label: {
                            Label("Demote to Core", systemImage: "arrow.down.circle")
                        }
                    }
            } else {
                // Show promote button
                promotionMenu(for: creator)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func promotionMenu(for creator: Creator) -> some View {
        let tier = creator.tier ?? .rising

        switch tier {
        case .core:
            HStack(spacing: Spacing.xs) {
                Button {
                    viewModel.targetCreator = creator
                    viewModel.targetTier = "anchor"
                    viewModel.showPromoteConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                        Text("Anchor")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(Capsule())
                }
                .contextMenu {
                    Button(role: .destructive) {
                        viewModel.targetCreator = creator
                        viewModel.targetTier = "rising"
                        viewModel.showDemoteConfirm = true
                    } label: {
                        Label("Demote to Rising", systemImage: "arrow.down.circle")
                    }
                }
            }

        case .rising:
            Button {
                viewModel.targetCreator = creator
                viewModel.targetTier = "core"
                viewModel.showPromoteConfirm = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                    Text("Core")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(ColorTokens.info)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ColorTokens.info.opacity(0.12))
                .clipShape(Capsule())
            }

        default:
            EmptyView()
        }
    }
}
