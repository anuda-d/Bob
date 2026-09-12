import Foundation

/// Credits moving time only after a continuous elbow phase transition is established.
/// This is a conservative activity heuristic, not an exercise-form or identity guarantee.
/// Thresholds are prototype values exercised with synthetic poses, not calibrated on real people.
/// Lighting, clothing, occlusion and camera placement require physical-device validation.
public struct PushupDetector: Sendable {
    public struct Update: Sendable {
        /// Newly accepted seconds. Persist this delta in the occurrence's progress store.
        public let creditedDuration: TimeInterval
        public let feedback: String
    }

    public private(set) var acceptedDuration: TimeInterval = 0
    private var previous: PoseSample?
    private var descending: Bool?
    private var pendingDuration: TimeInterval = 0
    private var extremeAngle: Double = 0
    private var latestTimestamp: TimeInterval?
    private var lastMovementTime: TimeInterval = 0
    private var candidateDuration: TimeInterval = 0

    public init() {}

    /// Call on missing/ambiguous observations, camera interruption, rotation or capture stop.
    /// Previously accepted activity belongs to the caller and is never subtracted.
    /// This also permits a new capture timestamp epoch after a session restart.
    public mutating func pause() {
        breakContinuity()
        latestTimestamp = nil
    }

    public mutating func consume(_ sample: PoseSample) -> Update {
        guard sample.timestamp.isFinite, sample.timestamp >= 0,
              latestTimestamp.map({ sample.timestamp > $0 }) ?? true else {
            breakContinuity()
            return Update(creditedDuration: 0, feedback: "Tracking paused. Keep your body in view.")
        }
        latestTimestamp = sample.timestamp
        guard sample.hasConfidentPoints else {
            breakContinuity()
            return Update(creditedDuration: 0, feedback: "Show your shoulder, elbow, wrist, hip and ankle clearly.")
        }
        guard sample.hasPushupAlignment else {
            breakContinuity()
            return Update(creditedDuration: 0, feedback: "Place the phone to your side and keep your body roughly straight.")
        }
        if let previous {
            let elapsed = sample.timestamp - previous.timestamp
            if elapsed <= 0 || elapsed > 0.25 || !sample.isContinuous(with: previous) {
                breakContinuity()
                return Update(creditedDuration: 0, feedback: "Tracking paused. Move steadily when ready.")
            }
        }
        defer { previous = sample }
        let angle = sample.elbowAngle
        guard let previous, let descending else {
            self.descending = angle >= 150 ? true : (angle <= 110 ? false : nil)
            extremeAngle = angle
            lastMovementTime = sample.timestamp
            return Update(creditedDuration: 0, feedback: "Keep your body in view and move steadily.")
        }
        let elapsed = sample.timestamp - previous.timestamp
        let change = angle - previous.elbowAngle
        guard abs(change) / elapsed <= 220 else {
            breakContinuity()
            return Update(creditedDuration: 0, feedback: "Tracking jumped. Hold the phone steady and keep your body in view.")
        }
        guard abs(change) / elapsed >= 6 else {
            candidateDuration = 0
            expirePausedSegment(at: sample.timestamp, angle: angle)
            return Update(creditedDuration: 0, feedback: "Paused. Move steadily when ready.")
        }
        let forwardChange = descending ? extremeAngle - angle : angle - extremeAngle
        // Buffer sub-degree motion until it crosses the two-degree jitter band.
        // Only moving intervals enter this buffer, so frame rate cannot turn holds into credit.
        let movingForward = descending ? change < 0 : change > 0
        if movingForward && forwardChange > 0 { candidateDuration += elapsed }
        else { candidateDuration = 0 }
        if forwardChange < -8 {
            pendingDuration = 0
            candidateDuration = 0
            self.descending = angle >= 150 ? true : (angle <= 110 ? false : nil)
            extremeAngle = angle
            return Update(creditedDuration: 0, feedback: "Move steadily through a comfortable range.")
        }
        guard forwardChange >= 2 else {
            expirePausedSegment(at: sample.timestamp, angle: angle)
            return Update(creditedDuration: 0, feedback: "Move steadily through a comfortable range.")
        }
        extremeAngle = angle
        lastMovementTime = sample.timestamp
        pendingDuration += candidateDuration
        candidateDuration = 0
        if (descending && angle <= 110) || (!descending && angle >= 150) {
            let credit = pendingDuration
            pendingDuration = 0
            self.descending = !descending
            acceptedDuration += credit
            return Update(creditedDuration: credit, feedback: "Movement accepted. Keep going.")
        }
        return Update(creditedDuration: 0, feedback: "Keep moving steadily.")
    }

    private mutating func breakContinuity() {
        previous = nil
        descending = nil
        pendingDuration = 0
        candidateDuration = 0
    }

    private mutating func expirePausedSegment(at timestamp: TimeInterval, angle: Double) {
        guard timestamp - lastMovementTime > 0.25 else { return }
        pendingDuration = 0
        candidateDuration = 0
        descending = angle >= 150 ? true : (angle <= 110 ? false : nil)
        extremeAngle = angle
        lastMovementTime = timestamp
    }
}
