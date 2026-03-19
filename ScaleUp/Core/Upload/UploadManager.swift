import Foundation
import UIKit
import AVFoundation

// MARK: - Upload Job

struct UploadJob: Sendable {
    let fileURL: URL
    let fileName: String
    let mimeType: String
    let fileSize: Int64
    let title: String
    let description: String?
    let contentType: String
    let domain: String
    let topics: [String]
    let tags: [String]
    let difficulty: String
}

// MARK: - Upload Manager

@Observable
@MainActor
final class UploadManager {

    // MARK: - Phase

    enum Phase: Equatable {
        case idle
        case compressing
        case uploading
        case registering
        case complete
        case failed
    }

    // MARK: - State

    var phase: Phase = .idle
    var compressionProgress: Double = 0
    var uploadProgress: Double = 0
    var partsCompleted: Int = 0
    var totalParts: Int = 0
    var errorMessage: String?
    var completedContentTitle: String?
    var isActive: Bool { phase != .idle }
    var showOverlay = false

    // Compression info
    var originalFileSize: Int64 = 0
    var compressedFileSize: Int64 = 0
    var compressionSavedPercent: Int = 0
    var wasCompressed = false

    // MARK: - Private

    private let compressor = VideoCompressor()
    private let service = ContentCreationService()
    private var currentJob: UploadJob?
    private var uploadFileURL: URL?
    private var s3Key: String?
    private var uploadId: String?
    private var completedParts: [(partNumber: Int, etag: String)] = []
    private var partURLs: [(partNumber: Int, url: String)] = []
    private var uploadTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    static let partSize: Int = 10 * 1024 * 1024 // 10 MB

    // MARK: - Compression threshold

    private let compressionThresholdBytes: Int64 = 500 * 1024 * 1024 // 500 MB

    // MARK: - Public API

    func startUpload(job: UploadJob) {
        currentJob = job
        originalFileSize = job.fileSize
        errorMessage = nil
        completedContentTitle = nil
        wasCompressed = false
        compressionProgress = 0
        uploadProgress = 0
        partsCompleted = 0
        totalParts = 0
        completedParts = []
        partURLs = []
        showOverlay = true

        beginBackgroundTask()
        uploadTask = Task { await runPipeline(job: job) }
    }

