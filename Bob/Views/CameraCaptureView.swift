import SwiftUI
import AVFoundation

/// Owns only the visible capture surface. Verification remains in the camera and app layers.
struct CameraCaptureView: View {
    @State private var controller: CameraController?
    @State private var startTask: Task<Void, Never>?
    @State private var isMounted = false
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    private let registration: Bool
    private let mode: CameraController.Mode
    private let onActivity: (TimeInterval) -> Void
    private let onCode: (String) -> Void

    init(mode: CameraController.Mode,
         registration: Bool = false,
         onActivity: @escaping (TimeInterval) -> Void = { _ in },
         onCode: @escaping (String) -> Void = { _ in }) {
        self.registration = registration
        self.mode = mode
        self.onActivity = onActivity
        self.onCode = onCode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let controller {
                captureSurface(controller)
            } else {
                ProgressView("Getting the camera ready…")
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
            Text("Processed on this iPhone. Camera footage isn't saved.")
                .font(.caption)
                .foregroundStyle(BobTheme.secondaryText)
        }
        .onAppear {
            isMounted = true
            startCapture()
        }
        .onScrollVisibilityChange(threshold: 0.05) { visible in
            isVisible = visible
            if visible { startCapture() } else { stopCapture() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startCapture() } else { stopCapture() }
        }
        .onDisappear {
            isMounted = false
            isVisible = false
            stopCapture()
        }
    }

    @ViewBuilder private func captureSurface(_ controller: CameraController) -> some View {
        if controller.permissionDenied {
            BobNotice(title: "Camera access is off",
                      message: registration
                        ? "Allow the camera in iPhone Settings, or go back and choose a puzzle challenge."
                        : "Allow the camera in iPhone Settings, or use the puzzle fallback for this morning.",
                      symbol: "camera")
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Text("Open iPhone settings").frame(minHeight: 44)
            }
            .accessibilityIdentifier("camera.settings")
        } else {
            CameraPreview(session: controller.session)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxHeight: 340)
                .clipShape(RoundedRectangle(cornerRadius: BobTheme.controlRadius))
                .accessibilityHidden(true)
            Text(controller.feedback)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("camera.feedback")
            Button {
                stopCapture()
                startCapture()
            } label: {
                Text("Restart camera").frame(minHeight: 44)
            }
            .accessibilityIdentifier("camera.restart")
        }
    }

    private func startCapture() {
        guard isMounted, isVisible, scenePhase == .active else { return }
        if controller == nil {
            controller = CameraController(mode: mode, onActivity: onActivity, onCode: onCode)
        }
        guard let controller else { return }
        startTask?.cancel()
        // CameraController's generation guard invalidates starts that outlive stop().
        startTask = Task {
            guard !Task.isCancelled, isMounted, isVisible, scenePhase == .active else { return }
            await controller.start()
        }
    }

    private func stopCapture() {
        startTask?.cancel()
        startTask = nil
        controller?.stop()
    }
}

struct QRRegistrationView: View {
    let onRegistered: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var capturedCode: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pick a place for your morning.")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Point the camera at the QR code you want Bob to recognize. The code stays on your iPhone.")
                    .foregroundStyle(BobTheme.secondaryText)
                BobSection {
                    if let code = capturedCode {
                        BobNotice(title: "Code captured", message: "Use this same code for your morning challenge.",
                                  symbol: "checkmark.circle")
                        DisclosureGroup {
                            Text(code).textSelection(.enabled).padding(.top, 8)
                        } label: {
                            Text("View code content").frame(minHeight: 44)
                        }
                        Button("Scan again") { capturedCode = nil }
                            .frame(minHeight: 44)
                        Button("Use this code") { onRegistered(code) }
                            .buttonStyle(BobButtonStyle())
                            .accessibilityIdentifier("alarm.qr.confirm")
                    } else {
                        CameraCaptureView(mode: .qr, registration: true, onCode: { code in
                            if capturedCode == nil && !code.isEmpty { capturedCode = code }
                        })
                        Text("If the camera is unavailable, go back and choose a puzzle. You can register a QR code later.")
                            .font(.footnote)
                            .foregroundStyle(BobTheme.secondaryText)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .bobScreen()
        .navigationTitle("Register QR code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.frame(minHeight: 44)
            }
        }
    }
}
