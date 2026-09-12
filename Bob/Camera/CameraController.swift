import AVFoundation
import Observation
import Vision

/// Camera-only adapter. The caller stores accepted activity and checks scanned QR values.
/// No image buffers leave the capture queue, and no footage is saved.
@MainActor @Observable
public final class CameraController {
    public enum Mode: Sendable { case pushups, qr }

    public var session: AVCaptureSession { capture.session }
    public private(set) var feedback = "Camera is stopped."
    public private(set) var permissionDenied = false

    @ObservationIgnored private let capture: CameraCapture
    @ObservationIgnored private let onActivity: (TimeInterval) -> Void
    @ObservationIgnored private let onCode: (String) -> Void
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var requested = false

    public init(mode: Mode, onActivity: @escaping (TimeInterval) -> Void, onCode: @escaping (String) -> Void) {
        capture = CameraCapture(mode: mode)
        self.onActivity = onActivity
        self.onCode = onCode
    }

    /// Rechecks authorization on every fresh start, including after returning from Settings.
    public func start() async {
        guard !requested, !Task.isCancelled else { return }
        requested = true
        generation += 1
        let request = generation
        permissionDenied = false
        feedback = "Starting camera…"
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        guard requested, generation == request else { return }
        guard !Task.isCancelled else { stop(); return }
        guard authorized else {
            requested = false
            permissionDenied = true
            feedback = "Camera access is unavailable. Allow it in Settings or use your puzzle fallback."
            return
        }
        await capture.start(generation: request) { [weak self] event, eventGeneration in
            // Preserve event order, especially a credit immediately before an interruption.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.requested, self.generation == eventGeneration else { return }
                switch event {
                case .feedback(let message): self.feedback = message
                case .activity(let seconds): self.onActivity(seconds)
                case .code(let code): self.onCode(code)
                case .failed(let message):
                    self.feedback = message
                    self.requested = false
                }
            }
        }
    }

    public func stop() {
        requested = false
        generation += 1
        capture.stop()
        feedback = "Camera is stopped. Your accepted progress is kept."
    }

    deinit { capture.stop() }
}

private enum CameraEvent: Sendable {
    case feedback(String), activity(TimeInterval), code(String), failed(String)
}

