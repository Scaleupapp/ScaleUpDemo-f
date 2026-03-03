import SwiftUI

struct MilestonesView: View {
    @Bindable var viewModel: MyPlanViewModel
    @State private var milestoneToDelete: Milestone?
    @State private var showDeleteConfirm = false
    @State private var selectedPhaseDetail: JourneyPhaseSnapshot?

    private var milestones: [Milestone] { viewModel.milestones }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    statsHeader
                    addMilestoneButton
                    timelineSection
                }
                .padding(.bottom, 80)
            }
        }
        .navigationTitle("Milestones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showAddMilestone = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddMilestone) {
            AddMilestoneSheet(viewModel: viewModel)
        }
        .alert("Delete Milestone", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let m = milestoneToDelete {
                    Task { await viewModel.deleteMilestone(id: m.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove \"\(milestoneToDelete?.title ?? "")\"?")
        }
        .sheet(item: $selectedPhaseDetail) { phase in
            PhaseDetailSheet(phase: phase, viewModel: viewModel)
        }
        .navigationDestination(for: TopicDetailDestination.self) { dest in
            TopicDetailView(topic: dest.topic)
        }
        .navigationDestination(for: QuizListDestination.self) { _ in
            QuizListView()
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statBadge(
                value: milestones.filter { $0.status == "completed" }.count,
                label: "Completed",
                color: ColorTokens.success
            )
            divider
            statBadge(
                value: milestones.filter { $0.status == "in_progress" }.count,
                label: "In Progress",
                color: ColorTokens.gold
            )
            divider
            statBadge(
                value: milestones.filter { $0.status != "completed" && $0.status != "in_progress" }.count,
                label: "Upcoming",
                color: ColorTokens.textTertiary
            )
        }
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private var divider: some View {
        Rectangle()
            .fill(ColorTokens.surfaceElevated)
            .frame(width: 1, height: 32)
    }

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Add Button

    private var addMilestoneButton: some View {
        Button {
            viewModel.showAddMilestone = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.gold)
                Text("Add Custom Milestone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTokens.gold.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(ColorTokens.gold.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                milestoneRow(milestone, index: index, isLast: index == milestones.count - 1)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }

    @ViewBuilder
    private func milestoneRow(_ milestone: Milestone, index: Int, isLast: Bool) -> some View {
        if milestone.type == "phase_completion" {
            Button {
                selectedPhaseDetail = viewModel.matchingPhase(for: milestone)
            } label: {
                timelineCard(milestone, index: index, isLast: isLast, isTappable: true)
            }
            .buttonStyle(.plain)
        } else if let topic = milestone.targetCriteria?.targetTopic {
            NavigationLink(value: TopicDetailDestination(topic: topic)) {
                timelineCard(milestone, index: index, isLast: isLast, isTappable: true)
            }
            .buttonStyle(.plain)
        } else if milestone.type == "score_target" || milestone.type == "final_assessment" {
            NavigationLink(value: QuizListDestination()) {
                timelineCard(milestone, index: index, isLast: isLast, isTappable: true)
            }
            .buttonStyle(.plain)
        } else {
            timelineCard(milestone, index: index, isLast: isLast, isTappable: false)
        }
    }

    private func timelineCard(_ milestone: Milestone, index: Int, isLast: Bool, isTappable: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Timeline dot + line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(statusColor(milestone.status))
                        .frame(width: 14, height: 14)

                    if milestone.status == "completed" {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(statusColor(milestone.status).opacity(0.3), lineWidth: 3)
                )

                if !isLast {
                    Rectangle()
                        .fill(milestone.status == "completed" ? ColorTokens.success.opacity(0.3) : ColorTokens.surfaceElevated)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 20)

            // Card content
            VStack(alignment: .leading, spacing: 8) {
                // Title row
                HStack(alignment: .top) {
                    Image(systemName: typeIcon(milestone.type))
                        .font(.system(size: 14))
                        .foregroundStyle(statusColor(milestone.status))

                    Text(milestone.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    if isTappable {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                // Badges row
                HStack(spacing: 6) {
                    // Status badge
                    if let status = milestone.status {
                        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(statusColor(status))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(statusColor(status).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    // Week badge
                    if milestone.status != "completed", let week = milestone.scheduledWeek {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 8))
                            Text("Week \(week)")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(ColorTokens.info)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ColorTokens.info.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    // Target score
                    if let target = milestone.targetCriteria?.targetScore {
                        HStack(spacing: 3) {
                            Image(systemName: "target")
                                .font(.system(size: 8))
                            Text("\(target)%")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ColorTokens.gold.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    // Topic
                    if let topic = milestone.targetCriteria?.targetTopic {
                        HStack(spacing: 3) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 8))
                            Text(topic.capitalized)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(ColorTokens.gold)
                    }
                }

                // Phase progress (inline)
                if milestone.type == "phase_completion",
                   let phase = viewModel.matchingPhase(for: milestone) {
                    phaseProgressInline(phase: phase)
                }

                // Completion or timing info
                if milestone.status == "completed" {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text("Completed")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(ColorTokens.success)
                } else if let week = milestone.scheduledWeek {
                    let currentWeek = viewModel.currentWeek
                    let weeksAway = week - currentWeek
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        if weeksAway <= 0 {
                            Text("Available now")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ColorTokens.gold)
                        } else if weeksAway == 1 {
                            Text("Unlocks next week")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ColorTokens.info)
                        } else {
                            Text("Unlocks in \(weeksAway) weeks (Week \(week))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }

                // Action hint
                if isTappable {
                    actionHint(for: milestone)
                }

                // Delete button
                Button {
                    milestoneToDelete = milestone
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Remove")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.red.opacity(0.6))
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(milestone.status == "in_progress" ? ColorTokens.gold.opacity(0.08) : ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(milestone.status == "in_progress" ? ColorTokens.gold.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .padding(.bottom, Spacing.md)
        }
    }

    // MARK: - Phase Progress Inline

    @ViewBuilder
    private func phaseProgressInline(phase: JourneyPhaseSnapshot) -> some View {
        let assigned = phase.contentAssigned ?? 0
        let consumed = phase.contentConsumed ?? 0

        if phase.status == "completed" {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.success)
                Text("Phase completed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.success)
            }
        } else if assigned > 0 {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 9))
                    Text("\(consumed)/\(assigned) lessons")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(ColorTokens.textSecondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorTokens.surfaceElevated)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorTokens.gold)
                            .frame(width: geo.size.width * CGFloat(consumed) / CGFloat(max(assigned, 1)))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    // MARK: - Helpers

    private func actionHint(for milestone: Milestone) -> some View {
        HStack(spacing: 4) {
            Image(systemName: actionHintIcon(for: milestone))
                .font(.system(size: 9))
            Text(actionHintText(for: milestone))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(ColorTokens.gold.opacity(0.8))
    }

    private func actionHintIcon(for milestone: Milestone) -> String {
        if milestone.type == "phase_completion" {
            return "rectangle.stack.fill"
        } else if milestone.targetCriteria?.targetTopic != nil {
            return "chart.line.uptrend.xyaxis"
        } else if milestone.type == "score_target" || milestone.type == "final_assessment" {
            return "brain.head.profile"
        }
        return "arrow.right.circle"
    }

    private func actionHintText(for milestone: Milestone) -> String {
        if milestone.type == "phase_completion" {
            return "View phase details"
        } else if let topic = milestone.targetCriteria?.targetTopic {
            return "View \(topic.capitalized) progress"
        } else if milestone.type == "score_target" {
            return "Take a quiz to hit your target"
        } else if milestone.type == "final_assessment" {
            return "Go to quizzes"
        }
        return "View details"
    }

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "completed": return ColorTokens.success
        case "in_progress": return ColorTokens.gold
        case "overdue": return .red
        case "skipped": return ColorTokens.textTertiary
        default: return ColorTokens.textTertiary
        }
    }

    private func typeIcon(_ type: String?) -> String {
        switch type {
        case "topic_completion": return "book.closed.fill"
        case "score_target": return "target"
        case "streak": return "flame.fill"
        case "phase_completion": return "flag.fill"
        case "project": return "hammer.fill"
        case "final_assessment": return "graduationcap.fill"
        case "custom": return "star.fill"
        default: return "flag.fill"
        }
    }
}

// MARK: - Phase Detail Sheet

struct PhaseDetailSheet: View {
    let phase: JourneyPhaseSnapshot
    @Bindable var viewModel: MyPlanViewModel
    @Environment(\.dismiss) private var dismiss

    private var phaseMilestones: [Milestone] {
        viewModel.milestonesForPhase(phase)
    }

    private var contentAssigned: Int { phase.contentAssigned ?? 0 }
    private var contentConsumed: Int { phase.contentConsumed ?? 0 }
    private var contentRemaining: Int { max(0, contentAssigned - contentConsumed) }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        phaseHeader
                        if let topics = phase.focusTopics, !topics.isEmpty {
                            focusTopicsSection(topics)
                        }
                        if let objectives = phase.objectives, !objectives.isEmpty {
                            objectivesSection(objectives)
                        }
                        if contentAssigned > 0 {
                            contentProgressSection
                        }
                        if !phaseMilestones.isEmpty {
                            milestonesSection
                        }
                        if phase.status == "active" && contentRemaining > 0 {
                            whatsLeftSection
                        }
                    }
                    .padding(Spacing.lg)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(phase.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    // MARK: - Phase Header

    private var phaseHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Text(phase.type?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Phase")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ColorTokens.gold.opacity(0.2))
                    .clipShape(Capsule())

                Text(phase.status?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Upcoming")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(phaseStatusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(phaseStatusColor.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()
            }

            if contentAssigned > 0 {
                let pct = Double(contentConsumed) / Double(max(contentAssigned, 1))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(Int(pct * 100))% complete")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(contentConsumed)/\(contentAssigned)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorTokens.surfaceElevated)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [ColorTokens.gold.opacity(0.8), ColorTokens.gold],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Focus Topics

    private func focusTopicsSection(_ topics: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Focus Topics")
            FlowLayout(spacing: 8) {
                ForEach(topics, id: \.self) { topic in
                    Text(topic.capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Objectives

    private func objectivesSection(_ objectives: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Objectives")
            ForEach(objectives, id: \.self) { objective in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.top, 2)
                    Text(objective)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    // MARK: - Content Progress

    private var contentProgressSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Content Progress")
            HStack {
                VStack(spacing: 2) {
                    Text("\(contentConsumed)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.gold)
                    Text("Completed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("\(contentRemaining)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text("Remaining")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("\(contentAssigned)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("Total")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTokens.surface)
            )
        }
    }

    // MARK: - Milestones in Phase

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Milestones")
            ForEach(phaseMilestones) { milestone in
                HStack(spacing: 10) {
                    Circle()
                        .fill(milestoneStatusColor(milestone.status))
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        if let status = milestone.status {
                            Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(milestoneStatusColor(status))
                        }
                    }

                    Spacer()

                    if milestone.status == "completed" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.success)
                    }
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTokens.surface)
                )
            }
        }
    }

    // MARK: - What's Left

    private var whatsLeftSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("What's Left")
            HStack(spacing: Spacing.md) {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(contentRemaining) lessons remaining")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    let incompleteMilestones = phaseMilestones.filter { $0.status != "completed" }.count
                    if incompleteMilestones > 0 {
                        Text("\(incompleteMilestones) milestone\(incompleteMilestones == 1 ? "" : "s") to complete")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTokens.gold.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(ColorTokens.gold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(ColorTokens.textSecondary)
            .textCase(.uppercase)
    }

    private var phaseStatusColor: Color {
        switch phase.status {
        case "completed": return ColorTokens.success
        case "active": return ColorTokens.gold
        default: return ColorTokens.textTertiary
        }
    }

    private func milestoneStatusColor(_ status: String?) -> Color {
        switch status {
        case "completed": return ColorTokens.success
        case "in_progress": return ColorTokens.gold
        case "overdue": return .red
        default: return ColorTokens.textTertiary
        }
    }
}
