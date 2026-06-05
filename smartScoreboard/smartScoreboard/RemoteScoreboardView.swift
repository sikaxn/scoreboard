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
    @State private var sleepPolicyViewID = UUID()

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
            updatePairingScreenVisibility()
            updateSleepPolicy()
        }
        .onDisappear {
            receiver.setPairingScreenVisible(false)
            clearSleepPolicy()
            releaseReceiverIfNeeded()
        }
        .onChange(of: showsConfiguration) { _, _ in
            updatePairingScreenVisibility()
            updateSleepPolicy()
        }
        .onChange(of: receiver.state != nil) { _, _ in
            handleReceiverPresentationStateChange()
            updatePairingScreenVisibility()
            updateSleepPolicy()
        }
        .onChange(of: receiver.status) { _, _ in
            handleReceiverPresentationStateChange()
            updatePairingScreenVisibility()
            updateSleepPolicy()
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

    private func updatePairingScreenVisibility() {
        receiver.setPairingScreenVisible(showsPairingControls && (receiver.state == nil || showsConfiguration))
    }

    private func handleReceiverPresentationStateChange() {
        guard receiver.status.isLive, receiver.state != nil else {
            return
        }
        showsConfiguration = false
    }

    private func updateSleepPolicy() {
        AppSleepPrevention.setReason(.receiverRemoteDisplayConnected(sleepPolicyViewID), active: receiver.status.isLive)
        AppSleepPrevention.setReason(.remoteScoreboardVisible(sleepPolicyViewID), active: receiver.state != nil && !showsConfiguration)
    }

    private func clearSleepPolicy() {
        AppSleepPrevention.setReason(.receiverRemoteDisplayConnected(sleepPolicyViewID), active: false)
        AppSleepPrevention.setReason(.remoteScoreboardVisible(sleepPolicyViewID), active: false)
    }
}

private struct RemoteScoreboardFace: View {
    let state: ScoreboardWebAPIState
    let lastReceivedAt: Date?
    let masterClockOffset: TimeInterval?
    let now: Date
    @State private var cachedBackgroundImageID: String?
    @State private var backgroundImageData: Data?
    @State private var cachedHomeLogoID: String?
    @State private var cachedGuestLogoID: String?
    @State private var homeLogoData: Data?
    @State private var guestLogoData: Data?

    private var theme: ScoreboardTheme {
        state.display?.theme ?? .classic
    }

    private var backgroundMode: ExternalDisplayBackgroundMode {
        state.display?.backgroundMode ?? .blurred
    }

    private var backgroundImage: ScoreboardWebAPIBackgroundImage? {
        guard backgroundMode == .image else {
            return nil
        }
        return state.display?.backgroundImage
    }

    private var backgroundImageFetchSignature: String {
        guard let backgroundImage else {
            return "none"
        }
        return ([backgroundImage.id] + backgroundImage.downloadURLs).joined(separator: "|")
    }

    private var teamLogoFetchSignature: String {
        [
            teamLogoFetchSignature(for: state.teams.home.logo),
            teamLogoFetchSignature(for: state.teams.guest.logo)
        ].joined(separator: "||")
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
                    homeTeamLogoData: homeLogoData,
                    guestTeamLogoData: guestLogoData,
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
        .task(id: backgroundImageFetchSignature) {
            await updateRemoteBackgroundImageCache()
        }
        .task(id: teamLogoFetchSignature) {
            await updateRemoteTeamLogoCache()
        }
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
        case .image:
            if let backgroundImage, backgroundImageData != nil {
                ExternalDisplayBackgroundImageView(image: backgroundImage, data: backgroundImageData)
            } else {
                palette.externalDisplayBackground
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
        case .image:
            return .transparent
        case .none:
            return .clear
        }
    }

