import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

private func localizedRemoteDisplayString(_ key: String) -> String {
    ScoreboardLocalization.string(key)
}

private func localizedRemoteDisplayFormat(_ key: String, _ arguments: Any...) -> String {
    scoreboardLocalizedFormat(localizedRemoteDisplayString(key), locale: Locale.current, arguments: arguments)
}

private enum RemoteDisplayReceiverNetworkModeStore {
    private static let key = "smartScoreboard.remoteDisplayReceiverNetworkMode"

    static var mode: ScoreboardRemoteDisplayNetworkMode {
        get {
            ScoreboardPreferences.current.string(forKey: key)
                .flatMap(ScoreboardRemoteDisplayNetworkMode.init(rawValue:)) ?? .nearbyAndLocalNetwork
        }
        set {
            ScoreboardPreferences.current.set(newValue.rawValue, forKey: key)
        }
    }
}

struct RemoteScoreboardView: View {
    @ObservedObject private var router = ScoreboardRemoteConnectionRouter.shared
    private var fixedReceiver: ScoreboardRemoteDisplayReceiver?
    private var exitRemoteDisplayMode: (() -> Void)?
    private var openScoreboardWindow: (() -> Void)?
    private var networkMode: ScoreboardRemoteDisplayNetworkMode
    private var setNetworkMode: ((ScoreboardRemoteDisplayNetworkMode) -> Void)?
    private var showsPairingControls: Bool
    private var usesExternalDisplayDirection: Bool
    @State private var activeMode: ScoreboardRemoteDisplayNetworkMode
    @State private var acquired = false
    @State private var showsConfiguration = false

    init(receiver: ScoreboardRemoteDisplayReceiver? = nil,
         exitRemoteDisplayMode: (() -> Void)? = nil, openScoreboardWindow: (() -> Void)? = nil,
         networkMode: ScoreboardRemoteDisplayNetworkMode? = nil,
         setNetworkMode: ((ScoreboardRemoteDisplayNetworkMode) -> Void)? = nil,
         showsPairingControls: Bool = true, usesExternalDisplayDirection: Bool = false) {
        let mode = networkMode ?? RemoteDisplayReceiverNetworkModeStore.mode
        self.fixedReceiver = receiver; self.exitRemoteDisplayMode = exitRemoteDisplayMode
        self.openScoreboardWindow = openScoreboardWindow; self.networkMode = mode
        self.setNetworkMode = setNetworkMode; self.showsPairingControls = showsPairingControls
        self.usesExternalDisplayDirection = usesExternalDisplayDirection
        _activeMode = State(initialValue: mode)
    }
    var body: some View {
        RemoteScoreboardContentView(receiver: fixedReceiver ?? router.receiver,
            exitRemoteDisplayMode: exitRemoteDisplayMode, openScoreboardWindow: openScoreboardWindow,
            networkMode: activeMode, setNetworkMode: { mode in
                activeMode = mode; setNetworkMode?(mode)
                if fixedReceiver == nil { router.updateMode(mode) }
            }, showsPairingControls: showsPairingControls, usesExternalDisplayDirection: usesExternalDisplayDirection,
            showsConfiguration: $showsConfiguration)
        .id(fixedReceiver == nil ? router.route : .local)
        .onAppear {
            if fixedReceiver == nil && !acquired { acquired = true; router.acquire(mode: activeMode) }
        }
        .onDisappear {
            if acquired { acquired = false; router.release() }
        }
        .onChange(of: networkMode) { _, mode in
            activeMode = mode
            if fixedReceiver == nil { router.updateMode(mode) }
        }
    }
}

private struct RemoteScoreboardContentView: View {
    var exitRemoteDisplayMode: (() -> Void)?
    var openScoreboardWindow: (() -> Void)?
    var networkMode: ScoreboardRemoteDisplayNetworkMode
    var setNetworkMode: ((ScoreboardRemoteDisplayNetworkMode) -> Void)?
    var showsPairingControls: Bool
    var usesExternalDisplayDirection: Bool

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var receiver: ScoreboardRemoteDisplayReceiver
    @ObservedObject private var sessionStore = ScoreboardStore.shared
    @Binding private var showsConfiguration: Bool
    @State private var showsHostedExitConfirmation = false
    @State private var hasAcquiredReceiver = false
    @State private var activeNetworkMode: ScoreboardRemoteDisplayNetworkMode
    @State private var sleepPolicyViewID = UUID()

    init(
        receiver: ScoreboardRemoteDisplayReceiver,
        exitRemoteDisplayMode: (() -> Void)? = nil,
        openScoreboardWindow: (() -> Void)? = nil,
        networkMode: ScoreboardRemoteDisplayNetworkMode? = nil,
        setNetworkMode: ((ScoreboardRemoteDisplayNetworkMode) -> Void)? = nil,
        showsPairingControls: Bool = true,
        usesExternalDisplayDirection: Bool = false,
        showsConfiguration: Binding<Bool>
    ) {
        let resolvedNetworkMode = networkMode ?? RemoteDisplayReceiverNetworkModeStore.mode
        self.receiver = receiver
        self.exitRemoteDisplayMode = exitRemoteDisplayMode
        self.openScoreboardWindow = openScoreboardWindow
        self.networkMode = resolvedNetworkMode
        self.setNetworkMode = setNetworkMode
        self.showsPairingControls = showsPairingControls
        self.usesExternalDisplayDirection = usesExternalDisplayDirection
        _showsConfiguration = showsConfiguration
        _activeNetworkMode = State(initialValue: resolvedNetworkMode)
    }

