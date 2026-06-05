import Foundation
import SwiftUI

private func localizedBoardString(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func localizedBoardFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedBoardString(key), locale: Locale.current, arguments: arguments)
}

private func localizedBoardText(_ key: String) -> Text {
    Text(localizedBoardString(key))
}

struct ScoreboardFaceView: View {
    static let preferredAspectRatio: CGFloat = 16.0 / 9.0
    static func fittedBoardSize(
        in availableSize: CGSize,
        horizontalInsetFraction: CGFloat = 0.025,
        maxHorizontalInset: CGFloat = 32,
        verticalInsetFraction: CGFloat = 0.025,
        maxVerticalInset: CGFloat = 26
    ) -> CGSize {
        let horizontalInset = max(0, min(availableSize.width * horizontalInsetFraction, maxHorizontalInset))
        let verticalInset = max(0, min(availableSize.height * verticalInsetFraction, maxVerticalInset))
        let usableWidth = max(availableSize.width - (horizontalInset * 2), 0)
        let usableHeight = max(availableSize.height - (verticalInset * 2), 0)
        guard usableWidth > 0, usableHeight > 0 else {
            return .zero
        }

        let usableAspect = usableWidth / usableHeight
        if usableAspect < 1.55 {
            let preferredHeight = usableWidth / preferredAspectRatio
            let adaptiveHeight = min(usableHeight, usableWidth * 1.05)
            return CGSize(width: usableWidth, height: max(preferredHeight, adaptiveHeight))
        }

        let preferredWidth = min(usableWidth, usableHeight * preferredAspectRatio)
        let preferredHeight = min(usableHeight, preferredWidth / preferredAspectRatio)
        return CGSize(width: preferredWidth, height: preferredHeight)
    }

    enum BackgroundStyle {
        case blurred
        case clear
        case transparent
    }

    let theme: ScoreboardTheme
    let backgroundStyle: BackgroundStyle
    let sport: SportType
    let rules: SportRules
    let showsScore: Bool
    let homeTeamName: String
    let guestTeamName: String
    let homeTeamLogoData: Data?
    let guestTeamLogoData: Data?
    let playerLineupOverflowMode: PlayerLineupOverflowMode
    let playerLineupOverflowLogoOverride: PlayerLineupOverflowMode?
    let playerLineupOverflowNoLogoOverride: PlayerLineupOverflowMode?
    let playerLineupFadePageSeconds: Int
    let playerLineupScrollSpeed: Int
    let playerLineupScrollDirection: PlayerLineupScrollDirection
    let homeScore: Int
    let guestScore: Int
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
    let debateActiveTimer: DebateActiveTimer?
    let showsDebatePrepTime: Bool
    let formattedDebatePrepHomeClock: String?
    let formattedDebatePrepGuestClock: String?
    let formattedShotClock: String
    let possessionDirection: PossessionDirection
    let areSidesSwapped: Bool
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
    let homeTeamFouls: Int
    let guestTeamFouls: Int
    let homePenaltyTimers: [HockeyPenaltyTimer]
    let guestPenaltyTimers: [HockeyPenaltyTimer]
    let homePlayers: [TrackedPlayer]
    let guestPlayers: [TrackedPlayer]
    let compact: Bool

    private var palette: ThemePalette { theme.palette }
    private var usesTransparentBoardSurfaces: Bool { backgroundStyle == .transparent }
    private var boardPrimaryTextColor: Color { usesTransparentBoardSurfaces ? .white : palette.boardPrimaryText }
    private var boardSecondaryTextColor: Color { usesTransparentBoardSurfaces ? .white.opacity(0.72) : palette.boardSecondaryText }
    private var boardPanelBackgroundColor: Color { usesTransparentBoardSurfaces ? .black.opacity(0.78) : palette.boardPanelBackground }
    private var boardClockPanelBackgroundColor: Color { usesTransparentBoardSurfaces ? .black.opacity(0.84) : palette.boardClockPanelBackground }
    private var boardPanelBorderColor: Color { usesTransparentBoardSurfaces ? .white.opacity(0.16) : palette.boardPanelBorder }
    private var boardBadgeBackgroundColor: Color { usesTransparentBoardSurfaces ? .black.opacity(0.68) : palette.boardBadgeBackground }
    private var boardBadgeBorderColor: Color { usesTransparentBoardSurfaces ? .white.opacity(0.18) : palette.boardBadgeBorder }
    private var boardBadgeTitleTextColor: Color { usesTransparentBoardSurfaces ? .white.opacity(0.76) : palette.boardBadgeTitleText }
    private var boardBadgeValueTextColor: Color { usesTransparentBoardSurfaces ? .white : palette.boardBadgeValueText }
    private var displayAlertColor: Color { .red }
    private var usesDedicatedDualClockLayout: Bool { sport == .chess }
    private var shouldShowSubstitutionTracking: Bool { homeSubstitutionsAllowed > 0 || guestSubstitutionsAllowed > 0 }

    private enum PlayerLineupListStyle {
        case side
        case center
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)
            let boardAspect = size.height > 0 ? size.width / size.height : Self.preferredAspectRatio
            let condensed = compact || boardAspect < 1.55 || size.width < 960 || size.height < 560
            let ultraCondensed = size.width < 760 || size.height < 620
            let outerPadding = ultraCondensed ? max(12, base * 0.035) : condensed ? max(16, base * 0.045) : max(24, base * 0.07)
            let columnSpacing = ultraCondensed ? max(10, size.width * 0.012) : condensed ? max(14, size.width * 0.014) : max(24, size.width * 0.024)
            let centerWidth = min(
                max(size.width * (condensed ? 0.31 : 0.3), ultraCondensed ? 170 : condensed ? 210 : 260),
                size.width * (ultraCondensed ? 0.4 : 0.38)
            )
            let leftTeam = areSidesSwapped ? sidePanelData(for: .guest) : sidePanelData(for: .home)
            let rightTeam = areSidesSwapped ? sidePanelData(for: .home) : sidePanelData(for: .guest)
            let leftHasLogo = leftTeam.logoData != nil
            let rightHasLogo = rightTeam.logoData != nil
            let leftDisplayedPlayers = displayedPlayers(for: leftTeam.side)
            let rightDisplayedPlayers = displayedPlayers(for: rightTeam.side)
            let leftRequestedPlayerCount = leftDisplayedPlayers.count
            let rightRequestedPlayerCount = rightDisplayedPlayers.count
            let leftSidePlayerLimit = sidePlayerDisplayLimit(
                for: size,
                condensed: condensed,
                ultraCondensed: ultraCondensed,
                hasLogo: leftHasLogo
            )
            let rightSidePlayerLimit = sidePlayerDisplayLimit(
                for: size,
                condensed: condensed,
                ultraCondensed: ultraCondensed,
                hasLogo: rightHasLogo
            )
            let usesCenterPlayerStripLayout = usesCenterPlayerStripFallback(
                size: size,
                leftSidePlayerLimit: leftSidePlayerLimit,
                rightSidePlayerLimit: rightSidePlayerLimit,
                leftRequestedPlayerCount: leftRequestedPlayerCount,
                rightRequestedPlayerCount: rightRequestedPlayerCount
            )
            let showsSidePlayerStrip = leftSidePlayerLimit > 0 && rightSidePlayerLimit > 0 && !usesCenterPlayerStripLayout
            let leftPlayerViewportHeight = showsSidePlayerStrip ? sidePlayerViewportHeight(for: size, condensed: condensed, ultraCondensed: ultraCondensed, hasLogo: leftHasLogo) : 0
            let rightPlayerViewportHeight = showsSidePlayerStrip ? sidePlayerViewportHeight(for: size, condensed: condensed, ultraCondensed: ultraCondensed, hasLogo: rightHasLogo) : 0
            let centerHasLogo = leftHasLogo || rightHasLogo
            let centerPlayerViewportHeight = centerPlayerViewportHeight(for: size, condensed: condensed, ultraCondensed: ultraCondensed)
            let leftOverflowMode = resolvedPlayerLineupOverflowMode(hasLogo: leftHasLogo)
            let rightOverflowMode = resolvedPlayerLineupOverflowMode(hasLogo: rightHasLogo)
            let centerOverflowMode = resolvedPlayerLineupOverflowMode(hasLogo: centerHasLogo)

