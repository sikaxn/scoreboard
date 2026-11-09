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
    var showsServiceConfiguration = true
    @State private var confirmsForget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if showsServiceConfiguration { serviceSection }
            if permitsSessionJoining {
                RemotePairingCard("Join a Match") {
                    ScoreboardMatchGuestJoinForm(beforeConnect: { control in
                        try ScoreboardStore.shared.prepareJoiningMatch(asDisplay: !control)
                        if !mode.allowsCloud { enableCloud?() }
                    }, joined: { ScoreboardStore.shared.commitJoinedMatch() },
                       failed: { if ScoreboardStore.shared.isPreparingMatchJoin { ScoreboardStore.shared.leaveJoinedMatch() } })
                    if cloud.isConnected {
                        Text(cloud.status).font(.callout)
                        Button("Leave Cloud Match") { cloud.leaveGuestMatch() }
                    }
                }
            }
        }
        .confirmationDialog("Forget Cloud Access?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget Cloud Access", role: .destructive) { cloud.disconnect() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes cloud credentials from this device. You can then choose another cloud service.") }
    }

    private var serviceSection: some View {
        RemotePairingCard("Cloud Service") {
            Toggle("Enable Cloud", isOn: $cloud.cloudEnabled).scoreboardCloudSettingsToggleStyle()
            Text(cloud.status).font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.7))
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
                hint("Forget this cloud connection before changing servers.")
                RemotePairingActionButton(title: "Change Cloud Service", symbol: "server.rack") { confirmsForget = true }
            }
            else if cloud.isLinking { hint("Cancel linking below to change the cloud service or server address.") }
        }
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
    @State private var nearbyCodes: [String: String] = [:]
    @State private var asksTakeover = false
    #if !os(tvOS)
    @State private var importsQR = false
    #endif
    #if os(iOS)
    @State private var scansQR = false
    #endif
    var body: some View {
        ScoreboardCloudSection("Add a Nearby Device", footer: "Open the pairing screen on the other device, then enter its 4-digit device PIN. No cloud account is required.") {
            #if !os(tvOS)
            ScoreboardCloudSettingsDivider()
            ScoreboardCloudSettingsRow("Pairing QR Code") {
                VStack(alignment: .leading, spacing: 10) {
                    #if os(iOS)
                    if AVCaptureDevice.default(for: .video) != nil {
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
            ForEach(store.remoteDisplaySources.filter { !$0.isSessionInfrastructure && $0.allowsNewPairing && !store.isTrustedRemoteDisplay($0) }) { source in
                ScoreboardCloudSettingsDivider()
                ScoreboardCloudSettingsRow(source.name, verbatim: true) {
                    HStack {
                        TextField("4-digit PIN", text: Binding(get: { nearbyCodes[source.id] ?? "" }, set: { nearbyCodes[source.id] = String($0.filter(\.isNumber).prefix(4)) }))
                            .scoreboardCloudSettingsField().frame(maxWidth: 130)
                            .accessibilityIdentifier("connection.pairingCode.\(source.id)")
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Button("Pair") { pendingNearby = (source.id, nearbyCodes[source.id] ?? ""); tryNearby() }
                            .disabled(nearbyCodes[source.id]?.count != 4)
                            .accessibilityIdentifier("connection.pair.\(source.id)")
                    }
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
        case .cloud:
            feedback = "Guests use a match invitation. Owner sign-in links open in a browser; nearby pairing does not register a cloud account."
        case nil: feedback = "This is not a Smart Scoreboard pairing code."
        }
    }
    private func tryNearby() {
        guard let pendingNearby, let source = store.remoteDisplaySources.first(where: { $0.id == pendingNearby.0 }) else { return }
        selectedNearby = source
        guard source.allowsNewPairing else { feedback = "Open the pairing screen on this device first."; return }
        let operatorID = store.remoteDisplayHostID
        if source.needsTakeoverConfirmation(currentOperatorID: operatorID) { asksTakeover = true }
        else { finishNearby(takeover: false) }
    }
    private func finishNearby(takeover: Bool) {
        guard let pendingNearby, let source = selectedNearby else { return }
        store.pairRemoteDisplay(source, pairingCode: pendingNearby.1, takeoverConfirmed: takeover)
        self.pendingNearby = nil; feedback = "Pairing with \(source.name)…"
    }
}
