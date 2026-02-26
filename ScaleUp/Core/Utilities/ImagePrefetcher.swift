import Foundation
import NukeUI
import Nuke

// MARK: - ImagePrefetcher

actor ImagePrefetcher {
    private let prefetcher = Nuke.ImagePrefetcher()

    // MARK: - Prefetch

    func prefetch(urls: [String]) {
        let imageURLs = urls.compactMap { URL(string: $0) }
        guard !imageURLs.isEmpty else { return }
        prefetcher.startPrefetching(with: imageURLs)
    }

    // MARK: - Cancel

    func cancelPrefetch(urls: [String]) {
        let imageURLs = urls.compactMap { URL(string: $0) }
        guard !imageURLs.isEmpty else { return }
        prefetcher.stopPrefetching(with: imageURLs)
    }

    func cancelAll() {
        prefetcher.stopPrefetching()
    }
}
