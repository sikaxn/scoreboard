import SwiftUI

struct ScoreboardFaceView: View {
    static let preferredAspectRatio: CGFloat = 2.18

    let homeTeamName: String
    let guestTeamName: String
    let homeScore: Int
    let guestScore: Int
    let period: Int
    let formattedClock: String
    let isClockRunning: Bool
    let compact: Bool

    var body: some View {
        GeometryReader { proxy in
            let base = min(proxy.size.width, proxy.size.height)
            let shellPadding = compact ? max(16, base * 0.09) : max(20, base * 0.11)
            let shellCornerRadius = compact ? max(24, base * 0.14) : max(30, base * 0.17)
            let clockSize = compact ? base * 0.18 : base * 0.22
            let labelSize = compact ? base * 0.07 : base * 0.08
            let scoreSize = compact ? base * 0.2 : base * 0.24
            let spacing = base * 0.06
            let centerWidth = min(
                max(proxy.size.width * (compact ? 0.36 : 0.34), compact ? 220 : 280),
                proxy.size.width * 0.46
            )
            let sideWidth = max((proxy.size.width - centerWidth - (spacing * 2)) / 2, 0)
            let shell = RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)

            ZStack {
                shell
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.12, blue: 0.14),
                                Color(red: 0.04, green: 0.04, blue: 0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                HStack(spacing: spacing) {
                    teamColumn(
                        title: homeTeamName,
                        score: homeScore,
                        accent: Color(red: 0.97, green: 0.38, blue: 0.28),
                        labelSize: labelSize,
                        scoreSize: scoreSize
                    )
                    .frame(width: sideWidth)

                    VStack(spacing: base * 0.04) {
                        Text(formattedClock)
                            .font(.system(size: clockSize, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .singleLineFitted(minScale: 0.25)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)

                        ViewThatFits {
                            HStack(spacing: 12) {
                                statBadge(title: "PERIOD", value: "\(period)")
                                statBadge(title: "STATUS", value: isClockRunning ? "LIVE" : "STOP")
                            }

                            VStack(spacing: 10) {
                                statBadge(title: "PERIOD", value: "\(period)")
                                statBadge(title: "STATUS", value: isClockRunning ? "LIVE" : "STOP")
                            }
                        }
                    }
                    .frame(width: centerWidth)
                    .layoutPriority(2)

                    teamColumn(
                        title: guestTeamName,
                        score: guestScore,
                        accent: Color(red: 0.22, green: 0.68, blue: 0.95),
                        labelSize: labelSize,
                        scoreSize: scoreSize
                    )
                    .frame(width: sideWidth)
                }
                .padding(shellPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(shell)
            .overlay(
                shell
                    .strokeBorder(.white.opacity(0.08))
            )
        }
    }

    private func teamColumn(
        title: String,
        score: Int,
        accent: Color,
        labelSize: CGFloat,
        scoreSize: CGFloat
    ) -> some View {
        VStack(spacing: 14) {
            Text(title.isEmpty ? " " : title)
                .font(.system(size: labelSize, weight: .heavy, design: .rounded))
                .singleLineFitted(minScale: 0.35)
                .foregroundStyle(.white.opacity(0.9))

            Text("\(score)")
                .font(.system(size: scoreSize, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.4)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
    }

    private func statBadge(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(.white.opacity(0.58))

            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .singleLineFitted(minScale: 0.6)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension View {
    func singleLineFitted(minScale: CGFloat = 0.55) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minScale)
    }
}
