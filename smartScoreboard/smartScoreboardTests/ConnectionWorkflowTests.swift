import Foundation
import Testing

extension ScoreboardTests {
    @Test("Unchanged nearby heartbeats preserve pairing preference bytes while changed credentials are saved")
    func nearbyPairingPersistenceIsIdempotent() throws {
        let previousHosts = ScoreboardRemoteDisplayPairingStore.trustedHosts()
        let previousOperator = ScoreboardRemoteDisplayPairingStore.lastActiveOperator()
        defer {
            ScoreboardRemoteDisplayPairingStore.saveTrustedHosts(previousHosts)
            ScoreboardRemoteDisplayPairingStore.saveLastActiveOperator(previousOperator)
        }
        let host = ScoreboardRemoteDisplayTrustedPeer(id: "heartbeat-host", name: "Mac Host", pairingSecret: "first-secret")
        ScoreboardRemoteDisplayPairingStore.saveTrustedHosts([host])
        ScoreboardRemoteDisplayPairingStore.saveLastActiveOperator(host)
        let defaults = ScoreboardPreferences.current
        let hostsKey = "com.ironmaple.smartscoreboard.remoteDisplayTrustedHosts"
        let operatorKey = "com.ironmaple.smartscoreboard.remoteDisplayLastActiveOperator"
        let hostsBytes = try #require(defaults.data(forKey: hostsKey))
        let operatorBytes = try #require(defaults.data(forKey: operatorKey))
        for _ in 0..<100 {
            ScoreboardRemoteDisplayPairingStore.saveTrustedHosts([host])
            ScoreboardRemoteDisplayPairingStore.saveLastActiveOperator(host)
        }
        #expect(defaults.data(forKey: hostsKey) == hostsBytes)
        #expect(defaults.data(forKey: operatorKey) == operatorBytes)
        let rekeyed = ScoreboardRemoteDisplayTrustedPeer(id: host.id, name: "Renamed Mac", pairingSecret: "new-secret")
        ScoreboardRemoteDisplayPairingStore.saveTrustedHosts([rekeyed])
        ScoreboardRemoteDisplayPairingStore.saveLastActiveOperator(rekeyed)
        #expect(ScoreboardRemoteDisplayPairingStore.trustedHosts() == [rekeyed])
        #expect(ScoreboardRemoteDisplayPairingStore.lastActiveOperator() == rekeyed)
    }

    @Test("A physical device appears once across authenticated LAN and cloud transports")
    func connectionDeviceIdentityMerge() {
        let local = ScoreboardSessionPeer(id: "local-device", name: "iPad", deviceType: .ipad, connected: true, supportsHosting: true,
            controlEnabled: true, connectionStatus: .init(active: .init(route: .lan, method: .webSocket), available: [.init(route: .lan, method: .webSocket)]), devicePublicKey: "verified-device-key")
        let cloud = ScoreboardSessionPeer(id: "cloud-member", name: "iPad", deviceType: .unknown, connected: true, supportsHosting: false,
            connectionStatus: .init(active: .cloud, available: [.cloud, .cloud]), devicePublicKey: "verified-device-key")
        let another = ScoreboardSessionPeer(id: "another-device", name: "iPad", deviceType: .ipad, connected: true, supportsHosting: true, devicePublicKey: "different-key")
        let peers = ScoreboardSessionPeer.uniqueDevices([local, cloud, another, local])
        #expect(peers.count == 2)
        #expect(peers[0].id == "local-device" && peers[0].deviceType == .ipad)
        #expect(peers[0].connectionStatus?.available.count == 2)
        #expect(peers[0].controlEnabled == true)
    }

    @Test("Joined controls and display state are temporary and leave the local scoreboard and file intact")
    func joinedControlWorkspaceIsolation() throws {
        try store.matchLibrary.start()
        store.adjustScore(isHome: true, by: 8)
        store.setCurrentGameDisplayName("Personal scoreboard")
        try store.matchLibrary.save()
        let personal = store.currentGameSnapshot(), runtime = store.currentRuntimeID
        let url = URL(fileURLWithPath: try #require(store.currentMatchRecord.filePath))
        let saved = try Data(contentsOf: url)
        let localLogID = ScoreboardLogManager.shared.currentSessionSnapshot()?.sessionID
        let localLogEntries = ScoreboardLogManager.shared.currentSessionSnapshot()?.entries.count
        store.setRemoteControlAllowed(displayID: "test-mac", isAllowed: true)
        let source = store.currentRemoteDisplayState(forDisplayID: "test-mac")
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        var game = try #require(object["game"] as? [String: Any])
        let foreignID = UUID()
        game["matchID"] = foreignID.uuidString; game["ownerDeviceID"] = "foreign-owner"; game["homeScore"] = 99
        object["game"] = game
        let state = try JSONDecoder().decode(ScoreboardWebAPIState.self, from: JSONSerialization.data(withJSONObject: object))
        try store.prepareJoiningMatch(asDisplay: true); store.commitJoinedMatch()
        defer { store.leaveJoinedMatch() }
        let receiver = ScoreboardRemoteDisplayReceiver()
        receiver.configureControlTestConnection(state: state)
        #expect(receiver.presentsControlBoard, "a later permission grant overrides the initial display role")
        var commands: [ScoreboardControlCommand] = []
        let mirror = ScoreboardStore.makeRemoteControlStore(receiver: receiver, sendCommand: { commands.append($0) })
        #expect(!mirror.isShowingFileHome, "local/external display uses the mirrored match, not Home")
        #expect(mirror.currentMatchID == foreignID && mirror.homeScore == 99)
        mirror.adjustScore(isHome: true, by: 1)
        #expect(commands.last?.action == "score.adjust")
        store.adjustScore(isHome: true, by: 100)
        #expect(store.homeScore == personal.homeScore, "global inputs while joined must not mutate the parked document")
        try store.matchLibrary.save()
        #expect(try Data(contentsOf: url) == saved)
        #expect(ScoreboardLogManager.shared.currentSessionSnapshot()?.sessionID == localLogID)
        #expect(ScoreboardLogManager.shared.currentSessionSnapshot()?.entries.count == localLogEntries)
        #expect(store.currentMatchID == personal.matchID && store.currentRuntimeID == runtime)
        receiver.discardReceivedScoreboard()
        #expect(!receiver.presentsControlBoard && receiver.state == nil)
        store.leaveJoinedMatch()
        #expect(store.homeScore == personal.homeScore && store.currentMatchID == personal.matchID)
        #expect(store.currentGameDisplayName == "Personal scoreboard")
    }

    @Test("A burst of host network failures queues one delayed recovery and can be cancelled")
    func hostNetworkRecoveryBackoff() {
        let receiver = ScoreboardRemoteDisplayReceiver()
        let start = Date()
        #expect(receiver.networkRecoveryBurstIsThrottledForTest())
        #expect(Date().timeIntervalSince(start) < 0.5)
    }

    @Test("App public viewing links open Match Center and keep the token out of the query")
    func appPublicLinkUsesMatchCenter() throws {
        let url = try #require(ScoreboardCloudEndpoint.publicViewingURL(base: URL(string: "https://scores.example.test")!, sessionID: "ABCDEFGHJK", token: "view-token"))
        #expect(url.path == "/views/match.html")
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems == [.init(name: "session", value: "ABCDEFGHJK")])
        #expect(url.fragment == "view=view-token")
    }
}