    var body: some View {
        ZStack {
            if receiver.isControlBoardDevice, !sessionStore.joinedAsDisplay, showsPairingControls, !showsConfiguration {
                if ScoreboardKioskPresentation.usesSharedLayout {
                    ScoreboardKioskControlView(receiver: receiver, showConnection: presentConnectionControls)
                } else {
                    #if !os(tvOS)
                    ScoreboardRemoteControlView(receiver: receiver, showConnection: presentConnectionControls)
                    #endif
                }
            } else { receiverContent }
        }
        #if os(tvOS)
        .onExitCommand(perform: tvExitHandler)
        #endif
        .onAppear {
            acquireReceiverIfNeeded()
            updatePairingScreenVisibility()
            updateSleepPolicy()
        }
        .onDisappear {
            receiver.setPairingScreenVisible(false)
            clearSleepPolicy()
            releaseReceiverIfNeeded()
        }
        .onChange(of: showsConfiguration) { _, _ in updatePairingScreenVisibility(); updateSleepPolicy() }
        .onChange(of: receiver.state != nil) { _, _ in
            updatePairingScreenVisibility(); updateSleepPolicy()
        }
        .onChange(of: receiver.status) { _, _ in
            updatePairingScreenVisibility(); updateSleepPolicy()
        }
        .onChange(of: networkMode) { _, newMode in applyNetworkMode(newMode, propagatesToParent: false) }
        .onChange(of: scenePhase) { _, newPhase in handleScenePhaseChange(newPhase) }
        .confirmationDialog("Leave Hosted Match?", isPresented: $showsHostedExitConfirmation,
                            titleVisibility: .visible) {
            Button("Delete Local Match and Leave", role: .destructive) {
                if sessionStore.deleteHostedMatchAndExitRemoteMode() { exitRemoteDisplayMode?() }
            }
            Button("Continue Hosting", role: .cancel) {}
        } message: {
            Text("The owner has not confirmed a saved copy, or a timer is still running. Reconnect to the owner and wait for Safe to Disconnect before leaving without deleting this match.")
        }
    }

    private var receiverContent: some View {
        ZStack {
            if let state = receiver.state, !showsConfiguration {
                TimelineView(.periodic(from: Date(), by: 0.25)) { timeline in
                    let health = RemoteDisplayConnectionHealth(
                        status: receiver.status,
                        lastHandshakeAt: receiver.lastHeartbeatAt ?? receiver.lastReceivedAt,
                        now: timeline.date,
                        isHosting: receiver.isHostingSession
                    )

                    GeometryReader { proxy in
                        let displaySize = proxy.size

                        if shouldShowIPhonePortraitLandscapePrompt(in: displaySize) {
                            RemoteDisplayIPhoneLandscapePrompt(
                                health: health,
                                returnToConfiguration: presentConnectionControls,
                                exitRemoteDisplayMode: exitRemoteDisplayMode
                            )
                        } else {
                            ZStack(alignment: .topTrailing) {
                                RemoteScoreboardFace(
                                    state: state,
                                    backgroundImageData: receiver.imageData(for: state.display?.backgroundImage?.id),
                                    homeLogoData: receiver.imageData(for: state.teams.home.logo?.id),
                                    guestLogoData: receiver.imageData(for: state.teams.guest.logo?.id),
                                    eventLogoData: receiver.imageData(for: state.display?.eventLogo?.id),
                                    lastReceivedAt: receiver.lastReceivedAt,
                                    masterClockOffset: receiver.masterClockOffset,
                                    now: timeline.date,
                                    usesExternalDisplayDirection: usesExternalDisplayDirection
                                )
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .focusable(true)
                                .onTapGesture {
                                    if showsPairingControls { presentConnectionControls() }
                                }

                                RemoteDisplayLiveBadge(health: health,
                                    safeToDisconnect: state.control?.session?.safeToDisconnect) {
                                    if showsPairingControls { presentConnectionControls() }
                                }
                                .padding(.top, PublicScoreboardDisplayView.dateTimeOverlayTopInset(in: displaySize))
                                .padding(.trailing, PublicScoreboardDisplayView.dateTimeOverlayHorizontalInset(in: displaySize))
                            }
                        }
                    }
                }
            } else {
                RemoteDisplayConfigurationView(
                    receiver: receiver.isCloudReceiver ? ScoreboardRemoteDisplayReceiver.shared : receiver,
                    hasLiveState: receiver.state != nil,
                    returnToLive: { showsConfiguration = false },
                    exitRemoteDisplayMode: exitRemoteDisplayMode.map { exit in
                        { requestExitRemoteMode(exit) }
                    },
                    openScoreboardWindow: openScoreboardWindow,
                    networkMode: activeNetworkMode,
                    setNetworkMode: { applyNetworkMode($0, propagatesToParent: true) },
                    showsPairingControls: showsPairingControls
                )
            }
        }
    }

    #if os(tvOS)
    private var tvExitHandler: (() -> Void)? {
        guard showsPairingControls, !showsConfiguration, receiver.state != nil else { return nil }
        return { presentConnectionControls() }
    }
    #endif

    private func presentConnectionControls() {
        #if !os(tvOS)
        if sessionStore.isJoinedMatchActive && ScoreboardDeviceMode.current == .app { ScoreboardAppNavigation.shared.open(.sharing); return }
        #endif
        showsConfiguration = true
    }

    private func acquireReceiverIfNeeded() {
        guard !hasAcquiredReceiver else {
            return
        }
        hasAcquiredReceiver = true
        receiver.acquire(networkMode: activeNetworkMode)
    }

    private func applyNetworkMode(
        _ mode: ScoreboardRemoteDisplayNetworkMode,
        propagatesToParent: Bool
    ) {
        guard activeNetworkMode != mode else {
            return
        }
        activeNetworkMode = mode
        RemoteDisplayReceiverNetworkModeStore.mode = mode
        receiver.updateNetworkMode(mode)
        if propagatesToParent {
            setNetworkMode?(mode)
        }
    }

