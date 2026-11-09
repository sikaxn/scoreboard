import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

@MainActor final class ScoreboardJoinCoordinator: ObservableObject {
    @Published private(set) var isJoining = false
    @Published private(set) var message = ""
    private var timeout: Task<Void, Never>?
    private var acquiredReceiver = false
    private var completion: ((Result<Void, Error>) -> Void)?

    func join(_ match: ScoreboardNearbyMatch, code: String, asDisplay: Bool, completion: @escaping () -> Void) {
        start(match, code: code, asDisplay: asDisplay) { result in
            if case .success = result { completion() }
        }
    }
    func joinInvitation(_ match: ScoreboardNearbyMatch, password: String, asDisplay: Bool) async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                start(match, code: "", asDisplay: asDisplay, password: password) { continuation.resume(with: $0) }
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }
    private func start(_ match: ScoreboardNearbyMatch, code: String, asDisplay: Bool, password: String? = nil,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isJoining else { completion(.failure(URLError(.cancelled))); return }
        let displayOnly = asDisplay || !ScoreboardRemoteDisplayDeviceType.current.supportsControl
        let store = ScoreboardStore.shared
        do { try store.prepareJoiningMatch(asDisplay: displayOnly) }
        catch { message = error.localizedDescription; completion(.failure(error)); return }
        ScoreboardRemoteConnectionRouter.shared.setJoinTarget(match.matchID)
        isJoining = true; message = code.isEmpty && password == nil ? "Waiting for the host to confirm…" : "Connecting to \(match.title)…"
        self.completion = completion
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        receiver.acquire(networkMode: store.remoteDisplayNetworkMode); acquiredReceiver = true
        receiver.setPairingScreenVisible(true)
        let beganAt = Date()
        ScoreboardNearbyMatchService.shared.requestJoin(match, code: code, control: !displayOnly,
            mode: store.remoteDisplayNetworkMode, invitationPassword: password) { [weak self] result in
            guard let self, self.isJoining else { return }
            switch result {
            case .failure(let error): self.finish(.failure(error))
            case .success:
                self.timeout = Task { [weak self] in
                    for _ in 0..<150 {
                        try? await Task.sleep(for: .milliseconds(100))
                        guard !Task.isCancelled, let self, self.isJoining else { return }
                        let descriptor = receiver.state?.control?.session
                        if receiver.lastReceivedAt.map({ $0 >= beganAt }) == true,
                           receiver.state?.game.matchID == match.matchID,
                           descriptor?.ownerDeviceID == match.id || descriptor?.hostDeviceID == match.id {
                            receiver.finishNearbyMatchJoin(connected: true)
                            ScoreboardRecentMatches.shared.record(title: match.title, matchID: match.matchID, nearbyOwnerID: match.id,
                                server: password == nil ? nil : match.cloudServer, code: password == nil ? nil : match.cloudCode)
                            store.commitJoinedMatch(); self.finish(.success(()))
                            return
                        }
                    }
                    self?.finish(.failure(URLError(.timedOut)))
                }
            }
        }
    }
    func cancel() { if isJoining { finish(.failure(CancellationError())) } }
    private func finish(_ result: Result<Void, Error>) {
        guard isJoining else { return }
        isJoining = false; timeout?.cancel(); timeout = nil
        let callback = completion; completion = nil
        if case .failure(let error) = result {
            ScoreboardNearbyMatchService.shared.cancelRequest()
            releaseReceiver(); ScoreboardStore.shared.leaveJoinedMatch()
            message = error is CancellationError ? "" : error.localizedDescription
        } else { releaseReceiver() }
        callback?(result)
    }
    private func releaseReceiver() {
        guard acquiredReceiver else { return }
        acquiredReceiver = false
        ScoreboardRemoteDisplayReceiver.shared.setPairingScreenVisible(false)
        ScoreboardRemoteDisplayReceiver.shared.release()
    }
}

