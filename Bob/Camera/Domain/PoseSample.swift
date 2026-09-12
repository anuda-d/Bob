import Foundation

/// One side of one body, in upright, unmirrored image coordinates.
/// y is normalized to image height; x is Vision's normalized x multiplied by width / height.
/// Both axes must use image-height units so angles remain correct in portrait and landscape.
public struct PoseSample: Sendable {
    public struct Point: Sendable {
        public var x: Double
        public var y: Double
        public var confidence: Double

        public init(x: Double, y: Double, confidence: Double) {
            self.x = x
            self.y = y
            self.confidence = confidence
        }
    }

    public var timestamp: TimeInterval
    public var shoulder: Point
    public var elbow: Point
    public var wrist: Point
    public var hip: Point
    public var ankle: Point

    public init(timestamp: TimeInterval, shoulder: Point, elbow: Point, wrist: Point, hip: Point, ankle: Point) {
        self.timestamp = timestamp
        self.shoulder = shoulder
        self.elbow = elbow
        self.wrist = wrist
        self.hip = hip
        self.ankle = ankle
    }

    var elbowAngle: Double { Self.angle(shoulder, elbow, wrist) }

    var hasConfidentPoints: Bool {
        [shoulder, elbow, wrist, hip, ankle].allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.confidence.isFinite && (0.6...1).contains($0.confidence)
        }
    }

    var hasPushupAlignment: Bool {
        let inclination = atan2(abs(shoulder.y - ankle.y), abs(shoulder.x - ankle.x)) * 180 / .pi
        return bodyLength.isFinite && bodyLength >= 0.25
            && Self.angle(shoulder, hip, ankle) >= 155 && inclination <= 35 && elbowAngle >= 45
    }

    var bodyLength: Double { hypot(shoulder.x - ankle.x, shoulder.y - ankle.y) }

    func isContinuous(with previous: PoseSample) -> Bool {
        let scale = previous.bodyLength
        let displacement = hypot(hip.x - previous.hip.x, hip.y - previous.hip.y)
        return scale > 0 && displacement / scale <= 0.15 && (0.8...1.25).contains(bodyLength / scale)
    }

    static func angle(_ a: Point, _ vertex: Point, _ b: Point) -> Double {
        let ax = a.x - vertex.x, ay = a.y - vertex.y
        let bx = b.x - vertex.x, by = b.y - vertex.y
        let length = hypot(ax, ay) * hypot(bx, by)
        guard length > 0 else { return .nan }
        return acos(max(-1, min(1, (ax * bx + ay * by) / length))) * 180 / .pi
    }
}
