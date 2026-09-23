import BobCore

/// Validates whole user messages or complete clause coverage within a bounded grammar.
/// Unsupported syntax and context retain exact source turns for manual editing.
/// This is extractive organization, not a general semantic or summarization guarantee.
/// This value has no confirmation or persistence side effects.
public struct GroundedSuggestionValidator: Sendable {
    public static let firstStepQuestion = "What would you like to do first?"
    public static let reasonQuestion = "Why does this matter to you?"

    private let messages: [ConversationMessage]

    /// Lossless source data, separate from every generated or manually edited draft.
    public var originalUserInputs: [String] {
        messages.filter { $0.role == .user }.map(\.text)
    }

    /// A clear draft needs no question; otherwise allow one first-action question.
    /// Existing Bob turns, including legacy reason questions, consume that slot.
    public var canClarify: Bool {
        messages.last?.role == .user
            && messages.last?.text.contains(where: { !$0.isWhitespace }) == true
            && !messages.contains { $0.role == .bob }
            && compactDraft == nil
    }

    /// Retains all nonblank user turns in order, including corrections and doubts.
    /// The caller must let the user resolve contradictions before confirmation.
    public var editableDraft: PlanSuggestion {
        .plan(steps: nonblankUserInputs, reason: "")
    }

    /// Compact source clauses when the complete conversation matches the grammar.
    /// Nil means use `editableDraft`; original input is retained either way.
    public var compactDraft: PlanSuggestion? {
        guard let steps = CompactPlanExtraction.steps(from: messages) else { return nil }
        return .plan(steps: steps, reason: "")
    }

    private var nonblankUserInputs: [String] {
        originalUserInputs.filter { $0.contains { !$0.isWhitespace } }
    }

    public init(messages: [ConversationMessage]) {
        self.messages = messages
    }

    /// Accepts only complete source coverage, including any first-action clarification.
    /// Replaces unsupported output with `editableDraft` rather than retrying AI.
    /// A reason may be separated only from the final answer to `reasonQuestion`.
    /// Returned plan text always comes from the source snapshot, preserving its bytes.
    public func validate(_ suggestion: PlanSuggestion) -> PlanSuggestion {
        let userInputs = nonblankUserInputs
        if case .clarification(let question) = suggestion {
            guard canClarify,
                  !messages.contains(where: { $0.role == .bob && $0.text == question }),
                  question == Self.firstStepQuestion else {
                return .plan(steps: userInputs, reason: "")
            }
        }
        if case .plan(let steps, let reason) = suggestion,
           let answer = messages.last,
           messages.count >= 2,
           messages[messages.count - 2].role == .bob,
           messages[messages.count - 2].text == Self.reasonQuestion,
           answer.role == .user,
           answer.text.contains(where: { !$0.isWhitespace }),
           reason == answer.text,
           steps == Array(userInputs.dropLast()) {
            return .plan(steps: Array(userInputs.dropLast()), reason: answer.text)
        }
        if case .plan(let steps, let reason) = suggestion,
           reason.isEmpty,
           let compactSteps = CompactPlanExtraction.steps(from: messages),
           steps == compactSteps {
            return .plan(steps: compactSteps, reason: "")
        }
        if case .plan = suggestion {
            return editableDraft
        }
        return suggestion
    }
}
