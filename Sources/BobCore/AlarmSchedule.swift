import Foundation

extension AlarmSettings {
    public func validate() throws {
        guard (0...23).contains(hour), (0...59).contains(minute), weekdays.isSubset(of: Set(1...7)) else {
            throw BobError.invalidSettings("Choose a valid wake-up time and repeating days.")
        }
        if challenge.kind != .puzzle && challenge.fallback == nil {
            throw BobError.invalidSettings("Choose a puzzle fallback for this challenge.")
        }
        if challenge.kind == .qr && (challenge.qrCode?.isEmpty != false) {
            throw BobError.invalidSettings("Register a QR code before saving this alarm.")
        }
    }

    public func nextWake(after date: Date, calendar: Calendar = .current) -> Date? {
        guard enabled, (try? validate()) != nil else { return nil }
        let days: [Int?] = weekdays.isEmpty ? [nil] : weekdays.sorted().map { $0 }
        return days.compactMap { weekday -> Date? in
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.second = 0
            components.weekday = weekday
            return calendar.nextDate(after: date, matching: components,
                                     matchingPolicy: .nextTime, repeatedTimePolicy: .first)
        }.min()
    }
}
