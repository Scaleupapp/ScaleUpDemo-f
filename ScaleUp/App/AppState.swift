import SwiftUI

@Observable
final class AppState {
    enum AuthStatus: Equatable {
        case loading
        case unauthenticated
        case authenticated
        case onboarding
    }

    var authStatus: AuthStatus = .loading
    var currentUser: User?
    var preferredColorScheme: ColorScheme? = .dark

    var isAuthenticated: Bool {
        authStatus == .authenticated
    }

    func logout() {
        authStatus = .unauthenticated
        currentUser = nil
    }
}