struct ScoreboardNearbyJoinContent: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @ObservedObject private var nearby = ScoreboardNearbyMatchService.shared
    @ObservedObject private var store = ScoreboardStore.shared
    @StateObject private var join = ScoreboardJoinCoordinator()
    var invitation: ScoreboardNearbyInvitation? = nil
    var initialCode = ""
    var preferredMatchID: UUID? = nil
    var joined: () -> Void = {}
    @State private var selected: ScoreboardNearbyMatch?
    @State private var code = ""
    @State private var usesPIN = ScoreboardDeviceMode.current == .kiosk
    @State private var asDisplay = true
    @State private var acquired = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nearby Matches").font(.title2.bold())
            Text("Join over your local network or nearby Wi-Fi. No internet or account is needed.")
                .font(.callout).foregroundStyle(.secondary)
            if !store.localConnectionsEnabled {
                Label("LAN and nearby connections are off.", systemImage: "network.slash").foregroundStyle(.secondary)
                Text("Enable LAN & Nearby in App Settings to discover local scoreboards. Cloud joining remains available separately.").font(.callout)
            } else if nearby.matches.isEmpty && nearby.discoveryError == nil {
                Label("Looking for matches…", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
                Text("Ask the host to open Connect Devices and allow nearby joining. Check Local Network permission if the match does not appear.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(nearby.matches) { match in
                Button {
                    selected = match
                    code = invitation?.ownerID == match.id ? invitation?.code ?? "" : initialCode
                    if !code.isEmpty { usesPIN = true }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.title).font(.headline)
                            Text(match.ownerName).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selected?.id == match.id ? "checkmark.circle.fill" : "chevron.right")
                    }.padding(.vertical, 8).contentShape(Rectangle())
                }.buttonStyle(.bordered).disabled(join.isJoining)
            }
            if let selected {
                #if os(tvOS)
                HStack(spacing: 24) {
                    RemotePairingActionButton(title: "Enter Pairing PIN", symbol: "number", selected: usesPIN) { usesPIN = true }
                    RemotePairingActionButton(title: "Ask Host to Confirm", symbol: "person.crop.circle.badge.checkmark", selected: !usesPIN) { usesPIN = false }
                }.focusSection()
                #else
                Picker("Pairing", selection: $usesPIN) {
                    Text("Ask Host to Confirm").tag(false)
                    Text("Enter Pairing PIN").tag(true)
                }.pickerStyle(.menu)
                #endif
                if usesPIN { TextField("6-digit pairing PIN", text: $code).autocorrectionDisabled().scoreboardCloudSettingsField()
                    #if !os(macOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityIdentifier("join.nearbyCode") }
                #if os(tvOS)
                Label("Apple TV joins as a display only.", systemImage: "tv").foregroundStyle(.secondary)
                #else
                Picker("Join as", selection: $asDisplay) {
                    Text("Display").tag(true); Text("Controller · owner approval").tag(false)
                }.pickerStyle(.menu)
                #endif
                Button(join.isJoining ? "Connecting…" : "Join \(selected.title)", systemImage: "arrow.right.circle") {
                    join.join(selected, code: usesPIN ? code : "", asDisplay: asDisplay, completion: joined)
                }.buttonStyle(.borderedProminent)
                    .disabled(join.isJoining || (usesPIN && (code.count != 6 || !code.allSatisfy(\.isNumber))))
                if join.isJoining { Button("Cancel Connection", role: .cancel) { join.cancel() } }
            }
            if let error = nearby.discoveryError, store.localConnectionsEnabled {
                Label("Nearby Discovery Unavailable", systemImage: "wifi.exclamationmark").font(.headline).foregroundStyle(.orange)
                Text(error).font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("join.discoveryError")
                HStack {
                    Button("Try Again", systemImage: "arrow.clockwise") { nearby.retryBrowser(mode: store.remoteDisplayNetworkMode) }
                        .buttonStyle(.bordered).accessibilityIdentifier("join.retryDiscovery")
                    #if os(macOS)
                    if nearby.discoveryNeedsPermission {
                        Button("Open System Settings") { openURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")!) }.buttonStyle(.bordered)
                    }
                    #elseif os(iOS)
                    if nearby.discoveryNeedsPermission {
                        Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }.buttonStyle(.bordered)
                    }
                    #endif
                }
            }
            if !join.message.isEmpty { Text(join.message).font(.callout).accessibilityIdentifier("join.nearbyStatus") }
        }
        .onAppear {
            if !acquired { acquired = true; nearby.acquireBrowser(mode: store.remoteDisplayNetworkMode) }
            selectInvitation()
        }
        .onChange(of: store.remoteDisplayNetworkMode) { _, mode in
            if acquired { nearby.releaseBrowser(); nearby.acquireBrowser(mode: mode) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, acquired, nearby.discoveryError != nil {
                nearby.retryBrowser(mode: store.remoteDisplayNetworkMode)
            }
        }
        .onChange(of: nearby.matches.map(\.id)) { _, _ in selectInvitation() }
        .onChange(of: invitation) { _, _ in selectInvitation() }
        .onChange(of: initialCode) { _, _ in selectInvitation() }
        .onChange(of: preferredMatchID) { _, _ in selectInvitation() }
        .onDisappear {
            join.cancel()
            if acquired { acquired = false; nearby.releaseBrowser() }
        }
    }
    private func selectInvitation() {
        if let invitation, let match = nearby.matches.first(where: { $0.id == invitation.ownerID }) {
            selected = match; code = invitation.code; usesPIN = true
        } else if let match = nearby.matches.first(where: { $0.matchID == preferredMatchID }) ?? (initialCode.isEmpty || nearby.matches.count != 1 ? nil : nearby.matches.first) {
            selected = match; code = initialCode; usesPIN = !initialCode.isEmpty
        }
    }
}

