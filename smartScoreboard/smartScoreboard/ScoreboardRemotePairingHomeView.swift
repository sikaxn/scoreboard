import SwiftUI

private enum RemotePairingPage: String, CaseIterable, Identifiable {
    case nearby, cloud, connection, device
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nearby: "Join Nearby Match"
        case .cloud: "Enter Invitation"
        case .connection: "Settings"
        case .device: "This Device"
        }
    }
    var symbol: String {
        switch self {
        case .nearby: "antenna.radiowaves.left.and.right"
        case .cloud: "cloud"
        case .connection: "arrow.left.arrow.right"
        case .device: "display"
        }
    }
}

enum RemotePairingAppearance {
    static var titleSize: CGFloat {
        #if os(tvOS)
        34
        #else
        26
        #endif
    }
    static var bodySize: CGFloat {
        #if os(tvOS)
        24
        #else
        17
        #endif
    }
    static var captionSize: CGFloat {
        #if os(tvOS)
        20
        #else
        14
        #endif
    }
    static var padding: CGFloat {
        #if os(tvOS)
        32
        #else
        20
        #endif
    }
    static var qrSize: CGFloat {
        #if os(tvOS)
        200
        #else
        160
        #endif
    }
}

struct RemotePairingCard<Content: View>: View {
    let title: LocalizedStringKey
    let content: () -> Content
    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: RemotePairingAppearance.bodySize, weight: .bold))
                .foregroundStyle(.white)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12)) }
    }
}

struct RemotePairingActionButton: View {
    let title: String
    let symbol: String
    var detail: String? = nil
    var selected = false
    var primary = false
    var destructive = false
    var disabled = false
    var verbatim = false
    let action: () -> Void
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: symbol).frame(width: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: verbatim ? title : ScoreboardLocalization.string(title))
                        .fontWeight(.semibold)
                    if let detail {
                        Text(verbatim: ScoreboardLocalization.string(detail))
                            .font(.system(size: RemotePairingAppearance.captionSize))
                            .foregroundStyle(focused ? .black.opacity(0.65) : .white.opacity(0.65))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if selected { Image(systemName: "checkmark.circle.fill") }
            }
            .font(.system(size: RemotePairingAppearance.bodySize))
            .foregroundStyle(focused ? .black : destructive ? Color(red: 1, green: 0.48, blue: 0.48) : .white)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selected ? .white.opacity(0.5) : .white.opacity(0.10)) }
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .focusEffectDisabled()
        #endif
        .focused($focused)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .scaleEffect(focused && !reduceMotion ? 1.025 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: focused)
    }
    private var background: Color {
        if focused { return .white }
        if primary { return Color(red: 0.05, green: 0.36, blue: 0.82) }
        return .white.opacity(selected ? 0.16 : 0.06)
    }
}

