import SwiftUI
import BobCore

struct HomeView: View {
    let model: AppModel
    let onSettings: () -> Void
    let onPrepare: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                greeting
                ModelErrorView(model: model)
                alarmPanel
                if !model.alarmReady {
                    BobPanel { AlarmReadinessView(model: model) }
                }
                if let occurrence = model.occurrence, !occurrence.isComplete {
                    BobPanel {
                        BobNotice(title: "A morning is still open",
                                  message: "Your challenge from \(occurrence.scheduledAt.formatted(date: .abbreviated, time: .shortened)) is incomplete.",
                                  symbol: "sun.max")
                        Button("Return to challenge") { model.morningPresented = true }
                            .buttonStyle(BobButtonStyle(secondary: true))
                            .accessibilityIdentifier("home.resume")
                    }
                }
                if let plan = model.plan {
                    PlanCard(plan: plan)
                } else {
                    BobPanel {
                        BobNotice(title: "Tomorrow has some room",
                                  message: "Leave a few things you want to begin. Your alarm and challenge also work without a plan.",
                                  symbol: "moon")
                    }
                }
                Button(action: onPrepare) {
                    Label("Prepare for the night", systemImage: "moon")
                }
                .buttonStyle(BobButtonStyle())
                .accessibilityIdentifier("home.prepare")
                Text("A short plan. Then some quiet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                #if DEBUG
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        Task { await model.startPreviewMorning() }
                    } label: {
                        Label("Try a morning", systemImage: "sun.horizon")
                            .frame(minHeight: 44)
                    }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("home.rehearsal")
                    Text("Rehearsal using your selected challenge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                #endif
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .bobScreen()
        .navigationTitle("Bob")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onSettings) {
                    Image(systemName: "slider.horizontal.3").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Alarm settings")
                .accessibilityIdentifier("home.settings")
            }
        }
    }

    @ViewBuilder private var greeting: some View {
        let words = VStack(alignment: .leading, spacing: 8) {
            Text("A little less\nto carry.")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Bob can hold the morning plan.")
                .foregroundStyle(.secondary)
        }
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                BobPortrait(size: 100)
                words
            }
        } else {
            HStack(alignment: .center, spacing: 8) {
                words.frame(maxWidth: .infinity, alignment: .leading)
                BobPortrait(size: 116)
            }
        }
    }

    private var alarmPanel: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let oneTimeUsed = model.settings.weekdays.isEmpty
                && model.occurrence?.settings.id == model.settings.id
                && (model.occurrence?.scheduledAt ?? .distantFuture) <= context.date
            BobPanel {
                Label(!model.settings.enabled ? "Alarm is off" : (oneTimeUsed ? "Your one-time alarm" : "Next wake-up"), systemImage: "alarm")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(BobCopy.time(model.settings), format: .dateTime.hour().minute())
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .accessibilityLabel("Wake-up time")
                    .accessibilityValue(BobCopy.time(model.settings).formatted(date: .omitted, time: .shortened))
                if oneTimeUsed && model.settings.enabled {
                    Text("This one-time alarm's scheduled time has passed. Set a new alarm when you're ready.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let next = model.settings.nextWake(after: context.date) {
                    Text("\(next.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) · \(BobCopy.repeatDays(model.settings.weekdays))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Turn it on in alarm settings when you're ready.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Divider()
                Label(BobCopy.challenge(model.settings.challenge.kind),
                      systemImage: BobCopy.symbol(model.settings.challenge.kind))
                    .font(.headline)
                Text(BobCopy.challengeDetail(model.settings.challenge))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if model.alarmReady && !oneTimeUsed {
                    Label(model.alarmStatus, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(BobTheme.green)
                        .accessibilityIdentifier("alarm.readiness")
                }
            }
        }
    }
}

struct AlarmReadinessView: View {
    let model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BobNotice(title: model.alarmReady ? "Alarm readiness" : "Check alarm readiness",
                      message: model.alarmStatus,
                      symbol: model.alarmReady ? "checkmark.circle" : "bell.badge")
                .accessibilityIdentifier("alarm.readiness")
            if !model.alarmReady {
                Button {
                    Task { await model.requestAlarmPermission() }
                } label: {
                    Text(model.isBusy ? "Checking…" : "Enable alarms").frame(minHeight: 44)
                }
                .disabled(model.isBusy)
                .accessibilityIdentifier("alarm.permission")
                Button("Open iPhone settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .frame(minHeight: 44)
                Text("If permission was denied, allow alarms in Settings. A puzzle fallback cannot fix alarm permission.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
