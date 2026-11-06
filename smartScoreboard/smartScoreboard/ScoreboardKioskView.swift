import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Shared by Apple TV, Mac, and iPad; iPhone keeps its compact joining screen.
enum ScoreboardKioskPresentation {
    static var usesSharedLayout: Bool {
        #if os(tvOS) || os(macOS)
        ScoreboardDeviceMode.current == .kiosk
        #else
        ScoreboardDeviceMode.current == .kiosk && UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
    static var platformName: String {
        #if os(tvOS)
        "Apple TV"
        #elseif os(macOS)
        "Mac"
        #else
        "iPad"
        #endif
    }
}

private enum KioskHomePage: Hashable { case nearby, cloud, settings }

struct ScoreboardKioskHomeView: View {
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    let hasLiveState: Bool
    let returnToLive: () -> Void
    let showAbout: () -> Void
    let discardHostedMatch: () -> Void
    @ObservedObject private var store = ScoreboardStore.shared
    @State private var path: [KioskHomePage] = []
    @State private var lastAction = "tv.nearby"
    @State private var confirmsLeave = false
    @FocusState private var focused: String?

    var body: some View {
        NavigationStack(path: $path) {
            landing
                .navigationDestination(for: KioskHomePage.self) { page in
                    switch page {
                    case .nearby:
                        ScrollView { ScoreboardNearbyJoinContent(joined: returnToLive).padding(32).frame(maxWidth: 1400).frame(maxWidth: .infinity) }
                            .navigationTitle("Nearby Scoreboards")
                    case .cloud:
                        ScrollView {
                            ScoreboardMatchGuestJoinForm(beforeConnect: { control in
                                try store.prepareJoiningMatch(asDisplay: !control)
                                if !store.remoteDisplayNetworkMode.allowsCloud { store.setRemoteDisplayNetworkMode(.preferLocal) }
                            }, joined: { store.commitJoinedMatch(); returnToLive() },
                               failed: { if store.isPreparingMatchJoin { store.leaveJoinedMatch() } })
                            .padding(32).frame(maxWidth: 1400).frame(maxWidth: .infinity)
                        }.navigationTitle("Cloud Code & Password")
                    case .settings:
                        ScoreboardKioskSettingsView(showAbout: showAbout) { path = []; lastAction = "tv.nearby" }
                    }
                }
        }
        .preferredColorScheme(.dark)
        .background(Color(red: 0.035, green: 0.055, blue: 0.10).ignoresSafeArea())
        .alert("Leave Scoreboard?", isPresented: $confirmsLeave) {
            Button("Leave Scoreboard", role: .destructive) {
                receiver.disconnectFromOperator(); store.leaveJoinedMatch(); receiver.discardReceivedScoreboard()
                path = []; lastAction = "tv.nearby"
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This clears the received match on this device. The host keeps running the scoreboard.") }
    }

    private var landing: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 900 || geometry.size.width < 1400
            if geometry.size.width < 900 || geometry.size.height < 640 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        identityPanel(compact: true, fillsHeight: false)
                        actions(compact: true)
                    }.padding(28)
                }
            } else {
                HStack(alignment: .top, spacing: compact ? 36 : 70) {
                    identityPanel(compact: compact, fillsHeight: true)
                        .frame(width: max(280, min(600, geometry.size.width * 0.34)), alignment: .leading)
                    ScrollView { actions(compact: compact).padding(18) }.scoreboardKioskFocusSection()
                }.padding(.horizontal, compact ? 40 : 72).padding(.vertical, compact ? 36 : 60)
            }
        }
        .defaultFocus($focused, hasLiveState ? "tv.live" : lastAction)
        #if os(tvOS) || os(macOS)
        .onExitCommand(perform: hasLiveState ? returnToLive : nil)
        #endif
    }

    private func identityPanel(compact: Bool, fillsHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 20) {
            HStack(spacing: 18) {
                ScoreboardLogoView(size: compact ? 56 : 80)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Smart Scoreboard").font(.system(size: compact ? 30 : 44, weight: .bold)).lineLimit(2)
                    Text("\(ScoreboardKioskPresentation.platformName) · Kiosk Mode")
                        .font(.system(size: compact ? 20 : 26)).foregroundStyle(.secondary)
                        .accessibilityIdentifier("kiosk.mode")
                }
            }
            if fillsHeight { Spacer(minLength: 8) }
            Text("DEVICE PAIRING PIN").font(.system(size: compact ? 18 : 22, weight: .semibold)).foregroundStyle(.secondary)
            Text(receiver.pairingCode).font(.system(size: compact ? 56 : 76, weight: .bold, design: .monospaced))
                .contentTransition(.opacity).accessibilityIdentifier("kiosk.devicePIN")
            Text("The host can discover this device and enter this PIN. Or choose Nearby Scoreboards to join from here.")
                .font(.system(size: compact ? 20 : 24)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 24) {
                ScoreboardPairingQRCode(value: ScoreboardPairingLink.nearbyURL(deviceID: receiver.displayID, code: receiver.pairingCode), size: compact ? 88 : 120)
                KioskActionButton("New PIN", symbol: "arrow.clockwise", id: "tv.newPIN", focus: $focused) { receiver.resetPairingCode() }
            }
            if fillsHeight { Spacer(minLength: 8) }
            ScoreboardHomeStatusView(stacked: true, fontSize: compact ? 16 : 20)
            Text(inputInstructions).font(.system(size: compact ? 16 : 20)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .leading)
            .scoreboardKioskFocusSection().scoreboardHomeEntrance()
    }

    private func actions(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(hasLiveState ? "Your Connection" : "Join a Scoreboard").font(.system(size: compact ? 30 : 36, weight: .bold))
            if hasLiveState {
                KioskActionButton("Return to Scoreboard", symbol: "play.rectangle", id: "tv.live", focus: $focused, primary: true, action: returnToLive)
            }
            if store.hasHostedMatchToDiscard {
                Text("This device has a hosted match from an earlier version. Return it to the owner before resetting or joining another scoreboard.").font(.system(size: 24)).foregroundStyle(.orange)
                KioskActionButton("Discard Previous Hosted Match", symbol: "trash", id: "tv.discard", focus: $focused, destructive: true, action: discardHostedMatch)
            } else {
                KioskActionButton("Nearby Scoreboards", symbol: "dot.radiowaves.left.and.right", detail: "Discover a host on LAN or nearby Wi-Fi", id: "tv.nearby", focus: $focused, primary: !hasLiveState) {
                    lastAction = "tv.nearby"; path.append(.nearby)
                }
                KioskActionButton("Cloud Code & Password", symbol: "cloud", detail: "Join without signing in", id: "tv.cloud", focus: $focused) {
                    lastAction = "tv.cloud"; path.append(.cloud)
                }
            }
            KioskActionButton("App Settings", symbol: "gearshape", detail: "Cloud server, connection and factory reset", id: "tv.settings", focus: $focused) {
                lastAction = "tv.settings"; path.append(.settings)
            }
            if hasLiveState || store.isJoinedMatchActive {
                KioskActionButton("Leave Scoreboard", symbol: "rectangle.portrait.and.arrow.right", id: "tv.leave", focus: $focused, destructive: true) { confirmsLeave = true }
            }
            Text("Join as a display or an approved control board. Received match data is cleared when disconnected.")
                .font(.system(size: compact ? 20 : 22)).foregroundStyle(.secondary)
        }.scoreboardHomeEntrance(order: 1)
    }
    private var inputInstructions: String {
        #if os(tvOS)
        "Use arrows to move · Select to choose\nBack returns to the previous screen"
        #elseif os(macOS)
        "Click to choose · Tab to move\nEsc returns to the scoreboard"
        #else
        "Choose an option to join. Use Back to return to this screen."
        #endif
    }
}

