import SwiftUI

// MARK: - Request Quiz View

struct RequestQuizView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var topic: String = ""
    @State private var selectedContentIds: [String] = []
    @State private var isSubmitting = false
    @State private var isPolling = false
    @State private var generatedQuiz: Quiz?
    @State private var error: APIError?
    @State private var dotCount = 1
    @State private var pollTask: Task<Void, Never>?
    @State private var pollProgress: Double = 0
    @FocusState private var isTopicFocused: Bool

    private let suggestedTopics = [
        "Machine Learning",
        "Data Structures",
        "System Design",
        "JavaScript ES6+",
        "Swift Concurrency",
        "REST APIs",
        "SQL Databases",
        "Git Workflows",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if isPolling {
                    pollingView
                } else {
                    requestForm
                }
            }
            .navigationTitle("Request a Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        pollTask?.cancel()
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }
            .alert("Error", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "Something went wrong")
            }
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    // MARK: - Request Form

    private var requestForm: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Header illustration
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.primary.opacity(0.1))
                            .frame(width: 88, height: 88)

                        Circle()
                            .fill(ColorTokens.primary.opacity(0.06))
                            .frame(width: 110, height: 110)

                        Image(systemName: "sparkles")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(ColorTokens.primary)
                    }

                    Text("AI-Powered Quiz Generation")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
                .padding(.top, Spacing.lg)

                // Topic input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("What do you want to be quizzed on?")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    TextField("Enter a topic...", text: $topic)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .focused($isTopicFocused)
                        .padding(Spacing.md)
                        .background(ColorTokens.surfaceDark)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(
                                    isTopicFocused ? ColorTokens.primary : ColorTokens.surfaceElevatedDark,
                                    lineWidth: isTopicFocused ? 2 : 1
                                )
                        )
                        .animation(Animations.quick, value: isTopicFocused)

                    Text("A quiz with 5-10 questions will be generated using AI based on your learning history.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
                .padding(.horizontal, Spacing.md)

                // Quick topic suggestions
                if topic.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Popular Topics")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                            .padding(.horizontal, Spacing.md)

                        FlowLayout(spacing: Spacing.sm) {
                            ForEach(suggestedTopics, id: \.self) { suggestion in
                                Button {
                                    topic = suggestion
                                    isTopicFocused = false
                                } label: {
                                    Text(suggestion)
                                        .font(Typography.bodySmall)
                                        .foregroundStyle(ColorTokens.primaryLight)
                                        .padding(.horizontal, Spacing.sm + 4)
                                        .padding(.vertical, Spacing.xs + 2)
                                        .background(ColorTokens.primary.opacity(0.1))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(ColorTokens.primary.opacity(0.2), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }

                Spacer(minLength: Spacing.xxl)

                PrimaryButton(
                    title: "Generate Quiz",
                    isLoading: isSubmitting,
                    isDisabled: topic.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    isTopicFocused = false
                    Task { await submitRequest() }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTopicFocused = true
            }
        }
    }

    // MARK: - Polling View

    private var pollingView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Animated brain icon with rings
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(ColorTokens.primary.opacity(0.1), lineWidth: 2)
                    .frame(width: 140, height: 140)

                // Spinning ring
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        ColorTokens.primary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(pollProgress * 360))
                    .animation(
                        .linear(duration: 2).repeatForever(autoreverses: false),
                        value: pollProgress
                    )

                Image(systemName: "brain")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(ColorTokens.primary)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .onAppear {
                pollProgress = 1
            }

            VStack(spacing: Spacing.sm) {
                Text("Generating Your Quiz")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("AI is crafting questions on")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                Text("\"\(topic)\"")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.primary)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.lg)
            }

            // Step indicators
            VStack(alignment: .leading, spacing: Spacing.sm) {
                pollingStep(text: "Analyzing your learning history", isActive: true)
                pollingStep(text: "Generating questions\(String(repeating: ".", count: dotCount))", isActive: true)
                pollingStep(text: "Finalizing quiz", isActive: false)
            }
            .padding(.horizontal, Spacing.xl)
            .onReceive(
                Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
            ) { _ in
                dotCount = (dotCount % 3) + 1
            }

            Text("This usually takes 15-30 seconds")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Spacer()

            SecondaryButton(title: "Cancel") {
                pollTask?.cancel()
                isPolling = false
                pollProgress = 0
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
    }

    private func pollingStep(text: String, isActive: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.success)
            } else {
                Circle()
                    .stroke(ColorTokens.textTertiaryDark, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }

            Text(text)
                .font(Typography.bodySmall)
                .foregroundStyle(isActive ? ColorTokens.textPrimaryDark : ColorTokens.textTertiaryDark)
        }
    }

    // MARK: - Submit Request

    private func submitRequest() async {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespaces)
        guard !trimmedTopic.isEmpty else { return }

        isSubmitting = true
        error = nil

        do {
            let triggerResponse = try await dependencies.quizService.request(
                topic: trimmedTopic,
                contentIds: selectedContentIds.isEmpty ? nil : selectedContentIds
            )

            isSubmitting = false
            isPolling = true
            startPolling(triggerId: triggerResponse.triggerId)
        } catch let apiError as APIError {
            self.error = apiError
            isSubmitting = false
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            isSubmitting = false
        }
    }

    // MARK: - Polling

    private func startPolling(triggerId: String) {
        pollTask?.cancel()
        pollTask = Task {
            var pollCount = 0
            let maxPolls = 24 // 2 minutes max (5s intervals)

            while !Task.isCancelled && pollCount < maxPolls {
                try? await Task.sleep(for: .seconds(5))

                guard !Task.isCancelled else { return }

                do {
                    let status = try await dependencies.quizService.triggerStatus(triggerId: triggerId)

                    // Quiz generation failed — show error immediately
                    if status.status == "failed" {
                        await MainActor.run {
                            isPolling = false
                            pollProgress = 0
                            self.error = .unknown(0, "Quiz generation failed. Please try again.")
                        }
                        return
                    }

                    // Quiz is ready — fetch it and dismiss
                    if status.status == "generated", let quizId = status.quizId {
                        let quiz = try await dependencies.quizService.getQuiz(id: quizId)
                        generatedQuiz = quiz
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        dismiss()
                        return
                    }
                } catch {
                    // Continue polling on transient errors
                }

                pollCount += 1
            }

            // Timeout
            if !Task.isCancelled {
                await MainActor.run {
                    isPolling = false
                    pollProgress = 0
                    self.error = .unknown(0, "Quiz generation is taking longer than expected. Check back shortly.")
                }
            }
        }
    }
}
