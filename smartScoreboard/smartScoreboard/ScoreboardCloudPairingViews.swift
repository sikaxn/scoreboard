import SwiftUI
import CoreImage.CIFilterBuiltins
#if !os(tvOS)
import UniformTypeIdentifiers
#endif
#if os(iOS)
import VisionKit
import Vision
import AVFoundation
#endif

struct ScoreboardPairingQRCode: View {
    let value: String
    private var image: CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        guard let output = filter.outputImage else { return nil }
        let enlarged = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return CIContext().createCGImage(enlarged, from: enlarged.extent)
    }
    var body: some View {
        if let image {
            Image(decorative: image, scale: 1)
                .resizable().interpolation(.none).scaledToFit()
                .frame(width: 150, height: 150).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Pairing QR Code")
        }
    }
}

struct ScoreboardCloudRemoteSection: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    let mode: ScoreboardRemoteDisplayNetworkMode
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if mode.allowsCloud {
                Label("Cloud Connection", systemImage: "cloud") .font(.headline)
                if !cloud.isLinked {
                    Picker("Cloud Service", selection: $cloud.serviceMode) {
                        Text("Public Cloud (Experimental)").tag(ScoreboardCloudServiceMode.publicCloud)
                        Text("Self-hosted").tag(ScoreboardCloudServiceMode.selfHosted)
                    }.disabled(cloud.isLinking)
                    if cloud.serviceMode == .selfHosted {
                        TextField("https://your-scoreboard-server.com", text: $cloud.selfHostedURL)
                            .autocorrectionDisabled().disabled(cloud.isLinking)
                    }
                    if cloud.isLinking { Button("Change Cloud Service") { cloud.cancelLink() } }
                }
                if cloud.isLinked {
                    if let account = cloud.account { Text(account.name).font(.subheadline) }
                    Picker("Host Session", selection: Binding(get: { cloud.selectedSessionID }, set: { cloud.selectSession($0) })) {
                        Text("Choose a host").tag("")
                        ForEach(cloud.sessions.filter { $0.hostDeviceID == nil || $0.hostDeviceID != cloud.deviceID }) { session in Text(session.name).tag(session.id) }
                    }
                    .accessibilityIdentifier("cloud.sessionPicker")
                    HStack {
                        Button("Refresh Hosts") { Task { await cloud.refreshSessions() } }
                        Button("Reconnect Cloud") { cloud.reconnect() }
                    }
                    Text(cloud.status).font(.footnote)
                    Button("Forget Cloud Account", role: .destructive) { cloud.disconnect() }
                } else if let code = cloud.linkCode {
                    Text("Cloud Pairing Code").font(.subheadline)
                    Text(code).font(.title.monospaced())
                    if let url = cloud.verificationURL { ScoreboardPairingQRCode(value: url.absoluteString) }
                    Text("On the signed-in host, open Cloud settings and enter or scan this code. This device does not need to sign in.").font(.footnote)
                    Button("New Pairing Code") { cloud.cancelLink(); cloud.beginLink(remote: true) }
                } else {
                    Button("Show Cloud Pairing Code") { cloud.beginLink(remote: true) }.disabled(cloud.isLinking)
                    Text(cloud.status).font(.footnote)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: mode) {
            if mode.allowsCloud {
                if cloud.isLinked { await cloud.refreshSessions() }
                else if !cloud.isLinking { cloud.beginLink(remote: true) }
            } else if cloud.isRemotePairing { cloud.cancelLink() }
        }
    }
}

