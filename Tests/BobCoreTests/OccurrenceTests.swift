import Foundation
import Testing
@testable import BobCore

@Suite struct OccurrenceTests {
    let wake = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func slowQualifyingMovementKeepsItsFullVerifiedDuration() throws {
        var occurrence = MorningOccurrence(settings: .init(challenge: .init(kind: .pushups, fallback: .easy)), scheduledAt: wake)
        try occurrence.acceptActivity(3.5, at: wake.addingTimeInterval(5))
        #expect(occurrence.verifiedSeconds == 3.5)
    }

    @Test func onlyRegisteredCodeCompletesQRChallenge() {
        let config = ChallengeConfiguration(kind: .qr, qrCode: "bob:kitchen:91", fallback: .hard)
        var occurrence = MorningOccurrence(settings: .init(challenge: config), scheduledAt: wake)
        let wrong = occurrence.scanCode("bob:kitchen:92", at: wake)
        #expect(!wrong)
        #expect(!occurrence.isComplete)
        let correct = occurrence.scanCode("bob:kitchen:91", at: wake)
        #expect(correct)
        #expect(occurrence.completionMethod == .qr)
    }

    @Test func fallbackRecordsRecoveryWithoutClaimingPushupsAndPreservesIntent() throws {
        let plan = MorningPlan(originalIntent: "Work on my proposal", steps: ["Draft the introduction"])
        var occurrence = MorningOccurrence(settings: .init(challenge: .init(kind: .pushups, fallback: .easy)), scheduledAt: wake, plan: plan)
        try occurrence.acceptActivity(1, at: wake.addingTimeInterval(1))
        try occurrence.useFallback(at: wake.addingTimeInterval(2), puzzle: .init(problems: [.init(left: 8, right: 5, operation: .add)]))
        let wrong = occurrence.submitAnswer("14", at: wake.addingTimeInterval(3))
        #expect(!wrong)
        #expect(!occurrence.isComplete)
        #expect(occurrence.retryDates(after: wake.addingTimeInterval(3)).first == wake.addingTimeInterval(243))
        let correct = occurrence.submitAnswer("13", at: wake.addingTimeInterval(901))
        #expect(correct)
        #expect(occurrence.completionMethod == .fallbackEasy)
        #expect(occurrence.verifiedSeconds == 1)
        #expect(occurrence.plan == plan)
    }

    @Test func verifiedActivitySurvivesFailureAndCompletionCancelsRetries() throws {
        var occurrence = MorningOccurrence(settings: .init(challenge: .init(kind: .pushups, fallback: .easy)), scheduledAt: wake)
        for second in 1...10 { try occurrence.acceptActivity(1, at: wake.addingTimeInterval(Double(second))) }
        #expect(occurrence.verifiedSeconds == 10)
        #expect(throws: BobError.invalidProgress) { try occurrence.acceptActivity(-2, at: wake.addingTimeInterval(11)) }
        #expect(occurrence.verifiedSeconds == 10)
        for second in 12...21 { try occurrence.acceptActivity(1, at: wake.addingTimeInterval(Double(second))) }
        #expect(occurrence.isComplete)
        #expect(occurrence.completionMethod == .pushups)
        #expect(occurrence.retryDates(after: wake.addingTimeInterval(22)).isEmpty)
    }

    @Test func silencingDoesNotCompleteAndRetryWindowStartsAtScheduledWake() throws {
        var occurrence = MorningOccurrence(settings: .init(challenge: .init(kind: .pushups, fallback: .easy)), scheduledAt: wake)
        occurrence.silence(at: wake.addingTimeInterval(30))
        #expect(occurrence.completedAt == nil)
        #expect(occurrence.retryDates(after: wake.addingTimeInterval(30)).first == wake.addingTimeInterval(150))
        #expect(occurrence.retryDates(after: wake.addingTimeInterval(899)).isEmpty)
        #expect(occurrence.audibleDeadline == wake.addingTimeInterval(900))
    }
}
