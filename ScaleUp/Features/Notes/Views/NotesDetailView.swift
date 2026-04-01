import SwiftUI
import PDFKit

struct NotesDetailView: View {
    let contentId: String

    @State private var content: Content?
    @State private var isLoading = true
    @State private var pdfURL: URL?
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
                ProgressView().tint(ColorTokens.gold)
            } else if let content {
                VStack(spacing: 0) {
                    // PDF viewer
                    if let pdfURL {
                        PDFViewerView(url: pdfURL)
                    } else {
                        VStack(spacing: Spacing.md) {
                            ProgressView().tint(ColorTokens.gold)
                            Text("Loading document...")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Bottom action bar
                    notesActionBar(content)
                }
            }
        }
        .navigationTitle(content?.title ?? "Notes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let content {
                NotesShareSheet(items: [
                    "Check out \"\(content.title)\" on ScaleUp!\n\nhttps://scaleupapp.club/content/\(content.id)"
                ])
                .presentationDetents([.medium])
            }
        }
        .task { await loadContent() }
        .onAppear { readStartTime = Date() }
        .onDisappear { trackReadingProgress() }
    }

    // MARK: - Action Bar

    private func notesActionBar(_ content: Content) -> some View {
        HStack(spacing: 0) {
            // Like
            actionButton(icon: "heart", label: "\(content.likeCount ?? 0)") {
                Task { _ = try? await contentService.toggleLike(contentId: content.id) }
            }

            // Save
            actionButton(icon: "bookmark", label: "\(content.saveCount ?? 0)") {
                Task { _ = try? await contentService.toggleSave(contentId: content.id) }
            }

            // Flashcards
            actionButton(
                icon: "rectangle.on.rectangle.angled",
                label: flashcardStatus ?? "Flashcards"
            ) {
                Task { await generateFlashcards() }
            }

            // Quiz
            actionButton(icon: "brain.head.profile", label: "Quiz") {
                // TODO: trigger on-demand quiz generation
            }

            // Share
            actionButton(icon: "square.and.arrow.up", label: "Share") {
                showShareSheet = true
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surface)
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.textSecondary)
                Text(label)
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load

    private func loadContent() async {
        isLoading = true
        content = try? await contentService.fetchContent(id: contentId)

        // Load PDF via stream URL
        if let stream: StreamResponse = try? await playerService.fetchStreamURL(contentId: contentId),
           let urlStr = stream.resolvedURL, let url = URL(string: urlStr) {
            pdfURL = url
        }

        isLoading = false
    }

    private func trackReadingProgress() {
        let timeSpent = Int(Date().timeIntervalSince(readStartTime))
        guard timeSpent > 5 else { return } // Only track if spent > 5 seconds
        Task {
            // Mark progress — treat any reading > 30s as complete
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

    private func generateFlashcards() async {
        flashcardStatus = "Generating..."
        do {
            _ = try await notesService.generateFlashcards(contentId: contentId)
            flashcardStatus = "Created!"
            Haptics.success()
        } catch {
            flashcardStatus = "Flashcards"
            Haptics.error()
        }
    }
}

// MARK: - PDF Viewer

struct PDFViewerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(ColorTokens.background)

        // Load PDF async
        Task {
            if let document = PDFDocument(url: url) {
                await MainActor.run {
                    pdfView.document = document
                }
            }
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Share Sheet

private struct NotesShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
