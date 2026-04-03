import SwiftUI
import PDFKit

@Observable
@MainActor
final class CreateNotesViewModel {

    // MARK: - State

    var step = 0

    // File
    var selectedFileData: Data?
    var selectedFileName: String?
    var fileFormat: String = "pdf"

    // Details
    var title = ""
    var desc = ""
    var domain = ""
    var topicsText = ""
    var difficulty = "intermediate"
    var collegeName = ""
    var collegeId: String?
    var collegeSuggestions: [CollegeSearchResult] = []

    // Upload
    var isUploading = false
    var uploadComplete = false
    var showError = false
    var errorMessage: String?

    // Pickers
    var showDocumentPicker = false
    var showScanner = false

    private let notesService = NotesService()
    private var searchTask: Task<Void, Never>?

    // MARK: - Computed

    var isDetailsValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !domain.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedFileData != nil
    }

    var parsedTopics: [String] {
        topicsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: - File Handling

    func handlePickedDocument(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            selectedFileData = try Data(contentsOf: url)
            selectedFileName = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            if ["jpg", "jpeg", "png", "heic"].contains(ext) {
                fileFormat = "image"
            } else if ["ppt", "pptx"].contains(ext) {
                fileFormat = "presentation"
            } else {
                fileFormat = "pdf" // pdf, docx, xlsx all uploaded as-is
            }
            step = 1
        } catch {
            errorMessage = "Could not read file"
            showError = true
        }
    }

    func handleScannedPages(images: [UIImage]) {
        guard !images.isEmpty else { return }

        // Convert scanned images to PDF
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)

        for image in images {
            let pageRect = CGRect(origin: .zero, size: image.size)
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            image.draw(in: pageRect)
        }

        UIGraphicsEndPDFContext()

        selectedFileData = pdfData as Data
        selectedFileName = "Scanned Notes (\(images.count) pages).pdf"
        fileFormat = "pdf"
        step = 1
    }

    // MARK: - College Search

    func searchColleges(query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else {
            collegeSuggestions = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results: [CollegeSearchResult] = try await APIClient.shared.request(
                    NotesCollegeSearchEndpoint(query: query)
                )
                if !Task.isCancelled { collegeSuggestions = results }
            } catch {
                if !Task.isCancelled { collegeSuggestions = [] }
            }
        }
    }

    // MARK: - Upload

    func upload() async {
        guard let fileData = selectedFileData else { return }
        isUploading = true

        do {
            // 1. Determine MIME type
            let ext = (selectedFileName ?? "").split(separator: ".").last?.lowercased() ?? "pdf"
            let mimeType: String
            switch ext {
            case "pdf": mimeType = "application/pdf"
            case "doc": mimeType = "application/msword"
            case "docx": mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            case "xls": mimeType = "application/vnd.ms-excel"
            case "xlsx": mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            case "ppt": mimeType = "application/vnd.ms-powerpoint"
            case "pptx": mimeType = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            case "jpg", "jpeg": mimeType = "image/jpeg"
            case "png": mimeType = "image/png"
            default: mimeType = "application/octet-stream"
            }

            // 2. Request presigned URL
            let uploadInfo = try await notesService.requestUpload(
                fileName: selectedFileName ?? "notes.pdf",
                fileType: mimeType,
                fileSize: fileData.count
            )

            // 3. Upload to S3
            guard let uploadURL = URL(string: uploadInfo.uploadURL) else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
            request.httpBody = fileData

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            // 3. Register with backend
            _ = try await notesService.completeUpload(
                key: uploadInfo.key,
                title: title.trimmingCharacters(in: .whitespaces),
                description: desc.isEmpty ? nil : desc,
                domain: domain.trimmingCharacters(in: .whitespaces).lowercased(),
                topics: parsedTopics.map { $0.lowercased() },
                tags: parsedTopics.map { $0.lowercased() },
                difficulty: difficulty,
                thumbnailKey: nil,
                collegeName: collegeName.isEmpty ? nil : collegeName,
                collegeId: collegeId,
                fileFormat: fileFormat
            )

            Haptics.success()
            uploadComplete = true
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            showError = true
            Haptics.error()
        }

        isUploading = false
    }
}

// MARK: - College Search Endpoint (for Notes)

private struct NotesCollegeSearchEndpoint: Endpoint {
    let query: String
    var path: String { "/colleges/search" }
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem]? {
        [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "10")]
    }
}