    private func releaseReceiverIfNeeded() {
        guard hasAcquiredReceiver else {
            return
        }
        hasAcquiredReceiver = false
        receiver.release()
    }

    private func requestExitRemoteMode(_ exit: () -> Void) {
        guard sessionStore.hasHostedMatchToDiscard else { exit(); return }
        guard sessionStore.isDelegatedSessionHost && sessionStore.isSessionSafeToDisconnect else {
            showsHostedExitConfirmation = true
            return
        }
        exit()
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .background { sessionStore.prepareHostedMatchForBackground() }
        #if os(tvOS)
        if newPhase == .active {
            (receiver.isCloudReceiver ? ScoreboardRemoteDisplayReceiver.shared : receiver).resumeAfterAppLifecycle(networkMode: activeNetworkMode)
            updatePairingScreenVisibility()
            updateSleepPolicy()
        } else {
            showsConfiguration = true
        }
        #elseif os(iOS)
        if newPhase == .active {
            (receiver.isCloudReceiver ? ScoreboardRemoteDisplayReceiver.shared : receiver).resumeAfterAppLifecycle(networkMode: activeNetworkMode)
        }
        #else
        _ = newPhase
        #endif
    }

    private func updatePairingScreenVisibility() {
        let pairingReceiver = receiver.isCloudReceiver ? ScoreboardRemoteDisplayReceiver.shared : receiver
        pairingReceiver.setPairingScreenVisible(showsPairingControls && (receiver.state == nil || showsConfiguration))
    }

    private func updateSleepPolicy() {
        AppSleepPrevention.setReason(.receiverRemoteDisplayConnected(sleepPolicyViewID), active: receiver.status.isLive)
        AppSleepPrevention.setReason(.remoteScoreboardVisible(sleepPolicyViewID), active: receiver.state != nil && !showsConfiguration)
    }

    private func clearSleepPolicy() {
        AppSleepPrevention.setReason(.receiverRemoteDisplayConnected(sleepPolicyViewID), active: false)
        AppSleepPrevention.setReason(.remoteScoreboardVisible(sleepPolicyViewID), active: false)
    }

    private func shouldShowIPhonePortraitLandscapePrompt(in size: CGSize) -> Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
            && showsPairingControls
            && !usesExternalDisplayDirection
            && size.height > size.width
        #else
        false
        #endif
    }
}

private struct RemoteScoreboardFace: View {
    let state: ScoreboardWebAPIState
    let backgroundImageData: Data?
    let homeLogoData: Data?
    let guestLogoData: Data?
    let eventLogoData: Data?
    let lastReceivedAt: Date?
    let masterClockOffset: TimeInterval?
    let now: Date
    let usesExternalDisplayDirection: Bool

    private var theme: ScoreboardTheme {
        state.display?.theme ?? .classic
    }

    private var backgroundMode: ExternalDisplayBackgroundMode {
        (state.display?.backgroundMode ?? .blurred).resolvedForRendering
    }

    private var displaysTeamLogos: Bool {
        state.display?.showsTeamLogos ?? true
    }

    private var displaysEventLogo: Bool {
        state.display?.resolvedShowsEventLogo ?? true
    }

    private var palette: ThemePalette {
        theme.palette
    }

    private var displayDirection: ScoreboardDisplayDirection {
        let legacyDirection = ScoreboardDisplayDirection(areSidesSwapped: state.runtime.areSidesSwapped)
        if usesExternalDisplayDirection {
            return state.display?.resolvedRemoteExternalDirection
                ?? state.display?.direction
                ?? legacyDirection
        }
        return state.display?.direction ?? legacyDirection
    }

