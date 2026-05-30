import SwiftUI

struct ScoreboardFaceView: View {
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
            let clockSize = compact ? base * 0.18 : base * 0.22
            let labelSize = compact ? base * 0.07 : base * 0.08
            let scoreSize = compact ? base * 0.2 : base * 0.24

            HStack(spacing: base * 0.06) {
                teamColumn(
                    title: homeTeamName,
                    score: homeScore,
                    accent: Color(red: 0.97, green: 0.38, blue: 0.28),
                    labelSize: labelSize,
                    scoreSize: scoreSize
                )

                VStack(spacing: base * 0.04) {
                    Text(formattedClock)
                        .font(.system(size: clockSize, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        statBadge(title: "PERIOD", value: "\(period)")
                        statBadge(title: "STATUS", value: isClockRunning ? "LIVE" : "STOP")
                    }
                }
                .frame(maxWidth: .infinity)

                teamColumn(
                    title: guestTeamName,
                    score: guestScore,
                    accent: Color(red: 0.22, green: 0.68, blue: 0.95),
                    labelSize: labelSize,
                    scoreSize: scoreSize
                )
            }
            .padding(compact ? 22 : 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: compact ? 28 : 36, style: .continuous)
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 28 : 36, style: .continuous)
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
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(.white.opacity(0.9))

            Text("\(score)")
                .font(.system(size: scoreSize, weight: .black, design: .rounded))
                .minimumScaleFactor(0.6)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
    }

    private func statBadge(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
