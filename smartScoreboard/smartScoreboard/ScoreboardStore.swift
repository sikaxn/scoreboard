import Combine
import Foundation

@MainActor
final class ScoreboardStore: NSObject, ObservableObject {
    static let shared = ScoreboardStore()

    @Published var homeTeamName = ""
    @Published var guestTeamName = ""
    @Published var homeScore = 0
    @Published var guestScore = 0
    @Published var period = 1
    @Published var gameClockSeconds = 12 * 60
    @Published var isClockRunning = false

    private var timer: Timer?

    private override init() {
        super.init()
    }

    var formattedClock: String {
        let minutes = gameClockSeconds / 60
        let seconds = gameClockSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func updateTeamName(_ name: String, isHome: Bool) {
        let resolvedName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if isHome {
            homeTeamName = resolvedName
        } else {
            guestTeamName = resolvedName
        }
    }

    func adjustScore(isHome: Bool, by delta: Int) {
        if isHome {
            homeScore = max(0, homeScore + delta)
        } else {
            guestScore = max(0, guestScore + delta)
        }
    }

    func adjustPeriod(by delta: Int) {
        period = max(1, min(9, period + delta))
    }

    func setPeriod(_ value: Int) {
        period = max(1, min(9, value))
    }

    func adjustClock(by delta: Int) {
        gameClockSeconds = max(0, min(59 * 60 + 59, gameClockSeconds + delta))
        if gameClockSeconds == 0 {
            pauseClock()
        }
    }

    func resetClock(to seconds: Int = 12 * 60) {
        pauseClock()
        gameClockSeconds = seconds
    }

    func toggleClock() {
        isClockRunning ? pauseClock() : startClock()
    }

    func newGame() {
        pauseClock()
        homeScore = 0
        guestScore = 0
        period = 1
        gameClockSeconds = 12 * 60
    }

    func applySetup(homeName: String, guestName: String, period: Int, clockSeconds: Int) {
        updateTeamName(homeName, isHome: true)
        updateTeamName(guestName, isHome: false)
        homeScore = 0
        guestScore = 0
        setPeriod(period)
        resetClock(to: clockSeconds)
    }

    private func startClock() {
        if gameClockSeconds == 0 {
            gameClockSeconds = 12 * 60
        }

        isClockRunning = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(handleTimerTick),
            userInfo: nil,
            repeats: true
        )
    }

    private func pauseClock() {
        isClockRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isClockRunning else {
            return
        }

        guard gameClockSeconds > 0 else {
            pauseClock()
            return
        }

        gameClockSeconds -= 1

        if gameClockSeconds == 0 {
            pauseClock()
        }
    }

    @objc private func handleTimerTick() {
        tick()
    }
}

@MainActor
final class ExternalDisplayState: ObservableObject {
    static let shared = ExternalDisplayState()

    @Published var isConnected = false

    private init() {}
}
