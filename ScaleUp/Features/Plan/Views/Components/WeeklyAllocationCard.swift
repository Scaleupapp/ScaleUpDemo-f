import SwiftUI

struct WeeklyAllocationCard: View {
    let entry: APIPlanWeeklyEntry

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                Haptics.light()
            } label: {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.weekLabel)
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text(String(format: "%.1f hrs", entry.totalHours))
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)

            // Expanded allocations
            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Divider()
                        .background(ColorTokens.divider)

                    ForEach(entry.allocations, id: \.topic) { allocation in
                        allocationRow(allocation)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
        )
    }

    private func allocationRow(_ allocation: APIPlanAllocation) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(ColorTokens.gold.opacity(0.6))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(allocation.topic)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Text(String(format: "%.1fh", allocation.hoursAllocated))
                        .font(Typography.captionBold)
                        .foregroundStyle(ColorTokens.gold)
                }

                Text(allocation.focusActivity)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }
}
