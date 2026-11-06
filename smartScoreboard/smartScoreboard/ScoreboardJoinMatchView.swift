import SwiftUI
import Combine

@MainActor final class ScoreboardJoinCoordinator: ObservableObject {
    @Published private(set) var isJoining = false
    @Published private(set) var message = ""
    private var timeout: Task<Void, Never>?
    private var acquiredReceiver = false
    private var completion: (() -> Void)?

    func join(_ match: ScoreboardNearbyMatch, code: String, asDisplay: Bool, completion: @escaping () -> Void) {
        guard !isJoining else { return }
        let store = ScoreboardStore.shared
        do { try store.prepareJoiningMatch(asDisplay: asDisplay) }
        catch { message = error.localizedDescription; return }
        isJoining = true; message = code.isEmpty ? "Waiting for the host to confirm…" : "Connecting to \(match.title)…"; self.completion = completion
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        receiver.acquire(networkMode: store.remoteDisplayNetworkMode); acquiredReceiver = true
        receiver.setPairingScreenVisible(true)
        let beganAt = Date()
        ScoreboardNearbyMatchService.shared.requestJoin(match, code: code, control: !asDisplay,
            mode: store.remoteDisplayNetworkMode) { [weak self] result in
            guard let self, self.isJoining else { return }
            switch result {
            case .failure(let error): self.fail(error)
            case .success:
                self.timeout = Task { [weak self] in
                    for _ in 0..<150 {
                        try? await Task.sleep(for: .milliseconds(100))
                        guard !Task.isCancelled, let self, self.isJoining else { return }
                        let descriptor = receiver.state?.control?.session
                        if receiver.lastReceivedAt.map({ $0 >= beganAt }) == true,
                           receiver.state?.game.matchID == match.matchID,
                           descriptor?.ownerDeviceID == match.id || descriptor?.hostDeviceID == match.id {
                            store.commitJoinedMatch(); self.isJoining = false
                            self.releaseReceiver(); self.completion?(); self.completion = nil
                            return
                        }
                    }
                    self?.fail(URLError(.timedOut))
                }
            }
        }
    }

    func cancel() {
        guard isJoining else { return }
        isJoining = false; timeout?.cancel(); timeout = nil; completion = nil
        ScoreboardNearbyMatchService.shared.cancelRequest()
        releaseReceiver(); ScoreboardStore.shared.leaveJoinedMatch()
        message = ""
    }
    private func fail(_ error: Error) {
        cancel(); message = error is CancellationError ? "" : error.localizedDescription
    }
    private func releaseReceiver() {
        guard acquiredReceiver else { return }
        acquiredReceiver = false
        ScoreboardRemoteDisplayReceiver.shared.setPairingScreenVisible(false)
        ScoreboardRemoteDisplayReceiver.shared.release()
    }
}

