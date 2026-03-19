import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutAlert = false
    @State private var showDeactivateAlert = false
    @State private var isDeactivating = false
    @State private var showClearCacheAlert = false
    @State private var cacheCleared = false

    private let userService = UserService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            List {
                accountSection
                preferencesSection
                appSection
                aboutSection
                dangerSection
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                Task { await appState.logout() }
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .alert("Deactivate Account", isPresented: $showDeactivateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Deactivate", role: .destructive) {
                Task { await deactivateAccount() }
            }
        } message: {
            Text("This will deactivate your account. You can reactivate by logging in again within 30 days.")
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will clear cached images and data. The app may load slower temporarily.")
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            if let email = appState.currentUser?.email {
                settingsInfoRow(icon: "envelope.fill", title: "Email", value: email)
            }
            if let phone = appState.currentUser?.phone {
                settingsInfoRow(icon: "phone.fill", title: "Phone", value: phone)
            }
            settingsInfoRow(icon: "key.fill", title: "Auth Provider",
                        value: appState.currentUser?.authProvider?.rawValue.capitalized ?? "Local")
        } header: {
            sectionHeader("Account")
        }
        .listRowBackground(ColorTokens.surface)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section {
            settingsInfoRow(icon: "clock.fill", title: "Member Since",
                        value: memberSinceString)
            settingsInfoRow(icon: "person.fill", title: "Role",
                        value: appState.currentUser?.role.rawValue.capitalized ?? "Consumer")
        } header: {
            sectionHeader("Profile")
        }
        .listRowBackground(ColorTokens.surface)
    }

    // MARK: - App

    private var appSection: some View {
        Section {
            settingsInfoRow(icon: "paintbrush.fill", title: "Appearance", value: "Dark")

            settingsNavigableRow(icon: "bell.fill", title: "Notifications", value: "Enabled") {
                NotificationSettingsView()
            }

            Button {
                showClearCacheAlert = true
            } label: {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 24)

                    Text("Clear Cache")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Spacer()

                    if cacheCleared {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.success)
                            .font(.system(size: 14))
                    }
                }
            }
        } header: {
            sectionHeader("App")
        }
        .listRowBackground(ColorTokens.surface)
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            settingsInfoRow(icon: "info.circle.fill", title: "Version", value: "1.0.0")

            settingsLinkRow(icon: "doc.text.fill", title: "Terms of Service",
                          urlString: "https://scaleup.io/terms")

            settingsLinkRow(icon: "hand.raised.fill", title: "Privacy Policy",
                          urlString: "https://scaleup.io/privacy")
        } header: {
            sectionHeader("About")
        }
        .listRowBackground(ColorTokens.surface)
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        Section {
            Button {
                showLogoutAlert = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                        .foregroundStyle(ColorTokens.warning)
                    Text("Log Out")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.warning)
                    Spacer()
                }
            }

            Button {
                showDeactivateAlert = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.slash.fill")
                        .foregroundStyle(ColorTokens.error)
                    Text("Deactivate Account")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.error)
                    Spacer()
                }
            }
        } header: {
            sectionHeader("")
        }
        .listRowBackground(ColorTokens.surface)
    }

    // MARK: - Row Helpers

    /// Static info row (not tappable)
    private func settingsInfoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 24)

            Text(title)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)

            Spacer()

            Text(value)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
                .lineLimit(1)
        }
    }

    /// Navigable row that pushes a destination view
    private func settingsNavigableRow<Destination: View>(
        icon: String, title: String, value: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 24)

                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Text(value)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    /// Row that opens an external URL
    private func settingsLinkRow(icon: String, title: String, urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 24)

                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.caption)
            .foregroundStyle(ColorTokens.textTertiary)
            .textCase(nil)
    }

    private var memberSinceString: String {
        guard let date = appState.currentUser?.createdAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        cacheCleared = true
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            cacheCleared = false
        }
    }

    private func deactivateAccount() async {
        isDeactivating = true
        do {
            try await userService.deactivate()
            await appState.logout()
        } catch {
            // Silently fail — user stays logged in
        }
        isDeactivating = false
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @Environment(PushNotificationManager.self) private var pushManager
    @State private var quizReminders = true
    @State private var streakReminders = true
    @State private var socialUpdates = true
    @State private var journeyUpdates = true

    @AppStorage("notif_quiz") private var quizPref = true
    @AppStorage("notif_streak") private var streakPref = true
    @AppStorage("notif_social") private var socialPref = true
    @AppStorage("notif_journey") private var journeyPref = true

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            List {
                Section {
                    HStack(spacing: Spacing.sm) {
                        settingsLabel(icon: "bell.fill", title: "Push Notifications")
                        Spacer()
                        if pushManager.isPermissionGranted {
                            Text("Enabled")
                                .font(.system(size: 13))
                                .foregroundStyle(.green)
                        } else {
                            Button("Enable") {
                                Task { await pushManager.requestPermission() }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ColorTokens.gold)
                        }
                    }
                } header: {
                    Text("General")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .textCase(nil)
                } footer: {
                    if !pushManager.isPermissionGranted {
                        Text("Enable push notifications to receive quiz reminders, streak alerts, and more.")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .listRowBackground(ColorTokens.surface)

                Section {
                    Toggle(isOn: $quizReminders) {
                        settingsLabel(icon: "brain.head.profile", title: "Quiz Reminders")
                    }
                    .tint(ColorTokens.gold)
                    .onChange(of: quizReminders) { _, val in quizPref = val }

                    Toggle(isOn: $streakReminders) {
                        settingsLabel(icon: "flame.fill", title: "Streak Reminders")
                    }
                    .tint(ColorTokens.gold)
                    .onChange(of: streakReminders) { _, val in streakPref = val }

                    Toggle(isOn: $journeyUpdates) {
                        settingsLabel(icon: "map.fill", title: "Journey Updates")
                    }
                    .tint(ColorTokens.gold)
                    .onChange(of: journeyUpdates) { _, val in journeyPref = val }

                    Toggle(isOn: $socialUpdates) {
                        settingsLabel(icon: "person.2.fill", title: "Social Updates")
                    }
                    .tint(ColorTokens.gold)
                    .onChange(of: socialUpdates) { _, val in socialPref = val }
                } header: {
                    Text("Categories")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .textCase(nil)
                }
                .listRowBackground(ColorTokens.surface)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            quizReminders = quizPref
            streakReminders = streakPref
            socialUpdates = socialPref
            journeyUpdates = journeyPref
        }
        .task {
            await pushManager.checkPermissionStatus()
        }
    }

    private func settingsLabel(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 24)
            Text(title)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }
}