    var body: some View {
        let projection = RemoteScoreboardProjection(
            state: state,
            lastReceivedAt: lastReceivedAt,
            masterClockOffset: masterClockOffset,
            now: now
        )

        PublicScoreboardDisplayView(
            viewMode: state.display?.resolvedViewMode ?? .scoreboard,
            playerViewRosterScope: .fullRoster,
            theme: theme,
            backgroundMode: backgroundMode,
            backgroundImage: publicBackgroundImage,
            animatedLogoStyle: state.display?.resolvedAnimatedLogoStyle ?? .horizontalMarquee,
            animatedLogoBackgroundColor: state.display?.resolvedAnimatedLogoBackgroundColor ?? .themeBackground,
            animatedLogoSpeed: state.display?.resolvedAnimatedLogoSpeed ?? ScoreboardStore.defaultAnimatedLogoSpeed,
            animatedLogoSize: state.display?.resolvedAnimatedLogoSize ?? ScoreboardStore.defaultAnimatedLogoSize,
            animatedLogoOpacity: state.display?.resolvedAnimatedLogoOpacity ?? ScoreboardStore.defaultAnimatedLogoOpacity,
            showsDateTime: state.display?.resolvedShowsDateTime ?? false,
            dateTimeFormat: state.display?.resolvedDateTimeFormat ?? .time24Hour,
            showsDateTimeSeconds: state.display?.resolvedShowsDateTimeSeconds ?? true,
            sport: state.rules.sport,
            rules: sportRules(),
            showsScore: state.rules.supportsScore,
            homeTeamName: state.teams.home.name,
            guestTeamName: state.teams.guest.name,
            eventName: state.game.eventName,
            homeTeamLogoData: displaysTeamLogos ? homeLogoData : nil,
            guestTeamLogoData: displaysTeamLogos ? guestLogoData : nil,
            eventLogoData: displaysEventLogo ? eventLogoData : nil,
            playerLineupOverflowMode: state.players.lineupOverflowMode ?? .scroll,
            playerLineupOverflowLogoOverride: state.players.lineupOverflowLogoOverride,
            playerLineupOverflowNoLogoOverride: state.players.lineupOverflowNoLogoOverride,
            playerLineupFadePageSeconds: state.players.lineupFadePageSeconds ?? ScoreboardStore.defaultPlayerLineupFadePageSeconds,
            playerLineupScrollSpeed: state.players.lineupScrollSpeed ?? ScoreboardStore.defaultPlayerLineupScrollSpeed,
            playerLineupScrollDirection: state.players.lineupScrollMode ?? state.players.lineupScrollDirection?.resolvedScrollMode ?? .continuousUp,
            homeScore: state.teams.home.score,
            guestScore: state.teams.guest.score,
            homeSetsWon: state.teams.home.periodsWon ?? state.teams.home.setsWon ?? 0,
            guestSetsWon: state.teams.guest.periodsWon ?? state.teams.guest.setsWon ?? 0,
            showsPeriodWins: state.rules.supportsPeriodWins ?? (state.rules.sport == .volleyball),
            usesServeTimer: state.rules.usesServeTimer ?? (state.rules.sport == .volleyball),
            period: state.game.period,
            formattedClock: projection.formattedGameClock,
            showsGameClock: state.clocks.showsGameClock,
            activeInjuryTimeMinutes: state.clocks.activeInjuryTimeMinutes ?? 0,
            showsDualClocks: state.rules.usesChessClocks,
            formattedHomeChessClock: projection.formattedHomeChessClock,
            formattedGuestChessClock: projection.formattedGuestChessClock,
            activeChessClockSide: state.clocks.activeChessClockSide,
            debateHomeSideLabel: state.debate?.homeSideLabel,
            debateGuestSideLabel: state.debate?.guestSideLabel,
            debateSegmentTitle: state.debate?.segmentTitle,
            debateSpeakingSide: state.debate?.speakingSide,
            debateActiveTimer: state.debate?.activeTimer,
            showsDebatePrepTime: state.debate?.prepTimeEnabled ?? false,
            formattedDebatePrepHomeClock: projection.formattedDebatePrepHomeClock,
            formattedDebatePrepGuestClock: projection.formattedDebatePrepGuestClock,
            formattedShotClock: projection.formattedShotClock,
            possessionDirection: state.runtime.possessionDirection,
            displayDirection: displayDirection,
            isClockRunning: projection.isClockRunning,
            isPlayerTrackingEnabled: state.players.isPlayerTrackingEnabled,
            isPlayerOverlayPaused: state.players.isPlayerOverlayPaused,
            playerFoulHighlightColor: state.players.foulHighlightColor,
            isDisplayGameClockAlertActive: isDisplayGameClockAlertActive(gameClockSeconds: projection.gameClockSeconds),
            isDisplayShotClockAlertActive: isDisplayShotClockAlertActive(shotClockMilliseconds: projection.shotClockMilliseconds),
            homeSubstitutionsAllowed: state.teams.home.substitutionsAllowed,
            guestSubstitutionsAllowed: state.teams.guest.substitutionsAllowed,
            homeSubstitutionsUsed: state.teams.home.substitutionsUsed,
            guestSubstitutionsUsed: state.teams.guest.substitutionsUsed,
            homePausesAllowed: state.teams.home.pausesAllowed ?? 0,
            guestPausesAllowed: state.teams.guest.pausesAllowed ?? 0,
            homePausesUsed: state.teams.home.pausesUsed ?? 0,
            guestPausesUsed: state.teams.guest.pausesUsed ?? 0,
            homeTeamFouls: state.teams.home.teamFouls,
            guestTeamFouls: state.teams.guest.teamFouls,
            homePenaltyTimers: projection.homePenaltyTimers,
            guestPenaltyTimers: projection.guestPenaltyTimers,
            homeDisplayedPlayers: state.players.homeDisplayed,
            guestDisplayedPlayers: state.players.guestDisplayed,
            homeRosterPlayers: state.players.homeRoster.players,
            guestRosterPlayers: state.players.guestRoster.players,
            pauseTimer: projection.pauseTimer
        )
    }

    private var publicBackgroundImage: PublicScoreboardBackgroundImage? {
        guard let backgroundImageData, let metadata = state.display?.backgroundImage else {
            return nil
        }
        return PublicScoreboardBackgroundImage(data: backgroundImageData, metadata: metadata)
    }

    private func fittedBoardSize(in availableSize: CGSize) -> CGSize {
        ScoreboardFaceView.fittedBoardSize(in: availableSize)
    }

