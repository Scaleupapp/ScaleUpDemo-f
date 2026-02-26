#if DEBUG
import SwiftUI

// MARK: - Debug Menu View

/// Developer-only diagnostics screen with quick access to
/// user state, feature flag toggles, cache management,
/// performance metrics, and testing utilities.
///
/// Wrapped in `#if DEBUG` so it is stripped entirely from
/// release builds.
struct DebugMenuView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.performanceMonitor) private var performanceMonitor
    @Environment(\.cacheManager) private var cacheManager

    @State private var showCopiedToast = false
    @State private var showCrashAlert = false
    @State private var showResetOnboardingAlert = false

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    userInfoSection
                    appInfoSection
                    cacheSection
                    featureFlagsSection
                    performanceSection
                    networkSection
                    actionsSection
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationTitle("Debug Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Force Crash", isPresented: $showCrashAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Crash", role: .destructive) {
                fatalError("Debug: forced crash for testing")
            }
        } message: {
            Text("This will intentionally crash the app. Use this to verify crash reporting integration.")
        }
        .alert("Reset Onboarding", isPresented: $showResetOnboardingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appState.authStatus = .onboarding
            }
        } message: {
            Text("This will navigate you back to the onboarding flow.")
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
            }
        }
        .task {
            await cacheManager.calculateCacheSize()
        }
    }

    // MARK: - User Info Section

    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debugSectionTitle("Current User")

            VStack(spacing: 0) {
                if let user = appState.currentUser {
                    debugRow(label: "ID", value: user.id)
                    debugDivider
                    debugRow(label: "Name", value: "\(user.firstName) \(user.lastName)")
                    debugDivider
                    debugRow(label: "Email", value: user.email)
                    debugDivider
                    debugRow(label: "Role", value: user.role.rawValue.capitalized)
                    debugDivider
                    debugRow(label: "Username", value: user.username ?? "N/A")
                    debugDivider
                    debugRow(label: "Auth Provider", value: user.authProvider)
                    debugDivider
                    debugRow(label: "Onboarding", value: user.onboardingComplete ? "Complete" : "Step \(user.onboardingStep)")
                } else {
                    debugRow(label: "Status", value: "No user signed in")
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debugSectionTitle("App Info")

            VStack(spacing: 0) {
                debugRow(label: "Version", value: AppConfig.fullVersion)
                debugDivider
                debugRow(label: "API Base URL", value: AppConfig.apiBaseURL.absoluteString)
                debugDivider
                debugRow(label: "Auth Status", value: "\(appState.authStatus)")
                debugDivider
                debugRow(label: "URL Scheme", value: AppConfig.urlScheme)
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debugSectionTitle("Cache")

            VStack(spacing: 0) {
                debugRow(label: "Image Cache", value: cacheManager.formattedImageCacheSize)
                debugDivider
                debugRow(label: "Data Cache", value: cacheManager.formattedDataCacheSize)
                debugDivider
                debugRow(label: "Total", value: cacheManager.formattedTotalSize)
                debugDivider

                Button {
                    cacheManager.clearAllCaches()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.error)

                        Text("Clear All Caches")
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

    // MARK: - Feature Flags Section

    private var featureFlagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debugSectionTitle("Feature Flags")

            VStack(spacing: 0) {
                debugToggle(label: "Journeys", isOn: Binding(
                    get: { featureFlags.isJourneyEnabled },
                    set: { featureFlags.isJourneyEnabled = $0 }
                ))
                debugDivider
                debugToggle(label: "Quizzes", isOn: Binding(
                    get: { featureFlags.isQuizEnabled },
                    set: { featureFlags.isQuizEnabled = $0 }
                ))
                debugDivider
                debugToggle(label: "Creator Applications", isOn: Binding(
                    get: { featureFlags.isCreatorApplicationEnabled },
                    set: { featureFlags.isCreatorApplicationEnabled = $0 }
                ))
                debugDivider
                debugToggle(label: "Social Features", isOn: Binding(
                    get: { featureFlags.isSocialFeaturesEnabled },
                    set: { featureFlags.isSocialFeaturesEnabled = $0 }
                ))
                debugDivider
                debugToggle(label: "Offline Progress", isOn: Binding(
                    get: { featureFlags.isOfflineProgressEnabled },
                    set: { featureFlags.isOfflineProgressEnabled = $0 }
                ))
                debugDivider
                debugToggle(label: "AI Recommendations", isOn: Binding(
                    get: { featureFlags.isAIRecommendationsEnabled },
                    set: { featureFlags.isAIRecommendationsEnabled = $0 }
                ))
                debugDivider
                debugToggle(label: "New Player (Exp.)", isOn: Binding(
                    get: { featureFlags.isNewPlayerEnabled },
                    set: { featureFlags.isNewPlayerEnabled = $0 }
                ))
                debugDivider
                debugToggle(label: "Network Logs", isOn: Binding(
                    get: { featureFlags.showNetworkLogs },
                    set: { featureFlags.showNetworkLogs = $0 }
                ))
                debugDivider
                debugToggle(label: "Performance Overlay", isOn: Binding(
                    get: { featureFlags.showPerformanceOverlay },
                    set: { featureFlags.showPerformanceOverlay = $0 }
                ))
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debugSectionTitle("Performance")

            VStack(spacing: 0) {
                debugRow(label: "Memory", value: performanceMonitor.formattedMemoryUsage)
                debugDivider
                debugRow(label: "Memory Warning", value: performanceMonitor.memoryWarningReceived ? "Yes" : "No")
                debugDivider
                debugRow(label: "Total Requests", value: "\(performanceMonitor.totalRequests)")
                debugDivider
                debugRow(label: "Failed Requests", value: "\(performanceMonitor.failedRequests)")
                debugDivider
                debugRow(label: "Avg Response", value: String(format: "%.2fs", performanceMonitor.averageResponseTime))
                debugDivider

                // Screen load times
                if !performanceMonitor.screenLoadTimes.isEmpty {
                    ForEach(
                        performanceMonitor.screenLoadTimes.sorted(by: { $0.key < $1.key }),
                        id: \.key
                    ) { screen, duration in
                        debugRow(label: screen, value: String(format: "%.2fs", duration))
                    }
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debugSectionTitle("Network")

            VStack(spacing: 0) {
                debugRow(label: "Connected", value: NetworkMonitor.shared.isConnected ? "Yes" : "No")
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debugSectionTitle("Actions")

            VStack(spacing: 0) {
                // Copy auth token
                debugActionRow(icon: "doc.on.doc", label: "Copy Auth Token") {
                    if let token = dependencies.tokenManager.accessToken {
                        UIPasteboard.general.string = token
                        withAnimation(Animations.quick) {
                            showCopiedToast = true
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(Animations.quick) {
                                showCopiedToast = false
                            }
                        }
                    }
                }
                debugDivider

                // Reset onboarding
                debugActionRow(icon: "arrow.counterclockwise", label: "Reset Onboarding") {
                    showResetOnboardingAlert = true
                }
                debugDivider

                // Switch user role (simulate)
                if let user = appState.currentUser {
                    Menu {
                        ForEach([UserRole.consumer, .creator, .admin], id: \.self) { role in
                            Button(role.rawValue.capitalized) {
                                simulateRoleSwitch(to: role, currentUser: user)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.2")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.info)
                                .frame(width: 20)

                            Text("Switch Role")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Spacer()

                            Text(user.role.rawValue.capitalized)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textSecondaryDark)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                    }
                    debugDivider
                }

                // Log performance summary
                debugActionRow(icon: "chart.bar.doc.horizontal", label: "Log Performance Summary") {
                    performanceMonitor.logPerformanceSummary()
                }
                debugDivider

                // Force crash
                debugActionRow(icon: "exclamationmark.triangle", label: "Force Crash", isDestructive: true) {
                    showCrashAlert = true
                }
            }
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Simulate Role Switch

    /// Build a new User value with the given role and push it into AppState.
    /// This is a local-only simulation; the backend user is unchanged.
    private func simulateRoleSwitch(to role: UserRole, currentUser user: User) {
        let patched = User(
            id: user.id,
            email: user.email,
            phone: user.phone,
            isPhoneVerified: user.isPhoneVerified,
            isEmailVerified: user.isEmailVerified,
            firstName: user.firstName,
            lastName: user.lastName,
            username: user.username,
            profilePicture: user.profilePicture,
            bio: user.bio,
            dateOfBirth: user.dateOfBirth,
            location: user.location,
            education: user.education,
            workExperience: user.workExperience,
            skills: user.skills,
            role: role,
            authProvider: user.authProvider,
            onboardingComplete: user.onboardingComplete,
            onboardingStep: user.onboardingStep,
            followersCount: user.followersCount,
            followingCount: user.followingCount,
            isActive: user.isActive,
            isBanned: user.isBanned,
            lastLoginAt: user.lastLoginAt,
            createdAt: user.createdAt
        )
        appState.currentUser = patched
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        Text("Token copied to clipboard")
            .font(Typography.bodySmall)
            .fontWeight(.medium)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorTokens.surfaceElevatedDark)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 8)
            .padding(.top, Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func debugSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Typography.titleMedium)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .padding(.horizontal, Spacing.md)
    }

    @ViewBuilder
    private func debugRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            Spacer()

            Text(value)
                .font(Typography.mono)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func debugToggle(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Spacer()

            Toggle("", isOn: isOn)
                .tint(ColorTokens.primary)
                .labelsHidden()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private func debugActionRow(
        icon: String,
        label: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDestructive ? ColorTokens.error : ColorTokens.info)
                    .frame(width: 20)

                Text(label)
                    .font(Typography.body)
                    .foregroundStyle(
                        isDestructive ? ColorTokens.error : ColorTokens.textPrimaryDark
                    )

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private var debugDivider: some View {
        Divider()
            .background(ColorTokens.textTertiaryDark.opacity(0.2))
            .padding(.leading, Spacing.md)
    }
}
#endif
