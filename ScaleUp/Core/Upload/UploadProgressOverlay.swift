import SwiftUI

// MARK: - Floating Upload Progress Overlay

struct UploadProgressOverlay: View {
    @Environment(UploadManager.self) private var manager
    @State private var isExpanded = false

    var body: some View {
        if manager.showOverlay {
            VStack {
                Spacer()

                if isExpanded {
                    expandedView
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                } else {
                    compactPill
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, 90) // Above tab bar
            .animation(Motion.springSmooth, value: isExpanded)
            .animation(Motion.springSmooth, value: manager.phase)
        }
    }

    // MARK: - Compact Pill

    private var compactPill: some View {
        Button {
            isExpanded = true
        } label: {
            HStack(spacing: Spacing.sm) {
                phaseIcon
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(phaseTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(phaseSubtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                // Progress percentage or status icon
                if manager.phase == .compressing || manager.phase == .uploading {
                    Text("\(Int(currentProgress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(ColorTokens.gold)
                } else if manager.phase == .complete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.success)
                } else if manager.phase == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.error)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surface)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            }
            .overlay(alignment: .bottom) {
                // Thin progress bar at bottom of pill
                if manager.phase == .compressing || manager.phase == .uploading {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(ColorTokens.gold)
                            .frame(width: geo.size.width * currentProgress, height: 2)
                            .animation(.easeInOut(duration: 0.3), value: currentProgress)
                    }
                    .frame(height: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack {
                Text("Upload Progress")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            // Phase timeline
            VStack(spacing: 0) {
                if manager.wasCompressed || manager.phase == .compressing {
                    phaseRow(
                        icon: "wand.and.stars",
                        title: "Compressing",
                        detail: compressionDetail,
                        isActive: manager.phase == .compressing,
                        isComplete: manager.phase != .compressing && manager.compressionProgress >= 1.0,
                        progress: manager.compressionProgress
                    )
                }

                phaseRow(
                    icon: "arrow.up.circle",
                    title: "Uploading",
                    detail: uploadDetail,
                    isActive: manager.phase == .uploading,
                    isComplete: manager.phase == .registering || manager.phase == .complete,
                    progress: manager.uploadProgress
                )

                phaseRow(
                    icon: "cpu",
                    title: "Processing",
                    detail: "AI analysis & registration",
                    isActive: manager.phase == .registering,
                    isComplete: manager.phase == .complete,
                    progress: manager.phase == .complete ? 1.0 : (manager.phase == .registering ? 0.5 : 0)
                )
            }

            // Error message
            if manager.phase == .failed, let error = manager.errorMessage {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.error)
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.error)
                        .lineLimit(2)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Action buttons
            HStack(spacing: Spacing.sm) {
                if manager.phase == .failed {
                    Button {
                        manager.retry()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("Retry")
                                .font(Typography.captionBold)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ColorTokens.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                if manager.phase == .complete {
                    Button {
                        manager.dismissOverlay()
                        isExpanded = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Done")
                                .font(Typography.captionBold)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ColorTokens.success)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if manager.phase == .complete || manager.phase == .failed {
                        manager.dismissOverlay()
                        isExpanded = false
                    } else {
                        manager.cancel()
                        isExpanded = false
                    }
                } label: {
                    Text(manager.phase == .complete || manager.phase == .failed ? "Dismiss" : "Cancel")
                        .font(Typography.captionBold)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(ColorTokens.surface)
                .shadow(color: .black.opacity(0.4), radius: 20, y: 6)
        }
    }

    // MARK: - Phase Row

    private func phaseRow(icon: String, title: String, detail: String, isActive: Bool, isComplete: Bool, progress: Double) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                if isComplete {
                    Circle()
                        .fill(ColorTokens.success.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ColorTokens.success)
                } else if isActive {
                    // Spinning progress ring
                    Circle()
                        .stroke(ColorTokens.surfaceElevated, lineWidth: 2)
                        .frame(width: 28, height: 28)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                } else {
                    Circle()
                        .fill(ColorTokens.surfaceElevated)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? ColorTokens.textPrimary : (isComplete ? ColorTokens.success : ColorTokens.textTertiary))

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            if isActive {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(ColorTokens.gold)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private var phaseIcon: some View {
        Group {
            switch manager.phase {
            case .idle:
                ProgressView()
                    .tint(ColorTokens.gold)
            case .compressing:
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.gold)
                    .symbolEffect(.pulse)
            case .uploading:
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.gold)
                    .symbolEffect(.pulse)
            case .registering:
                ProgressView()
                    .tint(ColorTokens.gold)
            case .complete:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.success)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.error)
            }
        }
    }

    private var phaseTitle: String {
        switch manager.phase {
        case .idle: return "Preparing..."
        case .compressing: return "Compressing video"
        case .uploading: return "Uploading"
        case .registering: return "Processing..."
        case .complete: return manager.completedContentTitle ?? "Upload complete"
        case .failed: return "Upload failed"
        }
    }

    private var phaseSubtitle: String {
        switch manager.phase {
        case .idle: return "Starting..."
        case .compressing: return "Optimizing for upload"
        case .uploading: return "Sending to cloud"
        case .registering: return "AI analysis queued"
        case .complete: return "Content is being analyzed"
        case .failed: return "Tap to see details"
        }
    }

    private var currentProgress: Double {
        switch manager.phase {
        case .compressing: return manager.compressionProgress
        case .uploading: return manager.uploadProgress
        default: return 0
        }
    }

    private var compressionDetail: String {
        if manager.wasCompressed && manager.phase != .compressing {
            let original = ByteCountFormatter.string(fromByteCount: manager.originalFileSize, countStyle: .file)
            let compressed = ByteCountFormatter.string(fromByteCount: manager.compressedFileSize, countStyle: .file)
            return "\(original) → \(compressed) (saved \(manager.compressionSavedPercent)%)"
        }
        return "Reducing file size for faster upload"
    }

    private var uploadDetail: String {
        return "\(Int(manager.uploadProgress * 100))% uploaded"
    }
}
