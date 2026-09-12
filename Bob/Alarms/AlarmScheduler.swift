import AlarmKit
import AppIntents
import BobCore
import Foundation
import SwiftUI

struct BobAlarmMetadata: AlarmMetadata {}

/// A small adapter around AlarmKit. Fixed retries are scheduled ahead of time, never by
/// assuming that an application timer will execute while iOS suspends the process.
@MainActor
final class AlarmScheduler {
    private var queued: Task<Void, Error>?

    func reconcile(_ state: BobState) async throws {
        let previous = queued
        let work = Task { @MainActor in
            _ = try? await previous?.value
            try await self.apply(state, now: Date())
        }
        queued = work
        try await work.value
    }

    func silence(_ occurrence: MorningOccurrence) async throws {
        let previous = queued
        let work = Task { @MainActor in
            _ = try? await previous?.value
            let ids = Set(occurrence.retryIDs + [occurrence.settings.id])
            for alarm in try AlarmManager.shared.alarms where ids.contains(alarm.id) && alarm.state == .alerting {
                try AlarmManager.shared.stop(id: alarm.id)
            }
            if occurrence.isComplete || Date() >= occurrence.audibleDeadline {
                for alarm in try AlarmManager.shared.alarms where occurrence.retryIDs.contains(alarm.id) {
                    try AlarmManager.shared.cancel(id: alarm.id)
                }
            }
        }
        queued = work
        try await work.value
    }

    private func apply(_ state: BobState, now: Date) async throws {
        let manager = AlarmManager.shared
        let requests = state.retryRequests(at: now)
        let live = try manager.alarms
        let oneShot = state.settings.weekdays.isEmpty
        let firstFuture = state.occurrences.first { $0.settings.id == state.settings.id && $0.scheduledAt > now }
        let primaryNeeded = state.settings.enabled && (!oneShot || firstFuture != nil)
        var desired = Set(requests.map(\.id))
        if primaryNeeded { desired.insert(state.settings.id) }

        // Keep a currently sounding occurrence until silence, completion, or its deadline.
        for occurrence in state.occurrences where !occurrence.isComplete && occurrence.scheduledAt <= now && now < occurrence.audibleDeadline {
            let ids = Set(occurrence.retryIDs + [occurrence.settings.id])
            for alarm in live where ids.contains(alarm.id) && alarm.state == .alerting { desired.insert(alarm.id) }
        }
        for alarm in live where !desired.contains(alarm.id) { try manager.cancel(id: alarm.id) }

        if primaryNeeded {
            let schedule: Alarm.Schedule
            if oneShot, let firstFuture { schedule = .fixed(firstFuture.scheduledAt) }
            else {
                let days: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
                schedule = .relative(.init(time: .init(hour: state.settings.hour, minute: state.settings.minute),
                                           repeats: .weekly(state.settings.weekdays.sorted().map { days[$0 - 1] })))
            }
            let existing = live.first { $0.id == state.settings.id }
            if existing?.schedule != schedule {
                _ = try await manager.schedule(id: state.settings.id, configuration: configuration(schedule: schedule, occurrenceID: nil))
            }
        }

        for request in requests {
            // Activity may have consumed part of this task's scheduling window while we awaited iOS.
            guard request.date > Date() else { continue }
            let existing = live.first { $0.id == request.id }
            if existing?.schedule == .fixed(request.date) { continue }
            _ = try await manager.schedule(id: request.id, configuration: configuration(schedule: .fixed(request.date), occurrenceID: request.occurrenceID))
        }
    }

    nonisolated private func configuration(schedule: Alarm.Schedule, occurrenceID: UUID?) -> sending AlarmManager.AlarmConfiguration<BobAlarmMetadata> {
        let open = AlarmButton(text: "Open Bob", textColor: .white, systemImageName: "sun.max")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = .init(title: "Your morning with Bob", secondaryButton: open, secondaryButtonBehavior: .custom)
        } else {
            alert = .init(title: "Your morning with Bob", stopButton: .init(text: "Silence", textColor: .white, systemImageName: "speaker.slash"),
                          secondaryButton: open, secondaryButtonBehavior: .custom)
        }
        return .alarm(schedule: schedule,
                      attributes: .init(presentation: .init(alert: alert), metadata: BobAlarmMetadata(), tintColor: Color(red: 0.25, green: 0.45, blue: 0.33)),
                      stopIntent: SilenceBobAlarm(occurrenceID: occurrenceID?.uuidString ?? ""),
                      secondaryIntent: OpenBobAlarm(occurrenceID: occurrenceID?.uuidString ?? ""))
    }
}

struct SilenceBobAlarm: LiveActivityIntent {
    static var title: LocalizedStringResource { "Silence Bob" }
    static var description: IntentDescription { "Silence this alarm without completing your morning challenge." }
    @Parameter(title: "Morning") var occurrenceID: String
    init() { occurrenceID = "" }
    init(occurrenceID: String) { self.occurrenceID = occurrenceID }
    @MainActor func perform() async throws -> some IntentResult {
        await AppModel.shared.handleAlarmAction(occurrenceID: UUID(uuidString: occurrenceID), open: false)
        return .result()
    }
}

struct OpenBobAlarm: LiveActivityIntent {
    static var title: LocalizedStringResource { "Open Bob" }
    static var openAppWhenRun: Bool { true }
    @Parameter(title: "Morning") var occurrenceID: String
    init() { occurrenceID = "" }
    init(occurrenceID: String) { self.occurrenceID = occurrenceID }
    @MainActor func perform() async throws -> some IntentResult {
        await AppModel.shared.handleAlarmAction(occurrenceID: UUID(uuidString: occurrenceID), open: true)
        return .result()
    }
}