private struct ScoreboardKioskSettingsView: View {
    let showAbout: () -> Void
    var didReset: () -> Void
    @ObservedObject private var store = ScoreboardStore.shared
    @State private var confirmsForget = false
    @State private var confirmsReset = false
    @State private var resetError: String?
    @FocusState private var focused: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                #if os(tvOS)
                Text("Apple TV always uses Kiosk Mode.").foregroundStyle(.secondary)
                #else
                ScoreboardSoftwareGeneralSettingsView()
                #endif
                ScoreboardCloudRemoteSection(mode: store.remoteDisplayNetworkMode, permitsSessionJoining: false)
                RemotePairingCard("Connection Preference") {
                    ForEach(ScoreboardRemoteDisplayNetworkMode.allCases) { mode in
                        KioskActionButton(mode.title, symbol: "network", detail: mode.detail, id: "tv.policy.\(mode.rawValue)", focus: $focused,
                            selected: store.remoteDisplayNetworkMode == mode) { store.setRemoteDisplayNetworkMode(mode) }
                    }
                }
                RemotePairingCard("This Device") {
                    KioskActionButton("Forget Saved Pairings", symbol: "link.badge.plus", id: "tv.forget", focus: $focused) { confirmsForget = true }
                    KioskActionButton("About Smart Scoreboard", symbol: "info.circle", id: "tv.about", focus: $focused, action: showAbout)
                }
                RemotePairingCard("Factory Default") {
                    Text("Remove cloud access, the self-hosted URL, saved pairings, local files and settings from this device. The host’s scoreboard is not changed.")
                        .font(.system(size: 24)).foregroundStyle(.secondary)
                    KioskActionButton("Factory Default", symbol: "arrow.counterclockwise", id: "tv.factoryDefault", focus: $focused,
                        destructive: true, enabled: !store.hasHostedMatchToDiscard) { confirmsReset = true }
                    if store.hasHostedMatchToDiscard { Text("Return or explicitly discard the previous hosted match first.").foregroundStyle(.orange) }
                }
            }.padding(64).frame(maxWidth: 1400).frame(maxWidth: .infinity)
        }.navigationTitle("App Settings")
        .alert("Forget Saved Pairings?", isPresented: $confirmsForget) {
            Button("Forget Pairings", role: .destructive) { ScoreboardRemoteDisplayReceiver.shared.forgetTrustedHosts() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Factory Default This Device?", isPresented: $confirmsReset) {
            Button("Factory Default", role: .destructive) {
                do { try store.resetKioskToFactoryDefaults(); didReset() }
                catch { resetError = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone. You will need to pair again and re-enter any self-hosted cloud URL.") }
        .alert("Unable to Reset", isPresented: Binding(get: { resetError != nil }, set: { if !$0 { resetError = nil } })) {
            Button("OK") { resetError = nil }
        } message: { Text(resetError ?? "") }
    }
}

/// Shared controller, with focus and Siri Remote commands on Apple TV.
struct ScoreboardKioskControlView: View {
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    var showConnection: () -> Void
    @FocusState private var focused: String?
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let state = receiver.state {
                    VStack(spacing: 28) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 28) {
                                controlHeader.frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
                                KioskActionButton("Connection", symbol: "network", id: "control.connection", focus: $focused, action: showConnection).frame(width: 300)
                            }
                            VStack(alignment: .leading, spacing: 20) {
                                controlHeader
                                KioskActionButton("Connection", symbol: "network", id: "control.connection", focus: $focused, action: showConnection)
                            }
                        }.scoreboardKioskFocusSection()
                        if !receiver.canSendControlCommand {
                            Label("Waiting for a fresh connection. Score controls are unavailable.", systemImage: "wifi.exclamationmark").foregroundStyle(.orange)
                        }
                        if state.rules.supportsScore {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: geometry.size.width >= 1000 ? 2 : 1), spacing: 28) {
                                score(state.teams.home.name, value: state.teams.home.score, side: .home, state: state)
                                score(state.teams.guest.name, value: state.teams.guest.score, side: .guest, state: state)
                            }
                        }
                        if state.clocks.showsGameClock || state.rules.usesChessClocks {
                            VStack(spacing: 20) {
                                if state.rules.usesChessClocks {
                                    HStack(spacing: 32) {
                                        KioskActionButton("\(state.teams.home.name) · \(state.clocks.formattedHomeChessClock)", symbol: "timer", id: "control.homeClock", focus: $focused, enabled: receiver.canSendControlCommand) { send(state.rules.sport == .debate ? "debate.turn" : "chess.side", side: .home) }
                                        KioskActionButton("\(state.teams.guest.name) · \(state.clocks.formattedGuestChessClock)", symbol: "timer", id: "control.guestClock", focus: $focused, enabled: receiver.canSendControlCommand) { send(state.rules.sport == .debate ? "debate.turn" : "chess.side", side: .guest) }
                                    }
                                } else { Text(state.clocks.formattedGameClock).font(.system(size: 64, weight: .bold, design: .monospaced)) }
                                KioskActionButton("Start / Pause Clock", symbol: "playpause.fill", id: "control.clock", focus: $focused, primary: true, enabled: receiver.canSendControlCommand) { send("clock.toggle") }.frame(maxWidth: 650)
                            }.scoreboardKioskFocusSection()
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: min(280, max(110, geometry.size.width - controlPadding * 2))), spacing: 32)], spacing: 24) {
                            if state.rules.supportsShotClock {
                                KioskActionButton("Shot Clock · \(state.clocks.formattedShotClock)", symbol: "playpause", id: "control.shot", focus: $focused, enabled: receiver.canSendControlCommand) { send("shot.toggle") }
                            }
                            if state.rules.supportsPeriod {
                                KioskActionButton("Previous \(state.rules.periodTitle)", symbol: "minus", id: "control.periodMinus", focus: $focused, enabled: receiver.canSendControlCommand) { send("period.adjust", value: -1) }
                                KioskActionButton("Next \(state.rules.periodTitle)", symbol: "plus", id: "control.periodPlus", focus: $focused, enabled: receiver.canSendControlCommand) { send("period.adjust", value: 1) }
                            }
                        }.scoreboardKioskFocusSection()
                        if let result = receiver.controlResult, !result.success { Text(result.message ?? "Command unavailable").foregroundStyle(.orange) }
                    }.padding(.horizontal, controlPadding).padding(.vertical, 40)
                    .defaultFocus($focused, receiver.canSendControlCommand ? (state.rules.supportsScore ? state.rules.scoreStepOptions.first.map { "control.home.plus.\($0)" } ?? "control.home.minus" : "control.clock") : "control.connection")
                }
            }
        }.background(Color(red: 0.035, green: 0.055, blue: 0.10).ignoresSafeArea()).preferredColorScheme(.dark)
        #if os(tvOS) || os(macOS)
        .onExitCommand(perform: showConnection)
        #endif
        #if os(tvOS)
        .onPlayPauseCommand {
            guard let state = receiver.state, state.clocks.showsGameClock || state.rules.usesChessClocks else { return }
            send("clock.toggle")
        }
        #endif
        .onChange(of: receiver.canSendControlCommand) { _, ready in if !ready { focused = "control.connection" } }
    }
    private var controlHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Control Board").font(.system(size: 38, weight: .bold))
            Text(controlInstructions).font(.system(size: 20)).foregroundStyle(.secondary)
        }
    }
    private var controlPadding: CGFloat {
        #if os(tvOS)
        72
        #else
        28
        #endif
    }
    private var controlInstructions: String {
        #if os(tvOS)
        "Arrows: move · Select: activate · Play/Pause: clock · Back: connection"
        #elseif os(macOS)
        "Click a control · Tab to move · Esc opens connection options"
        #else
        "Choose a score or clock control. Connection options stay available above."
        #endif
    }
    private func score(_ name: String, value: Int, side: TeamSide, state: ScoreboardWebAPIState) -> some View {
        VStack(spacing: 18) {
            Text(name).font(.system(size: 32, weight: .bold)).lineLimit(2)
            Text("\(value)").font(.system(size: 96, weight: .bold, design: .rounded)).monospacedDigit()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 18)], spacing: 18) {
                ForEach(Array(state.rules.scoreStepOptions.prefix(3)), id: \.self) { amount in
                    KioskActionButton("+\(amount)", symbol: "", id: "control.\(side.rawValue).plus.\(amount)", focus: $focused, primary: true, enabled: receiver.canSendControlCommand) { send("score.adjust", side: side, value: amount) }
                }
                KioskActionButton("−1", symbol: "", id: "control.\(side.rawValue).minus", focus: $focused, enabled: receiver.canSendControlCommand) { send("score.adjust", side: side, value: -1) }
            }.frame(maxWidth: CGFloat((min(3, state.rules.scoreStepOptions.count) + 1) * 138 - 18))
        }.padding(26).frame(maxWidth: .infinity).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24)).scoreboardKioskFocusSection()
    }
    private func send(_ action: String, side: TeamSide? = nil, value: Int? = nil) {
        guard receiver.canSendControlCommand, let state = receiver.state else { return }
        receiver.sendCommand(.init(action: action, sport: state.rules.sport, side: side, value: value))
    }
}

