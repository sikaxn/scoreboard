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
    private var usesConfiguredServer: Bool { ScoreboardDeviceMode.current == .kiosk }
    private var controlRequested: Bool { requestsControl && ScoreboardRemoteDisplayDeviceType.current.supportsControl }
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
            if !usesConfiguredServer {
                TextField("Cloud server URL", text: $server).autocorrectionDisabled().scoreboardCloudSettingsField().accessibilityIdentifier("join.server")
            }
            #if os(tvOS)
            Label("Apple TV joins as a display only.", systemImage: "tv").foregroundStyle(.secondary)
            #else
            Picker("Join as", selection: $requestsControl) { Text("Display").tag(false); Text("Controller · owner approval").tag(true) }
                .pickerStyle(.menu)
            #endif
            LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 12) {
                Button(busy ? "Joining…" : "Join Match", systemImage: "arrow.right.circle") {
                    if !usesConfiguredServer && server != cloud.serviceURL && !ScoreboardCloudEndpoint.isPublicService(server) { confirmsServer = true }
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
        .onAppear { server = usesConfiguredServer ? cloud.serviceURL : (initialInvitation?.server ?? cloud.serviceURL); if let invitation = initialInvitation { apply(invitation) } }
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
        if usesConfiguredServer, !ScoreboardCloudEndpoint.sameService(invitation.server, cloud.serviceURL) {
            code = ""; feedback = "This invitation uses another cloud server. Change the server in App Settings first."; return
        }
        code = invitation.code; server = usesConfiguredServer ? cloud.serviceURL : invitation.server
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
                    password: password, server: usesConfiguredServer ? cloud.serviceURL : server, requestControl: controlRequested,
                    beforeConnect: { try beforeConnect?(controlRequested) })
                joined?(); feedback = "Joined. Control requests need the owner's approval."
            } catch {
                failed?()
                if !(error is CancellationError) { feedback = error.localizedDescription }
            }
        }
    }
}

#if !os(tvOS)
/// The badge and device manager describe the same active session.
@MainActor struct ScoreboardConnectionOverview {
    let store: ScoreboardStore
    let receiver: ScoreboardRemoteDisplayReceiver
    var session: ScoreboardSessionDescriptor? {
        store.isSessionAuthority ? store.sessionDescriptor : (receiver.state?.control?.session ?? store.sessionDescriptor)
    }
    var isHosting: Bool {
        if store.isFollowingSessionHost { return false }
        if let session, session.hostDeviceID != store.localSessionDeviceID { return false }
        return receiver.isHostingSession || (store.isSessionAuthority &&
            (store.isRemoteDisplayHostEnabled || ScoreboardCloudClient.shared.isPublishingLocalHost))
    }
    var title: String {
        if isHosting { return ScoreboardLocalization.string("Hosting") }
        if store.isSessionAuthority && !store.isJoinedMatchActive && !store.isRemoteControlProxy {
            return ScoreboardLocalization.string("Local")
        }
        guard receiver.status.isLive else { return ScoreboardLocalization.string(receiver.status.title) }
        return ScoreboardLocalization.string(receiver.isControlConnectionReady || store.joinedAsDisplay ? "Connected" : "Waiting for session host…")
    }
    var peers: [ScoreboardSessionPeer] {
        if store.isJoinedMatchActive, !store.isRemoteControlProxy, let control = receiver.state?.control {
            let peers = control.devices ?? []
            return control.session?.clientPeers(from: peers, ownerConnected: control.ownerConnected) ?? peers
        }
        return store.remoteSessionDevices ?? []
    }
    var countsDescription: String {
        let connected = peers.filter(\.connected).count
        return scoreboardLocalizedFormat(ScoreboardLocalization.string("%d connected · %d disconnected"),
            locale: .current, arguments: [connected, peers.count - connected])
    }
}

