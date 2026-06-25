import SwiftUI

// MARK: - Placement Onboarding Payload

/// Decoded shape from `GET /api/v2/me/placement-onboarding`.
///
/// Returned (200) only for placement students — the backend auto-enrolled them
/// at registration and seeded a locked placement objective, so the app skips the
/// generic D2C onboarding entirely and shows this short intro before the
/// diagnostic. Non-placement users get a 404 (handled by the view: it simply
/// proceeds to the diagnostic, which never happens for them anyway since
/// `resolveLaunchState` only routes placement users here).
struct PlacementOnboardingPayload: Codable {
    let name: String?
    let phone: String?
    let rollNumber: String?
    let institution: String?
    let branch: String?
    /// "final" or "pre_final".
    let year: String?
    let cohortLabel: String?
    let objectiveLabel: String?
    let competencies: [PlacementOnboardingCompetency]?

    /// Friendly label for the backend `year` enum.
    var yearLabel: String? {
        switch year {
        case "final":     return "Final year"
        case "pre_final": return "Pre-final year"
        case .some(let raw) where !raw.isEmpty: return raw
        default:          return nil
        }
    }

    /// First name only, for the greeting.
    var firstName: String? {
        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return name.split(separator: " ").first.map(String.init)
    }
}

struct PlacementOnboardingCompetency: Codable {
    let name: String
    let category: String?
}

// MARK: - Placement Onboarding Intro

/// Short welcome screen shown to a placement student on first launch, in place
/// of the generic D2C onboarding (which exists to create an objective + gather
/// prefs — both already handled server-side for placement students).
///
/// Flow: PlacementOnboardingIntroView → existing diagnostic → insights →
/// placement home. The "Start my readiness check" button hands off to the
/// diagnostic via `appState.proceedFromPlacementIntro()`.
///
/// Data is fetched from `GET /api/v2/me/placement-onboarding`. If that request
/// fails (e.g. an unexpected 404), the screen falls back to the persona context
/// already loaded into `AppState` so it never blocks the student.
struct PlacementOnboardingIntroView: View {
    @Environment(AppState.self) private var appState

    @State private var payload: PlacementOnboardingPayload?
    @State private var isLoading = true
    @State private var phoneInput: String = ""

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(ColorTokens.gold)
            } else {
                content
            }
        }
        .task { await load() }
    }

    // MARK: Resolved display values (payload first, persona context fallback)

    private var institutionName: String {
        payload?.institution
            ?? appState.userContext?.placement?.institution.name
            ?? "your placement programme"
    }

    private var greetingName: String? {
        payload?.firstName
    }

    private var branch: String? { payload?.branch }

    private var yearLabel: String? {
        payload?.yearLabel ?? appState.userContext?.placement?.cohort.yearLabel
    }

    private var rollNumber: String? { payload?.rollNumber }

    private var objectiveLabel: String? { payload?.objectiveLabel }

    /// Show the optional phone capture only when the backend has no phone on file.
    private var needsPhone: Bool {
        guard let payload else { return false }
        let phone = payload.phone?.trimmingCharacters(in: .whitespaces) ?? ""
        return phone.isEmpty
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: Spacing.xxl)

                // Brand mark
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(ColorTokens.background)
                }
                .padding(.bottom, Spacing.lg)

                // Greeting
                Text(welcomeTitle)
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your programme is set up and your objective is locked in. Let's run a quick readiness check so we can tailor your plan.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)

                // Summary card
                summaryCard
                    .padding(.top, Spacing.xl)

                if needsPhone {
                    phoneField
                        .padding(.top, Spacing.lg)
                }

                Spacer(minLength: Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                PrimaryButton(title: "Start my readiness check", icon: "checkmark.seal.fill") {
                    Haptics.success()
                    appState.proceedFromPlacementIntro()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
            .background(ColorTokens.background)
        }
    }

    private var welcomeTitle: String {
        if let greetingName {
            return "Welcome to \(institutionName)'s placement programme, \(greetingName)"
        }
        return "Welcome to \(institutionName)'s placement programme"
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let objectiveLabel, !objectiveLabel.isEmpty {
                summaryRow(icon: "target", label: "Objective", value: objectiveLabel)
                Divider().overlay(ColorTokens.divider)
            }
            if let branch, !branch.isEmpty {
                summaryRow(icon: "book.closed.fill", label: "Branch", value: branch)
                Divider().overlay(ColorTokens.divider)
            }
            if let yearLabel, !yearLabel.isEmpty {
                summaryRow(icon: "calendar", label: "Year", value: yearLabel)
                Divider().overlay(ColorTokens.divider)
            }
            if let rollNumber, !rollNumber.isEmpty {
                summaryRow(icon: "number", label: "Roll no.", value: rollNumber)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(ColorTokens.gold.opacity(0.18), lineWidth: 1)
        )
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(ColorTokens.gold.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                Text(value)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Add a phone number (optional)")
                .font(Typography.bodySmallBold)
                .foregroundStyle(ColorTokens.textSecondary)
            TextField("", text: $phoneInput, prompt: Text("Phone number").foregroundColor(ColorTokens.textTertiary))
                .keyboardType(.phonePad)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(Spacing.md)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .strokeBorder(ColorTokens.border, lineWidth: 1)
                )
        }
    }

    // MARK: Loading

    private func load() async {
        defer { isLoading = false }
        do {
            let resp: V2APIResponse<PlacementOnboardingPayload> = try await V2APIClient.shared.get("/me/placement-onboarding")
            payload = resp.data
            if let existing = resp.data.phone {
                phoneInput = existing
            }
        } catch {
            // 404 (not a placement student) or any failure: leave `payload` nil
            // and fall back to the persona context already in AppState. The
            // student is never blocked — the primary button still proceeds to
            // the diagnostic.
            payload = nil
        }
    }
}

#Preview {
    PlacementOnboardingIntroView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
