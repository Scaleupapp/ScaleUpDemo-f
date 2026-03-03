import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
    var selectedFileSize: Int = 0
    var selectedMimeType: String = "video/mp4"
    var mediaData: Data?
    var mediaThumbnail: UIImage?
    var hasSelectedMedia: Bool { mediaData != nil }

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

    var isUploading = false
    var uploadProgress: Double = 0
    var uploadPhase: UploadPhase = .idle
    var errorMessage: String?
    var createdContent: Content?

    enum UploadPhase: Equatable {
        case idle
        case requestingURL
        case uploadingToStorage
        case registeringContent
        case processing
        case complete
    }

    // MARK: - Services

    private let service = ContentCreationService()

    // MARK: - Computed

    var canProceed: Bool {
        switch currentStep {
        case .media: return hasSelectedMedia
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
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(selectedFileSize))
    }

    // MARK: - Media Selection

    func handleVideoSelection() async {
        guard let item = selectedVideoItem else { return }

        // Try to load video data
        if let data = try? await item.loadTransferable(type: Data.self) {
            mediaData = data
            selectedFileSize = data.count
            mediaThumbnail = nil
            customThumbnail = nil
            videoDuration = nil

            // Determine MIME type from UTType
            if let contentType = item.supportedContentTypes.first {
                if contentType.conforms(to: .mpeg4Movie) || contentType.conforms(to: .movie) {
                    selectedMimeType = "video/mp4"
                    self.contentType = "video"
                } else if contentType.conforms(to: .quickTimeMovie) {
                    selectedMimeType = "video/quicktime"
                    self.contentType = "video"
                } else if contentType.conforms(to: .pdf) {
                    selectedMimeType = "application/pdf"
                    self.contentType = "article"
                } else if contentType.conforms(to: .image) {
                    selectedMimeType = "image/jpeg"
                    self.contentType = "infographic"
                }
            }

            // Generate filename
            let ext = selectedMimeType.split(separator: "/").last.map(String.init) ?? "mp4"
            selectedFileName = "content_\(UUID().uuidString.prefix(8)).\(ext)"

            // Generate thumbnail based on content type
            if self.contentType == "video" {
                await extractVideoThumbnail(from: data)
            } else if self.contentType == "infographic" {
                // For images, create thumbnail directly from data
                if let image = UIImage(data: data) {
                    mediaThumbnail = image
                }
            }
        }
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

    /// The thumbnail to display — custom overrides auto-generated
    var displayThumbnail: UIImage? {
        customThumbnail ?? mediaThumbnail
    }

    private func extractVideoThumbnail(from data: Data) async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video_\(UUID().uuidString.prefix(6)).mp4")
        try? data.write(to: tempURL)

        let asset = AVAsset(url: tempURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        // Extract thumbnail at 1 second in (more representative than frame 0)
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        if let cgImage = try? await generator.image(at: time).image {
            mediaThumbnail = UIImage(cgImage: cgImage)
        } else if let cgImage = try? await generator.image(at: .zero).image {
            mediaThumbnail = UIImage(cgImage: cgImage)
        }

        // Get duration
        if let duration = try? await asset.load(.duration) {
            videoDuration = duration.seconds
        }

        try? FileManager.default.removeItem(at: tempURL)
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

    // MARK: - Upload & Create

    func startUpload() async {
        guard let data = mediaData, let fileName = selectedFileName else { return }

        isUploading = true
        errorMessage = nil
        uploadProgress = 0

        do {
            // Phase 1: Get pre-signed URL
            uploadPhase = .requestingURL
            uploadProgress = 0.1
            let uploadInfo = try await service.requestUploadURL(
                fileName: fileName,
                fileType: selectedMimeType,
                fileSize: data.count
            )

            // Phase 2: Upload to S3
            uploadPhase = .uploadingToStorage
            uploadProgress = 0.3
            try await service.uploadToS3(url: uploadInfo.uploadURL, data: data, contentType: selectedMimeType)
            uploadProgress = 0.7

            // Phase 3: Register content
            uploadPhase = .registeringContent
            uploadProgress = 0.85

            let body = CompleteUploadRequest(
                key: uploadInfo.key,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                contentType: contentType,
                domain: domain.trimmingCharacters(in: .whitespaces).lowercased(),
                topics: topics,
                tags: tags,
                difficulty: difficulty
            )

            let content = try await service.completeUpload(body: body)
            createdContent = content

            // Phase 4: Processing (AI analysis happens server-side)
            uploadPhase = .processing
            uploadProgress = 0.95

            // Brief pause for dramatic effect, then complete
            try? await Task.sleep(for: .milliseconds(800))

            uploadPhase = .complete
            uploadProgress = 1.0
            Haptics.success()

        } catch let error as APIError {
            errorMessage = error.errorDescription
            uploadPhase = .idle
            Haptics.error()
        } catch {
            errorMessage = "Upload failed. Please try again."
            uploadPhase = .idle
            Haptics.error()
        }

        isUploading = false
    }
}

import AVFoundation