            ZStack {
                scoreboardBackground(leftAccent: leftTeam.accent, rightAccent: rightTeam.accent)

                Group {
                    if usesDedicatedDualClockLayout {
                        chessBoard(base: base, condensed: condensed, ultraCondensed: ultraCondensed)
                    } else {
                        HStack(spacing: columnSpacing) {
                            teamPanel(
                                side: leftTeam.side,
                                role: leftTeam.role,
                                title: leftTeam.title,
                                placeholder: leftTeam.role,
                                logoData: leftTeam.logoData,
                                score: leftTeam.score,
                                accent: leftTeam.accent,
                                substitutionsUsed: substitutionsUsed(for: leftTeam.side),
                                substitutionsAllowed: substitutionsAllowed(for: leftTeam.side),
                                teamFouls: teamFouls(for: leftTeam.side),
                                penaltyTimers: penaltyTimers(for: leftTeam.side),
                                displayedPlayers: leftDisplayedPlayers,
                                showsPlayerStrip: showsSidePlayerStrip,
                                playerViewportHeight: leftPlayerViewportHeight,
                                playerOverflowMode: leftOverflowMode,
                                base: base,
                                condensed: condensed,
                                ultraCondensed: ultraCondensed
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            centerClockPanel(
                                base: base,
                                condensed: condensed,
                                ultraCondensed: ultraCondensed,
                                showsCenterPlayerStrip: usesCenterPlayerStripLayout,
                                playerViewportHeight: centerPlayerViewportHeight,
                                playerOverflowMode: centerOverflowMode
                            )
                                .frame(width: centerWidth)
                                .frame(maxHeight: .infinity)

                            teamPanel(
                                side: rightTeam.side,
                                role: rightTeam.role,
                                title: rightTeam.title,
                                placeholder: rightTeam.role,
                                logoData: rightTeam.logoData,
                                score: rightTeam.score,
                                accent: rightTeam.accent,
                                substitutionsUsed: substitutionsUsed(for: rightTeam.side),
                                substitutionsAllowed: substitutionsAllowed(for: rightTeam.side),
                                teamFouls: teamFouls(for: rightTeam.side),
                                penaltyTimers: penaltyTimers(for: rightTeam.side),
                                displayedPlayers: rightDisplayedPlayers,
                                showsPlayerStrip: showsSidePlayerStrip,
                                playerViewportHeight: rightPlayerViewportHeight,
                                playerOverflowMode: rightOverflowMode,
                                base: base,
                                condensed: condensed,
                                ultraCondensed: ultraCondensed
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(outerPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func scoreboardBackground(leftAccent: Color, rightAccent: Color) -> some View {
        ZStack {
            if backgroundStyle != .transparent {
                LinearGradient(
                    colors: palette.boardBackground,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if backgroundStyle == .blurred {
                HStack {
                    RadialGradient(
                        colors: [
                            leftAccent.opacity(0.28),
                            .clear
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 420
                    )

                    Spacer()

                    RadialGradient(
                        colors: [
                            rightAccent.opacity(0.28),
                            .clear
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 420
                    )
                }
            }

            if backgroundStyle == .blurred {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.boardHighlightTop,
                                .clear,
                                .clear,
                                palette.boardHighlightBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private func teamPanel(
        side: TeamSide,
        role: String,
        title: String,
        placeholder: String,
        logoData: Data?,
        score: Int,
        accent: Color,
        substitutionsUsed: Int,
        substitutionsAllowed: Int,
        teamFouls: Int,
        penaltyTimers: [HockeyPenaltyTimer],
        displayedPlayers: [TrackedPlayer],
        showsPlayerStrip: Bool,
        playerViewportHeight: CGFloat,
        playerOverflowMode: PlayerLineupOverflowMode,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool
    ) -> some View {
        VStack(spacing: ultraCondensed ? max(8, base * 0.016) : condensed ? max(12, base * 0.02) : max(22, base * 0.035)) {
            VStack(spacing: ultraCondensed ? 6 : condensed ? 10 : 12) {
                if let logoData {
                    TeamLogoImageView(data: logoData, cornerRadius: ultraCondensed ? 8 : 10)
                        .frame(
                            width: ultraCondensed ? base * 0.1 : condensed ? base * 0.12 : base * 0.14,
                            height: ultraCondensed ? base * 0.1 : condensed ? base * 0.12 : base * 0.14
                        )
                        .frame(maxWidth: .infinity)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }

                Text(role)
                    .font(.system(size: ultraCondensed ? base * 0.022 : condensed ? base * 0.026 : base * 0.028, weight: .black, design: .rounded))
                    .tracking(ultraCondensed ? 1.5 : condensed ? 3 : 2)
                    .singleLineFitted(minScale: 0.8)
                    .foregroundStyle(boardSecondaryTextColor)

                Text(resolvedTitle(title, placeholder: placeholder))
                    .font(.system(size: ultraCondensed ? base * 0.034 : condensed ? base * 0.044 : base * 0.054, weight: .black, design: .rounded))
                    .singleLineFitted(minScale: 0.35)
                    .foregroundStyle(boardPrimaryTextColor)

                Capsule()
                    .fill(accent)
                    .frame(width: ultraCondensed ? base * 0.22 : condensed ? base * 0.26 : base * 0.24, height: ultraCondensed ? 5 : condensed ? 7 : 8)
            }

            Spacer(minLength: 0)

            if showsScore {
                Text("\(score)")
                    .font(.system(size: ultraCondensed ? base * 0.15 : condensed ? base * 0.22 : base * 0.28, weight: .black, design: .rounded))
                    .singleLineFitted(minScale: 0.32)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.28, dampingFraction: 0.76), value: score)
                    .foregroundStyle(accent)
                    .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.35) : .clear, radius: 12, y: 4)
                    .frame(maxWidth: .infinity)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            if sport == .debate && showsDebatePrepTime {
                debatePrepStrip(
                    side: side,
                    accent: accent,
                    condensed: condensed,
                    ultraCondensed: ultraCondensed
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if shouldShowSubstitutionTracking, substitutionsAllowed > 0 {
                substitutionLightStrip(
                    used: substitutionsUsed,
                    allowed: substitutionsAllowed,
                    accent: accent,
                    base: base,
                    condensed: condensed,
                    ultraCondensed: ultraCondensed
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if rules.supportsTeamFouls {
                teamFoulStrip(
                    fouls: teamFouls,
                    accent: accent,
                    ultraCondensed: ultraCondensed,
                    condensed: condensed
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if rules.supportsHockeyPenalties {
                hockeyPenaltyStrip(
                    penaltyTimers: penaltyTimers,
                    accent: accent,
                    base: base,
                    condensed: condensed,
                    ultraCondensed: ultraCondensed
                )
            }

            if showsPlayerStrip, !rules.usesCenterPlayerStrip, !displayedPlayers.isEmpty, playerViewportHeight > 0 {
                activeLineupStrip(
                    displayedPlayers,
                    accent: accent,
                    base: base,
                    condensed: condensed,
                    ultraCondensed: ultraCondensed,
                    viewportHeight: playerViewportHeight,
                    overflowMode: playerOverflowMode
                )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(ultraCondensed ? 14 : condensed ? 20 : 24)
        .background(boardPanelBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 20 : condensed ? 34 : 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 20 : condensed ? 34 : 28, style: .continuous)
                .strokeBorder(boardPanelBorderColor)
        )
        .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.30) : .clear, radius: 18, y: 8)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: logoData != nil)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: playerViewportHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: playerOverflowMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: substitutionsUsed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: substitutionsAllowed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: teamFouls)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: showsScore)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: showsDebatePrepTime)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayedPlayers)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: isPlayerOverlayPaused)
    }

    private func activeLineupStrip(
        _ players: [TrackedPlayer],
        accent: Color,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool,
        viewportHeight: CGFloat,
        overflowMode: PlayerLineupOverflowMode
    ) -> some View {
        playerLineupBadge(ultraCondensed: ultraCondensed) {
            playerLineupColumn(
                title: "PLAYERS",
                players: players,
                accent: accent,
                base: base,
                condensed: condensed,
                ultraCondensed: ultraCondensed,
                style: .side,
                viewportHeight: viewportHeight,
                overflowMode: overflowMode
            )
        }
    }

    private func centerClockPanel(
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool,
        showsCenterPlayerStrip: Bool,
        playerViewportHeight: CGFloat,
        playerOverflowMode: PlayerLineupOverflowMode
    ) -> some View {
        VStack(spacing: ultraCondensed ? max(8, base * 0.014) : condensed ? max(12, base * 0.02) : max(20, base * 0.03)) {
            Spacer(minLength: 0)

            if showsDualClocks {
                HStack(spacing: ultraCondensed ? 8 : condensed ? 12 : 14) {
                    headerBadge(
                        title: (sport == .debate ? sideRoleLabel(for: .home) : resolvedTitle(homeTeamName, placeholder: "HOME")).uppercased(),
                        value: formattedHomeChessClock,
                        condensed: condensed,
                        ultraCondensed: ultraCondensed,
                        valueFontSize: ultraCondensed ? base * 0.058 : condensed ? base * 0.075 : base * 0.078,
                        valueMinScale: 0.42,
                        valueColor: activeChessClockSide == .home ? palette.homeAccent : boardBadgeValueTextColor
                    )

                    headerBadge(
                        title: (sport == .debate ? sideRoleLabel(for: .guest) : resolvedTitle(guestTeamName, placeholder: "GUEST")).uppercased(),
                        value: formattedGuestChessClock,
                        condensed: condensed,
                        ultraCondensed: ultraCondensed,
                        valueFontSize: ultraCondensed ? base * 0.058 : condensed ? base * 0.075 : base * 0.078,
                        valueMinScale: 0.42,
                        valueColor: activeChessClockSide == .guest ? palette.guestAccent : boardBadgeValueTextColor
                    )
                }
                .id("public-dual-\(debateSegmentTitle ?? "")")
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if showsGameClock {
                Text(formattedClock)
                    .font(.system(size: ultraCondensed ? base * 0.115 : condensed ? base * 0.17 : base * 0.19, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .singleLineFitted(minScale: 0.24)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.34, dampingFraction: 0.84), value: formattedClock)
                    .foregroundStyle(isDisplayGameClockAlertActive ? displayAlertColor : boardPrimaryTextColor)
                    .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.35) : .clear, radius: 12, y: 4)
                    .frame(maxWidth: .infinity)
                    .id("public-master-\(debateSegmentTitle ?? "")")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(spacing: ultraCondensed ? 8 : condensed ? 10 : 12) {
                let shotClockValueSize = ultraCondensed ? base * 0.088 : condensed ? base * 0.118 : base * 0.132

                if sport == .debate,
                   let debateSegmentTitle,
                   !debateSegmentTitle.isEmpty {
                    headerBadge(title: "SEGMENT", value: localizedBoardString(debateSegmentTitle).uppercased(), condensed: condensed, ultraCondensed: ultraCondensed)
                        .id("public-segment-\(debateSegmentTitle)")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if rules.supportsShotClock {
                    shotClockBadge(
                        value: formattedShotClock,
                        condensed: condensed,
                        ultraCondensed: ultraCondensed,
                        base: base,
                        valueFontSize: shotClockValueSize,
                        valueMinScale: 0.34,
                        valueColor: isDisplayShotClockAlertActive ? displayAlertColor : boardBadgeValueTextColor
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }

                HStack(spacing: ultraCondensed ? 8 : condensed ? 14 : 12) {
                    if showsDualClocks {
                        headerBadge(title: "TURN", value: activeChessClockSide.map { sideRoleLabel(for: $0).uppercased() } ?? localizedBoardString("NONE"), condensed: condensed, ultraCondensed: ultraCondensed)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else if showsGameClock {
                        headerBadge(title: "CLOCK", value: localizedBoardString(isClockRunning ? "RUNNING" : "STOPPED"), condensed: condensed, ultraCondensed: ultraCondensed)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if rules.supportsPeriod {
                        headerBadge(title: localizedBoardString(rules.periodTitle).uppercased(), value: "\(period)", condensed: condensed, ultraCondensed: ultraCondensed)
                    }
                }

                if showsCenterPlayerStrip {
                    soccerCenterPlayerStrip(
                        base: base,
                        condensed: condensed,
                        ultraCondensed: ultraCondensed,
                        viewportHeight: playerViewportHeight,
                        overflowMode: playerOverflowMode
                    )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

            }

            Spacer(minLength: 0)
        }
        .padding(ultraCondensed ? 14 : condensed ? 20 : 24)
        .background(boardClockPanelBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 22 : condensed ? 38 : 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 22 : condensed ? 38 : 30, style: .continuous)
                .strokeBorder(boardPanelBorderColor)
        )
        .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.34) : .clear, radius: 18, y: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: isPlayerOverlayPaused)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: debateSegmentTitle)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: formattedShotClock)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: isDisplayShotClockAlertActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: period)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: displayedPlayers(for: .home))
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: displayedPlayers(for: .guest))
    }

    private func shotClockBadge(
        value: String,
        condensed: Bool,
        ultraCondensed: Bool,
        base: CGFloat,
        valueFontSize: CGFloat,
        valueMinScale: CGFloat,
        valueColor: Color
    ) -> some View {
        let arrowFontSize = ultraCondensed ? min(26, base * 0.044) : condensed ? min(34, base * 0.055) : min(40, base * 0.064)
        let arrowSlotWidth = arrowFontSize + (ultraCondensed ? 6 : 8)
        let arrowIndicator = centerPossessionIndicator
        let showsArrowIndicator = arrowIndicator != nil
        let showsLeftArrow = arrowIndicator?.systemName.contains("left") == true
        let showsRightArrow = arrowIndicator?.systemName.contains("right") == true
        let resolvedValueMinScale = min(valueMinScale, ultraCondensed ? 0.12 : condensed ? 0.16 : 0.22)

        return ZStack {
            headerBadge(
                title: "SHOT",
                value: value,
                condensed: condensed,
                ultraCondensed: ultraCondensed,
                valueFontSize: valueFontSize,
                valueMinScale: resolvedValueMinScale,
                valueColor: valueColor,
                showsContainer: false
            )
            .layoutPriority(2)

            if showsArrowIndicator {
                HStack {
                    shotArrowSlot(
                        systemName: arrowIndicator?.systemName,
                        color: arrowIndicator?.color,
                        isVisible: showsLeftArrow,
                        fontSize: arrowFontSize,
                        slotWidth: arrowSlotWidth
                    )

                    Spacer(minLength: 0)

                    shotArrowSlot(
                        systemName: arrowIndicator?.systemName,
                        color: arrowIndicator?.color,
                        isVisible: showsRightArrow,
                        fontSize: arrowFontSize,
                        slotWidth: arrowSlotWidth
                    )
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, ultraCondensed ? 10 : condensed ? 16 : 18)
        .padding(.vertical, ultraCondensed ? 8 : condensed ? 12 : 14)
        .background(boardBadgeBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 12 : condensed ? 22 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 12 : condensed ? 22 : 18, style: .continuous)
                .strokeBorder(boardBadgeBorderColor)
        )
    }

    private func chessBoard(base: CGFloat, condensed: Bool, ultraCondensed: Bool) -> some View {
        let leftSide: TeamSide = areSidesSwapped ? .guest : .home
        let rightSide: TeamSide = areSidesSwapped ? .home : .guest
        return HStack(spacing: ultraCondensed ? 12 : 18) {
            chessClockCard(
                title: resolvedTitle(leftSide == .home ? homeTeamName : guestTeamName, placeholder: leftSide.title.uppercased()),
                clock: leftSide == .home ? formattedHomeChessClock : formattedGuestChessClock,
                isActive: activeChessClockSide == leftSide,
                accent: leftSide == .home ? palette.homeAccent : palette.guestAccent,
                base: base,
                condensed: condensed,
                ultraCondensed: ultraCondensed
            )

            chessClockCard(
                title: resolvedTitle(rightSide == .home ? homeTeamName : guestTeamName, placeholder: rightSide.title.uppercased()),
                clock: rightSide == .home ? formattedHomeChessClock : formattedGuestChessClock,
                isActive: activeChessClockSide == rightSide,
                accent: rightSide == .home ? palette.homeAccent : palette.guestAccent,
                base: base,
                condensed: condensed,
                ultraCondensed: ultraCondensed
            )
        }
    }

    private func chessClockCard(title: String, clock: String, isActive: Bool, accent: Color, base: CGFloat, condensed: Bool, ultraCondensed: Bool) -> some View {
        VStack(spacing: ultraCondensed ? 10 : 16) {
            Text(title)
                .font(.system(size: ultraCondensed ? base * 0.05 : condensed ? base * 0.065 : base * 0.058, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.5)
                .foregroundStyle(boardPrimaryTextColor)

            Text(clock)
                .font(.system(size: ultraCondensed ? base * 0.16 : condensed ? base * 0.22 : base * 0.2, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)

            localizedBoardText(isActive ? "ACTIVE" : "WAITING")
                .font(.system(size: ultraCondensed ? 12 : 16, weight: .black, design: .rounded))
                .foregroundStyle(isActive ? accent : boardSecondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(ultraCondensed ? 18 : 28)
        .background(boardClockPanelBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 22 : 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 22 : 30, style: .continuous)
                .strokeBorder(boardPanelBorderColor)
        )
    }

    private func shotArrowSlot(
        systemName: String?,
        color: Color?,
        isVisible: Bool,
        fontSize: CGFloat,
        slotWidth: CGFloat
    ) -> some View {
        Group {
            if isVisible, let systemName, let color {
                Image(systemName: systemName)
                    .foregroundStyle(color)
            } else {
                Image(systemName: "arrow.left.circle.fill")
                    .foregroundStyle(.clear)
            }
        }
        .font(.system(size: fontSize, weight: .black))
        .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.35) : .clear, radius: 12, y: 4)
        .frame(width: slotWidth)
    }

    private func headerBadge(
        title: String,
        value: String,
        condensed: Bool,
        ultraCondensed: Bool,
        valueFontSize: CGFloat? = nil,
        valueMinScale: CGFloat = 0.55,
        valueColor: Color? = nil,
        showsContainer: Bool = true
    ) -> some View {
        VStack(spacing: ultraCondensed ? 3 : 6) {
            localizedBoardText(title)
                .font(.system(size: ultraCondensed ? 10 : condensed ? 13 : 14, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.5)
                .singleLineFitted(minScale: 0.75)
                .foregroundStyle(boardBadgeTitleTextColor)
                .frame(maxWidth: .infinity)

            Text(value)
                .font(.system(size: valueFontSize ?? (ultraCondensed ? 18 : condensed ? 28 : 28), weight: .heavy, design: .rounded))
                .monospacedDigit()
                .allowsTightening(true)
                .singleLineFitted(minScale: valueMinScale)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: value)
                .foregroundStyle(valueColor ?? boardBadgeValueTextColor)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ultraCondensed ? 10 : condensed ? 16 : 18)
        .padding(.vertical, ultraCondensed ? 8 : condensed ? 12 : 14)
        .background(
            Group {
                if showsContainer {
                    RoundedRectangle(cornerRadius: ultraCondensed ? 12 : condensed ? 22 : 18, style: .continuous)
                        .fill(boardBadgeBackgroundColor)
                }
            }
        )
        .overlay(
            Group {
                if showsContainer {
                    RoundedRectangle(cornerRadius: ultraCondensed ? 12 : condensed ? 22 : 18, style: .continuous)
                        .strokeBorder(boardBadgeBorderColor)
                }
            }
        )
        .frame(maxWidth: .infinity)
    }

    private func substitutionLightStrip(
        used: Int,
        allowed: Int,
        accent: Color,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool
    ) -> some View {
        let boundedAllowed = max(0, min(allowed, 12))
        let boundedUsed = max(0, min(used, boundedAllowed))
        let dotSize = ultraCondensed ? max(8, base * 0.015) : condensed ? max(10, base * 0.018) : max(12, base * 0.02)

        return VStack(alignment: .leading, spacing: ultraCondensed ? 6 : 8) {
            localizedBoardText("SWAPS")
                .font(.system(size: ultraCondensed ? 10 : condensed ? 14 : 12, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.4)
                .foregroundStyle(boardSecondaryTextColor)

            HStack(spacing: ultraCondensed ? 5 : 7) {
                ForEach(0..<boundedAllowed, id: \.self) { index in
                    Circle()
                        .fill(index < boundedUsed ? accent : boardBadgeBorderColor.opacity(0.45))
                        .scaleEffect(index < boundedUsed ? 1.08 : 0.92)
                        .frame(width: dotSize, height: dotSize)
                        .overlay(
                            Circle()
                                .strokeBorder(index < boundedUsed ? accent.opacity(0.35) : boardBadgeBorderColor, lineWidth: 1)
                        )
                        .shadow(
                            color: index < boundedUsed ? accent.opacity(0.45) : .clear,
                            radius: ultraCondensed ? 4 : 6
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ultraCondensed ? 10 : 12)
        .padding(.vertical, ultraCondensed ? 8 : 10)
        .background(boardBadgeBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous)
                .strokeBorder(boardBadgeBorderColor)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.74), value: boundedUsed)
    }

    private func teamFoulStrip(
        fouls: Int,
        accent: Color,
        ultraCondensed: Bool,
        condensed: Bool
    ) -> some View {
        let visibleLimit = 8
        let boundedFouls = max(0, fouls)
        let visibleFouls = min(boundedFouls, visibleLimit)
        let overflow = max(0, boundedFouls - visibleLimit)

        return VStack(alignment: .leading, spacing: ultraCondensed ? 6 : 8) {
            localizedBoardText("FOULS")
                .font(.system(size: ultraCondensed ? 10 : condensed ? 14 : 12, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.4)
                .foregroundStyle(boardSecondaryTextColor)

            HStack(spacing: ultraCondensed ? 5 : 7) {
                ForEach(0..<visibleLimit, id: \.self) { index in
                    Text("X")
                        .font(.system(size: ultraCondensed ? 11 : condensed ? 15 : 13, weight: .black, design: .rounded))
                        .foregroundStyle(index < visibleFouls ? accent : boardBadgeBorderColor.opacity(0.45))
                        .scaleEffect(index < visibleFouls ? 1.08 : 0.96)
                        .shadow(color: index < visibleFouls ? accent.opacity(0.35) : .clear, radius: 4)
                }

                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.system(size: ultraCondensed ? 10 : condensed ? 13 : 12, weight: .black, design: .rounded))
                        .foregroundStyle(boardBadgeValueTextColor)
                        .padding(.leading, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ultraCondensed ? 10 : 12)
        .padding(.vertical, ultraCondensed ? 8 : 10)
        .background(boardBadgeBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous)
                .strokeBorder(boardBadgeBorderColor)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.74), value: visibleFouls)
    }

    private func hockeyPenaltyStrip(
        penaltyTimers: [HockeyPenaltyTimer],
        accent: Color,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool
    ) -> some View {
        let visibleTimers = Array(penaltyTimers.prefix(3))
        let overflow = max(0, penaltyTimers.count - visibleTimers.count)

        return VStack(alignment: .leading, spacing: ultraCondensed ? 6 : 8) {
            localizedBoardText("PENALTIES")
                .font(.system(size: ultraCondensed ? 10 : condensed ? 14 : 12, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.4)
                .foregroundStyle(boardSecondaryTextColor)

            ForEach(visibleTimers) { timer in
                HStack(spacing: 8) {
                    Text(timer.playerNumber.isEmpty ? "#" : "#\(timer.playerNumber)")
                        .font(.system(size: ultraCondensed ? base * 0.018 : base * 0.02, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                    Text(timer.playerName.isEmpty ? localizedBoardString("PLAYER") : timer.playerName)
                        .font(.system(size: ultraCondensed ? base * 0.016 : base * 0.018, weight: .bold, design: .rounded))
                        .singleLineFitted(minScale: 0.6)
                        .foregroundStyle(boardPrimaryTextColor)
                    Spacer(minLength: 0)
                    Text(ScoreboardStore.formatGameClock(timer.remainingSeconds))
                        .font(.system(size: ultraCondensed ? base * 0.02 : base * 0.022, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timer.isRunning ? accent : boardBadgeValueTextColor)
                }
            }

            if overflow > 0 {
                Text(localizedBoardFormat("+%lld more", overflow))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(boardSecondaryTextColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ultraCondensed ? 10 : 12)
        .padding(.vertical, ultraCondensed ? 8 : 10)
        .background(boardBadgeBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous)
                .strokeBorder(boardBadgeBorderColor)
        )
    }

    private func soccerCenterPlayerStrip(
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool,
        viewportHeight: CGFloat,
        overflowMode: PlayerLineupOverflowMode
    ) -> some View {
        playerLineupBadge(ultraCondensed: ultraCondensed) {
            HStack(alignment: .top, spacing: ultraCondensed ? 10 : condensed ? 14 : 16) {
                playerLineupColumn(
                    title: localizedBoardFormat("%@ PLAYERS", sideRoleLabel(for: .home).uppercased()),
                    players: displayedPlayers(for: .home),
                    accent: palette.homeAccent,
                    base: base,
                    condensed: condensed,
                    ultraCondensed: ultraCondensed,
                    style: .center,
                    viewportHeight: viewportHeight,
                    overflowMode: overflowMode
                )

                playerLineupColumn(
                    title: localizedBoardFormat("%@ PLAYERS", sideRoleLabel(for: .guest).uppercased()),
                    players: displayedPlayers(for: .guest),
                    accent: palette.guestAccent,
                    base: base,
                    condensed: condensed,
                    ultraCondensed: ultraCondensed,
                    style: .center,
                    viewportHeight: viewportHeight,
                    overflowMode: overflowMode
                )
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: displayedPlayers(for: .home))
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: displayedPlayers(for: .guest))
    }

    private func playerLineupBadge<Content: View>(
        ultraCondensed: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, ultraCondensed ? 10 : 12)
            .padding(.vertical, ultraCondensed ? 8 : 10)
            .background(boardBadgeBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous)
                    .strokeBorder(boardBadgeBorderColor)
            )
    }

    private func playerLineupColumn(
        title: String,
        players: [TrackedPlayer],
        accent: Color,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool,
        style: PlayerLineupListStyle,
        viewportHeight: CGFloat,
        overflowMode: PlayerLineupOverflowMode
    ) -> some View {
        let height = max(28, viewportHeight)
        let unscaledHeight = playerLineupContentHeight(
            playerCount: players.count,
            base: base,
            condensed: condensed,
            ultraCondensed: ultraCondensed,
            style: style,
            scale: 1
        )
        let fitScale = overflowMode == .fit ? max(playerLineupMinimumFitScale(for: style), min(1, height / max(unscaledHeight, 1))) : 1
        let titleFontSize = playerLineupTitleFontSize(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style) * fitScale
        let titleHeight = titleFontSize * 1.25
        let titleSpacing = players.isEmpty ? 0 : playerLineupTitleSpacing(ultraCondensed: ultraCondensed, style: style) * fitScale
        let rowsViewportHeight = max(1, height - titleHeight - titleSpacing)
        let rowsContentHeight = playerLineupRowsHeight(
            playerCount: players.count,
            base: base,
            condensed: condensed,
            ultraCondensed: ultraCondensed,
            style: style,
            scale: fitScale
        )
        let shouldClipRows = rowsContentHeight > rowsViewportHeight + 1
        let shouldScroll = overflowMode == .scroll && shouldClipRows
        let usesPagedRows = (overflowMode == .fade || overflowMode == .fit) && shouldClipRows
        let pageSize = usesPagedRows
            ? playerLineupPageSize(
                rowViewportHeight: rowsViewportHeight,
                rowHeight: playerLineupRowHeight(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style) * fitScale,
                rowSpacing: playerLineupRowSpacing(ultraCondensed: ultraCondensed, style: style) * fitScale
            )
            : max(players.count, 1)
        let pageCount = usesPagedRows ? max(1, Int(ceil(Double(players.count) / Double(max(pageSize, 1))))) : 1
        let timelineInterval = shouldScroll ? 1.0 / 30.0 : (usesPagedRows && pageCount > 1 ? 0.5 : 1.0)

        return TimelineView(.animation(minimumInterval: timelineInterval)) { timeline in
            playerLineupColumnContent(
                title: title,
                players: players,
                accent: accent,
                base: base,
                condensed: condensed,
                ultraCondensed: ultraCondensed,
                style: style,
                fitScale: fitScale,
                titleFontSize: titleFontSize,
                titleSpacing: titleSpacing,
                rowsViewportHeight: rowsViewportHeight,
                shouldScroll: shouldScroll,
                usesPagedRows: usesPagedRows && pageCount > 1,
                pageSize: pageSize,
                pageIndex: usesPagedRows && pageCount > 1 ? playerLineupPageIndex(pageCount: pageCount, date: timeline.date) : 0,
                pageCount: pageCount,
                scrollDate: timeline.date
            )
        }
    }

    private func playerLineupColumnContent(
        title: String,
        players: [TrackedPlayer],
        accent: Color,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool,
        style: PlayerLineupListStyle,
        fitScale: CGFloat,
        titleFontSize: CGFloat,
        titleSpacing: CGFloat,
        rowsViewportHeight: CGFloat,
        shouldScroll: Bool,
        usesPagedRows: Bool,
        pageSize: Int,
        pageIndex: Int,
        pageCount: Int,
        scrollDate: Date
    ) -> some View {
        let visiblePlayers: [TrackedPlayer]
        if usesPagedRows {
            let start = min(players.count, max(0, pageIndex) * max(pageSize, 1))
            let end = min(players.count, start + max(pageSize, 1))
            visiblePlayers = Array(players[start..<end])
        } else {
            visiblePlayers = players
        }
        let visibleRowsContentHeight = playerLineupRowsHeight(
            playerCount: visiblePlayers.count,
            base: base,
            condensed: condensed,
            ultraCondensed: ultraCondensed,
            style: style,
            scale: fitScale
        )
        let titleText = pageCount > 1 ? "\(localizedBoardString(title)) (\(pageIndex + 1)/\(pageCount))" : localizedBoardString(title)

        return VStack(alignment: .leading, spacing: titleSpacing) {
            Text(titleText)
                .font(.system(size: titleFontSize, weight: .black, design: .rounded))
                .tracking((style == .side ? (ultraCondensed ? 0.8 : 1.4) : (ultraCondensed ? 0.8 : 1.2)) * fitScale)
                .foregroundStyle(boardSecondaryTextColor)

            if !visiblePlayers.isEmpty {
                playerLineupViewport(
                    height: rowsViewportHeight,
                    contentHeight: visibleRowsContentHeight,
                    shouldScroll: shouldScroll,
                    shouldFade: visibleRowsContentHeight > rowsViewportHeight + 1,
                    date: scrollDate
                ) {
                    VStack(spacing: playerLineupRowSpacing(ultraCondensed: ultraCondensed, style: style) * fitScale) {
                        ForEach(visiblePlayers) { player in
                            playerLineupRow(
                                player,
                                accent: accent,
                                base: base,
                                condensed: condensed,
                                ultraCondensed: ultraCondensed,
                                style: style,
                                scale: fitScale
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.35), value: pageIndex)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: players)
    }

    private func playerLineupViewport<Content: View>(
        height: CGFloat,
        contentHeight: CGFloat,
        shouldScroll: Bool,
        shouldFade: Bool,
        date: Date,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let distance = max(0, contentHeight - height)
        let offset = shouldScroll && distance > 1 ? playerLineupScrollOffset(distance: distance, date: date) : 0
        return clippedPlayerLineupContent(
            offset: offset,
            height: height,
            shouldFade: shouldFade || shouldScroll,
            content: content
        )
    }

    @ViewBuilder
    private func clippedPlayerLineupContent<Content: View>(
        offset: CGFloat,
        height: CGFloat,
        shouldFade: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if shouldFade {
            content()
                .offset(y: offset)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: height, alignment: .top)
                .clipped()
                .mask(playerLineupFadeMask())
        } else {
            content()
                .offset(y: offset)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: height, alignment: .top)
                .clipped()
        }
    }

    private func playerLineupFadeMask() -> some View {
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

    private func playerLineupScrollOffset(distance: CGFloat, date: Date) -> CGFloat {
        let speed = CGFloat(max(1, playerLineupScrollSpeed))
        let pause: TimeInterval = 1.4
        let travel = TimeInterval(max(distance / speed, 0.1))
        let cycle = (travel * 2) + (pause * 2)
        guard cycle > 0 else {
            return 0
        }

        let time = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        if time < pause {
            return playerLineupDirectionalScrollOffset(upwardOffset: 0, distance: distance)
        }
        if time < pause + travel {
            let upwardOffset = -distance * CGFloat((time - pause) / travel)
            return playerLineupDirectionalScrollOffset(upwardOffset: upwardOffset, distance: distance)
        }
        if time < pause + travel + pause {
            return playerLineupDirectionalScrollOffset(upwardOffset: -distance, distance: distance)
        }
        let upwardOffset = -distance + (distance * CGFloat((time - pause - travel - pause) / travel))
        return playerLineupDirectionalScrollOffset(upwardOffset: upwardOffset, distance: distance)
    }

    private func playerLineupDirectionalScrollOffset(upwardOffset: CGFloat, distance: CGFloat) -> CGFloat {
        switch playerLineupScrollDirection {
        case .up:
            return upwardOffset
        case .down:
            return -distance - upwardOffset
        }
    }

    private func playerLineupPageIndex(pageCount: Int, date: Date) -> Int {
        guard pageCount > 1 else {
            return 0
        }
        let pageSeconds = TimeInterval(max(1, playerLineupFadePageSeconds))
        return Int(date.timeIntervalSinceReferenceDate / pageSeconds) % pageCount
    }

    private func playerLineupPageSize(rowViewportHeight: CGFloat, rowHeight: CGFloat, rowSpacing: CGFloat) -> Int {
        let rowHeight = max(1, rowHeight)
        let rowSpacing = max(0, rowSpacing)
        guard rowViewportHeight > rowHeight else {
            return 1
        }
        return max(1, Int(floor((rowViewportHeight + rowSpacing) / (rowHeight + rowSpacing))))
    }

    private func playerLineupRow(
        _ player: TrackedPlayer,
        accent: Color,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool,
        style: PlayerLineupListStyle,
        scale: CGFloat
    ) -> some View {
        HStack(spacing: playerLineupHorizontalSpacing(style: style) * scale) {
            Text("#\(player.number.isEmpty ? "--" : player.number)")
                .font(.system(size: playerLineupNumberFontSize(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style) * scale, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: playerLineupNumberWidth(ultraCondensed: ultraCondensed, condensed: condensed, style: style) * scale, alignment: .leading)

            Text(player.name.isEmpty ? localizedBoardString("PLAYER") : player.name)
                .font(.system(size: playerLineupNameFontSize(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style) * scale, weight: .bold, design: .rounded))
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(playerStatusColor(player))
                .frame(maxWidth: .infinity, alignment: .leading)

            if style == .side {
                Spacer(minLength: 0)
            }

            if rules.supportsFouls {
                Text(foulDisplayText(for: player.foulCount))
                    .font(.system(size: playerLineupFoulFontSize(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style) * scale, weight: .black, design: .rounded))
                    .monospaced()
                    .foregroundStyle(player.foulCount > 0 ? foulHighlightColor : boardPrimaryTextColor)
            }
        }
        .scaleEffect(player.cardStatus != .none || player.foulCount > 0 ? 1.02 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: player.cardStatus)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: player.foulCount)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private func playerLineupContentHeight(
        playerCount: Int,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool,
        style: PlayerLineupListStyle,
        scale: CGFloat
    ) -> CGFloat {
        let boundedCount = max(0, playerCount)
        let titleHeight = playerLineupTitleFontSize(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style) * 1.25
        guard boundedCount > 0 else {
            return titleHeight * scale
        }

        let rowHeight = playerLineupRowHeight(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style)
        let rowSpacing = playerLineupRowSpacing(ultraCondensed: ultraCondensed, style: style)
        let titleSpacing = playerLineupTitleSpacing(ultraCondensed: ultraCondensed, style: style)
        return (titleHeight + titleSpacing + (rowHeight * CGFloat(boundedCount)) + (rowSpacing * CGFloat(max(0, boundedCount - 1)))) * scale
    }

    private func playerLineupRowsHeight(
        playerCount: Int,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool,
        style: PlayerLineupListStyle,
        scale: CGFloat
    ) -> CGFloat {
        let boundedCount = max(0, playerCount)
        guard boundedCount > 0 else {
            return 0
        }

        let rowHeight = playerLineupRowHeight(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style)
        let rowSpacing = playerLineupRowSpacing(ultraCondensed: ultraCondensed, style: style)
        return ((rowHeight * CGFloat(boundedCount)) + (rowSpacing * CGFloat(max(0, boundedCount - 1)))) * scale
    }

    private func playerLineupRowHeight(base: CGFloat, condensed: Bool, ultraCondensed: Bool, style: PlayerLineupListStyle) -> CGFloat {
        max(
            playerLineupNumberFontSize(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style),
            playerLineupNameFontSize(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style),
            playerLineupFoulFontSize(base: base, condensed: condensed, ultraCondensed: ultraCondensed, style: style)
        ) * 1.28
    }

    private func playerLineupTitleFontSize(base: CGFloat, condensed: Bool, ultraCondensed: Bool, style: PlayerLineupListStyle) -> CGFloat {
        switch style {
        case .side:
            return ultraCondensed ? 10 : condensed ? 14 : 12
        case .center:
            return ultraCondensed ? 9 : condensed ? 12 : 11
        }
    }

    private func playerLineupNumberFontSize(base: CGFloat, condensed: Bool, ultraCondensed: Bool, style: PlayerLineupListStyle) -> CGFloat {
        switch style {
        case .side:
            return ultraCondensed ? base * 0.022 : condensed ? base * 0.027 : base * 0.024
        case .center:
            return ultraCondensed ? base * 0.016 : condensed ? base * 0.019 : base * 0.017
        }
    }

    private func playerLineupNameFontSize(base: CGFloat, condensed: Bool, ultraCondensed: Bool, style: PlayerLineupListStyle) -> CGFloat {
        switch style {
        case .side:
            return ultraCondensed ? base * 0.021 : condensed ? base * 0.026 : base * 0.023
        case .center:
            return ultraCondensed ? base * 0.015 : condensed ? base * 0.018 : base * 0.016
        }
    }

    private func playerLineupFoulFontSize(base: CGFloat, condensed: Bool, ultraCondensed: Bool, style: PlayerLineupListStyle) -> CGFloat {
        switch style {
        case .side:
            return ultraCondensed ? base * 0.02 : condensed ? base * 0.024 : base * 0.022
        case .center:
            return ultraCondensed ? base * 0.014 : condensed ? base * 0.017 : base * 0.015
        }
    }

    private func playerLineupNumberWidth(ultraCondensed: Bool, condensed: Bool, style: PlayerLineupListStyle) -> CGFloat {
        switch style {
        case .side:
            return ultraCondensed ? 48 : 60
        case .center:
            return ultraCondensed ? 50 : condensed ? 58 : 54
        }
    }

    private func playerLineupHorizontalSpacing(style: PlayerLineupListStyle) -> CGFloat {
        style == .side ? 8 : 6
    }

    private func playerLineupTitleSpacing(ultraCondensed: Bool, style: PlayerLineupListStyle) -> CGFloat {
        switch style {
        case .side:
            return ultraCondensed ? 6 : 8
        case .center:
            return ultraCondensed ? 4 : 6
        }
    }

    private func playerLineupRowSpacing(ultraCondensed: Bool, style: PlayerLineupListStyle) -> CGFloat {
        ultraCondensed ? 4 : 6
    }

    private func playerLineupMinimumFitScale(for style: PlayerLineupListStyle) -> CGFloat {
        style == .side ? 0.66 : 0.72
    }

    private func resolvedTitle(_ title: String, placeholder: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? localizedBoardString(placeholder) : trimmed
    }

    private var centerPossessionIndicator: (systemName: String, color: Color)? {
        guard rules.supportsPossession else {
            return nil
        }

        switch possessionDirection {
        case .home:
            return (areSidesSwapped ? "arrow.left.circle.fill" : "arrow.right.circle.fill", palette.homeAccent)
        case .guest:
            return (areSidesSwapped ? "arrow.right.circle.fill" : "arrow.left.circle.fill", palette.guestAccent)
        case .none:
            return nil
        }
    }

    private func usesCenterPlayerStripFallback(
        size: CGSize,
        leftSidePlayerLimit: Int,
        rightSidePlayerLimit: Int,
        leftRequestedPlayerCount: Int,
        rightRequestedPlayerCount: Int
    ) -> Bool {
        guard leftRequestedPlayerCount > 0 || rightRequestedPlayerCount > 0 else {
            return false
        }
        if rules.usesCenterPlayerStrip {
            return true
        }
        guard size.width >= 760 else {
            return false
        }

        let leftNeedsRows = leftRequestedPlayerCount > 0
        let rightNeedsRows = rightRequestedPlayerCount > 0
        let sideLayoutMissingRows = (leftNeedsRows && leftSidePlayerLimit == 0) || (rightNeedsRows && rightSidePlayerLimit == 0)
        return sideLayoutMissingRows
    }

    private func centerPlayerDisplayLimit(for size: CGSize, condensed: Bool, ultraCondensed: Bool) -> Int {
        if ultraCondensed {
            return size.height < 600 ? 4 : 5
        }

        if condensed {
            if size.height < 640 {
                return 5
            }
            return 6
        }

        if size.height < 760 {
            return 6
        }
        return 8
    }

    private func sidePlayerDisplayLimit(for size: CGSize, condensed: Bool, ultraCondensed: Bool, hasLogo: Bool) -> Int {
        guard !rules.usesCenterPlayerStrip, size.width >= 620, size.height >= 520 else {
            return 0
        }

        if !hasLogo {
            if ultraCondensed {
                return size.height < 600 ? 4 : 5
            }

            if condensed {
                if size.height < 640 {
                    return 5
                }
                if size.height < 720 {
                    return 6
                }
                if size.height < 820 {
                    return 7
                }
                if size.height < 940 {
                    return 8
                }
                return 9
            }

            if size.height < 700 {
                return 6
            }
            if size.height < 820 {
                return 7
            }
            if size.height < 940 {
                return 8
            }
            return 10
        }

        if ultraCondensed {
            return size.height < 600 ? 2 : 3
        }

        if condensed {
            if size.height < 640 {
                return 3
            }
            if size.height < 720 {
                return 4
            }
            if size.height < 820 {
                return 5
            }
            return 6
        }

        if size.height < 700 {
            return 4
        }
        if size.height < 820 {
            return 5
        }
        return 6
    }

    private func sidePlayerViewportHeight(for size: CGSize, condensed: Bool, ultraCondensed: Bool, hasLogo: Bool) -> CGFloat {
        let base = min(size.width, size.height)
        let capacity = sidePlayerDisplayLimit(for: size, condensed: condensed, ultraCondensed: ultraCondensed, hasLogo: hasLogo)
        guard capacity > 0 else {
            return 0
        }

        let preferredHeight = playerLineupContentHeight(
            playerCount: capacity,
            base: base,
            condensed: condensed,
            ultraCondensed: ultraCondensed,
            style: .side,
            scale: 1
        )
        let maxShare = size.height * (ultraCondensed ? 0.32 : condensed ? 0.36 : 0.38)
        return min(max(preferredHeight, 44), maxShare)
    }

    private func centerPlayerViewportHeight(for size: CGSize, condensed: Bool, ultraCondensed: Bool) -> CGFloat {
        let base = min(size.width, size.height)
        let capacity = centerPlayerDisplayLimit(for: size, condensed: condensed, ultraCondensed: ultraCondensed)
        let preferredHeight = playerLineupContentHeight(
            playerCount: capacity,
            base: base,
            condensed: condensed,
            ultraCondensed: ultraCondensed,
            style: .center,
            scale: 1
        )
        let maxShare = size.height * (ultraCondensed ? 0.30 : condensed ? 0.34 : 0.36)
        return min(max(preferredHeight, 42), maxShare)
    }

    private func resolvedPlayerLineupOverflowMode(hasLogo: Bool) -> PlayerLineupOverflowMode {
        if hasLogo, let playerLineupOverflowLogoOverride {
            return playerLineupOverflowLogoOverride
        }
        if !hasLogo, let playerLineupOverflowNoLogoOverride {
            return playerLineupOverflowNoLogoOverride
        }
        return playerLineupOverflowMode
    }

    private func displayedPlayers(for side: TeamSide, limit: Int? = nil) -> [TrackedPlayer] {
        guard isPlayerTrackingEnabled, !isPlayerOverlayPaused else {
            return []
        }

        let players: [TrackedPlayer]
        switch side {
        case .home:
            players = homePlayers
        case .guest:
            players = guestPlayers
        }

        if let limit {
            return Array(players.prefix(max(0, limit)))
        }

        return players
    }

    private var foulHighlightColor: Color {
        switch playerFoulHighlightColor {
        case .red:
            return .red
        case .orange:
            return .orange
        case .yellow:
            return .yellow
        }
    }

    private func playerCardColor(_ status: PlayerCardStatus) -> Color {
        switch status {
        case .none:
            return boardPrimaryTextColor
        case .yellow:
            return .yellow
        case .red:
            return .red
        }
    }

    private func playerStatusColor(_ player: TrackedPlayer) -> Color {
        if rules.supportsCards, player.cardStatus != .none {
            return playerCardColor(player.cardStatus)
        }

        if rules.supportsFouls, player.foulCount > 0 {
            return foulHighlightColor
        }

        return boardPrimaryTextColor
    }

    private func foulDisplayText(for foulCount: Int) -> String {
        let count = max(0, foulCount)
        return count == 0 ? "-" : String(repeating: "X", count: count)
    }

    private func substitutionsAllowed(for side: TeamSide) -> Int {
        side == .home ? homeSubstitutionsAllowed : guestSubstitutionsAllowed
    }

    private func substitutionsUsed(for side: TeamSide) -> Int {
        side == .home ? homeSubstitutionsUsed : guestSubstitutionsUsed
    }

    private func teamFouls(for side: TeamSide) -> Int {
        side == .home ? homeTeamFouls : guestTeamFouls
    }

    private func debatePrepStrip(side: TeamSide, accent: Color, condensed: Bool, ultraCondensed: Bool) -> some View {
        let value: String
        let isActive: Bool
        let valueFontSize: CGFloat

        switch side {
        case .home:
            value = formattedDebatePrepHomeClock ?? "--:--"
            isActive = debateActiveTimer == .prepHome
        case .guest:
            value = formattedDebatePrepGuestClock ?? "--:--"
            isActive = debateActiveTimer == .prepGuest
        }

        if showsScore {
            valueFontSize = ultraCondensed ? 22 : condensed ? 30 : 26
        } else {
            valueFontSize = ultraCondensed ? 34 : condensed ? 48 : 40
        }

        return HStack(spacing: ultraCondensed ? 8 : 10) {
            localizedBoardText("PREP")
                .font(.system(size: ultraCondensed ? 10 : condensed ? 14 : 12, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.4)
                .foregroundStyle(boardSecondaryTextColor)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: valueFontSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .singleLineFitted(minScale: showsScore ? 0.72 : 0.82)
                .foregroundStyle(isActive ? accent : boardBadgeValueTextColor)
        }
        .padding(.horizontal, ultraCondensed ? 10 : 12)
        .padding(.vertical, ultraCondensed ? 8 : 10)
        .background(boardBadgeBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous)
                .strokeBorder(boardBadgeBorderColor)
        )
    }

    private func penaltyTimers(for side: TeamSide) -> [HockeyPenaltyTimer] {
        side == .home ? homePenaltyTimers : guestPenaltyTimers
    }

    private func sidePanelData(for side: PossessionDirection) -> SidePanelData {
        switch side {
        case .home:
            return SidePanelData(
                side: .home,
                role: sideRoleLabel(for: .home).uppercased(),
                title: homeTeamName,
                logoData: homeTeamLogoData,
                score: homeScore,
                accent: palette.homeAccent
            )
        case .guest:
            return SidePanelData(
                side: .guest,
                role: sideRoleLabel(for: .guest).uppercased(),
                title: guestTeamName,
                logoData: guestTeamLogoData,
                score: guestScore,
                accent: palette.guestAccent
            )
        case .none:
            return SidePanelData(
                side: .home,
                role: "",
                title: "",
                logoData: nil,
                score: 0,
                accent: palette.boardPrimaryText
            )
        }
    }

    private func sideRoleLabel(for side: TeamSide) -> String {
        guard sport == .debate else {
            return localizedBoardString(side.title)
        }

        switch side {
        case .home:
            return resolvedTitle(debateHomeSideLabel ?? "", placeholder: "Side A")
        case .guest:
            return resolvedTitle(debateGuestSideLabel ?? "", placeholder: "Side B")
        }
    }
}

private struct SidePanelData {
    let side: TeamSide
    let role: String
    let title: String
    let logoData: Data?
    let score: Int
    let accent: Color
}

private extension View {
    func singleLineFitted(minScale: CGFloat = 0.55) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minScale)
    }
}
