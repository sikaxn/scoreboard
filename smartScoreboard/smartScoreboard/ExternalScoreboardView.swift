import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ExternalScoreboardView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState

    var body: some View {
        PublicScoreboardDisplayView(
            viewMode: store.publicDisplayViewMode,
            playerViewRosterScope: .fullRoster,
            theme: store.theme,
            backgroundMode: store.externalDisplayBackgroundMode.resolvedForRendering,
            backgroundImage: store.externalDisplayBackgroundImage.map(PublicScoreboardBackgroundImage.init(image:)),
            animatedLogoStyle: store.externalDisplayAnimatedLogoStyle,
            animatedLogoBackgroundColor: store.externalDisplayAnimatedLogoBackgroundColor,
            animatedLogoSpeed: store.externalDisplayAnimatedLogoSpeed,
            animatedLogoSize: store.externalDisplayAnimatedLogoSize,
            animatedLogoOpacity: store.externalDisplayAnimatedLogoOpacity,
            showsDateTime: store.showsExternalDisplayDateTime,
            dateTimeFormat: store.externalDisplayDateTimeFormat,
            showsDateTimeSeconds: store.showsExternalDisplayDateTimeSeconds,
            sport: store.selectedSport,
            rules: store.currentRules,
            showsScore: store.supportsScore,
            homeTeamName: store.homeTeamName,
            guestTeamName: store.guestTeamName,
            eventName: store.eventName,
            homeTeamLogoData: store.showsTeamLogos ? store.homeTeamLogoImage?.data : nil,
            guestTeamLogoData: store.showsTeamLogos ? store.guestTeamLogoImage?.data : nil,
            eventLogoData: store.showsEventLogo ? store.eventLogoImage?.data : nil,
            playerLineupOverflowMode: store.playerLineupOverflowMode,
            playerLineupOverflowLogoOverride: store.playerLineupOverflowLogoOverride,
            playerLineupOverflowNoLogoOverride: store.playerLineupOverflowNoLogoOverride,
            playerLineupFadePageSeconds: store.playerLineupFadePageSeconds,
            playerLineupScrollSpeed: store.playerLineupScrollSpeed,
            playerLineupScrollDirection: store.playerLineupScrollDirection,
            homeScore: store.homeScore,
            guestScore: store.guestScore,
            homeSetsWon: store.homePeriodWins,
            guestSetsWon: store.guestPeriodWins,
            showsPeriodWins: store.supportsPeriodWinTracking,
            usesServeTimer: store.usesServeTimer,
            period: store.period,
            formattedClock: store.formattedClock,
            showsGameClock: store.showsGameClock,
            showsDualClocks: store.usesChessClocks,
            formattedHomeChessClock: store.formattedHomeChessClock,
            formattedGuestChessClock: store.formattedGuestChessClock,
            activeChessClockSide: store.activeChessClockSide,
            debateHomeSideLabel: store.isDebateMode ? store.sideRoleLabel(for: .home) : nil,
            debateGuestSideLabel: store.isDebateMode ? store.sideRoleLabel(for: .guest) : nil,
            debateSegmentTitle: store.isDebateMode ? store.debateSegmentTitle : nil,
            debateSpeakingSide: store.isDebateMode ? store.debateSpeakingSide : nil,
            debateActiveTimer: store.isDebateMode ? store.debateActiveTimer : nil,
            showsDebatePrepTime: store.showsDebatePrepTime,
            formattedDebatePrepHomeClock: store.showsDebatePrepTime ? store.formattedDebatePrepHomeClock : nil,
            formattedDebatePrepGuestClock: store.showsDebatePrepTime ? store.formattedDebatePrepGuestClock : nil,
            formattedShotClock: store.formattedShotClock,
            possessionDirection: store.possessionDirection,
            displayDirection: store.resolvedExternalDisplayDirection,
            isClockRunning: store.isClockRunning,
            isPlayerTrackingEnabled: store.isPlayerTrackingEnabled,
            isPlayerOverlayPaused: store.isPlayerOverlayPaused,
            playerFoulHighlightColor: store.playerFoulHighlightColor,
            isDisplayGameClockAlertActive: store.isDisplayGameClockAlertActive,
            isDisplayShotClockAlertActive: store.isDisplayShotClockAlertActive,
            homeSubstitutionsAllowed: store.homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: store.guestSubstitutionsAllowed,
            homeSubstitutionsUsed: store.homeSubstitutionsUsed,
            guestSubstitutionsUsed: store.guestSubstitutionsUsed,
            homePausesAllowed: store.homePausesAllowed,
            guestPausesAllowed: store.guestPausesAllowed,
            homePausesUsed: store.homePausesUsed,
            guestPausesUsed: store.guestPausesUsed,
            homeTeamFouls: store.homeTeamFouls,
            guestTeamFouls: store.guestTeamFouls,
            homePenaltyTimers: store.homePenaltyTimers,
            guestPenaltyTimers: store.guestPenaltyTimers,
            homeDisplayedPlayers: store.displayedHomePlayers,
            guestDisplayedPlayers: store.displayedGuestPlayers,
            homeRosterPlayers: store.homeRoster.players,
            guestRosterPlayers: store.guestRoster.players
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .background(PublicBoardWindowConfigurator(
            backgroundMode: store.externalDisplayBackgroundMode.resolvedForRendering,
            displayViewMode: store.publicDisplayViewMode,
            fullscreenRequestID: publicBoardState.fullscreenRequestID
        ))
        #endif
    }

    private func fittedBoardSize(in availableSize: CGSize) -> CGSize {
        ScoreboardFaceView.fittedBoardSize(in: availableSize)
    }

    @ViewBuilder
    private func externalBackgroundView(using palette: ThemePalette) -> some View {
        switch store.externalDisplayBackgroundMode.resolvedForRendering {
        case .blurred:
            palette.externalDisplayBackground
        case .clear:
            HStack(spacing: 0) {
                store.resolvedExternalDisplayDirection.leftSide == .home ? palette.homeAccent : palette.guestAccent
                store.resolvedExternalDisplayDirection.rightSide == .home ? palette.homeAccent : palette.guestAccent
            }
        case .clearUnderBoard:
            HStack(spacing: 0) {
                store.resolvedExternalDisplayDirection.leftSide == .home ? palette.homeAccent : palette.guestAccent
                store.resolvedExternalDisplayDirection.rightSide == .home ? palette.homeAccent : palette.guestAccent
            }
        case .smartScoreboard:
            SmartScoreboardBackgroundView()
        case .image:
            if let image = store.externalDisplayBackgroundImage {
                ExternalDisplayBackgroundImageView(image: image)
            } else {
                palette.externalDisplayBackground
            }
        case .animatedLogo:
            ExternalDisplayAnimatedLogoBackgroundView(
                data: store.externalDisplayBackgroundImage?.data,
                style: store.externalDisplayAnimatedLogoStyle,
                backgroundColor: store.externalDisplayAnimatedLogoBackgroundColor,
                speed: store.externalDisplayAnimatedLogoSpeed,
                logoSize: store.externalDisplayAnimatedLogoSize,
                logoOpacity: store.externalDisplayAnimatedLogoOpacity,
                palette: palette
            )
        case .none:
            Color.clear
        }
    }

    private func resolvedBoardBackgroundStyle() -> ScoreboardFaceView.BackgroundStyle {
        switch store.externalDisplayBackgroundMode.resolvedForRendering {
        case .blurred:
            return .blurred
        case .clear:
            return .clear
        case .clearUnderBoard:
            return .transparent
        case .smartScoreboard:
            return .transparent
        case .image:
            return store.externalDisplayBackgroundImage == nil ? .blurred : .transparent
        case .animatedLogo:
            return store.externalDisplayBackgroundImage == nil ? .blurred : .transparent
        case .none:
            return .clear
        }
    }
}

