import Foundation

public struct AlarmRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let occurrenceID: UUID
    public let date: Date
    public init(id: UUID, occurrenceID: UUID, date: Date) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.date = date
    }
}

extension BobState {
    /// The recurring primary alarm lives in AlarmKit. Retries are queued for the next seven days,
    /// matching the maximum life of a free Personal Team installation, and refreshed on each launch.
    public mutating func refreshSchedule(at now: Date, calendar: Calendar = .current) {
        guard settings.enabled else { return }
        if settings.weekdays.isEmpty && occurrences.contains(where: { $0.settings.id == settings.id }) { return }
        let horizon = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        var cursor = now
        var upcoming: [Date] = []
        while let wake = settings.nextWake(after: cursor, calendar: calendar), wake <= horizon {
            upcoming.append(wake)
            if settings.weekdays.isEmpty { break }
            cursor = wake
        }
        // Relative wake times follow the current timezone. Retire stale fixed retries on refresh,
        // while keeping past occurrences and identities of unchanged future occurrences.
        occurrences.removeAll { $0.scheduledAt > now && !upcoming.contains($0.scheduledAt) }
        for wake in upcoming where !occurrences.contains(where: { $0.settings.id == settings.id && $0.scheduledAt == wake }) {
            occurrences.append(.init(settings: settings, scheduledAt: wake, plan: plan))
        }
        occurrences.sort { $0.scheduledAt < $1.scheduledAt }
    }

    public func retryRequests(at now: Date) -> [AlarmRequest] {
        occurrences.flatMap { occurrence in
            zip(occurrence.retryIDs, occurrence.retryDates(after: occurrence.scheduledAt.addingTimeInterval(-1))).compactMap { id, date in
                guard date > now else { return nil }
                return AlarmRequest(id: id, occurrenceID: occurrence.id, date: date)
            }
        }
    }
}
