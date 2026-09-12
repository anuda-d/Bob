import Foundation
import Testing
@testable import BobCore

@Suite struct PersistenceTests {
    @Test func confirmingPlanPreservesTheIdentifiersOfAlreadyQueuedAlarms() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = BobState()
        state.occurrences = [.init(settings: .init(), scheduledAt: now.addingTimeInterval(3_600))]
        let before = state.retryRequests(at: now)
        try state.confirmPlan(steps: ["Make breakfast"], reason: "", at: now)
        #expect(state.retryRequests(at: now) == before)
        #expect(state.occurrences.first?.plan?.steps == ["Make breakfast"])
    }
    @Test func confirmationKeepsUsersExactIntentAndDoesNotRewriteActiveMorning() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = BobState()
        let old = MorningPlan(originalIntent: "Read", steps: ["Read one page"])
        state.plan = old
        state.occurrences = [.init(settings: .init(), scheduledAt: now.addingTimeInterval(-60), plan: old)]
        state.conversation = [.init(role: .user, text: "Work on my proposal"), .init(role: .bob, text: "What comes first?"), .init(role: .user, text: "Draft the introduction")]
        try state.confirmPlan(steps: ["  Draft the introduction  "], reason: "", at: now)
        #expect(state.plan?.originalIntent == "Work on my proposal\nDraft the introduction")
        #expect(state.plan?.steps == ["Draft the introduction"])
        #expect(state.occurrences.first?.plan == old)
        #expect(throws: BobError.invalidPlan) { try state.confirmPlan(steps: [" "], reason: "", at: now) }
    }
    @Test func restartRestoresAcceptedProgressAndOriginalConfirmedPlan() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONStore(directory: directory)
        let wake = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = MorningPlan(originalIntent: "Exercise and work on the proposal", steps: ["Draft the introduction"])
        var morning = MorningOccurrence(settings: .init(challenge: .init(kind: .pushups, fallback: .easy)), scheduledAt: wake, plan: plan)
        try morning.acceptActivity(1, at: wake.addingTimeInterval(1))
        var state = BobState()
        state.plan = plan
        state.occurrences = [morning]
        try store.save(state)
        let restored = try JSONStore(directory: directory).load()
        #expect(restored.occurrences.first?.verifiedSeconds == 1)
        #expect(restored.occurrences.first?.plan == plan)
        #expect(restored.plan?.originalIntent == "Exercise and work on the proposal")
    }
}
