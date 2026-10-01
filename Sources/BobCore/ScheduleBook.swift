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
        if settings.weekdays.isEmpty,
           let existing = occurrences.filter({ $0.settings.id == settings.id })
            .max(by: { $0.scheduledAt < $1.scheduledAt }),
           existing.settings == settings {
            return
        }
        let queuedPlan = plan ?? occurrences.filter { $0.scheduledAt > now && $0.plan != nil }
            .min { $0.scheduledAt < $1.scheduledAt }?.plan
        let planWasUsed = queuedPlan.map { currentPlan in
            occurrences.contains { $0.scheduledAt <= now && $0.plan?.id == currentPlan.id }
        } ?? false
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
        occurrences.removeAll {
            $0.scheduledAt > now && ($0.settings.id != settings.id || !upcoming.contains($0.scheduledAt))
        }
        for wake in upcoming where !occurrences.contains(where: { $0.settings.id == settings.id && $0.scheduledAt == wake }) {
            occurrences.append(.init(settings: settings, scheduledAt: wake))
        }
        let nextWake = upcoming.first
        occurrences = occurrences.map { occurrence in
            guard occurrence.scheduledAt > now else { return occurrence }
            let isCurrentNextWake = occurrence.settings.id == settings.id && occurrence.scheduledAt == nextWake
            let assignedPlan = !planWasUsed && isCurrentNextWake ? queuedPlan : nil
            return occurrence.replacingPlan(assignedPlan)
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
