import SwiftUI

/// Tiny developer settings — testers flip v2 on/off here.
///
/// Hook this into the existing v1 SettingsView (e.g. a row labeled "Try v2 redesign")
/// or attach as a debug shake-to-open menu. Either way, no v1 surfaces are changed.
struct V2DevSettingsView: View {
    @State private var flag = V2FeatureFlag.shared

    var body: some View {
        Form {
            Section {
                Toggle("Try v2 redesign", isOn: Binding(
                    get: { flag.isEnabled },
                    set: { flag.isEnabled = $0 }
                ))
                Toggle("Also use v2 onboarding", isOn: Binding(
                    get: { flag.v2OnboardingEnabled },
                    set: { flag.v2OnboardingEnabled = $0 }
                ))
                .disabled(!flag.isEnabled)
            } header: {
                Text("v2 experiment")
            } footer: {
                Text("v2 replaces the tab structure (Home / Learn / Compass / You) and key screens. Toggle off any time to roll back instantly to the current app.")
            }

            Section {
                Button("Roll back to v1 now") {
                    flag.disableAndRestart()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Developer")
    }
}

#Preview {
    NavigationStack { V2DevSettingsView() }
}
