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
}
