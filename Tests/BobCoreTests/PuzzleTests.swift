import Testing
@testable import BobCore

@Suite struct PuzzleTests {
    @Test func difficultyControlsActualProblemCountAndArithmetic() {
        let easy = PuzzleProgress.generate(difficulty: .easy)
        #expect(easy.problems.count == 1)
        #expect(easy.problems.allSatisfy { $0.operation == .add && (1...20).contains($0.left) && (1...20).contains($0.right) })
        let hard = PuzzleProgress.generate(difficulty: .hard)
        #expect(hard.problems.count == 3)
        #expect(hard.problems.map(\.operation) == [.multiply, .subtract, .add])
    }
    @Test func wrongAnswerPreservesProgressAndCorrectAnswerCompletes() {
        var puzzle = PuzzleProgress(problems: [.init(left: 8, right: 5, operation: .add)])
        let wrong = puzzle.submit("12")
        #expect(!wrong)
        #expect(puzzle.solvedCount == 0)
        let correct = puzzle.submit(" 13 ")
        #expect(correct)
        #expect(puzzle.isComplete)
        #expect(puzzle.currentProblem == nil)
    }
}
