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

    public mutating func confirmPlan(steps: [String], reason: String, at now: Date) throws {
        let cleanSteps = steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleanSteps.isEmpty else { throw BobError.invalidPlan }
        let source = conversation.filter { $0.role == .user }.map(\.text).joined(separator: "\n")
        let confirmed = MorningPlan(originalIntent: source.isEmpty ? cleanSteps.joined(separator: "\n") : source,
                                    steps: cleanSteps, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                                    confirmedAt: now, conversation: conversation)
        plan = confirmed
        occurrences = occurrences.map { occurrence in
            guard occurrence.scheduledAt > now else { return occurrence }
            return occurrence.replacingPlan(confirmed)
        }
        conversation = []
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
