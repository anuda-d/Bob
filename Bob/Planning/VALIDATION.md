# Local planning behavior and validation

The deterministic validator and native adapter were initially validated on 2026-09-12.
Actual on-device model quality remains unverified.

## Public API and integration

`BobPlan` imports `BobCore` and has no external dependencies.

```swift
public enum PlanSuggestion: Equatable, Sendable {
    case clarification(String)
    case plan(steps: [String], reason: String)
}

public struct GroundedSuggestionValidator: Sendable {
    public init(messages: [ConversationMessage])
    public var originalUserInputs: [String] { get }
    public var canClarify: Bool { get }
    public var editableDraft: PlanSuggestion { get }
    public var compactDraft: PlanSuggestion? { get }
    public func validate(_ suggestion: PlanSuggestion) -> PlanSuggestion
    public static let firstStepQuestion: String
    public static let reasonQuestion: String
}
```

The native app adapter is `@MainActor @Observable final class LocalPlanner`.
It exposes `init()`, a read-only `availabilityMessage: String?`, `refreshAvailability()`, and `draft(messages:) async throws -> PlanSuggestion`.
A nil availability message means the system model currently reports availability.
Call `refreshAvailability()` when returning to the app or retrying availability.
Pass the complete conversation with authentic role values and append each returned clarification as a `.bob` message before requesting the next draft.

Retain the conversation and original input separately from editable steps and reason fields.
`originalUserInputs` is an independent, lossless snapshot of all user turns, including whitespace.
`editableDraft` excludes blank-only turns from steps but does not trim or truncate any retained turn.
`compactDraft` supplies a deterministic, source-derived candidate when the complete conversation fits the bounded grammar; otherwise it returns nil.
The native planner uses this candidate and supplies it to the model as quoted data.
The deterministic `AppModel` UI test fixture uses `editableDraft` and does not exercise actual model inference.
The validator is for generated suggestions; manual edits are new user choices and belong at the existing explicit confirmation boundary.
Neither the validator nor the adapter constructs a `MorningPlan`, confirms a plan, writes storage, or completes a broader goal.

## Grounding contract

Generated compact steps must exactly match complete clause coverage from the bounded extraction grammar.
Arbitrary substrings and paraphrases are rejected.
If any nonblank user turn or Bob context is unsupported, the entire conversation falls back to exact nonblank user turns in their original order.
It does not resolve conflicting statements or interpret a short acknowledgment as agreement to details that only Bob supplied.
The user can resolve these in the editable draft before confirming.

For `I want to exercise and work on my proposal tomorrow`, a valid compact candidate is `["exercise", "work on my proposal tomorrow"]`.
After the exact first-action question and the user's `Exercise.`, the candidate is `["Exercise.", "work on my proposal tomorrow"]`.
After a more specific answer such as `Outline the introduction.`, that answer leads and both original compact goals remain present.
The extractor does not infer that outlining replaces proposal work or that exercise is already done.
Only one earlier phrase identical to the first-action answer, ignoring case and a terminal period, may be removed as a duplicate reference.
Quantities and temporal words remain part of duplicate comparison and coverage.

## Bounded design alternative and limitations

This is useful extractive organization for a small English grammar, not full summarization or a semantic language guarantee.
General-purpose interpretation of arbitrary natural language has not been established.
The strict grammar intentionally rejects many ordinary valid task descriptions instead of guessing their structure.

| Part | Supported form |
| --- | --- |
| Framing | Optional `I want to `, matched without changing the source's case. |
| Coordination | Literal ` and ` between fully recognized action clauses. |
| Standalone actions | `exercise`, `walk`, `stretch`. |
| Actions with objects | `work on`, `outline`, `draft`, `review`, or `read`, followed by `my`, `the`, or `a`, then `proposal`, `introduction`, `notes`, `book`, or `report`. |
| Duration | Verbatim ASCII digits followed by `minutes`, introduced by ` for ` within a clause. |
| Timing and punctuation | Optional terminal ` tomorrow` and a period, retained in the returned source span. |
| Conversation context | User turns alone, or the exact app-authored first-action question followed by one recognized action clause. |

