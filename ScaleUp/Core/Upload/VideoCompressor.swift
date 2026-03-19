import AVFoundation
import Foundation

// MARK: - Video Compressor

@Observable
@MainActor
final class VideoCompressor {
    var progress: Double = 0
    var isCompressing = false

    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?

    /// Compress a video file. Returns the compressed file URL and metadata.
    /// Only compresses if the file exceeds `thresholdBytes` (default 500 MB).
    func compress(inputURL: URL, maxSizeMB: Int = 2000) async throws -> CompressionResult {
        let attrs = try FileManager.default.attributesOfItem(atPath: inputURL.path)
        let originalSize = (attrs[.size] as? Int64) ?? 0

        let asset = AVAsset(url: inputURL)
        let duration = (try? await asset.load(.duration).seconds) ?? 0

        let preset = choosePreset(originalSizeMB: Int(originalSize / (1024 * 1024)), targetMB: maxSizeMB)

        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw CompressionError.sessionCreationFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed_\(UUID().uuidString.prefix(8)).mp4")

        // Remove any leftover file
        try? FileManager.default.removeItem(at: outputURL)

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        exportSession = session
        isCompressing = true
        progress = 0

        startProgressTracking(session: session)

        await session.export()

        stopProgressTracking()
        isCompressing = false

        guard session.status == .completed else {
            throw session.error ?? CompressionError.exportFailed
        }

        let compressedAttrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let compressedSize = (compressedAttrs[.size] as? Int64) ?? 0
        progress = 1.0

        return CompressionResult(
            outputURL: outputURL,
            originalSize: originalSize,
            compressedSize: compressedSize,
            duration: duration,
            preset: preset
        )
    }

    func cancel() {
        exportSession?.cancelExport()
        stopProgressTracking()
        isCompressing = false
    }

    private func choosePreset(originalSizeMB: Int, targetMB: Int) -> String {
        if originalSizeMB <= targetMB {
            return AVAssetExportPresetPassthrough
        }
        if originalSizeMB > targetMB * 3 {
            return AVAssetExportPreset1280x720
        }
        return AVAssetExportPreset1920x1080
    }

    private func startProgressTracking(session: AVAssetExportSession) {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.progress = Double(session.progress)
            }
        }
    }

    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// MARK: - Models

struct CompressionResult: Sendable {
    let outputURL: URL
    let originalSize: Int64
    let compressedSize: Int64
    let duration: TimeInterval
    let preset: String

    var savedPercent: Int {
        guard originalSize > 0 else { return 0 }
        return Int((1.0 - Double(compressedSize) / Double(originalSize)) * 100)
    }

    var compressedSizeDisplay: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    var originalSizeDisplay: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
}

enum CompressionError: LocalizedError {
    case sessionCreationFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .sessionCreationFailed: return "Could not create video compressor"
        case .exportFailed: return "Video compression failed"
        }
    }
}
