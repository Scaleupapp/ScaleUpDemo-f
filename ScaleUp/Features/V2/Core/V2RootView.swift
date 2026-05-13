import SwiftUI

/// V2 root view — chooses between v1 MainTabView and v2 MainTabView based on flag.
///
/// Drop-in replacement for MainTabView at the .home launch state in ScaleUpApp.swift.
/// If flag OFF → falls through to existing v1 MainTabView (untouched).
/// If flag ON  → renders v2 MainTabViewV2 (new 4-tab IA).
struct V2RootView: View {
    @State private var flag = V2FeatureFlag.shared

    var body: some View {
        Group {
            if flag.isEnabled {
                V2MainTabView()
            } else {
                MainTabView()
            }
        }
    }
}
