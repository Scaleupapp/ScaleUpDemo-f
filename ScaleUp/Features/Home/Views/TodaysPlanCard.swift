import SwiftUI

// MARK: - Hero Plan Card (Netflix-style)

struct HeroPlanCard: View {
    let journey: JourneySummary
    var onTapPlan: (() -> Void)? = nil

    private var progressPercent: Double {
        journey.progress.overallPercentage ?? 0
    }

    var body: some View {
        Button {
            onTapPlan?()
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background gradient
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#6C5CE7").opacity(0.6),
                                Color(hex: "#0A0A0F").opacity(0.95)
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .frame(height: 200)

                // Decorative circles
                Circle()
                    .fill(ColorTokens.primary.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .offset(x: 220, y: -60)

                Circle()
                    .fill(ColorTokens.primaryLight.opacity(0.06))
                    .frame(width: 100, height: 100)
                    .offset(x: -20, y: -80)

                // Content
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Phase badge
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 10))
                        Text((journey.currentPhase ?? "Foundation").uppercased())
                            .font(Typography.micro)
                            .tracking(1.2)
                    }
                    .foregroundStyle(ColorTokens.primaryLight)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(ColorTokens.primary.opacity(0.2))
                    .clipShape(Capsule())

                    // Title
                    Text(journey.title)
                        .font(Typography.titleLarge)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()
                        .frame(height: 2)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.12))

                            RoundedRectangle(cornerRadius: 3)
                                .fill(ColorTokens.progressGradient)
                                .frame(width: max(0, geo.size.width * (progressPercent / 100)))
                        }
                    }
                    .frame(height: 5)

                    // Stats row
                    HStack(spacing: Spacing.lg) {
                        HeroStat(label: "Week", value: "\(journey.currentWeek)")

                        HeroStat(label: "Progress", value: "\(Int(progressPercent))%")

                        HeroStat(
                            label: "Content",
                            value: "\(journey.progress.contentConsumed ?? 0)/\(journey.progress.contentAssigned ?? 0)"
                        )

                        if let streak = journey.streak, streak > 0 {
                            HeroStat(label: "Streak", value: "\(streak)d", icon: "flame.fill", iconColor: .orange)
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Hero Stat

private struct HeroStat: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .tracking(0.5)

            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(iconColor)
                }
                Text(value)
                    .font(Typography.mono)
                    .foregroundStyle(.white)
            }
        }
    }
}