    @ViewBuilder
    private func externalBackgroundView() -> some View {
        switch backgroundMode {
        case .blurred:
            palette.externalDisplayBackground
        case .clear, .clearUnderBoard:
            HStack(spacing: 0) {
                displayDirection.leftSide == .home ? palette.homeAccent : palette.guestAccent
                displayDirection.rightSide == .home ? palette.homeAccent : palette.guestAccent
            }
        case .smartScoreboard:
            SmartScoreboardBackgroundView()
        case .image:
            if let data = backgroundImageData, let metadata = state.display?.backgroundImage {
                ExternalDisplayBackgroundImageView(
                    data: data,
                    scale: metadata.placement.scale,
                    offsetX: metadata.placement.offsetX,
                    offsetY: metadata.placement.offsetY
                )
            } else {
                palette.externalDisplayBackground
            }
        case .animatedLogo:
            ExternalDisplayAnimatedLogoBackgroundView(
                data: backgroundImageData,
                style: state.display?.resolvedAnimatedLogoStyle ?? .horizontalMarquee,
                backgroundColor: state.display?.resolvedAnimatedLogoBackgroundColor ?? .themeBackground,
                speed: state.display?.resolvedAnimatedLogoSpeed ?? ScoreboardStore.defaultAnimatedLogoSpeed,
                logoSize: state.display?.resolvedAnimatedLogoSize ?? ScoreboardStore.defaultAnimatedLogoSize,
                logoOpacity: state.display?.resolvedAnimatedLogoOpacity ?? ScoreboardStore.defaultAnimatedLogoOpacity,
                palette: palette
            )
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
        case .smartScoreboard:
            return .transparent
        case .image:
            return backgroundImageData == nil ? .blurred : .transparent
        case .animatedLogo:
            return backgroundImageData == nil ? .blurred : .transparent
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
            defaultPauseLimit: max(state.teams.home.pausesAllowed ?? 0, state.teams.guest.pausesAllowed ?? 0),
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
            showsPauseTracking: state.rules.supportsPauses ?? false,
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


private enum RemoteDisplayConnectionHealth: Equatable {
    private static let poorConnectionInterval: TimeInterval = 3
    private static let disconnectedInterval: TimeInterval = 8

    case live
    case hosting
    case poor(TimeInterval)
    case disconnected(String)

    init(status: ScoreboardRemoteDisplayReceiverStatus, lastHandshakeAt: Date?, now: Date, isHosting: Bool = false) {
        if isHosting { self = .hosting; return }
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
        case .hosting:
            return localizedRemoteDisplayString("Hosting")
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
        case .live, .hosting:
            return nil
        case .poor(let age):
            return localizedRemoteDisplayFormat("Handshake %d s", Int(age))
        case .disconnected(let message):
            return message
        }
    }

    var color: Color {
        switch self {
        case .live, .hosting:
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
    @ObservedObject private var sessionStore = ScoreboardStore.shared
    let hasLiveState: Bool
    let returnToLive: () -> Void
    let exitRemoteDisplayMode: (() -> Void)?
    let openScoreboardWindow: (() -> Void)?
    let networkMode: ScoreboardRemoteDisplayNetworkMode
    let setNetworkMode: (ScoreboardRemoteDisplayNetworkMode) -> Void
    let showsPairingControls: Bool
    @State private var isAboutPresented = false
    @State private var factoryResetError: String?
    @State private var isDiscardHostedMatchConfirmationPresented = false

    var body: some View {
        Group {
            #if os(tvOS)
            if isAboutPresented {
                RemoteDisplayAppleTVAboutView(
                    close: { isAboutPresented = false },
                    factoryDefault: {
                        do { try sessionStore.resetKioskToFactoryDefaults(); isAboutPresented = false }
                        catch { isAboutPresented = false; factoryResetError = error.localizedDescription }
                    }
                )
            } else { configurationBody }
            #else
            configurationBody
                .sheet(isPresented: $isAboutPresented) {
                    NavigationStack {
                        ScrollView { RemoteDisplayAboutHeader(isCompact: true).padding(28) }
                            .background(Color(red: 0.04, green: 0.05, blue: 0.08))
                            .navigationTitle("About")
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { isAboutPresented = false } } }
                    }
                    .environment(\.colorScheme, .dark)
                    .frame(minWidth: 320, idealWidth: 600, minHeight: 400, idealHeight: 600)
                }
            #endif
        }
        .alert("Unable to Reset", isPresented: Binding(get: { factoryResetError != nil }, set: { if !$0 { factoryResetError = nil } })) {
            Button("OK") { factoryResetError = nil }
        } message: { Text(factoryResetError ?? "") }
        .confirmationDialog("Discard Hosted Match?", isPresented: $isDiscardHostedMatchConfirmationPresented, titleVisibility: .visible) {
            Button("Discard Match and Stop Hosting", role: .destructive) { _ = sessionStore.discardHostedMatchAndReturnToPairing() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the match and log stored only on this device. Any changes the owner has not saved will be lost. This device will return to pairing mode.")
        }
    }
    private var configurationBody: some View {
        ZStack {
            RemoteDisplayConnectionBackground(status: receiver.status)
            if ScoreboardKioskPresentation.usesSharedLayout {
                if showsPairingControls {
                    ScoreboardKioskHomeView(receiver: receiver, hasLiveState: hasLiveState, returnToLive: returnToLive,
                        showAbout: { isAboutPresented = true }, discardHostedMatch: { isDiscardHostedMatchConfirmationPresented = true })
                } else { ScoreboardWaitingDisplayView() }
            } else {
                ScoreboardRemotePairingHomeView(receiver: receiver, hasLiveState: hasLiveState, returnToLive: returnToLive,
                    networkMode: networkMode, setNetworkMode: setNetworkMode, showsPairingControls: showsPairingControls,
                    openScoreboardWindow: openScoreboardWindow, exitRemoteDisplayMode: exitRemoteDisplayMode,
                    showAbout: { isAboutPresented = true }, discardHostedMatch: { isDiscardHostedMatchConfirmationPresented = true })
            }
        }
    }
}

private struct RemoteDisplayConnectionBackground: View {
    let status: ScoreboardRemoteDisplayReceiverStatus

    private var accentColor: Color {
        switch status {
        case .waiting:
            return Color(red: 0.16, green: 0.58, blue: 1.0)
        case .paired:
            return Color(red: 0.18, green: 0.82, blue: 0.42)
        case .disconnected:
            return Color(red: 1.0, green: 0.58, blue: 0.20)
        case .failed:
            return Color(red: 1.0, green: 0.28, blue: 0.34)
        }
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0 / 30.0)) { timeline in
            GeometryReader { proxy in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.62 + (sin(phase * 0.72) * 0.18)

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

                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.16 * pulse),
                            .clear,
                            accentColor.opacity(0.10 * pulse)
                        ],
                        startPoint: animatedStartPoint(phase: phase),
                        endPoint: animatedEndPoint(phase: phase)
                    )
                    .blendMode(.screen)

                    RemoteDisplayConnectionGrid(accentColor: accentColor, phase: phase)
                        .opacity(0.68)

                    ForEach(0..<4, id: \.self) { index in
                        RemoteDisplayConnectionSweep(
                            accentColor: accentColor,
                            phase: phase,
                            index: index,
                            size: proxy.size
                        )
                    }

                    LinearGradient(
                        colors: [
                            .black.opacity(0.12),
                            .clear,
                            .black.opacity(0.42)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func animatedStartPoint(phase: TimeInterval) -> UnitPoint {
        UnitPoint(
            x: 0.18 + (0.08 * sin(phase * 0.10)),
            y: 0.06 + (0.12 * cos(phase * 0.08))
        )
    }

    private func animatedEndPoint(phase: TimeInterval) -> UnitPoint {
        UnitPoint(
            x: 0.86 + (0.08 * cos(phase * 0.09)),
            y: 0.92 + (0.10 * sin(phase * 0.11))
        )
    }
}

private struct RemoteDisplayConnectionGrid: View {
    let accentColor: Color
    let phase: TimeInterval

    var body: some View {
        Canvas { context, size in
            let spacing = max(CGFloat(44), min(size.width, size.height) / 12)
            let offset = CGFloat(phase.truncatingRemainder(dividingBy: 4) / 4) * spacing
            let diagonalShift = size.height * 0.18
            var path = Path()

            var x = -spacing + offset
            while x < size.width + spacing {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + diagonalShift, y: size.height))
                x += spacing
            }

            var y = -spacing + offset
            while y < size.height + spacing {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y - diagonalShift))
                y += spacing
            }

            context.stroke(path, with: .color(accentColor.opacity(0.12)), lineWidth: 1)
        }
    }
}

