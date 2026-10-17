import Foundation
import Testing

extension ScoreboardTests {
    @Test("Score corrections stop at zero and leave the other team unchanged", arguments: [TeamSide.home, .guest])
    func scoreCorrections(side: TeamSide) {
        let isHome = side == .home
        store.adjustScore(isHome: isHome, by: 3)
        store.adjustScore(isHome: isHome, by: -1)
        #expect(store.homeScore == (isHome ? 2 : 0))
        #expect(store.guestScore == (isHome ? 0 : 2))
        store.adjustScore(isHome: isHome, by: -10)
        #expect(store.homeScore == 0 && store.guestScore == 0)
    }

    @Test("A new game clears scores, fouls, pause usage, and running clocks")
    func newGameClearsMatchState() {
        store.adjustScore(isHome: true, by: 3)
        store.adjustScore(isHome: false, by: 2)
        store.adjustTeamFouls(for: .home, by: 1)
        store.startPause(for: .home, seconds: 30)
        store.newGame()
        #expect(store.homeScore == 0 && store.guestScore == 0)
        #expect(store.homeTeamFouls == 0 && store.guestTeamFouls == 0)
        #expect(store.homePausesUsed == 0 && store.guestPausesUsed == 0)
        #expect(store.pauseTimer == nil && !store.isAnyTimerRunning)
        #expect(store.period == 1)
    }

    @Test("Game clock retains fractional time and stops at zero")
    func gameClockFractionsAndExpiry() {
        store.resetClock(to: 2)
        store.toggleClock()
        store.advanceControlTestTimers(by: 0.4)
        #expect(store.gameClockSeconds == 2)
        store.advanceControlTestTimers(by: 0.7)
        #expect(store.gameClockSeconds == 1 && store.isClockRunning)
        store.advanceControlTestTimers(by: 10)
        #expect(store.gameClockSeconds == 0 && !store.isClockRunning)
    }

    @Test("Unit test storage and preferences are isolated from the app")
    func storageIsolation() throws {
        #expect(ScoreboardPreferences.current !== UserDefaults.standard)
        let directory = try ScoreboardFileStorage.storedGamesDirectory()
        #expect(directory.path.hasPrefix(ScoreboardTestEnvironment.root.path + "/"))
        #expect(ScoreboardSessionRecovery.url.path.hasPrefix(ScoreboardTestEnvironment.root.path + "/"))
    }
}
