import Foundation

public enum PuzzleDifficulty: String, Codable, CaseIterable, Sendable {
    case easy, hard
}

public enum ChallengeKind: String, Codable, CaseIterable, Sendable {
    case pushups, puzzle, qr
}

public struct ChallengeConfiguration: Codable, Equatable, Sendable {
    public var kind: ChallengeKind
    public var difficulty: PuzzleDifficulty
    public var qrCode: String?
    public var fallback: PuzzleDifficulty?

    public init(kind: ChallengeKind = .puzzle, difficulty: PuzzleDifficulty = .easy,
                qrCode: String? = nil, fallback: PuzzleDifficulty? = nil) {
        self.kind = kind
        self.difficulty = difficulty
        self.qrCode = qrCode
        self.fallback = fallback
    }
}

public struct AlarmSettings: Codable, Equatable, Sendable {
    public var id: UUID
    public var hour: Int
    public var minute: Int
    /// Calendar weekdays: Sunday = 1, Saturday = 7. Empty means one occurrence.
    public var weekdays: Set<Int>
    public var enabled: Bool
    public var challenge: ChallengeConfiguration

    public init(id: UUID = UUID(), hour: Int = 7, minute: Int = 0,
                weekdays: Set<Int> = [], enabled: Bool = false,
                challenge: ChallengeConfiguration = .init()) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.enabled = enabled
        self.challenge = challenge
    }
}

public struct ConversationMessage: Codable, Equatable, Identifiable, Sendable {
    public enum Role: String, Codable, Sendable { case user, bob }
    public var id: UUID
    public var role: Role
    public var text: String
    public init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

public struct MorningPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var originalIntent: String
    public var steps: [String]
    public var reason: String
    public var confirmedAt: Date
    public var conversation: [ConversationMessage]
    public init(id: UUID = UUID(), originalIntent: String, steps: [String], reason: String = "",
                confirmedAt: Date = Date(), conversation: [ConversationMessage] = []) {
        self.id = id
        self.originalIntent = originalIntent
        self.steps = steps
        self.reason = reason
        self.confirmedAt = confirmedAt
        self.conversation = conversation
    }
}

public enum BobError: Error, LocalizedError, Equatable {
    case invalidSettings(String), invalidPlan, unavailableFallback, invalidProgress, corruptStore
    public var errorDescription: String? {
        switch self {
        case .invalidSettings(let message): message
        case .invalidPlan: "Enter at least one goal before tapping Done."
        case .unavailableFallback: "This alarm does not have a puzzle fallback."
        case .invalidProgress: "That activity could not be verified. Your earlier progress is safe."
        case .corruptStore: "Bob could not read the saved data. Your original file has been preserved."
        }
    }
}
