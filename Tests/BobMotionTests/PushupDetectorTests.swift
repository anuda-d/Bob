import Foundation
import Testing
import BobMotion

struct PushupDetectorTests {
    @Test func tinyBodyCannotProvideReliableExerciseEvidence() {
        var detector = PushupDetector()
        for (index, angle) in [165.0, 155, 145, 135, 125, 115, 105].enumerated() {
            var sample = pose(at: Double(index) / 10, angle: angle)
            sample.shoulder = scaled(sample.shoulder, by: 0.01)
            sample.elbow = scaled(sample.elbow, by: 0.01)
            sample.wrist = scaled(sample.wrist, by: 0.01)
            sample.hip = scaled(sample.hip, by: 0.01)
            sample.ankle = scaled(sample.ankle, by: 0.01)
            _ = detector.consume(sample)
        }
        #expect(detector.acceptedDuration == 0)
    }

    @Test(arguments: [15, 30, 60])
    func smoothSlowerMotionKeepsItsDurationAcrossFrameRates(fps: Int) {
        var detector = PushupDetector()
        for tick in 0...(2 * fps) {
            let time = Double(tick) / Double(fps)
            _ = detector.consume(pose(at: time, angle: 165 - time * 30))
        }
        #expect(detector.acceptedDuration >= 1.7)
        #expect(detector.acceptedDuration <= 2.001)
    }

    @Test func longMidMovementPauseDiscardsOnlyUnacceptedTime() {
        var detector = earnedDescent()
        _ = detector.consume(pose(at: 0.7, angle: 115))
        _ = detector.consume(pose(at: 0.8, angle: 125))
        for tick in 9...30 { _ = detector.consume(pose(at: Double(tick) / 10, angle: 125)) }
        for (index, angle) in [135.0, 145, 155].enumerated() {
            _ = detector.consume(pose(at: 3.1 + Double(index) / 10, angle: angle))
        }
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
    }

    @Test func replayedTimestampsCannotEarnTheSameSegmentTwice() {
        var detector = earnedDescent()
        for (index, angle) in [165.0, 155, 145, 135, 125, 115, 105].enumerated() {
            _ = detector.consume(pose(at: Double(index) / 10, angle: angle))
        }
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
    }

    @Test func bodyJumpCannotBeCombinedWithEarlierMovement() {
        var detector = earnedDescent()
        for (index, angle) in [115.0, 125, 135, 145, 155].enumerated() {
            var sample = pose(at: 0.7 + Double(index) / 10, angle: angle)
            sample.shoulder.x += 0.8
            sample.elbow.x += 0.8
            sample.wrist.x += 0.8
            sample.hip.x += 0.8
            sample.ankle.x += 0.8
            _ = detector.consume(sample)
        }
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
    }

    @Test func missingPoseOrStoppedCaptureCannotBridgeAPhase() {
        var detector = earnedDescent()
        _ = detector.consume(pose(at: 0.7, angle: 115))
        detector.pause()
        for (index, angle) in [125.0, 135, 145, 155].enumerated() {
            _ = detector.consume(pose(at: 0.8 + Double(index) / 10, angle: angle))
        }
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
        for (index, angle) in [145.0, 135, 125, 115, 105].enumerated() {
            _ = detector.consume(pose(at: 1.2 + Double(index) / 10, angle: angle))
        }
        #expect(abs(detector.acceptedDuration - 1.1) < 0.0001)
    }

    @Test func endpointJitterDoesNotInflateTheNextMovingSegment() {
        var detector = PushupDetector()
        for tick in 0...200 {
            _ = detector.consume(pose(at: Double(tick) / 10, angle: tick.isMultiple(of: 2) ? 165 : 164))
        }
        for (index, angle) in [155.0, 145, 135, 125, 115, 105].enumerated() {
            _ = detector.consume(pose(at: 20.1 + Double(index) / 10, angle: angle))
        }
        #expect(detector.acceptedDuration >= 0.5)
        #expect(detector.acceptedDuration <= 0.6001)
    }

