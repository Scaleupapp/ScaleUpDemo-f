import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var notificationsEnabled = true
    @State private var isLoggingOut = false

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {

                    // Account Section
                    accountSection

                    // Preferences Section
                    preferencesSection

                    // Content Section
                    contentSection

                    // Creator Section
                    if appState.currentUser?.role != .creator {
                        creatorSection
                    }

                    // Admin Section (only for admin users)
                    if appState.currentUser?.role == .admin {
                        adminSection
                    }

                    // About Section
                    aboutSection

                    // Danger Zone
                    dangerZoneSection

                    // Bottom spacing
                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access your account.")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Placeholder — not yet implemented
            }
        } message: {
            Text("This action is permanent and cannot be undone. All your data will be deleted.")
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            settingsSectionTitle("Account")

            VStack(spacing: 0) {
                // Email (display only)
                settingsDisplayRow(
                    icon: "envelope.fill",
                    iconColor: ColorTokens.primary,
                    title: "Email",
                    value: appState.currentUser?.email ?? "Not set"
                )

                settingsDivider

                // Phone (display only)
                settingsDisplayRow(
                    icon: "phone.fill",
                    iconColor: ColorTokens.success,
                    title: "Phone",
                    value: appState.currentUser?.phone ?? "Not set"
                )

                settingsDivider

                // Change Password (placeholder)
                settingsNavigationRow(
                    icon: "lock.fill",
                    iconColor: ColorTokens.warning,
                    title: "Change Password"
                ) {
                    settingsPlaceholder(title: "Change Password", icon: "lock.fill", subtitle: "Password management coming soon.")
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            settingsSectionTitle("Preferences")

            VStack(spacing: 0) {
                // Color Scheme Picker
                colorSchemePicker

                settingsDivider

                // Notifications
                settingsNavigationRow(
                    icon: "bell.fill",
                    iconColor: ColorTokens.error,
                    title: "Notifications"
                ) {
                    NotificationSettingsView()
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Color Scheme Picker

    @ViewBuilder
    private var colorSchemePicker: some View {
        HStack(spacing: Spacing.sm) {
            settingsIconBadge(icon: "paintbrush.fill", color: ColorTokens.primary)

            Text("Appearance")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Spacer()

            Picker("", selection: Binding(
                get: { colorSchemeOption },
                set: { setColorScheme($0) }
            )) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var colorSchemeOption: Int {
        switch appState.preferredColorScheme {
        case nil: return 0
        case .light: return 1
        case .dark: return 2
        default: return 0
        }
    }

    private func setColorScheme(_ option: Int) {
        switch option {
        case 0: appState.preferredColorScheme = nil
        case 1: appState.preferredColorScheme = .light
        case 2: appState.preferredColorScheme = .dark
        default: break
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            settingsSectionTitle("Content")

            VStack(spacing: 0) {
                // Offline Downloads (placeholder)
                settingsNavigationRow(
                    icon: "arrow.down.circle.fill",
                    iconColor: ColorTokens.info,
                    title: "Offline Downloads"
                ) {
                    settingsPlaceholder(title: "Offline Downloads", icon: "arrow.down.circle.fill", subtitle: "Manage your downloaded content for offline access.")
                }

                settingsDivider

                // Clear Cache
                settingsActionRow(
                    icon: "trash.fill",
                    iconColor: ColorTokens.textTertiaryDark,
                    title: "Clear Cache"
                ) {
                    // Placeholder action
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Creator Section

    private var creatorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            settingsSectionTitle("Creator")

            VStack(spacing: 0) {
                settingsNavigationRow(
                    icon: "star.fill",
                    iconColor: ColorTokens.warning,
                    title: "Become a Creator"
                ) {
                    CreatorApplicationView()
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Admin Section

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            settingsSectionTitle("Administration")

            VStack(spacing: 0) {
                settingsNavigationRow(
                    icon: "shield.fill",
                    iconColor: ColorTokens.error,
                    title: "Admin Panel"
                ) {
                    AdminDashboardView()
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            settingsSectionTitle("About")

            VStack(spacing: 0) {
                // App Version
                settingsDisplayRow(
                    icon: "info.circle.fill",
                    iconColor: ColorTokens.textTertiaryDark,
                    title: "Version",
                    value: appVersion
                )

                settingsDivider

                // Terms of Service
                settingsNavigationRow(
                    icon: "doc.text.fill",
                    iconColor: ColorTokens.textTertiaryDark,
                    title: "Terms of Service"
                ) {
                    settingsPlaceholder(title: "Terms of Service", icon: "doc.text.fill", subtitle: "Terms of service content will be displayed here.")
                }

                settingsDivider

                // Privacy Policy
                settingsNavigationRow(
                    icon: "hand.raised.fill",
                    iconColor: ColorTokens.textTertiaryDark,
                    title: "Privacy Policy"
                ) {
                    settingsPlaceholder(title: "Privacy Policy", icon: "hand.raised.fill", subtitle: "Privacy policy content will be displayed here.")
                }

                settingsDivider

                // Rate App
                settingsActionRow(
                    icon: "heart.fill",
                    iconColor: ColorTokens.error,
                    title: "Rate App"
                ) {
                    // Placeholder — would open App Store review
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            settingsSectionTitle("Danger Zone")

            VStack(spacing: 0) {
                // Logout
                Button {
                    showLogoutAlert = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        settingsIconBadge(icon: "rectangle.portrait.and.arrow.right", color: ColorTokens.error)

                        Text("Sign Out")
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.error)

                        Spacer()

                        if isLoggingOut {
                            ProgressView()
                                .tint(ColorTokens.error)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }

                settingsDivider

                // Delete Account
                Button {
                    showDeleteAlert = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        settingsIconBadge(icon: "person.crop.circle.badge.xmark", color: ColorTokens.error)

                        Text("Delete Account")
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.error)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Logout

    private func performLogout() {
        isLoggingOut = true
        let authMgr = dependencies.authManager
        Task {
            await authMgr.logout()
            appState.logout()
            isLoggingOut = false
        }
    }

    // MARK: - App Version

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Reusable Settings Row Components

    @ViewBuilder
    private func settingsSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Typography.titleMedium)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .padding(.horizontal, Spacing.md)
    }

    @ViewBuilder
    private func settingsIconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func settingsDisplayRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: Spacing.sm) {
            settingsIconBadge(icon: icon, color: iconColor)

            Text(title)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Spacer()

            Text(value)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func settingsNavigationRow<Destination: View>(icon: String, iconColor: Color, title: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Spacing.sm) {
                settingsIconBadge(icon: icon, color: iconColor)

                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    @ViewBuilder
    private func settingsToggleRow(icon: String, iconColor: Color, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Spacing.sm) {
            settingsIconBadge(icon: icon, color: iconColor)

            Text(title)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Spacer()

            Toggle("", isOn: isOn)
                .tint(ColorTokens.primary)
                .labelsHidden()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func settingsActionRow(icon: String, iconColor: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                settingsIconBadge(icon: icon, color: iconColor)

                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private var settingsDivider: some View {
        Divider()
            .background(ColorTokens.textTertiaryDark.opacity(0.2))
            .padding(.leading, Spacing.md + 28 + Spacing.sm)
    }

    // MARK: - Placeholder View

    @ViewBuilder
    private func settingsPlaceholder(title: String, icon: String, subtitle: String) -> some View {
        ZStack {
            ColorTokens.backgroundDark.ignoresSafeArea()
            EmptyStateView(
                icon: icon,
                title: title,
                subtitle: subtitle
            )
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
