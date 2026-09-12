import SwiftUI
import BobCore

struct MorningView: View {
    let model: AppModel

    var body: some View {
        Group {
            if let occurrence = model.occurrence {
                MorningOccurrenceView(model: model, occurrence: occurrence)
                    .id(occurrence.id)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ModelErrorView(model: model)
                        BobNotice(title: "No active morning", message: "Your saved plan and alarm settings are on the home screen.", symbol: "sun.max")
                        Button("Back to Bob") { model.dismissMorning() }
                            .buttonStyle(BobButtonStyle())
                            .accessibilityIdentifier("morning.done")
                    }
                    .padding(20)
                }
            }
        }
        .bobScreen()
        .navigationTitle("Your morning")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MorningOccurrenceView: View {
    let model: AppModel
    let occurrence: MorningOccurrence
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var answerFocused: Bool
    @State private var started = false
    @State private var isStarting = false
    @State private var isSubmitting = false
    @State private var isSwitching = false
    @State private var isSilencing = false
    @State private var isScanning = false
    @State private var answer = ""
    @State private var answerFeedback: String?
    @State private var scanFeedback: String?
    @AccessibilityFocusState private var completionFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear.frame(height: 0).id("morning.top")
                    if occurrence.isComplete {
                        completed
                    } else {
                        introduction
                        ModelErrorView(model: model)
                        deadlineNotice
                        challengePanel.id("morning.challenge")
                        soundPanel
                        if let plan = occurrence.plan {
                            PlanCard(plan: plan)
                        } else {
                            BobNotice(title: "No saved plan for this morning",
                                      message: "You can still finish your challenge. Tonight, leave yourself a few words.", symbol: "text.book.closed")
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: occurrence.isComplete) { _, complete in
                if complete { proxy.scrollTo("morning.top", anchor: .top) }
            }
            .onChange(of: started) { _, didStart in
                if didStart { proxy.scrollTo("morning.challenge", anchor: .top) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if !occurrence.isComplete {
                silenceControl
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(BobTheme.background)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done typing") { answerFocused = false }.frame(minHeight: 44)
            }
        }
        .onChange(of: occurrence.usingFallback) { _, _ in
            answer = ""
            answerFeedback = nil
            scanFeedback = nil
        }
        .onChange(of: occurrence.isComplete) { _, complete in
            if complete {
                answerFocused = false
                completionFocused = true
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            BobPortrait(size: 104)
            Text("Morning, human.").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            if let plan = occurrence.plan, !plan.reason.isEmpty {
                Text(plan.reason).font(.title3).foregroundStyle(.secondary)
            } else if let first = occurrence.plan?.steps.first {
                Text("You wanted to begin with: \(first)").font(.title3).foregroundStyle(.secondary)
            } else {
                Text("One small start. I'll be here.").font(.title3).foregroundStyle(.secondary)
            }
            if let plan = occurrence.plan {
                Text("From your plan confirmed \(plan.confirmedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deadlineNotice: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if context.date >= occurrence.audibleDeadline {
                BobPanel {
                    BobNotice(title: "Retry window ended",
                              message: "No new retries are scheduled after 15 minutes. An existing system alert may still need silencing outside Bob. This challenge is incomplete; you can still finish it.",
                              symbol: "bell.slash")
                        .accessibilityIdentifier("morning.deadline")
                }
            }
        }
    }

    private var soundPanel: some View {
        DisclosureGroup {
            BobPanel {
                    BobNotice(title: "Sound and challenge are separate",
                              message: "Silence the sound and keep going. Inactivity can bring another ring. No new retries are scheduled after \(occurrence.audibleDeadline.formatted(date: .omitted, time: .shortened)); an existing system alert may need silencing.",
                              symbol: "bell")
            }
        } label: {
            Text("About sound and retries").frame(minHeight: 44)
        }
    }

    private var silenceControl: some View {
        VStack(spacing: 6) {
            Button {
                guard !isSilencing else { return }
                isSilencing = true
                Task {
                    model.errorMessage = nil
                    await model.silence()
                    isSilencing = false
                }
            } label: {
                Text(isSilencing ? "Silencing…" : "Silence alarm")
            }
            .buttonStyle(BobButtonStyle(secondary: true))
            .disabled(isSilencing)
            .accessibilityIdentifier("morning.silence")
            .accessibilityHint("Stops the current sound. Your challenge remains incomplete.")
            Text("Your challenge stays open.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var challengePanel: some View {
        BobPanel {
            Label(occurrence.usingFallback ? "Your puzzle fallback" : BobCopy.challenge(occurrence.effectiveChallenge),
                  systemImage: BobCopy.symbol(occurrence.effectiveChallenge))
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            // Keep recovery before the preview so it remains reachable on small screens and large text.
            if occurrence.settings.challenge.kind != .puzzle && !occurrence.usingFallback {
                fallbackControl
            }
            if started || occurrence.usingFallback {
                switch occurrence.effectiveChallenge {
                case .puzzle: puzzle
                case .pushups: pushups
                case .qr: qr
                }
            } else {
                Text(startDescription).foregroundStyle(.secondary)
                if occurrence.verifiedSeconds > 0 { activityProgress }
                Button(action: start) {
                    BusyLabel(title: isStarting ? "Getting ready…" : "Start challenge", busy: isStarting)
                }
                .buttonStyle(BobButtonStyle())
                .disabled(isStarting || model.isBusy || isSwitching)
                .accessibilityIdentifier("morning.start")
            }
        }
    }

    @ViewBuilder private var fallbackControl: some View {
        if let fallback = occurrence.settings.challenge.fallback {
            Button {
                guard !isSwitching, !model.isBusy else { return }
                isSwitching = true
                answerFocused = false
                Task {
                    await model.useFallback()
                    isSwitching = false
                    if model.occurrence?.id == occurrence.id && model.occurrence?.usingFallback == true { started = true }
                }
            } label: {
                Text(isSwitching ? "Opening fallback…" : "Use \(BobCopy.difficulty(fallback).lowercased()) puzzle instead")
            }
            .buttonStyle(BobButtonStyle(secondary: true))
            .disabled(isSwitching || model.isBusy)
            .accessibilityIdentifier("morning.fallback")
            .accessibilityHint("Uses your preselected puzzle fallback. No camera failure is required.")
        } else {
            BobNotice(title: "No fallback was saved",
                      message: "This occurrence has no puzzle fallback. Silence remains available; configure a fallback in your next alarm.",
                      symbol: "exclamationmark.circle")
        }
    }

    private var startDescription: String {
        switch occurrence.effectiveChallenge {
        case .pushups: "Set your phone to see your whole body from the side. Only verified movement adds time. Everything you've earned stays."
        case .puzzle: "Take a moment to think. A correct answer moves you forward; a wrong one leaves your progress intact."
        case .qr: "Find the code you registered during setup. A different code won't complete this challenge."
        }
    }

    private var puzzle: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let problem = occurrence.puzzle.currentProblem {
                Text("Problem \(occurrence.puzzle.solvedCount + 1) of \(occurrence.puzzle.problems.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(problem.prompt)
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("morning.problem")
                    .accessibilityLabel(problem.prompt.replacingOccurrences(of: "×", with: " times ")
                        .replacingOccurrences(of: "+", with: " plus ")
                        .replacingOccurrences(of: "-", with: " minus "))
                Text("Your answer").font(.subheadline.weight(.semibold))
                TextField("Enter a number", text: $answer)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($answerFocused)
                    .bobField()
                    .accessibilityLabel("Puzzle answer")
                    .accessibilityIdentifier("morning.answer")
                    .onSubmit(submit)
                    .onChange(of: answer) { _, _ in answerFeedback = nil }
                if let answerFeedback {
                    Text(answerFeedback)
                        .font(.subheadline)
                        .accessibilityIdentifier("morning.answerFeedback")
                }
                Button(action: submit) {
                    BusyLabel(title: isSubmitting ? "Checking…" : "Check answer", busy: isSubmitting)
                }
                .buttonStyle(BobButtonStyle())
                .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || model.isBusy)
                .accessibilityIdentifier("morning.submit")
                Text("You have four minutes to think after starting or submitting an answer. Simply leaving the screen open doesn't extend it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                BobNotice(title: "The puzzle isn't ready", message: "Your challenge is still open. Try loading it again.", symbol: "puzzlepiece.extension")
                Button("Load puzzle", action: start)
                    .buttonStyle(BobButtonStyle())
                    .disabled(isStarting || model.isBusy)
                    .accessibilityIdentifier("morning.start")
            }
        }
    }

    private var pushups: some View {
        VStack(alignment: .leading, spacing: 16) {
            activityProgress
            Text("Full body in view, side on. Move at your own pace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            CameraCaptureView(mode: .pushups, onActivity: { seconds in
                guard scenePhase == .active else { return }
                Task {
                    guard model.occurrence?.id == occurrence.id,
                          model.occurrence?.isComplete == false,
                          model.occurrence?.effectiveChallenge == .pushups else { return }
                    await model.acceptActivity(seconds)
                }
            })
        }
    }

    private var activityProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(floor(min(20, max(0, occurrence.verifiedSeconds)) * 10) / 10, specifier: "%.1f") / 20 seconds")
                .font(.title2.bold())
                .monospacedDigit()
            ProgressView(value: min(20, max(0, occurrence.verifiedSeconds)), total: 20)
                .accessibilityLabel("Verified pushup activity")
                .accessibilityValue("\(Int(min(20, max(0, occurrence.verifiedSeconds)))) of 20 seconds")
                .accessibilityIdentifier("morning.progress")
            Text("Earned time stays, even when tracking pauses.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var qr: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scan the same code you registered with Bob.").foregroundStyle(.secondary)
            if let scanFeedback {
                Text(scanFeedback).font(.subheadline).accessibilityIdentifier("morning.scanFeedback")
            }
            CameraCaptureView(mode: .qr, onCode: { code in
                guard scenePhase == .active, !isScanning else { return }
                isScanning = true
                Task {
                    defer { isScanning = false }
                    guard model.occurrence?.id == occurrence.id,
                          model.occurrence?.isComplete == false,
                          model.occurrence?.effectiveChallenge == .qr else { return }
                    await model.scanCode(code)
                    if model.occurrence?.isComplete == false {
                        let feedback = model.errorMessage ?? "That isn't your registered code. Your challenge is still open; try the original code."
                        if scanFeedback != feedback {
                            scanFeedback = feedback
                            UIAccessibility.post(notification: .announcement, argument: feedback)
                        }
                    }
                }
            })
        }
    }

    private var completed: some View {
        VStack(alignment: .leading, spacing: 20) {
            BobPortrait(size: 168).frame(maxWidth: .infinity)
            Text("You're up. I'm off.")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("morning.completed")
                .accessibilityFocused($completionFocused)
            Text(BobCopy.completion(occurrence.completionMethod))
                .font(.title3)
                .accessibilityIdentifier("morning.completionMethod")
            Text("This challenge is complete. Your morning plan is still yours to begin.")
                .foregroundStyle(.secondary)
            ModelErrorView(model: model)
            if model.errorMessage != nil {
                Button("Try silencing alarm") {
                    Task {
                        model.errorMessage = nil
                        await model.silence()
                    }
                }
                .buttonStyle(BobButtonStyle(secondary: true))
                .accessibilityIdentifier("morning.silence")
            }
            if let plan = occurrence.plan {
                PlanCard(plan: plan, compact: false)
            } else {
                Text("No plan was saved for this morning. There's room to make one tonight.")
                    .foregroundStyle(.secondary)
            }
            Button("Back to my day") { model.dismissMorning() }
                .buttonStyle(BobButtonStyle())
                .accessibilityIdentifier("morning.done")
        }
    }

    private func start() {
        guard !isStarting, !model.isBusy else { return }
        isStarting = true
        Task {
            model.errorMessage = nil
            await model.beginChallenge()
            isStarting = false
            if model.errorMessage == nil { started = true }
        }
    }

    private func submit() {
        let submittedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedAnswer.isEmpty, !isSubmitting, !model.isBusy else { return }
        isSubmitting = true
        answerFocused = false
        Task {
            model.errorMessage = nil
            let accepted = await model.submitAnswer(submittedAnswer)
            isSubmitting = false
            if accepted {
                answer = ""
                answerFeedback = "That one's solved. Here's the next."
            } else {
                answerFeedback = model.errorMessage ?? "Not quite. Try again; your earlier answers are safe."
            }
            if model.occurrence?.isComplete == false, let feedback = answerFeedback {
                UIAccessibility.post(notification: .announcement, argument: feedback)
            }
        }
    }
}
