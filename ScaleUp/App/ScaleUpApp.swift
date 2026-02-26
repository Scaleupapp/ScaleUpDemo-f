import SwiftUI
import SwiftData

@main
struct ScaleUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var dependencies = DependencyContainer()

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try DatabaseManager.createContainer()
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .environment(appState)
                .environment(dependencies)
                .preferredColorScheme(appState.preferredColorScheme)
                .modelContainer(modelContainer)
        }
    }
}