    @Test func implausibleElbowJumpCannotCompleteAPhase() {
        var detector = earnedDescent()
        let update = detector.consume(pose(at: 0.7, angle: 165))
        #expect(update.creditedDuration == 0)
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
    }

    @Test(arguments: ["standing", "bent", "collapsed", "nonfinite"])
    func armMotionWithoutPlausibleBodyAlignmentEarnsNothing(kind: String) {
        var detector = PushupDetector()
        for (index, angle) in [165.0, 155, 145, 135, 125, 115, 105].enumerated() {
            var sample = pose(at: Double(index) / 10, angle: angle)
            switch kind {
            case "standing":
                sample.hip = .init(x: 0.3, y: 0.3, confidence: 1)
                sample.ankle = .init(x: 0.3, y: 0.05, confidence: 1)
            case "bent": sample.hip.y = 0.8
            case "collapsed": sample.hip = sample.shoulder
            default: sample.wrist.x = .nan
            }
            _ = detector.consume(sample)
        }
        #expect(detector.acceptedDuration == 0)
    }

    @Test(arguments: [0.2, 0.59, Double.nan, Double.infinity])
    func unclearTrackingBreaksUnacceptedSegmentAndKeepsEarnedTime(confidence: Double) {
        var detector = earnedDescent()
        _ = detector.consume(pose(at: 0.7, angle: 115))
        _ = detector.consume(pose(at: 0.8, angle: 125, confidence: confidence))
        _ = detector.consume(pose(at: 0.9, angle: 135))
        _ = detector.consume(pose(at: 1.0, angle: 145))
        _ = detector.consume(pose(at: 1.1, angle: 155))
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
    }

    @Test(arguments: [5.0, 0.6, 0.5, -1.0, Double.nan, Double.infinity])
    func invalidOrDiscontinuousTimeCannotCreditOrEraseProgress(timestamp: Double) {
        var detector = earnedDescent()
        let result = detector.consume(pose(at: timestamp, angle: 155))
        #expect(result.creditedDuration == 0)
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
    }

    @Test func staticHoldBeforeMovementEarnsNothing() {
        var detector = PushupDetector()
        for tick in 0...200 { _ = detector.consume(pose(at: Double(tick) / 10, angle: 165)) }
        #expect(detector.acceptedDuration == 0)
        for (index, angle) in [155.0, 145, 135, 125, 115, 105].enumerated() {
            _ = detector.consume(pose(at: 20.1 + Double(index) / 10, angle: angle))
        }
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
    }

    @Test func qualifyingDescentCreditsItsMovingDuration() {
        var detector = PushupDetector()
        var credits: [TimeInterval] = []
        for (index, angle) in [165.0, 155, 145, 135, 125, 115, 105].enumerated() {
            credits.append(detector.consume(pose(at: Double(index) / 10, angle: angle)).creditedDuration)
        }
        #expect(credits.dropLast().allSatisfy { $0 == 0 })
        #expect(abs(credits.last! - 0.6) < 0.0001)
        #expect(abs(detector.acceptedDuration - 0.6) < 0.0001)
    }
}

private func scaled(_ point: PoseSample.Point, by scale: Double) -> PoseSample.Point {
    .init(x: point.x * scale, y: point.y * scale, confidence: point.confidence)
}

private func earnedDescent() -> PushupDetector {
    var detector = PushupDetector()
    for (index, angle) in [165.0, 155, 145, 135, 125, 115, 105].enumerated() {
        _ = detector.consume(pose(at: Double(index) / 10, angle: angle))
    }
    return detector
}

private func pose(at timestamp: TimeInterval, angle: Double, confidence: Double = 1) -> PoseSample {
    let radians = angle * .pi / 180
    return PoseSample(
        timestamp: timestamp,
        shoulder: .init(x: 0.3, y: 0.55, confidence: confidence),
        elbow: .init(x: 0.3, y: 0.4, confidence: confidence),
        wrist: .init(x: 0.3 + 0.15 * sin(radians), y: 0.4 + 0.15 * cos(radians), confidence: confidence),
        hip: .init(x: 0.55, y: 0.52, confidence: confidence),
        ankle: .init(x: 0.88, y: 0.48, confidence: confidence)
    )
}
