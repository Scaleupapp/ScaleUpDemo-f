import SwiftUI

/// "How did it go?" — Phase 4A outcome capture. Server-provided objective-aware
/// options; SUCCESS triggers a celebration + (server-side) stamps the proof.
struct V2OutcomeSheet: View {
    let prompt: V2HomeData.OutcomePrompt
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var submitting = false
    @State private var celebrate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if celebrate {
                    VStack(spacing: 12) {
                        Text("🎉").font(.system(size: 48))
                        Text("You did it!")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Your proof now shows ✓ ACHIEVED.")
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Button("Done") { onDone(); dismiss() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ColorTokens.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(ColorTokens.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)
                    }.padding(24)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text((prompt.objectiveLabel ?? "Your goal").uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.gold)
                        Text("How did it go?")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                            .padding(.bottom, 6)
                        ForEach(prompt.options) { opt in
                            Button { submit(opt.key) } label: {
                                Text(opt.label)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorTokens.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTokens.surfaceElevated.opacity(0.7), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(submitting)
                        }
                    }.padding(20)
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Your outcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") {
                        Task { let _: V2APIResponse<OutcomeSnoozeEmpty>? = try? await V2APIClient.shared.post("/you/outcome/snooze", body: OutcomeSnoozeEmpty()) }
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
    }

    // MARK: - Private helpers

    private struct OutcomeSnoozeEmpty: Codable {}
    private struct OutcomeBody: Codable {
        let objectiveId: String
        let rawChoice: String
        let source: String
    }
    private struct OutcomeResp: Codable {
        let label: String
        let celebrate: Bool
    }

    private func submit(_ rawChoice: String) {
        submitting = true
        Task {
            do {
                let r: V2APIResponse<OutcomeResp> = try await V2APIClient.shared.post(
                    "/you/outcome",
                    body: OutcomeBody(objectiveId: prompt.objectiveId, rawChoice: rawChoice, source: "target_date_prompt")
                )
                if r.data.celebrate { celebrate = true } else { onDone(); dismiss() }
            } catch {
                dismiss()
            }
            submitting = false
        }
    }
}
