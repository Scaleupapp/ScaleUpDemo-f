import SwiftUI

// MARK: - Phase Map View

struct PhaseMapView: View {
    @Environment(DependencyContainer.self) private var dependencies

    let journey: Journey

    @State private var expandedPhase: Int?

    // MARK: - Computed

    private var currentPhaseIndex: Int {
        journey.currentPhaseIndex
    }

    private var phases: [JourneyPhaseDetail] {
        journey.phases
    }

    private var currentWeek: Int {
        journey.currentWeek
    }

    private func phaseEnum(for detail: JourneyPhaseDetail) -> JourneyPhase {
        if let type = detail.type, let phase = JourneyPhase(rawValue: type) {
            return phase
        }
        return .foundation
    }

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero header
                    heroHeader

                    // Phase cards
                    ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                        phaseCard(index: index, phase: phase)
                    }

                    // Journey completion
                    journeyEndMarker

                    Spacer()
                        .frame(height: Spacing.xxl + Spacing.lg)
                }
            }
        }
        .navigationTitle("Learning Path")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            // Auto-expand current phase
            expandedPhase = currentPhaseIndex
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: Spacing.md) {
            // Progress summary
            HStack(spacing: Spacing.lg) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 6)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: overallProgress)
                        .stroke(
                            ColorTokens.heroGradient,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(overallProgress * 100))")
                            .font(Typography.monoLarge)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                        Text("%")
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(journey.title)
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(2)

                    Text("Phase \(currentPhaseIndex + 1) of \(phases.count) \u{00B7} Week \(currentWeek)")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
            )
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.lg)
    }

    private var overallProgress: Double {
        (journey.progress.overallPercentage ?? 0) / 100.0
    }

    // MARK: - Phase Card

    @ViewBuilder
    private func phaseCard(index: Int, phase: JourneyPhaseDetail) -> some View {
        let isCurrent = index == currentPhaseIndex
        let isPast = index < currentPhaseIndex
        let isFuture = index > currentPhaseIndex
        let isExpanded = expandedPhase == index
        let pEnum = phaseEnum(for: phase)

        VStack(spacing: 0) {
            // Timeline connector (top)
            if index > 0 {
                timelineConnector(isPast: isPast || isCurrent)
            }

            // Phase card content
            Button {
                withAnimation(Animations.spring) {
                    expandedPhase = isExpanded ? nil : index
                }
            } label: {
                VStack(spacing: 0) {
                    // Main phase row
                    HStack(spacing: Spacing.md) {
                        // Phase indicator
                        phaseIndicator(
                            index: index,
                            isPast: isPast,
                            isCurrent: isCurrent,
                            isFuture: isFuture,
                            phase: pEnum
                        )

                        // Phase info
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text(phase.name.capitalized)
                                    .font(isCurrent ? Typography.titleMedium : Typography.body)
                                    .foregroundStyle(
                                        isFuture
                                            ? ColorTokens.textTertiaryDark
                                            : ColorTokens.textPrimaryDark
                                    )

                                Spacer()

                                // Status chip
                                phaseStatusChip(isPast: isPast, isCurrent: isCurrent, isFuture: isFuture, phase: pEnum)
                            }

                            // Meta info
                            HStack(spacing: Spacing.md) {
                                if let duration = phase.estimatedDuration {
                                    Label(duration, systemImage: "clock")
                                        .font(Typography.caption)
                                        .foregroundStyle(ColorTokens.textTertiaryDark)
                                }

                                if !phase.weekNumbers.isEmpty {
                                    Label(
                                        "Weeks \(phase.weekNumbers.first ?? 0)-\(phase.weekNumbers.last ?? 0)",
                                        systemImage: "calendar"
                                    )
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiaryDark)
                                }

                                Label(
                                    "\(phase.topics.count) topics",
                                    systemImage: "book"
                                )
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                            }
                        }
                    }
                    .padding(Spacing.md)

                    // Expanded details
                    if isExpanded {
                        expandedSection(
                            phase: phase,
                            index: index,
                            isPast: isPast,
                            isCurrent: isCurrent,
                            isFuture: isFuture,
                            pEnum: pEnum
                        )
                    }
                }
                .background(
                    isCurrent
                        ? phaseColor(pEnum).opacity(0.06)
                        : ColorTokens.surfaceDark
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isCurrent
                                ? phaseColor(pEnum).opacity(0.35)
                                : ColorTokens.surfaceElevatedDark,
                            lineWidth: isCurrent ? 1.5 : 1
                        )
                )
                .shadow(
                    color: isCurrent ? phaseColor(pEnum).opacity(0.15) : .clear,
                    radius: 16, x: 0, y: 6
                )
                .opacity(isFuture ? 0.55 : 1.0)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.md)

            // Timeline connector (bottom)
            if index < phases.count - 1 {
                timelineConnector(isPast: isPast && !isCurrent)
            }
        }
    }

    // MARK: - Phase Indicator

    private func phaseIndicator(
        index: Int,
        isPast: Bool,
        isCurrent: Bool,
        isFuture: Bool,
        phase: JourneyPhase
    ) -> some View {
        ZStack {
            if isCurrent {
                // Outer glow ring
                Circle()
                    .fill(phaseColor(phase).opacity(0.12))
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(phaseColor(phase))
                    .frame(width: 42, height: 42)

                Image(systemName: phaseIcon(phase))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            } else if isPast {
                Circle()
                    .fill(ColorTokens.success)
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(ColorTokens.surfaceElevatedDark)
                    .frame(width: 36, height: 36)

                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
        }
        .frame(width: 52, height: 52)
    }

    // MARK: - Phase Status Chip

    @ViewBuilder
    private func phaseStatusChip(
        isPast: Bool,
        isCurrent: Bool,
        isFuture: Bool,
        phase: JourneyPhase
    ) -> some View {
        if isCurrent {
            Text("In Progress")
                .font(Typography.micro)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(phaseColor(phase))
                .clipShape(Capsule())
        } else if isPast {
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                Text("Done")
                    .font(Typography.micro)
            }
            .foregroundStyle(ColorTokens.success)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 3)
            .background(ColorTokens.success.opacity(0.12))
            .clipShape(Capsule())
        } else {
            Text("Locked")
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textTertiaryDark)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(ColorTokens.surfaceElevatedDark)
                .clipShape(Capsule())
        }
    }

    // MARK: - Expanded Section

    @ViewBuilder
    private func expandedSection(
        phase: JourneyPhaseDetail,
        index: Int,
        isPast: Bool,
        isCurrent: Bool,
        isFuture: Bool,
        pEnum: JourneyPhase
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Divider
            Rectangle()
                .fill(ColorTokens.surfaceElevatedDark)
                .frame(height: 1)
                .padding(.horizontal, Spacing.md)

            // Objectives
            if let objectives = phase.objectives, !objectives.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("What you'll learn")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    ForEach(objectives, id: \.self) { objective in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: isPast ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundStyle(isPast ? ColorTokens.success : phaseColor(pEnum).opacity(0.6))
                                .frame(width: 16)

                            Text(objective)
                                .font(Typography.bodySmall)
                                .foregroundStyle(
                                    isFuture
                                        ? ColorTokens.textTertiaryDark
                                        : ColorTokens.textSecondaryDark
                                )
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }

            // Topics
            if !phase.topics.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Topics")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(phase.topics, id: \.self) { topic in
                            Text(topic)
                                .font(Typography.caption)
                                .foregroundStyle(
                                    isPast ? ColorTokens.success
                                        : isCurrent ? phaseColor(pEnum)
                                        : ColorTokens.textTertiaryDark
                                )
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(
                                    isPast ? ColorTokens.success.opacity(0.1)
                                        : isCurrent ? phaseColor(pEnum).opacity(0.1)
                                        : ColorTokens.surfaceElevatedDark
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }

            // Weekly breakdown with navigation
            if !phase.weekNumbers.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Weeks")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    ForEach(phase.weekNumbers, id: \.self) { weekNum in
                        let isCurrentWeek = weekNum == currentWeek
                        let isCompletedWeek = weekNum < currentWeek
                        let isFutureWeek = weekNum > currentWeek

                        // Get week goals if available
                        let weekPlan = journey.weeklyPlans.first { $0.weekNumber == weekNum }

                        NavigationLink {
                            WeeklyPlanView(
                                weekNumber: weekNum,
                                totalWeeks: journey.weeklyPlans.count,
                                journeyService: dependencies.journeyService
                            )
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                // Week status icon
                                ZStack {
                                    Circle()
                                        .fill(
                                            isCompletedWeek ? ColorTokens.success.opacity(0.12)
                                                : isCurrentWeek ? phaseColor(pEnum).opacity(0.12)
                                                : ColorTokens.surfaceElevatedDark
                                        )
                                        .frame(width: 28, height: 28)

                                    Image(systemName: isCompletedWeek ? "checkmark" : isCurrentWeek ? "play.fill" : "lock.fill")
                                        .font(.system(size: isCompletedWeek || isCurrentWeek ? 10 : 8, weight: .semibold))
                                        .foregroundStyle(
                                            isCompletedWeek ? ColorTokens.success
                                                : isCurrentWeek ? phaseColor(pEnum)
                                                : ColorTokens.textTertiaryDark
                                        )
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: Spacing.xs) {
                                        Text("Week \(weekNum)")
                                            .font(isCurrentWeek ? Typography.bodyBold : Typography.bodySmall)
                                            .foregroundStyle(
                                                isFutureWeek
                                                    ? ColorTokens.textTertiaryDark
                                                    : ColorTokens.textPrimaryDark
                                            )

                                        if isCurrentWeek {
                                            Text("Current")
                                                .font(Typography.micro)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(phaseColor(pEnum))
                                                .clipShape(Capsule())
                                        }
                                    }

                                    if let theme = weekPlan?.theme, theme != "Week \(weekNum)" {
                                        Text(theme)
                                            .font(Typography.caption)
                                            .foregroundStyle(ColorTokens.textTertiaryDark)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if !isFutureWeek || isCurrentWeek {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(ColorTokens.textTertiaryDark)
                                }
                            }
                            .padding(Spacing.sm + 2)
                            .background(
                                isCurrentWeek
                                    ? phaseColor(pEnum).opacity(0.06)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        }
                        .buttonStyle(.plain)
                        .disabled(isFutureWeek && !isCurrentWeek)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }

            // CTA for current phase
            if isCurrent {
                NavigationLink {
                    WeeklyPlanView(
                        weekNumber: currentWeek,
                        totalWeeks: journey.weeklyPlans.count,
                        journeyService: dependencies.journeyService
                    )
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Continue Week \(currentWeek)")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(phaseColor(pEnum))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                .padding(.horizontal, Spacing.md)
            }

            Spacer()
                .frame(height: Spacing.xs)
        }
        .padding(.bottom, Spacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Timeline Connector

    private func timelineConnector(isPast: Bool) -> some View {
        HStack {
            Spacer()
                .frame(width: Spacing.md + 26) // Align with center of indicator
            Rectangle()
                .fill(
                    isPast
                        ? ColorTokens.success.opacity(0.5)
                        : ColorTokens.surfaceElevatedDark
                )
                .frame(width: 2, height: 20)
            Spacer()
        }
    }

    // MARK: - Journey End Marker

    private var journeyEndMarker: some View {
        VStack(spacing: Spacing.sm) {
            timelineConnector(isPast: false)

            ZStack {
                Circle()
                    .fill(ColorTokens.anchorGold.opacity(0.12))
                    .frame(width: 64, height: 64)

                Circle()
                    .fill(ColorTokens.anchorGold.opacity(0.06))
                    .frame(width: 80, height: 80)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(ColorTokens.anchorGold)
            }

            Text("Mastery Achieved")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.anchorGold)

            Text("Complete all phases to reach your goal")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Helpers

    private func phaseColor(_ phase: JourneyPhase) -> Color {
        switch phase {
        case .foundation: return ColorTokens.info
        case .building: return ColorTokens.primary
        case .strengthening: return ColorTokens.warning
        case .mastery: return ColorTokens.success
        case .revision: return Color(hex: "#FD79A8")
        case .examPrep: return ColorTokens.error
        }
    }

    private func phaseIcon(_ phase: JourneyPhase) -> String {
        switch phase {
        case .foundation: return "building.columns.fill"
        case .building: return "hammer.fill"
        case .strengthening: return "figure.strengthtraining.traditional"
        case .mastery: return "crown.fill"
        case .revision: return "arrow.counterclockwise"
        case .examPrep: return "pencil.and.list.clipboard"
        }
    }
}
