/// An editable suggestion. Creating one never confirms or stores a morning plan.
public enum PlanSuggestion: Equatable, Sendable {
    case clarification(String)
    case plan(steps: [String], reason: String)
}
