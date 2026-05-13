import SwiftUI

/// V2 Objective Setup — text-led (mockup screen 01).
/// User types their goal in their own words; taxonomy autocompletes.
/// Popular full-sentence suggestions tap to fill.
/// Specifics use proper input fields with autocomplete chips.
struct V2ObjectiveSetupView: View {
    @State private var goalText: String = "SDE placement at Google"
    @State private var matched: Bool = true
    @State private var targetCompanies: [String] = ["Google", "Microsoft"]
    @State private var newCompany: String = ""
    @State private var location: String = ""
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                OnboardProgressBar(currentStep: 2, totalSteps: 4)
                    .padding(.bottom, 22)

                Text("What's your goal?")
                    .font(V2Theme.h1)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Tell us in your own words. We'll figure out the rest.")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                // Big search input
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ColorTokens.textTertiary)
                    TextField("", text: $goalText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(matched ? ColorTokens.gold : ColorTokens.textPrimary)
                    if matched {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                            Text("matched").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(ColorTokens.success)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ColorTokens.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(ColorTokens.surfaceElevated, lineWidth: 1.5)
                )

                Text("Try: \"Crack CAT 2026\" · \"Switch from service to product\" · \"Master AI/ML\"")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                Text("Popular goals".uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(1)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    popularGoalCard(highlighted: "SDE placement", suffix: "at Google or FAANG")
                    popularGoalCard(prefix: "Switch from service to ", highlighted: "product engineering")
                    popularGoalCard(highlighted: "CAT 2026", suffix: "— target IIM A/B/C")
                    popularGoalCard(prefix: "Become ", highlighted: "AI/ML", suffix: " engineer in 6 months")
                }
                .padding(.bottom, 26)

                Divider().background(V2Theme.cardBorder).padding(.vertical, 8)

                // Specifics
                HStack(alignment: .firstTextBaseline) {
                    Text("A few specifics")
                        .font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary)
                    Text("— quick, then we're done")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.top, 14)
                .padding(.bottom, 14)

                // Target role
                specificsField(label: "Target role", value: "Software Development Engineer", dropdown: true)

                // Target companies
                VStack(alignment: .leading, spacing: 6) {
                    Text("Target companies (optional)".uppercased())
                        .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(ColorTokens.textTertiary)
                    HStack(spacing: 6) {
                        ForEach(targetCompanies, id: \.self) { company in
                            HStack(spacing: 4) {
                                Text(company).font(.system(size: 11, weight: .semibold))
                                Text("×").foregroundStyle(ColorTokens.gold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(ColorTokens.gold.opacity(0.15)))
                            .overlay(Capsule().strokeBorder(ColorTokens.gold, lineWidth: 1))
                            .foregroundStyle(ColorTokens.gold)
                        }
                        TextField("type to add…", text: $newCompany)
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                }
                .padding(.bottom, 12)

                specificsField(label: "Achieve it by", value: "August 2026 · ~6 months", dropdown: true)
                specificsFieldInput(label: "Where are you right now?", placeholder: "Your college or workplace…", text: $location)
                    .padding(.bottom, 22)

                Button {
                    path.append(V2OnboardingRoute.realityCheck)
                } label: {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(ColorTokens.gold)
                    .foregroundStyle(ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Helpers

    private func popularGoalCard(prefix: String = "", highlighted: String, suffix: String = "") -> some View {
        Button {
            goalText = "\(prefix)\(highlighted)\(suffix)"
            matched = true
        } label: {
            HStack {
                HStack(spacing: 0) {
                    if !prefix.isEmpty {
                        Text(prefix).foregroundStyle(ColorTokens.textPrimary)
                    }
                    Text(highlighted)
                        .foregroundStyle(ColorTokens.gold)
                        .fontWeight(.semibold)
                    if !suffix.isEmpty {
                        Text(suffix).foregroundStyle(ColorTokens.textPrimary)
                    }
                }
                .font(V2Theme.body)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .v2Card(padding: 0)
        }
        .buttonStyle(.plain)
    }

    private func specificsField(label: String, value: String, dropdown: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
            HStack {
                Text(value).font(V2Theme.body).foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                if dropdown {
                    Image(systemName: "chevron.down").font(.system(size: 11)).foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
        }
        .padding(.bottom, 12)
    }

    private func specificsFieldInput(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
            TextField(placeholder, text: text)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
        }
    }
}

enum V2OnboardingRoute: Hashable {
    case realityCheck
    case calibrationInsights
}

struct OnboardProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                Capsule()
                    .fill(idx < currentStep ? ColorTokens.gold : (idx == currentStep ? ColorTokens.gold.opacity(0.5) : ColorTokens.surfaceElevated))
                    .frame(height: 3)
            }
        }
    }
}

#Preview {
    NavigationStack {
        V2ObjectiveSetupView(path: .constant(NavigationPath()))
    }
    .preferredColorScheme(.dark)
}
