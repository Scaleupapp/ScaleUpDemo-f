import SwiftUI

@Observable
@MainActor
final class AdminEmployerRequestsViewModel {
    var employers: [PendingEmployer] = []
    var isLoading = false
    var errorMessage: String?
    var actioningId: String?

    private let adminService = AdminService()

    func loadEmployers() async {
        isLoading = true
        errorMessage = nil
        do {
            employers = try await adminService.fetchPendingEmployers()
        } catch {
            errorMessage = "\(error)"
            employers = []
        }
        isLoading = false
    }

    func approve(employerId: String) async {
        actioningId = employerId
        do {
            try await adminService.approveEmployer(id: employerId)
            Haptics.success()
            await loadEmployers()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to approve"
            Haptics.error()
        }
        actioningId = nil
    }

    func reject(employerId: String) async {
        actioningId = employerId
        do {
            try await adminService.rejectEmployer(id: employerId)
            Haptics.success()
            await loadEmployers()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to reject"
            Haptics.error()
        }
        actioningId = nil
    }
}

// MARK: - View

struct AdminEmployerRequestsView: View {
    @State private var viewModel = AdminEmployerRequestsViewModel()
    @State private var employerToReject: PendingEmployer?

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if let error = viewModel.errorMessage {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.error)
                        Text(error)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.error)
                        Spacer()
                        Button { viewModel.errorMessage = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ColorTokens.error)
                        }
                    }
                    .padding(Spacing.sm)
                    .background(ColorTokens.error.opacity(0.1))
                }

                if viewModel.isLoading && viewModel.employers.isEmpty {
                    Spacer()
                    ProgressView().tint(ColorTokens.gold)
                    Spacer()
                } else if viewModel.employers.isEmpty {
                    emptyState
                } else {
                    employerList
                }
            }
        }
        .navigationTitle("Company Requests")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadEmployers()
        }
        .refreshable {
            await viewModel.loadEmployers()
        }
        .alert("Reject Company?", isPresented: Binding(
            get: { employerToReject != nil },
            set: { if !$0 { employerToReject = nil } }
        )) {
            Button("Cancel", role: .cancel) { employerToReject = nil }
            Button("Reject", role: .destructive) {
                if let employer = employerToReject {
                    Task { await viewModel.reject(employerId: employer.id) }
                }
                employerToReject = nil
            }
        } message: {
            Text("This company will not gain access to contact talent on ScaleUp.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "building.2")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("No pending company requests")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Companies awaiting marketplace access will appear here")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var employerList: some View {
        List(viewModel.employers) { employer in
            employerRow(employer)
                .listRowBackground(ColorTokens.surface)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    private func employerRow(_ employer: PendingEmployer) -> some View {
        let isActioning = viewModel.actioningId == employer.id

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                // Company avatar
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(ColorTokens.surfaceElevated)
                        .frame(width: 44, height: 44)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.gold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(employer.companyName)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(contactLine(employer))
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)

                    Text(employer.email)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if let created = employer.createdAt {
                    Text("Applied \(created.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            if let linkedIn = employer.linkedIn, !linkedIn.isEmpty {
                linkedInLink(linkedIn)
            }

            HStack(spacing: Spacing.sm) {
                Button {
                    Task { await viewModel.approve(employerId: employer.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                        Text("Approve")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ColorTokens.success)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }
                .disabled(isActioning)
                .buttonStyle(.plain)

                Button {
                    employerToReject = employer
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                        Text("Reject")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(ColorTokens.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ColorTokens.error.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }
                .disabled(isActioning)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func contactLine(_ employer: PendingEmployer) -> String {
        if let title = employer.title, !title.isEmpty {
            return "\(employer.name) · \(title)"
        }
        return employer.name
    }

    private func linkedInLink(_ linkedIn: String) -> some View {
        Group {
            if let url = URL(string: linkedIn.hasPrefix("http") ? linkedIn : "https://\(linkedIn)") {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                        Text("LinkedIn")
                            .font(Typography.bodySmall)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(ColorTokens.info)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                    Text(linkedIn)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                }
            }
        }
    }
}
