import Foundation
import BobCore

/// A deliberately bounded phrase grammar, not a natural-language semantic parser.
enum CompactPlanExtraction {
    static func steps(from messages: [ConversationMessage]) -> [String]? {
        // Only the app's first-action question establishes a supported reply context.
        guard messages.filter({ $0.role == .bob }).allSatisfy({
            $0.text == GroundedSuggestionValidator.firstStepQuestion
        }) else { return nil }
        var result: [String] = []
        var firstAction: String?
        for (index, message) in messages.enumerated() where message.role == .user {
            guard message.text.contains(where: { !$0.isWhitespace }) else { continue }
            guard let clauses = clauses(in: message.text) else { return nil }
            if index > 0, messages[index - 1].role == .bob,
               messages[index - 1].text == GroundedSuggestionValidator.firstStepQuestion {
                guard firstAction == nil, clauses.count == 1 else { return nil }
                firstAction = clauses[0]
            } else {
                result.append(contentsOf: clauses)
            }
        }
        if let firstAction {
            if let duplicate = result.firstIndex(where: { comparisonKey($0) == comparisonKey(firstAction) }) {
                result.remove(at: duplicate)
            }
            result.insert(firstAction, at: 0)
        }
        return result.isEmpty ? nil : result
    }

    private static func comparisonKey(_ phrase: String) -> String {
        var key = phrase.lowercased()
        if key.hasSuffix(".") { key.removeLast() }
        return key
    }

    private static func clauses(in input: String) -> [String]? {
        var body = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let framing = "I want to "
        if body.lowercased().hasPrefix(framing.lowercased()) {
            body.removeFirst(framing.count)
        }
        let clauses = body.components(separatedBy: " and ")
        // A trailing duration can scope over the entire coordination.
        guard clauses.count == 1 || clauses.last?.lowercased().contains(" for ") == false else { return nil }
        for clause in clauses {
            var phrase = clause.lowercased()
            if phrase.hasSuffix(".") { phrase.removeLast() }
            if phrase.hasSuffix(" tomorrow") { phrase.removeLast(" tomorrow".count) }
            if let duration = phrase.range(of: " for ") {
                let amount = phrase[duration.upperBound...].split(separator: " ", omittingEmptySubsequences: false)
                guard amount.count == 2, !amount[0].isEmpty,
                      amount[0].allSatisfy({ $0.isASCII && $0.isNumber }),
                      amount[1] == "minutes" else { return nil }
                phrase = String(phrase[..<duration.lowerBound])
            }
            guard isAction(phrase) else { return nil }
        }
        return clauses
    }

    private static func isAction(_ phrase: String) -> Bool {
        if ["exercise", "walk", "stretch"].contains(phrase) { return true }
        for verb in ["work on", "outline", "draft", "review", "read"] {
            guard phrase.hasPrefix(verb + " ") else { continue }
            let object = phrase.dropFirst(verb.count + 1).split(separator: " ", omittingEmptySubsequences: false)
            return object.count == 2
                && ["my", "the", "a"].contains(String(object[0]))
                && ["proposal", "introduction", "notes", "book", "report"].contains(String(object[1]))
        }
        return false
    }
}
