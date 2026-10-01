import Foundation

public struct BobState: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var settings = AlarmSettings()
    public var plan: MorningPlan?
    public var conversation: [ConversationMessage] = []
    public var occurrences: [MorningOccurrence] = []
    public var practice: MorningOccurrence?
    public var setupComplete = false
    public init() {}

    /// Saves the user's plan verbatim and assigns it to the next future alarm occurrence only.
    public mutating func savePlan(_ text: String, at now: Date) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw BobError.invalidPlan }
        let saved = MorningPlan(originalIntent: text, steps: [text], confirmedAt: now)
        plan = saved
        assignToNextOccurrence(saved, at: now)
    }

    /// Returns the plan on the next future occurrence, or an unconsumed saved plan when
    /// no occurrence is scheduled yet (for example, while the alarm is disabled).
    public func nextPlan(at now: Date) -> MorningPlan? {
        let scheduled = settings.enabled ? occurrences
            .filter { $0.settings.id == settings.id && $0.scheduledAt > now }
            .min { $0.scheduledAt < $1.scheduledAt }?
            .plan : nil
        if let scheduled { return scheduled }
        return savedPlanIsUnconsumed(at: now) ? plan : nil
    }

    /// Returns the upcoming plan, or today's plan after its alarm has fired.
    public func planForHome(at now: Date, calendar: Calendar = .current) -> MorningPlan? {
        if settings.enabled,
           let upcoming = occurrences
            .filter({ $0.settings.id == settings.id && $0.scheduledAt > now && $0.plan != nil })
            .min(by: { $0.scheduledAt < $1.scheduledAt })?.plan {
            return upcoming
        }
        if savedPlanIsUnconsumed(at: now), let plan { return plan }
        return planForToday(at: now, calendar: calendar)
    }

    /// Returns the plan for an alarm that fired earlier on the current local calendar day.
    public func planForToday(at now: Date, calendar: Calendar = .current) -> MorningPlan? {
        occurrences
            .filter { $0.scheduledAt <= now && $0.plan != nil && calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .max { $0.scheduledAt < $1.scheduledAt }?
            .plan
    }

    private func savedPlanIsUnconsumed(at now: Date) -> Bool {
        guard let plan else { return false }
        return !occurrences.contains { $0.scheduledAt <= now && $0.plan?.id == plan.id }
    }

    /// Legacy structured confirmation remains decodable and callable by older clients.
    /// It now assigns the accepted result to one future occurrence, matching the current flow.
    public mutating func confirmPlan(steps: [String], reason: String, at now: Date) throws {
        let cleanSteps = steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleanSteps.isEmpty else { throw BobError.invalidPlan }
        let source = conversation.filter { $0.role == .user }.map(\.text).joined(separator: "\n")
        let confirmed = MorningPlan(originalIntent: source.isEmpty ? cleanSteps.joined(separator: "\n") : source,
                                    steps: cleanSteps, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                                    confirmedAt: now, conversation: conversation)
        assignToNextOccurrence(confirmed, at: now)
        conversation = []
    }

    private mutating func assignToNextOccurrence(_ replacement: MorningPlan, at now: Date) {
        plan = replacement
        let nextID = settings.enabled ? occurrences
            .filter { $0.settings.id == settings.id && $0.scheduledAt > now }
            .min { $0.scheduledAt < $1.scheduledAt }?
            .id : nil
        occurrences = occurrences.map { occurrence in
            guard occurrence.scheduledAt > now else { return occurrence }
            return occurrence.replacingPlan(occurrence.id == nextID ? replacement : nil)
        }
    }
}

public struct JSONStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func load() throws -> BobState {
        let file = directory.appendingPathComponent("bob.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return BobState() }
        let data = try Data(contentsOf: file)
        do {
            let state = try JSONDecoder().decode(BobState.self, from: data)
            guard state.schemaVersion == 1 else { throw BobError.corruptStore }
            return state
        } catch { throw BobError.corruptStore }
    }
    public func save(_ state: BobState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("bob.json")
        let data = try JSONEncoder().encode(state)
        #if os(iOS)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: file, options: .atomic)
        #endif
        var protectedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedDirectory.setResourceValues(values)
    }
}