/// Kiosk landing screen. No file, account ownership, or host controls appear here.
struct ScoreboardRemotePairingHomeView: View {
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    let hasLiveState: Bool
    let returnToLive: () -> Void
    let networkMode: ScoreboardRemoteDisplayNetworkMode
    let setNetworkMode: (ScoreboardRemoteDisplayNetworkMode) -> Void
    let showsPairingControls: Bool
    let openScoreboardWindow: (() -> Void)?
    let exitRemoteDisplayMode: (() -> Void)?
    let showAbout: () -> Void
    let discardHostedMatch: () -> Void
    @ObservedObject private var store = ScoreboardStore.shared
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @ObservedObject private var local = ScoreboardRemoteDisplayReceiver.shared
    @State private var forgot = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top) {
                        HStack(spacing: 18) {
                            ScoreboardLogoView(size: 64)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Smart Scoreboard").font(.largeTitle.bold())
                                Text("Kiosk Mode · Join a Scoreboard").font(.title3).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if hasLiveState { Button("Return to Scoreboard", action: returnToLive).buttonStyle(.borderedProminent) }
                    }
                    ScoreboardHomeStatusView().scoreboardHomeEntrance(order: 1)
                    if store.hasHostedMatchToDiscard {
                        RemotePairingCard("Previous Hosted Match") {
                            Text("This device still holds a match from the previous version. Return it to the owner before using join-only kiosk mode.")
                            Text(store.sessionStatusMessage ?? "Reconnect the owner to finish the handoff.").font(.callout)
                            Button("Discard Previous Hosted Match", role: .destructive, action: discardHostedMatch)
                        }
                    } else if showsPairingControls {
                        if store.localConnectionsEnabled {
                            ScoreboardNearbyJoinContent(joined: returnToLive)
                            Divider()
                        }
                        NavigationLink {
                            ScrollView {
                                ScoreboardMatchGuestJoinForm(beforeConnect: { control in
                                    try store.prepareJoiningMatch(asDisplay: !control)
                                    if !networkMode.allowsCloud { setNetworkMode(.preferLocal) }
                                }, joined: { store.commitJoinedMatch(); returnToLive() },
                                    failed: { if store.isPreparingMatchJoin { store.leaveJoinedMatch() } })
                                    .padding(32)
                            }.navigationTitle("Cloud Code & Password")
                        } label: { Label("Join with Cloud Code & Password", systemImage: "cloud") }
                            .buttonStyle(.bordered).disabled(!cloud.cloudEnabled).accessibilityIdentifier("kiosk.cloudJoin")
                        if store.localConnectionsEnabled {
                        NavigationLink {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 24) {
                                    Text("Device Pairing PIN").font(.title2.bold())
                                    Text(local.pairingCode).font(.system(size: 58, weight: .bold, design: .monospaced))
                                    Text("On the host, open Connect Devices → Pair Using the Kiosk’s Device PIN. Select this device and enter the PIN.")
                                        .foregroundStyle(.secondary)
                                    ScoreboardPairingQRCode(value: ScoreboardPairingLink.nearbyURL(deviceID: local.displayID, code: local.pairingCode), size: 180)
                                    Button("New PIN") { local.resetPairingCode() }
                                }.padding(32)
                            }.navigationTitle("Pair This Device")
                        } label: { Label("Show This Device’s Pairing PIN", systemImage: "qrcode") }.buttonStyle(.bordered)
                        }
                    }
                    Divider()
                    NavigationLink {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 28) {
                                ScoreboardSoftwareGeneralSettingsView()
                                ScoreboardLocalConnectionsToggle()
                                ScoreboardConnectionPreferencesView()
                                ScoreboardCloudRemoteSection(mode: networkMode, permitsSessionJoining: false)
                                Button("Forget Saved Pairings", role: .destructive) { forgot = true }
                                Button("About", action: showAbout)
                            }.padding(32)
                        }.navigationTitle("App Settings")
                    } label: { Label("App Settings", systemImage: "gearshape") }.buttonStyle(.bordered)
                    Text("Display or control a scoreboard hosted on another device. Received match data is cleared when disconnected.")
                        .font(.callout).foregroundStyle(.secondary)
                    if hasLiveState || store.isJoinedMatchActive {
                        Button("Leave Scoreboard", role: .destructive) {
                            local.disconnectFromOperator(); store.leaveJoinedMatch(); receiver.discardReceivedScoreboard()
                            returnToLive()
                        }.buttonStyle(.bordered)
                    }
                }.padding(40).frame(maxWidth: 1100).frame(maxWidth: .infinity, alignment: .center)
                    .scoreboardHomeEntrance()
            }.background(Color(red: 0.035, green: 0.055, blue: 0.10))
                .preferredColorScheme(.dark)
                .confirmationDialog("Forget Saved Pairings?", isPresented: $forgot, titleVisibility: .visible) {
                    Button("Forget Pairings", role: .destructive) { local.forgetTrustedHosts() }
                }
        }
    }
}

