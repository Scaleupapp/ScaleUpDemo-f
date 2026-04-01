import SwiftUI
import VisionKit
import PDFKit
import UniformTypeIdentifiers

struct CreateNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CreateNotesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                switch vm.step {
                case 0: pickStep
                case 1: detailsStep
                case 2: reviewStep
                default: EmptyView()
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .sheet(isPresented: $vm.showDocumentPicker) {
                DocumentPickerView(onPick: vm.handlePickedDocument)
            }
            .fullScreenCover(isPresented: $vm.showScanner) {
                DocumentScannerView(onScan: vm.handleScannedPages)
            }
            .alert("Upload Failed", isPresented: $vm.showError) {
                Button("OK") {}
            } message: {
                Text(vm.errorMessage ?? "Something went wrong")
            }
            .onChange(of: vm.uploadComplete) { _, done in
                if done { dismiss() }
            }
        }
    }

    private var stepTitle: String {
        ["Upload Notes", "Details", "Review"][min(vm.step, 2)]
    }

    // MARK: - Step 0: Pick

    private var pickStep: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "doc.text.image")
                .font(.system(size: 60))
                .foregroundStyle(ColorTokens.gold)

            Text("Upload your notes")
                .font(Typography.titleLarge)
                .foregroundStyle(.white)

            Text("Share your handwritten or typed notes with others")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Pick PDF File", icon: "doc.fill") {
                    vm.showDocumentPicker = true
                }

                Button {
                    vm.showScanner = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                        Text("Scan with Camera")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ColorTokens.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 1: Details

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // File preview
                if let fileName = vm.selectedFileName {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(ColorTokens.gold)
                        Text(fileName)
                            .font(Typography.bodySmall)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.success)
                    }
                    .padding(Spacing.md)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }

                ScaleUpTextField(label: "Title", icon: "textformat", text: $vm.title, autocapitalization: .words)

                ScaleUpTextField(label: "Description (optional)", icon: "text.alignleft", text: $vm.desc, autocapitalization: .sentences)

                ScaleUpTextField(label: "Domain / Subject", icon: "folder.fill", text: $vm.domain, autocapitalization: .words)

                ScaleUpTextField(label: "Topics (comma separated)", icon: "tag.fill", text: $vm.topicsText, autocapitalization: .words)

                // College autocomplete
                VStack(alignment: .leading, spacing: 0) {
                    ScaleUpTextField(label: "College (optional)", icon: "building.columns.fill", text: $vm.collegeName, autocapitalization: .words)
                        .onChange(of: vm.collegeName) { _, newValue in
                            vm.searchColleges(query: newValue)
                        }

                    if !vm.collegeSuggestions.isEmpty && vm.collegeName.count >= 2 {
                        VStack(spacing: 0) {
                            ForEach(vm.collegeSuggestions.prefix(5)) { college in
                                Button {
                                    vm.collegeName = college.name
                                    vm.collegeId = college.id
                                    vm.collegeSuggestions = []
                                } label: {
                                    HStack {
                                        Text(college.name)
                                            .font(.system(size: 13))
                                            .foregroundStyle(ColorTokens.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.vertical, 8)
                                }
                                Divider().background(ColorTokens.border)
                            }
                        }
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                }

                // Difficulty
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Difficulty")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                    HStack(spacing: Spacing.sm) {
                        ForEach(["beginner", "intermediate", "advanced"], id: \.self) { level in
                            Button {
                                vm.difficulty = level
                            } label: {
                                Text(level.capitalized)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(vm.difficulty == level ? .white : ColorTokens.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(vm.difficulty == level ? ColorTokens.gold : ColorTokens.surface)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                PrimaryButton(title: "Next", isDisabled: !vm.isDetailsValid) {
                    vm.step = 2
                }

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 2: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Summary card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(vm.title)
                        .font(Typography.titleMedium)
                        .foregroundStyle(.white)

                    if !vm.desc.isEmpty {
                        Text(vm.desc)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }

                    HStack(spacing: Spacing.md) {
                        Label(vm.domain, systemImage: "folder.fill")
                        if !vm.collegeName.isEmpty {
                            Label(vm.collegeName, systemImage: "building.columns")
                        }
                    }
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)

                    HStack(spacing: Spacing.sm) {
                        Text(vm.difficulty.capitalized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(ColorTokens.gold)
                            .clipShape(Capsule())

                        ForEach(vm.parsedTopics, id: \.self) { topic in
                            Text(topic)
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ColorTokens.surface)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Info
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(ColorTokens.gold)
                    Text("After uploading, AI will process your notes to generate summary, key concepts, and enable flashcard/quiz creation.")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                // Upload button
                PrimaryButton(
                    title: vm.isUploading ? "Uploading..." : "Upload Notes",
                    isLoading: vm.isUploading
                ) {
                    Task { await vm.upload() }
                }

                // Back button
                Button {
                    vm.step = 1
                } label: {
                    Text("Back to Details")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}

// MARK: - Document Scanner

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        init(onScan: @escaping ([UIImage]) -> Void) { self.onScan = onScan }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true)
            onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}
