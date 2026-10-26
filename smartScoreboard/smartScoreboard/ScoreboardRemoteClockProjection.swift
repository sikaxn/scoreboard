import Foundation

struct RemoteScoreboardProjection {
    let state: ScoreboardWebAPIState
    let elapsedSeconds: TimeInterval

    init(
        state: ScoreboardWebAPIState,
        lastReceivedAt: Date?,
        masterClockOffset: TimeInterval?,
        now: Date
    ) {
        self.state = state
        if
            let generatedAtUnixTime = state.generatedAtUnixTime,
            let masterClockOffset
        {
            let estimatedMasterNow = now.timeIntervalSince1970 + masterClockOffset
            elapsedSeconds = max(0, estimatedMasterNow - generatedAtUnixTime)
        } else {
            elapsedSeconds = max(0, now.timeIntervalSince(lastReceivedAt ?? now))
        }
    }

    var gameClockSeconds: Int {
        guard
            state.clocks.showsGameClock,
            state.runtime.isClockRunning,
            !state.rules.usesChessClocks
        else {
            return state.clocks.gameClockSeconds
        }

        let wholeSeconds = elapsedWholeSeconds
        switch state.clocks.gameClockMode {
        case .countdown:
            return max(0, state.clocks.gameClockSeconds - wholeSeconds)
        case .countUp:
            return min(ScoreboardStore.maxGameClockSeconds, state.clocks.gameClockSeconds + wholeSeconds)
        }
    }

    var formattedGameClock: String {
        ScoreboardStore.formatGameClock(gameClockSeconds)
    }

    var shotClockMilliseconds: Int {
        guard state.runtime.isShotClockRunning, state.rules.supportsShotClock else {
            return state.clocks.shotClockMilliseconds
        }

        return max(0, state.clocks.shotClockMilliseconds - elapsedMilliseconds)
    }

    var formattedShotClock: String {
        ScoreboardStore.formatShotClock(milliseconds: shotClockMilliseconds)
    }

    var homeChessClockSeconds: Int {
        projectedChessClockSeconds(for: .home)
    }

    var formattedHomeChessClock: String {
        ScoreboardStore.formatGameClock(homeChessClockSeconds)
    }

    var guestChessClockSeconds: Int {
        projectedChessClockSeconds(for: .guest)
    }

    var formattedGuestChessClock: String {
        ScoreboardStore.formatGameClock(guestChessClockSeconds)
    }

    var formattedDebatePrepHomeClock: String? {
        guard state.debate != nil else {
            return nil
        }
        return ScoreboardStore.formatGameClock(projectedDebatePrepSeconds(for: .home))
    }

    var formattedDebatePrepGuestClock: String? {
        guard state.debate != nil else {
            return nil
        }
        return ScoreboardStore.formatGameClock(projectedDebatePrepSeconds(for: .guest))
    }

    var pauseTimer: ScoreboardPauseTimer? {
        guard var pause = state.clocks.pauseTimer ?? state.game.pauseTimer else { return nil }
        if pause.isRunning, let seconds = pause.remainingSeconds {
            pause.remainingSeconds = max(0, seconds - elapsedWholeSeconds)
            if pause.remainingSeconds == 0 { pause.isRunning = false }
        }
        return pause
    }

    var homePenaltyTimers: [HockeyPenaltyTimer] {
        projectedPenaltyTimers(state.game.homePenaltyTimers ?? [])
    }

    var guestPenaltyTimers: [HockeyPenaltyTimer] {
        projectedPenaltyTimers(state.game.guestPenaltyTimers ?? [])
    }

    var isClockRunning: Bool {
        guard state.runtime.isClockRunning else {
            return false
        }

        if state.rules.usesChessClocks {
            switch state.clocks.activeChessClockSide {
            case .home:
                return homeChessClockSeconds > 0
            case .guest:
                return guestChessClockSeconds > 0
            case .none:
                return false
            }
        }

        guard state.clocks.showsGameClock else {
            return false
        }

        switch state.clocks.gameClockMode {
        case .countdown:
            return gameClockSeconds > 0
        case .countUp:
            return gameClockSeconds < ScoreboardStore.maxGameClockSeconds
        }
    }

    private var elapsedWholeSeconds: Int {
        Int(elapsedSeconds)
    }

    private var elapsedMilliseconds: Int {
        Int(elapsedSeconds * 1_000)
    }

    private func projectedChessClockSeconds(for side: TeamSide) -> Int {
        let sourceSeconds = side == .home ? state.clocks.homeChessClockSeconds : state.clocks.guestChessClockSeconds
        guard
            state.rules.usesChessClocks,
            state.runtime.isClockRunning,
            state.clocks.activeChessClockSide == side
        else {
            return sourceSeconds
        }

        return max(0, sourceSeconds - elapsedWholeSeconds)
    }

    func projectedDebatePrepSeconds(for side: TeamSide) -> Int {
        guard let debate = state.debate else {
            return 0
        }

        let sourceSeconds = side == .home ? debate.prepHomeSeconds : debate.prepGuestSeconds
        guard
            debate.prepTimeEnabled,
            state.runtime.isDebatePrepClockRunning,
            debate.activeTimer == (side == .home ? .prepHome : .prepGuest)
        else {
            return sourceSeconds
        }

        return max(0, sourceSeconds - elapsedWholeSeconds)
    }

    private func projectedPenaltyTimers(_ timers: [HockeyPenaltyTimer]) -> [HockeyPenaltyTimer] {
        guard elapsedWholeSeconds > 0 else {
            return timers
        }

        return timers.map { timer in
            guard timer.isRunning else {
                return timer
            }

            var projectedTimer = timer
            projectedTimer.remainingSeconds = max(0, timer.remainingSeconds - elapsedWholeSeconds)
            if projectedTimer.remainingSeconds == 0 {
                projectedTimer.isRunning = false
            }
            return projectedTimer
        }
    }
}

