import SwiftUI

/// V2 tab structure — 4 tabs replacing v1's 5 tabs.
/// Home / Learn / Compass / You
enum V2Tab: String, CaseIterable, Identifiable {
    case home
    case learn
    case compass
    case you

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:    return "Home"
        case .learn:   return "Learn"
        case .compass: return "Compass"
        case .you:     return "You"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "house.fill"
        case .learn:   return "books.vertical.fill"
        case .compass: return "location.north.circle.fill"
        case .you:     return "person.fill"
        }
    }
}

/// Lightweight v2 state — separate from AppState so v1 remains untouched.
@Observable
@MainActor
final class V2NavState {
    var selectedTab: V2Tab = .home
    var compassSheetOpen: Bool = false
}
