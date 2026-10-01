import SwiftUI
import BobCore

struct HomeView: View {
    let model: AppModel
    let onSettings: () -> Void
    let onPrepare: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 48
    @ScaledMetric(relativeTo: .title2) private var challengeIconWidth = 28

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                alarmHeader
                VStack(alignment: .leading, spacing: 28) {
                    ModelErrorView(model: model)
                    challengeSummary
                    if !model.alarmReady {
                        BobSection { AlarmReadinessView(model: model) }
                    }
                    if let occurrence = model.occurrence, !occurrence.isComplete {
                        BobSection {
                            BobNotice(title: "A morning is still open",
                                      message: "Your challenge from \(occurrence.scheduledAt.formatted(date: .abbreviated, time: .shortened)) is incomplete.",
                                      symbol: "sun.max")
                            Button("Return to challenge") { model.morningPresented = true }
                                .buttonStyle(BobButtonStyle(secondary: true))
                            .accessibilityIdentifier("home.resume")
                        }
                    }
                    Divider()
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        VStack(alignment: .leading, spacing: 28) {
                            if let plan = model.plan {
                                let today = model.todayPlan
                                PlanCard(plan: plan, title: today?.id == plan.id ? "Today's goals" : "Your morning plan")
                                if let today, today.id != plan.id {
                                    Divider()
                                    PlanCard(plan: today, title: "Today's goals")
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("No morning plan yet")
                                        .font(.title3.weight(.semibold))
                                    Text("Add your goals whenever you're ready. Your alarm works without a plan.")
                                        .foregroundStyle(BobTheme.secondaryText)
                                }
                            }
                        }
                    }
                    Button(action: onPrepare) {
                        Label("Plan my morning", systemImage: "moon")
                    }
                    .buttonStyle(BobButtonStyle())
                    .accessibilityIdentifier("home.prepare")
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
                            .foregroundStyle(BobTheme.secondaryText)
                    }
                    .padding(.top, 8)
                    #endif
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .bobScreen()
        .navigationTitle("Bob")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BobTheme.header, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    private var alarmHeader: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let oneTimeUsed = model.settings.weekdays.isEmpty
                && model.occurrence?.settings.id == model.settings.id
                && (model.occurrence?.scheduledAt ?? .distantFuture) <= context.date
            let alarm = VStack(alignment: .leading, spacing: 12) {
                Label(!model.settings.enabled ? "Alarm is off"
                      : (oneTimeUsed ? "Your one-time alarm" : (model.alarmReady ? "Next wake-up" : "Alarm needs attention")), systemImage: "alarm")
                    .font(.subheadline.weight(.semibold))
                Text(BobCopy.time(model.settings), format: .dateTime.hour().minute())
                    .font(.system(size: timeSize, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel("Wake-up time")
                    .accessibilityValue(BobCopy.time(model.settings).formatted(date: .omitted, time: .shortened))
                    .accessibilityHint(model.settings.enabled && !oneTimeUsed ? model.alarmStatus : "")
                    .accessibilityIdentifier("home.wakeTime")
                if oneTimeUsed && model.settings.enabled {
                    Text("This one-time alarm's scheduled time has passed. Set a new alarm when you're ready.")
                        .font(.subheadline)
                } else if let next = model.settings.nextWake(after: context.date) {
                    Text("\(next.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) · \(BobCopy.repeatDays(model.settings.weekdays))")
                        .font(.subheadline)
                } else {
                    Text("Turn it on in alarm settings when you're ready.")
                        .font(.subheadline)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Group {
                if dynamicTypeSize >= .xxLarge {
                    VStack(alignment: .leading, spacing: 20) {
                        alarm
                        BobPortrait(size: 150)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(y: 4)
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        alarm
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 28)
                        BobPortrait(size: 154)
                            .offset(y: 4)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
            .foregroundStyle(BobTheme.onHeader)
            .background(BobTheme.header.ignoresSafeArea(edges: .top))
        }
    }

    private var challengeSummary: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: BobCopy.symbol(model.settings.challenge.kind))
                .font(.title2)
                .frame(width: challengeIconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(BobCopy.challenge(model.settings.challenge.kind))
                    .font(.headline)
                Text(BobCopy.challengeDetail(model.settings.challenge))
                    .font(.subheadline)
                    .foregroundStyle(BobTheme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
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
                    .foregroundStyle(BobTheme.secondaryText)
            }
        }
    }
}
