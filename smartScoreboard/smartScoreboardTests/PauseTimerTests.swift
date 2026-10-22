import Foundation
import Combine
import Testing

extension ScoreboardTests {
    @Test("Sixty-minute pause limit survives saved games and backup restore")
    func sixtyMinutePauseLimit() throws {
        store.resetClock(to: 600)
        store.toggleClock()
        #expect(store.executeControlCommand(cmd("pause.official", value: 3600)).success)
        #expect(store.pauseTimer?.remainingSeconds == 3600 && !store.isClockRunning)
        #expect(store.pauseTimer?.formattedTime == "60:00")
        let snapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self,
            from: JSONEncoder().encode(store.currentGameSnapshot()))
        let backup = try store.exportPersistedStateData()
        store.cancelPause()
        store.applyGameSnapshot(snapshot)
        #expect(store.pauseTimer?.remainingSeconds == 3600 && store.pauseTimer?.isRunning == false)
        store.cancelPause()
        try store.restorePersistedStateData(backup)
        #expect(store.pauseTimer?.remainingSeconds == 3600 && store.pauseTimer?.isRunning == false)
        store.cancelPause()
        #expect(store.executeControlCommand(cmd("pause.official", value: 3601)).error == "invalidCommand")
        store.startPause(seconds: 3601)
        #expect(store.pauseTimer == nil)
        #expect(store.executeControlCommand(cmd("pause.start", side: .home, value: 3600)).success)
        store.cancelPause()
        store.startPause(seconds: 60)
        #expect(store.pauseTimer?.remainingSeconds == 60)
        store.advanceControlTestTimers(by: 60.1)
        #expect(store.pauseTimer?.remainingSeconds == 0 && store.pauseTimer?.isRunning == false)
        #expect(!store.isClockRunning)
    }

    @Test("Pause usage counts and keyboard controls")
    func pauseKeyboardControls() throws {
        // Count changes and starting a timer are separate operator actions.
        store.setSelectedSport(.basketball)
        store.newGame()
        store.isSoundEnabled = false
        let keyboard = ScoreboardKeyboardShortcutExecutionContext(
            store: store, isResetInterlockActive: false, isGameClockResetInterlockActive: false,
            requestGameConfirmation: { _ in }, adjustDebateSegmentTimer: { _ in },
            handleDebateTurnHere: { _ in }, addPenaltyTimer: { _, _ in }, togglePlayersPage: {})
        #expect(store.executeControlCommand(cmd("pause.adjust", side: .home, value: 1)).success,
            "API can add a pause count without a timer")
        #expect(store.homePausesUsed == 1 && store.pauseTimer == nil, "count-only action leaves pause timer absent")
        store.toggleClock()
        keyboard.perform(.guestPausePlus)
        #expect(store.guestPausesUsed == 1 && store.pauseTimer == nil && store.isClockRunning,
            "count shortcut does not stop game clock or start a pause")
        keyboard.perform(.startGuestPause)
        #expect(store.pauseTimer?.side == .guest && store.guestPausesUsed == 2 && !store.isClockRunning,
            "separate start shortcut starts and counts a team pause")
        let runningPause = store.pauseTimer
        keyboard.perform(.homePausePlus)
        #expect(store.homePausesUsed == 2 && store.pauseTimer == runningPause,
            "count shortcut remains available while another team's timer runs")
        keyboard.perform(.homePauseMinus)
        #expect(store.homePausesUsed == 1 && store.pauseTimer == runningPause,
            "count decrement does not alter the running timer")
        let scoreBefore = store.homeScore
        keyboard.perform(.homeScorePrimary)
        #expect(store.homeScore == scoreBefore + 1, "inline pause controls leave scoring shortcuts available")
        #expect(!ScoreboardKeyboardShortcutAction.togglePrimaryTimer.isAvailable(store: store,
            isResetInterlockActive: false, isGameClockResetInterlockActive: false),
            "play timer cannot restart during a pause")
        keyboard.perform(.togglePauseTimer)
        #expect(store.pauseTimer?.isRunning == false, "pause shortcut stops the countdown")
        keyboard.perform(.togglePauseTimer)
        #expect(store.pauseTimer?.isRunning == true, "pause shortcut continues the countdown")
        keyboard.perform(.cancelPause)
        #expect(store.pauseTimer == nil && !store.isClockRunning, "cancel shortcut dismisses pause without restarting play")
    }

    @Test("Official pause capabilities in every sport", arguments: SportType.allCases)
    func officialPauseCapabilities(sport: SportType) throws {
        let pauseEvents: Set<ScoreboardSoundEvent> = [.pauseStarted, .officialPauseStarted,
            .pauseTimerPaused, .pauseTimerResumed, .pauseEnded, .pauseExpired]
        store.setSelectedSport(sport)
        store.newGame()
        store.isSoundEnabled = false
        #expect(pauseEvents.isSubset(of: Set(store.assignableSoundEventsForCurrentSport)), "pause sound/Companion events available for \(sport)")
        #expect(store.executeControlCommand(cmd("pause.official", value: 0)).success, "official pause supports \(sport)")
        #expect(store.pauseTimer?.side == nil && store.pauseTimer?.remainingSeconds == nil, "official pause is indefinite")
        #expect(store.pauseTimer?.formattedTime.isEmpty == true, "indefinite pause has no clock value")
        #expect(store.homePausesUsed == 0 && store.guestPausesUsed == 0, "official pause does not consume allowance")
        #expect(!store.isClockRunning && !store.isShotClockRunning && !store.isDebatePrepClockRunning, "pause stops play timers")
        #expect(store.executeControlCommand(cmd("pause.running", enabled: true)).error == "conflict", "indefinite pause has no countdown")
        #expect(store.executeControlCommand(cmd("pause.cancel")).success && store.pauseTimer == nil, "official pause cancels")
        if !store.supportsPauseTracking {
            #expect(store.executeControlCommand(cmd("pause.start", side: .home, value: 30)).error == "unsupported", "team pauses respect sport capabilities")
        }
    }

    @Test("Team pause allowances, countdown, retry, and expiry")
    func teamPauseLifecycle() throws {
        store.setSelectedSport(.basketball)
        store.newGame()
        store.isSoundEnabled = false
        store.setPauseDurationSeconds(45)
        store.updateTeamName("Visitors", isHome: false)
        store.startPause(for: .guest)
        #expect(store.pauseTimer?.remainingSeconds == 45 && store.guestPausesUsed == 1, "team pause uses configured duration and one allowance")
        #expect(store.pauseTitle == store.pauseTimer?.title(homeTeamName: store.homeTeamName, guestTeamName: "VISITORS"), "pause uses current team name")
        let duplicate = store.executeControlCommand(cmd("pause.start", side: .home, value: 30))
        #expect(duplicate.error == "conflict" && store.homePausesUsed == 0, "overlapping pause rejected without charging allowance")
        #expect(store.executeControlCommand(cmd("clock.running", enabled: true)).error == "conflict", "API cannot restart play during pause")
        #expect(store.executeControlCommand(cmd("shot.running", enabled: true)).error == "conflict", "API cannot restart shot timer during pause")
        store.toggleClock(); store.toggleShotClock()
        #expect(!store.isClockRunning && !store.isShotClockRunning, "local timer entry points respect pause")
        store.advanceControlTestTimers(by: 1.25)
        #expect(store.pauseTimer?.remainingSeconds == 44, "pause advances with wall-clock elapsed time")
        store.setPauseTimerRunning(false)
        store.advanceControlTestTimers(by: 9)
        #expect(store.pauseTimer?.remainingSeconds == 44, "suspended countdown stays fixed")
        store.setPauseTimerRunning(true)
        store.advanceControlTestTimers(by: 0.8)
        #expect(store.pauseTimer?.remainingSeconds == 43, "resume preserves fractional countdown time")
        store.cancelPause()
        #expect(store.guestPausesUsed == 1 && !store.isClockRunning && !store.isShotClockRunning, "cancel retains allowance and leaves play stopped")
        store.setPausesAllowed(for: .home, to: 0)
        #expect(store.executeControlCommand(cmd("pause.start", side: .home, value: 30)).error == "conflict", "exhausted allowances rejected")
        store.setPausesAllowed(for: .home, to: 2)
        #expect(store.executeControlCommand(cmd("pause.start", side: .home, value: 0)).success, "API supports indefinite team pauses")
        #expect(store.pauseTimer?.side == .home && store.pauseTimer?.remainingSeconds == nil && store.homePausesUsed == 1,
            "indefinite team pause consumes one allowance without a countdown")
        store.cancelPause()
        store.adjustPausesUsed(for: .home, by: -1)
        #expect(store.executeControlCommand(cmd("pause.official", value: -1)).error == "invalidCommand", "negative duration rejected")
        #expect(store.executeControlCommand(cmd("pause.official", value: 3601)).error == "invalidCommand", "over sixty minutes rejected")
        #expect(store.executeControlCommand(cmd("pause.start", value: 30)).error == "invalidCommand", "team side required")
        let start = cmd("pause.start", side: .home, value: 2)
        #expect(store.performControlCommand(start, remote: false).success, "pause starts through shared deduplicating command path")
        #expect(store.performControlCommand(start, remote: false).success && store.homePausesUsed == 1, "retry consumes allowance only once")
        store.advanceControlTestTimers(by: 2.1)
        #expect(store.pauseTimer?.remainingSeconds == 0 && store.pauseTimer?.isRunning == false, "expiry retains zero overlay")
        let logCount = ScoreboardLogManager.shared.currentSessionSnapshot()!.entries.count
        store.advanceControlTestTimers(by: 10)
        #expect(ScoreboardLogManager.shared.currentSessionSnapshot()!.entries.count == logCount, "expiry event recorded only once")
        #expect(store.executeControlCommand(cmd("pause.running", enabled: true)).error == "conflict", "expired countdown cannot resume")
        #expect(!store.isClockRunning && !store.isShotClockRunning, "expiry leaves play stopped")
        store.cancelPause()
        store.adjustPausesUsed(for: .home, by: -1)
        #expect(store.pauseTimer == nil, "usage corrections do not start overlay")
    }

    @Test("Pause delay compensation, remote projection, and saved games")
    func pauseCompensationAndPersistence() throws {
        // A delayed pause tap freezes every play timer at tap time, then advances only the pause.
        store.setSelectedSport(.hockey)
        store.newGame()
        store.isSoundEnabled = false
        store.resetClock(to: 60)
        store.toggleClock()
        store.addPenaltyTimer(for: .home, seconds: 120, player: nil, startsRunning: true)
        store.addPenaltyTimer(for: .home, seconds: 60, player: nil, startsRunning: true)
        store.advanceControlTestTimers(by: 1.25)
        #expect(store.executeControlCommand(cmd("pause.official", value: 30, delay: 1.25), remote: true).success, "delayed pause starts")
        #expect(store.gameClockSeconds == 60 && !store.isClockRunning, "pause compensates stopped game clock to tap time")
        #expect(store.homePenaltyTimers.map(\.remainingSeconds) == [120, 60] && !store.homePenaltyTimers.contains(where: \.isRunning), "pause freezes all penalties at tap time")
        #expect(store.pauseTimer?.remainingSeconds == 29, "pause countdown compensates travel time")
        let beforeUnrelated = store.pauseTimer
        #expect(store.executeControlCommand(cmd("score.adjust", side: .home, value: 1, delay: 1.25), remote: true).success, "unrelated delayed command applies")
        #expect(store.pauseTimer == beforeUnrelated, "unrelated command does not double-advance pause")
        #expect(store.executeControlCommand(cmd("pause.running", enabled: false, delay: 1.25), remote: true).success, "delayed countdown pause applies")
        #expect(store.pauseTimer?.remainingSeconds == 30 && store.pauseTimer?.isRunning == false, "countdown freezes at remote tap time")
        var stale = cmd("pause.running", enabled: true, delay: 0.1)
        stale.expectedRunning = true
        #expect(store.executeControlCommand(stale, remote: true).error == "conflict", "stale remote countdown state rejected")
        store.setPauseTimerRunning(true)
        let snapshot = store.currentGameSnapshot()
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: encoded)
        #expect(decoded.pauseTimer == snapshot.pauseTimer && decoded.pauseDurationSeconds == snapshot.pauseDurationSeconds, "saved game pause fields round trip")
        let state = store.currentWebAPIState()
        #expect(state.clocks.pauseTimer == store.pauseTimer && state.clocks.pauseTitle == store.pauseTitle, "API clocks expose timer and label")
        let wire = try JSONDecoder().decode(ScoreboardWebAPIRemoteDisplayStateV2.self, from: JSONEncoder().encode(state.remoteDisplayV2Payload))
        #expect(wire.v1CompatibleState.clocks.pauseTimer == store.pauseTimer, "v2 paired display preserves pause")
        let projection = RemoteScoreboardProjection(state: state, lastReceivedAt: Date(), masterClockOffset: 0,
            now: Date(timeIntervalSince1970: state.generatedAtUnixTime! + 2.1))
        #expect(projection.pauseTimer?.remainingSeconds == 28, "remote display projects countdown")
        var routed: [ScoreboardControlCommand] = []
        let mirror = ScoreboardStore.makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver(), sendCommand: { routed.append($0) })
        mirror.applyRemoteControlState(state)
        #expect(mirror.pauseTimer == store.pauseTimer, "remote control board receives pause")
        var changes = 0
        let subscription = mirror.objectWillChange.sink { changes += 1 }
        mirror.applyRemoteControlState(state)
        #expect(changes == 0, "unchanged pause frames do not redraw control board")
        subscription.cancel()
        mirror.setPauseTimerRunning(false); mirror.cancelPause(); mirror.startPause(seconds: 0)
        #expect(routed.map(\.action) == ["pause.running", "pause.cancel", "pause.official"], "remote pause actions route to authority")
        store.setCompanionLocationText("1/2/3", for: .pauseExpired)
        store.setSoundEffect(.whistle, for: .pauseStarted)
        let backup = try store.exportPersistedStateData()
        store.cancelPause()
        try store.restorePersistedStateData(backup)
        #expect(store.pauseTimer?.isRunning == false && store.pauseTimer?.remainingSeconds == 30, "backup restore retains pause with countdown stopped")
        #expect(store.companionLocationText(for: .pauseExpired) == "1/2/3" && store.selectedSoundEffect(for: .pauseStarted) == .whistle,
            "pause Companion and sound assignments survive backup")
        store.applyGameSnapshot(snapshot)
        #expect(store.pauseTimer?.isRunning == false, "opening a game stops saved pause countdown")
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        legacy.removeValue(forKey: "pauseTimer"); legacy.removeValue(forKey: "pauseDurationSeconds"); legacy.removeValue(forKey: "isTeamPauseIndefinite")
        let legacySnapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
        store.applyGameSnapshot(legacySnapshot)
        #expect(store.pauseTimer == nil && store.pauseDurationSeconds == 60 && !store.isTeamPauseIndefinite, "older game files load with finite pause defaults")
        store.startPause(seconds: 0)
        store.newGame()
        #expect(store.pauseTimer == nil && store.homePausesUsed == 0 && store.guestPausesUsed == 0, "new game clears pause state and allowances")
        store.startPause(seconds: 0)
        store.setSelectedSport(.volleyball)
        #expect(store.pauseTimer == nil && store.pauseDurationSeconds == 30, "sport change clears overlay and selects default duration")
        store.setSelectedSport(.basketball)
        store.newGame()
        store.resetClock(to: 60); store.resetShotClock(to: 24)
        store.toggleClock(); store.toggleShotClock()
        store.advanceControlTestTimers(by: 1.25)
        #expect(store.executeControlCommand(cmd("pause.official", value: 30, delay: 1.25), remote: true).success, "delayed pause stops shot and game clocks")
        #expect(store.gameClockSeconds == 60 && (23990...24000).contains(store.shotClockMilliseconds), "game and shot clocks freeze together at tap time")
        store.cancelPause()
        store.setSelectedSport(.debate)
        store.newGame()
        store.setDebatePrepTimeEnabled(true)
        store.toggleDebatePrepClock(for: .home)
        store.startPause(seconds: 0)
        #expect(!store.isDebatePrepClockRunning && !store.isClockRunning, "official pause stops debate prep")
        store.cancelPause()
    }

    @Test("Finite and indefinite team pause configuration and persistence")
    func indefiniteTeamPauses() throws {
        let keyboard = ScoreboardKeyboardShortcutExecutionContext(
            store: store, isResetInterlockActive: false, isGameClockResetInterlockActive: false,
            requestGameConfirmation: { _ in }, adjustDebateSegmentTimer: { _ in },
            handleDebateTurnHere: { _ in }, addPenaltyTimer: { _, _ in }, togglePlayersPage: {})
        store.setSelectedSport(.custom)
        store.customSportConfig.isPauseTrackingEnabled = true
        store.setPausesAllowed(for: .guest, to: 1)
        #expect(store.executeControlCommand(cmd("pause.start", side: .guest, value: 15)).success, "custom team pauses enabled by module")
        store.cancelPause()
        store.setPausesAllowed(for: .guest, to: 3)
        store.setPauseDurationSeconds(45)
        store.setTeamPauseIndefinite(true)
        keyboard.perform(.startGuestPause)
        #expect(store.pauseTimer?.remainingSeconds == 45 && store.guestPausesUsed == 2,
            "normal start keeps the saved duration when infinite pauses are offered")
        store.cancelPause()
        store.adjustPausesUsed(for: .guest, by: -1)
        store.startPause(for: .guest, seconds: 0)
        #expect(store.pauseTimer?.remainingSeconds == nil && store.pauseTimer?.side == .guest && store.guestPausesUsed == 2,
            "separate infinite start creates an indefinite pause and counts it")
        #expect(store.pauseTimer?.isRunning == false && store.pauseTimer?.formattedTime.isEmpty == true,
            "indefinite team pause has no running clock or clock text")
        let indefinitePause = store.pauseTimer
        store.advanceControlTestTimers(by: 300)
        #expect(store.pauseTimer == indefinitePause, "indefinite team pause does not expire")
        let infiniteState = store.currentWebAPIState()
        #expect(infiniteState.clocks.isTeamPauseIndefinite == true && infiniteState.clocks.pauseDurationSeconds == 45,
            "API advertises indefinite team setting and finite fallback duration")
        let infiniteSnapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self,
            from: JSONEncoder().encode(store.currentGameSnapshot()))
        #expect(infiniteSnapshot.isTeamPauseIndefinite == true && infiniteSnapshot.pauseTimer?.remainingSeconds == nil,
            "indefinite team setup and active timer survive game encoding")
        let infiniteBackup = try store.exportPersistedStateData()
        store.cancelPause(); store.setTeamPauseIndefinite(false)
        try store.restorePersistedStateData(infiniteBackup)
        #expect(store.isTeamPauseIndefinite && store.pauseTimer?.remainingSeconds == nil && store.pauseTimer?.side == .guest,
            "backup restores indefinite team setup and pause")
        store.cancelPause(); store.setTeamPauseIndefinite(false)
        store.applyGameSnapshot(infiniteSnapshot)
        #expect(store.isTeamPauseIndefinite && store.pauseTimer?.remainingSeconds == nil,
            "opening a saved match preserves its indefinite team pause")
        let indefiniteMirror = ScoreboardStore.makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver())
        indefiniteMirror.applyRemoteControlState(infiniteState)
        #expect(indefiniteMirror.isTeamPauseIndefinite && indefiniteMirror.pauseTimer?.remainingSeconds == nil,
            "remote board receives indefinite team setup and pause")
        let indefiniteProjection = RemoteScoreboardProjection(state: infiniteState, lastReceivedAt: Date(), masterClockOffset: 0,
            now: Date(timeIntervalSince1970: infiniteState.generatedAtUnixTime! + 120))
        #expect(indefiniteProjection.pauseTimer == infiniteState.clocks.pauseTimer,
            "remote projection keeps indefinite team pauses timeless")
        store.cancelPause()
        store.startPause()
        #expect(store.pauseTimer?.side == nil && store.pauseTimer?.remainingSeconds == 45,
            "timed official pause still uses configured duration when teams are indefinite")
        store.cancelPause(); store.setTeamPauseIndefinite(false)
        store.startPause(for: .guest)
        #expect(store.pauseTimer?.remainingSeconds == 45, "disabling indefinite team pauses restores default countdown")
        store.cancelPause()
    }

    @Test("Pause ended actions fire once and choose the correct logo")
    func pauseEndedEffectsAndLogos() throws {
        store.setSelectedSport(.basketball)
        store.newGame()
        store.isCompanionVisible = true
        store.isCompanionEnabled = true
        store.companionSyncWithSound = true
        store.setCompanionLocationText("1/2/3", for: .pauseEnded)
        store.setSoundEffect(.whistle, for: .pauseEnded)
        for side: TeamSide? in [.home, .guest, nil] {
            store.isSoundEnabled = false
            store.startPause(for: side, seconds: 0)
            let idleEffects = store.captureControlTestEventActions { store.advanceControlTestTimers(by: 300) }
            #expect(idleEffects.isEmpty, "infinite pause emits no expiration effects")
            store.isSoundEnabled = true
            let stopEffects = store.captureControlTestEventActions { store.cancelPause() }
            #expect(stopEffects.count == 1 && stopEffects.first?.event == .pauseEnded,
                "stopping an infinite team or official pause emits Pause Ended once")
            #expect(stopEffects.first?.effect == .whistle && stopEffects.first?.location == "1/2/3",
                "infinite pause stop queues the assigned sound and Companion command")
            #expect(store.pauseTimer == nil && !store.isClockRunning && !store.isShotClockRunning,
                "infinite pause stop clears the pause and leaves play stopped")
            let repeatedEffects = store.captureControlTestEventActions { store.cancelPause() }
            #expect(repeatedEffects.isEmpty, "repeated stop does not repeat sound or Companion")
        }
        store.isSoundEnabled = false
        store.startPause(seconds: 0)
        let silentStopEffects = store.captureControlTestEventActions { store.cancelPause() }
        #expect(silentStopEffects.count == 1 && silentStopEffects.first?.effect == ScoreboardSoundEffect.none
            && silentStopEffects.first?.location == "1/2/3", "infinite pause stop keeps Companion when sound is disabled")
        store.isCompanionEnabled = false
        store.isCompanionVisible = false
        store.companionSyncWithSound = false
        store.setCompanionLocationText("", for: .pauseEnded)
        store.setSoundEffect(.none, for: .pauseEnded)
        let homeLogo = Data([1]), guestLogo = Data([2]), eventLogo = Data([3])
        let teamNotice = ScoreboardPauseTimer(side: .guest, remainingSeconds: nil, isRunning: false)
        #expect(teamNotice.logoData(homeTeamLogoData: homeLogo, guestTeamLogoData: guestLogo, eventLogoData: eventLogo) == guestLogo,
            "team pause selects that team's logo")
        #expect(teamNotice.logoData(homeTeamLogoData: homeLogo, guestTeamLogoData: nil, eventLogoData: eventLogo) == eventLogo,
            "team pause falls back to event logo")
        let officialNotice = ScoreboardPauseTimer(side: nil, remainingSeconds: nil, isRunning: false)
        #expect(officialNotice.logoData(homeTeamLogoData: homeLogo, guestTeamLogoData: guestLogo, eventLogoData: eventLogo) == eventLogo,
            "official pause selects event logo")
        #expect(officialNotice.logoData(homeTeamLogoData: homeLogo, guestTeamLogoData: guestLogo, eventLogoData: nil) == nil,
            "official pause without event logo remains text-only")
    }

}
