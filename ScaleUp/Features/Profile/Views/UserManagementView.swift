import SwiftUI

@Observable
@MainActor
final class UserManagementViewModel {
    var users: [AdminUser] = []
    var searchText = ""
    var selectedRole: String?
    var isLoading = false
    var isLoadingMore = false
    var currentPage = 1
    var hasNextPage = false
    var totalUsers = 0
    var errorMessage: String?

    // Ban/unban confirmation
    var userToAction: AdminUser?
    var showBanConfirm = false
    var showUnbanConfirm = false

    private let adminService = AdminService()
    private var searchTask: Task<Void, Never>?

    func loadUsers(reset: Bool = true) async {
        if reset {
            currentPage = 1
            isLoading = true
        } else {
            isLoadingMore = true
        }
        do {
            let result = try await adminService.fetchUsers(
                search: searchText.isEmpty ? nil : searchText,
                role: selectedRole,
                page: currentPage
            )
            if reset {
                users = result.items
            } else {
                users.append(contentsOf: result.items)
            }
            hasNextPage = result.hasNextPage
            totalUsers = result.total
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        isLoadingMore = false
    }

    func loadMore() async {
        guard hasNextPage, !isLoadingMore else { return }
        currentPage += 1
        await loadUsers(reset: false)
    }

    func debouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await loadUsers()
        }
    }

    func banUser(_ user: AdminUser) async {
        do {
            try await adminService.banUser(id: user.id)
            Haptics.success()
            if let idx = users.firstIndex(where: { $0.id == user.id }) {
                // Optimistic: reload to get fresh data
                await loadUsers()
            }
        } catch {
            Haptics.error()
        }
    }

    func unbanUser(_ user: AdminUser) async {
        do {
            try await adminService.unbanUser(id: user.id)
            Haptics.success()
            await loadUsers()
        } catch {
            Haptics.error()
        }
    }
}

struct UserManagementView: View {
    @State private var viewModel = UserManagementViewModel()

    private let roleFilters: [String?] = [nil, "consumer", "creator", "admin"]

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ColorTokens.textTertiary)
                    TextField("Search by name, email, username...", text: $viewModel.searchText)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                            viewModel.debouncedSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }
                .padding(Spacing.sm)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
                .onChange(of: viewModel.searchText) {
                    viewModel.debouncedSearch()
                }

                // Role filter chips + total count
                HStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(roleFilters, id: \.self) { role in
                                let label = role?.capitalized ?? "All"
                                Button {
                                    viewModel.selectedRole = role
                                    Task { await viewModel.loadUsers() }
                                } label: {
                                    Text(label)
                                        .font(Typography.bodySmall)
                                        .foregroundStyle(viewModel.selectedRole == role ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
                                        .padding(.horizontal, Spacing.md)
                                        .padding(.vertical, Spacing.sm)
                                        .background(viewModel.selectedRole == role ? ColorTokens.gold : ColorTokens.surface)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.leading, Spacing.md)
                    }

                    if viewModel.totalUsers > 0 {
                        Text("\(viewModel.totalUsers)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ColorTokens.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ColorTokens.gold.opacity(0.15))
                            .clipShape(Capsule())
                            .padding(.trailing, Spacing.md)
                    }
                }
                .padding(.vertical, Spacing.sm)

                // User list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(ColorTokens.gold)
                    Spacer()
                } else if viewModel.users.isEmpty {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "person.3")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("No users found")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.users) { user in
                            userRow(user)
                                .listRowBackground(ColorTokens.surface)
                                .listRowSeparatorTint(ColorTokens.border.opacity(0.3))
                        }

                        // Load more
                        if viewModel.hasNextPage {
                            HStack {
                                Spacer()
                                if viewModel.isLoadingMore {
                                    ProgressView().tint(ColorTokens.gold)
                                } else {
                                    Button("Load More") {
                                        Task { await viewModel.loadMore() }
                                    }
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(ColorTokens.gold)
                                }
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("User Management")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadUsers()
        }
        .alert("Ban User", isPresented: $viewModel.showBanConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Ban", role: .destructive) {
                if let user = viewModel.userToAction {
                    Task { await viewModel.banUser(user) }
                }
            }
        } message: {
            if let user = viewModel.userToAction {
                Text("Are you sure you want to ban \(user.displayName)? They will not be able to access the platform.")
            }
        }
        .alert("Unban User", isPresented: $viewModel.showUnbanConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Unban") {
                if let user = viewModel.userToAction {
                    Task { await viewModel.unbanUser(user) }
                }
            }
        } message: {
            if let user = viewModel.userToAction {
                Text("Are you sure you want to unban \(user.displayName)?")
            }
        }
    }

    private func userRow(_ user: AdminUser) -> some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            if let pic = user.profilePicture, let url = URL(string: pic) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        initialsAvatar(user)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                initialsAvatar(user)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(user.displayName)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)
                    if user.isBanned == true {
                        Text("BANNED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ColorTokens.error)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: Spacing.xs) {
                    Text(user.email ?? "No email")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
                HStack(spacing: Spacing.xs) {
                    roleBadge(user.role)
                    if let date = user.createdAt {
                        Text("Joined \(date.formatted(.dateTime.month(.abbreviated).year()))")
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            // Ban/Unban button
            if user.isBanned == true {
                Button {
                    viewModel.userToAction = user
                    viewModel.showUnbanConfirm = true
                } label: {
                    Text("Unban")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.success)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 5)
                        .background(ColorTokens.success.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                Button {
                    viewModel.userToAction = user
                    viewModel.showBanConfirm = true
                } label: {
                    Text("Ban")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.error)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 5)
                        .background(ColorTokens.error.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func initialsAvatar(_ user: AdminUser) -> some View {
        ZStack {
            Circle()
                .fill(ColorTokens.surfaceElevated)
                .frame(width: 40, height: 40)
            Text(user.displayName.prefix(2).uppercased())
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func roleBadge(_ role: UserRole) -> some View {
        let (color, icon): (Color, String) = switch role {
        case .admin: (ColorTokens.info, "shield.fill")
        case .creator: (ColorTokens.gold, "star.fill")
        case .consumer: (ColorTokens.textTertiary, "person.fill")
        }
        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(role.rawValue.capitalized)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