private struct RemoteDisplayConnectionSweep: View {
    let accentColor: Color
    let phase: TimeInterval
    let index: Int
    let size: CGSize

    var body: some View {
        let largestDimension = max(size.width, size.height)
        let bandWidth = max(CGFloat(180), largestDimension * 0.22)
        let travel = size.width + (bandWidth * 2)
        let duration = Double(7 + index)
        let progress = (phase / duration + Double(index) * 0.27).truncatingRemainder(dividingBy: 1)
        let xPosition = -bandWidth + (CGFloat(progress) * travel)
        let opacity = 0.08 + (0.03 * sin(phase * 0.7 + Double(index)))

        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        accentColor.opacity(opacity),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: bandWidth, height: largestDimension * 1.85)
            .rotationEffect(.degrees(-18))
            .position(x: xPosition, y: size.height / 2)
            .blendMode(.screen)
    }
}

private struct RemoteDisplayIPhoneLandscapePrompt: View {
    let health: RemoteDisplayConnectionHealth
    let returnToConfiguration: () -> Void
    let exitRemoteDisplayMode: (() -> Void)?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.05),
                    Color(red: 0.04, green: 0.09, blue: 0.08),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "iphone.landscape")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    Text("Turn iPhone to Landscape")
                        .font(.title2.weight(.black))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text("Remote Display is live. Rotate iPhone to show the scoreboard on this screen. A connected external display will keep showing the scoreboard.")
                        .font(.callout.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    RemoteDisplayControlButton(
                        title: "Pairing & Controls",
                        systemImage: "number.square",
                        tone: .primary,
                        action: returnToConfiguration
                    )

                    if let exitRemoteDisplayMode {
                        RemoteDisplayControlButton(
                            title: "Exit Display Mode",
                            systemImage: "rectangle.portrait.and.arrow.right",
                            tone: .neutral,
                            action: exitRemoteDisplayMode
                        )
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaPadding(.horizontal, 18)
        .safeAreaPadding(.vertical, 16)
        .overlay(alignment: .topTrailing) {
            RemoteDisplayLiveBadge(health: health, action: returnToConfiguration)
                .padding(.top, 12)
                .padding(.trailing, 16)
        }
    }
}

private enum RemoteDisplayControlButtonTone {
    case neutral
    case primary
    case destructive

    var background: Color {
        switch self {
        case .neutral:
            return .white.opacity(0.18)
        case .primary:
            return Color(red: 0.0, green: 0.44, blue: 0.95)
        case .destructive:
            return Color(red: 1.0, green: 0.24, blue: 0.30)
        }
    }

    var pressedBackground: Color {
        switch self {
        case .neutral:
            return .white.opacity(0.26)
        case .primary:
            return Color(red: 0.0, green: 0.36, blue: 0.78)
        case .destructive:
            return Color(red: 0.86, green: 0.16, blue: 0.22)
        }
    }

    var focusedBackground: Color {
        switch self {
        case .neutral:
            return .white
        case .primary:
            return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .destructive:
            return Color(red: 1.0, green: 0.28, blue: 0.34)
        }
    }

    var foreground: Color {
        switch self {
        case .neutral, .primary, .destructive:
            return .white
        }
    }

    var focusedForeground: Color {
        switch self {
        case .neutral:
            return Color(red: 0.04, green: 0.05, blue: 0.08)
        case .primary, .destructive:
            return .white
        }
    }

    var stroke: Color {
        switch self {
        case .neutral:
            return .white.opacity(0.22)
        case .primary, .destructive:
            return .white.opacity(0.26)
        }
    }

    var focusedStroke: Color {
        switch self {
        case .neutral:
            return .white.opacity(0.95)
        case .primary, .destructive:
            return .white.opacity(0.72)
        }
    }
}

