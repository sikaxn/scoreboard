import SwiftUI

private enum RemotePairingPage: String, CaseIterable, Identifiable {
    case nearby, cloud, connection, device
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nearby: "Nearby Pairing"
        case .cloud: "Cloud"
        case .connection: "Connection"
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
        .focused($focused)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .scaleEffect(focused ? 1.025 : 1)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
    private var background: Color {
        if focused { return .white }
        if primary { return Color(red: 0.05, green: 0.36, blue: 0.82) }
        return .white.opacity(selected ? 0.16 : 0.06)
    }
}

struct ScoreboardRemotePairingHomeView: View {
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    @ObservedObject private var sessionStore = ScoreboardStore.shared
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @ObservedObject private var router = ScoreboardRemoteConnectionRouter.shared
    let hasLiveState: Bool
    let returnToLive: () -> Void
    let networkMode: ScoreboardRemoteDisplayNetworkMode
    let setNetworkMode: (ScoreboardRemoteDisplayNetworkMode) -> Void
    let showsPairingControls: Bool
    let openScoreboardWindow: (() -> Void)?
    let exitRemoteDisplayMode: (() -> Void)?
    let showAbout: () -> Void
    let discardHostedMatch: () -> Void
    @AppStorage("scoreboard.remotePairingPage", store: ScoreboardPreferences.current) private var selectedPageRaw = "nearby"
    @State private var confirmsForget = false

    private var pages: [RemotePairingPage] {
        if !showsPairingControls { return [.device] }
        return sessionStore.hasHostedMatchToDiscard ? [.device, .cloud] : RemotePairingPage.allCases
    }
    private var selectedPage: RemotePairingPage {
        let requested = RemotePairingPage(rawValue: selectedPageRaw) ?? .nearby
        return pages.contains(requested) ? requested : pages[0]
    }
    private var activeReceiver: ScoreboardRemoteDisplayReceiver {
        networkMode.allowsCloud && router.route == .cloud ? cloud.receiver : receiver
    }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 900 && proxy.size.height >= 500
            VStack(alignment: .leading, spacing: 24) {
                header
                if !showsPairingControls {
                    ScrollView { passiveContent.padding(.bottom, 24) }
                } else if wide {
                    HStack(alignment: .top, spacing: 28) {
                        ScrollView { navigation.padding(8) }
                            .frame(width: navigationWidth)
                        contentScroll
                    }
                } else {
                    pageMenu
                    contentScroll
                }
            }
            .padding(RemotePairingAppearance.padding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .environment(\.colorScheme, .dark)
        .onChange(of: networkMode) { _, mode in
            if !mode.allowsCloud && cloud.isRemotePairing { cloud.cancelLink() }
        }
        .confirmationDialog("Forget Paired Devices?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget Paired Devices", role: .destructive) { receiver.forgetTrustedHosts() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved nearby operators will need to pair again. Cloud account registration is managed on the Cloud page.")
        }
        #if os(tvOS)
        .onExitCommand {
            if selectedPage != pages[0] { selectedPageRaw = pages[0].rawValue }
            else if hasLiveState { returnToLive() }
        }
        #endif
    }

