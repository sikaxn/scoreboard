import Foundation
import SwiftUI

private func localizedRemoteDisplayString(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func localizedRemoteDisplayFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedRemoteDisplayString(key), locale: Locale.current, arguments: arguments)
}

struct RemoteScoreboardView: View {
    var exitRemoteDisplayMode: (() -> Void)?
    var openScoreboardWindow: (() -> Void)?
    var showsPairingControls: Bool

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var receiver: ScoreboardRemoteDisplayReceiver
    @State private var showsConfiguration = false
    @State private var hasAcquiredReceiver = false

    @MainActor
    init(
        exitRemoteDisplayMode: (() -> Void)? = nil,
        openScoreboardWindow: (() -> Void)? = nil,
        showsPairingControls: Bool = true
    ) {
        self.receiver = ScoreboardRemoteDisplayReceiver.shared
        self.exitRemoteDisplayMode = exitRemoteDisplayMode
        self.openScoreboardWindow = openScoreboardWindow
        self.showsPairingControls = showsPairingControls
    }

    init(
        receiver: ScoreboardRemoteDisplayReceiver,
        exitRemoteDisplayMode: (() -> Void)? = nil,
        openScoreboardWindow: (() -> Void)? = nil,
        showsPairingControls: Bool = true
    ) {
        self.receiver = receiver
        self.exitRemoteDisplayMode = exitRemoteDisplayMode
        self.openScoreboardWindow = openScoreboardWindow
        self.showsPairingControls = showsPairingControls
    }

