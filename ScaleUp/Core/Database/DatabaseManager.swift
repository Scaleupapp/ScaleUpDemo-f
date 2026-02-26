import Foundation
import SwiftData

// MARK: - Database Manager

/// Centralised factory for creating the app's SwiftData `ModelContainer`.
/// All persistent @Model types must be registered in the schema here.
enum DatabaseManager {

    // MARK: - Container Factory

    /// Creates a `ModelContainer` with the full app schema.
    /// Call once at app launch and inject via the SwiftUI environment.
    ///
    /// - Returns: A configured `ModelContainer` backed by on-disk SQLite storage.
    /// - Throws: If SwiftData fails to initialise the store.
    static func createContainer() throws -> ModelContainer {
        let schema = Schema([
            OfflineProgressUpdate.self,
            SearchHistory.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    // MARK: - In-Memory Container (Testing)

    /// Creates an in-memory container suitable for previews and unit tests.
    ///
    /// - Returns: A `ModelContainer` that stores data only in memory.
    /// - Throws: If SwiftData fails to initialise the in-memory store.
    static func createPreviewContainer() throws -> ModelContainer {
        let schema = Schema([
            OfflineProgressUpdate.self,
            SearchHistory.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
