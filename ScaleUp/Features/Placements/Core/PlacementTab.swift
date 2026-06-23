import SwiftUI

/// Placement shell tabs — Home / Campus / Library / You.
///
/// Mirrors the V2 IA but swaps Learn→Library and drops the dedicated Compass
/// tab (Compass is the floating FAB only). The "You" tab reuses `V2YouView`.
enum PlacementTab: String, CaseIterable, Identifiable {
    case home
    case campus
    case library
    case you

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:    return "Home"
        case .campus:  return "Campus"
        case .library: return "Library"
        case .you:     return "You"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "house.fill"
        case .campus:  return "building.columns.fill"
        case .library: return "books.vertical.fill"
        case .you:     return "person.fill"
        }
    }
}

/// Lightweight placement-shell nav state — separate from `AppState` and
/// `V2NavState` so the existing experiences remain untouched.
@Observable
@MainActor
final class PlacementNavState {
    var selectedTab: PlacementTab = .home
    var compassSheetOpen: Bool = false
}