#if !os(tvOS)
struct ScoreboardJoinMatchView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var initialInvitation: ScoreboardMatchInvitation? = nil
    var nearbyInvitation: ScoreboardNearbyInvitation? = nil
    var embedded = false
    var finished: (() -> Void)? = nil
    @State private var scannedNearby: ScoreboardNearbyInvitation?
    @State private var scannedCloud: ScoreboardMatchInvitation?
    @State private var feedback = ""
    @ObservedObject private var recents = ScoreboardRecentMatches.shared
    @ObservedObject private var nearby = ScoreboardNearbyMatchService.shared
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @State private var recentMatchID: UUID?
    @State private var nearbyPIN = ""
    @State private var availability: [String: ScoreboardCloudInvitationStatus] = [:]
    @State private var browsingForRecents = false
    private var palette: SettingsPalette { store.theme.palette.settingsPalette(for: store.theme, colorScheme: colorScheme) }
    var body: some View {
        Group {
            if embedded { joinContent }
            else { NavigationStack { joinContent } }
        }
        .frame(minWidth: embedded ? 0 : 320, idealWidth: 780, minHeight: embedded ? 0 : 500)
        // Recents need discovery even when the nearby section is below the fold.
        .onAppear { updateRecentDiscovery() }
        .onChange(of: store.localConnectionsEnabled) { _, _ in updateRecentDiscovery() }
        .onChange(of: store.remoteDisplayNetworkMode) { _, mode in
            updateRecentDiscovery()
            if browsingForRecents { nearby.retryBrowser(mode: mode) }
        }
        .onDisappear {
            if browsingForRecents { nearby.releaseBrowser(); browsingForRecents = false }
        }
        .onChange(of: initialInvitation) { _, invitation in scannedCloud = invitation }
    }
    private var joinContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(ScoreboardDeviceMode.current == .kiosk ? "Join as a display or controller. This device keeps no copy when you disconnect." : "Your local scoreboard stays saved on this device.").font(.callout).foregroundStyle(palette.secondaryText)
                ScoreboardCloudSection("Code or Link") {
                    ScoreboardMatchGuestJoinForm(initialInvitation: scannedCloud ?? initialInvitation,
                        beforeConnect: { control in
                            try store.prepareJoiningMatch(asDisplay: !control)
                            if !store.remoteDisplayNetworkMode.allowsCloud { store.setRemoteDisplayNetworkMode(.preferLocal) }
                        }, joined: { store.commitJoinedMatch(); finish() },
                        failed: { if store.isPreparingMatchJoin { store.leaveJoinedMatch() } },
                        receivedNearbyInvitation: { scannedNearby = $0; nearbyPIN = $0.code },
                        receivedNearbyPIN: { nearbyPIN = $0 })
                        .id(scannedCloud?.url?.absoluteString ?? initialInvitation?.url?.absoluteString ?? "join-code")
                        .padding(.vertical, 12)
                }
                if !recents.matches.isEmpty, ScoreboardDeviceMode.current == .app {
                    ScoreboardCloudSection("Recent Connections", footer: "Connection details only. Passwords and received game data are not saved.") {
                        ForEach(recents.matches) { recent in
                            Button { chooseRecent(recent) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(recent.title).font(.headline)
                                        Text(recentStatus(recent)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(); Image(systemName: "chevron.right")
                                }.padding(.vertical, 12).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .contextMenu { Button("Remove from Recents", role: .destructive) { recents.remove(recent.id) } }
                            if recent.id != recents.matches.last?.id { Divider() }
                        }
                    }
                }
                if store.localConnectionsEnabled {
                ScoreboardCloudSection("Nearby") {
                    ScoreboardNearbyJoinContent(invitation: scannedNearby ?? nearbyInvitation, initialCode: nearbyPIN,
                        preferredMatchID: recentMatchID, joined: finish).padding(.vertical, 12)
                }
                }
                if store.localConnectionsEnabled {
                    ScoreboardCloudSection("Device Pairing") {
                        NavigationLink("Show This Device’s Pairing Code") { ScoreboardWaitingForPairingView(joined: finish) }
                            .padding(.vertical, 12)
                    }
                }
                if !feedback.isEmpty { Text(feedback).font(.callout).foregroundStyle(.orange) }
            }.padding(24).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .background(palette.detailBackground).foregroundStyle(palette.primaryText)
        .navigationTitle(embedded ? "" : "Connect to Scoreboard")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: cloud.cloudEnabled.description + cloud.serviceURL + recents.matches.map(\.id).joined()) { await checkRecents() }
        .toolbar { if !embedded { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } } }
    }
    private func finish() { if let finished { finished() } else { dismiss() } }
    private func updateRecentDiscovery() {
        if browsingForRecents { nearby.releaseBrowser(); browsingForRecents = false }
        if store.localConnectionsEnabled {
            nearby.acquireBrowser(mode: store.remoteDisplayNetworkMode); browsingForRecents = true
        }
    }
    private func chooseRecent(_ recent: ScoreboardRecentMatch) {
        if nearby.matches.contains(where: { $0.matchID == recent.matchID }), store.localConnectionsEnabled {
            recentMatchID = recent.matchID; nearbyPIN = ""; scannedNearby = nil
        } else if let server = recent.server, let code = recent.code {
            scannedCloud = .init(server: server, code: code)
        } else { feedback = "This scoreboard is offline. Enable nearby connections and ask its host to open the match." }
    }
    private func recentStatus(_ recent: ScoreboardRecentMatch) -> String {
        if store.localConnectionsEnabled, nearby.matches.contains(where: { $0.matchID == recent.matchID }) { return "Nearby · Available" }
        guard let server = recent.server, let code = recent.code else { return "Offline · Not nearby" }
        guard cloud.cloudEnabled else { return "Offline · Cloud is off" }
        guard ScoreboardCloudEndpoint.sameService(server, cloud.serviceURL) else { return "Offline · Another cloud host" }
        guard let status = availability[code] else { return "Cloud · Not checked" }
        return status.available && status.hostOnline == true ? "Via Cloud · Available" : "Offline · Host unavailable"
    }
    private func checkRecents() async {
        availability = [:]
        let codes = recents.matches.filter { $0.server.map { ScoreboardCloudEndpoint.sameService($0, cloud.serviceURL) } == true }.compactMap(\.code)
        guard cloud.cloudEnabled, !codes.isEmpty else { return }
        if let statuses = try? await cloud.invitationAvailability(codes: codes), !Task.isCancelled {
            availability = Dictionary(uniqueKeysWithValues: statuses.map { ($0.code, $0) })
        }
    }
}

