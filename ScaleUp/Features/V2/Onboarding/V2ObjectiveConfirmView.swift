import SwiftUI

/// V2 Objective Confirmation Gate — Step 2 of onboarding.
///
/// The gate that makes "stupid in → stupid out" structurally impossible.
/// Renders the NLU parse result three ways:
///   - green     → "Here's what we understood" + confirm
///   - long_tail → "We'll build your plan, but it's not curated yet" + confirm
///   - rejected  → "We couldn't read that as a goal" + browse catalog / retry
///
/// Every path also offers "Let me fix it" → structured manual pickers.
struct V2ObjectiveConfirmView: View {
    @Environment(V2OnboardingState.self) private var state
    @Binding var path: NavigationPath

    @State private var showManualPicker = false

    private var result: V2ObjectiveParseResult? { state.parseResult }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardProgressBar(currentStep: 2, totalSteps: 4)
                    .padding(.bottom, 22)

                if let result = result {
                    statusBadge(result)
                        .padding(.bottom, 12)

                    Text(result.message.title)
                        .font(V2Theme.h1)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .padding(.bottom, 10)

                    Text(result.message.body)
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 20)

                    if result.isRejected {
                        rejectedContent(result)
                    } else {
                        understoodContent(result)
                    }
                } else {
                    Text("Something went wrong reading your goal.")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Button("Go back") { path = NavigationPath() }
                        .buttonStyle(.bordered)
                        .tint(ColorTokens.gold)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .sheet(isPresented: $showManualPicker) {
            V2ManualObjectivePicker(path: $path)
                .environment(state)
        }
    }

    // MARK: - Green / long-tail: "here's what we understood"

    @ViewBuilder
    private func understoodContent(_ result: V2ObjectiveParseResult) -> some View {
        // Structured interpretation card
        VStack(alignment: .leading, spacing: 12) {
            interpretationRow(label: "Objective", value: state.objectiveType.displayName)
            if !state.targetRole.isEmpty {
                interpretationRow(label: "Role", value: state.targetRole,
                                  verified: result.catalogMatches.role != nil)
            }
            if !state.targetCompany.isEmpty {
                interpretationRow(label: "Company", value: state.targetCompany,
                                  verified: result.catalogMatches.company != nil)
            }
            if !state.examName.isEmpty {
                interpretationRow(label: "Exam", value: state.examName,
                                  verified: result.catalogMatches.exam != nil)
            }
            if !state.targetSkill.isEmpty {
                interpretationRow(label: "Skill", value: state.targetSkill,
                                  verified: result.catalogMatches.skill != nil)
            }
            if !state.fromDomain.isEmpty || !state.toDomain.isEmpty {
                interpretationRow(label: "Switch",
                                  value: "\(state.fromDomain) → \(state.toDomain)")
            }
        }
        .padding(16)
        .v2Card(padding: 0)
        .padding(.bottom, 18)

        // Timeline + current level pickers (always needed before topics)
        Text("A couple more things")
            .font(V2Theme.h3)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.bottom, 12)

        timelinePicker
            .padding(.bottom, 12)
        levelPicker
            .padding(.bottom, 22)

        Button {
            path.append(V2OnboardingRoute.topicSelection)
        } label: {
            Text(result.isLongTail ? "Continue anyway" : "Yes, that's right")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(ColorTokens.gold)
                .foregroundStyle(ColorTokens.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)

        Button {
            showManualPicker = true
        } label: {
            Text("Let me fix it")
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Rejected: browse catalog / retry

    @ViewBuilder
    private func rejectedContent(_ result: V2ObjectiveParseResult) -> some View {
        if result.message.showCatalogBrowse == true {
            Button {
                showManualPicker = true
            } label: {
                Text("Pick from what we cover")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(ColorTokens.gold)
                    .foregroundStyle(ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }

        Button {
            path = NavigationPath()  // back to objective setup
        } label: {
            Text("Try describing it again")
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Components

    private func statusBadge(_ result: V2ObjectiveParseResult) -> some View {
        let (text, color): (String, Color) = {
            switch result.status {
            case "green":     return ("Understood", ColorTokens.success)
            case "long_tail": return ("Not in our list yet", ColorTokens.warning)
            default:          return ("Needs a clearer goal", ColorTokens.warning)
            }
        }()
        return Text(text.uppercased())
            .font(.system(size: 10, weight: .bold)).tracking(1.2)
            .foregroundStyle(color)
    }

    private func interpretationRow(label: String, value: String, verified: Bool? = nil) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            if let verified = verified {
                Image(systemName: verified ? "checkmark.seal.fill" : "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(verified ? ColorTokens.success : ColorTokens.textTertiary)
            }
        }
    }

    private var timelinePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Timeline".uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(V2Timeline.allCases, id: \.self) { t in
                        chip(t.label, selected: state.timeline == t) { state.timeline = t }
                    }
                }
            }
        }
    }

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where are you now?".uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
            HStack(spacing: 8) {
                ForEach(V2CurrentLevel.allCases, id: \.self) { lvl in
                    chip(lvl.label, selected: state.currentLevel == lvl) { state.currentLevel = lvl }
                }
            }
        }
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(selected ? ColorTokens.gold.opacity(0.15) : ColorTokens.surface)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? ColorTokens.gold : V2Theme.cardBorder, lineWidth: 1)
                )
                .foregroundStyle(selected ? ColorTokens.gold : ColorTokens.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
