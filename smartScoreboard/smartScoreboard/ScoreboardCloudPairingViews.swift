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
    var size: CGFloat = 150
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
                .frame(width: size, height: size).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Pairing QR Code")
        }
    }
}

struct ScoreboardCloudRemoteSection: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    let mode: ScoreboardRemoteDisplayNetworkMode
    var enableCloud: (() -> Void)? = nil
    var permitsSessionJoining = true
    @State private var confirmsForget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !permitsSessionJoining {
                RemotePairingCard("Session Host") {
                    hint("Finish hosting this match before pairing with another host. You can configure the cloud service below.")
                }
            } else if !mode.allowsCloud {
                RemotePairingCard("Connection") {
                    hint("Choose a cloud preference to pair or join through the cloud. You can configure your server below first.")
                    RemotePairingActionButton(title: "Prefer Cloud", symbol: "cloud", primary: true, disabled: enableCloud == nil) { enableCloud?() }
                }
            }
            serviceSection
            if cloud.isLinked { registeredSection }
            else { pairingSection }
        }
        .confirmationDialog("Forget Cloud Account?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget Cloud Account", role: .destructive) { cloud.disconnect() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes cloud registration from this device. Nearby pairing is kept.") }
        .task(id: mode) {
            if !permitsSessionJoining && cloud.isRemotePairing { cloud.cancelLink() }
            else if mode.allowsCloud && cloud.isLinked { await cloud.refreshSessions() }
            else if !mode.allowsCloud && cloud.isRemotePairing { cloud.cancelLink() }
        }
    }

    private var serviceSection: some View {
        RemotePairingCard("Cloud Service") {
            RemotePairingActionButton(title: "Public Cloud (Experimental)", symbol: "cloud",
                selected: cloud.serviceMode == .publicCloud, disabled: cloud.isLinked || cloud.isLinking) {
                cloud.serviceMode = .publicCloud
            }.accessibilityIdentifier("remote.cloud.public")
            RemotePairingActionButton(title: "Self-hosted", symbol: "server.rack",
                selected: cloud.serviceMode == .selfHosted, disabled: cloud.isLinked || cloud.isLinking) {
                cloud.serviceMode = .selfHosted
            }.accessibilityIdentifier("remote.cloud.selfHosted")
            if cloud.serviceMode == .selfHosted {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Service URL").font(.system(size: RemotePairingAppearance.captionSize, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                    TextField("https://your-scoreboard-server.com", text: $cloud.selfHostedURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: RemotePairingAppearance.bodySize))
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .padding(16)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .disabled(cloud.isLinked || cloud.isLinking)
                        .accessibilityIdentifier("remote.cloud.selfHostedURL")
                }
            } else {
                Text(verbatim: ScoreboardCloudEndpoint.publicServiceURL)
                    .font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if cloud.isLinked {
                hint("Forget this cloud account before changing servers.")
                RemotePairingActionButton(title: "Change Cloud Service", symbol: "server.rack") { confirmsForget = true }
            }
            else if cloud.isLinking { hint("Cancel linking below to change the cloud service or server address.") }
        }
    }

    private var registeredSection: some View {
        RemotePairingCard("Host Session") {
            if let account = cloud.account {
                Text(verbatim: account.name).font(.system(size: RemotePairingAppearance.bodySize, weight: .semibold)).foregroundStyle(.white)
            }
            let sessions = cloud.sessions.filter { $0.hostDeviceID == nil || $0.hostDeviceID != cloud.deviceID }
            if sessions.isEmpty {
                hint("Enable Cloud Hosting on a device registered to this account, then refresh the hosts.")
            }
            ForEach(sessions) { session in
                RemotePairingActionButton(title: session.name, symbol: "display", selected: cloud.selectedSessionID == session.id,
                    disabled: !mode.allowsCloud || !permitsSessionJoining, verbatim: true) { cloud.selectSession(session.id) }
            }
            Text(cloud.status).font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            RemotePairingActionButton(title: "Refresh Hosts", symbol: "arrow.clockwise", disabled: !mode.allowsCloud) { Task { await cloud.refreshSessions() } }
            if !cloud.selectedSessionID.isEmpty {
                RemotePairingActionButton(title: "Reconnect Cloud", symbol: "arrow.triangle.2.circlepath", disabled: !mode.allowsCloud || !permitsSessionJoining) { cloud.reconnect() }
            }
            RemotePairingActionButton(title: "Forget Cloud Account", symbol: "person.crop.circle.badge.xmark", destructive: true) { confirmsForget = true }
        }
    }

    private var pairingSection: some View {
        RemotePairingCard("Cloud Pairing Code") {
            if let code = cloud.linkCode {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 28) {
                        pairingCode(code).frame(maxWidth: .infinity)
                        if let url = cloud.verificationURL { ScoreboardPairingQRCode(value: url.absoluteString, size: RemotePairingAppearance.qrSize) }
                    }
                    VStack(spacing: 24) {
                        pairingCode(code)
                        if let url = cloud.verificationURL { ScoreboardPairingQRCode(value: url.absoluteString, size: RemotePairingAppearance.qrSize) }
                    }.frame(maxWidth: .infinity)
                }
                hint("On the signed-in host, open Cloud settings and enter or scan this code. This device does not need to sign in.")
                RemotePairingActionButton(title: "New Pairing Code", symbol: "arrow.clockwise", disabled: !mode.allowsCloud || !permitsSessionJoining) { cloud.cancelLink(); cloud.beginLink(remote: true) }
            } else {
                hint("Register this display from your signed-in host, then choose a host session here.")
                if cloud.isLinking {
                    ProgressView().tint(.white)
                } else {
                    RemotePairingActionButton(title: "Show Cloud Pairing Code", symbol: "qrcode", primary: true,
                        disabled: !mode.allowsCloud || !permitsSessionJoining || cloud.serviceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { cloud.beginLink(remote: true) }
                }
            }
            Text(cloud.status).font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            if cloud.isLinking {
                RemotePairingActionButton(title: "Cancel Linking", symbol: "xmark.circle") { cloud.cancelLink() }
            }
        }
    }

    private func pairingCode(_ code: String) -> some View {
        Text(code).font(.system(size: 40, weight: .bold, design: .monospaced))
            .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            .accessibilityIdentifier("remote.cloud.pairingCode")
    }
    private func hint(_ text: String) -> some View {
        Text(verbatim: ScoreboardLocalization.string(text))
            .font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
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
        ScoreboardCloudSection("Pair a Device", footer: "Remote devices show a code or QR code. Registration grants access to this account's sessions; control needs approval for each host.") {
            ScoreboardCloudSettingsRow("Cloud Pairing Code") {
                TextField("Cloud Pairing Code", text: $code)
                    .autocorrectionDisabled().scoreboardCloudSettingsField()
            }
            ScoreboardCloudSettingsDivider()
            ScoreboardCloudSettingsRow("Account") {
                Button("Register Device") {
                    Task {
                        do { try await cloud.approveRemote(code: code); feedback = "Device registered. Choose a host session on that device."; code = "" }
                        catch { feedback = error.localizedDescription }
                    }
                }.disabled(!cloud.isLinked || cloud.isRemoteRegistration || code.isEmpty)
            }
            #if !os(tvOS)
            ScoreboardCloudSettingsDivider()
            ScoreboardCloudSettingsRow("Pairing QR Code") {
                VStack(alignment: .leading, spacing: 10) {
                    #if os(iOS)
                    if DataScannerViewController.isSupported {
                        Button("Scan Pairing QR Code", systemImage: "qrcode.viewfinder") { scansQR = true }
                    }
                    #endif
                    #if !os(tvOS)
                    Button("Import Pairing QR Image", systemImage: "qrcode") { importsQR = true }
                    #endif
                }
            }
            #endif
            if !store.isRemoteDisplayHostEnabled {
                ScoreboardCloudSettingsDivider()
                ScoreboardCloudSettingsRow("Connection") {
                    Button("Discover Nearby Devices") { store.setRemoteDisplayHostEnabled(true) }
                }
            }
            ForEach(store.remoteDisplaySources.filter { !$0.isSessionInfrastructure && $0.allowsNewPairing }) { source in
                ScoreboardCloudSettingsDivider()
                ScoreboardCloudSettingsRow(source.name, verbatim: true) {
                    Button("Pair Nearby") { selectedNearby = source; nearbyCode = ""; asksNearbyCode = true }
                }
            }
            if !feedback.isEmpty {
                ScoreboardCloudSettingsDivider()
                Text(feedback).font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    .accessibilityIdentifier("cloud.pairingFeedback")
            }
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
