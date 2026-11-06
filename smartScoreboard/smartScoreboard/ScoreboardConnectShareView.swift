import SwiftUI
#if !os(tvOS)
import CoreImage
import UniformTypeIdentifiers
#endif

struct ScoreboardMatchGuestJoinForm: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    var initialInvitation: ScoreboardMatchInvitation? = nil
    var beforeConnect: ((Bool) throws -> Void)? = nil
    var joined: (() -> Void)? = nil
    var failed: (() -> Void)? = nil
    var receivedNearbyInvitation: ((ScoreboardNearbyInvitation) -> Void)? = nil
    @State private var code = ""
    @State private var password = ""
    @State private var server = ScoreboardCloudEndpoint.publicServiceURL
    @State private var requestsControl = false
    @State private var busy = false
    @State private var feedback = ""
    @State private var joinTask: Task<Void, Never>?
    @State private var confirmsServer = false
    #if !os(tvOS)
    @State private var importsQR = false
    #endif
    #if os(iOS)
    @State private var scans = false
    #endif
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Code or Link").font(.title2.bold())
            Text("No account needed. Enter an invitation and choose how to participate.").font(.callout).foregroundStyle(.secondary)
            if !cloud.cloudEnabled {
                Toggle("Allow Cloud Connections", isOn: $cloud.cloudEnabled).scoreboardCloudSettingsToggleStyle()
                Text("Online invitations require an internet connection. Nearby joining works independently.").font(.caption).foregroundStyle(.secondary)
            }
            TextField("Match code or invitation link", text: $code).autocorrectionDisabled().scoreboardCloudSettingsField()
                .accessibilityIdentifier("join.matchCode")
            SecureField("Match password", text: $password).scoreboardCloudSettingsField().accessibilityIdentifier("join.password")
            TextField("Cloud server URL", text: $server).autocorrectionDisabled().scoreboardCloudSettingsField()
            #if os(tvOS)
            HStack(spacing: 24) {
                RemotePairingActionButton(title: "Display", symbol: "tv", selected: !requestsControl) { requestsControl = false }
                RemotePairingActionButton(title: "Control Board", symbol: "gamecontroller", detail: "Requires host approval", selected: requestsControl) { requestsControl = true }
            }.focusSection()
            #else
            Picker("Join as", selection: $requestsControl) { Text("Display").tag(false); Text("Controller · owner approval").tag(true) }
                .pickerStyle(.menu)
            #endif
            LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 12) {
                Button(busy ? "Joining…" : "Join Match", systemImage: "arrow.right.circle") {
                    if server != cloud.serviceURL && !ScoreboardCloudEndpoint.isPublicService(server) { confirmsServer = true }
                    else { submit() }
                }.buttonStyle(.borderedProminent).disabled(busy || code.isEmpty || password.count < 6 || !cloud.cloudEnabled)
                    .accessibilityIdentifier("join.submit")
                #if os(iOS)
                Button("Scan QR", systemImage: "qrcode.viewfinder") { scans = true }.buttonStyle(.bordered)
                #endif
                #if !os(tvOS)
                Button("Import QR", systemImage: "qrcode") { importsQR = true }.buttonStyle(.bordered)
                #endif
            }
            if !feedback.isEmpty { Text(feedback).font(.callout).accessibilityIdentifier("join.feedback") }
        }
        .onAppear { server = initialInvitation?.server ?? cloud.serviceURL; if let invitation = initialInvitation { apply(invitation) } }
        .onChange(of: code) { _, value in
            if let invitation = ScoreboardMatchInvitation.parse(value) { apply(invitation) }
            else if let invitation = ScoreboardNearbyInvitation.parse(value), let receivedNearbyInvitation {
                receivedNearbyInvitation(invitation); code = ""
            }
        }
        .onDisappear { joinTask?.cancel(); joinTask = nil }
        .confirmationDialog("Join a Self-hosted Service?", isPresented: $confirmsServer, titleVisibility: .visible) {
            Button("Join This Service") { submit() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(server) }
        #if !os(tvOS)
        .fileImporter(isPresented: $importsQR, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let image = CIImage(data: try Data(contentsOf: url)),
                      let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
                      let value = (detector.features(in: image).first as? CIQRCodeFeature)?.messageString else {
                    feedback = "No match invitation QR code found in this image."; return
                }
                receive(value)
            } catch { feedback = error.localizedDescription }
        }
        #endif
        #if os(iOS)
        .sheet(isPresented: $scans) { ScoreboardQRScannerView { value in
            scans = false
            receive(value)
        }}
        #endif
    }
    private var actionColumns: [GridItem] {
        #if os(tvOS)
        [GridItem(.flexible())]
        #else
        [GridItem(.adaptive(minimum: 150), alignment: .leading)]
        #endif
    }
    private func apply(_ invitation: ScoreboardMatchInvitation) {
        code = invitation.code; server = invitation.server
        if let value = invitation.password { password = value }
    }
    private func receive(_ value: String) {
        if let invitation = ScoreboardMatchInvitation.parse(value) { apply(invitation) }
        else if let invitation = ScoreboardNearbyInvitation.parse(value), let receivedNearbyInvitation { receivedNearbyInvitation(invitation) }
        else { feedback = "This QR code is not a match invitation. Use Add a Display or Device for device pairing codes." }
    }
    private func submit() {
        busy = true; feedback = ""
        joinTask = Task { @MainActor in
            defer { busy = false }
            do {
                try ScoreboardStore.shared.requireMatchReplacementAllowed()
                try await cloud.joinInvitation(code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: " ", with: ""),
                    password: password, server: server, requestControl: requestsControl,
                    beforeConnect: { try beforeConnect?(requestsControl) })
                joined?(); feedback = "Joined. Control requests need the owner's approval."
            } catch {
                failed?()
                if !(error is CancellationError) { feedback = error.localizedDescription }
            }
        }
    }
}

