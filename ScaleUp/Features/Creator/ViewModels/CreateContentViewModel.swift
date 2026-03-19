import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Video File Transferable (saves to disk, never loads into memory)

struct VideoFileTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked_\(UUID().uuidString.prefix(8)).mov")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

@Observable
@MainActor
final class CreateContentViewModel {

    // MARK: - Steps

    enum Step: Int, CaseIterable {
        case media = 0      // Pick file
        case details = 1    // Title, description, type
        case categorize = 2 // Domain, topics, tags, difficulty
        case review = 3     // Review & upload
    }

    var currentStep: Step = .media

    // MARK: - Step 0: Media

    var selectedVideoItem: PhotosPickerItem?
    var selectedFileName: String?
    var selectedFileSize: Int64 = 0
    var selectedMimeType: String = "video/mp4"
    var mediaFileURL: URL?
    var mediaData: Data? // Only for small files (images, PDFs)
    var mediaThumbnail: UIImage?
    var hasSelectedMedia: Bool { mediaFileURL != nil }
    var isLoadingMedia = false

    // Size info
    var isVideo: Bool { selectedMimeType.hasPrefix("video/") }
    var willCompress: Bool { isVideo && selectedFileSize > 500 * 1024 * 1024 }
    /// Only block non-compressible files over 4GB. Videos will be compressed down.
    var fileSizeTooLarge: Bool { selectedFileSize > 4 * 1024 * 1024 * 1024 && !isVideo }

    // Video thumbnail
    var thumbnailPickerItem: PhotosPickerItem?
    var customThumbnail: UIImage?
    var hasCustomThumbnail: Bool { customThumbnail != nil }
    var videoDuration: TimeInterval?

    // MARK: - Step 1: Details

    var title = ""
    var description = ""
    var contentType = "video" // video | article | infographic

    // MARK: - Step 2: Categorize

    var domain = ""
    var topicInput = ""
    var topics: [String] = []
    var tagInput = ""
    var tags: [String] = []
    var difficulty = "intermediate"

    // MARK: - Upload State

    var uploadStarted = false
    var errorMessage: String?

    // MARK: - Computed

    var canProceed: Bool {
        switch currentStep {
        case .media: return hasSelectedMedia && !fileSizeTooLarge
        case .details: return !title.trimmingCharacters(in: .whitespaces).isEmpty
        case .categorize: return !domain.trimmingCharacters(in: .whitespaces).isEmpty && !topics.isEmpty
        case .review: return true
        }
    }

    var stepTitle: String {
        switch currentStep {
        case .media: return "Upload Media"
        case .details: return "Content Details"
        case .categorize: return "Categorize"
        case .review: return "Review & Publish"
        }
    }

    var fileSizeDisplay: String {
        ByteCountFormatter.string(fromByteCount: selectedFileSize, countStyle: .file)
    }

    // MARK: - Media Selection

    func handleVideoSelection() async {
        guard let item = selectedVideoItem else { return }

        isLoadingMedia = true
        mediaThumbnail = nil
        customThumbnail = nil
        videoDuration = nil
        mediaFileURL = nil
        mediaData = nil

        // Determine content type from UTType
        let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })
        let isImage = item.supportedContentTypes.contains(where: { $0.conforms(to: .image) })

        if isVideo {
            // Load as file (never into memory)
            if let video = try? await item.loadTransferable(type: VideoFileTransferable.self) {
                mediaFileURL = video.url
                let attrs = try? FileManager.default.attributesOfItem(atPath: video.url.path)
                selectedFileSize = (attrs?[.size] as? Int64) ?? 0

                if let utType = item.supportedContentTypes.first {
                    selectedMimeType = utType.conforms(to: .quickTimeMovie) ? "video/quicktime" : "video/mp4"
                } else {
                    selectedMimeType = "video/mp4"
                }
                contentType = "video"

                let ext = selectedMimeType.split(separator: "/").last.map(String.init) ?? "mp4"
                selectedFileName = "content_\(UUID().uuidString.prefix(8)).\(ext)"

                await extractVideoThumbnail(from: video.url)
            }
        } else {
            // Small file: load into Data
            if let data = try? await item.loadTransferable(type: Data.self) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("picked_\(UUID().uuidString.prefix(8))")
                try? data.write(to: tempURL)
                mediaFileURL = tempURL
                mediaData = data
                selectedFileSize = Int64(data.count)

                if isImage {
                    selectedMimeType = "image/jpeg"
                    contentType = "infographic"
                    mediaThumbnail = UIImage(data: data)
                } else {
                    selectedMimeType = "application/pdf"
                    contentType = "article"
                }

                let ext = selectedMimeType.split(separator: "/").last.map(String.init) ?? "dat"
                selectedFileName = "content_\(UUID().uuidString.prefix(8)).\(ext)"
            }
        }

        isLoadingMedia = false
    }

    func handleThumbnailSelection() async {
        guard let item = thumbnailPickerItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            customThumbnail = image
            Haptics.success()
        }
    }

    func removeThumbnail() {
        customThumbnail = nil
        thumbnailPickerItem = nil
    }

    var displayThumbnail: UIImage? {
        customThumbnail ?? mediaThumbnail
    }

    private func extractVideoThumbnail(from url: URL) async {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        let time = CMTime(seconds: 1, preferredTimescale: 600)
        if let cgImage = try? await generator.image(at: time).image {
            mediaThumbnail = UIImage(cgImage: cgImage)
        } else if let cgImage = try? await generator.image(at: .zero).image {
            mediaThumbnail = UIImage(cgImage: cgImage)
        }

        if let duration = try? await asset.load(.duration) {
            videoDuration = duration.seconds
        }
    }

    var durationDisplay: String? {
        guard let dur = videoDuration, dur > 0 else { return nil }
        let mins = Int(dur) / 60
        let secs = Int(dur) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Topic / Tag Management

    func addTopic() {
        let trimmed = topicInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !topics.contains(trimmed) else { return }
        topics.append(trimmed)
        topicInput = ""
        Haptics.light()
    }

    func removeTopic(_ topic: String) {
        topics.removeAll { $0 == topic }
    }

    func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
        Haptics.light()
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    // MARK: - Navigation

    func goNext() {
        guard canProceed else { return }
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            Haptics.medium()
            currentStep = next
        }
    }

    func goBack() {
        if let prev = Step(rawValue: currentStep.rawValue - 1) {
            Haptics.selection()
            currentStep = prev
        }
    }

    // MARK: - Start Upload via UploadManager

    func startUpload(uploadManager: UploadManager) {
        guard let fileURL = mediaFileURL, let fileName = selectedFileName else { return }

        let job = UploadJob(
            fileURL: fileURL,
            fileName: fileName,
            mimeType: selectedMimeType,
            fileSize: selectedFileSize,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
            contentType: contentType,
            domain: domain.trimmingCharacters(in: .whitespaces).lowercased(),
            topics: topics,
            tags: tags,
            difficulty: difficulty
        )

        uploadManager.startUpload(job: job)
        uploadStarted = true
        Haptics.medium()
    }
}