    var body: some View {
        ZStack {
            if let state = receiver.state, !showsConfiguration {
                TimelineView(.periodic(from: Date(), by: 0.25)) { timeline in
                    let health = RemoteDisplayConnectionHealth(
                        status: receiver.status,
                        lastHandshakeAt: receiver.lastHeartbeatAt ?? receiver.lastReceivedAt,
                        now: timeline.date
                    )

                    ZStack(alignment: .topTrailing) {
                        RemoteScoreboardFace(
                            state: state,
                            lastReceivedAt: receiver.lastReceivedAt,
                            masterClockOffset: receiver.masterClockOffset,
                            now: timeline.date
                        )
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .focusable(true)
                        .onTapGesture {
                            if showsPairingControls {
                                showsConfiguration = true
                            }
                        }

                        RemoteDisplayLiveBadge(health: health) {
                            if showsPairingControls {
                                showsConfiguration = true
                            }
                        }
                        .padding(.top, 18)
                        .padding(.trailing, 18)
                    }
                }
            } else {
                RemoteDisplayConfigurationView(
                    receiver: receiver,
                    hasLiveState: receiver.state != nil,
                    returnToLive: { showsConfiguration = false },
                    exitRemoteDisplayMode: exitRemoteDisplayMode,
                    openScoreboardWindow: openScoreboardWindow,
                    showsPairingControls: showsPairingControls
                )
            }
        }
        .onAppear {
            acquireReceiverIfNeeded()
        }
        .onDisappear {
            releaseReceiverIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    private func acquireReceiverIfNeeded() {
        guard !hasAcquiredReceiver else {
            return
        }
        hasAcquiredReceiver = true
        receiver.acquire()
    }

    private func releaseReceiverIfNeeded() {
        guard hasAcquiredReceiver else {
            return
        }
        hasAcquiredReceiver = false
        receiver.release()
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        #if os(tvOS)
        if newPhase != .active {
            showsConfiguration = true
        }
        #else
        _ = newPhase
        #endif
    }
}

private struct RemoteScoreboardFace: View {
    let state: ScoreboardWebAPIState
    let lastReceivedAt: Date?
    let masterClockOffset: TimeInterval?
    let now: Date

    private var theme: ScoreboardTheme {
        state.display?.theme ?? .classic
    }

    private var backgroundMode: ExternalDisplayBackgroundMode {
        state.display?.backgroundMode ?? .blurred
    }

    private var palette: ThemePalette {
        theme.palette
    }

    var body: some View {
        GeometryReader { proxy in
            let displaySize = proxy.size
            let boardSize = fittedBoardSize(in: displaySize)
            let usesCompactBoard = boardSize.width < 1320 || boardSize.height < 760
            let projection = RemoteScoreboardProjection(
                state: state,
                lastReceivedAt: lastReceivedAt,
                masterClockOffset: masterClockOffset,
                now: now
            )

            ZStack {
                externalBackgroundView()
                    .ignoresSafeArea()

                ScoreboardFaceView(
                    theme: theme,
                    backgroundStyle: boardBackgroundStyle(),
                    sport: state.rules.sport,
                    rules: sportRules(),
                    showsScore: state.rules.supportsScore,
                    homeTeamName: state.teams.home.name,
                    guestTeamName: state.teams.guest.name,
                    homeScore: state.teams.home.score,
                    guestScore: state.teams.guest.score,
                    period: state.game.period,
                    formattedClock: projection.formattedGameClock,
                    showsGameClock: state.clocks.showsGameClock,
                    showsDualClocks: state.rules.usesChessClocks,
                    formattedHomeChessClock: projection.formattedHomeChessClock,
                    formattedGuestChessClock: projection.formattedGuestChessClock,
                    activeChessClockSide: state.clocks.activeChessClockSide,
                    debateHomeSideLabel: state.debate?.homeSideLabel,
                    debateGuestSideLabel: state.debate?.guestSideLabel,
                    debateSegmentTitle: state.debate?.segmentTitle,
                    debateActiveTimer: state.debate?.activeTimer,
                    showsDebatePrepTime: state.debate?.prepTimeEnabled ?? false,
                    formattedDebatePrepHomeClock: projection.formattedDebatePrepHomeClock,
                    formattedDebatePrepGuestClock: projection.formattedDebatePrepGuestClock,
                    formattedShotClock: projection.formattedShotClock,
                    possessionDirection: state.runtime.possessionDirection,
                    areSidesSwapped: state.runtime.areSidesSwapped,
                    isClockRunning: projection.isClockRunning,
                    isPlayerTrackingEnabled: state.players.isPlayerTrackingEnabled,
                    isPlayerOverlayPaused: state.players.isPlayerOverlayPaused,
                    playerFoulHighlightColor: state.players.foulHighlightColor,
                    isDisplayGameClockAlertActive: isDisplayGameClockAlertActive(
                        gameClockSeconds: projection.gameClockSeconds
                    ),
                    isDisplayShotClockAlertActive: isDisplayShotClockAlertActive(
                        shotClockMilliseconds: projection.shotClockMilliseconds
                    ),
                    homeSubstitutionsAllowed: state.teams.home.substitutionsAllowed,
                    guestSubstitutionsAllowed: state.teams.guest.substitutionsAllowed,
                    homeSubstitutionsUsed: state.teams.home.substitutionsUsed,
                    guestSubstitutionsUsed: state.teams.guest.substitutionsUsed,
                    homeTeamFouls: state.teams.home.teamFouls,
                    guestTeamFouls: state.teams.guest.teamFouls,
                    homePenaltyTimers: projection.homePenaltyTimers,
                    guestPenaltyTimers: projection.guestPenaltyTimers,
                    homePlayers: state.players.homeDisplayed,
                    guestPlayers: state.players.guestDisplayed,
                    compact: usesCompactBoard
                )
                .frame(width: boardSize.width, height: boardSize.height)
                .clipped()
                .position(x: displaySize.width / 2, y: displaySize.height / 2)
            }
            .frame(width: displaySize.width, height: displaySize.height)
        }
        .background(externalBackgroundView().ignoresSafeArea())
    }

    private func fittedBoardSize(in availableSize: CGSize) -> CGSize {
        let horizontalInset = max(0, min(availableSize.width * 0.025, 32))
        let verticalInset = max(0, min(availableSize.height * 0.025, 26))
        let usableWidth = max(availableSize.width - (horizontalInset * 2), 0)
        let usableHeight = max(availableSize.height - (verticalInset * 2), 0)
        let preferredWidth = min(usableWidth, usableHeight * ScoreboardFaceView.preferredAspectRatio)
        let preferredHeight = min(usableHeight, preferredWidth / ScoreboardFaceView.preferredAspectRatio)
        return CGSize(width: preferredWidth, height: preferredHeight)
    }

    @ViewBuilder
    private func externalBackgroundView() -> some View {
        switch backgroundMode {
        case .blurred:
            palette.externalDisplayBackground
        case .clear, .clearUnderBoard:
            HStack(spacing: 0) {
                palette.homeAccent
                palette.guestAccent
            }
        case .none:
            Color.clear
        }
    }

    private func boardBackgroundStyle() -> ScoreboardFaceView.BackgroundStyle {
        switch backgroundMode {
        case .blurred:
            return .blurred
        case .clear:
            return .clear
        case .clearUnderBoard:
            return .transparent
        case .none:
            return .clear
        }
    }

    private func sportRules() -> SportRules {
        let fallbackRules = state.rules.sport.rules(customConfig: state.game.customSportConfig)
        return SportRules(
            sport: state.rules.sport,
            title: state.rules.title,
            periodTitle: state.rules.periodTitle,
            periodShortTitle: state.rules.periodShortTitle,
            scoreStepOptions: state.rules.scoreStepOptions,
            defaultClockSeconds: state.clocks.defaultClockSeconds,
            defaultShotClockSeconds: state.clocks.defaultShotClockSeconds,
            defaultRosterSize: state.players.rosterSizePerTeam,
            defaultDisplayLineupSize: state.players.displayLineupSize,
            defaultSubstitutionLimit: max(state.teams.home.substitutionsAllowed, state.teams.guest.substitutionsAllowed),
            mainClockMode: state.rules.mainClockMode,
            supportsScore: state.rules.supportsScore,
            supportsPeriod: state.rules.supportsPeriod,
            supportsShotClock: state.rules.supportsShotClock,
            supportsPossession: state.rules.supportsPossession,
            supportsFouls: state.rules.supportsFouls,
            supportsTeamFouls: state.rules.supportsTeamFouls,
            supportsPlayerTracking: state.rules.supportsPlayerTracking,
            usesCenterPlayerStrip: fallbackRules.usesCenterPlayerStrip,
            supportsCards: state.rules.supportsCards,
            showsSubstitutionTracking: state.rules.supportsSubstitutions,
            supportsHockeyPenalties: state.rules.supportsHockeyPenalties,
            usesChessClocks: state.rules.usesChessClocks
        )
    }

    private func isDisplayGameClockAlertActive(gameClockSeconds: Int) -> Bool {
        guard
            state.clocks.showsGameClock,
            state.clocks.gameClockMode == .countdown,
            state.game.isGameClockRedEnabled == true
        else {
            return false
        }

        let threshold = max(0, state.game.gameClockRedThresholdSeconds ?? 0)
        return gameClockSeconds <= threshold
    }

    private func isDisplayShotClockAlertActive(shotClockMilliseconds: Int) -> Bool {
        guard
            state.rules.supportsShotClock,
            state.game.isShotClockRedEnabled == true
        else {
            return false
        }

        let threshold = max(0, state.game.shotClockRedThresholdSeconds ?? 0) * 1_000
        return shotClockMilliseconds <= threshold
    }
}

private struct RemoteScoreboardProjection {
    let state: ScoreboardWebAPIState
    let elapsedSeconds: TimeInterval

    init(
        state: ScoreboardWebAPIState,
        lastReceivedAt: Date?,
        masterClockOffset: TimeInterval?,
        now: Date
    ) {
        self.state = state
        if
            let generatedAtUnixTime = state.generatedAtUnixTime,
            let masterClockOffset
        {
            let estimatedMasterNow = now.timeIntervalSince1970 + masterClockOffset
            elapsedSeconds = max(0, estimatedMasterNow - generatedAtUnixTime)
        } else {
            elapsedSeconds = max(0, now.timeIntervalSince(lastReceivedAt ?? now))
        }
    }

    var gameClockSeconds: Int {
        guard
            state.clocks.showsGameClock,
            state.runtime.isClockRunning,
            !state.rules.usesChessClocks
        else {
            return state.clocks.gameClockSeconds
        }

        let wholeSeconds = elapsedWholeSeconds
        switch state.clocks.gameClockMode {
        case .countdown:
            return max(0, state.clocks.gameClockSeconds - wholeSeconds)
        case .countUp:
            return min(ScoreboardStore.maxGameClockSeconds, state.clocks.gameClockSeconds + wholeSeconds)
        }
    }

    var formattedGameClock: String {
        ScoreboardStore.formatGameClock(gameClockSeconds)
    }

    var shotClockMilliseconds: Int {
        guard state.runtime.isShotClockRunning, state.rules.supportsShotClock else {
            return state.clocks.shotClockMilliseconds
        }

        return max(0, state.clocks.shotClockMilliseconds - elapsedMilliseconds)
    }

    var formattedShotClock: String {
        ScoreboardStore.formatShotClock(milliseconds: shotClockMilliseconds)
    }

    var homeChessClockSeconds: Int {
        projectedChessClockSeconds(for: .home)
    }

    var formattedHomeChessClock: String {
        ScoreboardStore.formatGameClock(homeChessClockSeconds)
    }

    var guestChessClockSeconds: Int {
        projectedChessClockSeconds(for: .guest)
    }

    var formattedGuestChessClock: String {
        ScoreboardStore.formatGameClock(guestChessClockSeconds)
    }

    var formattedDebatePrepHomeClock: String? {
        guard state.debate != nil else {
            return nil
        }
        return ScoreboardStore.formatGameClock(projectedDebatePrepSeconds(for: .home))
    }

    var formattedDebatePrepGuestClock: String? {
        guard state.debate != nil else {
            return nil
        }
        return ScoreboardStore.formatGameClock(projectedDebatePrepSeconds(for: .guest))
    }

    var homePenaltyTimers: [HockeyPenaltyTimer] {
        projectedPenaltyTimers(state.game.homePenaltyTimers ?? [])
    }

    var guestPenaltyTimers: [HockeyPenaltyTimer] {
        projectedPenaltyTimers(state.game.guestPenaltyTimers ?? [])
    }

    var isClockRunning: Bool {
        guard state.runtime.isClockRunning else {
            return false
        }

        if state.rules.usesChessClocks {
            switch state.clocks.activeChessClockSide {
            case .home:
                return homeChessClockSeconds > 0
            case .guest:
                return guestChessClockSeconds > 0
            case .none:
                return false
            }
        }

        guard state.clocks.showsGameClock else {
            return false
        }

        switch state.clocks.gameClockMode {
        case .countdown:
            return gameClockSeconds > 0
        case .countUp:
            return gameClockSeconds < ScoreboardStore.maxGameClockSeconds
        }
    }

    private var elapsedWholeSeconds: Int {
        Int(elapsedSeconds)
    }

    private var elapsedMilliseconds: Int {
        Int(elapsedSeconds * 1_000)
    }

    private func projectedChessClockSeconds(for side: TeamSide) -> Int {
        let sourceSeconds = side == .home ? state.clocks.homeChessClockSeconds : state.clocks.guestChessClockSeconds
        guard
            state.rules.usesChessClocks,
            state.runtime.isClockRunning,
            state.clocks.activeChessClockSide == side
        else {
            return sourceSeconds
        }

        return max(0, sourceSeconds - elapsedWholeSeconds)
    }

    private func projectedDebatePrepSeconds(for side: TeamSide) -> Int {
        guard let debate = state.debate else {
            return 0
        }

        let sourceSeconds = side == .home ? debate.prepHomeSeconds : debate.prepGuestSeconds
        guard
            debate.prepTimeEnabled,
            state.runtime.isDebatePrepClockRunning,
            debate.activeTimer == (side == .home ? .prepHome : .prepGuest)
        else {
            return sourceSeconds
        }

        return max(0, sourceSeconds - elapsedWholeSeconds)
    }

    private func projectedPenaltyTimers(_ timers: [HockeyPenaltyTimer]) -> [HockeyPenaltyTimer] {
        guard elapsedWholeSeconds > 0 else {
            return timers
        }

        return timers.map { timer in
            guard timer.isRunning else {
                return timer
            }

            var projectedTimer = timer
            projectedTimer.remainingSeconds = max(0, timer.remainingSeconds - elapsedWholeSeconds)
            if projectedTimer.remainingSeconds == 0 {
                projectedTimer.isRunning = false
            }
            return projectedTimer
        }
    }
}

private enum RemoteDisplayConnectionHealth: Equatable {
    private static let poorConnectionInterval: TimeInterval = 3
    private static let disconnectedInterval: TimeInterval = 8

    case live
    case poor(TimeInterval)
    case disconnected(String)

    init(status: ScoreboardRemoteDisplayReceiverStatus, lastHandshakeAt: Date?, now: Date) {
        let age = lastHandshakeAt.map { max(0, now.timeIntervalSince($0)) }

        if status.isLive, let age {
            if age >= Self.disconnectedInterval {
                self = .disconnected(localizedRemoteDisplayFormat("No handshake for %d s", Int(age)))
            } else if age >= Self.poorConnectionInterval {
                self = .poor(age)
            } else {
                self = .live
            }
            return
        }

        switch status {
        case .paired:
            self = .disconnected(localizedRemoteDisplayString("Waiting for scoreboard data"))
        case .waiting:
            self = .disconnected(localizedRemoteDisplayString("Waiting to reconnect"))
        case .disconnected(let message), .failed(let message):
            self = .disconnected(message)
        }
    }

    var title: String {
        switch self {
        case .live:
            return localizedRemoteDisplayString("Live")
        case .poor:
            return localizedRemoteDisplayString("Poor")
        case .disconnected:
            return localizedRemoteDisplayString("Disconnected")
        }
    }

    var detail: String? {
        switch self {
        case .live:
            return nil
        case .poor(let age):
            return localizedRemoteDisplayFormat("Handshake %d s", Int(age))
        case .disconnected(let message):
            return message
        }
    }

    var color: Color {
        switch self {
        case .live:
            return .green
        case .poor:
            return .orange
        case .disconnected:
            return .red
        }
    }
}

private struct RemoteDisplayConfigurationView: View {
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    let hasLiveState: Bool
    let returnToLive: () -> Void
    let exitRemoteDisplayMode: (() -> Void)?
    let openScoreboardWindow: (() -> Void)?
    let showsPairingControls: Bool
    @State private var isForgetPairingConfirmationPresented = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.05),
                    Color(red: 0.08, green: 0.09, blue: 0.14),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let usesStackedLayout = proxy.size.width < 840

                Group {
                    if usesStackedLayout {
                        VStack(spacing: 24) {
                            RemoteDisplayAboutHeader()
                            pairingPanel
                        }
                    } else {
                        HStack(alignment: .center, spacing: 44) {
                            RemoteDisplayAboutHeader()
                                .frame(maxWidth: 720, alignment: .leading)

                            pairingPanel
                                .frame(width: min(max(proxy.size.width * 0.34, 360), 520))
                        }
                    }
                }
                .padding(60)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: receiver.status)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: receiver.pairingCode)
            }
        }
    }

    private var pairingPanel: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text(localizedRemoteDisplayReceiverStatusTitle(receiver.status))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .contentTransition(.opacity)

                Text(showsPairingControls ? localizedRemoteDisplayReceiverStatusDetail(receiver.status) : passiveDisplayDetail)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsPairingControls {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        scanningIndicator
                        Text("Pairing Code")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Text(receiver.pairingCode)
                        .font(.system(size: 82, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 34)
                        .padding(.vertical, 18)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )

                    Text("Enter this code on the operator device. The code refreshes automatically while waiting to pair.")
                        .font(.footnote.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.54))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(savedPairingDetail)
                        .font(.caption.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.62))
                        .contentTransition(.numericText())
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                passiveDisplayPanel
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if showsPairingControls {
                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        Button {
                            receiver.resetPairingCode()
                        } label: {
                            Label("New Code", systemImage: "arrow.clockwise")
                        }

                        if hasLiveState {
                            Button {
                                returnToLive()
                            } label: {
                                Label("Return to Live", systemImage: "play.rectangle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if let openScoreboardWindow {
                            Button {
                                openScoreboardWindow()
                            } label: {
                                Label("Open Scoreboard Window", systemImage: "rectangle.on.rectangle")
                            }
                        }

                        if let exitRemoteDisplayMode {
                            Button {
                                exitRemoteDisplayMode()
                            } label: {
                                Label("Exit Display Mode", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }

                    Button(role: .destructive) {
                        isForgetPairingConfirmationPresented = true
                    } label: {
                        Label("Forget Paired Devices", systemImage: "trash")
                    }
                    .disabled(receiver.trustedHosts.isEmpty)
                    .opacity(receiver.trustedHosts.isEmpty ? 0.48 : 1)
                }
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 30)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .confirmationDialog(
            "Forget Paired Devices?",
            isPresented: $isForgetPairingConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Forget Paired Devices", role: .destructive) {
                receiver.forgetTrustedHosts()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This Remote Display will remove all saved operator devices. Each master will need to pair again with a 4-digit code.")
        }
    }

    private var passiveDisplayDetail: String {
        localizedRemoteDisplayString("This screen mirrors the Remote Display output. Use the main Smart Scoreboard window on this device to pair.")
    }

    private var savedPairingDetail: String {
        let count = receiver.trustedHosts.count
        if count == 0 {
            return localizedRemoteDisplayString("No operator devices saved")
        }
        if count == 1 {
            return localizedRemoteDisplayString("1 operator device saved")
        }
        return localizedRemoteDisplayFormat("%d operator devices saved", count)
    }

    private func localizedRemoteDisplayReceiverStatusTitle(_ status: ScoreboardRemoteDisplayReceiverStatus) -> String {
        switch status {
        case .waiting:
            return localizedRemoteDisplayString("Ready to Pair")
        case .paired:
            return localizedRemoteDisplayString("Live")
        case .disconnected:
            return localizedRemoteDisplayString("Disconnected")
        case .failed:
            return localizedRemoteDisplayString("Connection Failed")
        }
    }

    private func localizedRemoteDisplayReceiverStatusDetail(_ status: ScoreboardRemoteDisplayReceiverStatus) -> String {
        switch status {
        case .waiting:
            return localizedRemoteDisplayString("Open Scoreboard settings on the operator device and pair this display.")
        case .paired(let name):
            return localizedRemoteDisplayFormat("Receiving live scoreboard updates from %@.", name)
        case .disconnected(let message), .failed(let message):
            return message
        }
    }

    private var passiveDisplayPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: "display.and.arrow.down")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))

            Text("Waiting for Remote Scoreboard")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Pairing controls are available on the primary screen.")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(.vertical, 16)
    }

    private var scanningIndicator: some View {
        TimelineView(.periodic(from: Date(), by: 1.0)) { timeline in
            Circle()
                .fill(Color.green.opacity(receiver.status.isLive ? 1 : 0.72))
                .frame(width: 9, height: 9)
                .scaleEffect(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) < 1 ? 1 : 0.72)
                .animation(.easeInOut(duration: 0.8), value: timeline.date)
        }
        .frame(width: 12, height: 12)
    }
}

private struct RemoteDisplayAboutHeader: View {
    private var appDisplayName: String {
        "Smart Scoreboard"
    }

    private var appVersionLine: String {
        localizedRemoteDisplayFormat("Version %@", ScoreboardRemoteDisplayAppVersion.current.displayText)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            Image("ScoreboardIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("Remote Display")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)

                Text(appDisplayName)
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(appVersionLine)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("A live scoreboard app for sports, debate, chess, and custom game displays.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)

                Text("This device is a Remote Display. Open Smart Scoreboard on a tablet or computer, enable Remote Display Pairing, then enter the code below from that operator device.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RemoteDisplayLiveBadge: View {
    let health: RemoteDisplayConnectionHealth
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle()
                    .fill(health.color)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 0) {
                    Text(health.title)
                        .font(.caption2.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if let detail = health.detail {
                        Text(detail)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, health.detail == nil ? 5 : 6)
            .frame(maxWidth: health.detail == nil ? 82 : 190, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(.black.opacity(0.42), in: Capsule())
        .overlay(
            Capsule()
                .stroke(health.color.opacity(0.45), lineWidth: 1)
        )
        .focusable(true)
    }
}
