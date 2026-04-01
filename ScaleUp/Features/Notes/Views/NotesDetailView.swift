import SwiftUI
import PDFKit

struct NotesDetailView: View {
    let contentId: String

    @State private var content: Content?
    @State private var isLoading = true
    @State private var pdfDocument: PDFDocument?
    @State private var pdfLoadError = false
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var likeCount = 0
    @State private var saveCount = 0
    @State private var flashcardStatus: String?
    @State private var showShareSheet = false
    @State private var readStartTime = Date()
    @Environment(AppState.self) private var appState

    private let contentService = ContentService()
    private let playerService = PlayerService()
    private let notesService = NotesService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                VStack(spacing: Spacing.md) {
                    ProgressView().tint(ColorTokens.gold)
                    Text("Loading notes...")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            } else if let content {
                VStack(spacing: 0) {
                    // Content area
                    if let pdfDocument {
                        PDFKitView(document: pdfDocument)
                    } else if pdfLoadError {
                        // Show AI summary as fallback
                        ScrollView {
                            notesSummaryView(content)
                        }
                    } else {
                        VStack(spacing: Spacing.md) {
                            ProgressView().tint(ColorTokens.gold)
                            Text("Loading document...")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Action bar
                    notesActionBar
                }
            }
        }
        .navigationTitle(content?.title ?? "Notes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let content {
                NotesShareView(items: [
                    "Check out \"\(content.title)\" on ScaleUp!\n\nhttps://scaleupapp.club/content/\(content.id)"
                ])
                .presentationDetents([.medium])
            }
        }
        .task { await loadContent() }
        .onAppear { readStartTime = Date() }
        .onDisappear { trackReadingProgress() }
    }

    // MARK: - Summary Fallback View

    private func notesSummaryView(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Title card
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(content.title)
                    .font(Typography.titleLarge)
                    .foregroundStyle(.white)

                if let desc = content.description, !desc.isEmpty {
                    Text(desc)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                HStack(spacing: Spacing.sm) {
                    if let domain = content.domain {
                        Text(domain.capitalized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTokens.surfaceElevated)
                            .clipShape(Capsule())
                    }
                    if let pages = content.pageCount {
                        Text("\(pages) pages")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    if let college = content.collegeName, !college.isEmpty {
                        Text(college)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // AI Summary
            if let aiData = content.aiData {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(ColorTokens.gold)
                        Text("AI Summary")
                            .font(Typography.bodyBold)
                            .foregroundStyle(.white)
                    }

                    if let summary = aiData.summary, !summary.isEmpty {
                        Text(summary)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }

                    if let concepts = aiData.keyConcepts, !concepts.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Key Concepts")
                                .font(Typography.captionBold)
                                .foregroundStyle(ColorTokens.textTertiary)

                            ForEach(concepts, id: \.concept) { kc in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle().fill(ColorTokens.gold).frame(width: 6, height: 6).padding(.top, 6)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(kc.concept)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                        if let desc = kc.description, !desc.isEmpty {
                                            Text(desc)
                                                .font(Typography.caption)
                                                .foregroundStyle(ColorTokens.textTertiary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - Action Bar

    private var notesActionBar: some View {
        HStack(spacing: 0) {
            actionButton(icon: isLiked ? "heart.fill" : "heart", label: "\(likeCount)", isActive: isLiked) {
                Task { await toggleLike() }
            }

            actionButton(icon: isSaved ? "bookmark.fill" : "bookmark", label: "\(saveCount)", isActive: isSaved) {
                Task { await toggleSave() }
            }

            actionButton(icon: "rectangle.on.rectangle.angled", label: flashcardStatus ?? "Flashcards", isActive: false) {
                Task { await generateFlashcards() }
            }

            actionButton(icon: "brain.head.profile", label: "Quiz", isActive: false) {
                // Quiz generation — uses same flow as video content
            }

            actionButton(icon: "square.and.arrow.up", label: "Share", isActive: false) {
                showShareSheet = true
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surface)
    }

    private func actionButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? ColorTokens.gold : ColorTokens.textSecondary)
                Text(label)
                    .font(Typography.micro)
                    .foregroundStyle(isActive ? ColorTokens.gold : ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load

    private func loadContent() async {
        isLoading = true
        content = try? await contentService.fetchContent(id: contentId)

        if let content {
            likeCount = content.likeCount ?? 0
            saveCount = content.saveCount ?? 0

            // Load interaction status
            if let status = try? await contentService.fetchInteractionStatus(contentId: contentId) {
                isLiked = status.isLiked
                isSaved = status.isSaved
            }
        }

        // Load PDF
        if let stream: StreamResponse = try? await playerService.fetchStreamURL(contentId: contentId),
           let urlStr = stream.resolvedURL, let url = URL(string: urlStr) {
            // Download and create PDFDocument
            if let data = try? await URLSession.shared.data(from: url).0 {
                pdfDocument = PDFDocument(data: data)
                if pdfDocument == nil {
                    pdfLoadError = true
                }
            } else {
                pdfLoadError = true
            }
        } else {
            pdfLoadError = true
        }

        isLoading = false
    }

    // MARK: - Actions

    private func toggleLike() async {
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        Haptics.light()
        if let response = try? await contentService.toggleLike(contentId: contentId) {
            isLiked = response.liked
            likeCount = response.likeCount
        }
    }

    private func toggleSave() async {
        isSaved.toggle()
        saveCount += isSaved ? 1 : -1
        Haptics.light()
        if let response = try? await contentService.toggleSave(contentId: contentId) {
            isSaved = response.saved
            saveCount = response.saveCount
        }
    }

    private func generateFlashcards() async {
        flashcardStatus = "Generating..."
        Haptics.light()
        do {
            _ = try await notesService.generateFlashcards(contentId: contentId)
            flashcardStatus = "Created!"
            Haptics.success()
        } catch {
            flashcardStatus = "Flashcards"
            Haptics.error()
        }
    }

    private func trackReadingProgress() {
        let timeSpent = Int(Date().timeIntervalSince(readStartTime))
        guard timeSpent > 5 else { return }
        Task {
            let _ = try? await playerService.updateProgress(
                contentId: contentId,
                currentPosition: timeSpent,
                totalDuration: max(timeSpent, 60),
                timeSpent: timeSpent
            )
            if timeSpent > 30 {
                try? await playerService.markComplete(contentId: contentId)
            }
        }
    }
}

// MARK: - PDFKit View

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(ColorTokens.background)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Share Sheet

private struct NotesShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