struct PublicScoreboardBackgroundImage: Equatable {
    let data: Data
    let scale: Double
    let offsetX: Double
    let offsetY: Double

    init(image: ExternalDisplayBackgroundImage) {
        data = image.data
        scale = image.scale
        offsetX = image.offsetX
        offsetY = image.offsetY
    }

    init(data: Data, metadata: ScoreboardWebAPIBackgroundImage) {
        self.data = data
        scale = metadata.placement.scale
        offsetX = metadata.placement.offsetX
        offsetY = metadata.placement.offsetY
    }
}

struct PublicScoreboardDisplayView: View {
    let viewMode: ScoreboardDisplayViewMode
    let playerViewRosterScope: PlayerViewRosterScope
    let theme: ScoreboardTheme
    let backgroundMode: ExternalDisplayBackgroundMode
    let backgroundImage: PublicScoreboardBackgroundImage?
    let animatedLogoStyle: ExternalDisplayAnimatedLogoStyle
    let animatedLogoBackgroundColor: ExternalDisplayAnimatedLogoBackgroundColor
    let animatedLogoSpeed: Int
    let animatedLogoSize: Int
    let animatedLogoOpacity: Double
    let showsDateTime: Bool
    let dateTimeFormat: ExternalDisplayDateTimeFormat
    let showsDateTimeSeconds: Bool
    let sport: SportType
    let rules: SportRules
    let showsScore: Bool
    let homeTeamName: String
    let guestTeamName: String
    let eventName: String
    let homeTeamLogoData: Data?
    let guestTeamLogoData: Data?
    let eventLogoData: Data?
    let playerLineupOverflowMode: PlayerLineupOverflowMode
    let playerLineupOverflowLogoOverride: PlayerLineupOverflowMode?
    let playerLineupOverflowNoLogoOverride: PlayerLineupOverflowMode?
    let playerLineupFadePageSeconds: Int
    let playerLineupScrollSpeed: Int
    let playerLineupScrollDirection: PlayerLineupScrollDirection
    let homeScore: Int
    let guestScore: Int
    let homeSetsWon: Int
    let guestSetsWon: Int
    let showsPeriodWins: Bool
    let usesServeTimer: Bool
    let period: Int
    let formattedClock: String
    let showsGameClock: Bool
    let showsDualClocks: Bool
    let formattedHomeChessClock: String
    let formattedGuestChessClock: String
    let activeChessClockSide: TeamSide?
    let debateHomeSideLabel: String?
    let debateGuestSideLabel: String?
    let debateSegmentTitle: String?
    let debateSpeakingSide: TeamSide?
    let debateActiveTimer: DebateActiveTimer?
    let showsDebatePrepTime: Bool
    let formattedDebatePrepHomeClock: String?
    let formattedDebatePrepGuestClock: String?
    let formattedShotClock: String
    let possessionDirection: PossessionDirection
    let displayDirection: ScoreboardDisplayDirection
    let isClockRunning: Bool
    let isPlayerTrackingEnabled: Bool
    let isPlayerOverlayPaused: Bool
    let playerFoulHighlightColor: PlayerFoulHighlightColor
    let isDisplayGameClockAlertActive: Bool
    let isDisplayShotClockAlertActive: Bool
    let homeSubstitutionsAllowed: Int
    let guestSubstitutionsAllowed: Int
    let homeSubstitutionsUsed: Int
    let guestSubstitutionsUsed: Int
    let homePausesAllowed: Int
    let guestPausesAllowed: Int
    let homePausesUsed: Int
    let guestPausesUsed: Int
    let homeTeamFouls: Int
    let guestTeamFouls: Int
    let homePenaltyTimers: [HockeyPenaltyTimer]
    let guestPenaltyTimers: [HockeyPenaltyTimer]
    let homeDisplayedPlayers: [TrackedPlayer]
    let guestDisplayedPlayers: [TrackedPlayer]
    let homeRosterPlayers: [TrackedPlayer]
    let guestRosterPlayers: [TrackedPlayer]
    var compactBoardOverride: Bool? = nil
    var animatesAnimatedLogoBackground = true
    @State private var foregroundViewMode: ScoreboardDisplayViewMode = .scoreboard
    @State private var isForegroundVisible = true
    @State private var deferredForegroundMode: ScoreboardDisplayViewMode?
    @State private var isBlackoutVisible = false
    @State private var hasPreparedInitialMode = false

