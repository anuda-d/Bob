import Foundation
import Testing
import BobCore

@Suite struct ScheduleBookTests {
    @Test func timezoneChangeReplacesFutureRetriesWithoutDuplicatingWakeUps() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(ISO8601DateFormatter().date(from: "2026-09-12T04:00:00Z"))
        var state = BobState()
        state.settings = .init(hour: 7, weekdays: Set(1...7), enabled: true)
        state.refreshSchedule(at: now, calendar: calendar)
        let oldRetryIDs = Set(state.retryRequests(at: now).map(\.id))
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        state.refreshSchedule(at: now, calendar: calendar)
        #expect(state.occurrences.count == 7)
        #expect(state.occurrences.first?.scheduledAt == ISO8601DateFormatter().date(from: "2026-09-12T05:00:00Z"))
        #expect(oldRetryIDs.isDisjoint(with: state.retryRequests(at: now).map(\.id)))
    }
    @Test func oneTimeAlarmDoesNotSilentlyBecomeADailyAlarm() {
        let wake = Date(timeIntervalSince1970: 1_800_000_000)
        var state = BobState()
        state.settings = .init(hour: 7, enabled: true)
        state.occurrences = [.init(settings: state.settings, scheduledAt: wake)]
        state.refreshSchedule(at: wake.addingTimeInterval(3_600))
        #expect(state.occurrences.count == 1)
    }
    @Test func timePassingDoesNotMoveOrRecreateAlreadyScheduledRetries() {
        let wake = Date(timeIntervalSince1970: 1_800_000_000)
        var state = BobState()
        state.occurrences = [.init(settings: .init(), scheduledAt: wake)]
        let before = state.retryRequests(at: wake)
        let later = state.retryRequests(at: wake.addingTimeInterval(125))
        #expect(later == Array(before.dropFirst()))
    }
    @Test func scheduledRetriesAreBoundedAndCompletedOccurrenceHasNone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(ISO8601DateFormatter().date(from: "2026-09-12T06:00:00Z"))
        var state = BobState()
        state.settings = .init(hour: 7, weekdays: Set(1...7), enabled: true)
        state.refreshSchedule(at: now, calendar: calendar)
        #expect(state.occurrences.count == 7)
        let requests = state.retryRequests(at: now)
        #expect(requests.count == 49)
        let first = try #require(state.occurrences.first)
        #expect(requests.filter { $0.occurrenceID == first.id }.allSatisfy { $0.date < first.audibleDeadline })
        #expect(Set(requests.map(\.id)).count == requests.count)
        state.refreshSchedule(at: now, calendar: calendar)
        #expect(state.retryRequests(at: now) == requests)
    }

    @Test func recurringScheduleKeepsAPlanOnOnlyItsNextWake() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(ISO8601DateFormatter().date(from: "2026-09-12T04:00:00Z"))
        var state = BobState()
        state.settings = .init(hour: 7, weekdays: Set(1...7), enabled: true)
        state.refreshSchedule(at: now, calendar: calendar)
        try state.savePlan("Get outside", at: now)

        #expect(state.occurrences.count == 7)
        #expect(state.occurrences.filter { $0.plan != nil }.count == 1)
        #expect(state.nextPlan(at: now)?.originalIntent == "Get outside")
    }

    @Test func homeKeepsTodaysPlanAfterAlarmAndChallengeAndDropsItNextDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = ISO8601DateFormatter()
        let wake = try #require(formatter.date(from: "2026-09-12T07:00:00Z"))
        var state = BobState()
        state.settings = .init(hour: 7, weekdays: Set(1...7), enabled: true)
        state.refreshSchedule(at: wake.addingTimeInterval(-3_600), calendar: calendar)
        try state.savePlan("Read and stretch", at: wake.addingTimeInterval(-3_600))
        let firstID = try #require(state.occurrences.first?.id)
        #expect(state.planForHome(at: wake.addingTimeInterval(-30), calendar: calendar)?.originalIntent == "Read and stretch")

        #expect(state.planForHome(at: wake.addingTimeInterval(3_600), calendar: calendar)?.originalIntent == "Read and stretch")
        #expect(state.nextPlan(at: wake.addingTimeInterval(3_600)) == nil)
        #expect(state.occurrences.first?.id == firstID)
        try state.savePlan("Tomorrow's priorities", at: wake.addingTimeInterval(3_600))
        #expect(state.planForToday(at: wake.addingTimeInterval(3_600), calendar: calendar)?.originalIntent == "Read and stretch")
        #expect(state.planForHome(at: wake.addingTimeInterval(3_600), calendar: calendar)?.originalIntent == "Tomorrow's priorities")
        #expect(state.planForHome(at: wake.addingTimeInterval(86_400), calendar: calendar)?.originalIntent == "Tomorrow's priorities")

        try state.savePlan("New day, new plan", at: wake.addingTimeInterval(86_400))
        state.refreshSchedule(at: wake.addingTimeInterval(86_400), calendar: calendar)
        #expect(state.nextPlan(at: wake.addingTimeInterval(86_400))?.originalIntent == "New day, new plan")
        #expect(state.occurrences.filter { $0.scheduledAt > wake.addingTimeInterval(86_400) && $0.plan != nil }.count == 1)
    }

    @Test func refreshingAfterWakeDoesNotCarryTheConsumedPlanToTomorrow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let wake = try #require(ISO8601DateFormatter().date(from: "2026-09-12T07:00:00Z"))
        var state = BobState()
        state.settings = .init(hour: 7, weekdays: Set(1...7), enabled: true)
        state.refreshSchedule(at: wake.addingTimeInterval(-3_600), calendar: calendar)
        try state.savePlan("Today's goals", at: wake.addingTimeInterval(-3_600))

        let afterWake = wake.addingTimeInterval(60)
        state.refreshSchedule(at: afterWake, calendar: calendar)

        #expect(state.planForHome(at: afterWake, calendar: calendar)?.originalIntent == "Today's goals")
        #expect(state.planForToday(at: afterWake, calendar: calendar)?.originalIntent == "Today's goals")
        #expect(state.nextPlan(at: afterWake) == nil)
        #expect(state.occurrences.filter { $0.scheduledAt > afterWake && $0.plan != nil }.isEmpty)
        #expect(state.planForHome(at: afterWake.addingTimeInterval(86_400), calendar: calendar) == nil)
    }

    @Test func alarmTimeChangeMovesAnUnconsumedPlanToTheNewNextOccurrence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(ISO8601DateFormatter().date(from: "2026-09-12T04:00:00Z"))
        var state = BobState()
        state.settings = .init(hour: 7, weekdays: Set(1...7), enabled: true)
        state.refreshSchedule(at: now, calendar: calendar)
        try state.savePlan("Journal", at: now)
        state.settings.hour = 8

        state.refreshSchedule(at: now, calendar: calendar)

        #expect(state.occurrences.first?.scheduledAt == ISO8601DateFormatter().date(from: "2026-09-12T08:00:00Z"))
        #expect(state.nextPlan(at: now)?.originalIntent == "Journal")
        #expect(state.occurrences.filter { $0.plan != nil }.count == 1)
    }
}
