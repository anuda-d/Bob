import Foundation

public enum CompletionMethod: String, Codable, Sendable {
    case pushups, puzzle, qr, fallbackEasy, fallbackHard
}

public struct MorningOccurrence: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let settings: AlarmSettings
    public let scheduledAt: Date
    public private(set) var plan: MorningPlan?
    public let retryIDs: [UUID]
    public private(set) var verifiedSeconds: TimeInterval = 0
    public private(set) var completedAt: Date?
    public private(set) var completionMethod: CompletionMethod?
    public private(set) var usingFallback = false
    public private(set) var lastActivityAt: Date
    public private(set) var puzzleThinking = false
    public private(set) var puzzle: PuzzleProgress
    private var lastVerifiedAt: Date?

    public init(id: UUID = UUID(), settings: AlarmSettings, scheduledAt: Date, plan: MorningPlan? = nil,
                puzzle: PuzzleProgress? = nil) {
        self.id = id
        self.settings = settings
        self.scheduledAt = scheduledAt
        self.plan = plan
        self.retryIDs = (0..<7).map { _ in UUID() }
        self.lastActivityAt = scheduledAt
        self.puzzle = puzzle ?? .generate(difficulty: settings.challenge.difficulty)
    }

    public var audibleDeadline: Date { scheduledAt.addingTimeInterval(15 * 60) }
    public var isComplete: Bool { completedAt != nil }
    public var effectiveChallenge: ChallengeKind { usingFallback ? .puzzle : settings.challenge.kind }

    public func replacingPlan(_ replacement: MorningPlan) -> MorningOccurrence {
        var result = self
        result.plan = replacement
        return result
    }

    @discardableResult public mutating func scanCode(_ code: String, at now: Date) -> Bool {
        guard !isComplete, effectiveChallenge == .qr, now >= scheduledAt,
              !code.isEmpty, code == settings.challenge.qrCode else { return false }
        complete(method: .qr, at: now)
        return true
    }

    public mutating func beginChallenge(at now: Date) {
        guard !isComplete, now >= scheduledAt else { return }
        if effectiveChallenge == .puzzle && !puzzleThinking {
            puzzleThinking = true
            lastActivityAt = max(lastActivityAt, now)
        }
    }

    public mutating func useFallback(at now: Date, puzzle replacement: PuzzleProgress? = nil) throws {
        guard let difficulty = settings.challenge.fallback, settings.challenge.kind != .puzzle else {
            throw BobError.unavailableFallback
        }
        guard !isComplete, !usingFallback else { return }
        usingFallback = true
        puzzle = replacement ?? .generate(difficulty: difficulty)
        beginChallenge(at: now)
    }

    @discardableResult public mutating func submitAnswer(_ answer: String, at now: Date) -> Bool {
        guard !isComplete, effectiveChallenge == .puzzle, now >= scheduledAt else { return false }
        beginChallenge(at: now)
        // An actual answer attempt renews thinking time; simply keeping the screen open does not.
        lastActivityAt = max(lastActivityAt, now)
        let accepted = puzzle.submit(answer)
        if puzzle.isComplete {
            complete(method: usingFallback ? (settings.challenge.fallback == .hard ? .fallbackHard : .fallbackEasy) : .puzzle, at: now)
        }
        return accepted
    }

    public mutating func acceptActivity(_ seconds: TimeInterval, at now: Date) throws {
        guard !isComplete, effectiveChallenge == .pushups else { return }
        guard seconds.isFinite, seconds > 0, seconds <= 20,
              now > (lastVerifiedAt ?? scheduledAt),
              seconds <= now.timeIntervalSince(lastVerifiedAt ?? scheduledAt) + 0.05 else {
            throw BobError.invalidProgress
        }
        lastVerifiedAt = now
        lastActivityAt = max(lastActivityAt, now)
        verifiedSeconds = min(20, verifiedSeconds + seconds)
        if verifiedSeconds >= 20 - 0.00001 {
            verifiedSeconds = 20
            complete(method: .pushups, at: now)
        }
    }

    private mutating func complete(method: CompletionMethod, at now: Date) {
        guard !isComplete else { return }
        completedAt = now
        completionMethod = method
    }

    public mutating func silence(at now: Date) {
        guard !isComplete, now >= scheduledAt else { return }
        lastActivityAt = max(lastActivityAt, now)
    }

    public func retryDates(after now: Date) -> [Date] {
        guard !isComplete, now < audibleDeadline else { return [] }
        let allowance: TimeInterval = puzzleThinking ? 240 : 120
        var next = lastActivityAt.addingTimeInterval(allowance)
        var dates: [Date] = []
        while next < audibleDeadline {
            if next > now { dates.append(next) }
            next = next.addingTimeInterval(120)
        }
        return dates
    }
}
