import SwiftUI
import UniformTypeIdentifiers

/// V2 Note flow — opened from Compass when the user asks to "make a note".
///
/// Two tabs:
///   • Upload — pick a PDF / slide deck / image, give it a title + domain,
///     upload it. On success the user lands on the note's detail screen
///     where they generate a summary, audio narration, mind map, flashcards,
///     or a quiz (the mature v1 NotesDetailView surface — reused as-is).
///   • My notes — every note the user has uploaded; tap to reopen.
struct V2NoteFlowView: View {
    let onClose: () -> Void

    @State private var tab: Tab = .upload
    @State private var path = NavigationPath()

    // Upload state
    @State private var fileData: Data?
    @State private var fileName: String = ""
    @State private var fileFormat: String = "pdf"
    @State private var title: String = ""
    @State private var domain: String = ""
    @State private var topicsText: String = ""
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showPicker = false

    // History state
    @State private var myNotes: [Content] = []
    @State private var notesLoading = false
    @State private var notesError: String?

    private let notesService = NotesService()

    enum Tab: String, CaseIterable { case upload = "Upload", history = "My notes" }

    private var canUpload: Bool {
        fileData != nil &&
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !domain.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isUploading
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                picker
                Divider().background(V2Theme.cardBorder)
                ScrollView {
                    switch tab {
                    case .upload:  uploadTab
                    case .history: historyTab
                    }
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
            .navigationDestination(for: Content.self) { content in
                NotesDetailView(contentId: content.id)
            }
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handlePick(result)
        }
        .task { await loadMyNotes() }
    }

    // MARK: - Segmented picker

    private var picker: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    tab = t
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tab == t ? ColorTokens.gold : ColorTokens.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(tab == t ? ColorTokens.gold : .clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, V2Theme.pad)
    }

    // MARK: - Upload tab

    private var uploadTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Turn a document into a summary, audio narration, mind map, flashcards, and a quiz.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)

            Button {
                showPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: fileData == nil ? "doc.badge.plus" : "doc.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileData == nil ? "Choose a file" : fileName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(1)
                        Text(fileData == nil ? "PDF, slide deck, or image" : "Tap to change")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(V2Theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: fileData == nil ? [5] : []))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            field(label: "Title", text: $title, placeholder: "e.g. DBMS Unit 3 notes")
            field(label: "Subject / domain", text: $domain, placeholder: "e.g. computer science")
            field(label: "Topics (optional, comma-separated)", text: $topicsText, placeholder: "e.g. indexing, normalization")

            if let err = uploadError {
                Text(err)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.warning)
            }

            Button {
                Task { await upload() }
            } label: {
                HStack(spacing: 8) {
                    if isUploading { ProgressView().tint(ColorTokens.background) }
                    Text(isUploading ? "Uploading…" : "Upload & process")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canUpload ? ColorTokens.gold : ColorTokens.surfaceElevated)
                .foregroundStyle(canUpload ? ColorTokens.background : ColorTokens.textTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canUpload)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, V2Theme.pad)
        .padding(.top, 18)
    }

    private func field(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(ColorTokens.textTertiary)
            TextField(placeholder, text: text)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - History tab

    @ViewBuilder
    private var historyTab: some View {
        if notesLoading && myNotes.isEmpty {
            ProgressView().tint(ColorTokens.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
        } else if let err = notesError, myNotes.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text(err)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
                Button("Try again") { Task { await loadMyNotes() } }
                    .buttonStyle(.bordered)
                    .tint(ColorTokens.gold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 70)
        } else if myNotes.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("No notes yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Upload your first document to get started.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 70)
        } else {
            VStack(spacing: 10) {
                ForEach(myNotes) { note in
                    Button {
                        path.append(note)
                    } label: {
                        noteRow(note)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 16)
        }
    }

    private func noteRow(_ note: Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconFor(note.fileFormat))
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 38, height: 38)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text([note.domain?.capitalized, formattedDate(note.createdAt)].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(12)
        .background(ColorTokens.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func iconFor(_ format: String?) -> String {
        switch format {
        case "image": return "photo"
        case "presentation": return "rectangle.on.rectangle"
        default: return "doc.text"
        }
    }

    private func formattedDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    // MARK: - File picking

    private var allowedTypes: [UTType] {
        var types: [UTType] = [.pdf, .image, .presentation]
        if let docx = UTType("org.openxmlformats.wordprocessingml.document") { types.append(docx) }
        if let doc = UTType("com.microsoft.word.doc") { types.append(doc) }
        return types
    }

    private func handlePick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                uploadError = "Couldn't access that file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                fileData = try Data(contentsOf: url)
                fileName = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                if ["jpg", "jpeg", "png", "heic"].contains(ext) {
                    fileFormat = "image"
                } else if ["ppt", "pptx"].contains(ext) {
                    fileFormat = "presentation"
                } else {
                    fileFormat = "pdf"
                }
                if title.isEmpty {
                    title = url.deletingPathExtension().lastPathComponent
                }
                uploadError = nil
            } catch {
                uploadError = "Couldn't read that file."
            }
        case .failure:
            uploadError = "File selection failed."
        }
    }

    // MARK: - Upload

    private func upload() async {
        guard let data = fileData, canUpload else { return }
        isUploading = true
        uploadError = nil
        do {
            let ext = fileName.split(separator: ".").last?.lowercased() ?? "pdf"
            let mime = mimeType(for: String(ext))

            let info = try await notesService.requestUpload(
                fileName: fileName.isEmpty ? "note.pdf" : fileName,
                fileType: mime,
                fileSize: data.count
            )
            guard let uploadURL = URL(string: info.uploadURL) else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue(mime, forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let topics = topicsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }

            let content = try await notesService.completeUpload(
                key: info.key,
                title: title.trimmingCharacters(in: .whitespaces),
                description: nil,
                domain: domain.trimmingCharacters(in: .whitespaces).lowercased(),
                topics: topics,
                tags: topics,
                difficulty: "intermediate",
                thumbnailKey: nil,
                collegeName: nil,
                collegeId: nil,
                fileFormat: fileFormat
            )

            isUploading = false
            // Reset the form, refresh history, jump straight into the note.
            fileData = nil
            fileName = ""
            title = ""
            domain = ""
            topicsText = ""
            await loadMyNotes()
            path.append(content)
        } catch {
            isUploading = false
            uploadError = "Upload failed. Check your connection and try again."
        }
    }

    private func mimeType(for ext: String) -> String {
        switch ext {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }

    // MARK: - History load

    private func loadMyNotes() async {
        notesLoading = true
        notesError = nil
        do {
            myNotes = try await notesService.fetchMyNotes()
        } catch {
            notesError = "Couldn't load your notes."
        }
        notesLoading = false
    }
}