/// AVFoundation delegate APIs require an NSObject rather than an actor.
/// All mutable capture state, Vision work, configuration and session operations are confined
/// to `queue`. The session is exposed solely for AVCaptureVideoPreviewLayer attachment.
private final class CameraCapture: NSObject, @unchecked Sendable,
    AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "Bob.camera.capture", qos: .userInitiated)
    private let mode: CameraController.Mode
    private var sink: (@Sendable (CameraEvent, Int) -> Void)?
    private var generation = 0
    private var wantsRunning = false
    private var configured = false
    private var interrupted = false
    private var detector = PushupDetector()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var notificationTokens: [NSObjectProtocol] = []
    private var lastFrameTime: TimeInterval?
    private var lastSide: Bool?
    private var lastCode: String?
    private var lastCodeTime: TimeInterval = 0
    private var lastFeedback: String?
    private let poseRequest = VNDetectHumanBodyPoseRequest()

    init(mode: CameraController.Mode) {
        self.mode = mode
        super.init()
    }

    func start(generation: Int, sink: @escaping @Sendable (CameraEvent, Int) -> Void) async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                self.generation = generation
                self.sink = sink
                wantsRunning = true
                lastFeedback = nil
                detector.pause()
                do {
                    if !configured { try configure() }
                    installNotifications()
                    if !session.isRunning { session.startRunning() }
                    interrupted = session.isInterrupted
                    if interrupted {
                        publish(.feedback("Camera is interrupted. Your progress is kept."))
                    } else if session.isRunning {
                        publish(.feedback(guidance))
                    } else {
                        fail("Camera could not start. Try again or use your puzzle fallback.")
                    }
                } catch {
                    fail("Camera is unavailable. Try again or use your puzzle fallback.")
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        queue.async { [self] in
            wantsRunning = false
            sink = nil
            detector.pause()
            lastFrameTime = nil
            lastSide = nil
            lastCode = nil
            if session.isRunning { session.stopRunning() }
        }
    }

    private var guidance: String {
        mode == .qr ? "Point the rear camera at your QR code." : "Place the phone to your side with your full body in view."
    }

    private func configure() throws {
        dispatchPrecondition(condition: .onQueue(queue))
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // Clean up partial configuration so a failed start is recoverable.
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        videoOutput = nil
        rotationObservation = nil
        rotation = nil
        session.sessionPreset = .medium
        let position: AVCaptureDevice.Position = mode == .qr ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CaptureFailure.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CaptureFailure.unavailable }
        session.addInput(input)
        if mode == .qr {
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { throw CaptureFailure.unavailable }
            session.addOutput(output)
            guard output.availableMetadataObjectTypes.contains(.qr) else { throw CaptureFailure.unavailable }
            output.metadataObjectTypes = [.qr]
            output.setMetadataObjectsDelegate(self, queue: queue)
        } else {
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            guard session.canAddOutput(output) else { throw CaptureFailure.unavailable }
            session.addOutput(output)
            output.setSampleBufferDelegate(self, queue: queue)
            videoOutput = output
            if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            rotation = coordinator
            applyRotation(coordinator.videoRotationAngleForHorizonLevelCapture)
            rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                self?.queue.async { [weak self] in self?.applyRotation(angle) }
            }
        }
        configured = true
    }

    private func applyRotation(_ angle: CGFloat) {
        // Quarter turns avoid resetting tracking for tiny changes in the phone's tilt.
        // Use the physical camera orientation even when the app's UI is portrait-locked.
        let captureAngle = ((angle / 90).rounded() * 90).truncatingRemainder(dividingBy: 360)
        guard let connection = videoOutput?.connection(with: .video), connection.isVideoRotationAngleSupported(captureAngle) else { return }
        if connection.videoRotationAngle != captureAngle {
            detector.pause()
            lastSide = nil
            connection.videoRotationAngle = captureAngle
        }
    }

    private func installNotifications() {
        guard notificationTokens.isEmpty else { return }
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.interruptionEndedNotification,
                     AVCaptureSession.runtimeErrorNotification] {
            notificationTokens.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] note in
                let reset = (note.userInfo?[AVCaptureSessionErrorKey] as? AVError)?.code == .mediaServicesWereReset
                self?.queue.async { [weak self] in self?.handleNotification(name, mediaReset: reset) }
            })
        }
    }

    private func handleNotification(_ name: Notification.Name, mediaReset: Bool) {
        guard wantsRunning else { return }
        detector.pause()
        lastFrameTime = nil
        lastSide = nil
        switch name {
        case AVCaptureSession.wasInterruptedNotification:
            interrupted = true
            publish(.feedback("Camera is interrupted. Return to Bob when the camera is available. Your progress is kept."))
        case AVCaptureSession.interruptionEndedNotification:
            interrupted = false
            if !session.isRunning { session.startRunning() }
            if session.isRunning { publish(.feedback(guidance)) }
            else { fail("Camera could not resume. Try again or use your puzzle fallback.") }
        default:
            configured = false
            if mediaReset {
                do {
                    if session.isRunning { session.stopRunning() }
                    try configure()
                    session.startRunning()
                    interrupted = session.isInterrupted
                    if session.isRunning { publish(.feedback(guidance)); return }
                } catch { /* Surface the recoverable failure below. */ }
            }
            fail("Camera stopped unexpectedly. Try again or use your puzzle fallback.")
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard wantsRunning, !interrupted else { return }
        let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        // Bound Vision work to about 15 fps. Capture timestamps, never wall time, drive credit.
        if let lastFrameTime, timestamp > lastFrameTime, timestamp - lastFrameTime < 1.0 / 15 { return }
        lastFrameTime = timestamp
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { lostTracking(); return }
        autoreleasepool {
            do {
                // Pixels already have the physical portrait/landscape orientation, without mirroring.
                try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([poseRequest])
                guard let bodies = poseRequest.results, bodies.count == 1,
                      let sample = makeSample(bodies[0], timestamp: timestamp,
                                              aspect: Double(CVPixelBufferGetWidth(buffer)) / Double(CVPixelBufferGetHeight(buffer))) else {
                    lostTracking()
                    return
                }
                let update = detector.consume(sample)
                publish(.feedback(update.feedback))
                if update.creditedDuration > 0 { publish(.activity(update.creditedDuration)) }
            } catch { lostTracking() }
        }
    }

    private func makeSample(_ body: VNHumanBodyPoseObservation, timestamp: TimeInterval, aspect: Double) -> PoseSample? {
        guard let points = try? body.recognizedPoints(.all) else { return nil }
        let sides: [[VNHumanBodyPoseObservation.JointName]] = [
            [.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftAnkle],
            [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightAnkle]
        ]
        let confidence = sides.map { side in side.map { Double(points[$0]?.confidence ?? 0) }.min() ?? 0 }
        let side: Int
        if let lastSide, confidence[lastSide ? 0 : 1] >= 0.6 { side = lastSide ? 0 : 1 }
        else { side = confidence[0] >= confidence[1] ? 0 : 1 }
        guard confidence[side] >= 0.6 else { return nil }
        if lastSide != nil && lastSide != (side == 0) { detector.pause() }
        lastSide = side == 0
        let joints = sides[side].compactMap { name -> PoseSample.Point? in
            guard let point = points[name] else { return nil }
            return .init(x: point.location.x * aspect, y: point.location.y, confidence: Double(point.confidence))
        }
        guard joints.count == 5 else { return nil }
        return PoseSample(timestamp: timestamp, shoulder: joints[0], elbow: joints[1], wrist: joints[2], hip: joints[3], ankle: joints[4])
    }

    private func lostTracking() {
        detector.pause()
        lastSide = nil
        publish(.feedback("Show one person's full body from the side, with enough light. Your progress is kept."))
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard wantsRunning, !interrupted else { return }
        let codes = metadataObjects.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
        guard codes.count == 1, let code = codes.first, !code.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard code != lastCode || now - lastCodeTime >= 1 else { return }
        lastCode = code
        lastCodeTime = now
        publish(.feedback("QR code detected."))
        publish(.code(code))
    }

    private func publish(_ event: CameraEvent) {
        dispatchPrecondition(condition: .onQueue(queue))
        if case .feedback(let message) = event {
            guard message != lastFeedback else { return }
            lastFeedback = message
        }
        sink?(event, generation)
    }

    private func fail(_ message: String) {
        wantsRunning = false
        detector.pause()
        if session.isRunning { session.stopRunning() }
        publish(.failed(message))
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private enum CaptureFailure: Error { case unavailable }
}
