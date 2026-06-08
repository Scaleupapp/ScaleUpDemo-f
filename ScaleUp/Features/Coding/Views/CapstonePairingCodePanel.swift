import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// Reusable "here's your laptop code" panel — shown at session START
/// (inside CapstonePairView) and again on REJOIN (inside CapstoneLiveView's
/// "Resume on laptop" sheet).
///
/// Displays the 6-digit pairing code, a scan-to-pair QR, the laptop URL
/// with a one-tap copy, a share-sheet button, and the code expiry time.
struct CapstonePairingCodePanel: View {
    let pairingCode: String
    let expiresAt: Date
    let laptopURL: String

    @State private var copiedFlash: CopiedKind?

    private enum CopiedKind { case url, code }

    var body: some View {
        VStack(spacing: 20) {
            codeBlock
            qrBlock
            urlBlock
            expiryLine
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Code block

    private var codeBlock: some View {
        VStack(spacing: 10) {
            Text(formattedCode)
                .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                .tracking(8)
                .padding(.vertical, 18)
                .padding(.horizontal, 32)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("Pairing code \(pairingCode)")

            Button {
                UIPasteboard.general.string = pairingCode
                flash(.code)
            } label: {
                Label(copiedFlash == .code ? "Code copied" : "Copy code",
                      systemImage: copiedFlash == .code ? "checkmark" : "doc.on.doc")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - QR block

    private var qrBlock: some View {
        VStack(spacing: 8) {
            Group {
                if let img = generateQR(for: "https://\(laptopURL)?code=\(pairingCode)") {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 200, height: 200)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ProgressView().frame(width: 200, height: 200)
                }
            }
            Text("Or scan the QR with your laptop camera")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - URL block

    private var urlBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.tint)
                Text(laptopURL)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    UIPasteboard.general.string = "https://\(laptopURL)"
                    flash(.url)
                } label: {
                    Image(systemName: copiedFlash == .url ? "checkmark" : "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .padding(8)
                        .background(Color.accentColor.opacity(0.18))
                        .clipShape(Circle())
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy URL")
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ShareLink(item: "Open https://\(laptopURL) and enter \(pairingCode)") {
                Label("Email / message link", systemImage: "paperplane.fill")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if copiedFlash == .url {
                Text("URL copied — paste it in your laptop's browser")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Expiry

    private var expiryLine: some View {
        Text("Code expires \(relativeExpiry)")
            .font(.footnote)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Helpers

    private var formattedCode: String {
        guard pairingCode.count == 6 else { return pairingCode }
        return "\(pairingCode.prefix(3)) \(pairingCode.suffix(3))"
    }

    private var relativeExpiry: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: expiresAt, relativeTo: Date())
    }

    private func generateQR(for payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func flash(_ kind: CopiedKind) {
        withAnimation(.spring(response: 0.25)) { copiedFlash = kind }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if copiedFlash == kind { copiedFlash = nil }
                }
            }
        }
    }
}
