import SwiftUI

// MARK: - Playlist List View Model

@Observable
@MainActor
final class PlaylistListViewModel {

    // MARK: - State

    var playlists: [Playlist] = []
    var isLoading: Bool = false
    var error: APIError?
    var showCreateSheet: Bool = false

    // MARK: - Dependencies

    private let socialService: SocialService

    // MARK: - Init

    init(socialService: SocialService) {
        self.socialService = socialService
    }

    // MARK: - Computed Properties

    var isEmpty: Bool {
        playlists.isEmpty
    }

    // MARK: - Load Playlists

    /// Fetches all playlists for the current user.
    func loadPlaylists() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            playlists = try await socialService.playlists()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Refresh

    /// Refreshes playlists without showing the full loading state.
    func refresh() async {
        error = nil

        do {
            playlists = try await socialService.playlists()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Delete Playlist

    /// Deletes a playlist by ID and removes it from the local list.
    func deletePlaylist(id: String) async {
        do {
            try await socialService.deletePlaylist(id: id)
            playlists.removeAll { $0.id == id }
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Add Created Playlist

    /// Appends a newly created playlist to the local list.
    func addPlaylist(_ playlist: Playlist) {
        playlists.insert(playlist, at: 0)
    }
}