private struct RemoteDisplayControlButton: View {
    let title: String
    let systemImage: String
    let tone: RemoteDisplayControlButtonTone
    var isDisabled = false
    var isFocused = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: iconWidth)

                Text(localizedRemoteDisplayString(title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(localizedRemoteDisplayString(title))
        }
        .buttonStyle(RemoteDisplayControlButtonStyle(tone: tone, isFocused: isFocused))
        .disabled(isDisabled)
    }

    private var iconWidth: CGFloat {
        #if os(tvOS)
        30
        #else
        22
        #endif
    }
}

private struct RemoteDisplayControlButtonStyle: ButtonStyle {
    let tone: RemoteDisplayControlButtonTone
    let isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(configuration: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(
                color: focusShadowColor,
                radius: isEnabled && isFocused ? 18 : 0,
                y: isEnabled && isFocused ? 8 : 0
            )
            .scaleEffect(scale(configuration: configuration))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isFocused)
    }

    private var buttonFont: Font {
        #if os(tvOS)
        .system(size: 25, weight: .bold, design: .rounded)
        #else
        .headline.weight(.bold)
        #endif
    }

    private var minHeight: CGFloat {
        #if os(tvOS)
        76
        #else
        50
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(tvOS)
        22
        #else
        16
        #endif
    }

    private var foregroundColor: Color {
        if isEnabled && isFocused {
            return tone.focusedForeground
        }
        return isEnabled ? tone.foreground : .white.opacity(0.38)
    }

    private var strokeColor: Color {
        if isEnabled && isFocused {
            return tone.focusedStroke
        }
        return isEnabled ? tone.stroke : .white.opacity(0.12)
    }

    private var focusShadowColor: Color {
        guard isEnabled && isFocused else {
            return .clear
        }
        switch tone {
        case .neutral:
            return .white.opacity(0.28)
        case .primary:
            return Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.34)
        case .destructive:
            return Color(red: 1.0, green: 0.28, blue: 0.34).opacity(0.34)
        }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        guard isEnabled else {
            return .white.opacity(0.08)
        }
        if configuration.isPressed {
            return tone.pressedBackground
        }
        return isFocused ? tone.focusedBackground : tone.background
    }

    private func scale(configuration: Configuration) -> CGFloat {
        guard isEnabled else {
            return 1
        }
        if configuration.isPressed {
            return isFocused ? 1.02 : 0.97
        }
        return isFocused ? 1.045 : 1
    }
}

private struct RemoteDisplayAboutHeader: View {
    var isCompact = false

    private var appDisplayName: String {
        "Smart Scoreboard"
    }

    private var remoteModeTitle: String {
        #if os(tvOS)
        localizedRemoteDisplayString("Remote Display & Session Host")
        #else
        localizedRemoteDisplayString("Remote Display & Control")
        #endif
    }

    private var pairingInstructions: String {
        #if os(tvOS)
        localizedRemoteDisplayString("This Apple TV can display and host a session. Enter this pairing code from Settings > Integration > Remote Display & Control on the owner device, then choose Make Session Host there if needed.")
        #else
        localizedRemoteDisplayString("Enter this pairing code from Settings > Integration > Remote Display & Control on the main device. Enable Allow This Device to Control there to use this device as a control board.")
        #endif
    }

    private var appVersionLine: String {
        localizedRemoteDisplayFormat("Version %@", ScoreboardRemoteDisplayAppVersion.current.displayText)
    }

    var body: some View {
        if isCompact {
            compactBody
        } else {
            regularBody
        }
    }

