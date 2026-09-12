import AVFoundation
import SwiftUI
import UIKit

@MainActor
public struct CameraPreview: UIViewRepresentable {
    private let session: AVCaptureSession

    public init(session: AVCaptureSession) { self.session = session }

    public func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.attach(session)
        return view
    }

    public func updateUIView(_ uiView: CameraPreviewView, context: Context) { uiView.attach(session) }

    public static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: ()) { uiView.detach() }
}

@MainActor
public final class CameraPreviewView: UIView {
    public override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var observation: NSKeyValueObservation?
    private var started: NSObjectProtocol?

    fileprivate func attach(_ session: AVCaptureSession) {
        guard preview.session !== session else { return }
        detach()
        preview.session = session
        preview.videoGravity = .resizeAspectFill
        isAccessibilityElement = true
        accessibilityLabel = "Live camera preview"
        started = NotificationCenter.default.addObserver(forName: AVCaptureSession.didStartRunningNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.configureRotation() }
        }
        configureRotation()
    }

    fileprivate func detach() {
        if let started { NotificationCenter.default.removeObserver(started) }
        started = nil
        observation = nil
        rotation = nil
        preview.session = nil
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        configureRotation()
    }

    private func configureRotation() {
        guard let device = (preview.session?.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        if rotation?.device !== device {
            observation = nil
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
            rotation = coordinator
            observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { @MainActor [weak self] in self?.applyRotation(angle) }
            }
        }
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = device.position == .front
        }
        if let rotation { applyRotation(rotation.videoRotationAngleForHorizonLevelPreview) }
    }

    private func applyRotation(_ angle: CGFloat) {
        guard let connection = preview.connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    isolated deinit {
        if let started { NotificationCenter.default.removeObserver(started) }
    }
}