struct ScoreboardNearbyJoinContent: View {
    @ObservedObject private var nearby = ScoreboardNearbyMatchService.shared
    @ObservedObject private var store = ScoreboardStore.shared
    @StateObject private var join = ScoreboardJoinCoordinator()
    var invitation: ScoreboardNearbyInvitation? = nil
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
            if nearby.matches.isEmpty {
                Label("Looking for matches…", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
                Text("Ask the host to open Connect Devices and allow nearby joining. Check Local Network permission if the match does not appear.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(nearby.matches) { match in
                Button {
                    selected = match
                    code = invitation?.ownerID == match.id ? invitation?.code ?? "" : ""
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
                HStack(spacing: 24) {
                    RemotePairingActionButton(title: "Display", symbol: "tv", selected: asDisplay) { asDisplay = true }
                    RemotePairingActionButton(title: "Control Board", symbol: "gamecontroller", detail: "Requires host approval", selected: !asDisplay) { asDisplay = false }
                }.focusSection()
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
            if let error = nearby.discoveryError { Text(error).font(.callout).foregroundStyle(.orange) }
            if !join.message.isEmpty { Text(join.message).font(.callout).accessibilityIdentifier("join.nearbyStatus") }
        }
        .onAppear {
            if !acquired { acquired = true; nearby.acquireBrowser(mode: store.remoteDisplayNetworkMode) }
            selectInvitation()
        }
        .onChange(of: store.remoteDisplayNetworkMode) { _, mode in
            if acquired { nearby.releaseBrowser(); nearby.acquireBrowser(mode: mode) }
        }
        .onChange(of: nearby.matches.map(\.id)) { _, _ in selectInvitation() }
        .onChange(of: invitation) { _, _ in selectInvitation() }
        .onDisappear {
            join.cancel()
            if acquired { acquired = false; nearby.releaseBrowser() }
        }
    }
    private func selectInvitation() {
        if let invitation, let match = nearby.matches.first(where: { $0.id == invitation.ownerID }) {
            selected = match; code = invitation.code; usesPIN = true
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
    @State private var showsInvitation = false
    @State private var appliedInvitation = false
    @State private var feedback = ""
    #if os(iOS)
    @State private var scans = false
    #endif
    private var palette: SettingsPalette { store.theme.palette.settingsPalette(for: store.theme, colorScheme: colorScheme) }
    var body: some View {
        Group {
            if embedded { joinContent }
            else { NavigationStack { joinContent } }
        }
        .frame(minWidth: embedded ? 0 : 320, idealWidth: 780, minHeight: embedded ? 0 : 500)
        .onAppear {
            if !appliedInvitation {
                appliedInvitation = true
                if initialInvitation != nil { showsInvitation = true }
            }
        }
        .onChange(of: initialInvitation) { _, invitation in
            if let invitation { scannedCloud = invitation; showsInvitation = true }
        }
        #if os(iOS)
        .sheet(isPresented: $scans) { ScoreboardQRScannerView { value in scans = false; receive(value) } }
        #endif
    }
    private var joinContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(ScoreboardDeviceMode.current == .kiosk ? "Join as a display or controller. This device keeps no copy when you disconnect." : "Your local scoreboard stays saved on this device.").font(.callout).foregroundStyle(palette.secondaryText)
                ScoreboardCloudSection("Nearby") {
                    ScoreboardNearbyJoinContent(invitation: scannedNearby ?? nearbyInvitation, joined: finish).padding(.vertical, 12)
                }
                ScoreboardCloudSection("More Ways to Join") {
                    Button("Enter Code or Link", systemImage: "link") { showsInvitation = true }
                        .padding(.vertical, 12).accessibilityIdentifier("join.openInvitation")
                    #if os(iOS)
                    Divider()
                    Button("Scan QR", systemImage: "qrcode.viewfinder") { scans = true }.padding(.vertical, 12)
                    #endif
                    Divider()
                    NavigationLink("Show This Device’s Pairing Code") { ScoreboardWaitingForPairingView(joined: finish) }
                        .padding(.vertical, 12)
                }
                if !feedback.isEmpty { Text(feedback).font(.callout).foregroundStyle(.orange) }
            }.padding(24).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .background(palette.detailBackground).foregroundStyle(palette.primaryText)
        .navigationTitle("Join Match")
        .navigationDestination(isPresented: $showsInvitation) {
            ScrollView {
                ScoreboardMatchGuestJoinForm(initialInvitation: scannedCloud ?? initialInvitation,
                    beforeConnect: { control in
                        try store.prepareJoiningMatch(asDisplay: !control)
                        if !store.remoteDisplayNetworkMode.allowsCloud { store.setRemoteDisplayNetworkMode(.preferLocal) }
                    }, joined: { store.commitJoinedMatch(); finish() },
                    failed: { if store.isPreparingMatchJoin { store.leaveJoinedMatch() } },
                    receivedNearbyInvitation: { scannedNearby = $0; showsInvitation = false })
                    .padding(24)
            }.navigationTitle("Invitation")
        }
        .toolbar { if !embedded { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } } }
    }
    private func receive(_ value: String) {
        if let invitation = ScoreboardNearbyInvitation.parse(value) { scannedNearby = invitation; showsInvitation = false }
        else if let invitation = ScoreboardMatchInvitation.parse(value) { scannedCloud = invitation; showsInvitation = true }
        else { feedback = "This QR code is not a match invitation." }
    }
    private func finish() { if let finished { finished() } else { dismiss() } }
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