    @MainActor
    private func updateRemoteBackgroundImageCache() async {
        guard let backgroundImage else {
            cachedBackgroundImageID = nil
            backgroundImageData = nil
            return
        }

        guard cachedBackgroundImageID != backgroundImage.id || backgroundImageData == nil else {
            return
        }

        for urlString in backgroundImage.downloadURLs {
            guard let url = URL(string: urlString) else {
                continue
            }

            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                let (data, response) = try await URLSession.shared.data(for: request)
                guard
                    let httpResponse = response as? HTTPURLResponse,
                    (200..<300).contains(httpResponse.statusCode),
                    !data.isEmpty
                else {
                    continue
                }

                cachedBackgroundImageID = backgroundImage.id
                backgroundImageData = data
                return
            } catch {
                continue
            }
        }

        cachedBackgroundImageID = nil
        backgroundImageData = nil
    }

    @MainActor
    private func updateRemoteTeamLogoCache() async {
        if let logo = state.teams.home.logo {
            if cachedHomeLogoID != logo.id || homeLogoData == nil {
                homeLogoData = await fetchRemoteTeamLogoData(logo)
                cachedHomeLogoID = homeLogoData == nil ? nil : logo.id
            }
        } else {
            cachedHomeLogoID = nil
            homeLogoData = nil
        }

        if let logo = state.teams.guest.logo {
            if cachedGuestLogoID != logo.id || guestLogoData == nil {
                guestLogoData = await fetchRemoteTeamLogoData(logo)
                cachedGuestLogoID = guestLogoData == nil ? nil : logo.id
            }
        } else {
            cachedGuestLogoID = nil
            guestLogoData = nil
        }
    }

    private func fetchRemoteTeamLogoData(_ logo: ScoreboardWebAPITeamLogo) async -> Data? {
        for urlString in logo.downloadURLs {
            guard let url = URL(string: urlString) else {
                continue
            }

            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                let (data, response) = try await URLSession.shared.data(for: request)
                guard
                    let httpResponse = response as? HTTPURLResponse,
                    (200..<300).contains(httpResponse.statusCode),
                    !data.isEmpty
                else {
                    continue
                }
                return data
            } catch {
                continue
            }
        }

        return nil
    }

    private func teamLogoFetchSignature(for logo: ScoreboardWebAPITeamLogo?) -> String {
        guard let logo else {
            return "none"
        }
        return ([logo.id] + logo.downloadURLs).joined(separator: "|")
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

private enum RemoteDisplayControlID: Hashable {
    case returnToLive
    case newCode
    case disconnect
    case openScoreboard
    case exitDisplayMode
    case about
    case forgetPairedDevices
}

private struct RemoteDisplayConfigurationView: View {
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    let hasLiveState: Bool
    let returnToLive: () -> Void
    let exitRemoteDisplayMode: (() -> Void)?
    let openScoreboardWindow: (() -> Void)?
    let showsPairingControls: Bool
    @State private var isForgetPairingConfirmationPresented = false
    #if os(tvOS)
    @State private var isAboutPresented = false
    @FocusState private var focusedControl: RemoteDisplayControlID?
    #endif

    var body: some View {
        #if os(tvOS)
        if isAboutPresented {
            RemoteDisplayAppleTVAboutView(
                close: {
                    isAboutPresented = false
                    updateFocusedControl(force: true)
                },
                factoryDefault: {
                    receiver.forgetTrustedHosts()
                    isAboutPresented = false
                    updateFocusedControl(force: true)
                }
            )
        } else {
            configurationBody
        }
        #else
        configurationBody
        #endif
    }

    private var configurationBody: some View {
        ZStack {
            RemoteDisplayConnectionBackground(status: receiver.status)

            GeometryReader { proxy in
                let usesStackedLayout = proxy.size.width < stackedLayoutBreakpoint

                Group {
                    if usesStackedLayout {
                        VStack(spacing: 24) {
                            RemoteDisplayAboutHeader()
                            pairingPanel
                        }
                    } else {
                        HStack(alignment: .center, spacing: horizontalSpacing) {
                            RemoteDisplayAboutHeader()
                                .frame(maxWidth: aboutHeaderMaxWidth, alignment: .leading)

                            pairingPanel
                                .frame(width: pairingPanelWidth(in: proxy.size.width))
                        }
                    }
                }
                .padding(configurationPadding)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: receiver.status)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: receiver.pairingCode)
            }
        }
        #if os(tvOS)
        .onAppear {
            updateFocusedControl(force: true)
        }
        .onChange(of: hasLiveState) { _, _ in
            updateFocusedControl()
        }
        .onChange(of: receiver.status) { _, _ in
            updateFocusedControl()
        }
        .onChange(of: receiver.canDisconnectFromOperator) { _, _ in
            updateFocusedControl()
        }
        .onChange(of: receiver.trustedHosts.count) { _, _ in
            updateFocusedControl()
        }
        .onExitCommand {
            if hasLiveState {
                returnToLive()
            }
        }
        #endif
    }

    private var stackedLayoutBreakpoint: CGFloat {
        #if os(tvOS)
        980
        #else
        840
        #endif
    }

    private var configurationPadding: CGFloat {
        #if os(tvOS)
        48
        #else
        60
        #endif
    }

    private var horizontalSpacing: CGFloat {
        #if os(tvOS)
        56
        #else
        44
        #endif
    }

    private var aboutHeaderMaxWidth: CGFloat {
        #if os(tvOS)
        860
        #else
        720
        #endif
    }

    private func pairingPanelWidth(in availableWidth: CGFloat) -> CGFloat {
        #if os(tvOS)
        min(max(availableWidth * 0.36, 430), 620)
        #else
        min(max(availableWidth * 0.34, 360), 520)
        #endif
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

                    Text("On the operator device, go to Settings > Integration > Remote Display and enter this code. The code refreshes automatically while waiting to pair.")
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
                actionControls
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
            Text("This Remote Display will remove all saved operator devices. Each operator device will need to pair again with a 4-digit code.")
        }
    }

    private var actionButtonColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: actionButtonMinimumWidth),
                spacing: actionButtonSpacing
            )
        ]
    }

    private var actionButtonMinimumWidth: CGFloat {
        #if os(tvOS)
        220
        #else
        210
        #endif
    }

    private var actionButtonSpacing: CGFloat {
        #if os(tvOS)
        14
        #else
        12
        #endif
    }

    private var forgetButtonMaxWidth: CGFloat {
        #if os(tvOS)
        440
        #else
        360
        #endif
    }

    private var actionControls: some View {
        VStack(spacing: actionButtonSpacing) {
            #if os(tvOS)
            VStack(spacing: actionButtonSpacing) {
                orderedActionButtons
            }

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 4)

            forgetPairedDevicesButton
            #else
            LazyVGrid(
                columns: actionButtonColumns,
                spacing: actionButtonSpacing
            ) {
                orderedActionButtons
            }

            forgetPairedDevicesButton
                .frame(maxWidth: forgetButtonMaxWidth)
            #endif
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var orderedActionButtons: some View {
        if hasLiveState {
            remoteDisplayActionButton(
                .returnToLive,
                title: "Return to Live",
                systemImage: "play.rectangle.fill",
                tone: .primary
            ) {
                returnToLive()
            }
        }

        remoteDisplayActionButton(
            .newCode,
            title: "New Code",
            systemImage: "arrow.clockwise",
            tone: .neutral
        ) {
            receiver.resetPairingCode()
        }

        if receiver.canDisconnectFromOperator {
            remoteDisplayActionButton(
                .disconnect,
                title: "Disconnect",
                systemImage: "xmark.circle",
                tone: .destructive
            ) {
                receiver.disconnectFromOperator()
            }
        }

        if let openScoreboardWindow {
            remoteDisplayActionButton(
                .openScoreboard,
                title: "Open Scoreboard",
                systemImage: "rectangle.on.rectangle",
                tone: .neutral
            ) {
                openScoreboardWindow()
            }
        }

        if let exitRemoteDisplayMode {
            remoteDisplayActionButton(
                .exitDisplayMode,
                title: "Exit Display Mode",
                systemImage: "rectangle.portrait.and.arrow.right",
                tone: .neutral
            ) {
                exitRemoteDisplayMode()
            }
        }

        #if os(tvOS)
        remoteDisplayActionButton(
            .about,
            title: "About",
            systemImage: "info.circle",
            tone: .neutral
        ) {
            isAboutPresented = true
        }
        #endif
    }

    private var forgetPairedDevicesButton: some View {
        remoteDisplayActionButton(
            .forgetPairedDevices,
            title: "Forget Paired Devices",
            systemImage: "trash",
            tone: .destructive,
            isDisabled: receiver.trustedHosts.isEmpty
        ) {
            isForgetPairingConfirmationPresented = true
        }
    }

    @ViewBuilder
    private func remoteDisplayActionButton(
        _ id: RemoteDisplayControlID,
        title: String,
        systemImage: String,
        tone: RemoteDisplayControlButtonTone,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        #if os(tvOS)
        RemoteDisplayControlButton(
            title: title,
            systemImage: systemImage,
            tone: tone,
            isDisabled: isDisabled,
            isFocused: focusedControl == id,
            action: action
        )
        .focused($focusedControl, equals: id)
        #else
        RemoteDisplayControlButton(
            title: title,
            systemImage: systemImage,
            tone: tone,
            isDisabled: isDisabled,
            action: action
        )
        #endif
    }

    #if os(tvOS)
    private var availableFocusedControls: [RemoteDisplayControlID] {
        var controls: [RemoteDisplayControlID] = []

        if hasLiveState {
            controls.append(.returnToLive)
        }
        controls.append(.newCode)
        if receiver.canDisconnectFromOperator {
            controls.append(.disconnect)
        }
        if openScoreboardWindow != nil {
            controls.append(.openScoreboard)
        }
        if exitRemoteDisplayMode != nil {
            controls.append(.exitDisplayMode)
        }
        controls.append(.about)
        if !receiver.trustedHosts.isEmpty {
            controls.append(.forgetPairedDevices)
        }

        return controls
    }

    private var preferredFocusedControl: RemoteDisplayControlID? {
        if hasLiveState {
            return .returnToLive
        }
        return .newCode
    }

    private func updateFocusedControl(force: Bool = false) {
        let controls = availableFocusedControls
        guard !controls.isEmpty else {
            focusedControl = nil
            return
        }

        if force || focusedControl.map({ !controls.contains($0) }) != false {
            focusedControl = preferredFocusedControl.flatMap { controls.contains($0) ? $0 : nil } ?? controls[0]
        }
    }
    #endif

    private var passiveDisplayDetail: String {
        localizedRemoteDisplayString("This screen mirrors the Remote Display output. On the main Smart Scoreboard window, go to Settings > Integration > Remote Display to pair.")
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
            return localizedRemoteDisplayString("On the operator device, open Settings > Integration > Remote Display, then enter this display's pairing code.")
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

            Text("Use the primary screen: Settings > Integration > Remote Display.")
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

                Text("This device is a Remote Display. On the tablet or computer running Smart Scoreboard, go to Settings > Integration > Remote Display, then enter the code below.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)

                #if os(tvOS)
                Text("Apple TV can only act as a Remote Display. It requires the full Smart Scoreboard app on macOS or iPad to pair, control, and run the scoreboard.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
            .frame(maxWidth: 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
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
                HStack(alignment: .top, spacing: 58) {
                    aboutSidebar
                        .frame(width: min(max(proxy.size.width * 0.28, 380), 500), alignment: .topLeading)

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
            Text("This will delete saved operator devices, disconnect the current Remote Display session, and return this Apple TV display app to first-launch pairing defaults.")
        }
    }

    private var aboutSidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image("ScoreboardIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 146, height: 146)
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
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(appVersionLine)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))

                Text("Apple TV can only act as a Remote Display. Use the full Smart Scoreboard app on macOS or iPad to pair this Apple TV, control the scoreboard, and send live updates.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

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

            Spacer(minLength: 0)
        }
    }

    private var aboutApplicationSection: some View {
        aboutSection("Application") {
            aboutValueRow(title: "Name", value: "Smart Scoreboard")
            aboutDivider
            aboutValueRow(title: "Version", value: ScoreboardRemoteDisplayAppVersion.current.displayText)
            aboutDivider
            aboutParagraph("A live scoreboard app for sports, debate, chess, and custom game displays.")
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