    private var navigationWidth: CGFloat {
        #if os(tvOS)
        300
        #else
        250
        #endif
    }
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                branding.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                RemotePairingStatusBadge(receiver: activeReceiver)
            }
            VStack(alignment: .leading, spacing: 12) {
                branding
                RemotePairingStatusBadge(receiver: activeReceiver)
            }
        }
    }
    private var branding: some View {
        HStack(spacing: 16) {
            Image("ScoreboardIcon").resizable().scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Scoreboard")
                    .font(.system(size: RemotePairingAppearance.titleSize, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(remoteModeTitle)
                    .font(.system(size: RemotePairingAppearance.captionSize))
                    .foregroundStyle(.white.opacity(0.6))
            }.foregroundStyle(.white)
        }
    }
    private var remoteModeTitle: LocalizedStringKey {
        #if os(tvOS)
        "Remote Display & Session Host"
        #else
        "Remote Display & Control"
        #endif
    }
    private var navigation: some View {
        VStack(spacing: 12) {
            ForEach(pages) { page in
                RemotePairingActionButton(title: page.title, symbol: page.symbol, selected: page == selectedPage) {
                    selectedPageRaw = page.rawValue
                }
                .accessibilityIdentifier("remote.pairing.page.\(page.rawValue)")
            }
            if hasLiveState {
                Divider().overlay(.white.opacity(0.15)).padding(.vertical, 8)
                returnButton
            }
        }
    }
    private var pageMenu: some View {
        HStack(spacing: 12) {
            Picker("Connection", selection: Binding(get: { selectedPage.rawValue }, set: { selectedPageRaw = $0 })) {
                ForEach(pages) { page in Label(ScoreboardLocalization.string(page.title), systemImage: page.symbol).tag(page.rawValue) }
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            #else
            .pickerStyle(.menu)
            #endif
            .tint(.white)
            .accessibilityIdentifier("remote.pairing.navigation")
            Spacer(minLength: 0)
            if hasLiveState {
                Button(action: returnToLive) { Label("Return to Live", systemImage: "play.rectangle.fill") }
                    .buttonStyle(.bordered).tint(.white)
            }
        }
    }
    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(verbatim: ScoreboardLocalization.string(selectedPage.title))
                    .font(.system(size: RemotePairingAppearance.titleSize, weight: .bold)).foregroundStyle(.white)
                pageContent
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(selectedPage)
    }
    @ViewBuilder private var pageContent: some View {
        switch selectedPage {
        case .nearby: nearbyContent
        case .cloud:
            ScoreboardCloudRemoteSection(mode: networkMode,
                enableCloud: { setNetworkMode(.preferCloud) },
                permitsSessionJoining: !sessionStore.hasHostedMatchToDiscard)
        case .connection: connectionContent
        case .device: deviceContent
        }
    }
    private var nearbyContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            RemotePairingCard("Pairing Code") {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 32) {
                        localPairingControls.frame(maxWidth: .infinity)
                        nearbyQR
                    }
                    VStack(spacing: 24) { localPairingControls; nearbyQR }
                }
                Text("On the host, open Settings > Remote Display & Control. Select this device and enter its code, or scan the QR code.")
                    .font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            RemotePairingCard("Connection") {
                Text(nearbyStatusDetail)
                    .font(.system(size: RemotePairingAppearance.bodySize)).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Text(savedPairingDetail).font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    private var localCode: some View {
        Text(receiver.pairingCode)
            .font(.system(size: 84, weight: .bold, design: .rounded))
            .monospacedDigit().tracking(6)
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.6)
            .accessibilityIdentifier("remote.pairing.code")
    }
    private var localPairingControls: some View {
        VStack(spacing: 18) {
            localCode
            RemotePairingActionButton(title: "New Code", symbol: "arrow.clockwise") { receiver.resetPairingCode() }
        }
    }
    private var nearbyQR: some View {
        ScoreboardPairingQRCode(value: ScoreboardPairingLink.nearbyURL(deviceID: receiver.displayID, code: receiver.pairingCode), size: RemotePairingAppearance.qrSize)
    }
    private var connectionContent: some View {
        RemotePairingCard("Connection") {
            let connection = router.connectionStatus
            Text(connection.summary)
                .font(.system(size: RemotePairingAppearance.bodySize, weight: .semibold)).foregroundStyle(.white)
            if let medium = connection.active?.interfaceTitle {
                Text(medium).font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.65))
            }
            if let other = connection.otherConnections {
                Text("Available: \(other)").font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.65))
            }
            Text("Choose the preferred route to your host. Local-only modes do not use the cloud.")
                .font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.65))
            ForEach(ScoreboardRemoteDisplayNetworkMode.allCases) { mode in
                RemotePairingActionButton(title: mode.title, symbol: mode.allowsCloud ? "cloud" : mode.includesPeerToPeer ? "antenna.radiowaves.left.and.right" : "network",
                    detail: mode.detail, selected: networkMode == mode) { setNetworkMode(mode) }
                    .accessibilityIdentifier("remote.connection.\(mode.rawValue)")
            }
        }
    }
    @ViewBuilder private var deviceContent: some View {
        if sessionStore.hasHostedMatchToDiscard {
            RemotePairingCard("Session Host") {
                Text(receiver.isHostingSession ? "Pairing is managed by the session owner." : "This device still holds a hosted match. Discard it before pairing again.")
                    .font(.system(size: RemotePairingAppearance.bodySize)).foregroundStyle(.white)
                Text(receiver.state?.control?.session?.safeToDisconnect == true
                    ? "Safe to Disconnect — the owner has saved this match and all timers are stopped."
                    : "Match active or sync pending — keep this host running until the owner reconnects and saves the match.")
                    .font(.system(size: RemotePairingAppearance.captionSize)).foregroundStyle(.white.opacity(0.65))
                if let message = sessionStore.sessionStatusMessage {
                    Text(ScoreboardLocalization.remoteSessionMessage(message)).foregroundStyle(.orange)
                }
                RemotePairingActionButton(title: "Discard Match & Stop Hosting", symbol: "trash", destructive: true, action: discardHostedMatch)
            }
        }
        RemotePairingCard("This Device") {
            if hasLiveState { returnButton }
            if receiver.canDisconnectFromOperator {
                RemotePairingActionButton(title: "Disconnect Nearby", symbol: "xmark.circle", destructive: true) { receiver.disconnectFromOperator() }
            }
            if let openScoreboardWindow {
                RemotePairingActionButton(title: "Open Scoreboard", symbol: "rectangle.on.rectangle", action: openScoreboardWindow)
            }
            if let exitRemoteDisplayMode {
                RemotePairingActionButton(title: "Exit Display Mode", symbol: "rectangle.portrait.and.arrow.right", action: exitRemoteDisplayMode)
            }
            RemotePairingActionButton(title: "About", symbol: "info.circle", action: showAbout)
            if !sessionStore.hasHostedMatchToDiscard {
                RemotePairingActionButton(title: "Forget Nearby Devices", symbol: "trash", destructive: true, disabled: receiver.trustedHosts.isEmpty) { confirmsForget = true }
            }
        }
    }
    private var returnButton: some View {
        RemotePairingActionButton(title: activeReceiver.isControlBoardDevice ? "Return to Control Board" : "Return to Live", symbol: "play.rectangle.fill", primary: true, action: returnToLive)
    }
    private var passiveContent: some View {
        RemotePairingCard("Waiting for Remote Scoreboard") {
            Image(systemName: "display.and.arrow.down").font(.system(size: 50)).foregroundStyle(.white.opacity(0.8))
            Text("Use the primary screen: Settings > Remote Display & Control.")
                .font(.system(size: RemotePairingAppearance.bodySize)).foregroundStyle(.white.opacity(0.65))
        }.padding(8)
    }
    private var savedPairingDetail: String {
        switch receiver.trustedHosts.count {
        case 0: ScoreboardLocalization.string("No operator devices saved")
        case 1: ScoreboardLocalization.string("1 operator device saved")
        default: scoreboardLocalizedFormat(ScoreboardLocalization.string("%d operator devices saved"), locale: .current, arguments: [receiver.trustedHosts.count])
        }
    }
    private var nearbyStatusDetail: String {
        switch receiver.status {
        case .waiting: ScoreboardLocalization.string("Ready to pair with a nearby host.")
        case .paired(let name): scoreboardLocalizedFormat(ScoreboardLocalization.string("Receiving live scoreboard updates from %@."), locale: .current, arguments: [name])
        case .disconnected(let message), .failed(let message): message
        }
    }
}

private struct RemotePairingStatusBadge: View {
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(receiver.status.isLive ? .green : .orange).frame(width: 8, height: 8)
            Text(verbatim: ScoreboardLocalization.string(receiver.isHostingSession ? "Hosting" : receiver.status.title))
                .font(.system(size: RemotePairingAppearance.captionSize, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.white.opacity(0.07), in: Capsule())
        .fixedSize()
    }
}
