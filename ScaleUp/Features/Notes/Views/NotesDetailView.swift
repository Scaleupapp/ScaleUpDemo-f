import SwiftUI
import PDFKit

struct NotesDetailView: View {
    let contentId: String

    @State private var content: Content?
    @State private var isLoading = true
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var likeCount = 0
    @State private var saveCount = 0
    @State private var showPDFViewer = false
    @State private var pdfDocument: PDFDocument?
    @State private var isLoadingPDF = false
    @State private var flashcardSetId: String?
    @State private var isGeneratingFlashcards = false
    @State private var isGeneratingQuiz = false
    @State private var showShareSheet = false
    @State private var showContributorCard = false
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
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        headerSection(content)
                        actionButtons
                        viewPDFButton

                        if let aiData = content.aiData, aiData.summary != nil {
                            aiSummarySection(aiData)
                        }

                        studySection
                        aboutSection(content)
                        Spacer().frame(height: Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            }
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPDFViewer) {
            if let pdfDocument {
                FullScreenPDFView(document: pdfDocument, title: content?.title ?? "Notes") {
                    showPDFViewer = false
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let content {
                NotesDetailShareSheet(items: [
                    "Check out \"\(content.title)\" on ScaleUp!\n\nhttps://scaleupapp.club/content/\(content.id)"
                ])
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showContributorCard) {
            if let creatorId = content?.creatorId?.id {
                ContributorCardView(userId: creatorId)
                    .presentationDetents([.medium, .large])
            }
        }
        .navigationDestination(item: $flashcardSetId) { id in
            FlashcardStudyView(flashcardSetId: id)
        }
        .task { await loadContent() }
        .onAppear { readStartTime = Date() }
        .onDisappear { trackReadingProgress() }
    }

    // MARK: - Header

    private func headerSection(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.image.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("NOTES")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange)
                .clipShape(Capsule())

                if let pages = content.pageCount, pages > 0 {
                    Text("\(pages) pages")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                if let rating = content.averageRating, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(ColorTokens.gold)
                        Text(String(format: "%.1f", rating)).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    }
                }
            }

            Text(content.title).font(Typography.titleLarge).foregroundStyle(.white)

            if let desc = content.description, !desc.isEmpty {
                Text(desc).font(Typography.bodySmall).foregroundStyle(ColorTokens.textSecondary)
            }

            HStack(spacing: Spacing.sm) {
                if let creator = content.creatorId {
                    Button { showContributorCard = true } label: {
                        Text(creator.displayName).font(Typography.caption).foregroundStyle(ColorTokens.gold).underline()
                    }
                }
                if let domain = content.domain {
                    Text("·").foregroundStyle(ColorTokens.textTertiary)
                    Text(domain.capitalized).font(Typography.caption).foregroundStyle(ColorTokens.gold)
                }
                if let college = content.collegeName, !college.isEmpty {
                    Text("·").foregroundStyle(ColorTokens.textTertiary)
                    Text(college).font(Typography.caption).foregroundStyle(ColorTokens.textTertiary).lineLimit(1)
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: Spacing.sm) {
            Button { Task { await toggleLike() } } label: {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart").font(.system(size: 14))
                    Text("\(likeCount)").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(isLiked ? ColorTokens.gold : ColorTokens.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(isLiked ? ColorTokens.gold.opacity(0.12) : ColorTokens.surface)
                .clipShape(Capsule())
            }

            Button { Task { await toggleSave() } } label: {
                HStack(spacing: 4) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark").font(.system(size: 14))
                    Text("\(saveCount)").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(isSaved ? ColorTokens.gold : ColorTokens.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(isSaved ? ColorTokens.gold.opacity(0.12) : ColorTokens.surface)
                .clipShape(Capsule())
            }

            Spacer()

            Button { showShareSheet = true } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(10).background(ColorTokens.surface).clipShape(Circle())
            }
        }
    }

    // MARK: - View PDF

    private var viewPDFButton: some View {
        Button { Task { await openPDF() } } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surfaceElevated).frame(width: 50, height: 50)
                    if isLoadingPDF {
                        ProgressView().tint(ColorTokens.gold)
                    } else {
                        Image(systemName: "doc.text.fill").font(.system(size: 22)).foregroundStyle(.orange)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("View Full Document").font(Typography.bodyBold).foregroundStyle(.white)
                    Text("Open PDF viewer").font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(ColorTokens.gold)
            }
            .padding(Spacing.md)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - AI Summary

    private func aiSummarySection(_ aiData: AIData) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(ColorTokens.gold)
                Text("AI Summary").font(Typography.bodyBold).foregroundStyle(.white)
            }

            if let summary = aiData.summary {
                Text(summary).font(Typography.body).foregroundStyle(ColorTokens.textSecondary).lineSpacing(4)
            }

            if let concepts = aiData.keyConcepts, !concepts.isEmpty {
                Divider().background(ColorTokens.border)
                Text("Key Concepts").font(.system(size: 12, weight: .bold)).foregroundStyle(ColorTokens.textTertiary)

                ForEach(concepts.prefix(8), id: \.concept) { kc in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill").font(.system(size: 10)).foregroundStyle(ColorTokens.gold).padding(.top, 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kc.concept).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            if let desc = kc.description, !desc.isEmpty {
                                Text(desc).font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
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

    // MARK: - Study

    private var studySection: some View {
        VStack(spacing: Spacing.sm) {
            Button { Task { await handleFlashcards() } } label: {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.15)).frame(width: 44, height: 44)
                        if isGeneratingFlashcards {
                            ProgressView().tint(.purple)
                        } else {
                            Image(systemName: "rectangle.on.rectangle.angled").font(.system(size: 18)).foregroundStyle(.purple)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isGeneratingFlashcards ? "Generating..." : flashcardSetId != nil ? "Study Flashcards" : "Create Flashcards")
                            .font(Typography.bodyBold).foregroundStyle(.white)
                        Text(flashcardSetId != nil ? "Tap to start studying" : "AI generates cards from this content")
                            .font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(Spacing.md).background(ColorTokens.surface).clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button { Task { await generateQuiz() } } label: {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(ColorTokens.gold.opacity(0.15)).frame(width: 44, height: 44)
                        if isGeneratingQuiz {
                            ProgressView().tint(ColorTokens.gold)
                        } else {
                            Image(systemName: "brain.head.profile").font(.system(size: 18)).foregroundStyle(ColorTokens.gold)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isGeneratingQuiz ? "Generating Quiz..." : "Generate Quiz").font(Typography.bodyBold).foregroundStyle(.white)
                        Text(isGeneratingQuiz ? "This may take a minute" : "Test your understanding of these notes").font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(Spacing.md).background(ColorTokens.surface).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - About

    private func aboutSection(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let topics = content.topics, !topics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(topics.prefix(5), id: \.self) { topic in
                        Text(topic.capitalized).font(.system(size: 10, weight: .medium)).foregroundStyle(ColorTokens.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(ColorTokens.surfaceElevated).clipShape(Capsule())
                    }
                }
            }
            HStack(spacing: Spacing.lg) {
                Label("\(content.viewCount ?? 0) views", systemImage: "eye")
                Label("\(content.commentCount ?? 0) comments", systemImage: "bubble.left")
            }
            .font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.lg).background(ColorTokens.surface).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Logic

    private func loadContent() async {
        isLoading = true
        content = try? await contentService.fetchContent(id: contentId)
        if let content {
            likeCount = content.likeCount ?? 0
            saveCount = content.saveCount ?? 0
            if let s = try? await contentService.fetchInteractionStatus(contentId: contentId) {
                isLiked = s.isLiked; isSaved = s.isSaved
            }
        }
        if let sets = try? await notesService.fetchMyFlashcards() {
            for set in sets.items {
                if let ref = set.contentId {
                    let matchId: String
                    switch ref {
                    case .content(let info): matchId = info.id
                    case .id(let id): matchId = id
                    }
                    if matchId == contentId && set.isReady {
                        flashcardSetId = set.id
                        break
                    }
                }
            }
        }
        isLoading = false
    }

    private func openPDF() async {
        if pdfDocument != nil { showPDFViewer = true; return }
        isLoadingPDF = true
        if let stream: StreamResponse = try? await playerService.fetchStreamURL(contentId: contentId),
           let urlStr = stream.resolvedURL, let url = URL(string: urlStr),
           let data = try? await URLSession.shared.data(from: url).0 {
            pdfDocument = PDFDocument(data: data)
            showPDFViewer = true
        }
        isLoadingPDF = false
    }

    private func toggleLike() async {
        isLiked.toggle(); likeCount += isLiked ? 1 : -1; Haptics.light()
        if let r = try? await contentService.toggleLike(contentId: contentId) { isLiked = r.liked; likeCount = r.likeCount }
    }

    private func toggleSave() async {
        isSaved.toggle(); saveCount += isSaved ? 1 : -1; Haptics.light()
        if let r = try? await contentService.toggleSave(contentId: contentId) { isSaved = r.saved; saveCount = r.saveCount }
    }

    private func handleFlashcards() async {
        if let id = flashcardSetId {
            // Navigate to existing flashcard set
            flashcardSetId = nil
            try? await Task.sleep(for: .milliseconds(100))
            flashcardSetId = id
            return
        }
        isGeneratingFlashcards = true; Haptics.light()
        do {
            _ = try await notesService.generateFlashcards(contentId: contentId)
            for _ in 0..<12 {
                try? await Task.sleep(for: .seconds(5))
                if let sets = try? await notesService.fetchMyFlashcards() {
                    for set in sets.items {
                        if let ref = set.contentId {
                            let matchId: String
                            switch ref {
                            case .content(let info): matchId = info.id
                            case .id(let id): matchId = id
                            }
                            if matchId == contentId && set.isReady {
                                flashcardSetId = set.id; Haptics.success()
                                isGeneratingFlashcards = false
                                return
                            }
                        }
                    }
                }
            }
        } catch { Haptics.error() }
        isGeneratingFlashcards = false
    }

    private func generateQuiz() async {
        guard !isGeneratingQuiz else { return }
        isGeneratingQuiz = true; Haptics.light()
        do {
            let body = NotesQuizRequestBody(topic: content?.domain ?? "general", contentIds: [contentId], questionCount: 10)
            _ = try await APIClient.shared.requestRaw(NotesQuizRequestEndpoint(), body: body)
            // Show success — quiz will appear in quiz list when ready
            Haptics.success()
            // Brief delay then stop spinner
            try? await Task.sleep(for: .seconds(2))
        } catch {
            Haptics.error()
        }
        isGeneratingQuiz = false
    }

    private func trackReadingProgress() {
        let t = Int(Date().timeIntervalSince(readStartTime))
        guard t > 5 else { return }
        Task {
            _ = try? await playerService.updateProgress(contentId: contentId, currentPosition: t, totalDuration: max(t, 60), timeSpent: t)
            if t > 30 { try? await playerService.markComplete(contentId: contentId) }
        }
    }
}

// MARK: - Full Screen PDF

struct FullScreenPDFView: View {
    let document: PDFDocument
    let title: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            PDFKitView(document: document)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { onDismiss() }.foregroundStyle(ColorTokens.gold)
                    }
                }
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView(); v.document = document; v.autoScales = true
        v.displayMode = .singlePageContinuous; v.displayDirection = .vertical
        v.backgroundColor = .systemBackground; return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

private struct NotesQuizRequestBody: Encodable, Sendable {
    let topic: String
    let contentIds: [String]
    let questionCount: Int
}

private struct NotesQuizRequestEndpoint: Endpoint {
    var path: String { "/quizzes/request" }
    var method: HTTPMethod { .post }
}

private struct NotesDetailShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
