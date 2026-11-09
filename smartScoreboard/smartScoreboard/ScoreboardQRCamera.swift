#if os(iOS)
import SwiftUI
@preconcurrency import AVFoundation
import UIKit

struct ScoreboardQRScannerView: View {
    var found: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var allowed: Bool?
    @State private var cameraError: String?
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                if allowed == true, cameraError == nil {
                    ScoreboardQRCameraPreview(found: found, failed: { cameraError = $0 })
                    Text("Point at the QR code. Tap to focus or pinch to zoom.")
                        .font(.callout).multilineTextAlignment(.center).padding(14)
                        .foregroundStyle(.white).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                        .padding(20).allowsHitTesting(false)
                } else if allowed == nil { ProgressView().tint(.white).frame(maxHeight: .infinity) }
                else {
                    ContentUnavailableView("Camera Unavailable", systemImage: "camera",
                        description: Text(cameraError ?? "Allow camera access in Settings, or enter the pairing code or import a QR image."))
                        .foregroundStyle(.white).frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Scan Pairing Code")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .task { allowed = await AVCaptureDevice.requestAccess(for: .video) }
    }
}

private struct ScoreboardQRCameraPreview: UIViewControllerRepresentable {
    let found: (String) -> Void
    let failed: (String) -> Void
    func makeUIViewController(context: Context) -> ScoreboardQRCameraController { .init(found: found, failed: failed) }
    func updateUIViewController(_ controller: ScoreboardQRCameraController, context: Context) {}
    static func dismantleUIViewController(_ controller: ScoreboardQRCameraController, coordinator: ()) { controller.stop() }
}

private final class ScoreboardQRCameraController: UIViewController {
    private let found: (String) -> Void
    private let failed: (String) -> Void
    private var camera: ScoreboardQRCamera?
    private let preview = AVCaptureVideoPreviewLayer()
    init(found: @escaping (String) -> Void, failed: @escaping (String) -> Void) {
        self.found = found; self.failed = failed
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let camera = ScoreboardQRCamera(found: { [weak self] value in
            Task { @MainActor [weak self] in self?.found(value) }
        }, failed: { [weak self] error in
            Task { @MainActor [weak self] in self?.failed(error) }
        }, ready: { [weak self] in
            Task { @MainActor [weak self] in self?.view.setNeedsLayout() }
        })
        self.camera = camera
        preview.session = camera.session; preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:))))
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); camera?.start() }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); preview.frame = view.bounds
        if let connection = preview.connection, let orientation = view.window?.windowScene?.interfaceOrientation {
            let angle: CGFloat = switch orientation {
            case .landscapeLeft: 0
            case .landscapeRight: 180
            case .portraitUpsideDown: 270
            default: 90
            }
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        }
    }
    func stop() { camera?.stop(); preview.session = nil }
    @objc private func focus(_ gesture: UITapGestureRecognizer) {
        camera?.focus(at: preview.captureDevicePointConverted(fromLayerPoint: gesture.location(in: view)))
    }
    @objc private func zoom(_ gesture: UIPinchGestureRecognizer) {
        camera?.zoom(by: gesture.scale); gesture.scale = 1
    }
}

/// Capture configuration, autofocus, start and stop never block the UI thread.
nonisolated private final class ScoreboardQRCamera: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "scoreboard.qr-camera", qos: .userInitiated)
    private let found: @Sendable (String) -> Void
    private let failed: @Sendable (String) -> Void
    private let ready: @Sendable () -> Void
    private var device: AVCaptureDevice?
    private var configured = false
    private var finished = false
    init(found: @escaping @Sendable (String) -> Void, failed: @escaping @Sendable (String) -> Void, ready: @escaping @Sendable () -> Void) {
        self.found = found; self.failed = failed; self.ready = ready
        super.init()
    }
    func start() {
        queue.async { [self] in
            do {
                if !configured { try configure() }
                if !session.isRunning { session.startRunning() }
                ready()
            } catch { failed(error.localizedDescription) }
        }
    }
    func stop() { queue.async { [self] in if session.isRunning { session.stopRunning() } } }
    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { throw URLError(.resourceUnavailable) }
        let input = try AVCaptureDeviceInput(device: device), output = AVCaptureMetadataOutput()
        session.beginConfiguration(); defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard session.canAddInput(input), session.canAddOutput(output) else { throw URLError(.cannotOpenFile) }
        session.addInput(input); session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: queue); output.metadataObjectTypes = [.qr]
        self.device = device
        try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        device.isSubjectAreaChangeMonitoringEnabled = true
        configured = true
    }
    func focus(at point: CGPoint) {
        queue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = point }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = point }
        }
    }
    func zoom(by factor: CGFloat) {
        queue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = min(min(device.activeFormat.videoMaxZoomFactor, 6), max(1, device.videoZoomFactor * factor))
        }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !finished, let value = objects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first else { return }
        finished = true; found(value); stop()
    }
}
#endif
