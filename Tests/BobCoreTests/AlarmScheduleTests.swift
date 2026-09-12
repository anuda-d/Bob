import Foundation
import Testing
@testable import BobCore

@Suite struct AlarmScheduleTests {
    @Test func daylightSavingGapMovesToNextValidLocalTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let before = try #require(ISO8601DateFormatter().date(from: "2026-03-08T05:00:00Z"))
        let settings = AlarmSettings(hour: 2, minute: 30, enabled: true)
        let next = try #require(settings.nextWake(after: before, calendar: calendar))
        #expect(next == ISO8601DateFormatter().date(from: "2026-03-08T07:00:00Z"))
    }

    @Test func invalidConfigurationIsRejectedBeforeScheduling() {
        let qr = AlarmSettings(enabled: true, challenge: .init(kind: .qr, fallback: .easy))
        #expect(throws: BobError.invalidSettings("Register a QR code before saving this alarm.")) { try qr.validate() }
        let missingFallback = AlarmSettings(enabled: true, challenge: .init(kind: .pushups))
        #expect(throws: BobError.invalidSettings("Choose a puzzle fallback for this challenge.")) { try missingFallback.validate() }
    }
    @Test func repeatingAlarmSkipsUnselectedDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fridayEvening = Date(timeIntervalSince1970: 1_789_171_200) // Friday 2026-09-11 00:00 UTC
        let settings = AlarmSettings(hour: 7, weekdays: [2], enabled: true)
        let next = try #require(settings.nextWake(after: fridayEvening, calendar: calendar))
        #expect(calendar.component(.weekday, from: next) == 2)
        #expect(calendar.component(.hour, from: next) == 7)
        #expect(next > fridayEvening)
    }
}
