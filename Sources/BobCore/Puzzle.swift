import Foundation

public struct MathProblem: Codable, Equatable, Sendable {
    public enum Operation: String, Codable, Sendable { case add, subtract, multiply }
    public let left: Int
    public let right: Int
    public let operation: Operation
    public init(left: Int, right: Int, operation: Operation) {
        self.left = left
        self.right = right
        self.operation = operation
    }
    public var prompt: String {
        let symbol = switch operation { case .add: "+"; case .subtract: "-"; case .multiply: "×" }
        return "\(left) \(symbol) \(right)"
    }
    public func accepts(_ answer: String) -> Bool {
        guard let value = Int(answer.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        let result = switch operation {
        case .add: left.addingReportingOverflow(right)
        case .subtract: left.subtractingReportingOverflow(right)
        case .multiply: left.multipliedReportingOverflow(by: right)
        }
        return !result.overflow && value == result.partialValue
    }
}

public struct PuzzleProgress: Codable, Equatable, Sendable {
    public static func generate(difficulty: PuzzleDifficulty) -> PuzzleProgress {
        switch difficulty {
        case .easy:
            .init(problems: [.init(left: .random(in: 1...20), right: .random(in: 1...20), operation: .add)])
        case .hard:
            .init(problems: [
                .init(left: .random(in: 6...12), right: .random(in: 6...12), operation: .multiply),
                .init(left: .random(in: 70...99), right: .random(in: 21...59), operation: .subtract),
                .init(left: .random(in: 24...89), right: .random(in: 24...89), operation: .add)
            ])
        }
    }
    public let problems: [MathProblem]
    public private(set) var solvedCount: Int = 0
    public init(problems: [MathProblem]) { self.problems = problems }
    public var isComplete: Bool { !problems.isEmpty && solvedCount == problems.count }
    public var currentProblem: MathProblem? {
        problems.indices.contains(solvedCount) ? problems[solvedCount] : nil
    }
    @discardableResult public mutating func submit(_ answer: String) -> Bool {
        guard let currentProblem, currentProblem.accepts(answer) else { return false }
        solvedCount += 1
        return true
    }
}
