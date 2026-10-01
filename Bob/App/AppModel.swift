import AlarmKit
import BobCore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()
    private var state: BobState
    private let store: JSONStore
    private let alarms = AlarmScheduler()
    private let testing: Bool
    private let usesSystemAlarms: Bool
    private var storageFailed = false
    private var selectedOccurrenceID: UUID?
    private var rehearsal = false
    private var lastRetrySync = Date.distantPast
    private var handledDeadline: UUID?
    private var lastScannedCode: String?
    var morningPresented = false
    var alarmReady = false
    var alarmStatus = "Allow alarms so Bob can wake you while the app is closed."
    var errorMessage: String?
    var isBusy = false
    var settings: AlarmSettings { state.settings }
    var plan: MorningPlan? { state.planForHome(at: Date()) }
    var todayPlan: MorningPlan? { state.planForToday(at: Date()) }
    var planText: String { state.nextPlan(at: Date())?.originalIntent ?? "" }
    var setupComplete: Bool { state.setupComplete }
    var occurrence: MorningOccurrence? {
        if rehearsal { return state.practice }
        return state.occurrences.first { $0.id == selectedOccurrenceID }
    }

    init() {
        #if DEBUG
        testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        usesSystemAlarms = !testing || ProcessInfo.processInfo.arguments.contains("--real-alarms")
        #else
        testing = false
        usesSystemAlarms = true
        #endif
        let root = URL.applicationSupportDirectory.appendingPathComponent(testing ? "BobUITesting" : "Bob", isDirectory: true)
        store = JSONStore(directory: root)
        #if DEBUG
        if testing && ProcessInfo.processInfo.arguments.contains("--reset-state") {
            try? FileManager.default.removeItem(at: root)
        }
        #endif
        do { state = try store.load() }
        catch {
            state = BobState()
            storageFailed = true
            errorMessage = error.localizedDescription
        }
    }

    private func update(_ change: (inout BobState) throws -> Void) throws {
        guard !storageFailed else { throw BobError.corruptStore }
        var candidate = state
        try change(&candidate)
        try store.save(candidate)
        state = candidate
    }

    func refresh() async {
        guard !storageFailed else { return }
        do {
            let now = Date()
            try update { $0.refreshSchedule(at: now) }
            selectCurrentMorning(at: now)
            await syncAlarms()
        } catch { errorMessage = error.localizedDescription }
    }

    func tick() async {
        guard !storageFailed else { return }
        let now = Date()
        selectCurrentMorning(at: now)
        if let current = occurrence, !rehearsal, usesSystemAlarms, now >= current.audibleDeadline, handledDeadline != current.id {
            do {
                try await alarms.silence(current)
                await syncAlarms()
                handledDeadline = current.id
            } catch { errorMessage = "The retry window ended, but Bob could not stop the system alert. \(error.localizedDescription)" }
        }
    }

    private func selectCurrentMorning(at now: Date) {
        guard !rehearsal else { return }
        let newest = state.occurrences.filter { $0.scheduledAt <= now }.max { $0.scheduledAt < $1.scheduledAt }
        if let newest, newest.id != selectedOccurrenceID {
            selectedOccurrenceID = newest.id
            morningPresented = !newest.isComplete
            lastScannedCode = nil
        }
    }

    func requestAlarmPermission() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            if usesSystemAlarms { _ = try await AlarmManager.shared.requestAuthorization() }
            await syncAlarms()
        } catch { errorMessage = error.localizedDescription; alarmReady = false }
    }

    func saveAlarm(_ value: AlarmSettings) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            let now = Date()
            if let active = state.occurrences.last(where: { $0.scheduledAt <= now && !$0.isComplete && now < $0.audibleDeadline }) {
                throw BobError.invalidSettings("Finish this morning's challenge or wait until \(active.audibleDeadline.formatted(date: .omitted, time: .shortened)) before changing the alarm.")
            }
            try value.validate()
            var newSettings = value
            newSettings.id = UUID()
            try update { state in
                state.settings = newSettings
                state.setupComplete = true
                state.occurrences.removeAll { $0.scheduledAt > now }
                state.refreshSchedule(at: now)
            }
            if value.enabled && usesSystemAlarms && AlarmManager.shared.authorizationState == .notDetermined {
                _ = try await AlarmManager.shared.requestAuthorization()
            }
            await syncAlarms()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func deleteAlarm() async {
        var off = settings
        off.enabled = false
        _ = await saveAlarm(off)
    }

    func savePlan(_ text: String) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try update { try $0.savePlan(text, at: Date()) }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func changeMorning(_ change: (inout MorningOccurrence) throws -> Void) throws {
        try update { state in
            if rehearsal {
                guard var practice = state.practice else { return }
                try change(&practice)
                state.practice = practice
            } else if let index = state.occurrences.firstIndex(where: { $0.id == selectedOccurrenceID }) {
                try change(&state.occurrences[index])
            }
        }
    }

    func beginChallenge() async {
        do {
            try changeMorning { $0.beginChallenge(at: Date()) }
            await silence()
        } catch { errorMessage = error.localizedDescription }
    }

    func silence() async {
        do {
            try changeMorning { $0.silence(at: Date()) }
            if let occurrence, !rehearsal, usesSystemAlarms { try await alarms.silence(occurrence) }
            if !rehearsal { await syncAlarms() }
        } catch { errorMessage = error.localizedDescription }
    }

    func submitAnswer(_ answer: String) async -> Bool {
        var accepted = false
        do {
            try changeMorning { accepted = $0.submitAnswer(answer, at: Date()) }
            if accepted { errorMessage = nil }
            await afterChallengeChange()
        } catch { errorMessage = error.localizedDescription }
        return accepted
    }

    func scanCode(_ code: String) async {
        guard code != lastScannedCode else { return }
        lastScannedCode = code
        do {
            var accepted = false
            try changeMorning { accepted = $0.scanCode(code, at: Date()) }
            if accepted { errorMessage = nil; await afterChallengeChange() }
            else { errorMessage = "That is a different code. Scan the code registered for this alarm, or use your puzzle fallback." }
        } catch { errorMessage = error.localizedDescription }
    }

    func acceptActivity(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        do {
            let previousRetry = occurrence?.retryDates(after: Date()).first
            try changeMorning { try $0.acceptActivity(seconds, at: Date()) }
            // A near retry is suppressed immediately. Otherwise the two-minute cushion allows
            // batching native scheduler updates while every accepted segment is persisted.
            if occurrence?.isComplete == true || Date().timeIntervalSince(lastRetrySync) >= 5 || (previousRetry?.timeIntervalSinceNow ?? 120) < 6 {
                if let current = occurrence, !rehearsal, usesSystemAlarms { try await alarms.silence(current) }
                await afterChallengeChange()
                lastRetrySync = Date()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func useFallback() async {
        do {
            try changeMorning { try $0.useFallback(at: Date(), puzzle: testing ? Self.testPuzzle : nil) }
            errorMessage = nil
            await silence()
        } catch { errorMessage = error.localizedDescription }
    }

    private func afterChallengeChange() async {
        guard !rehearsal else { return }
        if let current = occurrence, current.isComplete, usesSystemAlarms {
            do { try await alarms.silence(current) }
            catch { errorMessage = "Challenge complete, but stopping the system alarm failed. \(error.localizedDescription)" }
        }
        await syncAlarms()
    }

    func dismissMorning() {
        morningPresented = false
        if rehearsal {
            rehearsal = false
            do { try update { $0.practice = nil } }
            catch { errorMessage = error.localizedDescription }
        }
    }

    #if DEBUG
    func startPreviewMorning() async {
        do {
            var selected = settings
            if selected.challenge.kind != .puzzle && selected.challenge.fallback == nil { selected.challenge.fallback = .easy }
            try update { $0.practice = MorningOccurrence(settings: selected, scheduledAt: Date().addingTimeInterval(-2), plan: $0.nextPlan(at: Date()), puzzle: testing ? Self.testPuzzle : nil) }
            rehearsal = true
            morningPresented = true
            lastScannedCode = nil
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    #endif

    private static var testPuzzle: PuzzleProgress { .init(problems: [.init(left: 8, right: 5, operation: .add)]) }

    private func syncAlarms() async {
        guard !storageFailed else { return }
        if !usesSystemAlarms {
            alarmReady = true
            alarmStatus = settings.enabled ? "Ready for simulator rehearsal" : "Alarm is off"
            return
        }
        guard AlarmManager.shared.authorizationState == .authorized else {
            alarmReady = false
            alarmStatus = "Alarm permission is missing. Bob cannot schedule your wake-up alarm."
            return
        }
        do {
            try await alarms.reconcile(state)
            alarmReady = true
            if !settings.enabled { alarmStatus = "Alarm is off" }
            else if let through = state.occurrences.last?.scheduledAt {
                alarmStatus = "Alarm ready. Retries queued through \(through.formatted(.dateTime.month(.abbreviated).day()))."
            } else { alarmStatus = "This one-time alarm has finished. Set another when you're ready." }
        } catch {
            alarmReady = false
            alarmStatus = "Alarm setup is incomplete. \(error.localizedDescription)"
            errorMessage = alarmStatus
        }
    }

    /// Called by AlarmKit's stop/custom AppIntent, including when the app was not running.
    func handleAlarmAction(occurrenceID: UUID?, open: Bool) async {
        do {
            try update { $0.refreshSchedule(at: Date()) }
            rehearsal = false
            selectCurrentMorning(at: Date())
            if let occurrenceID, state.occurrences.contains(where: { $0.id == occurrenceID }) { selectedOccurrenceID = occurrenceID }
            await silence()
            if open { morningPresented = true }
        } catch { errorMessage = error.localizedDescription }
    }
}