#if !os(tvOS)
/// Match participation lives with the open document, not in global settings.
struct ScoreboardHostConnectionsView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @ObservedObject private var nearby = ScoreboardNearbyMatchService.shared
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @State private var password = ""
    @State private var publicURL: URL?
    @State private var feedback = ""
    @State private var busy = false
    @State private var confirmsStop = false
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text(store.currentMatchTitle).font(.title2.bold())
            ScoreboardCloudSection("Nearby", footer: "Works without internet. Other devices discover this scoreboard and ask you to confirm, or enter the pairing PIN.") {
                Toggle("Allow Nearby Connections", isOn: Binding(get: { store.isRemoteDisplayHostEnabled }, set: {
                    if !$0 && store.remoteSessionDevices?.contains(where: \.connected) == true { confirmsStop = true }
                    else { store.setRemoteDisplayHostEnabled($0); nearby.update(owner: store) }
                })).padding(.vertical, 12).accessibilityIdentifier("host.nearby")
                if store.isRemoteDisplayHostEnabled {
                    Divider()
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pairing PIN").font(.caption).foregroundStyle(.secondary)
                            Text(nearby.joinCode).font(.largeTitle.bold().monospaced()).textSelection(.enabled)
                        }
                        Spacer()
                        if let value = ScoreboardNearbyInvitation(ownerID: store.localSessionDeviceID, code: nearby.joinCode).url {
                            ScoreboardPairingQRCode(value: value.absoluteString, size: 110)
                        }
                    }.padding(.vertical, 14)
                    NavigationLink("Pair Using the Kiosk’s Device PIN") {
                        ScrollView { ScoreboardDevicePairingSection().padding(24) }.navigationTitle("Pair Device")
                    }.padding(.vertical, 10)
                }
                ForEach(nearby.approvals) { request in
                    HStack {
                        Text("\(request.name) · \(request.requestsControl ? "Controller" : "Display")")
                        Spacer()
                        Button("Approve") { nearby.approve(request) }.buttonStyle(.borderedProminent)
                        Button("Decline", role: .destructive) { nearby.decline(request) }
                    }.padding(.vertical, 12)
                }
            }
            ScoreboardCloudSection("Cloud", footer: "Only the host signs in. Guests join with this session’s fixed code and password.") {
                NavigationLink("Cloud Account & Service") { ScrollView { ScoreboardCloudSettingsView().padding(24) }.navigationTitle("App Settings · Cloud") }
                    .padding(.vertical, 12)
                Divider()
                if cloud.hostingEnabled {
                    Label(cloud.isConnected ? "Sharing Online" : "Connecting…", systemImage: "cloud").padding(.vertical, 12)
                    Button("Stop Online Sharing", role: .destructive) { cloud.hostingEnabled = false }
                } else {
                    Text(cloud.onlineSharingGuidance).font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
                    Button("Share This Scoreboard Online") { cloud.hostingEnabled = true; cloud.reconnect() }
                        .buttonStyle(.borderedProminent).disabled(!cloud.canEnableOnlineSharing).accessibilityIdentifier("host.shareOnline")
                }
                if cloud.canManageMatch && cloud.hostingEnabled {
                    Divider()
                    if let code = cloud.session?.invitationCode {
                        Text("Cloud Code").font(.caption).foregroundStyle(.secondary).padding(.top, 12)
                        Text(code).font(.title.bold().monospaced()).textSelection(.enabled)
                        if let url = URL(string: "\(cloud.serviceURL)/join/\(code)") {
                            ShareLink("Share Join Link", item: url).padding(.vertical, 8)
                            ScoreboardPairingQRCode(value: url.absoluteString, size: 120)
                        }
                        Text("This code stays the same for this session. The password changes only when you update it here.").font(.caption).foregroundStyle(.secondary)
                    }
                    SecureField(cloud.session?.invitationCode == nil ? "Set a match password" : "New password (leave blank to keep current)", text: $password)
                        .scoreboardCloudSettingsField().padding(.vertical, 12)
                    Button(cloud.session?.invitationCode == nil ? "Enable Code & Password" : "Update Password") { updatePassword() }
                        .buttonStyle(.bordered).disabled(password.count < 6 || busy)
                }
            }
            if cloud.canManageMatch && cloud.hostingEnabled {
                ScoreboardCloudSection("Public Viewing", footer: "Anyone with these links can view without signing in. These links do not grant control.") {
                    Button("Get Public Viewing Links") {
                        Task { @MainActor in
                            do { publicURL = try await cloud.webViewingLink(enabled: true) }
                            catch { feedback = error.localizedDescription }
                        }
                    }.padding(.vertical, 12)
                    if let publicURL {
                        ForEach(["scoreboard", "obs", "commentator"], id: \.self) { mode in
                            if let url = viewingURL(publicURL, mode: mode) {
                                HStack {
                                    Link(mode == "obs" ? "OBS Overlay" : mode == "scoreboard" ? "Fullscreen Scoreboard" : "Commentator", destination: url)
                                    Spacer(); ShareLink("Share", item: url)
                                }.padding(.vertical, 10)
                            }
                        }
                    }
                    Button("Revoke Public Viewing Links", role: .destructive) {
                        Task { @MainActor in
                            do { _ = try await cloud.webViewingLink(enabled: false); publicURL = nil }
                            catch { feedback = error.localizedDescription }
                        }
                    }.padding(.vertical, 12)
                }
            }
            ScoreboardCloudSection("Connected Devices") {
                let peers = store.remoteSessionDevices ?? []
                if peers.isEmpty { Text("No devices connected.").foregroundStyle(.secondary).padding(.vertical, 12) }
                ForEach(peers, id: \.id) { peer in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(peer.name).font(.headline); Spacer(); Text(peer.connected ? "Connected" : "Offline").font(.caption) }
                        if let status = peer.connectionStatus { Text(status.summary).font(.caption).foregroundStyle(.secondary) }
                        let member = cloud.session?.members.first { $0.id == peer.id && $0.role != "host" }
                        let locallyPaired = store.remoteDisplayTrustedDisplays.contains { $0.id == peer.id }
                        if locallyPaired || member != nil {
                            Toggle((peer.requestedControl == true || member?.requestedControl == true) && peer.controlEnabled != true ? "Approve Control Request" : "Allow Control", isOn: Binding(
                                get: { peer.controlEnabled == true }, set: { allowed in
                                    if locallyPaired { store.setRemoteControlAllowed(displayID: peer.id, isAllowed: allowed) }
                                    else if let member { Task { _ = await cloud.setCloudPermission(memberID: member.id, allowed: allowed) } }
                                }))
                        } else { Label("Viewer", systemImage: "eye").font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 14)
                    Divider()
                }
            }
            ScoreboardCloudFailoverSettings()
            if !feedback.isEmpty { Text(feedback).font(.callout).foregroundStyle(.orange) }
        }
        .confirmationDialog("Disconnect Nearby Devices?", isPresented: $confirmsStop, titleVisibility: .visible) {
            Button("Disconnect and Stop Nearby Joining", role: .destructive) { store.setRemoteDisplayHostEnabled(false); nearby.update(owner: store) }
        }
    }
    private func viewingURL(_ value: URL, mode: String) -> URL? {
        var parts = URLComponents(url: value, resolvingAgainstBaseURL: false)
        parts?.path = "/views/\(mode).html"
        return parts?.url
    }
    private func updatePassword() {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { _ = try await cloud.makeInvitation(password: password); password = ""; feedback = "Code and password are ready to share." }
            catch { feedback = error.localizedDescription }
        }
    }
}
#endif
