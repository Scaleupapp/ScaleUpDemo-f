import SwiftUI

/// V2 Reality Check — required-time computed (mockup screen 02).
///
/// Calls POST /api/v2/objective/required-time to fetch the honest hours/week
/// for the user's objective + timeline + proficiency.
struct V2RealityCheckView: View {
    @State private var hoursPerWeek: Int = 25
    @State private var hoursPerDay: Double = 3.5
    @State private var loading: Bool = false
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardProgressBar(currentStep: 3, totalSteps: 4)
                    .padding(.bottom, 22)

                Text("Reality check".uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.bottom, 10)

                Text("Here's what it actually takes")
                    .font(V2Theme.h1)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.bottom, 14)

                Text("For ")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                + Text("SDE @ Google/Microsoft in 6 months").font(V2Theme.bodyMedium).foregroundStyle(ColorTokens.gold)
                + Text(", based on your inputs:").font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)

                // Big number card
                VStack(spacing: 8) {
                    Text("You'll need to invest".uppercased())
                        .font(.system(size: 10, weight: .semibold)).tracking(1)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("\(hoursPerWeek)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                    Text("hours per week")
                        .font(V2Theme.bodyMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("≈ \(String(format: "%.1f", hoursPerDay)) hours / day if studying daily")
                        .font(V2Theme.small).foregroundStyle(ColorTokens.textTertiary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(V2Theme.heroGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1)
                )
                .padding(.vertical, 22)

                Text("We don't pretend the impossible is possible. Choose honestly:")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.bottom, 14)

                pathCard(
                    color: ColorTokens.success,
                    badge: "✓",
                    title: "I can commit to 25 hrs/week",
                    sub: "Plan generates for 6 months. Realistic.",
                    isPrimary: true
                ) {
                    path.append(V2OnboardingRoute.calibrationInsights)
                }

                pathCard(
                    color: ColorTokens.warning,
                    badge: "⚠",
                    title: "I can do less — adjust",
                    sub: "At 15 hrs/wk, realistic timeline is 10 months. Pick what fits."
                ) {
                    // TODO: open adjustment sheet
                }

                pathCard(
                    color: ColorTokens.gold,
                    badge: "↑",
                    title: "I can do more — faster path",
                    sub: "At 40 hrs/wk you could target 4 months. Burnout risk is real."
                ) {
                    // TODO: confirm and proceed
                }

                Text("No silent acceptance of unrealistic combinations.\nYou always see the tradeoff.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .task {
            await fetchRequiredTime()
        }
    }

    @MainActor
    private func fetchRequiredTime() async {
        loading = true
        defer { loading = false }
        // Placeholder for v2 backend wiring:
        //   try await V2APIClient.shared.post("/objective/required-time", body: ...)
        // For now we render the design with the example numbers from the mockup.
    }

    private func pathCard(color: Color, badge: String, title: String, sub: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(badge)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(V2Theme.h3)
                        .foregroundStyle(isPrimary ? color : ColorTokens.textPrimary)
                    Text(sub)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .fill(isPrimary ? color.opacity(0.06) : ColorTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .strokeBorder(isPrimary ? color : V2Theme.cardBorder, lineWidth: isPrimary ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }
}

#Preview {
    NavigationStack {
        V2RealityCheckView(path: .constant(NavigationPath()))
    }
    .preferredColorScheme(.dark)
}
