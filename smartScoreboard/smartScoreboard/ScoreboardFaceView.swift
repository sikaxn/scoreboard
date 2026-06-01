import SwiftUI

struct ScoreboardFaceView: View {
    static let preferredAspectRatio: CGFloat = 16.0 / 9.0

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
    let compact: Bool

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
                        possessionArrowSystemName: "arrowtriangle.right.fill",
                        showsPossession: leftTeam.showsPossession,
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
                        possessionArrowSystemName: "arrowtriangle.left.fill",
                        showsPossession: rightTeam.showsPossession,
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
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.05),
                    Color(red: 0.04, green: 0.04, blue: 0.07),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.05),
                            .clear,
                            .clear,
                            .white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private func teamPanel(
        role: String,
        title: String,
        placeholder: String,
        score: Int,
        accent: Color,
        possessionArrowSystemName: String,
        showsPossession: Bool,
        base: CGFloat,
        condensed: Bool,
        ultraCondensed: Bool
    ) -> some View {
        VStack(spacing: ultraCondensed ? max(10, base * 0.02) : condensed ? max(18, base * 0.03) : max(22, base * 0.035)) {
            VStack(spacing: ultraCondensed ? 6 : condensed ? 10 : 12) {
                HStack(spacing: 8) {
                    Text(role)
                        .font(.system(size: ultraCondensed ? base * 0.026 : condensed ? base * 0.032 : base * 0.028, weight: .black, design: .rounded))
                        .tracking(ultraCondensed ? 1.5 : condensed ? 3 : 2)
                        .singleLineFitted(minScale: 0.8)
                        .foregroundStyle(.white.opacity(0.42))

                    if showsPossession {
                        Image(systemName: possessionArrowSystemName)
                            .font(.system(size: ultraCondensed ? base * 0.022 : condensed ? base * 0.026 : base * 0.022, weight: .black))
                            .foregroundStyle(accent)
                    }
                }

                Text(resolvedTitle(title, placeholder: placeholder))
                    .font(.system(size: ultraCondensed ? base * 0.044 : condensed ? base * 0.06 : base * 0.054, weight: .black, design: .rounded))
                    .singleLineFitted(minScale: 0.35)
                    .foregroundStyle(.white)

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
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(ultraCondensed ? 14 : condensed ? 28 : 24)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: ultraCondensed ? 20 : condensed ? 34 : 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 20 : condensed ? 34 : 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            VStack(spacing: ultraCondensed ? 8 : condensed ? 14 : 12) {
                headerBadge(title: "CLOCK", value: isClockRunning ? "RUNNING" : "STOPPED", condensed: condensed, ultraCondensed: ultraCondensed)
                headerBadge(title: "SHOT", value: formattedShotClock, condensed: condensed, ultraCondensed: ultraCondensed)
                headerBadge(title: "PERIOD", value: "\(period)", condensed: condensed, ultraCondensed: ultraCondensed)
            }

            Spacer(minLength: 0)
        }
        .padding(ultraCondensed ? 14 : condensed ? 28 : 24)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: ultraCondensed ? 22 : condensed ? 38 : 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 22 : condensed ? 38 : 30, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private func headerBadge(title: String, value: String, condensed: Bool, ultraCondensed: Bool) -> some View {
        VStack(spacing: ultraCondensed ? 3 : 6) {
            Text(title)
                .font(.system(size: ultraCondensed ? 10 : condensed ? 16 : 14, weight: .black, design: .rounded))
                .tracking(ultraCondensed ? 0.8 : 1.5)
                .singleLineFitted(minScale: 0.75)
                .foregroundStyle(.white.opacity(0.46))

            Text(value)
                .font(.system(size: ultraCondensed ? 18 : condensed ? 34 : 28, weight: .heavy, design: .rounded))
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, ultraCondensed ? 10 : condensed ? 22 : 18)
        .padding(.vertical, ultraCondensed ? 8 : condensed ? 16 : 14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: ultraCondensed ? 12 : condensed ? 22 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ultraCondensed ? 12 : condensed ? 22 : 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private func resolvedTitle(_ title: String, placeholder: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? placeholder : trimmed
    }

    private func sidePanelData(for side: PossessionDirection) -> SidePanelData {
        switch side {
        case .home:
            return SidePanelData(
                role: "HOME",
                title: homeTeamName,
                score: homeScore,
                accent: Color(red: 0.97, green: 0.38, blue: 0.28),
                showsPossession: possessionDirection == .home
            )
        case .guest:
            return SidePanelData(
                role: "GUEST",
                title: guestTeamName,
                score: guestScore,
                accent: Color(red: 0.22, green: 0.68, blue: 0.95),
                showsPossession: possessionDirection == .guest
            )
        case .none:
            return SidePanelData(
                role: "",
                title: "",
                score: 0,
                accent: .white,
                showsPossession: false
            )
        }
    }
}

private struct SidePanelData {
    let role: String
    let title: String
    let score: Int
    let accent: Color
    let showsPossession: Bool
}

private extension View {
    func singleLineFitted(minScale: CGFloat = 0.55) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minScale)
    }
}