    func retry() {
        guard let job = currentJob else { return }
        errorMessage = nil

        beginBackgroundTask()

        if let fileURL = uploadFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            uploadTask = Task { await runUpload(fileURL: fileURL, job: job) }
        } else {
            uploadTask = Task { await runPipeline(job: job) }
        }
    }

    func cancel() {
        uploadTask?.cancel()
        compressor.cancel()
        phase = .idle
        showOverlay = false

        if let key = s3Key, let uid = uploadId {
            Task {
                try? await service.abortMultipart(key: key, uploadId: uid)
            }
        }
        cleanup()
        endBackgroundTask()
    }

    func dismissOverlay() {
        guard phase == .complete || phase == .failed else { return }
        showOverlay = false
        if phase == .complete {
            phase = .idle
            cleanup()
        }
    }

    // MARK: - Background Task Management

    private func beginBackgroundTask() {
        endBackgroundTask() // End any existing one first
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ScaleUpUpload") { [weak self] in
            // System is about to kill our background time — don't cancel, just end the task marker.
            // The upload state is preserved so it can resume when the user returns.
            Task { @MainActor [weak self] in
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - Pipeline

    private func runPipeline(job: UploadJob) async {
        let isVideo = job.mimeType.hasPrefix("video/")
        let needsCompression = isVideo && job.fileSize > compressionThresholdBytes
        var fileToUpload = job.fileURL

        // Phase 1: Compress if needed
        if needsCompression {
            phase = .compressing
            do {
                let result = try await compressVideo(inputURL: job.fileURL)
                fileToUpload = result.outputURL
                compressedFileSize = result.compressedSize
                compressionSavedPercent = result.savedPercent
                wasCompressed = true
                compressionProgress = 1.0
            } catch {
                if Task.isCancelled { endBackgroundTask(); return }
                phase = .failed
                errorMessage = "Compression failed: \(error.localizedDescription)"
                Haptics.error()
                endBackgroundTask()
                return
            }
        }

        uploadFileURL = fileToUpload
        await runUpload(fileURL: fileToUpload, job: job)
    }

    private func runUpload(fileURL: URL, job: UploadJob) async {
        phase = .uploading
        uploadProgress = 0
        partsCompleted = 0

        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attrs?[.size] as? Int64) ?? job.fileSize

        do {
            let useMultipart = fileSize > Int64(Self.partSize) * 2

            if useMultipart {
                try await uploadMultipart(fileURL: fileURL, fileSize: fileSize, job: job)
            } else {
                try await uploadSinglePut(fileURL: fileURL, fileSize: Int(fileSize), job: job)
            }

            // Phase 3: Register content
            phase = .registering
            uploadProgress = 1.0

            guard let key = s3Key else { throw UploadError.missingKey }

            let body = CompleteUploadRequest(
                key: key,
                title: job.title,
                description: job.description,
                contentType: job.contentType,
                domain: job.domain,
                topics: job.topics,
                tags: job.tags,
                difficulty: job.difficulty
            )

            _ = try await service.completeUpload(body: body)

            phase = .complete
            completedContentTitle = job.title
            Haptics.success()
            endBackgroundTask()

            // Auto-dismiss after 5 seconds
            try? await Task.sleep(for: .seconds(5))
            if phase == .complete {
                showOverlay = false
                phase = .idle
                cleanup()
            }

        } catch {
            if Task.isCancelled { endBackgroundTask(); return }
            phase = .failed
            errorMessage = "Upload failed: \(error.localizedDescription)"
            Haptics.error()
            endBackgroundTask()
        }
    }

    // MARK: - Single PUT Upload (small files)

    private func uploadSinglePut(fileURL: URL, fileSize: Int, job: UploadJob) async throws {
        let uploadInfo = try await service.requestUploadURL(
            fileName: job.fileName,
            fileType: job.mimeType,
            fileSize: fileSize
        )
        s3Key = uploadInfo.key

        totalParts = 1

        guard let url = URL(string: uploadInfo.uploadURL) else { throw UploadError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(job.mimeType, forHTTPHeaderField: "Content-Type")

        let delegate = UploadProgressDelegate { [weak self] fraction in
            Task { @MainActor [weak self] in
                self?.uploadProgress = fraction
            }
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600
        config.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let (_, response) = try await session.upload(for: request, fromFile: fileURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UploadError.s3Failed
        }
        partsCompleted = 1
    }

    // MARK: - Multipart Upload (large files)

    private func uploadMultipart(fileURL: URL, fileSize: Int64, job: UploadJob) async throws {
        let partSize = Self.partSize
        let partCount = Int(ceil(Double(fileSize) / Double(partSize)))
        totalParts = partCount

        if uploadId == nil || partURLs.isEmpty {
            let initResult = try await service.initiateMultipart(
                fileName: job.fileName,
                fileType: job.mimeType,
                fileSize: Int(fileSize),
                partSize: partSize
            )
            s3Key = initResult.key
            uploadId = initResult.uploadId
            partURLs = initResult.partURLs.map { ($0.partNumber, $0.url) }
            completedParts = []
            partsCompleted = 0
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        let completedPartNumbers = Set(completedParts.map(\.partNumber))

        for part in partURLs {
            if Task.isCancelled { throw CancellationError() }
            if completedPartNumbers.contains(part.partNumber) { continue }

            let offset = UInt64(part.partNumber - 1) * UInt64(partSize)
            try handle.seek(toOffset: offset)

            let remainingBytes = Int(fileSize) - Int(offset)
            let readSize = min(partSize, remainingBytes)
            guard let chunkData = handle.readData(ofLength: readSize) as Data?, !chunkData.isEmpty else { continue }

            // Write chunk to temp file for file-based upload (avoids keeping in memory)
            let chunkFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("chunk_\(part.partNumber).tmp")
            try chunkData.write(to: chunkFile)

            guard let partURL = URL(string: part.url) else { throw UploadError.invalidURL }

            var request = URLRequest(url: partURL)
            request.httpMethod = "PUT"
            request.timeoutInterval = 300

            let (_, response) = try await URLSession.shared.upload(for: request, fromFile: chunkFile)

            // Clean up chunk file
            try? FileManager.default.removeItem(at: chunkFile)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw UploadError.partFailed(part.partNumber)
            }

            let etag = http.value(forHTTPHeaderField: "ETag") ?? ""
            completedParts.append((partNumber: part.partNumber, etag: etag))
            partsCompleted = completedParts.count
            uploadProgress = Double(partsCompleted) / Double(totalParts)
        }

        guard let key = s3Key, let uid = uploadId else { throw UploadError.missingKey }
        try await service.completeMultipart(
            key: key,
            uploadId: uid,
            parts: completedParts.map { MultipartPart(partNumber: $0.partNumber, etag: $0.etag) }
        )
    }

    // MARK: - Compression Helper

    private func compressVideo(inputURL: URL) async throws -> CompressionResult {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.compressionProgress = self.compressor.progress
            }
        }
        defer { timer.invalidate() }

        return try await compressor.compress(inputURL: inputURL)
    }

    // MARK: - Cleanup

    private func cleanup() {
        currentJob = nil
        s3Key = nil
        uploadId = nil
        completedParts = []
        partURLs = []
        if let url = uploadFileURL, wasCompressed {
            try? FileManager.default.removeItem(at: url)
        }
        uploadFileURL = nil
    }
}

// MARK: - Upload Progress Delegate

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress(fraction)
    }
}

// MARK: - Errors

enum UploadError: LocalizedError {
    case invalidURL
    case s3Failed
    case partFailed(Int)
    case missingKey

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid upload URL"
        case .s3Failed: return "Storage upload failed"
        case .partFailed(let n): return "Part \(n) upload failed"
        case .missingKey: return "Missing file key"
        }
    }
}