    private enum PlayerViewRosterScrollAxisDirection {
        case up
        case down
    }

    private var palette: ThemePalette {
        theme.palette
    }

    private func accentColor(for side: TeamSide) -> Color {
        side == .home ? palette.homeAccent : palette.guestAccent
    }

    var body: some View {
        GeometryReader { proxy in
            let displaySize = proxy.size
            let displayedBlackoutVisible = hasPreparedInitialMode ? isBlackoutVisible : viewMode == .blackScreen
            let boardSize = ScoreboardFaceView.fittedBoardSize(in: displaySize)
            let usesCompactBoard = compactBoardOverride ?? (boardSize.width < 1320 || boardSize.height < 760)
            let displayedForegroundMode = hasPreparedInitialMode ? foregroundViewMode : initialForegroundMode
            let displayedForegroundVisible = hasPreparedInitialMode ? isForegroundVisible : viewMode != .backgroundOnly

            ZStack {
                stableBackgroundView()
                    .ignoresSafeArea()

                foregroundContent(
                    mode: displayedForegroundMode,
                    displaySize: displaySize,
                    boardSize: boardSize,
                    usesCompactBoard: usesCompactBoard
                )
                    .id(displayedForegroundMode)
                    .transition(modeTransition)
                    .opacity(displayedForegroundVisible ? 1 : 0)
                    .scaleEffect(displayedForegroundVisible ? 1 : 0.94)

                Color.black
                    .opacity(displayedBlackoutVisible ? 1 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if shouldShowDateTimeOverlay(blackoutVisible: displayedBlackoutVisible) {
                    dateTimeOverlay(displaySize: displaySize)
                        .transition(.opacity)
                }
            }
            .frame(width: displaySize.width, height: displaySize.height)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            prepareInitialModeIfNeeded()
        }
        .onChange(of: viewMode) { oldMode, newMode in
            handleViewModeChange(from: oldMode, to: newMode)
        }
    }

    @ViewBuilder
    private func foregroundContent(
        mode: ScoreboardDisplayViewMode,
        displaySize: CGSize,
        boardSize: CGSize,
        usesCompactBoard: Bool
    ) -> some View {
        switch mode {
        case .blackScreen:
            Color.clear
                .frame(width: displaySize.width, height: displaySize.height)
        case .scoreboard:
            scoreboardFace(usesCompactBoard: usesCompactBoard)
                .frame(width: boardSize.width, height: boardSize.height)
                .clipped()
                .position(x: displaySize.width / 2, y: displaySize.height / 2)
                .frame(width: displaySize.width, height: displaySize.height)
        case .backgroundOnly:
            Color.clear
                .frame(width: displaySize.width, height: displaySize.height)
        case .teamView:
            teamDisplay(displaySize: displaySize, includesPlayers: false)
                .frame(width: displaySize.width, height: displaySize.height)
        case .playerView:
            teamDisplay(displaySize: displaySize, includesPlayers: true)
                .frame(width: displaySize.width, height: displaySize.height)
        case .eventLogo:
            eventLogoDisplay(displaySize: displaySize)
                .frame(width: displaySize.width, height: displaySize.height)
        }
    }

    private var modeTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94)),
            removal: .opacity.combined(with: .scale(scale: 0.94))
        )
    }

    private func prepareInitialModeIfNeeded() {
        guard !hasPreparedInitialMode else {
            return
        }

        hasPreparedInitialMode = true
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            foregroundViewMode = foregroundMode(for: viewMode)
            isForegroundVisible = viewMode != .backgroundOnly
            isBlackoutVisible = viewMode == .blackScreen
            deferredForegroundMode = nil
        }
    }

    private func handleViewModeChange(from oldMode: ScoreboardDisplayViewMode, to newMode: ScoreboardDisplayViewMode) {
        if newMode == .blackScreen {
            deferredForegroundMode = nil
            withAnimation(blackoutAnimation) {
                isBlackoutVisible = true
            }
            return
        }

        if oldMode == .blackScreen || isBlackoutVisible {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                foregroundViewMode = foregroundMode(for: newMode)
                isForegroundVisible = newMode != .backgroundOnly
                deferredForegroundMode = nil
            }

            DispatchQueue.main.async {
                withAnimation(blackoutAnimation) {
                    isBlackoutVisible = false
                }
            }
            return
        }

        if newMode == .backgroundOnly {
            deferredForegroundMode = .backgroundOnly
            withAnimation(boxAnimation) {
                isForegroundVisible = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + boxAnimationDuration) {
                guard deferredForegroundMode == .backgroundOnly else {
                    return
                }

                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    foregroundViewMode = .backgroundOnly
                }
            }
            return
        }

        if oldMode == .backgroundOnly || !isForegroundVisible {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                foregroundViewMode = foregroundMode(for: newMode)
                deferredForegroundMode = nil
            }

            DispatchQueue.main.async {
                withAnimation(boxAnimation) {
                    isForegroundVisible = true
                }
            }
            return
        }

        deferredForegroundMode = nil
        withAnimation(boxAnimation) {
            isForegroundVisible = true
            foregroundViewMode = foregroundMode(for: newMode)
        }
    }

    private func foregroundMode(for mode: ScoreboardDisplayViewMode) -> ScoreboardDisplayViewMode {
        mode == .blackScreen ? foregroundViewMode : mode
    }

    private var initialForegroundMode: ScoreboardDisplayViewMode {
        viewMode == .blackScreen ? .scoreboard : viewMode
    }

    private var boxAnimation: Animation {
        .easeInOut(duration: boxAnimationDuration)
    }

    private var boxAnimationDuration: TimeInterval {
        0.38
    }

    private var blackoutAnimation: Animation {
        .easeInOut(duration: 0.34)
    }

    private func shouldShowDateTimeOverlay(blackoutVisible: Bool) -> Bool {
        showsDateTime && !blackoutVisible
    }

    static func dateTimeOverlayHorizontalInset(in displaySize: CGSize) -> CGFloat {
        max(16, displaySize.width * 0.018)
    }

    static func dateTimeOverlayTopInset(in displaySize: CGSize) -> CGFloat {
        max(14, displaySize.height * 0.014)
    }

    private func dateTimeFontSize(in displaySize: CGSize) -> CGFloat {
        max(18, min(min(displaySize.width, displaySize.height) * 0.030, 36))
    }

    private func dateTimeOverlay(displaySize: CGSize) -> some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            Text(dateTimeFormat.string(from: timeline.date, showingSeconds: showsDateTimeSeconds))
                .font(.system(size: dateTimeFontSize(in: displaySize), weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .foregroundStyle(.white)
                .padding(.horizontal, max(12, displaySize.width * 0.010))
                .padding(.vertical, max(7, displaySize.height * 0.006))
                .background(.black.opacity(0.50), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .frame(maxWidth: max(160, displaySize.width * 0.42), alignment: .leading)
                .padding(.leading, Self.dateTimeOverlayHorizontalInset(in: displaySize))
                .padding(.top, Self.dateTimeOverlayTopInset(in: displaySize))
                .frame(width: displaySize.width, height: displaySize.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }

    private func scoreboardFace(usesCompactBoard: Bool) -> some View {
        ScoreboardFaceView(
            theme: theme,
            backgroundStyle: boardBackgroundStyle(),
            sport: sport,
            rules: rules,
            showsScore: showsScore,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            eventName: eventName,
            homeTeamLogoData: homeTeamLogoData,
            guestTeamLogoData: guestTeamLogoData,
            eventLogoData: eventLogoData,
            playerLineupOverflowMode: playerLineupOverflowMode,
            playerLineupOverflowLogoOverride: playerLineupOverflowLogoOverride,
            playerLineupOverflowNoLogoOverride: playerLineupOverflowNoLogoOverride,
            playerLineupFadePageSeconds: playerLineupFadePageSeconds,
            playerLineupScrollSpeed: playerLineupScrollSpeed,
            playerLineupScrollDirection: playerLineupScrollDirection,
            homeScore: homeScore,
            guestScore: guestScore,
            homeSetsWon: homeSetsWon,
            guestSetsWon: guestSetsWon,
            showsPeriodWins: showsPeriodWins,
            usesServeTimer: usesServeTimer,
            period: period,
            formattedClock: formattedClock,
            showsGameClock: showsGameClock,
            showsDualClocks: showsDualClocks,
            formattedHomeChessClock: formattedHomeChessClock,
            formattedGuestChessClock: formattedGuestChessClock,
            activeChessClockSide: activeChessClockSide,
            debateHomeSideLabel: debateHomeSideLabel,
            debateGuestSideLabel: debateGuestSideLabel,
            debateSegmentTitle: debateSegmentTitle,
            debateSpeakingSide: debateSpeakingSide,
            debateActiveTimer: debateActiveTimer,
            showsDebatePrepTime: showsDebatePrepTime,
            formattedDebatePrepHomeClock: formattedDebatePrepHomeClock,
            formattedDebatePrepGuestClock: formattedDebatePrepGuestClock,
            formattedShotClock: formattedShotClock,
            possessionDirection: possessionDirection,
            displayDirection: displayDirection,
            isClockRunning: isClockRunning,
            isPlayerTrackingEnabled: isPlayerTrackingEnabled,
            isPlayerOverlayPaused: isPlayerOverlayPaused,
            playerFoulHighlightColor: playerFoulHighlightColor,
            isDisplayGameClockAlertActive: isDisplayGameClockAlertActive,
            isDisplayShotClockAlertActive: isDisplayShotClockAlertActive,
            homeSubstitutionsAllowed: homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: guestSubstitutionsAllowed,
            homeSubstitutionsUsed: homeSubstitutionsUsed,
            guestSubstitutionsUsed: guestSubstitutionsUsed,
            homePausesAllowed: homePausesAllowed,
            guestPausesAllowed: guestPausesAllowed,
            homePausesUsed: homePausesUsed,
            guestPausesUsed: guestPausesUsed,
            homeTeamFouls: homeTeamFouls,
            guestTeamFouls: guestTeamFouls,
            homePenaltyTimers: homePenaltyTimers,
            guestPenaltyTimers: guestPenaltyTimers,
            homePlayers: homeDisplayedPlayers,
            guestPlayers: guestDisplayedPlayers,
            compact: usesCompactBoard
        )
    }

    @ViewBuilder
    private func stableBackgroundView() -> some View {
        switch backgroundMode.resolvedForRendering {
        case .blurred:
            palette.externalDisplayBackground
        case .clear, .clearUnderBoard:
            HStack(spacing: 0) {
                accentColor(for: displayDirection.leftSide)
                accentColor(for: displayDirection.rightSide)
            }
        case .smartScoreboard:
            SmartScoreboardBackgroundView()
        case .image:
            if let backgroundImage {
                ExternalDisplayBackgroundImageView(
                    data: backgroundImage.data,
                    scale: backgroundImage.scale,
                    offsetX: backgroundImage.offsetX,
                    offsetY: backgroundImage.offsetY
                )
            } else {
                palette.externalDisplayBackground
            }
        case .animatedLogo:
            ExternalDisplayAnimatedLogoBackgroundView(
                data: backgroundImage?.data,
                style: animatedLogoStyle,
                backgroundColor: animatedLogoBackgroundColor,
                speed: animatedLogoSpeed,
                logoSize: animatedLogoSize,
                logoOpacity: animatedLogoOpacity,
                palette: palette,
                animates: animatesAnimatedLogoBackground
            )
        case .none:
            Color.clear
        }
    }

    private func boardBackgroundStyle() -> ScoreboardFaceView.BackgroundStyle {
        switch backgroundMode.resolvedForRendering {
        case .blurred:
            return .blurred
        case .clear:
            return .clear
        case .clearUnderBoard:
            return .transparent
        case .smartScoreboard:
            return .transparent
        case .image:
            return backgroundImage == nil ? .blurred : .transparent
        case .animatedLogo:
            return backgroundImage == nil ? .blurred : .transparent
        case .none:
            return .clear
        }
    }

    @ViewBuilder
    private func teamDisplay(displaySize: CGSize, includesPlayers: Bool) -> some View {
        let leftSide = displayDirection.leftSide
        let rightSide = displayDirection.rightSide
        let isVertical = displaySize.width < displaySize.height * 1.05
        let spacing = max(18, min(displaySize.width, displaySize.height) * 0.035)
        let horizontalPadding = max(28, min(displaySize.width * 0.055, 92))
        let verticalPadding = max(24, min(displaySize.height * 0.075, 78))

        Group {
            if isVertical {
                VStack(spacing: spacing) {
                    teamPanel(data: teamDisplayData(for: leftSide, includesPlayers: includesPlayers), displaySize: displaySize, includesPlayers: includesPlayers)
                    teamPanel(data: teamDisplayData(for: rightSide, includesPlayers: includesPlayers), displaySize: displaySize, includesPlayers: includesPlayers)
                }
            } else {
                HStack(spacing: spacing) {
                    teamPanel(data: teamDisplayData(for: leftSide, includesPlayers: includesPlayers), displaySize: displaySize, includesPlayers: includesPlayers)
                    teamPanel(data: teamDisplayData(for: rightSide, includesPlayers: includesPlayers), displaySize: displaySize, includesPlayers: includesPlayers)
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(width: displaySize.width, height: displaySize.height)
    }

    private func teamPanel(data: PublicScoreboardTeamDisplayData, displaySize: CGSize, includesPlayers: Bool) -> some View {
        let base = min(displaySize.width, displaySize.height)
        let logoSide = includesPlayers ? max(74, min(base * 0.18, 150)) : max(110, min(base * 0.26, 230))
        let titleSize = includesPlayers ? max(38, min(base * 0.082, 88)) : max(54, min(base * 0.12, 128))
        let roleSize = max(15, min(base * 0.032, 28))
        let isVertical = displaySize.width < displaySize.height * 1.05
        let rowViewportHeight = displaySize.height * (isVertical ? 0.16 : 0.48)

        return VStack(spacing: includesPlayers ? 20 : 26) {
            VStack(spacing: includesPlayers ? 14 : 22) {
                if let logoData = data.logoData {
                    TeamLogoImageView(data: logoData, cornerRadius: 14)
                        .frame(width: logoSide, height: logoSide)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }

                Text(data.role)
                    .font(.system(size: roleSize, weight: .black, design: .rounded))
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(panelSecondaryTextColor)

                Text(resolvedTitle(data.name, placeholder: data.placeholder))
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.35)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(panelPrimaryTextColor)

                Capsule()
                    .fill(data.accent)
                    .frame(width: max(110, min(base * 0.28, 250)), height: includesPlayers ? 7 : 10)
            }

            if includesPlayers {
                rosterList(
                    data.players,
                    accent: data.accent,
                    hasLogo: data.logoData != nil,
                    base: base,
                    viewportHeight: rowViewportHeight
                )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(includesPlayers ? 24 : 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(panelBackgroundColor, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(panelBorderColor)
        )
        .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.34) : .clear, radius: 20, y: 8)
    }

    private func rosterList(
        _ players: [TrackedPlayer],
        accent: Color,
        hasLogo: Bool,
        base: CGFloat,
        viewportHeight: CGFloat
    ) -> some View {
        let overflowMode = resolvedPlayerViewOverflowMode(hasLogo: hasLogo)
        let rowHeight = playerViewRosterRowHeight(base: base)
        let rowSpacing = playerViewRosterRowSpacing
        let unscaledContentHeight = playerViewRosterRowsHeight(playerCount: players.count, rowHeight: rowHeight, rowSpacing: rowSpacing, scale: 1)
        let fitScale = overflowMode == .fit ? max(0.58, min(1, viewportHeight / max(unscaledContentHeight, 1))) : 1
        let scaledRowHeight = rowHeight * fitScale
        let scaledRowSpacing = rowSpacing * fitScale
        let rowsContentHeight = playerViewRosterRowsHeight(playerCount: players.count, rowHeight: rowHeight, rowSpacing: rowSpacing, scale: fitScale)
        let shouldClipRows = rowsContentHeight > viewportHeight + 1
        let shouldScroll = overflowMode == .scroll && shouldClipRows
        let usesPagedRows = (overflowMode == .fade || overflowMode == .fit) && shouldClipRows
        let pageSize = usesPagedRows
            ? playerViewRosterPageSize(rowViewportHeight: viewportHeight, rowHeight: scaledRowHeight, rowSpacing: scaledRowSpacing)
            : max(players.count, 1)
        let pageCount = usesPagedRows ? max(1, Int(ceil(Double(players.count) / Double(max(pageSize, 1))))) : 1
        let timelineInterval = shouldScroll ? 1.0 / 30.0 : (usesPagedRows && pageCount > 1 ? 0.5 : 1.0)

        return TimelineView(.animation(minimumInterval: timelineInterval)) { timeline in
            playerViewRosterTimelineContent(
                players: players,
                accent: accent,
                base: base,
                rowHeight: rowHeight,
                rowSpacing: rowSpacing,
                scaledRowSpacing: scaledRowSpacing,
                fitScale: fitScale,
                viewportHeight: viewportHeight,
                shouldClipRows: shouldClipRows,
                shouldScroll: shouldScroll,
                usesPagedRows: usesPagedRows,
                pageSize: pageSize,
                pageCount: pageCount,
                date: timeline.date
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func playerViewRosterTimelineContent(
        players: [TrackedPlayer],
        accent: Color,
        base: CGFloat,
        rowHeight: CGFloat,
        rowSpacing: CGFloat,
        scaledRowSpacing: CGFloat,
        fitScale: CGFloat,
        viewportHeight: CGFloat,
        shouldClipRows: Bool,
        shouldScroll: Bool,
        usesPagedRows: Bool,
        pageSize: Int,
        pageCount: Int,
        date: Date
    ) -> some View {
        let pageIndex = usesPagedRows && pageCount > 1 ? playerViewRosterPageIndex(pageCount: pageCount, date: date) : 0
        let visiblePlayers: [TrackedPlayer]
        if usesPagedRows {
            let start = min(players.count, max(0, pageIndex) * max(pageSize, 1))
            let end = min(players.count, start + max(pageSize, 1))
            visiblePlayers = Array(players[start..<end])
        } else {
            visiblePlayers = players
        }
        let visibleContentHeight = playerViewRosterRowsHeight(
            playerCount: visiblePlayers.count,
            rowHeight: rowHeight,
            rowSpacing: rowSpacing,
            scale: fitScale
        )

        return playerViewRosterViewport(
            height: viewportHeight,
            contentHeight: visibleContentHeight,
            shouldScroll: shouldScroll,
            shouldFade: shouldClipRows,
            date: date
        ) {
            VStack(spacing: scaledRowSpacing) {
                ForEach(visiblePlayers) { player in
                    playerViewRosterRow(player, accent: accent, base: base, scale: fitScale)
                }
            }
            .id(pageIndex)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: pageIndex)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: players)
    }

    private func playerViewRosterRow(
        _ player: TrackedPlayer,
        accent: Color,
        base: CGFloat,
        scale: CGFloat
    ) -> some View {
        HStack(spacing: 12 * scale) {
            Text(player.number.isEmpty ? "-" : "#\(player.number)")
                .font(.system(size: playerViewRosterNumberFontSize(base: base) * scale, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(player.isInActiveLineup ? accent : panelSecondaryTextColor)
                .frame(width: 72 * scale, alignment: .leading)

            Text(playerDisplayName(player))
                .font(.system(size: playerViewRosterNameFontSize(base: base) * scale, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(player.isInActiveLineup ? panelPrimaryTextColor : panelSecondaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !player.isInActiveLineup {
                Text("BENCH")
                    .font(.system(size: 12 * scale, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(panelSecondaryTextColor)
            }
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 10 * scale)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
    }

    private func playerViewRosterViewport<Content: View>(
        height: CGFloat,
        contentHeight: CGFloat,
        shouldScroll: Bool,
        shouldFade: Bool,
        date: Date,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let offset = shouldScroll && contentHeight > height + 1 ? playerViewRosterScrollOffset(contentHeight: contentHeight, viewportHeight: height, date: date) : 0
        return playerViewRosterScrollableContent(
            duplicatesContent: shouldScroll && playerViewRosterUsesContinuousScroll,
            content: content
        )
            .offset(y: offset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: height, alignment: .top)
            .clipped()
            .mask(
                Group {
                    if shouldFade || shouldScroll {
                        playerViewRosterFadeMask()
                    } else {
                        Rectangle()
                    }
                }
            )
    }

    @ViewBuilder
    private func playerViewRosterScrollableContent<Content: View>(
        duplicatesContent: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if duplicatesContent {
            VStack(spacing: 0) {
                content()
                content()
            }
        } else {
            content()
        }
    }

    private func playerViewRosterFadeMask() -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.92),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var playerViewRosterUsesContinuousScroll: Bool {
        switch playerLineupScrollDirection {
        case .continuousUp, .continuousDown:
            return true
        case .throughUp, .throughDown, .bounce:
            return false
        }
    }

    private func playerViewRosterScrollOffset(contentHeight: CGFloat, viewportHeight: CGFloat, date: Date) -> CGFloat {
        switch playerLineupScrollDirection {
        case .continuousUp:
            return playerViewRosterContinuousScrollOffset(contentHeight: contentHeight, date: date, direction: .up)
        case .continuousDown:
            return playerViewRosterContinuousScrollOffset(contentHeight: contentHeight, date: date, direction: .down)
        case .throughUp:
            return playerViewRosterThroughScrollOffset(contentHeight: contentHeight, viewportHeight: viewportHeight, date: date, direction: .up)
        case .throughDown:
            return playerViewRosterThroughScrollOffset(contentHeight: contentHeight, viewportHeight: viewportHeight, date: date, direction: .down)
        case .bounce:
            return playerViewRosterBounceScrollOffset(distance: max(0, contentHeight - viewportHeight), date: date)
        }
    }

    private func playerViewRosterContinuousScrollOffset(contentHeight: CGFloat, date: Date, direction: PlayerViewRosterScrollAxisDirection) -> CGFloat {
        let speed = CGFloat(max(1, playerLineupScrollSpeed))
        let cycleDistance = max(contentHeight, 1)
        let traveled = CGFloat(date.timeIntervalSinceReferenceDate).truncatingRemainder(dividingBy: cycleDistance / speed) * speed
        switch direction {
        case .up:
            return -traveled
        case .down:
            return -cycleDistance + traveled
        }
    }

    private func playerViewRosterThroughScrollOffset(contentHeight: CGFloat, viewportHeight: CGFloat, date: Date, direction: PlayerViewRosterScrollAxisDirection) -> CGFloat {
        let speed = CGFloat(max(1, playerLineupScrollSpeed))
        let cycleDistance = max(contentHeight + viewportHeight, 1)
        let traveled = CGFloat(date.timeIntervalSinceReferenceDate).truncatingRemainder(dividingBy: cycleDistance / speed) * speed
        switch direction {
        case .up:
            return viewportHeight - traveled
        case .down:
            return -contentHeight + traveled
        }
    }

    private func playerViewRosterBounceScrollOffset(distance: CGFloat, date: Date) -> CGFloat {
        let speed = CGFloat(max(1, playerLineupScrollSpeed))
        let pause: TimeInterval = 1.4
        let travel = TimeInterval(max(distance / speed, 0.1))
        let cycle = (travel * 2) + (pause * 2)
        guard cycle > 0 else {
            return 0
        }

        let time = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        if time < pause {
            return 0
        }
        if time < pause + travel {
            return -distance * CGFloat((time - pause) / travel)
        }
        if time < pause + travel + pause {
            return -distance
        }
        return -distance + (distance * CGFloat((time - pause - travel - pause) / travel))
    }

    private func playerViewRosterPageIndex(pageCount: Int, date: Date) -> Int {
        guard pageCount > 1 else {
            return 0
        }
        let pageSeconds = TimeInterval(max(1, playerLineupFadePageSeconds))
        return Int(date.timeIntervalSinceReferenceDate / pageSeconds) % pageCount
    }

    private func playerViewRosterPageSize(rowViewportHeight: CGFloat, rowHeight: CGFloat, rowSpacing: CGFloat) -> Int {
        let rowHeight = max(1, rowHeight)
        let rowSpacing = max(0, rowSpacing)
        guard rowViewportHeight > rowHeight else {
            return 1
        }
        return max(1, Int(floor((rowViewportHeight + rowSpacing) / (rowHeight + rowSpacing))))
    }

    private func playerViewRosterRowsHeight(
        playerCount: Int,
        rowHeight: CGFloat,
        rowSpacing: CGFloat,
        scale: CGFloat
    ) -> CGFloat {
        let boundedCount = max(0, playerCount)
        guard boundedCount > 0 else {
            return 0
        }
        return ((rowHeight * CGFloat(boundedCount)) + (rowSpacing * CGFloat(max(0, boundedCount - 1)))) * scale
    }

    private var playerViewRosterRowSpacing: CGFloat {
        8
    }

    private func playerViewRosterRowHeight(base: CGFloat) -> CGFloat {
        max(playerViewRosterNumberFontSize(base: base), playerViewRosterNameFontSize(base: base)) * 1.95
    }

    private func playerViewRosterNumberFontSize(base: CGFloat) -> CGFloat {
        max(18, min(base * 0.04, 24))
    }

    private func playerViewRosterNameFontSize(base: CGFloat) -> CGFloat {
        max(20, min(base * 0.044, 28))
    }

    private func resolvedPlayerViewOverflowMode(hasLogo: Bool) -> PlayerLineupOverflowMode {
        if hasLogo, let playerLineupOverflowLogoOverride {
            return playerLineupOverflowLogoOverride
        }
        if !hasLogo, let playerLineupOverflowNoLogoOverride {
            return playerLineupOverflowNoLogoOverride
        }
        return playerLineupOverflowMode
    }

    private func eventLogoDisplay(displaySize: CGSize) -> some View {
        let base = min(displaySize.width, displaySize.height)
        let panelWidth = min(displaySize.width * 0.88, max(640, displaySize.width * 0.72))
        let panelHeight = min(displaySize.height * 0.88, max(480, displaySize.height * 0.78))
        let logoSide = max(220, min(min(panelHeight * 0.62, panelWidth * 0.52), 680))
        let titleSize = max(64, min(base * 0.15, 170))

        return VStack(spacing: 32) {
            if let eventLogoData {
                TeamLogoImageView(data: eventLogoData, cornerRadius: 30)
                    .frame(width: logoSide, height: logoSide)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            Text(resolvedTitle(eventName, placeholder: "Event"))
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.32)
                .multilineTextAlignment(.center)
                .foregroundStyle(panelPrimaryTextColor)
        }
        .padding(48)
        .frame(width: panelWidth, height: panelHeight)
        .background(panelBackgroundColor, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(panelBorderColor)
        )
        .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.34) : .clear, radius: 20, y: 8)
        .frame(width: displaySize.width, height: displaySize.height)
    }

    private func teamDisplayData(for side: TeamSide, includesPlayers: Bool) -> PublicScoreboardTeamDisplayData {
        PublicScoreboardTeamDisplayData(
            side: side,
            role: sideRoleLabel(for: side).uppercased(),
            placeholder: side.title,
            name: side == .home ? homeTeamName : guestTeamName,
            logoData: side == .home ? homeTeamLogoData : guestTeamLogoData,
            accent: side == .home ? palette.homeAccent : palette.guestAccent,
            players: includesPlayers ? playerViewPlayers(for: side) : []
        )
    }

    private func playerViewPlayers(for side: TeamSide) -> [TrackedPlayer] {
        switch side {
        case .home:
            return homeRosterPlayers
        case .guest:
            return guestRosterPlayers
        }
    }

    private func playerDisplayName(_ player: TrackedPlayer) -> String {
        let name = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
        return NSLocalizedString("Player", comment: "")
    }

    private func sideRoleLabel(for side: TeamSide) -> String {
        guard sport == .debate else {
            return side.title
        }

        switch side {
        case .home:
            return resolvedTitle(debateHomeSideLabel ?? "", placeholder: "Side A")
        case .guest:
            return resolvedTitle(debateGuestSideLabel ?? "", placeholder: "Side B")
        }
    }

    private func resolvedTitle(_ value: String, placeholder: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString(placeholder, comment: "") : trimmed
    }

    private var usesTransparentBoardSurfaces: Bool {
        switch backgroundMode.resolvedForRendering {
        case .clearUnderBoard, .smartScoreboard, .none:
            return true
        case .image:
            return backgroundImage != nil
        case .animatedLogo:
            return backgroundImage != nil
        case .blurred, .clear:
            return false
        }
    }

    private var panelBackgroundColor: Color {
        usesTransparentBoardSurfaces ? .black.opacity(0.78) : palette.boardPanelBackground
    }

    private var panelBorderColor: Color {
        usesTransparentBoardSurfaces ? .white.opacity(0.16) : palette.boardPanelBorder
    }

    private var panelPrimaryTextColor: Color {
        usesTransparentBoardSurfaces ? .white : palette.boardPrimaryText
    }

    private var panelSecondaryTextColor: Color {
        usesTransparentBoardSurfaces ? .white.opacity(0.72) : palette.boardSecondaryText
    }
}

private struct PublicScoreboardTeamDisplayData {
    let side: TeamSide
    let role: String
    let placeholder: String
    let name: String
    let logoData: Data?
    let accent: Color
    let players: [TrackedPlayer]
}

#if os(macOS)
private struct PublicBoardWindowConfigurator: NSViewRepresentable {
    let backgroundMode: ExternalDisplayBackgroundMode
    let displayViewMode: ScoreboardDisplayViewMode
    let fullscreenRequestID: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.configureWindowIfNeeded(
                for: view,
                backgroundMode: backgroundMode,
                displayViewMode: displayViewMode,
                fullscreenRequestID: fullscreenRequestID
            )
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configureWindowIfNeeded(
                for: nsView,
                backgroundMode: backgroundMode,
                displayViewMode: displayViewMode,
                fullscreenRequestID: fullscreenRequestID
            )
        }
    }

    final class Coordinator {
        private var configuredWindowNumbers = Set<Int>()
        private var placedWindowNumbers = Set<Int>()
        private var handledFullscreenRequestIDs = [Int: UUID]()

        func configureWindowIfNeeded(
            for view: NSView,
            backgroundMode: ExternalDisplayBackgroundMode,
            displayViewMode: ScoreboardDisplayViewMode,
            fullscreenRequestID: UUID
        ) {
            guard let window = view.window else {
                return
            }

            if configuredWindowNumbers.insert(window.windowNumber).inserted {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = false
                window.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
            }

            let usesClearWindow = backgroundMode == .none && displayViewMode != .blackScreen
            window.isOpaque = !usesClearWindow
            window.backgroundColor = usesClearWindow ? .clear : .black

            if placedWindowNumbers.insert(window.windowNumber).inserted {
                placeWindowOnSecondaryDisplayIfAvailable(window)
            }

            requestFullscreenIfNeeded(window, fullscreenRequestID: fullscreenRequestID)
        }

        private func placeWindowOnSecondaryDisplayIfAvailable(_ window: NSWindow) {
            let screens = NSScreen.screens
            guard screens.count > 1 else {
                return
            }

            let targetScreen = Array(screens.dropFirst()).first ?? screens[1]
            let visibleFrame = targetScreen.visibleFrame
            let currentSize = window.frame.size
            let fittedSize = CGSize(
                width: min(currentSize.width, visibleFrame.width),
                height: min(currentSize.height, visibleFrame.height)
            )
            let origin = CGPoint(
                x: visibleFrame.midX - (fittedSize.width / 2),
                y: visibleFrame.midY - (fittedSize.height / 2)
            )

            window.setFrame(CGRect(origin: origin, size: fittedSize), display: true)
        }

        private func requestFullscreenIfNeeded(_ window: NSWindow, fullscreenRequestID: UUID) {
            guard !window.styleMask.contains(.fullScreen) else {
                handledFullscreenRequestIDs[window.windowNumber] = fullscreenRequestID
                return
            }

            guard handledFullscreenRequestIDs[window.windowNumber] != fullscreenRequestID else {
                return
            }

            handledFullscreenRequestIDs[window.windowNumber] = fullscreenRequestID
            DispatchQueue.main.async {
                guard !window.styleMask.contains(.fullScreen) else {
                    return
                }

                window.toggleFullScreen(nil)
            }
        }
    }
}
#endif
