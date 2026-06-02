import SwiftUI

struct ScoreboardFaceView: View {
    static let preferredAspectRatio: CGFloat = 16.0 / 9.0

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
    private var shouldShowSubstitutionTracking: Bool { homeSubstitutionsAllowed > 0 || guestSubstitutionsAllowed > 0 || rules.showsSubstitutionTracking }
    private var shouldShowSoccerCenterPlayers: Bool { rules.usesCenterPlayerStrip && (!displayedPlayers(for: .home).isEmpty || !displayedPlayers(for: .guest).isEmpty) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)
            let condensed = compact || size.width < 960 || size.height < 560
            let ultraCondensed = size.width < 760 || size.height < 430
            let outerPadding = ultraCondensed ? max(12, base * 0.04) : condensed ? max(18, base * 0.055) : max(24, base * 0.07)
            let columnSpacing = ultraCondensed ? max(10, size.width * 0.012) : condensed ? max(18, size.width * 0.018) : max(24, size.width * 0.024)
            let centerWidth = min(
                max(size.width * (condensed ? 0.32 : 0.3), ultraCondensed ? 180 : condensed ? 220 : 260),
                size.width * (ultraCondensed ? 0.42 : 0.38)
            )
            let leftTeam = areSidesSwapped ? sidePanelData(for: .guest) : sidePanelData(for: .home)
            let rightTeam = areSidesSwapped ? sidePanelData(for: .home) : sidePanelData(for: .guest)

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
                                score: leftTeam.score,
                                accent: leftTeam.accent,
                                substitutionsUsed: substitutionsUsed(for: leftTeam.side),
                                substitutionsAllowed: substitutionsAllowed(for: leftTeam.side),
                                teamFouls: teamFouls(for: leftTeam.side),
                                penaltyTimers: penaltyTimers(for: leftTeam.side),
                                displayedPlayers: displayedPlayers(for: leftTeam.side),
                                base: base,
                                condensed: condensed,
                                ultraCondensed: ultraCondensed
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            centerClockPanel(base: base, condensed: condensed, ultraCondensed: ultraCondensed)
                                .frame(width: centerWidth)
                                .frame(maxHeight: .infinity)