private struct KioskActionButton: View {
    let title: String
    let symbol: String
    var detail: String? = nil
    let id: String
    var focus: FocusState<String?>.Binding
    var primary = false
    var selected = false
    var destructive = false
    var enabled = true
    let action: () -> Void
    init(_ title: String, symbol: String, detail: String? = nil, id: String, focus: FocusState<String?>.Binding,
         primary: Bool = false, selected: Bool = false, destructive: Bool = false, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.detail = detail; self.id = id; self.focus = focus
        self.primary = primary; self.selected = selected; self.destructive = destructive; self.enabled = enabled; self.action = action
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    private var isFocused: Bool { focus.wrappedValue == id || hovered }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                if !symbol.isEmpty { Image(systemName: symbol).frame(width: 30) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 27, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    if let detail { Text(detail).font(.system(size: 21)).foregroundStyle(isFocused ? .black.opacity(0.65) : .white.opacity(0.65)).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark.circle.fill") }
            }.padding(22).frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                .foregroundStyle(isFocused ? Color.black : destructive ? Color.red : Color.white)
                .background(isFocused ? .white : primary ? Color.blue.opacity(0.75) : .white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(isFocused ? .white : .white.opacity(0.12), lineWidth: isFocused ? 3 : 1) }
        }.buttonStyle(ScoreboardHomeButtonStyle(hoverEffect: false)).focusEffectDisabled().focused(focus, equals: id).disabled(!enabled).opacity(enabled ? 1 : 0.4)
            .scaleEffect(isFocused && !reduceMotion ? 1.025 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isFocused)
            #if !os(tvOS)
            .onHover { hovered = $0 }
            #endif
            .accessibilityIdentifier(id)
    }
}

private extension View {
    @ViewBuilder func scoreboardKioskFocusSection() -> some View {
        #if os(tvOS) || os(macOS)
        self.focusSection()
        #else
        self
        #endif
    }
}
