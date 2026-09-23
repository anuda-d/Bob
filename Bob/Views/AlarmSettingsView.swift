import SwiftUI
import BobCore

struct AlarmSettingsView: View {
    let model: AppModel
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: AlarmSettings
    @State private var isSaving = false
    @State private var registeringCode = false
    @State private var confirmingDelete = false
    private let isSetup: Bool

    init(model: AppModel, onSaved: @escaping () -> Void) {
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
            VStack(alignment: .leading, spacing: 24) {
                ModelErrorView(model: model)
                timePanel
                RepeatingDaysView(days: $draft.weekdays)
                challengePanel
                if draft.challenge.kind != .puzzle { fallbackPanel }
                if !isSetup && draft.enabled && model.settings.enabled && !model.alarmReady {
                    AlarmReadinessView(model: model)
                }
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
            .disabled(isSaving || model.isBusy)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                BusyLabel(title: isSaving ? "Saving alarm…" : (isSetup ? "Set alarm" : "Save alarm"), busy: isSaving)
            }
            .buttonStyle(BobButtonStyle())
            .disabled(needsCode || isSaving || model.isBusy)
            .accessibilityIdentifier("alarm.save")
            .padding(20)
            .background(BobTheme.background)
        }
        .bobScreen()
        .navigationTitle(isSetup ? "Set your alarm" : "Alarm")
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
        VStack(alignment: .leading, spacing: 0) {
            if !isSetup {
                Toggle("Alarm on", isOn: $draft.enabled)
                    .font(.headline)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("alarm.enabled")
            }
            DatePicker("Wake-up time", selection: Binding(
                get: { BobCopy.time(draft) },
                set: { time in
                    draft.hour = Calendar.current.component(.hour, from: time)
                    draft.minute = Calendar.current.component(.minute, from: time)
                }
            ), displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("alarm.time")
        }
    }

    private var challengePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wake-up challenge").font(.headline).accessibilityAddTraits(.isHeader)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                challengeChoice(.puzzle, title: "Puzzle")
                challengeChoice(.pushups, title: "Pushups")
                challengeChoice(.qr, title: "QR code")
            }
            switch draft.challenge.kind {
            case .pushups:
                Text("20 seconds of pushups, counted with the camera. Place your phone to see your full body from the side.")
                    .font(.subheadline)
                    .foregroundStyle(BobTheme.secondaryText)
            case .puzzle:
                DifficultyPicker(title: "Difficulty", selection: $draft.challenge.difficulty,
                                 identifier: "alarm.difficulty")
            case .qr:
                Text("Scan the same QR code each morning. Put it somewhere that gets you out of bed.")
                    .font(.subheadline)
                    .foregroundStyle(BobTheme.secondaryText)
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

    private func challengeChoice(_ kind: ChallengeKind, title: String) -> some View {
        let selected = draft.challenge.kind == kind
        return Button { draft.challenge.kind = kind } label: {
            VStack(spacing: 6) {
                Image(systemName: BobCopy.symbol(kind)).font(.title3).accessibilityHidden(true)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(8)
            .foregroundStyle(selected ? BobTheme.onGreen : BobTheme.green)
            .background(selected ? BobTheme.green : BobTheme.field,
                        in: RoundedRectangle(cornerRadius: BobTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BobTheme.controlRadius)
                    .strokeBorder(BobTheme.green.opacity(selected ? 0 : 0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("alarm.challenge.\(kind.rawValue)")
    }

    private var fallbackPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backup puzzle").font(.headline).accessibilityAddTraits(.isHeader)
            DifficultyPicker(title: "Backup puzzle", selection: Binding(
                get: { draft.challenge.fallback ?? .easy },
                set: { draft.challenge.fallback = $0 }
            ), identifier: "alarm.fallback")
            Text("You can switch to this puzzle anytime during your challenge.")
                .font(.footnote)
                .foregroundStyle(BobTheme.secondaryText)
        }
    }

    private func save() {
        guard !isSaving, !model.isBusy, !needsCode else { return }
        Task {
            isSaving = true
            model.errorMessage = nil
            let saved = await model.saveAlarm(draft)
            isSaving = false
            if saved { onSaved() }
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
            .pickerStyle(.segmented)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Repeat").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                Menu {
                    Button("Once") { days = [] }
                    Button("Every day") { days = Set(1...7) }
                    Button("Weekdays") { days = Set(2...6) }
                    Button("Weekends") { days = [1, 7] }
                } label: {
                    Label(BobCopy.repeatDays(days), systemImage: "chevron.down")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Repeat: \(BobCopy.repeatDays(days))")
                .accessibilityIdentifier("alarm.repeat")
            }
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
                      ? [GridItem(.flexible())]
                      : [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 8) {
                ForEach(BobCopy.orderedWeekdays, id: \.self) { day in
                    let selected = days.contains(day)
                    Button {
                        if selected { days.remove(day) } else { days.insert(day) }
                    } label: {
                        Text(dynamicTypeSize.isAccessibilitySize
                             ? Calendar.current.weekdaySymbols[day - 1]
                             : Calendar.current.shortStandaloneWeekdaySymbols[day - 1])
                            .font(dynamicTypeSize.isAccessibilitySize ? .body : .footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selected ? BobTheme.onGreen : BobTheme.green)
                            .background(selected ? BobTheme.green : BobTheme.field,
                                        in: RoundedRectangle(cornerRadius: BobTheme.controlRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("alarm.weekday.\(day)")
                }
            }
        }
    }
}
