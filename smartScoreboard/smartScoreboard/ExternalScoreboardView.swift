import SwiftUI

struct ExternalScoreboardView: View {
    @EnvironmentObject private var store: ScoreboardStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.12, green: 0.04, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScoreboardFaceView(
                homeTeamName: store.homeTeamName,
                guestTeamName: store.guestTeamName,
                homeScore: store.homeScore,
                guestScore: store.guestScore,
                period: store.period,
                formattedClock: store.formattedClock,
                isClockRunning: store.isClockRunning,
                compact: true
            )
            .aspectRatio(ScoreboardFaceView.preferredAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(36)
        }
    }
}