    private var regularBody: some View {
        HStack(alignment: .center, spacing: 22) {
            appIcon(size: 112, cornerRadius: 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(remoteModeTitle)
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

                Text(pairingInstructions)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)

                if shouldShowIPhoneNotice {
                    iPhoneScoreboardFitNotice
                }

                #if os(tvOS)
                Text("Apple TV can display the scoreboard and run game logic as the session host. Use iPhone, iPad, or Mac for the control board, game files, and setup.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
            .frame(maxWidth: 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                appIcon(size: 76, cornerRadius: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(remoteModeTitle)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)

                    Text(appDisplayName)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)

                    Text(appVersionLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(pairingInstructions)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            if shouldShowIPhoneNotice {
                iPhoneScoreboardFitNotice
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func appIcon(size: CGFloat, cornerRadius: CGFloat) -> some View {
        Image("ScoreboardIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }

    private var shouldShowIPhoneNotice: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var iPhoneScoreboardFitNotice: some View {
        Text("Some scoreboard content, including player lists and longer text, may not display fully on the iPhone screen because of the limited space. For the best viewing experience, connect an external display.")
            .font(.callout.weight(.medium))
            .foregroundStyle(.white.opacity(0.68))
            .fixedSize(horizontal: false, vertical: true)
    }
}

#if os(tvOS)
private enum RemoteDisplayAppleTVAboutControlID: Hashable {
    case back
    case factoryDefault
}

private struct RemoteDisplayAppleTVAboutView: View {
    let close: () -> Void
    let factoryDefault: () -> Void

    @State private var isFactoryDefaultConfirmationPresented = false
    @FocusState private var focusedControl: RemoteDisplayAppleTVAboutControlID?

    private var appVersionLine: String {
        localizedRemoteDisplayFormat("Version %@", ScoreboardRemoteDisplayAppVersion.current.displayText)
    }

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
                HStack(alignment: .top, spacing: 48) {
                    aboutSidebar
                        .frame(width: min(max(proxy.size.width * 0.28, 380), 500), alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .topLeading)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            aboutApplicationSection
                            aboutFactoryDefaultSection
                            aboutLicenseSection
                            aboutThirdPartySection
                            aboutTrademarksSection
                            aboutLinksSection
                            aboutBugReportsSection
                            aboutPrivacySection
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 70)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focusSection()
                }
                .padding(.horizontal, 72)
                .padding(.vertical, 62)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .onAppear {
            focusedControl = .back
        }
        .onExitCommand {
            close()
        }
        .alert("Factory Default App", isPresented: $isFactoryDefaultConfirmationPresented) {
            Button("Factory Default", role: .destructive) {
                factoryDefault()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes cloud access, the self-hosted URL, saved pairings, local files and device settings from this Apple TV. It does not delete the host’s scoreboard.")
        }
    }

    private var aboutSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("ScoreboardIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white.opacity(0.58))

                Text("Smart Scoreboard")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(appVersionLine)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))

            }

            Spacer(minLength: 20)

            RemoteDisplayControlButton(
                title: "Back",
                systemImage: "chevron.left",
                tone: .primary,
                isFocused: focusedControl == .back,
                action: close
            )
            .focused($focusedControl, equals: .back)

            RemoteDisplayControlButton(
                title: "Factory Default",
                systemImage: "trash",
                tone: .destructive,
                isFocused: focusedControl == .factoryDefault
            ) {
                isFactoryDefaultConfirmationPresented = true
            }
            .focused($focusedControl, equals: .factoryDefault)

        }
    }

    private var aboutApplicationSection: some View {
        aboutSection("Application") {
            aboutValueRow(title: "Name", value: "Smart Scoreboard")
            aboutDivider
            aboutValueRow(title: "Version", value: ScoreboardRemoteDisplayAppVersion.current.displayText)
            aboutDivider
            aboutParagraph("A live scoreboard app for sports, debate, chess, and custom game displays.")
            aboutDivider
            aboutParagraph("Apple TV can display the scoreboard and host the session, including timers, Web API, and Companion. Pair it from the owner device and choose Make Session Host. The control board, game files, and setup remain on iPhone, iPad, or Mac.")
        }
    }

    private var aboutFactoryDefaultSection: some View {
        aboutSection("Factory Default") {
            aboutParagraph("Deletes local Remote Display pairing data and returns this Apple TV display app to first-launch defaults.")
        }
    }

    private var aboutLicenseSection: some View {
        aboutSection("License") {
            aboutValueRow(title: "License", value: "GNU General Public License v3.0", localizesValue: true)
            aboutDivider
            aboutParagraph("This software is free software released under the GNU General Public License version 3. You may redistribute and modify it under those terms.")
            aboutDivider
            aboutParagraph("Distributed without warranty.", isEmphasized: true)
            aboutDivider
            aboutParagraph("See LICENSE.md in the repository for the full GNU General Public License text.")
        }
    }

    private var aboutThirdPartySection: some View {
        aboutSection("Third-Party Licenses") {
            aboutParagraph("The Web API demo pages use bundled first-party HTML, CSS, and JavaScript only. No third-party web libraries are included for these integrations.")
        }
    }

    private var aboutTrademarksSection: some View {
        aboutSection("Trademarks") {
            aboutParagraph("Bitfocus Companion is a trademark of its respective owner. SmartScoreboard is not affiliated with or endorsed by Bitfocus.")
        }
    }

    private var aboutLinksSection: some View {
        aboutSection("Links") {
            aboutLinkRow(
                title: "Source Code",
                subtitle: "github.com/sikaxn/scoreboard",
                systemImage: "chevron.left.forwardslash.chevron.right",
                urlString: "https://github.com/sikaxn/scoreboard"
            )
            aboutDivider
            aboutLinkRow(
                title: "Privacy Policy",
                subtitle: "studenttechsupport.com/privacy",
                systemImage: "hand.raised",
                urlString: "https://studenttechsupport.com/privacy"
            )
            aboutDivider
            aboutLinkRow(
                title: "Bug Reports",
                subtitle: "Open a GitHub issue",
                systemImage: "exclamationmark.bubble",
                urlString: "https://github.com/sikaxn/scoreboard/issues/new"
            )
        }
    }

    private var aboutBugReportsSection: some View {
        aboutSection("Bug Reports") {
            aboutParagraph("To report a bug, open a GitHub issue in the scoreboard repository and include the sport, device, OS version, and steps to reproduce.")
        }
    }

    private var aboutPrivacySection: some View {
        aboutSection("Privacy") {
            aboutParagraph("This app does not collect any data and does not phone any third-party server.")
        }
    }

    private func aboutSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localizedRemoteDisplayString(title))
                .font(.title3.weight(.black))
                .foregroundStyle(.white.opacity(0.92))
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .focusable()
    }

    private func aboutValueRow(title: String, value: String, localizesValue: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(localizedRemoteDisplayString(title))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.74))

            Spacer(minLength: 0)

            Text(localizesValue ? localizedRemoteDisplayString(value) : value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private func aboutParagraph(_ text: String, isEmphasized: Bool = false) -> some View {
        Text(localizedRemoteDisplayString(text))
            .font(isEmphasized ? .body.weight(.bold) : .body.weight(.medium))
            .foregroundStyle(isEmphasized ? .white.opacity(0.78) : .white.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
    }

    private func aboutLinkRow(
        title: String,
        subtitle: String,
        systemImage: String,
        urlString: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white.opacity(0.84))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(localizedRemoteDisplayString(title))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(localizedRemoteDisplayString(subtitle))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))

                Text(urlString)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.vertical, 12)
    }

    private var aboutDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
    }
}
#endif

private struct RemoteDisplayLiveBadge: View {
    let health: RemoteDisplayConnectionHealth
    var safeToDisconnect: Bool? = nil
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
                    if let safeToDisconnect {
                        Text(safeToDisconnect ? "Safe to Disconnect" : "Match active or sync pending")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(safeToDisconnect ? .green : .white.opacity(0.68))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, health.detail == nil ? 5 : 6)
            .frame(maxWidth: safeToDisconnect == nil && health.detail == nil ? 82 : 190, alignment: .leading)
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