                            teamPanel(
                                side: rightTeam.side,
                                role: rightTeam.role,
                                title: rightTeam.title,
                                placeholder: rightTeam.role,
                                score: rightTeam.score,
                                accent: rightTeam.accent,
                                substitutionsUsed: substitutionsUsed(for: rightTeam.side),
                                substitutionsAllowed: substitutionsAllowed(for: rightTeam.side),
                                teamFouls: teamFouls(for: rightTeam.side),
                                penaltyTimers: penaltyTimers(for: rightTeam.side),
                                displayedPlayers: displayedPlayers(for: rightTeam.side),
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
        score: Int,
        accent: Color,
        substitutionsUsed: Int,
        substitutionsAllowed: Int,
        teamFouls: Int,
        penaltyTimers: [HockeyPenaltyTimer],
        displayedPlayers: [TrackedPlayer],
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool
    ) -> some View {
        VStack(spacing: ultraCondensed ? max(10, base * 0.02) : condensed ? max(18, base * 0.03) : max(22, base * 0.035)) {
            VStack(spacing: ultraCondensed ? 6 : condensed ? 10 : 12) {
                Text(role)
                    .font(.system(size: ultraCondensed ? base * 0.026 : condensed ? base * 0.032 : base * 0.028, weight: .black, design: .rounded))
                    .tracking(ultraCondensed ? 1.5 : condensed ? 3 : 2)
                    .singleLineFitted(minScale: 0.8)
                    .foregroundStyle(boardSecondaryTextColor)

                Text(resolvedTitle(title, placeholder: placeholder))
                    .font(.system(size: ultraCondensed ? base * 0.044 : condensed ? base * 0.06 : base * 0.054, weight: .black, design: .rounded))
                    .singleLineFitted(minScale: 0.35)
                    .foregroundStyle(boardPrimaryTextColor)

                Capsule()
                    .fill(accent)
                    .frame(width: ultraCondensed ? base * 0.22 : condensed ? base * 0.3 : base * 0.24, height: ultraCondensed ? 5 : condensed ? 10 : 8)
            }

            Spacer(minLength: 0)

            if showsScore {
                Text("\(score)")
                    .font(.system(size: ultraCondensed ? base * 0.22 : condensed ? base * 0.34 : base * 0.28, weight: .black, design: .rounded))
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

            if !rules.usesCenterPlayerStrip && !displayedPlayers.isEmpty {
                activeLineupStrip(displayedPlayers, accent: accent, base: base, condensed: condensed, ultraCondensed: ultraCondensed)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(ultraCondensed ? 14 : condensed ? 28 : 24)
        .background(boardPanelBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 20 : condensed ? 34 : 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 20 : condensed ? 34 : 28, style: .continuous)
                .strokeBorder(boardPanelBorderColor)
        )
        .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.30) : .clear, radius: 18, y: 8)
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
        ultraCondensed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: ultraCondensed ? 6 : 8) {
            Text("PLAYERS")
                .font(.system(size: ultraCondensed ? 10 : condensed ? 14 : 12, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.4)
                .foregroundStyle(boardSecondaryTextColor)

            VStack(spacing: ultraCondensed ? 4 : 6) {
                ForEach(players) { player in
                    HStack(spacing: 8) {
                        Text("#\(player.number.isEmpty ? "--" : player.number)")
                            .font(.system(size: ultraCondensed ? base * 0.022 : condensed ? base * 0.027 : base * 0.024, weight: .black, design: .rounded))
                            .foregroundStyle(accent)
                            .frame(width: ultraCondensed ? 34 : 44, alignment: .leading)

                        Text(player.name.isEmpty ? "PLAYER" : player.name)
                            .font(.system(size: ultraCondensed ? base * 0.021 : condensed ? base * 0.026 : base * 0.023, weight: .bold, design: .rounded))
                            .singleLineFitted(minScale: 0.55)
                            .foregroundStyle(playerStatusColor(player))

                        Spacer(minLength: 0)

                        if rules.supportsFouls {
                            Text(foulDisplayText(for: player.foulCount))
                                .font(.system(size: ultraCondensed ? base * 0.02 : condensed ? base * 0.024 : base * 0.022, weight: .black, design: .rounded))
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
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: players)
    }

    private func centerClockPanel(base: CGFloat, condensed: Bool, ultraCondensed: Bool) -> some View {
        VStack(spacing: ultraCondensed ? max(10, base * 0.018) : condensed ? max(18, base * 0.026) : max(20, base * 0.03)) {
            Spacer(minLength: 0)

            if showsDualClocks {
                HStack(spacing: ultraCondensed ? 8 : condensed ? 12 : 14) {
                    headerBadge(
                        title: (sport == .debate ? sideRoleLabel(for: .home) : resolvedTitle(homeTeamName, placeholder: "HOME")).uppercased(),
                        value: formattedHomeChessClock,
                        condensed: condensed,
                        ultraCondensed: ultraCondensed,
                        valueFontSize: ultraCondensed ? base * 0.065 : condensed ? base * 0.085 : base * 0.078,
                        valueMinScale: 0.42,
                        valueColor: activeChessClockSide == .home ? palette.homeAccent : boardBadgeValueTextColor
                    )

                    headerBadge(
                        title: (sport == .debate ? sideRoleLabel(for: .guest) : resolvedTitle(guestTeamName, placeholder: "GUEST")).uppercased(),
                        value: formattedGuestChessClock,
                        condensed: condensed,
                        ultraCondensed: ultraCondensed,
                        valueFontSize: ultraCondensed ? base * 0.065 : condensed ? base * 0.085 : base * 0.078,
                        valueMinScale: 0.42,
                        valueColor: activeChessClockSide == .guest ? palette.guestAccent : boardBadgeValueTextColor
                    )
                }
                .id("public-dual-\(debateSegmentTitle ?? "")")
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if showsGameClock {
                Text(formattedClock)
                    .font(.system(size: ultraCondensed ? base * 0.15 : condensed ? base * 0.215 : base * 0.19, weight: .heavy, design: .rounded))
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

            VStack(spacing: ultraCondensed ? 8 : condensed ? 14 : 12) {
                if sport == .debate,
                   let debateSegmentTitle,
                   !debateSegmentTitle.isEmpty {
                    headerBadge(title: "SEGMENT", value: debateSegmentTitle.uppercased(), condensed: condensed, ultraCondensed: ultraCondensed)
                        .id("public-segment-\(debateSegmentTitle)")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if rules.supportsShotClock {
                    shotClockBadge(
                        value: formattedShotClock,
                        condensed: condensed,
                        ultraCondensed: ultraCondensed,
                        base: base,
                        valueFontSize: ultraCondensed ? base * 0.15 : condensed ? base * 0.215 : base * 0.19,
                        valueMinScale: 0.24,
                        valueColor: isDisplayShotClockAlertActive ? displayAlertColor : boardBadgeValueTextColor
                    )
                }

                HStack(spacing: ultraCondensed ? 8 : condensed ? 14 : 12) {
                    if showsDualClocks {
                        headerBadge(title: "TURN", value: activeChessClockSide.map { sideRoleLabel(for: $0).uppercased() } ?? "NONE", condensed: condensed, ultraCondensed: ultraCondensed)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else if showsGameClock {
                        headerBadge(title: "CLOCK", value: isClockRunning ? "RUNNING" : "STOPPED", condensed: condensed, ultraCondensed: ultraCondensed)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if rules.supportsPeriod {
                        headerBadge(title: rules.periodTitle.uppercased(), value: "\(period)", condensed: condensed, ultraCondensed: ultraCondensed)
                    }
                }

                if shouldShowSoccerCenterPlayers {
                    soccerCenterPlayerStrip(base: base, condensed: condensed, ultraCondensed: ultraCondensed)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

            }

            Spacer(minLength: 0)
        }
        .padding(ultraCondensed ? 14 : condensed ? 28 : 24)
        .background(boardClockPanelBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 22 : condensed ? 38 : 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 22 : condensed ? 38 : 30, style: .continuous)
                .strokeBorder(boardPanelBorderColor)
        )
        .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.34) : .clear, radius: 18, y: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: isPlayerOverlayPaused)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: debateSegmentTitle)
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
        let arrowFontSize = ultraCondensed ? base * 0.072 : condensed ? base * 0.102 : base * 0.088
        let arrowSlotWidth = ultraCondensed ? base * 0.1 : condensed ? base * 0.14 : base * 0.12
        let arrowIndicator = centerPossessionIndicator
        let showsLeftArrow = arrowIndicator?.systemName.contains("left") == true
        let showsRightArrow = arrowIndicator?.systemName.contains("right") == true

        return HStack(spacing: ultraCondensed ? 8 : condensed ? 14 : 12) {
            shotArrowSlot(
                systemName: arrowIndicator?.systemName,
                color: arrowIndicator?.color,
                isVisible: showsLeftArrow,
                fontSize: arrowFontSize,
                slotWidth: arrowSlotWidth
            )

            headerBadge(
                title: "SHOT",
                value: value,
                condensed: condensed,
                ultraCondensed: ultraCondensed,
                valueFontSize: valueFontSize,
                valueMinScale: valueMinScale,
                valueColor: valueColor,
                showsContainer: false
            )
            .frame(maxWidth: .infinity)

            shotArrowSlot(
                systemName: arrowIndicator?.systemName,
                color: arrowIndicator?.color,
                isVisible: showsRightArrow,
                fontSize: arrowFontSize,
                slotWidth: arrowSlotWidth
            )
        }
        .padding(.horizontal, ultraCondensed ? 10 : condensed ? 22 : 18)
        .padding(.vertical, ultraCondensed ? 8 : condensed ? 16 : 14)
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

            Text(isActive ? "ACTIVE" : "WAITING")
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
            Text(title)
                .font(.system(size: ultraCondensed ? 10 : condensed ? 16 : 14, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.5)
                .singleLineFitted(minScale: 0.75)
                .foregroundStyle(boardBadgeTitleTextColor)

            Text(value)
                .font(.system(size: valueFontSize ?? (ultraCondensed ? 18 : condensed ? 34 : 28), weight: .heavy, design: .rounded))
                .monospacedDigit()
                .singleLineFitted(minScale: valueMinScale)
                .foregroundStyle(valueColor ?? boardBadgeValueTextColor)
        }
        .padding(.horizontal, ultraCondensed ? 10 : condensed ? 22 : 18)
        .padding(.vertical, ultraCondensed ? 8 : condensed ? 16 : 14)
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
            Text("SWAPS")
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
            Text("FOULS")
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
            Text("PENALTIES")
                .font(.system(size: ultraCondensed ? 10 : condensed ? 14 : 12, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.4)
                .foregroundStyle(boardSecondaryTextColor)

            ForEach(visibleTimers) { timer in
                HStack(spacing: 8) {
                    Text(timer.playerNumber.isEmpty ? "#" : "#\(timer.playerNumber)")
                        .font(.system(size: ultraCondensed ? base * 0.018 : base * 0.02, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                    Text(timer.playerName.isEmpty ? "PLAYER" : timer.playerName)
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
                Text("+\(overflow) more")
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

    private func soccerCenterPlayerStrip(base: CGFloat, condensed: Bool, ultraCondensed: Bool) -> some View {
        HStack(alignment: .top, spacing: ultraCondensed ? 10 : condensed ? 14 : 16) {
            soccerPlayerColumn(
                title: "\(sideRoleLabel(for: .home).uppercased()) PLAYERS",
                players: displayedPlayers(for: .home),
                accent: palette.homeAccent,
                base: base,
                condensed: condensed,
                ultraCondensed: ultraCondensed
            )

            soccerPlayerColumn(
                title: "\(sideRoleLabel(for: .guest).uppercased()) PLAYERS",
                players: displayedPlayers(for: .guest),
                accent: palette.guestAccent,
                base: base,
                condensed: condensed,
                ultraCondensed: ultraCondensed
            )
        }
        .padding(.horizontal, ultraCondensed ? 10 : 12)
        .padding(.vertical, ultraCondensed ? 8 : 10)
        .background(boardBadgeBackgroundColor, in: RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 14 : 18, style: .continuous)
                .strokeBorder(boardBadgeBorderColor)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: displayedPlayers(for: .home))
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: displayedPlayers(for: .guest))
    }

    private func soccerPlayerColumn(
        title: String,
        players: [TrackedPlayer],
        accent: Color,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: ultraCondensed ? 4 : 6) {
            Text(title)
                .font(.system(size: ultraCondensed ? 9 : condensed ? 12 : 11, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.2)
                .foregroundStyle(boardSecondaryTextColor)

            ForEach(players) { player in
                HStack(spacing: 6) {
                    Text("#\(player.number.isEmpty ? "--" : player.number)")
                        .font(.system(size: ultraCondensed ? base * 0.016 : condensed ? base * 0.019 : base * 0.017, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(accent)
                        .frame(width: ultraCondensed ? 40 : condensed ? 48 : 44, alignment: .leading)

                    Text(player.name.isEmpty ? "PLAYER" : player.name)
                        .font(.system(size: ultraCondensed ? base * 0.015 : condensed ? base * 0.018 : base * 0.016, weight: .bold, design: .rounded))
                        .singleLineFitted(minScale: 0.55)
                        .foregroundStyle(playerStatusColor(player))
                }
                .scaleEffect(player.cardStatus != .none || player.foulCount > 0 ? 1.02 : 1)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: player.cardStatus)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: player.foulCount)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: players)
    }

    private func resolvedTitle(_ title: String, placeholder: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? placeholder : trimmed
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

    private func displayedPlayers(for side: TeamSide) -> [TrackedPlayer] {
        guard isPlayerTrackingEnabled, !isPlayerOverlayPaused else {
            return []
        }

        switch side {
        case .home:
            return homePlayers
        case .guest:
            return guestPlayers
        }
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
            Text("PREP")
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
                score: homeScore,
                accent: palette.homeAccent
            )
        case .guest:
            return SidePanelData(
                side: .guest,
                role: sideRoleLabel(for: .guest).uppercased(),
                title: guestTeamName,
                score: guestScore,
                accent: palette.guestAccent
            )
        case .none:
            return SidePanelData(
                side: .home,
                role: "",
                title: "",
                score: 0,
                accent: palette.boardPrimaryText
            )
        }
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
}

private struct SidePanelData {
    let side: TeamSide
    let role: String
    let title: String
    let score: Int
    let accent: Color
}

private extension View {
    func singleLineFitted(minScale: CGFloat = 0.55) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minScale)
    }
}