struct ScoreboardDevicePairingSection: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @ObservedObject private var store = ScoreboardStore.shared
    @State private var code = ""
    @State private var feedback = ""
    @State private var pendingNearby: (String, String)?
    @State private var selectedNearby: ScoreboardRemoteDisplaySource?
    @State private var nearbyCode = ""
    @State private var asksNearbyCode = false
    @State private var asksTakeover = false
    #if !os(tvOS)
    @State private var importsQR = false
    #endif
    #if os(iOS)
    @State private var scansQR = false
    #endif
    var body: some View {
        ScoreboardCloudSection("Pair a Device") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TextField("Cloud Pairing Code", text: $code).autocorrectionDisabled()
                    Button("Register Device") {
                        Task {
                            do { try await cloud.approveRemote(code: code); feedback = "Device registered. Choose a host session on that device."; code = "" }
                            catch { feedback = error.localizedDescription }
                        }
                    }.disabled(!cloud.isLinked || cloud.isRemoteRegistration || code.isEmpty)
                }
                Text("Remote devices show a code or QR code. Registration grants access to this account's sessions; control needs approval for each host.").font(.footnote)
                HStack {
                    #if os(iOS)
                    if DataScannerViewController.isSupported {
                        Button("Scan Pairing QR Code", systemImage: "qrcode.viewfinder") { scansQR = true }
                    }
                    #endif
                    #if !os(tvOS)
                    Button("Import Pairing QR Image", systemImage: "qrcode") { importsQR = true }
                    #endif
                }
                if !store.isRemoteDisplayHostEnabled {
                    Button("Discover Nearby Devices") { store.setRemoteDisplayHostEnabled(true) }
                }
                ForEach(store.remoteDisplaySources.filter { !$0.isSessionInfrastructure && $0.allowsNewPairing }) { source in
                    HStack {
                        Label(source.name, systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Button("Pair Nearby") { selectedNearby = source; nearbyCode = ""; asksNearbyCode = true }
                    }
                }
                if !feedback.isEmpty { Text(feedback).font(.footnote).accessibilityIdentifier("cloud.pairingFeedback") }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: store.remoteDisplaySources.map(\.id)) { _, _ in tryNearby() }
        .alert("Nearby Pairing Code", isPresented: $asksNearbyCode) {
            TextField("4-digit code", text: $nearbyCode)
            Button("Pair") {
                if let source = selectedNearby { pendingNearby = (source.id, nearbyCode); tryNearby() }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enter the code shown on the remote device.") }
        .confirmationDialog("Replace This Device's Existing Pairing?", isPresented: $asksTakeover, titleVisibility: .visible) {
            Button("Replace Pairing", role: .destructive) { finishNearby(takeover: true) }
            Button("Cancel", role: .cancel) { pendingNearby = nil }
        } message: { Text("The remote device already has an operator. Only continue if you intend to replace that pairing.") }
        #if !os(tvOS)
        .fileImporter(isPresented: $importsQR, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let image = CIImage(data: try Data(contentsOf: url)),
                      let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
                      let value = (detector.features(in: image).first as? CIQRCodeFeature)?.messageString else {
                    feedback = "No pairing QR code found in this image."; return
                }
                handleQR(value)
            } catch { feedback = error.localizedDescription }
        }
        #endif
        #if os(iOS)
        .sheet(isPresented: $scansQR) { ScoreboardQRScannerView { value in scansQR = false; handleQR(value) } }
        #endif
    }
    private func handleQR(_ value: String) {
        switch ScoreboardPairingLink.parse(value) {
        case .nearby(let id, let code):
            pendingNearby = (id, code)
            if !store.isRemoteDisplayHostEnabled { store.setRemoteDisplayHostEnabled(true) }
            feedback = "Looking for the nearby device…"; tryNearby()
        case .cloud(let code, let origin):
            guard let selected = try? ScoreboardCloudEndpoint.validate(cloud.serviceURL),
                  let scanned = try? ScoreboardCloudEndpoint.validate(origin), selected.scheme == scanned.scheme,
                  selected.host == scanned.host, selected.port == scanned.port else {
                feedback = "This code belongs to a different cloud service. Choose that service in Cloud settings first."; return
            }
            self.code = code
            Task {
                do { try await cloud.approveRemote(code: code); feedback = "Device registered. Choose its host session on the remote device." }
                catch { feedback = error.localizedDescription }
            }
        case nil: feedback = "This is not a Smart Scoreboard pairing code."
        }
    }
    private func tryNearby() {
        guard let pendingNearby, let source = store.remoteDisplaySources.first(where: { $0.id == pendingNearby.0 }) else { return }
        selectedNearby = source
        guard source.allowsNewPairing else { feedback = "Open the pairing screen on this device first."; return }
        let operatorID = store.sessionDescriptor?.ownerHostID ?? ScoreboardRemoteDisplayReceiver.shared.displayID
        if source.needsTakeoverConfirmation(currentOperatorID: operatorID) { asksTakeover = true }
        else { finishNearby(takeover: false) }
    }
    private func finishNearby(takeover: Bool) {
        guard let pendingNearby, let source = selectedNearby else { return }
        store.pairRemoteDisplay(source, pairingCode: pendingNearby.1, takeoverConfirmed: takeover)
        self.pendingNearby = nil; feedback = "Pairing with \(source.name)…"
    }
}

#if os(iOS)
private struct ScoreboardQRScannerView: View {
    var found: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var allowed = false
    var body: some View {
        NavigationStack {
            Group {
                if allowed && DataScannerViewController.isAvailable { ScoreboardQRScanner(found: found) }
                else { ContentUnavailableView("Camera Unavailable", systemImage: "camera", description: Text("Use the pairing code or import a QR image instead.")) }
            }
            .navigationTitle("Scan Pairing Code")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .task { allowed = await AVCaptureDevice.requestAccess(for: .video) }
    }
}
private struct ScoreboardQRScanner: UIViewControllerRepresentable {
    var found: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(found: found) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }
    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) { controller.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let found: (String) -> Void
        private var finished = false
        init(found: @escaping (String) -> Void) { self.found = found }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !finished else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    finished = true; found(value); return
                }
            }
        }
    }
}
#endif

struct ScoreboardCloudSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: () -> Content
    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.content = content
    }
    var body: some View {
        #if os(tvOS)
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            content()
        }.padding(20).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        #else
        GroupBox(title) { content() }
        #endif
    }
}
