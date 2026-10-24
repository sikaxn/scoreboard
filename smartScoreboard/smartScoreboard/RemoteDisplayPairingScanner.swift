#if os(iOS)
import SwiftUI
import AVFoundation
import UIKit

/// Returning an error keeps the sheet open, so an unavailable display can be
/// discovered and scanned again without leaving the pairing flow.
struct RemoteDisplayPairingScanner: View {
    var onScan: (ScoreboardRemoteDisplayPairingCode) -> String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = RemoteDisplayPairingCamera()
    @State private var message: String?
    @State private var needsSettings = false
    @State private var isStarting = true
    @State private var scanAttempt = 0
    @State private var hasCompleted = false
    @State private var isVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Scan the QR code on the Remote Display's pairing screen.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    RemoteDisplayCameraPreview(session: camera.session)
                        .overlay {
                            if isStarting { ProgressView().tint(.white) }
                            if let message {
                                VStack(spacing: 12) {
                                    Image(systemName: needsSettings ? "camera.fill" : "exclamationmark.triangle")
                                        .font(.largeTitle)
                                    Text(message)
                                        .multilineTextAlignment(.center)
                                        .accessibilityIdentifier("remote.scan.error")
                                }
                                .foregroundStyle(.white)
                                .padding(24)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black.opacity(0.85))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .accessibilityHidden(message == nil)

                    if needsSettings {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else if message != nil {
                        Button("Scan Again") { scanAttempt += 1 }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("remote.scan.retry")
                    }

                    Text("Keep the display's pairing screen open. The display must appear in the nearby displays list before it can pair.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .navigationTitle("Scan to Pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { isVisible = true }
        .task(id: scanAttempt) { await startScanning() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { scanAttempt += 1 }
            else { camera.stop() }
        }
        .onDisappear {
            isVisible = false
            camera.stop()
        }
    }

    private func startScanning() async {
        guard isVisible, !hasCompleted, scenePhase == .active else { return }
        let attempt = scanAttempt
        message = nil
        needsSettings = false
        isStarting = true
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let authorized: Bool
        if status == .notDetermined {
            authorized = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            authorized = status == .authorized
        }
        guard !Task.isCancelled, isVisible, !hasCompleted, scenePhase == .active else { return }
        guard authorized else {
            isStarting = false
            needsSettings = AVCaptureDevice.authorizationStatus(for: .video) == .denied
            message = ScoreboardLocalization.string(needsSettings
                ? "Camera access is unavailable. Allow camera access in Settings to scan a pairing code, or cancel and enter the four-digit code manually."
                : "Camera access is restricted on this device. Cancel and enter the four-digit pairing code manually.")
            return
        }
        camera.start { event in
            guard isVisible, !hasCompleted, attempt == scanAttempt, scenePhase == .active else { return }
            isStarting = false
            switch event {
            case .ready:
                break
            case .unavailable:
                message = ScoreboardLocalization.string("No camera is available. Cancel and enter the four-digit pairing code manually.")
            case .failed:
                message = ScoreboardLocalization.string("The camera could not start. Try again, or cancel and enter the four-digit pairing code manually.")
            case .code(let value):
                guard let code = ScoreboardRemoteDisplayPairingCode(scannedValue: value) else {
                    message = ScoreboardLocalization.string("This is not a Scoreboard pairing QR code. Scan the QR code on the Remote Display's pairing screen.")
                    return
                }
                if let error = onScan(code) {
                    message = error
                } else {
                    hasCompleted = true
                    dismiss()
                }
            }
        }
    }
}

/// All session configuration, capture, and teardown run on the same serial queue.
nonisolated private final class RemoteDisplayPairingCamera: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    enum Event: Sendable { case ready, code(String), unavailable, failed }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "scoreboard.pairing-camera", qos: .userInitiated)
    private var configured = false
    private var onEvent: (@MainActor @Sendable (Event) -> Void)?
    private var notificationTokens: [NSObjectProtocol] = []

    override init() {
        super.init()
        for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification] {
            notificationTokens.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
                guard let self else { return }
                self.queue.async { [self] in self.finish(.failed) }
            })
        }
    }

    deinit {
        for token in notificationTokens { NotificationCenter.default.removeObserver(token) }
    }

    func start(onEvent: @escaping @MainActor @Sendable (Event) -> Void) {
        queue.async { [self] in
            self.onEvent = onEvent
            if !configured {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    ?? AVCaptureDevice.default(for: .video) else {
                    finish(.unavailable)
                    return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    let output = AVCaptureMetadataOutput()
                    session.beginConfiguration()
                    defer { session.commitConfiguration() }
                    guard session.canAddInput(input) else { finish(.failed); return }
                    session.addInput(input)
                    guard session.canAddOutput(output) else {
                        session.removeInput(input)
                        finish(.failed)
                        return
                    }
                    session.addOutput(output)
                    guard output.availableMetadataObjectTypes.contains(.qr) else {
                        session.removeInput(input)
                        session.removeOutput(output)
                        finish(.failed)
                        return
                    }
                    output.setMetadataObjectsDelegate(self, queue: queue)
                    output.metadataObjectTypes = [.qr]
                    configured = true
                } catch {
                    finish(.failed)
                    return
                }
            }
            if !session.isRunning { session.startRunning() }
            if session.isRunning { emit(.ready) }
            else { finish(.failed) }
        }
    }

    func stop() {
        queue.async { [self] in
            onEvent = nil
            if session.isRunning { session.stopRunning() }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard onEvent != nil,
              let value = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first else { return }
        // Return from the metadata callback before stopping capture.
        queue.async { [self] in finish(.code(value)) }
    }

    private func emit(_ event: Event) {
        guard let callback = onEvent else { return }
        Task { @MainActor in callback(event) }
    }

    private func finish(_ event: Event) {
        emit(event)
        onEvent = nil
        if session.isRunning { session.stopRunning() }
    }
}

private struct RemoteDisplayCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let connection = previewLayer.connection,
                  let orientation = window?.windowScene?.interfaceOrientation else { return }
            let angle: CGFloat
            switch orientation {
            case .landscapeLeft: angle = 180
            case .landscapeRight: angle = 0
            case .portraitUpsideDown: angle = 270
            default: angle = 90
            }
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        }
    }
}
#endif
