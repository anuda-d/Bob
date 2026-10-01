import Foundation
import Testing
@testable import BobCore

@Suite struct PersistenceTests {
    @Test func confirmingPlanPreservesTheIdentifiersOfAlreadyQueuedAlarms() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = BobState()
        state.settings = .init(enabled: true)
        state.occurrences = [.init(settings: state.settings, scheduledAt: now.addingTimeInterval(3_600))]
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

    @Test func savePlanPreservesExactTextAndAssignsOnlyTheNextOccurrence() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let text = "  Run 3 km\n\nThen write  "
        var state = BobState()
        state.settings = .init(hour: 7, weekdays: Set(1...7), enabled: true)
        state.occurrences = [
            .init(settings: state.settings, scheduledAt: now.addingTimeInterval(60)),
            .init(settings: state.settings, scheduledAt: now.addingTimeInterval(86_400)),
            .init(settings: state.settings, scheduledAt: now.addingTimeInterval(172_800))
        ]

        try state.savePlan(text, at: now)

        #expect(state.nextPlan(at: now)?.originalIntent == text)
        #expect(state.nextPlan(at: now)?.steps == [text])
        #expect(state.occurrences.map { $0.plan?.originalIntent } == [text, nil, nil])
        #expect(throws: BobError.invalidPlan) { try state.savePlan(" \n\t ", at: now) }
    }

    @Test func savedExactTextSurvivesJSONRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONStore(directory: directory)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = BobState()
        state.settings = .init(enabled: true)
        state.occurrences = [.init(settings: state.settings, scheduledAt: now.addingTimeInterval(3_600))]
        let text = "  Call Sam\nFinish the outline.  "
        try state.savePlan(text, at: now)

        try store.save(state)

        let restored = try store.load()
        #expect(restored.nextPlan(at: now)?.originalIntent == text)
        #expect(restored.planForHome(at: now)?.originalIntent == text)
    }

    @Test func disabledAlarmKeepsSavedPlanEditableAndHomeVisibleUntilReenabled() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = BobState()
        try state.savePlan("Walk before work", at: now)

        #expect(state.nextPlan(at: now)?.originalIntent == "Walk before work")
        #expect(state.planForHome(at: now)?.originalIntent == "Walk before work")
        #expect(state.occurrences.isEmpty)

        state.settings = .init(hour: 7, weekdays: Set(1...7), enabled: true)
        state.refreshSchedule(at: now)
        #expect(state.nextPlan(at: now)?.originalIntent == "Walk before work")
        #expect(state.occurrences.filter { $0.plan != nil }.count == 1)
    }
}
