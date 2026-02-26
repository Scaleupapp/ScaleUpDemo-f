import Foundation
import SwiftData

// MARK: - Search History

/// SwiftData model for persisting recent search queries locally.
/// Enables offline access to search history and quick re-searching
/// of previously entered terms.
@Model
final class SearchHistory {

    // MARK: - Properties

    /// The search query string entered by the user.
    var query: String

    /// Timestamp when the search was performed.
    var searchedAt: Date

    // MARK: - Init

    init(query: String) {
        self.query = query
        self.searchedAt = Date()
    }
}
