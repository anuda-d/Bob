import SwiftUI
import BobCore

struct AlarmSettingsView: View {
    let model: AppModel
    let onSaved: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: AlarmSettings
    @State private var isSaving = false
    @State private var registeringCode = false
    @State private var confirmingDelete = false
    private let isSetup: Bool

    init(model: AppModel, onSaved: @escaping (Bool) -> Void) {
        self.model = model
        self.onSaved = onSaved
        isSetup = !model.setupComplete
        var initial = model.settings
        if !model.setupComplete { initial.enabled = true }
        if initial.challenge.kind != .puzzle && initial.challenge.fallback == nil {
            initial.challenge.fallback = .easy
        }
        _draft = State(initialValue: initial)
    }

    private var needsCode: Bool {
        draft.challenge.kind == .qr && (draft.challenge.qrCode?.isEmpty != false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModelErrorView(model: model)
                timePanel
                challengePanel
                if draft.challenge.kind != .puzzle { fallbackPanel }
                BobSection { AlarmReadinessView(model: model) }
                if !isSetup {
                    Button("Remove alarm", role: .destructive) { confirmingDelete = true }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(isSaving || model.isBusy)
                        .accessibilityIdentifier("alarm.delete")
                }
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                BusyLabel(title: isSaving ? "Saving alarm…" : "Save alarm", busy: isSaving)
            }
            .buttonStyle(BobButtonStyle())
            .disabled(needsCode || isSaving || model.isBusy)
            .accessibilityIdentifier("alarm.save")
            .padding(20)
            .background(BobTheme.background)
        }
        .bobScreen()
        .navigationTitle(isSetup ? "Your first morning" : "Alarm settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .frame(minHeight: 44)
                    .disabled(isSaving)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .sheet(isPresented: $registeringCode) {
            NavigationStack {
                QRRegistrationView { code in
                    draft.challenge.qrCode = code
                    registeringCode = false
                }
            }
            .bobScreen()
        }
        .confirmationDialog("Remove this alarm?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove alarm", role: .destructive) {
                Task {
                    isSaving = true
                    model.errorMessage = nil
                    await model.deleteAlarm()
                    isSaving = false
                    if model.errorMessage == nil { dismiss() }
                }
            }
        } message: {
            Text("Your saved plan will still be available.")
        }
        .onChange(of: draft.challenge.kind) { _, kind in
            if kind != .puzzle && draft.challenge.fallback == nil { draft.challenge.fallback = .easy }
        }
    }

    private var timePanel: some View {
        BobSection {
            Text("Wake-up time").font(.headline).accessibilityAddTraits(.isHeader)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 16) { hourPicker; minutePicker }
            } else {
                HStack(spacing: 16) { hourPicker; minutePicker }
            }
            Text("24-hour time, in your iPhone's current time zone.")
                .font(.caption)
                .foregroundStyle(BobTheme.secondaryText)
            Divider()
            NavigationLink {
                RepeatingDaysView(days: $draft.weekdays)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repeat").foregroundStyle(.primary)
                        Text(BobCopy.repeatDays(draft.weekdays)).foregroundStyle(BobTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary).accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier("alarm.repeat")
            if draft.weekdays.isEmpty {
                Text("No repeat days: ring once at the next selected time.")
                    .font(.footnote)
                    .foregroundStyle(BobTheme.secondaryText)
            }
            Divider()
            Toggle("Alarm enabled", isOn: $draft.enabled)
                .frame(minHeight: 44)
                .accessibilityIdentifier("alarm.enabled")
        }
    }

    private var hourPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hour").font(.subheadline).foregroundStyle(BobTheme.secondaryText)
            Picker("Hour, 24-hour time", selection: $draft.hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(minWidth: 100, maxWidth: .infinity)
            .frame(height: 144)
            .clipped()
            .accessibilityLabel("Hour, 24-hour time")
            .accessibilityIdentifier("alarm.hour")
        }
    }

    private var minutePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Minute").font(.subheadline).foregroundStyle(BobTheme.secondaryText)
            Picker("Minute", selection: $draft.minute) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(minWidth: 100, maxWidth: .infinity)
            .frame(height: 144)
            .clipped()
            .accessibilityLabel("Minute")
            .accessibilityIdentifier("alarm.minute")
        }
    }

    private var challengePanel: some View {
        BobSection {
            Text("Your wake-up challenge").font(.headline).accessibilityAddTraits(.isHeader)
            Picker("Challenge", selection: $draft.challenge.kind) {
                Text("Pushups").tag(ChallengeKind.pushups)
                Text("Puzzle").tag(ChallengeKind.puzzle)
                Text("QR code").tag(ChallengeKind.qr)
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("alarm.challenge")
            switch draft.challenge.kind {
            case .pushups:
                BobNotice(title: "20 seconds, gathered as you go",
                          message: "The camera counts verified pushup activity. Pauses and unclear tracking keep the time you've already earned.",
                          symbol: BobCopy.symbol(.pushups))
                Text("No video is saved. Set the phone where it can see your full body from the side.")
                    .font(.footnote)
                    .foregroundStyle(BobTheme.secondaryText)
            case .puzzle:
                DifficultyPicker(title: "Difficulty", selection: $draft.challenge.difficulty,
                                 identifier: "alarm.difficulty")
            case .qr:
                BobNotice(title: "One familiar code",
                          message: "Register a QR code here, then scan that same code in the morning. Put it somewhere useful.",
                          symbol: "qrcode")
                if !needsCode {
                    Label("QR code registered", systemImage: "checkmark.circle")
                        .foregroundStyle(BobTheme.green)
                        .accessibilityIdentifier("alarm.qr.registered")
                }
                Button(needsCode ? "Register a QR code" : "Replace registered code") { registeringCode = true }
                    .buttonStyle(BobButtonStyle(secondary: true))
                    .accessibilityIdentifier("alarm.qr.register")
                if needsCode {
                    Text("Scan and confirm a code before saving this alarm.")
                        .font(.footnote)
                        .foregroundStyle(BobTheme.secondaryText)
                }
            }
        }
    }

    private var fallbackPanel: some View {
        BobSection {
            Text("For a different kind of morning").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Choose a puzzle fallback now. It's always available if the camera, code, or your body needs a break.")
                .font(.subheadline)
                .foregroundStyle(BobTheme.secondaryText)
            DifficultyPicker(title: "Puzzle fallback", selection: Binding(
                get: { draft.challenge.fallback ?? .easy },
                set: { draft.challenge.fallback = $0 }
            ), identifier: "alarm.fallback")
        }
    }

    private func save() {
        guard !isSaving, !model.isBusy, !needsCode else { return }
        Task {
            isSaving = true
            model.errorMessage = nil
            let saved = await model.saveAlarm(draft)
            isSaving = false
            if saved { onSaved(isSetup) }
        }
    }
}

private struct DifficultyPicker: View {
    let title: String
    @Binding var selection: PuzzleDifficulty
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: $selection) {
                Text("Easy").tag(PuzzleDifficulty.easy)
                Text("Hard").tag(PuzzleDifficulty.hard)
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier(identifier)
            Text(selection == .easy ? "One small addition problem." : "Three arithmetic problems: multiplication, subtraction, and addition.")
                .font(.footnote)
                .foregroundStyle(BobTheme.secondaryText)
        }
    }
}

private struct RepeatingDaysView: View {
    @Binding var days: Set<Int>

    var body: some View {
        List {
            Section {
                ForEach(BobCopy.orderedWeekdays, id: \.self) { day in
                    Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(
                        get: { days.contains(day) },
                        set: { selected in
                            if selected { days.insert(day) } else { days.remove(day) }
                        }
                    ))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("alarm.weekday.\(day)")
                }
            } footer: {
                Text("Leave every day off for a one-time alarm.")
            }
        }
        .scrollContentBackground(.hidden)
        .bobScreen()
        .navigationTitle("Repeating days")
        .navigationBarTitleDisplayMode(.inline)
    }
}
