import Foundation
import Testing

extension ScoreboardTests {
    @Test("A new debate flow respects its opening side; unrelated edits preserve the live turn",
          arguments: [TeamSide.home, .guest])
    func debateSetupStartingSide(_ startingSide: TeamSide) async {
        store.setSelectedSport(.debate)
        store.newGame()
        let navigation = SetupNavigationFixture(store: store)
        navigation.loadSetupDraftsFromStore()
        await settleSetupChanges()
        navigation.showsSetup = true
        var preset = DebatePreset.customDefault
        preset.segments[0].timerMode = .dualClock
        preset.segments[0].startingSide = startingSide
        preset.segments[0].allowsSideSwitching = true
        navigation.setupCustomDebatePreset = preset
        navigation.setupDebatePresetID = DebatePreset.customID
        navigation.hasPendingSetupEdits = true
        navigation.commitSetupEdits()
        await settleSetupChanges()
        #expect(store.activeChessClockSide == startingSide)

        store.switchChessClock()
        let liveSide = store.activeChessClockSide
        #expect(liveSide != startingSide)
        navigation.eventNameDraft = "Edited title 100% %@"
        navigation.handleSetupDraftChanged()
        await settleSetupChanges()
        #expect(store.activeChessClockSide == liveSide,
                "editing an event title must not reset an operator's live turn")

        navigation.setupCustomDebatePreset.segments[0].durationSeconds += 15
        navigation.handleSetupDraftChanged()
        await settleSetupChanges()
        #expect(store.activeChessClockSide == startingSide,
                "editing the flow must apply the opening segment's configured side")
    }

    private func settleSetupChanges() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    @Test("Settings navigation preserves the live game and applies actual edits")
    func setupNavigation() async throws {
        let store = ScoreboardStore.shared
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
            let navigation = SetupNavigationFixture(store: store)
            navigation.showsSetup = false
            navigation.openSettingsFromLiveBoard()
            #expect(navigation.pendingGameConfirmation?.id == "openSettings" && !navigation.showsSetup,
                "running timers require confirmation before Settings in \(sport)")
            #expect(store.currentGameSnapshot() == originalGame && store.isAnyTimerRunning,
                "showing the warning does not stop or change timers in \(sport)")
            navigation.pendingGameConfirmation = nil
            #expect(!navigation.showsSetup && store.isAnyTimerRunning,
                "canceling the warning stays on the board with timers running")
            navigation.openSettingsFromLiveBoard()
            navigation.pendingGameConfirmation = nil
            navigation.openSettingsFromLiveBoard(confirmedRunningTimers: true)
            await settleNavigation()
            #expect(navigation.showsSetup && store.isAnyTimerRunning,
                "confirming Settings keeps timers running in \(sport)")
            navigation.openSetupGame()
            await settleNavigation()
            #expect(!navigation.showsSetup && navigation.ensureFileCalls == 0,
                "returning without edits never enters the game replacement path in \(sport)")
            #expect(store.currentGameSnapshot() == originalGame
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
        let navigation = SetupNavigationFixture(store: store)
        navigation.loadSetupDraftsFromStore()
        await settleNavigation()
        navigation.showsSetup = true
        store.period = 2
        store.possessionDirection = .guest
        navigation.openSetupGame()
        store.advanceControlTestTimers(by: 0.7)
        #expect(store.gameClockSeconds == initialMain - 1 && store.isClockRunning && store.isShotClockRunning,
            "returning to the board preserves fractional main clock time and running clocks")
        #expect(abs(store.shotClockMilliseconds - (initialShot - 1_100)) <= 1,
            "returning to the board preserves the shot countdown")
        #expect(store.period == 2 && store.possessionDirection == .guest,
            "unchanged settings do not overwrite live period and possession updates")

        store.startPause(for: .home, seconds: 30)
        store.advanceControlTestTimers(by: 0.4)
        let pauseNavigation = SetupNavigationFixture(store: store)
        pauseNavigation.loadSetupDraftsFromStore()
        pauseNavigation.showsSetup = true
        pauseNavigation.openSetupGame()
        store.advanceControlTestTimers(by: 0.7)
        #expect(store.pauseTimer?.isRunning == true && store.pauseTimer?.remainingSeconds == 29,
            "returning without edits preserves the running pause and its fractional countdown")
        store.cancelPause()
        store.startPause(seconds: 0)
        let infiniteNavigation = SetupNavigationFixture(store: store)
        infiniteNavigation.showsSetup = false
        infiniteNavigation.openSettingsFromLiveBoard()
        #expect(infiniteNavigation.showsSetup && infiniteNavigation.pendingGameConfirmation == nil,
            "an indefinite pause without a running clock opens Settings directly")
        infiniteNavigation.openSetupGame()
        #expect(store.pauseTimer != nil && store.pauseTimer?.remainingSeconds == nil,
            "unchanged Settings preserves an indefinite pause")
        store.cancelPause()

        let editedNavigation = SetupNavigationFixture(store: store)
        editedNavigation.loadSetupDraftsFromStore()
        await settleNavigation()
        editedNavigation.showsSetup = true
        editedNavigation.homeTeamDraft = "Edited Home"
        editedNavigation.handleSetupDraftChanged()
        #expect(store.homeTeamName == "EDITED HOME" && editedNavigation.ensureFileCalls == 1,
            "actual setup edits still apply immediately")
        await settleNavigation()
        editedNavigation.openSetupGame()
        #expect(editedNavigation.ensureFileCalls == 1,
            "returning after a committed edit does not load the game again")

        let newNavigation = SetupNavigationFixture(store: store)
        newNavigation.resetSetupDraftsToDefaults()
        newNavigation.openSetupGame()
        #expect(store.selectedSport == .simple && newNavigation.ensureFileCalls == 1,
            "a new-game draft still applies even when the previous game completed setup")
        await settleNavigation()
        store.didCompleteSetup = false
        let firstNavigation = SetupNavigationFixture(store: store)
        firstNavigation.loadSetupDraftsFromStore()
        firstNavigation.openSetupGame()
        #expect(store.didCompleteSetup && firstNavigation.ensureFileCalls == 1,
            "first setup still initializes the game without requiring an edit")
        await settleNavigation()

        store.withControlTestFollowingSessionHost {
            #expect(store.isFollowingSessionHost && store.isSessionOwner,
                "owner regression runs while following a delegated host")
            let ownerNavigation = SetupNavigationFixture(store: store)
            ownerNavigation.loadSetupDraftsFromStore()
            let previousStatus = store.sessionStatusMessage
            ownerNavigation.openSetupGame()
            #expect(ownerNavigation.ensureFileCalls == 0 && store.sessionStatusMessage == previousStatus,
                "unchanged owner navigation does not attempt to send a game replacement to the host")
            store.setPauseDurationSeconds(store.pauseDurationSeconds + 5)
            ownerNavigation.openSetupGame()
            #expect(ownerNavigation.ensureFileCalls == 1 && ownerNavigation.hasPendingSetupEdits,
                "actual owner setup options still forward to the host and remain pending while disconnected")
        }
    }
}
