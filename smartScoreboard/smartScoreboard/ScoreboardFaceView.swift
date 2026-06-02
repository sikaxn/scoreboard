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
    let homeTeamName: String
    let guestTeamName: String
    let homeScore: Int
    let guestScore: Int
    let period: Int
    let formattedClock: String
    let formattedShotClock: String
    let possessionDirection: PossessionDirection
    let areSidesSwapped: Bool
    let isClockRunning: Bool
    let isPlayerTrackingEnabled: Bool
    let isPlayerOverlayPaused: Bool
    let playerFoulHighlightColor: PlayerFoulHighlightColor
    let isDisplayGameClockAlertActive: Bool
    let isDisplayShotClockAlertActive: Bool
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

                HStack(spacing: columnSpacing) {
                    teamPanel(
                        role: leftTeam.role,
                        title: leftTeam.title,
                        placeholder: leftTeam.role,
                        score: leftTeam.score,
                        accent: leftTeam.accent,
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
                        role: rightTeam.role,
                        title: rightTeam.title,
                        placeholder: rightTeam.role,
                        score: rightTeam.score,
                        accent: rightTeam.accent,
                        displayedPlayers: displayedPlayers(for: rightTeam.side),
                        base: base,
                        condensed: condensed,
                        ultraCondensed: ultraCondensed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        role: String,
        title: String,
        placeholder: String,
        score: Int,
        accent: Color,
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

            Text("\(score)")
                .font(.system(size: ultraCondensed ? base * 0.22 : condensed ? base * 0.34 : base * 0.28, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.32)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.28, dampingFraction: 0.76), value: score)
                .foregroundStyle(accent)
                .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.35) : .clear, radius: 12, y: 4)
                .frame(maxWidth: .infinity)

            if !displayedPlayers.isEmpty {
                activeLineupStrip(displayedPlayers, accent: accent, base: base, condensed: condensed, ultraCondensed: ultraCondensed)
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
                            .foregroundStyle(player.foulCount > 0 ? foulHighlightColor : boardPrimaryTextColor)

                        Spacer(minLength: 0)

                        Text(foulDisplayText(for: player.foulCount))
                            .font(.system(size: ultraCondensed ? base * 0.02 : condensed ? base * 0.024 : base * 0.022, weight: .black, design: .rounded))
                            .monospaced()
                            .foregroundStyle(player.foulCount > 0 ? foulHighlightColor : boardPrimaryTextColor)
                    }
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
    }

    private func centerClockPanel(base: CGFloat, condensed: Bool, ultraCondensed: Bool) -> some View {
        VStack(spacing: ultraCondensed ? max(10, base * 0.018) : condensed ? max(18, base * 0.026) : max(20, base * 0.03)) {
            Spacer(minLength: 0)

            Text(formattedClock)
                .font(.system(size: ultraCondensed ? base * 0.15 : condensed ? base * 0.215 : base * 0.19, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .singleLineFitted(minScale: 0.24)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: formattedClock)
                .foregroundStyle(isDisplayGameClockAlertActive ? displayAlertColor : boardPrimaryTextColor)
                .shadow(color: usesTransparentBoardSurfaces ? .black.opacity(0.35) : .clear, radius: 12, y: 4)
                .frame(maxWidth: .infinity)

            VStack(spacing: ultraCondensed ? 8 : condensed ? 14 : 12) {
                shotClockBadge(
                    value: formattedShotClock,
                    condensed: condensed,
                    ultraCondensed: ultraCondensed,
                    base: base,
                    valueFontSize: ultraCondensed ? base * 0.15 : condensed ? base * 0.215 : base * 0.19,
                    valueMinScale: 0.24,
                    valueColor: isDisplayShotClockAlertActive ? displayAlertColor : boardBadgeValueTextColor
                )

                HStack(spacing: ultraCondensed ? 8 : condensed ? 14 : 12) {
                    headerBadge(title: "CLOCK", value: isClockRunning ? "RUNNING" : "STOPPED", condensed: condensed, ultraCondensed: ultraCondensed)
                    headerBadge(title: "PERIOD", value: "\(period)", condensed: condensed, ultraCondensed: ultraCondensed)
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

    private func resolvedTitle(_ title: String, placeholder: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? placeholder : trimmed
    }

    private var centerPossessionIndicator: (systemName: String, color: Color)? {
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

    private func foulDisplayText(for foulCount: Int) -> String {
        let count = max(0, foulCount)
        return count == 0 ? "-" : String(repeating: "X", count: count)
    }

    private func sidePanelData(for side: PossessionDirection) -> SidePanelData {
        switch side {
        case .home:
            return SidePanelData(
                side: .home,
                role: "HOME",
                title: homeTeamName,
                score: homeScore,
                accent: palette.homeAccent
            )
        case .guest:
            return SidePanelData(
                side: .guest,
                role: "GUEST",
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
