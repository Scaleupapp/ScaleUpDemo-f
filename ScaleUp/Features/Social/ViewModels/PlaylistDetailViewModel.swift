import SwiftUI

// MARK: - Playlist Detail View Model

@Observable
@MainActor
final class PlaylistDetailViewModel {

    // MARK: - State

    var playlist: Playlist?
    var isLoading: Bool = false
    var error: APIError?
    var showEditSheet: Bool = false

    // MARK: - Dependencies

    private let socialService: SocialService

    // MARK: - Init

    init(socialService: SocialService) {
        self.socialService = socialService
    }

    // MARK: - Computed Properties

    /// The number of items in the playlist.
    var itemCount: Int {
        playlist?.items.count ?? 0
    }

    /// Total duration of all content items in seconds.
    var totalDuration: Int {
        playlist?.items.compactMap { item -> Int? in
            if case .populated(let content) = item.contentId { return content.duration }
            return nil
        }.reduce(0, +) ?? 0
    }

    /// Whether the playlist has no items.
    var isEmpty: Bool {
        playlist?.items.isEmpty ?? true
    }

    // MARK: - Load Playlist

    /// Fetches a single playlist by ID.
    func loadPlaylist(id: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            playlist = try await socialService.getPlaylist(id: id)
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Refresh

    /// Refreshes the playlist without showing the full loading state.
    func refresh() async {
        guard let playlistId = playlist?.id else { return }
        error = nil

        do {
            playlist = try await socialService.getPlaylist(id: playlistId)
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Remove Item

    /// Removes a content item from the playlist.
    func removeItem(contentId: String) async {
        guard let playlistId = playlist?.id else { return }

        do {
            playlist = try await socialService.removeFromPlaylist(
                playlistId: playlistId,
                contentId: contentId
            )
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Update Playlist

    /// Updates playlist metadata (name, description, public/private).
    func updatePlaylist(name: String?, description: String?, isPublic: Bool?) async {
        guard let playlistId = playlist?.id else { return }

        do {
            playlist = try await socialService.updatePlaylist(
                id: playlistId,
                name: name,
                description: description,
                isPublic: isPublic
            )
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }
}
