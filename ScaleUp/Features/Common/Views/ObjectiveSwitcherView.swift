import SwiftUI

struct ObjectiveSwitcherView: View {
    @Environment(ObjectiveContext.self) private var objectiveContext

    var body: some View {
        if objectiveContext.canSwitch {
            Menu {
                ForEach(objectiveContext.allObjectives) { objective in
                    Button {
                        Task {
                            await objectiveContext.switchObjective(to: objective)
                        }
                    } label: {
                        HStack {
                            Text(objectiveLabel(objective))
                            if objective.id == objectiveContext.activeObjective?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if objectiveContext.isSwitching {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Text(objectiveLabel(objectiveContext.activeObjective))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ColorTokens.card)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(objectiveContext.isSwitching)
        }
    }

    private func objectiveLabel(_ objective: Objective?) -> String {
        guard let obj = objective else { return "No Objective" }
        if let role = obj.targetRole { return role }
        if let skill = obj.targetSkill { return skill }
        return obj.objectiveType?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? "Objective"
    }
}