struct ScoreboardConnectionOverviewSection: View {
    @EnvironmentObject private var store: ScoreboardStore
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    private var overview: ScoreboardConnectionOverview { .init(store: store, receiver: receiver) }
    var body: some View {
        ScoreboardCloudSection("Connection Status") {
            VStack(alignment: .leading, spacing: 14) {
                row("Connection", overview.title)
                if let session = overview.session {
                    row("Session Host", session.hostName)
                    row("Owner", session.ownerName)
                } else if store.isSessionAuthority && !store.isJoinedMatchActive {
                    row("Session Host", ScoreboardRemoteDisplayDeviceName.current ?? ScoreboardLocalization.string("This Device"))
                    row("Owner", ScoreboardRemoteDisplayDeviceName.current ?? ScoreboardLocalization.string("This Device"))
                } else if let name = receiver.connectedHostName {
                    row("Scoreboard", name)
                }
                if !store.isSessionAuthority || store.isJoinedMatchActive {
                    if let info = receiver.connectionInfo {
                        row("Route", ScoreboardLocalization.string(info.normalized.route.title))
                        row("Transport", info.method.title)
                        if let medium = info.interfaceTitle { row("Interface", medium) }
                    } else { row("Transport", receiver.realtimeTransport) }
                    if receiver.connectionInfo?.normalized.route != .cloud, let trip = receiver.roundTripSeconds {
                        row("Latency", scoreboardLocalizedFormat(ScoreboardLocalization.string("Ping %d ms"),
                            locale: .current, arguments: [Int((trip * 1_000).rounded())]))
                    }
                }
                if store.remoteSessionOwnerConnected == false {
                    Label("Owner disconnected", systemImage: "person.crop.circle.badge.exclamationmark").foregroundStyle(.orange)
                }
                if store.isFollowingSessionHost {
                    Text(store.isSessionSafeToDisconnect ? "Safe to Disconnect" : "Match active or sync pending").font(.caption).foregroundStyle(.secondary)
                }
                if let result = receiver.controlResult, !result.success {
                    Label(ScoreboardLocalization.remoteSessionMessage(result.message ?? "Command failed"), systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                }
            }.padding(.vertical, 14)
        }
    }
    private func row(_ title: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(ScoreboardLocalization.string(title)).foregroundStyle(.secondary).fixedSize()
                Spacer(minLength: 4)
                Text(verbatim: value).multilineTextAlignment(.trailing).fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(ScoreboardLocalization.string(title)).foregroundStyle(.secondary)
                Text(verbatim: value).fixedSize(horizontal: false, vertical: true)
            }
        }.font(.callout)
    }
}

