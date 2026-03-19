import SwiftUI
import PhotosUI

struct CreateContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UploadManager.self) private var uploadManager
    @State private var viewModel = CreateContentViewModel()
    @State private var showCompressionConfirm = false
    var onCreated: ((Content) -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Step indicator
                    stepProgressBar

                    // Content
                    ScrollView {
                        VStack(spacing: Spacing.lg) {
                            stepContent
                        }
                        .padding(Spacing.md)
                        .padding(.bottom, 100)
                    }

                    actionBar
                }
            }
            .navigationTitle(viewModel.stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .onChange(of: viewModel.uploadStarted) { _, started in
                if started { dismiss() }
            }
            .sheet(isPresented: $showCompressionConfirm) {
                compressionConfirmSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Compression Confirmation Sheet

    private var compressionConfirmSheet: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.top, Spacing.lg)

            // Title & explanation
            VStack(spacing: Spacing.sm) {
                Text("File Size Optimization")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Your video is \(viewModel.fileSizeDisplay), which exceeds the recommended size. The system will compress it to optimize the upload.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // What this means
            VStack(alignment: .leading, spacing: Spacing.sm) {
                compressionInfoRow(icon: "arrow.down.right.circle", color: ColorTokens.success,
                                   text: "Resolution may be reduced to 1080p")
                compressionInfoRow(icon: "eye", color: ColorTokens.info,
                                   text: "Quality difference is minimal for most viewers")
                compressionInfoRow(icon: "clock", color: ColorTokens.warning,
                                   text: "Compression runs in the background — you can keep using the app")
                compressionInfoRow(icon: "bell", color: ColorTokens.gold,
                                   text: "You'll be notified when it's ready to upload")
            }
            .padding(Spacing.md)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            // Action buttons
            VStack(spacing: Spacing.sm) {
                Button {
                    showCompressionConfirm = false
                    viewModel.startUpload(uploadManager: uploadManager)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Compress & Upload")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                .buttonStyle(.plain)

                Button {
                    showCompressionConfirm = false
                } label: {
                    Text("Cancel — I'll reduce the size manually")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, Spacing.md)
        }
        .padding(.horizontal, Spacing.lg)
        .background(ColorTokens.background.ignoresSafeArea())
    }

    private func compressionInfoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    // MARK: - Step Progress Bar

    private var stepProgressBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: 4) {
                ForEach(CreateContentViewModel.Step.allCases, id: \.rawValue) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step.rawValue <= viewModel.currentStep.rawValue ? ColorTokens.gold : ColorTokens.surfaceElevated)
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
                }
            }

            HStack {
                ForEach(CreateContentViewModel.Step.allCases, id: \.rawValue) { step in
                    Text(stepLabel(step))
                        .font(.system(size: 9, weight: step == viewModel.currentStep ? .semibold : .regular))
                        .foregroundStyle(step.rawValue <= viewModel.currentStep.rawValue ? ColorTokens.gold : ColorTokens.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private func stepLabel(_ step: CreateContentViewModel.Step) -> String {
        switch step {
        case .media: return "Media"
        case .details: return "Details"
        case .categorize: return "Categorize"
        case .review: return "Review"
        }
    }

    // MARK: - Step Content Router

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .media: mediaStep
        case .details: detailsStep
        case .categorize: categorizeStep
        case .review: reviewStep
        }
    }

    // MARK: - Step 0: Media Selection

    private var mediaStep: some View {
        VStack(spacing: Spacing.lg) {
            // Hero prompt (only when nothing selected)
            if !viewModel.hasSelectedMedia {
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.gold.opacity(0.08))
                            .frame(width: 88, height: 88)
                        Circle()
                            .fill(ColorTokens.gold.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(ColorTokens.gold)
                    }

                    Text("Upload Your Content")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Share your expertise with the world.\nUpload a video, article, or infographic.")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xl)
            }

            // File picker / preview
            if viewModel.hasSelectedMedia {
                selectedMediaPreview
            } else {
                mediaPicker
            }

            // Loading indicator
            if viewModel.isLoadingMedia {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .tint(ColorTokens.gold)
                    Text("Loading media...")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            }

            // Compression info banner
            if viewModel.hasSelectedMedia && viewModel.willCompress {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Video will be optimized")
                            .font(Typography.captionBold)
                            .foregroundStyle(ColorTokens.gold)
                        Text("Resolution may be reduced to 1080p for faster upload. This happens automatically in the background.")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.gold.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // File too large error (only for non-video files — videos get compressed)
            if viewModel.fileSizeTooLarge {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.error)
                    Text("File too large. Maximum 4 GB for non-video files.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.error)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Supported formats (only when nothing selected)
            if !viewModel.hasSelectedMedia && !viewModel.isLoadingMedia {
                VStack(spacing: Spacing.xs) {
                    Text("Supported formats")
                        .font(Typography.captionBold)
                        .foregroundStyle(ColorTokens.textTertiary)

                    HStack(spacing: Spacing.md) {
                        formatChip("MP4", icon: "film")
                        formatChip("MOV", icon: "video")
                        formatChip("PDF", icon: "doc.text")
                        formatChip("JPG/PNG", icon: "photo")
                    }
                }
                .padding(.top, Spacing.md)

                Text("Maximum file size: 4 GB")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)

                Text("Videos over 500 MB are optimized automatically")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .onChange(of: viewModel.selectedVideoItem) {
            Task { await viewModel.handleVideoSelection() }
        }
    }

    private var mediaPicker: some View {
        PhotosPicker(
            selection: $viewModel.selectedVideoItem,
            matching: .any(of: [.videos, .images])
        ) {
            VStack(spacing: Spacing.md) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(ColorTokens.gold)

                VStack(spacing: 4) {
                    Text("Tap to select a file")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("from your photo library")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .strokeBorder(
                                ColorTokens.gold.opacity(0.3),
                                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedMediaPreview: some View {
        VStack(spacing: Spacing.md) {
            // Main preview card
            ZStack(alignment: .topLeading) {
                // Thumbnail / Image preview
                if let thumb = viewModel.displayThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            // Gradient scrim at bottom
                            LinearGradient(
                                colors: [.clear, .clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        )
                        .overlay(alignment: .center) {
                            // Play icon for videos
                            if viewModel.contentType == "video" {
                                ZStack {
                                    Circle()
                                        .fill(.black.opacity(0.5))
                                        .frame(width: 52, height: 52)
                                    Circle()
                                        .fill(.white.opacity(0.15))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                        .offset(x: 2) // optical centering
                                }
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            // Bottom info bar
                            HStack(spacing: 8) {
                                // Duration badge (video only)
                                if let duration = viewModel.durationDisplay {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 8))
                                        Text(duration)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.6))
                                    .clipShape(Capsule())
                                }

                                Spacer()

                                // File size
                                Text(viewModel.fileSizeDisplay)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                            .padding(10)
                        }
                } else {
                    // No thumbnail available
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.surfaceElevated, ColorTokens.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 220)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: contentTypeIcon)
                                    .font(.system(size: 40))
                                    .foregroundStyle(ColorTokens.gold.opacity(0.4))
                                Text("Preview unavailable")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                }

                // Type badge - top left
                Text(viewModel.contentType.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ColorTokens.gold)
                    .clipShape(Capsule())
                    .padding(10)
            }

            // File info + Change button
            HStack(spacing: Spacing.sm) {
                // File icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTokens.gold.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: contentTypeIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.gold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedFileName ?? "Selected file")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text(viewModel.fileSizeDisplay)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                PhotosPicker(
                    selection: $viewModel.selectedVideoItem,
                    matching: .any(of: [.videos, .images])
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Change")
                            .font(Typography.captionBold)
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTokens.gold.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.sm)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Video thumbnail picker
            if viewModel.contentType == "video" {
                videoThumbnailSection
            }
        }
    }

    // MARK: - Video Thumbnail Section

    private var videoThumbnailSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Thumbnail")
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if viewModel.hasCustomThumbnail {
                    Button {
                        viewModel.removeThumbnail()
                    } label: {
                        Text("Use Auto")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.hasCustomThumbnail, let custom = viewModel.customThumbnail {
                // Show custom thumbnail
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: custom)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Replace button
                    PhotosPicker(
                        selection: $viewModel.thumbnailPickerItem,
                        matching: .images
                    ) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.gold)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .onChange(of: viewModel.thumbnailPickerItem) {
                        Task { await viewModel.handleThumbnailSelection() }
                    }
                }
            } else {
                // Thumbnail picker
                HStack(spacing: Spacing.md) {
                    // Auto-generated preview
                    if let autoThumb = viewModel.mediaThumbnail {
                        VStack(spacing: 4) {
                            Image(uiImage: autoThumb)
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(width: 100, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(ColorTokens.gold.opacity(0.5), lineWidth: 1.5)
                                )
                            Text("Auto")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }

                    // Upload custom thumbnail
                    PhotosPicker(
                        selection: $viewModel.thumbnailPickerItem,
                        matching: .images
                    ) {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ColorTokens.surfaceElevated)
                                .frame(width: 100, height: 56)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            ColorTokens.border,
                                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                        )
                                )
                                .overlay {
                                    VStack(spacing: 2) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 16, weight: .light))
                                        Text("Upload")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundStyle(ColorTokens.textTertiary)
                                }
                            Text("Custom")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: viewModel.thumbnailPickerItem) {
                        Task { await viewModel.handleThumbnailSelection() }
                    }

                    Spacer()
                }
            }
        }
        .padding(Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var contentTypeIcon: String {
        switch viewModel.contentType {
        case "video": return "film.fill"
        case "article": return "doc.text.fill"
        case "infographic": return "photo.fill"
        default: return "doc.fill"
        }
    }

    private func formatChip(_ label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(ColorTokens.textTertiary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ColorTokens.surfaceElevated)
        .clipShape(Capsule())
    }

    // MARK: - Step 1: Details

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Title
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Title")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("*")
                        .foregroundStyle(ColorTokens.error)
                }

                TextField("Give your content a compelling title", text: $viewModel.title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(Spacing.md)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )

                Text("\(viewModel.title.count)/200")
                    .font(Typography.caption)
                    .foregroundStyle(viewModel.title.count > 200 ? ColorTokens.error : ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Description
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Description")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                TextEditor(text: $viewModel.description)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(Spacing.sm)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )

                Text("Describe what learners will gain from this content")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Content type selector
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Content Type")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.sm) {
                    contentTypeButton("Video", type: "video", icon: "film.fill")
                    contentTypeButton("Article", type: "article", icon: "doc.text.fill")
                    contentTypeButton("Infographic", type: "infographic", icon: "photo.fill")
                }
            }
        }
    }

    private func contentTypeButton(_ label: String, type: String, icon: String) -> some View {
        Button {
            Haptics.selection()
            viewModel.contentType = type
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(Typography.caption)
            }
            .foregroundStyle(viewModel.contentType == type ? .black : ColorTokens.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(viewModel.contentType == type ? ColorTokens.gold : ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(viewModel.contentType == type ? Color.clear : ColorTokens.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Categorize

    private var categorizeStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Domain
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Domain")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("*")
                        .foregroundStyle(ColorTokens.error)
                }

                TextField("e.g. software-engineering, product-management", text: $viewModel.domain)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .textInputAutocapitalization(.never)
                    .padding(Spacing.md)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
            }

            // Topics
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Topics")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("*")
                        .foregroundStyle(ColorTokens.error)
                }

                HStack(spacing: Spacing.sm) {
                    TextField("Add a topic", text: $viewModel.topicInput)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .textInputAutocapitalization(.never)
                        .padding(Spacing.sm)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        .overlay(RoundedRectangle(cornerRadius: CornerRadius.small).stroke(ColorTokens.border, lineWidth: 1))
                        .onSubmit { viewModel.addTopic() }

                    Button { viewModel.addTopic() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .disabled(viewModel.topicInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !viewModel.topics.isEmpty {
                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(viewModel.topics, id: \.self) { topic in
                            chipWithRemove(topic) { viewModel.removeTopic(topic) }
                        }
                    }
                }
            }

            // Tags
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Tags")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.sm) {
                    TextField("Add a tag", text: $viewModel.tagInput)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .textInputAutocapitalization(.never)
                        .padding(Spacing.sm)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        .overlay(RoundedRectangle(cornerRadius: CornerRadius.small).stroke(ColorTokens.border, lineWidth: 1))
                        .onSubmit { viewModel.addTag() }

                    Button { viewModel.addTag() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .disabled(viewModel.tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !viewModel.tags.isEmpty {
                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            chipWithRemove(tag) { viewModel.removeTag(tag) }
                        }
                    }
                }
            }

            // Difficulty
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Difficulty Level")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.sm) {
                    difficultyButton("Beginner", level: "beginner", color: ColorTokens.success)
                    difficultyButton("Intermediate", level: "intermediate", color: ColorTokens.warning)
                    difficultyButton("Advanced", level: "advanced", color: ColorTokens.error)
                }
            }
        }
    }

    private func difficultyButton(_ label: String, level: String, color: Color) -> some View {
        Button {
            Haptics.selection()
            viewModel.difficulty = level
        } label: {
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(viewModel.difficulty == level ? .white : ColorTokens.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(viewModel.difficulty == level ? color : ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(viewModel.difficulty == level ? Color.clear : ColorTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func chipWithRemove(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.gold)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(ColorTokens.gold.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Step 3: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Preview card
            VStack(spacing: 0) {
                // Thumbnail
                ZStack {
                    if let thumb = viewModel.displayThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(ColorTokens.surfaceElevated)
                            .frame(height: 180)
                            .overlay {
                                Image(systemName: contentTypeIcon)
                                    .font(.system(size: 48))
                                    .foregroundStyle(ColorTokens.gold.opacity(0.3))
                            }
                    }

                    // Overlay badges
                    VStack {
                        HStack {
                            Text(viewModel.contentType.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ColorTokens.gold)
                                .clipShape(Capsule())

                            Spacer()

                            Text(viewModel.difficulty.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(difficultyColor.opacity(0.9))
                                .clipShape(Capsule())
                        }
                        .padding(Spacing.sm)
                        Spacer()
                    }
                }

                // Details
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(viewModel.title)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if !viewModel.description.isEmpty {
                        Text(viewModel.description)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineLimit(3)
                    }

                    Divider().overlay(ColorTokens.divider)

                    HStack(spacing: Spacing.md) {
                        reviewInfoItem(icon: "folder.fill", text: viewModel.domain)
                        reviewInfoItem(icon: "number", text: "\(viewModel.topics.count) topics")
                        reviewInfoItem(icon: "tag.fill", text: "\(viewModel.tags.count) tags")
                    }

                    if !viewModel.topics.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(viewModel.topics, id: \.self) { topic in
                                Text(topic)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(ColorTokens.gold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ColorTokens.gold.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
            )

            // What happens next
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("What happens next")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                if viewModel.willCompress {
                    timelineItem(step: 1, icon: "wand.and.stars", color: ColorTokens.warning,
                                 title: "Auto-Optimize", desc: "Video is compressed for faster upload")
                }
                timelineItem(step: viewModel.willCompress ? 2 : 1, icon: "arrow.up.circle.fill", color: ColorTokens.info,
                             title: "Upload to Cloud", desc: "Uploaded in chunks with progress tracking")
                timelineItem(step: viewModel.willCompress ? 3 : 2, icon: "cpu.fill", color: ColorTokens.gold,
                             title: "AI Analysis", desc: "GPT-4o analyzes content quality & key concepts")
                timelineItem(step: viewModel.willCompress ? 4 : 3, icon: "checkmark.seal.fill", color: ColorTokens.success,
                             title: "Ready to Publish", desc: "Review AI insights, then publish when ready")

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 10))
                    Text("You can browse the app while uploading")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.top, 4)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.error)
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
        }
    }

    private var difficultyColor: Color {
        switch viewModel.difficulty {
        case "beginner": return ColorTokens.success
        case "intermediate": return ColorTokens.warning
        case "advanced": return ColorTokens.error
        default: return ColorTokens.warning
        }
    }

    private func reviewInfoItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    private func timelineItem(step: Int, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(desc)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: Spacing.md) {
            if viewModel.currentStep != .media {
                Button {
                    viewModel.goBack()
                } label: {
                    Text("Back")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(ColorTokens.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                if viewModel.currentStep == .review {
                    if viewModel.willCompress {
                        showCompressionConfirm = true
                    } else {
                        viewModel.startUpload(uploadManager: uploadManager)
                    }
                } else {
                    viewModel.goNext()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(viewModel.currentStep == .review ? "Upload & Create" : "Continue")
                        .font(Typography.bodyBold)
                    if viewModel.currentStep != .review {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.canProceed ? ColorTokens.gold : ColorTokens.gold.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .shadow(color: viewModel.canProceed ? ColorTokens.gold.opacity(0.25) : .clear, radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canProceed)
        }
        .padding(Spacing.md)
        .background(
            ColorTokens.surface
                .shadow(.drop(color: .black.opacity(0.3), radius: 8, y: -4))
        )
    }

    // MARK: - Upload Progress (handled by UploadProgressOverlay)
}
