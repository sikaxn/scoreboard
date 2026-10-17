import Foundation
import Combine
@main struct ControlTests {
    @MainActor static func main() async {
        let peers = [
            ScoreboardRemoteDisplayTrustedPeer(id: "test-mac", name: "Control Mac", deviceType: .mac, pairingSecret: "test-secret-a"),
            ScoreboardRemoteDisplayTrustedPeer(id: "test-ipad", name: "Display iPad", deviceType: .ipad, pairingSecret: "test-secret-b"),
            ScoreboardRemoteDisplayTrustedPeer(id: "test-tv", name: "Apple TV", deviceType: .appleTV, pairingSecret: "test-secret-c")
        ]
        UserDefaults.standard.setVolatileDomain([
            "scoreboard.webControlEnabled": false, "scoreboard.remoteControlAllowedDisplayIDs": [String](),
            "com.ironmaple.smartscoreboard.remoteDisplayTrustedDisplays": try! JSONEncoder().encode(peers),
            "smartScoreboard.persistedState": Data(), "scoreboard.webControlAPIKey": "0123456789ABCDEF"
        ], forName: UserDefaults.argumentDomain)
        let store = ScoreboardStore.shared
        store.isSoundEnabled = false
        store.isCompanionEnabled = false
        store.isRemoteDisplayHostEnabled = false
        store.isWebAPIEnabled = false
        var checks = 0
        func expect(_ value: @autoclosure () -> Bool, _ message: String) {
            precondition(value(), message); checks += 1
        }
        func cmd(_ action: String, side: TeamSide? = nil, value: Int? = nil, text: String? = nil,
                 enabled: Bool? = nil, playerID: UUID? = nil, timerID: UUID? = nil, delay: Double? = nil) -> ScoreboardControlCommand {
            ScoreboardControlCommand(action: action, sport: store.selectedSport, side: side, value: value,
                                     text: text, enabled: enabled, playerID: playerID, timerID: timerID,
                                     sentAt: delay.map { Date().timeIntervalSince1970 - $0 })
        }
        checks += try! runPauseTimerTests()
        for sport in SportType.allCases {
            store.setSelectedSport(sport)
            store.newGame()
            store.isSoundEnabled = false
            let state = store.currentWebAPIState()
            expect(state.rules.sport == sport, "sport state")
            let available = ScoreboardControlOperation.all.filter { $0.isAvailable(in: state) }
            expect(!available.isEmpty, "catalog for \(sport)")
            let sportMirror = ScoreboardStore.makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver())
            sportMirror.applyRemoteControlState(state)
            var repeatedPublications = 0
            let repeatedToken = sportMirror.objectWillChange.sink { repeatedPublications += 1 }
            for _ in 0..<20 { sportMirror.applyRemoteControlState(state) }
            expect(repeatedPublications == 0, "unchanged frames do not redraw \(sport) board")
            repeatedToken.cancel()
            for operation in ScoreboardControlOperation.all where !operation.isAvailable(in: state) {
                let result = store.executeControlCommand(cmd(operation.id))
                expect(result.error == "unsupported", "capability gate \(sport) \(operation.id)")
            }
            if store.supportsScore {
                let before = store.homeScore
                let result = store.executeControlCommand(cmd("score.adjust", side: .home, value: 1))
                expect(result.success && store.homeScore == before + 1, "score \(sport)")
            }
            expect(store.executeControlCommand(cmd("display.mode", text: "blackScreen")).success, "display \(sport)")
            expect(store.publicDisplayViewMode == .blackScreen, "display applied")
            expect(store.executeControlCommand(cmd("unknown")).error == "invalidCommand", "unknown command")
            expect(store.executeControlCommand(cmd("display.mode", text: "invalid")).error == "invalidCommand", "invalid enum")
        }
        store.setSelectedSport(.basketball)
        store.newGame()
        store.isSoundEnabled = false
        store.setPlayerTrackingEnabled(true)
        let player = store.homeRoster.players[0]
        expect(store.executeControlCommand(cmd("player.name", side: .home, text: "Remote Player", playerID: player.id)).success, "edit player")
        expect(store.homeRoster.players[0].name == "REMOTE PLAYER", "player applied")
        expect(store.executeControlCommand(cmd("player.foul", side: .home, value: 1, playerID: UUID())).error == "invalidCommand", "stale player")
        let duplicate = cmd("score.adjust", side: .home, value: 1)
        let scoreBefore = store.homeScore
        expect(store.performControlCommand(duplicate, remote: false).success, "first command")
        expect(store.performControlCommand(duplicate, remote: false).success && store.homeScore == scoreBefore + 1, "deduplication")
        var conflict = duplicate; conflict.value = 2
        expect(store.performControlCommand(conflict, remote: false).error == "conflict", "ID collision")
        expect(store.executeControlCommand(cmd("clock.running", enabled: true, delay: 3), remote: true).error == "stale", "stale timer")
        expect(store.executeControlCommand(cmd("clock.running", enabled: true), remote: true).error == "stale", "unsynced timer")
        store.resetClock(to: 60)
        expect(store.executeControlCommand(cmd("clock.running", enabled: true, delay: 1.25), remote: true).success, "delayed start")
        expect(store.gameClockSeconds == 59, "start compensates travel time")
        expect(store.executeControlCommand(cmd("clock.reset", value: 60)).error == "conflict", "game reset interlock")
        expect(store.executeControlCommand(cmd("score.reset")).error == "conflict", "score reset interlock")
        var staleToggle = cmd("clock.toggle", delay: 0.1); staleToggle.expectedRunning = false
        expect(store.executeControlCommand(staleToggle, remote: true).error == "conflict", "concurrent timer change")
        expect(store.executeControlCommand(cmd("clock.running", enabled: false, delay: 1.25), remote: true).success, "delayed pause")
        expect(store.gameClockSeconds == 60 && !store.isClockRunning, "pause restores tap-time clock")
        store.resetShotClock(to: 24)
        expect(store.executeControlCommand(cmd("shot.running", enabled: true, delay: 0.25), remote: true).success, "shot start")
        expect((23740...23760).contains(store.shotClockMilliseconds), "shot milliseconds compensation")
        expect(store.executeControlCommand(cmd("shot.running", enabled: false, delay: 0.25), remote: true).success, "shot pause")
        expect((23990...24000).contains(store.shotClockMilliseconds), "shot pause compensation")
        expect(store.executeControlCommand(cmd("clock.running", enabled: true, delay: 1.25), remote: true).success, "main clock before shot operation")
        let primaryBeforeShot = store.gameClockSeconds
        expect(store.executeControlCommand(cmd("shot.running", enabled: true, delay: 1.25), remote: true).success, "shot operation with main clock running")
        expect(store.gameClockSeconds == primaryBeforeShot, "shot compensation leaves unrelated primary clock alone")
        store.toggleClock()
        store.toggleShotClock()
        store.setSelectedSport(.chess)
        store.newGame()
        store.isSoundEnabled = false
        let home = store.homeChessClockSeconds, guest = store.guestChessClockSeconds
        expect(store.executeControlCommand(cmd("clock.running", enabled: true, delay: 1.25), remote: true).success, "chess start")
        expect(store.homeChessClockSeconds == home - 1, "chess start compensation")
        expect(store.executeControlCommand(cmd("chess.switch", delay: 1.25), remote: true).success, "chess switch")
        expect(store.homeChessClockSeconds == home && store.guestChessClockSeconds == guest - 1, "chess switch offsets both sides")
        store.setSelectedSport(.hockey)
        store.newGame()
        store.isSoundEnabled = false
        expect(store.executeControlCommand(cmd("penalty.add", side: .home, value: 120, enabled: true, delay: 1.25), remote: true).success, "penalty start")
        expect(store.homePenaltyTimers[0].remainingSeconds == 119, "penalty delay compensation")
        store.setSelectedSport(.debate)
        store.newGame()
        store.isSoundEnabled = false
        let debate = store.gameClockSeconds
        expect(store.executeControlCommand(cmd("clock.running", enabled: true, delay: 1.25), remote: true).success, "debate start")
        expect(store.gameClockSeconds == debate - 1, "debate compensation")
        store.toggleClock()
        store.setDebatePrepTimeEnabled(true)
        store.debatePrepHomeSeconds = 120
        expect(store.executeControlCommand(cmd("debate.prepToggle", side: .home, delay: 1.25), remote: true).success, "prep timer starts")
        expect(store.debatePrepHomeSeconds == 119, "prep start compensation")
        expect(store.executeControlCommand(cmd("debate.prepToggle", side: .home, delay: 1.25), remote: true).success, "prep timer pauses")
        expect(store.debatePrepHomeSeconds == 120, "prep pause compensation")
        store.setSelectedSport(.custom)
        store.customSportConfig.mainClockMode = .countUp
        store.gameClockSeconds = 0
        expect(store.executeControlCommand(cmd("clock.running", enabled: true, delay: 1.25), remote: true).success, "custom count-up starts")
        expect(store.gameClockSeconds == 1, "count-up start compensation")
        expect(store.executeControlCommand(cmd("clock.running", enabled: false, delay: 1.25), remote: true).success, "custom count-up pauses")
        expect(store.gameClockSeconds == 0, "count-up pause compensation")
        store.customSportConfig.usesChessClocks = true
        expect(store.executeControlCommand(cmd("clock.adjust", value: 1)).error == "unsupported", "dual clock excludes master-clock jog")
        expect(store.executeControlCommand(cmd("chess.side", side: .guest)).success, "custom dual-clock side")
        store.setSelectedSport(.basketball)
        store.setRemoteControlAllowed(displayID: "test-mac", isAllowed: true)
        expect(store.isRemoteControlAllowed(displayID: "test-mac"), "specific device granted")
        expect(!store.isRemoteControlAllowed(displayID: "test-ipad"), "other paired device remains display-only")
        store.setRemoteControlAllowed(displayID: "test-ipad", isAllowed: true)
        for _ in 0..<3 {
            // Every live acknowledgement refreshes this pairing through trustDisplay.
            store.refreshControlTestTrustedDisplay(peers[1])
            expect(store.isRemoteControlAllowed(displayID: "test-ipad"), "iPad permission survives heartbeat pairing refresh")
            expect(store.isRemoteControlAllowed(displayID: "test-mac"), "other device permission survives pairing refresh")
        }
        store.setRemoteControlAllowed(displayID: "test-ipad", isAllowed: false)
        store.setRemoteControlAllowed(displayID: "test-tv", isAllowed: true)
        expect(!store.isRemoteControlAllowed(displayID: "test-tv"), "Apple TV cannot receive control permission")
        store.setRemoteControlAllowed(displayID: "unpaired", isAllowed: true)
        expect(!store.isRemoteControlAllowed(displayID: "unpaired"), "unpaired device cannot receive control permission")
        store.setPlayerTrackingEnabled(true)
        store.setCurrentGameDisplayName("test")
        let remoteState = store.currentRemoteDisplayState(forDisplayID: "test-mac")
        expect(!remoteState.players.homeRoster.players.isEmpty, "remote control receives full roster")
        let decoded = try! JSONDecoder().decode(ScoreboardWebAPIRemoteDisplayStateV2.self,
                                               from: JSONEncoder().encode(remoteState.remoteDisplayV2Payload))
        expect(decoded.v1CompatibleState.control?.remoteEnabled == true, "v2 capability round trip")
        let oldHeartbeat = Data(#"{"kind":"heartbeat","sequence":1,"sentAt":123}"#.utf8)
        let oldMessage = try! JSONDecoder().decode(ScoreboardRemoteDisplayControlMessage.self, from: oldHeartbeat)
        expect(oldMessage.kind == .heartbeat && oldMessage.receivedAt == nil && oldMessage.command == nil, "legacy heartbeat compatible")
        let wireCommand = ScoreboardRemoteDisplayControlMessage(kind: .command, sequence: 2, sentAt: 123,
            hostID: "host", hostName: "Main", displayID: "display", displayName: "Remote", command: duplicate)
        let wireDecoded = try! JSONDecoder().decode(ScoreboardRemoteDisplayControlMessage.self, from: JSONEncoder().encode(wireCommand))
        expect(wireDecoded.command?.id == duplicate.id, "shared command wire round trip")
        let displayOnlyState = store.currentRemoteDisplayState(forDisplayID: "test-ipad")
        expect(displayOnlyState.control?.remoteEnabled == false && displayOnlyState.players.homeRoster.players.isEmpty,
               "permission and full roster scoped to recipient")
        var routed: [ScoreboardControlCommand] = []
        let proxy = ScoreboardStore.makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver(), sendCommand: { routed.append($0) })
        let preferenceDomain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let gameSentinel = Data("LOCAL GAME SENTINEL".utf8)
        let timerSentinel = Data("LOCAL TIMER SENTINEL".utf8)
        UserDefaults.standard.set(gameSentinel, forKey: "smartScoreboard.persistedState")
        UserDefaults.standard.set(timerSentinel, forKey: "smartScoreboard.primaryTimerPersistence")
        func persistedGameData() -> Data? {
            UserDefaults.standard.persistentDomain(forName: preferenceDomain)?["smartScoreboard.persistedState"] as? Data
        }
        expect(persistedGameData() == gameSentinel, "persistent-domain sentinel bypasses argument-domain masking")
        let localPersistence = persistedGameData()
        let localTimerPersistence = UserDefaults.standard.data(forKey: "smartScoreboard.primaryTimerPersistence")
        proxy.applyRemoteControlState(remoteState)
        expect(proxy.isRemoteControlProxy && proxy.selectedSport == store.selectedSport, "standard board uses remote mirror")
        expect(proxy.currentGameDisplayName == "test", "mirror shows host saved game name")
        let decodedNameState = try! JSONDecoder().decode(ScoreboardWebAPIState.self, from: JSONEncoder().encode(remoteState))
        expect(decodedNameState.control?.gameName == "test", "game name survives remote wire encoding")
        var mirrorPublications = 0
        let publicationToken = proxy.objectWillChange.sink { mirrorPublications += 1 }
        let repeatStart = Date()
        for _ in 0..<200 { proxy.applyRemoteControlState(remoteState) }
        expect(mirrorPublications == 0, "unchanged remote frames do not redraw player UI")
        print("200 unchanged remote frames: \(mirrorPublications) UI publications, \(Int(Date().timeIntervalSince(repeatStart) * 1_000)) ms")
        publicationToken.cancel()
        var timerFrame = remoteState.game
        timerFrame.gameClockSeconds -= 1
        let timedState = ScoreboardWebAPIState(schemaVersion: remoteState.schemaVersion,
            generatedAt: remoteState.generatedAt, generatedAtUnixTime: remoteState.generatedAtUnixTime,
            app: remoteState.app, game: timerFrame, runtime: remoteState.runtime, display: remoteState.display,
            audio: remoteState.audio, rules: remoteState.rules, teams: remoteState.teams,
            clocks: remoteState.clocks, players: remoteState.players, debate: remoteState.debate, control: remoteState.control)
        var rosterPublications = 0
        mirrorPublications = 0
        let timerPublicationToken = proxy.objectWillChange.sink { mirrorPublications += 1 }
        let rosterPublicationToken = proxy.$homeRoster.dropFirst().sink { _ in rosterPublications += 1 }
        proxy.applyRemoteControlState(timedState)
        expect(proxy.gameClockSeconds == timerFrame.gameClockSeconds, "timer-only frame updates timer")
        expect(mirrorPublications == 1 && rosterPublications == 0, "timer-only frame publishes one clock update and leaves player rows unchanged")
        timerPublicationToken.cancel()
        rosterPublicationToken.cancel()
        proxy.applyRemoteControlState(remoteState)
        expect(proxy.homeRoster.players.map(\.id) == store.homeRoster.players.map(\.id), "mirror preserves player IDs")
        let mirrorScore = proxy.homeScore
        proxy.adjustScore(isHome: true, by: 2)
        expect(routed.last?.action == "score.adjust" && routed.last?.value == 2 && routed.last?.side == .home, "native score control routes shared command")
        expect(proxy.homeScore == mirrorScore, "score waits for authoritative state")
        proxy.toggleClock()
        expect(routed.last?.action == "clock.running" && routed.last?.enabled == !remoteState.runtime.isClockRunning, "native timer control routes absolute running state")
        proxy.setPublicDisplayViewMode(.teamView)
        expect(routed.last?.action == "display.mode" && routed.last?.text == "teamView", "native display control routes command")
        proxy.setTheme(.night)
        expect(routed.last?.action == "display.theme", "native theme control routes command")
        proxy.updateTrackedPlayerName("REMOTE", for: .home, playerID: proxy.homeRoster.players[0].id)
        expect(routed.last?.action == "player.name", "native player editor routes command")
        proxy.clearTrackedPlayerState(for: .home, playerID: proxy.homeRoster.players[0].id)
        expect(routed.last?.action == "player.clear", "player reset is one atomic command")
        proxy.turnDebateClockHere(.guest)
        expect(routed.last?.action == "debate.turn", "debate turn is one atomic command")
        expect(persistedGameData() == localPersistence,
               "mirror does not overwrite local game preferences")
        expect(UserDefaults.standard.data(forKey: "smartScoreboard.primaryTimerPersistence") == localTimerPersistence,
               "mirror does not overwrite local timer persistence")
        expect(proxy.executeControlCommand(cmd("game.new")).error == "disabled", "mirror cannot execute main game operations locally")
        let connectedReceiver = ScoreboardRemoteDisplayReceiver()
        connectedReceiver.configureControlTestConnection(state: remoteState)
        let liveProxy = ScoreboardStore.makeRemoteControlStore(receiver: connectedReceiver)
        ScoreboardControlTestTransport.packets.removeAll()
        func sentCommand(_ index: Int) -> ScoreboardControlCommand {
            try! JSONDecoder().decode(ScoreboardRemoteDisplayControlMessage.self,
                from: ScoreboardControlTestTransport.packets[index]).command!
        }
        func acknowledge(_ command: ScoreboardControlCommand) {
            connectedReceiver.receiveControlTestMessage(ScoreboardRemoteDisplayControlMessage(
                kind: .commandResult, sequence: 0, sentAt: Date().timeIntervalSince1970,
                hostID: "test-main-host", hostName: "Main", displayID: connectedReceiver.displayID, displayName: "Remote",
                commandResult: ScoreboardControlResult(id: command.id, success: true, error: nil, message: nil)))
        }
        expect(connectedReceiver.canSendControlCommand, "approved connected controller ready")
        liveProxy.toggleClock()
        expect(connectedReceiver.isControlConnectionReady, "pending start does not change connection badge")
        let startCommand = sentCommand(0)
        expect(startCommand.action == "clock.running" && startCommand.enabled == true && startCommand.expectedRunning == false,
               "native start produces timestamped absolute command")
        expect(liveProxy.isClockRunning, "start intent appears immediately without local game logic")
        liveProxy.toggleClock()
        let stopCommand = sentCommand(1)
        expect(stopCommand.enabled == false && stopCommand.expectedRunning == true,
               "quick pause uses pending start intent rather than old snapshot")
        expect(!liveProxy.isClockRunning && connectedReceiver.pendingCommandsForDisplay.count == 2,
               "quick timer taps remain responsive and ordered")
        acknowledge(startCommand)
        expect(!liveProxy.isClockRunning && connectedReceiver.pendingCommandsForDisplay.count == 1,
               "first acknowledgement preserves pending pause")
        acknowledge(stopCommand)
        expect(connectedReceiver.pendingControlCommandID == nil, "both timer acknowledgements retire pending commands")
        let editingID = liveProxy.homeRoster.players[0].id
        liveProxy.updateTrackedPlayerName("A", for: .home, playerID: editingID)
        let firstEdit = sentCommand(2)
        liveProxy.updateTrackedPlayerName("AB", for: .home, playerID: editingID)
        let secondEdit = sentCommand(3)
        expect(liveProxy.homeRoster.players[0].name == "AB", "typing overlays the latest pending edit")
        acknowledge(firstEdit)
        expect(liveProxy.homeRoster.players[0].name == "AB", "earlier acknowledgement does not drop later text")
        acknowledge(secondEdit)
        for _ in 0..<16 { liveProxy.adjustScore(isHome: true, by: 1) }
        expect(connectedReceiver.pendingCommandsForDisplay.count == 16 && !connectedReceiver.canSendControlCommand,
               "in-flight commands are bounded")
        expect(connectedReceiver.isControlConnectionReady, "queue capacity does not change connection status")
        connectedReceiver.receiveControlTestMessage(ScoreboardRemoteDisplayControlMessage(
            kind: .clockSync, sequence: 1, sentAt: Date().timeIntervalSince1970,
            hostID: "test-main-host", hostName: "Main", displayID: connectedReceiver.displayID, displayName: "Remote",
            clockOffset: 0, roundTrip: 0.02, remoteControlEnabled: false))
        expect(!connectedReceiver.isControlBoardDevice && !connectedReceiver.canSendControlCommand,
               "permission revocation returns device to display role")
        expect(connectedReceiver.pendingCommandsForDisplay.isEmpty, "revocation discards pending intents")
        connectedReceiver.receiveControlTestMessage(ScoreboardRemoteDisplayControlMessage(
            kind: .clockSync, sequence: 2, sentAt: Date().timeIntervalSince1970,
            hostID: "test-main-host", hostName: "Main", displayID: connectedReceiver.displayID, displayName: "Remote",
            clockOffset: 0, roundTrip: 0.02, remoteControlEnabled: true))
        expect(connectedReceiver.isControlBoardDevice, "grant automatically selects app control board")
        liveProxy.adjustScore(isHome: true, by: 1)
        connectedReceiver.disconnectControlTestConnection()
        expect(connectedReceiver.isControlBoardDevice && !connectedReceiver.canSendControlCommand,
               "disconnect retains app screen with controls disabled")
        expect(connectedReceiver.pendingCommandsForDisplay.isEmpty, "disconnect does not queue commands for reconnect")
        connectedReceiver.configureControlTestConnection(state: remoteState)
        connectedReceiver.simulateSilentControlTestDisconnect()
        let offlinePacketCount = ScoreboardControlTestTransport.packets.count
        let offlineActionStart = Date()
        for _ in 0..<50 { liveProxy.adjustScore(isHome: true, by: 1) }
        expect(!connectedReceiver.status.isLive && connectedReceiver.status.title == "Disconnected",
               "offline action immediately marks stale connection disconnected")
        expect(ScoreboardControlTestTransport.packets.count == offlinePacketCount && connectedReceiver.pendingCommandsForDisplay.isEmpty,
               "offline actions never send or queue packets")
        expect(Date().timeIntervalSince(offlineActionStart) < 0.5, "repeated offline actions return without blocking")
        expect(connectedReceiver.isControlBoardDevice && connectedReceiver.state != nil,
               "offline actions preserve browsable board and cached state")
        connectedReceiver.configureControlTestConnection(state: remoteState)
        connectedReceiver.simulateSilentControlTestDisconnect()
        connectedReceiver.checkControlTestConnectionHealth()
        expect(connectedReceiver.status.title == "Disconnected", "health monitor detects silent disconnect without an action")
        connectedReceiver.configureControlTestConnection(state: remoteState)
        liveProxy.adjustScore(isHome: true, by: 1)
        try? await Task.sleep(for: .milliseconds(3_100))
        expect(connectedReceiver.status.title == "Disconnected" && connectedReceiver.pendingCommandsForDisplay.isEmpty,
               "command acknowledgement timeout disconnects and clears pending actions")
        store.setRemoteControlAllowed(displayID: "test-mac", isAllowed: false)
        expect(!store.isRemoteControlAllowed(displayID: "test-mac"), "per-device permission revokes")
        expect(store.currentRemoteDisplayState(forDisplayID: "test-mac").control?.remoteEnabled == false, "revocation advertised to recipient")
        store.setRemoteControlAllowed(displayID: "test-mac", isAllowed: true)
        store.removeRemoteDisplayPairing(displayID: "test-mac")
        expect(!store.remoteControlAllowedDisplayIDs.contains("test-mac"), "removing pairing removes permission")
        store.isRemoteDisplayViewerModeEnabled = true
        expect(store.executeControlCommand(cmd("game.new")).error == "disabled", "receiver cannot execute authoritative operations")
        store.isRemoteDisplayViewerModeEnabled = false
        if ProcessInfo.processInfo.environment["SCOREBOARD_TEST_HTTP"] == "1" {
            store.setSelectedSport(.basketball)
            store.isWebControlEnabled = true
            store.isWebAPIEnabled = true
            for _ in 0..<30 {
                if store.webAPIStatus.isRunning { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            expect(store.webAPIStatus.isRunning, "HTTP listener starts")
            func request(_ path: String, body: Data? = nil, key: String? = nil) async -> (Int, Data) {
                var request = URLRequest(url: URL(string: "http://127.0.0.1:5516" + path)!)
                request.timeoutInterval = 4
                if let body { request.httpMethod = "POST"; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
                if let key { request.setValue(key, forHTTPHeaderField: "X-API-Key") }
                let (data, response) = try! await URLSession.shared.data(for: request)
                return ((response as! HTTPURLResponse).statusCode, data)
            }
            let catalogResponse = await request("/api/v2/control/operations")
            expect(catalogResponse.0 == 200, "operation catalog HTTP")
            let catalog = try! JSONDecoder().decode([ScoreboardControlOperation].self, from: catalogResponse.1)
            expect(catalog.count == ScoreboardControlOperation.all.count, "HTTP shared catalog")
            expect(catalog.first { $0.id == "sound.play" }!.textChoices.contains("whistle"), "catalog choices")
            let command = cmd("score.adjust", side: .home, value: 1)
            let body = try! JSONEncoder().encode(command)
            let key = store.webControlAPIKey
            let missing = await request("/api/v2/control", body: body)
            expect(missing.0 == 401, "missing key HTTP")
            let wrong = await request("/api/v2/control", body: body, key: "WRONGKEY01234567")
            expect(wrong.0 == 401, "wrong key HTTP")
            let before = store.homeScore
            let applied = await request("/api/v2/control", body: body, key: key.lowercased())
            expect(applied.0 == 200 && store.homeScore == before + 1, "case insensitive key HTTP")
            let retry = await request("/api/v2/control", body: body, key: key)
            expect(retry.0 == 200 && store.homeScore == before + 1, "HTTP duplicate")
            let malformed = await request("/api/v2/control", body: Data("{".utf8), key: key)
            expect(malformed.0 == 400, "malformed JSON HTTP")
            var wrongSport = cmd("score.adjust", side: .home, value: 1); wrongSport.sport = .soccer
            let mismatch = await request("/api/v2/control", body: try! JSONEncoder().encode(wrongSport), key: key)
            expect(mismatch.0 == 409, "sport conflict HTTP")
            store.isWebControlEnabled = false
            let disabled = await request("/api/v2/control", body: body, key: key)
            expect(disabled.0 == 403, "control disabled HTTP")
            store.isWebControlEnabled = true
            store.resetWebControlAPIKey()
            expect(store.webControlAPIKey.count == 16 && store.webControlAPIKey.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }, "key format")
            let revoked = await request("/api/v2/control", body: body, key: key)
            expect(revoked.0 == 401, "reset key revokes HTTP")
            let newKey = await request("/api/v2/control", body: body, key: store.webControlAPIKey.lowercased())
            expect(newKey.0 == 200, "new key HTTP")
            store.setWebAPIEnabled(false)
        }
        checks += try! runSessionLogTests()
        checks += try! runSessionAuthorityTests()
        print("Passed \(checks) control checks across all \(SportType.allCases.count) sports.")
    }
}
