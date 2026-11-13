import Foundation
import Testing

extension ScoreboardTests {
    @Test("Completion locks every sport and station until undo", arguments: SportType.allCases, ScoreboardControlBoardMode.allCases)
    func gameCompletionAllModes(sport: SportType, mode: ScoreboardControlBoardMode) throws {
        store.setSelectedSport(sport)
        store.newGame()
        store.isSoundEnabled = false
        var station = ScoreboardControlBoardConfiguration()
        station.mode = mode
        // Completion is a match operation, independent of station modules or team scope.
        station.enabledModules = []
        station.teams = .guest
        var preferences = ScoreboardControlBoardPreferences()
        preferences.set(station, for: sport)
        ScoreboardPreferences.current.set(preferences.data, forKey: ScoreboardControlBoardPreferences.storageKey)
        store.homeTeamName = "HOME FINAL"
        store.guestTeamName = "GUEST FINAL"
        if store.supportsScore { store.adjustScore(isHome: true, by: 7) }
        store.toggleClock()
        if store.supportsShotClock { store.toggleShotClock() }
        let id = store.currentMatchID
        #expect(store.executeControlCommand(cmd("game.complete", text: "guestWin")).success)
        let completion = try #require(store.gameCompletion)
        #expect(completion.outcome == .guestWin, "The selected outcome is independent of the scores")
        #expect(completion.homeScore == store.homeScore && completion.guestScore == store.guestScore)
        #expect(store.isGameCompleted && store.isGameViewOnly && !store.isAnyTimerRunning)
        let frozen = store.currentGameSnapshot()
        for operation in ScoreboardControlOperation.all where operation.id != "game.undoComplete" {
            #expect(!operation.isAvailable(in: store.currentWebAPIState()))
            #expect(store.executeControlCommand(cmd(operation.id)).error == "conflict", "Locked: \(sport) / \(mode) / \(operation.id)")
        }
        // Native buttons and keyboard actions must obey the same lock as web/cloud commands.
        store.adjustScore(isHome: true, by: 1)
        store.swapSides()
        store.resetScores()
        store.toggleClock()
        store.toggleShotClock()
        store.adjustPeriod(by: 1)
        store.startPause(seconds: 30)
        store.newGame()
        store.advanceControlTestTimers(by: 30)
        #expect(store.currentGameSnapshot() == frozen && store.currentMatchID == id)
        #expect(!store.areSidesSwapped, "Completed games cannot swap sides")
        for action in ScoreboardKeyboardShortcutAction.allCases {
            #expect(action.isAvailable(store: store, isResetInterlockActive: false, isGameClockResetInterlockActive: false)
                == (action == .togglePlayersPage && store.isPlayerTrackingEnabled))
        }
        #expect(store.executeControlCommand(cmd("game.undoComplete")).success)
        #expect(!store.isGameCompleted && !store.isGameViewOnly && !store.isAnyTimerRunning)
        #expect(store.homeScore == completion.homeScore && store.guestScore == completion.guestScore)
        #expect(ScoreboardControlOperation.all.first { $0.id == "game.complete" }!.isAvailable(in: store.currentWebAPIState()))
        #expect(!ScoreboardControlOperation.all.first { $0.id == "game.undoComplete" }!.isAvailable(in: store.currentWebAPIState()))
        if store.supportsScore {
            store.adjustScore(isHome: true, by: 1)
            #expect(store.homeScore == completion.homeScore + 1)
        }
    }

    @Test("Completed games allow settings and player browsing without edits", arguments: SportType.allCases)
    func gameCompletionReadOnlyBrowsing(sport: SportType) async {
        store.setSelectedSport(sport)
        store.newGame()
        store.didCompleteSetup = true
        store.setPlayerTrackingEnabled(true)
        store.completeGame(outcome: .tie)
        let frozen = store.currentGameSnapshot()
        let navigation = SetupNavigationFixture(store: store)
        navigation.openSettingsFromLiveBoard()
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        #expect(navigation.showsSetup && navigation.pendingGameConfirmation == nil)
        navigation.homeTeamDraft = "Cannot edit a completed game"
        navigation.hasPendingSetupEdits = true
        navigation.commitSetupEdits(forceRefresh: true)
        navigation.openSetupGame()
        #expect(!navigation.showsSetup && navigation.ensureFileCalls == 0)
        #expect(store.currentGameSnapshot() == frozen && !store.isAnyTimerRunning)
        for mode in ScoreboardControlBoardMode.allCases {
            var station = ScoreboardControlBoardConfiguration()
            station.mode = mode
            station.enabledModules = []
            var playerNavigationCount = 0
            let keyboard = ScoreboardKeyboardShortcutExecutionContext(
                store: store, isResetInterlockActive: false, isGameClockResetInterlockActive: false,
                requestGameConfirmation: { _ in }, adjustDebateSegmentTimer: { _ in },
                handleDebateTurnHere: { _ in }, addPenaltyTimer: { _, _ in },
                togglePlayersPage: { playerNavigationCount += 1 }, controlBoardConfiguration: station)
            keyboard.perform(.togglePlayersPage)
            #expect(playerNavigationCount == (store.isPlayerTrackingEnabled ? 1 : 0))
            #expect(store.currentGameSnapshot() == frozen)
        }
    }

    @Test("Every outcome survives documents, backups, cloud state, and remote mirrors", arguments: ScoreboardGameOutcome.allCases)
    func gameCompletionPersistence(outcome: ScoreboardGameOutcome) throws {
        store.homeScore = 14
        store.guestScore = 9
        let command = cmd("game.complete", text: outcome.rawValue)
        #expect(store.performControlCommand(command, remote: false).success)
        let completion = try #require(store.gameCompletion)
        #expect(store.performControlCommand(command, remote: false).success)
        #expect(store.gameCompletion == completion, "Retransmission must not overwrite the final result")
        let saved = store.currentGameSnapshot()
        let decoded = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: JSONEncoder().encode(saved))
        #expect(decoded.completion == completion)
        let preferences = try store.exportPersistedStateData()
        let wire = store.currentWebAPIState().remoteDisplayPayload
        let mirror = ScoreboardStore.makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver())
        mirror.applyRemoteControlState(wire)
        #expect(mirror.gameCompletion == completion && mirror.isGameViewOnly)
        let v2 = try JSONDecoder().decode(ScoreboardWebAPIRemoteDisplayStateV2.self,
            from: JSONEncoder().encode(store.currentWebAPIState().remoteDisplayV2Payload))
        #expect(v2.v1CompatibleState.game.completion == completion)
        store.undoGameCompletion()
        store.applyGameSnapshot(decoded)
        #expect(store.gameCompletion == completion && !store.isAnyTimerRunning)
        store.undoGameCompletion()
        try store.restorePersistedStateData(preferences)
        #expect(store.gameCompletion == completion && !store.isAnyTimerRunning)
        store.undoGameCompletion()
        mirror.applyRemoteControlState(store.currentWebAPIState())
        #expect(mirror.gameCompletion == nil)
        var legacy = saved
        legacy.completion = nil
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json.removeValue(forKey: "completion")
        json["fileVersion"] = 14
        let old = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.completion == nil)
    }

    @Test("Completion stops independent penalties, prep clocks, and official pauses")
    func gameCompletionStopsAllTimers() throws {
        store.setSelectedSport(.hockey)
        store.newGame()
        store.addPenaltyTimer(for: .home, seconds: 120, player: nil, startsRunning: true)
        store.toggleClock()
        store.completeGame(outcome: .aborted)
        #expect(!store.isAnyTimerRunning && store.homePenaltyTimers[0].remainingSeconds > 0)
        store.undoGameCompletion()
        #expect(!store.homePenaltyTimers[0].isRunning)
        store.setSelectedSport(.debate)
        store.newGame()
        store.toggleDebatePrepClock(for: .home)
        store.completeGame(outcome: .tie)
        #expect(!store.isDebatePrepClockRunning && !store.isAnyTimerRunning)
        store.undoGameCompletion()
        store.startPause(seconds: 45)
        store.completeGame(outcome: .homeWin)
        #expect(store.pauseTimer == nil && !store.isAnyTimerRunning)
        store.undoGameCompletion()
        #expect(store.pauseTimer == nil && !store.isAnyTimerRunning)
    }

    @Test("Completion validates outcomes and uses period totals for period-win games")
    func gameCompletionValidationAndPeriodScores() throws {
        #expect(store.executeControlCommand(cmd("game.complete")).error == "invalidCommand")
        #expect(store.executeControlCommand(cmd("game.complete", text: "invalid")).error == "invalidCommand")
        #expect(!store.isGameCompleted)
        store.setSelectedSport(.volleyball)
        store.newGame()
        store.homeScore = 25
        store.guestScore = 20
        store.awardPeriod(to: .home)
        store.completeGame(outcome: .homeWin)
        #expect(store.gameCompletion?.scoreLine == "1 – 0")
        store.undoGameCompletion()
        store.newGame()
        store.isGameClockEnabled = false
        store.homeScore = 12
        store.guestScore = 9
        store.completeGame(outcome: .aborted)
        #expect(store.isGameCompleted && !store.showsGameClock)
        #expect(store.gameCompletion?.scoreLine == "12 – 9", "Before any recorded period win, retain the actual point score")
    }

    @Test("Completion supports custom clock combinations and every debate segment timer mode")
    func gameCompletionCustomAndDebateConfigurations() throws {
        for clockMode in MainClockMode.allCases {
            for dualClocks in [false, true] {
                var config = CustomSportConfig.default
                config.mainClockMode = clockMode
                config.usesChessClocks = dualClocks
                config.isScoreEnabled = !dualClocks
                config.isShotClockEnabled = true
                config.isPeriodWinTrackingEnabled = clockMode == .countUp
                var snapshot = ScoreboardGameSnapshot.empty
                snapshot.sport = .custom
                snapshot.customSportConfig = config
                store.applyGameSnapshot(snapshot)
                store.newGame()
                store.toggleClock()
                store.toggleShotClock()
                store.completeGame(outcome: .guestWin)
                #expect(store.isGameCompleted && !store.isAnyTimerRunning)
                let frozen = store.currentGameSnapshot()
                store.toggleClock()
                store.advanceControlTestTimers(by: 10)
                #expect(store.currentGameSnapshot() == frozen)
                store.undoGameCompletion()
                #expect(!store.isGameCompleted && !store.isAnyTimerRunning)
            }
        }
        store.setSelectedSport(.debate)
        for mode in DebateTimerMode.allCases {
            var preset = DebatePreset.customDefault
            preset.segments = [preset.segments[0]]
            preset.segments[0].timerMode = mode
            store.updateCustomDebatePreset(preset)
            store.applyDebatePreset(id: DebatePreset.customID)
            store.newGame()
            store.toggleClock()
            store.completeGame(outcome: .tie)
            #expect(store.isGameCompleted && !store.isAnyTimerRunning)
            store.undoGameCompletion()
            #expect(!store.isGameCompleted && !store.isAnyTimerRunning)
        }
    }

    @Test("Remote view-only boards retain the board, kiosk uses fullscreen, and unauthorized undo stays blocked")
    func gameCompletionViewOnlyRemote() throws {
        store.setPlayerTrackingEnabled(true)
        let receiver = ScoreboardRemoteDisplayReceiver()
        let publicState = store.currentRemoteDisplayState(forDisplayID: "test-mac")
        receiver.configureControlTestConnection(state: publicState)
        let mirror = ScoreboardStore.makeRemoteControlStore(receiver: receiver)
        #expect(receiver.presentsControlBoard && !receiver.canSendControlCommand)
        #expect(mirror.homeRoster.players.map(\.id) == publicState.players.homeDisplayed.map(\.id))
        #expect(mirror.isGameViewOnly && !mirror.canControlGame)
        let packets = ScoreboardControlTestTransport.packets.count
        let before = mirror.currentGameSnapshot()
        mirror.adjustScore(isHome: true, by: 1)
        mirror.completeGame(outcome: .homeWin)
        #expect(mirror.currentGameSnapshot() == before)
        #expect(ScoreboardControlTestTransport.packets.count == packets)
        store.completeGame(outcome: .tie)
        mirror.applyRemoteControlState(store.currentWebAPIState())
        #expect(mirror.isGameCompleted && mirror.isGameViewOnly && !mirror.canControlGame)
        mirror.undoGameCompletion()
        #expect(mirror.isGameCompleted && ScoreboardControlTestTransport.packets.count == packets)
        let previous = ScoreboardPreferences.current.string(forKey: ScoreboardDeviceMode.preferenceKey)
        defer { ScoreboardPreferences.current.set(previous, forKey: ScoreboardDeviceMode.preferenceKey) }
        ScoreboardPreferences.current.set("kiosk", forKey: ScoreboardDeviceMode.preferenceKey)
        #expect(!receiver.presentsControlBoard, "Kiosk always uses the fullscreen scoreboard")
    }

    @Test("LAN, paired controllers and cloud share the completion lock and authenticated undo")
    func gameCompletionAcrossTransports() async throws {
        store.isWebControlEnabled = true
        store.isWebAPIEnabled = true
        store.setRemoteDisplayHostEnabled(true)
        store.setRemoteControlAllowed(displayID: "test-mac", isAllowed: true)
        defer { store.setWebAPIEnabled(false); store.setRemoteDisplayHostEnabled(false) }
        for _ in 0..<100 {
            if store.webAPIStatus.isRunning { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let port = try #require({ () -> UInt16? in
            guard case .running(let port, _, _) = store.webAPIStatus else { return nil }
            return port
        }())
        func post(_ command: ScoreboardControlCommand) async throws -> Int {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/v2/control")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(store.webControlAPIKey, forHTTPHeaderField: "X-API-Key")
            request.httpBody = try JSONEncoder().encode(command)
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as! HTTPURLResponse).statusCode
        }
        let complete = cmd("game.complete", text: "homeWin")
        #expect(store.performCloudControlCommand(complete).success)
        #expect(try await post(complete) == 200, "A transport retry is deduplicated")
        #expect(try await post(cmd("score.adjust", side: .home, value: 1)) == 409)
        #expect(store.performCloudControlCommand(cmd("clock.running", enabled: true)).error == "conflict")
        #expect(store.currentWebAPIState().cloudControlPayload(allowed: false).game.completion == store.gameCompletion)
        #expect(store.currentRemoteDisplayState(forDisplayID: "test-mac").game.completion == store.gameCompletion)
        #expect(try await post(cmd("game.undoComplete")) == 200)
        #expect(!store.isGameCompleted && !store.isAnyTimerRunning)
        #expect(try await post(cmd("score.adjust", side: .home, value: 1)) == 200)
    }
}