private struct ScoreboardWaitingForPairingView: View {
    var joined: () -> Void
    @ObservedObject private var receiver = ScoreboardRemoteDisplayReceiver.shared
    @ObservedObject private var store = ScoreboardStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var prepared = false
    @State private var message = ""
    @State private var acquired = false
    @State private var displayOnly = true
    @State private var confirmsForget = false
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Ask the owner to add this device from Connect Devices.").multilineTextAlignment(.center)
                if prepared {
                    Picker("Join as", selection: $displayOnly) {
                        Text("Display").tag(true); Text("Controller · owner approval").tag(false)
                    }.pickerStyle(.menu)
                    Text(receiver.pairingCode).font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                    ScoreboardPairingQRCode(value: ScoreboardPairingLink.nearbyURL(deviceID: receiver.displayID, code: receiver.pairingCode), size: 180)
                    Button("New Code") { receiver.resetPairingCode() }
                    if !receiver.trustedHosts.isEmpty {
                        Button("Forget Previous Pairings", role: .destructive) { confirmsForget = true }
                    }
                }
                if !message.isEmpty { Text(message).foregroundStyle(.orange) }
            }.padding(24).frame(maxWidth: .infinity)
        }.navigationTitle("Pair This Device")
        .onChange(of: displayOnly) { _, value in store.setJoiningPresentation(displayOnly: value) }
        .confirmationDialog("Forget Previous Local Pairings?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget Pairings", role: .destructive) { receiver.forgetTrustedHosts() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Previously paired operators will need to pair this device again.") }
        .onAppear {
            do {
                try store.prepareJoiningMatch(asDisplay: true)
                prepared = true; receiver.acquire(networkMode: store.remoteDisplayNetworkMode); acquired = true
                receiver.setPairingScreenVisible(true)
            } catch { message = error.localizedDescription }
        }
        .onChange(of: receiver.state != nil) { _, hasState in
            if prepared && hasState { store.commitJoinedMatch(); joined() }
        }
        .onDisappear {
            if acquired { receiver.setPairingScreenVisible(false); receiver.release(); acquired = false }
            if store.isPreparingMatchJoin { store.leaveJoinedMatch() }
        }
    }
}
#endif