Only framing, coordination separators, and outer whitespace are omitted from compact presentation.
Every action clause and its quantities or timing words must remain covered, including meaningful later user input.
Every returned compact step is a contiguous phrase from a user message; words are not assembled across disjoint spans.
The literal `tomorrow` remains on its source clause rather than being copied onto other steps or converted into a deadline.
Shared timing interpretation remains visible in the separately retained original intent and requires user review; the planner does not schedule plan steps.

A duration on the final clause of a coordinated sentence is rejected because it may apply to the whole coordination.
Negation, conditions, corrections, disjunctions, quotations, unknown objects, other deadlines, multilingual input, and instruction-like content fall outside this grammar.
One unsupported turn prevents partial compaction of the others.
Any Bob context other than the first-action question also prevents compaction, including reason questions and hypothetical suggestions.
This is deliberate: a reason answer that looks like an action must not silently become another commitment.
Whole-message reason separation remains available through the original validation path below.

The only separate generated reason accepted is a complete final user answer immediately following the exact app-authored reason question.
The remaining steps must cover the earlier nonblank user turns in order.
Even accepted text is reconstructed from the retained source, preserving its original Unicode bytes.
If a reason cannot be separated safely, the draft keeps all user turns and uses an empty reason field.

Clarifications use two fixed, brief questions: “What would you like to do first?” and “Why does this matter to you?”
Every Bob turn consumes a slot, including unrecognized historical replies.
There are at most two slots, repeated questions are rejected, and another question requires a nonblank latest user turn.
The adapter returns `compactDraft ?? editableDraft` without inference when clarification is no longer possible.

## Native adapter

The adapter explicitly uses `SystemLanguageModel.default` and a fresh `LanguageModelSession` per request.
It uses an `@Generable` schema, `@Guide`, greedy sampling, temperature zero, and a 1,000-token response limit.
User and Bob messages, a source-derived candidate, and a compact-mode flag are JSON-encoded as untrusted data beneath static instructions.
The prompt requests the supplied compact source clauses when available and exact full-source recovery otherwise.
The model helps decide whether a brief clarification is needed; application code establishes the accepted extraction boundary.
All generated content passes through the public validator before it is returned.
No network API, cloud model, model tools, paid AI service, or OpenAI dependency is present.

All model unavailability cases offer manual entry and confirmation.
Prompt contexts exceeding 6,000 encoded bytes produce an actionable manual-editing error without truncating the source.
Generation failures offer the same manual recovery, and cancellation propagates as cancellation.
Generation errors do not permanently change model availability status.
The UI must keep manual editing and confirmation available regardless of availability or errors.

## Repeatable checks

From the repository root:

```sh
swift test --filter BobPlanTests
sh Tests/BobPlanTests/.support/verify-native.sh
```

The initial validation on 2026-09-12 passed 28 planner tests with Swift 6.3.3.
They cover intent preservation, Unicode source fidelity, quantities, timing, clarification bounds, omissions, duplicates, corrections, unsupported syntax, prompt injection as data, and conservative recovery.
The native script compiles for both iPhone and simulator with Swift 6 strict concurrency and warnings treated as errors.
These checks establish deterministic validator behavior and SDK compatibility, not actual model quality.

## Pending device task

Actual offline model inference has not been run on a physical iPhone.
Use the [device checklist](../../docs/DEVICE_VALIDATION.md) for representative and adversarial conversations.
Check the phone's installed iOS version, Apple Intelligence readiness, downloaded model, and representative planning conversations with internet unavailable.
Exercise model refusal, context limits, cancellation, availability changes, manual recovery, clarification usefulness, latency, and battery impact on the device.
Recheck adversarial inputs through actual generation as well as the deterministic validator.
No effectiveness, offline inference, UI, or device-runtime result is claimed by these compiler and validator checks.

## Primary references

The availability and session API were checked against Apple's [generation documentation](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models).
Structured output was checked against Apple's [guided generation documentation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation).
The distinction between model output and application validation was reviewed against Apple's [generative output safety documentation](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output).
