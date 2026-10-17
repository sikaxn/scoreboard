import Foundation

@MainActor
func runSetupNavigationTests() async -> Int {
    let store = ScoreboardStore.shared
    var checks = 0
    func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message)
        checks += 1
    }
    func settleNavigation() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    for sport in SportType.allCases {
        store.setSelectedSport(sport)
        store.newGame()
        store.didCompleteSetup = true
        store.isSoundEnabled = false
        if store.usesChessClocks { store.toggleChessClock() }
        else { store.toggleClock() }
        if !store.isAnyTimerRunning { store.startPause(seconds: 30) }
        let originalGame = store.currentGameSnapshot()
        let originalRuntime = store.currentWebAPIState().runtime
        let navigation = ScoreboardSetupNavigationFixture(store: store)
        navigation.showsSetup = false
        navigation.openSettingsFromLiveBoard()
        expect(navigation.pendingGameConfirmation?.id == "openSettings" && !navigation.showsSetup,
            "running timers require confirmation before Settings in \(sport)")
        expect(store.currentGameSnapshot() == originalGame && store.isAnyTimerRunning,
            "showing the warning does not stop or change timers in \(sport)")
        navigation.pendingGameConfirmation = nil
        expect(!navigation.showsSetup && store.isAnyTimerRunning,
            "canceling the warning stays on the board with timers running")
        navigation.openSettingsFromLiveBoard()
        navigation.pendingGameConfirmation = nil
        navigation.performConfirmedGameAction(.openSettings)
        await settleNavigation()
        expect(navigation.showsSetup && store.isAnyTimerRunning,
            "confirming Settings keeps timers running in \(sport)")
        navigation.openSetupGame()
        await settleNavigation()
        expect(!navigation.showsSetup && navigation.ensureFileCalls == 0,
            "returning without edits never enters the game replacement path in \(sport)")
        expect(store.currentGameSnapshot() == originalGame
            && store.isClockRunning == originalRuntime.isClockRunning
            && store.isShotClockRunning == originalRuntime.isShotClockRunning
            && store.isDebatePrepClockRunning == originalRuntime.isDebatePrepClockRunning,
            "unchanged navigation preserves live game and timer state in \(sport)")
    }

    store.setSelectedSport(.basketball)
    store.newGame()
    store.didCompleteSetup = true
    store.toggleClock()
    store.toggleShotClock()
    let initialMain = store.gameClockSeconds
    let initialShot = store.shotClockMilliseconds
    store.advanceControlTestTimers(by: 0.4)
    let navigation = ScoreboardSetupNavigationFixture(store: store)
    navigation.loadSetupDraftsFromStore()
    await settleNavigation()
    navigation.showsSetup = true
    store.period = 2
    store.possessionDirection = .guest
    navigation.openSetupGame()
    store.advanceControlTestTimers(by: 0.7)
    expect(store.gameClockSeconds == initialMain - 1 && store.isClockRunning && store.isShotClockRunning,
        "returning to the board preserves fractional main clock time and running clocks")
    expect(abs(store.shotClockMilliseconds - (initialShot - 1_100)) <= 1,
        "returning to the board preserves the shot countdown")
    expect(store.period == 2 && store.possessionDirection == .guest,
        "unchanged settings do not overwrite live period and possession updates")

    store.startPause(for: .home, seconds: 30)
    store.advanceControlTestTimers(by: 0.4)
    let pauseNavigation = ScoreboardSetupNavigationFixture(store: store)
    pauseNavigation.loadSetupDraftsFromStore()
    pauseNavigation.showsSetup = true
    pauseNavigation.openSetupGame()
    store.advanceControlTestTimers(by: 0.7)
    expect(store.pauseTimer?.isRunning == true && store.pauseTimer?.remainingSeconds == 29,
        "returning without edits preserves the running pause and its fractional countdown")
    store.cancelPause()
    store.startPause(seconds: 0)
    let infiniteNavigation = ScoreboardSetupNavigationFixture(store: store)
    infiniteNavigation.showsSetup = false
    infiniteNavigation.openSettingsFromLiveBoard()
    expect(infiniteNavigation.showsSetup && infiniteNavigation.pendingGameConfirmation == nil,
        "an indefinite pause without a running clock opens Settings directly")
    infiniteNavigation.openSetupGame()
    expect(store.pauseTimer != nil && store.pauseTimer?.remainingSeconds == nil,
        "unchanged Settings preserves an indefinite pause")
    store.cancelPause()

    let editedNavigation = ScoreboardSetupNavigationFixture(store: store)
    editedNavigation.loadSetupDraftsFromStore()
    await settleNavigation()
    editedNavigation.showsSetup = true
    editedNavigation.homeTeamDraft = "Edited Home"
    editedNavigation.handleSetupDraftChanged()
    expect(store.homeTeamName == "EDITED HOME" && editedNavigation.ensureFileCalls == 1,
        "actual setup edits still apply immediately")
    await settleNavigation()
    editedNavigation.openSetupGame()
    expect(editedNavigation.ensureFileCalls == 1,
        "returning after a committed edit does not load the game again")

    let newNavigation = ScoreboardSetupNavigationFixture(store: store)
    newNavigation.resetSetupDraftsToDefaults()
    newNavigation.openSetupGame()
    expect(store.selectedSport == .simple && newNavigation.ensureFileCalls == 1,
        "a new-game draft still applies even when the previous game completed setup")
    await settleNavigation()
    store.didCompleteSetup = false
    let firstNavigation = ScoreboardSetupNavigationFixture(store: store)
    firstNavigation.loadSetupDraftsFromStore()
    firstNavigation.openSetupGame()
    expect(store.didCompleteSetup && firstNavigation.ensureFileCalls == 1,
        "first setup still initializes the game without requiring an edit")
    await settleNavigation()

    store.withControlTestFollowingSessionHost {
        expect(store.isFollowingSessionHost && store.isSessionOwner,
            "owner regression runs while following a delegated host")
        let ownerNavigation = ScoreboardSetupNavigationFixture(store: store)
        ownerNavigation.loadSetupDraftsFromStore()
        let previousStatus = store.sessionStatusMessage
        ownerNavigation.openSetupGame()
        expect(ownerNavigation.ensureFileCalls == 0 && store.sessionStatusMessage == previousStatus,
            "unchanged owner navigation does not attempt to send a game replacement to the host")
        store.setPauseDurationSeconds(store.pauseDurationSeconds + 5)
        ownerNavigation.openSetupGame()
        expect(ownerNavigation.ensureFileCalls == 1 && ownerNavigation.hasPendingSetupEdits,
            "actual owner setup options still forward to the host and remain pending while disconnected")
    }
    return checks
}
