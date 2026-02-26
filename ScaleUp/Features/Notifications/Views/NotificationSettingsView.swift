import SwiftUI

// MARK: - Notification Settings View

/// A settings sub-view for managing notification preferences.
/// Intended to be pushed onto a NavigationStack from the profile/settings screen.
struct NotificationSettingsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.openURL) private var openURL

    // MARK: - State

    @State private var notificationManager = NotificationManager()

    @State private var dailyReminderEnabled: Bool = UserDefaultsManager.getBool(for: .notificationDailyReminder)
    @State private var quizRemindersEnabled: Bool = UserDefaultsManager.getBool(for: .notificationQuizReminders)
    @State private var streakRemindersEnabled: Bool = UserDefaultsManager.getBool(for: .notificationStreakReminders)
    @State private var milestoneCelebrationsEnabled: Bool = UserDefaultsManager.getBool(for: .notificationMilestoneCelebrations)

    @State private var reminderTime: Date = {
        let hour = UserDefaultsManager.getInt(for: .notificationDailyReminderHour)
        let minute = UserDefaultsManager.getInt(for: .notificationDailyReminderMinute)
        var components = DateComponents()
        components.hour = hour == 0 && minute == 0 ? 9 : hour // Default to 9:00 AM
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }()

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    authorizationStatusSection
                    dailyReminderSection
                    otherNotificationsSection
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization Status Section

    @ViewBuilder
    private var authorizationStatusSection: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Image(systemName: notificationManager.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(notificationManager.isAuthorized ? ColorTokens.success : ColorTokens.warning)
                    .frame(width: 40, height: 40)
                    .background(
                        (notificationManager.isAuthorized ? ColorTokens.success : ColorTokens.warning)
                            .opacity(0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(notificationManager.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text(
                        notificationManager.isAuthorized
                            ? "You'll receive reminders and updates."
                            : "Enable notifications to stay on track with your learning."
                    )
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

            if !notificationManager.isAuthorized {
                PrimaryButton(title: "Enable Notifications") {
                    Task {
                        let granted = await notificationManager.requestAuthorization()
                        if !granted {
                            // Authorization was denied previously — open system settings
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                openURL(settingsURL)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Daily Reminder Section

    @ViewBuilder
    private var dailyReminderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Daily Learning")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                // Daily reminder toggle
                settingsToggleRow(
                    icon: "clock.fill",
                    iconColor: ColorTokens.primary,
                    title: "Daily Reminder",
                    subtitle: "Get reminded to complete your daily session",
                    isOn: $dailyReminderEnabled
                )
                .onChange(of: dailyReminderEnabled) { _, newValue in
                    UserDefaultsManager.set(newValue, for: .notificationDailyReminder)
                    if newValue {
                        scheduleDailyReminder()
                    } else {
                        notificationManager.cancelNotification(id: "com.scaleup.daily-reminder")
                    }
                }

                if dailyReminderEnabled {
                    Divider()
                        .background(ColorTokens.surfaceElevatedDark)
                        .padding(.leading, 60)

                    // Time picker
                    HStack {
                        Spacer()
                            .frame(width: 60)

                        DatePicker(
                            "Reminder Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .tint(ColorTokens.primary)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .labelsHidden()

                        Spacer()

                        Text("Reminder Time")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .onChange(of: reminderTime) { _, newValue in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        let hour = components.hour ?? 9
                        let minute = components.minute ?? 0
                        UserDefaultsManager.set(hour, for: .notificationDailyReminderHour)
                        UserDefaultsManager.set(minute, for: .notificationDailyReminderMinute)
                        scheduleDailyReminder()
                    }
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .opacity(notificationManager.isAuthorized ? 1 : 0.5)
        .disabled(!notificationManager.isAuthorized)
    }

    // MARK: - Other Notifications Section

    @ViewBuilder
    private var otherNotificationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Activity")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                // Quiz reminders
                settingsToggleRow(
                    icon: "questionmark.circle.fill",
                    iconColor: ColorTokens.info,
                    title: "Quiz Reminders",
                    subtitle: "Get notified when new quizzes are available",
                    isOn: $quizRemindersEnabled
                )
                .onChange(of: quizRemindersEnabled) { _, newValue in
                    UserDefaultsManager.set(newValue, for: .notificationQuizReminders)
                }

                Divider()
                    .background(ColorTokens.surfaceElevatedDark)
                    .padding(.leading, 60)

                // Streak reminders
                settingsToggleRow(
                    icon: "flame.fill",
                    iconColor: ColorTokens.warning,
                    title: "Streak Reminders",
                    subtitle: "Reminded at 8 PM if you haven't learned today",
                    isOn: $streakRemindersEnabled
                )
                .onChange(of: streakRemindersEnabled) { _, newValue in
                    UserDefaultsManager.set(newValue, for: .notificationStreakReminders)
                    if newValue {
                        notificationManager.scheduleStreakReminder()
                    } else {
                        notificationManager.cancelNotification(id: "com.scaleup.streak-reminder")
                    }
                }

                Divider()
                    .background(ColorTokens.surfaceElevatedDark)
                    .padding(.leading, 60)

                // Milestone celebrations
                settingsToggleRow(
                    icon: "trophy.fill",
                    iconColor: ColorTokens.anchorGold,
                    title: "Milestone Celebrations",
                    subtitle: "Celebrate streaks, completions, and achievements",
                    isOn: $milestoneCelebrationsEnabled
                )
                .onChange(of: milestoneCelebrationsEnabled) { _, newValue in
                    UserDefaultsManager.set(newValue, for: .notificationMilestoneCelebrations)
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .opacity(notificationManager.isAuthorized ? 1 : 0.5)
        .disabled(!notificationManager.isAuthorized)
    }

    // MARK: - Toggle Row Component

    @ViewBuilder
    private func settingsToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ColorTokens.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Helpers

    private func scheduleDailyReminder() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        notificationManager.scheduleDailyReminder(
            hour: components.hour ?? 9,
            minute: components.minute ?? 0
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environment(DependencyContainer())
    }
    .preferredColorScheme(.dark)
}
