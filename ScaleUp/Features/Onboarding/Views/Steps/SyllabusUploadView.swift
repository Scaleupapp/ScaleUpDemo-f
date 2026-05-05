import SwiftUI
import UniformTypeIdentifiers

struct SyllabusUploadView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var pickerSource: PickerSource?
    @State private var uploadProgress: Double = 0
    @State private var phase: Phase = .idle
    @State private var statusMessage: String = ""
    private let service = SyllabusUploadService()

    enum PickerSource: Identifiable {
        case file, image
        var id: String { String(describing: self) }
    }

    enum Phase {
        case idle, uploading, extracting, ready, failed
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                heroCard
                ctas
                if phase == .uploading || phase == .extracting {
                    progressBlock
                }
                if phase == .ready {
                    extractedList
                }
                if phase == .failed && !statusMessage.isEmpty {
                    failureBlock
                }
                skipRow
                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .fileImporter(
            isPresented: Binding(
                get: { pickerSource == .file },
                set: { if !$0 { pickerSource = nil } }
            ),
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileResult(result)
        }
        // Image picker placeholder — full PhotosPicker / UIImagePickerController
        // wiring deferred. Tapping "Photo" simply dismisses the source state for now.
        .onChange(of: pickerSource) { _, newValue in
            if newValue == .image {
                pickerSource = nil
            }
        }
    }

    private var allowedFileTypes: [UTType] {
        var types: [UTType] = [.pdf, .image]
        if let pptx = UTType(filenameExtension: "pptx") { types.append(pptx) }
        if let ppt = UTType(filenameExtension: "ppt") { types.append(ppt) }
        return types
    }

    // MARK: - Subviews

    private var heroCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.gold)
            Text("Upload your chapter or syllabus")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text("We'll generate questions from your actual content for the most accurate diagnostic.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.top, Spacing.lg)
    }

    private var ctas: some View {
        HStack(spacing: Spacing.md) {
            Button { pickerSource = .file } label: {
                Label("Upload PDF / PPT", systemImage: "doc.fill")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            Button { pickerSource = .image } label: {
                Label("Photo", systemImage: "camera.fill")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.gold, lineWidth: 1)
                    )
            }
        }
    }

    private var progressBlock: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView(value: phase == .uploading ? uploadProgress : nil)
                .progressViewStyle(.linear)
                .tint(ColorTokens.gold)
            Text(statusMessage)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var failureBlock: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.error)
            Text(statusMessage)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    private var extractedList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Extracted topics")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
            ForEach(viewModel.syllabusExtractedTopics) { topic in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.success)
                    Text(topic.name)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                }
            }
            Button {
                AnalyticsService.shared.track(.onboardingSyllabusUploaded(
                    topicCount: viewModel.syllabusExtractedTopics.count,
                    fileType: viewModel.syllabusFileTypeForAnalytics ?? "unknown"
                ))
                viewModel.suggestedTopics = viewModel.syllabusExtractedTopics
                viewModel.selectedCanonicals = Set(viewModel.syllabusExtractedTopics.map(\.canonicalName))
                viewModel.showSyllabusUpload = false
            } label: {
                Text("Use these topics")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private var skipRow: some View {
        Button {
            AnalyticsService.shared.track(.onboardingSyllabusSkipped)
            viewModel.showSyllabusUpload = false
        } label: {
            Text("Skip — use standard topics")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .underline()
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Upload pipeline

    private func handleFileResult(_ result: Result<[URL], Error>) {
        Task {
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }

                // Security-scoped resource (file picker URLs need access on iOS).
                let needsScopedAccess = url.startAccessingSecurityScopedResource()
                defer { if needsScopedAccess { url.stopAccessingSecurityScopedResource() } }

                let data = try Data(contentsOf: url)
                viewModel.syllabusFileTypeForAnalytics = url.pathExtension.lowercased()

                phase = .uploading
                statusMessage = "Uploading..."

                let initResp = try await service.initUpload(
                    filename: url.lastPathComponent,
                    mimeType: mimeType(for: url),
                    byteCount: data.count
                )
                viewModel.syllabusId = initResp.syllabusId

                guard let uploadURL = URL(string: initResp.uploadUrl) else {
                    throw SyllabusUploadError.extractionFailed("Invalid upload URL.")
                }
                try await service.uploadFile(
                    to: uploadURL,
                    data: data,
                    mimeType: mimeType(for: url)
                ) { p in
                    uploadProgress = p
                }
                try await service.completeUpload(syllabusId: initResp.syllabusId)

                phase = .extracting
                statusMessage = "Reading your content..."
                try await poll(syllabusId: initResp.syllabusId)
            } catch {
                phase = .failed
                statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                viewModel.errorMessage = statusMessage
            }
        }
    }

    private func poll(syllabusId: String) async throws {
        var attempts = 0
        while attempts < 60 {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            let s = try await service.pollStatus(syllabusId: syllabusId)
            switch s.status {
            case "ready":
                viewModel.syllabusExtractedTopics = s.extractedTopics ?? []
                phase = .ready
                statusMessage = ""
                return
            case "failed":
                throw SyllabusUploadError.extractionFailed(s.errorReason ?? "Could not read your file.")
            default:
                break
            }
            attempts += 1
        }
        throw SyllabusUploadError.extractionFailed("Timed out — please try again.")
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":          return "application/pdf"
        case "ppt":          return "application/vnd.ms-powerpoint"
        case "pptx":         return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "jpg", "jpeg":  return "image/jpeg"
        case "png":          return "image/png"
        case "heic":         return "image/heic"
        default:             return "application/octet-stream"
        }
    }
}