struct ScoreboardConnectedDevicesSection: View {
    @EnvironmentObject private var store: ScoreboardStore
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    @State private var feedback: String?
    private var overview: ScoreboardConnectionOverview { .init(store: store, receiver: receiver) }
    private var canManage: Bool { !store.isRemoteControlProxy && (store.isSessionAuthority || store.isFollowingSessionHost) && !store.isJoinedMatchActive }
    var body: some View {
        ScoreboardCloudSection("Connected Devices") {
            if overview.peers.isEmpty {
                Text("No devices connected.").foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                Text(overview.countsDescription).font(.caption).foregroundStyle(.secondary).padding(.vertical, 12)
            }
            if !overview.isHosting && !receiver.status.isLive && !overview.peers.isEmpty {
                Text("Last reported by the session host.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(overview.peers, id: \.id) { peer in
                VStack(alignment: .leading, spacing: 12) {
                    deviceDetails(peer)
                    let member = cloud.session?.members.first { $0.id == peer.id && $0.role != "host" }
                    let paired = store.remoteDisplayTrustedDisplays.contains { $0.id == peer.id }
                    if canManage, peer.deviceType.supportsControl, peer.supportsControl != false,
                       peer.id != overview.session?.ownerDeviceID, paired || member != nil {
                        Toggle((peer.requestedControl == true || member?.requestedControl == true) && peer.controlEnabled != true ? "Approve Control Request" : "Allow Control", isOn: Binding(
                            get: { peer.controlEnabled == true }, set: { allowed in
                                if paired { store.setRemoteControlAllowed(displayID: peer.id, isAllowed: allowed) }
                                else if let member { Task { if !(await cloud.setCloudPermission(memberID: member.id, allowed: allowed)) { feedback = cloud.status } } }
                            }))
                            .accessibilityIdentifier("connection.control.\(peer.id)")
                    } else if let allowed = peer.controlEnabled {
                        Label(allowed ? "Control enabled" : "Remote Display", systemImage: allowed ? "gamecontroller" : "eye").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 14).accessibilityElement(children: .contain)
                    .accessibilityIdentifier("connection.client.\(peer.id)")
                Divider()
            }
            if let feedback { Text(feedback).font(.caption).foregroundStyle(.orange).padding(.vertical, 10) }
        }
    }
    private func deviceDetails(_ peer: ScoreboardSessionPeer) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: peer.deviceType.systemImage).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(peer.name).font(.headline)
                HStack(spacing: 6) {
                    Circle().fill(peer.connected ? (peer.quality == .poor ? Color.orange : Color.green) : Color.orange).frame(width: 7, height: 7)
                    Text(peer.connected ? (peer.quality == .poor ? "Poor" : "Connected") : (peer.quality == .connecting ? "Connecting" : "Disconnected")).font(.caption)
                }
                if peer.id == overview.session?.ownerDeviceID { Text("Owner · Client").font(.caption.weight(.semibold)) }
                let type = ScoreboardLocalization.string(peer.deviceType.title)
                if peer.name.localizedCaseInsensitiveCompare(type) != .orderedSame { Text(type).font(.caption).foregroundStyle(.secondary) }
                if peer.connected {
                    if let status = peer.connectionStatus {
                        Text(status.summary).font(.caption).foregroundStyle(.secondary)
                        if let medium = status.active?.interfaceTitle { Text(medium).font(.caption).foregroundStyle(.secondary) }
                        if let other = status.otherConnections { Text("Available: \(other)").font(.caption).foregroundStyle(.secondary) }
                    } else if let transport = peer.realtimeTransport { Text(transport).font(.caption).foregroundStyle(.secondary) }
                    if peer.connectionStatus?.active?.route != .cloud, let latency = peer.latencyMilliseconds {
                        Text(scoreboardLocalizedFormat(ScoreboardLocalization.string("Ping %d ms"), locale: .current, arguments: [latency])).font(.caption).monospacedDigit()
                    }
                } else if let age = peer.lastHandshakeAgeSeconds {
                    Text(scoreboardLocalizedFormat(ScoreboardLocalization.string("Last response %d s ago"), locale: .current, arguments: [age])).font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityElement(children: .combine)
    }
}

struct ScoreboardSessionRecoveryControls: View {
    @EnvironmentObject private var store: ScoreboardStore
    var body: some View {
        if store.isSessionOwner && !store.isRemoteControlProxy && (store.isRemoteDisplayHostEnabled || store.isFollowingSessionHost) {
            ScoreboardCloudSection("Session Host") {
                Button("Host Here & Disconnect Others", role: .destructive) { store.hostOnOwnerAndDisconnectOthers() }
                    .buttonStyle(.bordered).padding(.vertical, 12).disabled(!store.canHostOnOwnerAndDisconnectOthers)
                if store.isAnyTimerRunning { Text("Stop all timers before moving the session host.").font(.caption).foregroundStyle(.secondary) }
                if let message = store.sessionStatusMessage { Text(ScoreboardLocalization.remoteSessionMessage(message)).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

/// Match participation lives with the open document, not in global settings.
struct ScoreboardHostConnectionsView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @Environment(\.dismiss) private var dismiss
    var receiver: ScoreboardRemoteDisplayReceiver = .shared
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
            ScoreboardConnectionOverviewSection(receiver: receiver)
            ScoreboardConnectedDevicesSection(receiver: receiver)
            ScoreboardCloudSection("Nearby", footer: "Works without internet. Other devices discover this scoreboard and ask you to confirm, or enter the pairing PIN.") {
                Toggle("Allow Nearby Connections", isOn: Binding(get: { store.isRemoteDisplayHostEnabled }, set: {
                    if !$0 && store.remoteSessionDevices?.contains(where: \.connected) == true { confirmsStop = true }
                    else { store.setRemoteDisplayHostEnabled($0); nearby.update(owner: store) }
                })).padding(.vertical, 12).disabled(!store.localConnectionsEnabled).accessibilityIdentifier("host.nearby")
                if !store.localConnectionsEnabled {
                    Text("LAN & Nearby is off in App Settings. Cloud sharing is available separately.").font(.callout).foregroundStyle(.secondary)
                }
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
                Button("LAN & Cloud Settings") { dismiss(); ScoreboardAppNavigation.shared.openSettings("cloud") }
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("connection.settings")
                Divider()
                if cloud.hostingEnabled {
                    Label(!cloud.cloudEnabled ? "Cloud is disabled in App Settings" : cloud.isConnected ? "Sharing Online" : "Connecting…", systemImage: "cloud").padding(.vertical, 12)
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
            ScoreboardCloudFailoverSettings()
            ScoreboardSessionRecoveryControls()
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
