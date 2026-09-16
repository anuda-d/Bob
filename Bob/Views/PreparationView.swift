import SwiftUI
import BobCore
import BobPlan

struct PreparationView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var stage: Stage = .intent
    @State private var input = ""
    @State private var initialIntent = ""
    @State private var stepsText = ""
    @State private var reason = ""
    @State private var clarification = ""
    @State private var conversation: [ConversationMessage] = []
    @State private var isSending = false
    @State private var isConfirming = false
    @State private var requestID = UUID()
    @State private var localError: String?
    @State private var confirmedPlan: MorningPlan?

    private enum Stage { case intent, clarification, draft, confirmed }
    private enum Field: Hashable { case input, steps, reason }

    init(model: AppModel) {
        self.model = model
        let saved = model.conversation
        _conversation = State(initialValue: saved)
        _initialIntent = State(initialValue: saved.first(where: { $0.role == .user })?.text ?? "")
        if !saved.isEmpty {
            switch model.suggestion {
            case .clarification(let question):
                _stage = State(initialValue: .clarification)
                _clarification = State(initialValue: question)
            case .plan(let steps, let reason):
                _stage = State(initialValue: .draft)
                _stepsText = State(initialValue: steps.joined(separator: "\n"))
                _reason = State(initialValue: reason)
            case nil:
                if let last = saved.last, last.role == .bob {
                    _stage = State(initialValue: .clarification)
                    _clarification = State(initialValue: last.text)
                } else {
                    _stage = State(initialValue: .draft)
                    _stepsText = State(initialValue: saved.filter { $0.role == .user }.map(\.text).joined(separator: "\n"))
                }
            }
        }
    }

    private var steps: [String] {
        stepsText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear.frame(height: 0).id("preparation.top")
                    if stage == .confirmed, let confirmedPlan {
                        confirmation(confirmedPlan)
                    } else {
                        introduction
                        ModelErrorView(model: model)
                        if let localError {
                            BobNotice(title: "Let's try that again", message: localError,
                                      symbol: "exclamationmark.circle")
                        }
                        if stage == .draft {
                            draftEditor
                        } else {
                            intentionEditor
                        }
                        if !conversation.isEmpty { conversationDetails }
                    }
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .onChange(of: stage) { _, _ in proxy.scrollTo("preparation.top", anchor: .top) }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if stage == .draft {
                Button(action: confirm) {
                    BusyLabel(title: isConfirming ? "Saving your plan…" : "Confirm my plan", busy: isConfirming)
                }
                .buttonStyle(BobButtonStyle())
                .disabled(steps.isEmpty || isConfirming || model.isBusy)
                .accessibilityIdentifier("plan.confirm")
                .padding(20)
                .background(BobTheme.background)
            }
        }
        .bobScreen()
        .navigationTitle(stage == .confirmed ? "Plan tucked away" : "Prepare for the night")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(stage == .confirmed ? "Done" : "Close") { dismiss() }
                    .frame(minHeight: 44)
                    .disabled(isConfirming)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done typing") { focusedField = nil }.frame(minHeight: 44)
            }
        }
        .interactiveDismissDisabled(isConfirming)
        .onDisappear {
            requestID = UUID()
            if stage == .draft && !model.isBusy {
                model.conversation = sourceConversation
                model.suggestion = .plan(steps: steps, reason: reason)
            } else if stage == .intent && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isBusy {
                model.conversation = [.init(role: .user, text: input)]
            } else if stage == .clarification && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isBusy {
                let saved = conversation + [.init(role: .user, text: input)]
                model.conversation = saved
                model.suggestion = .plan(steps: saved.filter { $0.role == .user }.map(\.text), reason: "")
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            BobPortrait(size: 112, pose: .listening)
            Text(stage == .draft ? "Does this sound like you?" : "What's on your mind for morning?")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if stage == .draft {
                Text("Edit anything. Bob keeps only the plan you confirm.")
                    .foregroundStyle(BobTheme.secondaryText)
            }
            if let availability = model.modelAvailability, stage != .draft {
                BobNotice(title: "Make a plan in your own words", message: availability, symbol: "character.cursor.ibeam")
            }
        }
    }

    private var intentionEditor: some View {
        BobSection {
            if stage == .clarification {
                Text(clarification)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plan.clarification")
            }
            Text(stage == .clarification ? "Your answer" : "Your intentions")
                .font(.subheadline.weight(.semibold))
            TextField(stage == .clarification ? "A little more detail" : "What would you like to begin?",
                      text: $input, axis: .vertical)
                .lineLimit(4...10)
                .textInputAutocapitalization(.sentences)
                .focused($focusedField, equals: .input)
                .bobField()
                .accessibilityLabel(stage == .clarification ? "Your clarification answer" : "Your morning intentions")
                .accessibilityIdentifier("plan.input")
            if model.modelAvailability == nil {
                Button(action: send) {
                    BusyLabel(title: isSending ? "Bob is thinking…" : (stage == .clarification ? "Send answer" : "Make a draft"),
                              busy: isSending)
                }
                .buttonStyle(BobButtonStyle())
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || model.isBusy)
                .accessibilityIdentifier("plan.send")
            }
            Button(action: makeManualDraft) {
                Text(model.modelAvailability == nil ? "Write my plan manually" : "Write my plan")
            }
            .buttonStyle(BobButtonStyle(secondary: true))
            .accessibilityIdentifier("plan.manual")
            .accessibilityHint("Opens an editable plan without needing the on-device model.")
        }
    }

    private var draftEditor: some View {
        VStack(alignment: .leading, spacing: 20) {
            BobSection {
                Text("Morning steps").font(.headline)
                Text("One step per line. Small and specific is plenty.")
                    .font(.subheadline)
                    .foregroundStyle(BobTheme.secondaryText)
                TextField("Add your first step", text: $stepsText, axis: .vertical)
                    .lineLimit(4...14)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedField, equals: .steps)
                    .bobField()
                    .accessibilityLabel("Morning steps, one per line")
                    .accessibilityIdentifier("plan.steps")
                Text("Why it matters to you (optional)").font(.subheadline.weight(.semibold))
                TextField("Your reason, in your words", text: $reason, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedField, equals: .reason)
                    .bobField()
                    .accessibilityLabel("Why it matters, optional")
                    .accessibilityIdentifier("plan.reason")
            }
            BobSection {
                Label("Your alarm", systemImage: "alarm").font(.headline)
                Text("\(BobCopy.time(model.settings).formatted(date: .omitted, time: .shortened)) · \(BobCopy.repeatDays(model.settings.weekdays))")
                Text(BobCopy.challenge(model.settings.challenge.kind)).foregroundStyle(BobTheme.secondaryText)
                Text(BobCopy.challengeDetail(model.settings.challenge)).font(.footnote).foregroundStyle(BobTheme.secondaryText)
                if !model.settings.enabled {
                    Text("Your alarm is off. You can still save this plan, then turn on the alarm in Settings.")
                        .font(.footnote)
                } else if !model.alarmReady {
                    Text(model.alarmStatus).font(.footnote)
                }
            }
            Text("Confirming saves this plan on your iPhone. Completing a wake-up challenge won't check off these steps.")
                .font(.footnote)
                .foregroundStyle(BobTheme.secondaryText)
            Button("Keep editing manually") { focusedField = .steps }
                .frame(minHeight: 44)
                .accessibilityIdentifier("plan.manual")
        }
    }

    private var conversationDetails: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(conversation) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.role == .user ? "You" : "Bob").font(.caption.bold())
                        Text(message.text).textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 12)
        } label: {
            Text("Conversation details").frame(minHeight: 44)
        }
    }

    private func confirmation(_ plan: MorningPlan) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            BobPortrait(size: 180, pose: .pleased).frame(maxWidth: .infinity)
            Text("Tucked away.").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            PlanCard(plan: plan, compact: false)
            if !model.alarmReady || !model.settings.enabled {
                BobSection {
                    BobNotice(title: "Your plan is saved; check your alarm",
                              message: model.settings.enabled ? model.alarmStatus : "Your alarm is currently off. Turn it on from the home screen's alarm settings.",
                              symbol: "alarm")
                }
            }
            Button("Good night") { dismiss() }
                .buttonStyle(BobButtonStyle())
                .accessibilityIdentifier("plan.done")
        }
    }

    private func makeManualDraft() {
        requestID = UUID()
        isSending = false
        localError = nil
        if stage == .intent { initialIntent = input }
        // Seed from the user's words, never from an unconfirmed model response.
        if conversation.isEmpty && !initialIntent.isEmpty {
            conversation = [.init(role: .user, text: initialIntent)]
        }
        if stage == .clarification && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            conversation.append(.init(role: .user, text: input))
        }
        stepsText = conversation.filter { $0.role == .user }.map(\.text).joined(separator: "\n")
        model.conversation = conversation
        stage = .draft
        focusedField = nil
    }

    private func send() {
        let rawText = input
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending, !model.isBusy else { return }
        if stage == .intent {
            initialIntent = input
        }
        focusedField = nil
        isSending = true
        localError = nil
        let request = UUID()
        requestID = request
        Task {
            await model.prepare(text)
            guard requestID == request else { return }
            isSending = false
            conversation = model.conversation
            if let lastUser = conversation.lastIndex(where: { $0.role == .user }) {
                conversation[lastUser].text = rawText
                model.conversation = conversation
            }
            // A failed generation can still return a grounded, editable draft.
            switch model.suggestion {
            case .clarification(let question):
                clarification = question
                input = ""
                stage = .clarification
            case .plan(let suggestedSteps, let suggestedReason):
                stepsText = suggestedSteps.joined(separator: "\n")
                reason = suggestedReason
                stage = .draft
            case nil:
                localError = "Bob didn't return a draft. Try again, or write your plan manually."
            }
        }
    }

    private var sourceConversation: [ConversationMessage] {
        if conversation.contains(where: { $0.role == .user }) { return conversation }
        if !stepsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [.init(role: .user, text: stepsText)]
        }
        return []
    }

    private func confirm() {
        guard !steps.isEmpty, !isConfirming, !model.isBusy else { return }
        let confirmedSteps = steps
        let confirmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousDate = model.plan?.confirmedAt
        focusedField = nil
        isConfirming = true
        localError = nil
        Task {
            // The persisted setter keeps exact user messages separate from edited plan steps.
            model.errorMessage = nil
            model.conversation = sourceConversation
            guard model.errorMessage == nil else { isConfirming = false; return }
            await model.confirmPlan(steps: confirmedSteps, reason: confirmedReason)
            isConfirming = false
            if let plan = model.plan, plan.confirmedAt != previousDate,
               plan.steps == confirmedSteps, plan.reason == confirmedReason {
                confirmedPlan = plan
                stage = .confirmed
            } else if model.errorMessage == nil {
                localError = "The plan hasn't been saved yet. Your draft is still here. Please try confirming again."
            }
        }
    }
}
