import Foundation
import Testing
import CryptoKit
import Network

extension ScoreboardTests {
    @Test("Home stops serving clients without discarding the scoreboard and reopening restarts hosting")
    func fileHomeDisconnectsClients() async throws {
        try store.matchLibrary.start()
        store.adjustScore(isHome: true, by: 7)
        let matchID = store.currentMatchID
        store.isWebAPIEnabled = true
        defer { store.isWebAPIEnabled = false; store.setRemoteDisplayHostEnabled(false); store.isShowingFileHome = false }
        for _ in 0..<80 {
            if store.webAPIStatus.isRunning { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        let port = try #require({ () -> UInt16? in if case .running(_, let port, _) = store.webAPIStatus { return port }; return nil }())
        let socket = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/")!)
        socket.resume()
        defer { socket.cancel(with: .goingAway, reason: nil) }
        _ = try await socket.receive()
        for _ in 0..<80 {
            if !store.webAPIClients.isEmpty { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(!store.webAPIClients.isEmpty)
        try store.prepareForFileHome()
        for _ in 0..<80 {
            if store.webAPIClients.isEmpty && !store.webAPIStatus.isRunning { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(store.isShowingFileHome && !store.isRemoteDisplayHostEnabled)
        #expect(store.webAPIClients.isEmpty && !store.webAPIStatus.isRunning)
        store.setRemoteDisplayHostEnabled(true)
        #expect(!store.isRemoteDisplayHostEnabled)
        #expect(!store.performCloudControlCommand(cmd("score.adjust", side: .home, value: 1)).success)
        #expect(store.currentMatchID == matchID && store.homeScore == 7)
        store.resumeOpenMatchConnections()
        for _ in 0..<80 {
            if store.webAPIStatus.isRunning { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(!store.isShowingFileHome && store.webAPIStatus.isRunning && store.isRemoteDisplayHostEnabled)
        #expect(store.currentMatchID == matchID && store.homeScore == 7)
    }

    @Test("Apple TV is display-only while iPad and Mac support the standard controller")
    func remoteDeviceControlCapabilities() {
        #expect(!ScoreboardRemoteDisplayDeviceType.appleTV.supportsControl)
        #expect(ScoreboardRemoteDisplayDeviceType.ipad.supportsControl && ScoreboardRemoteDisplayDeviceType.mac.supportsControl)
        store.setRemoteControlAllowed(displayID: "test-tv", isAllowed: true)
        #expect(!store.isRemoteControlAllowed(displayID: "test-tv"))
        store.setRemoteControlAllowed(displayID: "test-ipad", isAllowed: true)
        #expect(store.isRemoteControlAllowed(displayID: "test-ipad"))
    }

    @Test("Kiosk invitations compare the configured cloud origin without accepting another server")
    func configuredCloudServiceOrigin() {
        #expect(ScoreboardCloudEndpoint.sameService("https://scores.example.test/", "https://scores.example.test"))
        #expect(ScoreboardCloudEndpoint.sameService("https://scores.example.test:443", "https://scores.example.test"))
        #expect(!ScoreboardCloudEndpoint.sameService("https://other.example.test", "https://scores.example.test"))
        #expect(!ScoreboardCloudEndpoint.sameService("https://scores.example.test:8443", "https://scores.example.test"))
    }

    @Test("Local-only mode stops network services and cannot be bypassed by opening or restoring a scoreboard")
    func localOnlyConnectionPolicy() async throws {
        let library = store.matchLibrary
        try library.start()
        store.adjustScore(isHome: true, by: 7)
        try library.save()
        let matchID = store.currentMatchID
        var backup = try #require(JSONSerialization.jsonObject(with: store.exportPersistedStateData()) as? [String: Any])
        backup["isRemoteDisplayHostEnabled"] = true
        backup["isWebAPIEnabled"] = true
        backup["isCompanionVisible"] = true
        backup["isCompanionEnabled"] = true
        defer { try? store.setLocalConnectionsEnabled(true) }

        // The core fixture serves HTTP on an OS-assigned loopback port.
        store.isWebAPIEnabled = true
        for _ in 0..<80 {
            if store.webAPIStatus.isRunning { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(store.webAPIStatus.isRunning)

        try store.setLocalConnectionsEnabled(false)
        for _ in 0..<80 {
            if !store.webAPIStatus.isRunning { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(!store.webAPIStatus.isRunning)
        #expect(!ScoreboardConnectionPolicy.allowsLocalNetworking && !store.localConnectionsEnabled)
        #expect(!store.isRemoteDisplayHostEnabled && !store.isWebAPIEnabled && !store.isCompanionEnabled)
        store.setRemoteDisplayHostEnabled(true)
        store.setWebAPIEnabled(true)
        store.isCompanionVisible = true
        store.setCompanionEnabled(true)
        #expect(!store.isRemoteDisplayHostEnabled && !store.isWebAPIEnabled && !store.isCompanionEnabled)
        try store.restorePersistedStateData(JSONSerialization.data(withJSONObject: backup))
        #expect(!store.isRemoteDisplayHostEnabled && !store.isWebAPIEnabled && !store.isCompanionEnabled)
        #expect(!store.localConnectionsEnabled && !ScoreboardConnectionPolicy.allowsLocalNetworking)
        // Restoring file state must remain usable without reactivating networking.
        store.adjustScore(isHome: true, by: 1)
        try library.save()
        #expect(store.currentMatchID == matchID && store.homeScore == 8)
        #expect(!ScoreboardCloudClient.shared.isConnected)
        try store.setLocalConnectionsEnabled(true)
        #expect(ScoreboardConnectionPolicy.allowsLocalNetworking && store.localConnectionsEnabled)
        #expect(store.currentMatchID == matchID && store.homeScore == 8)
    }

    @Test("Preferred routes track independent LAN and cloud switches, including cloud-only operation")
    func linkedConnectionPreferences() throws {
        let cloud = ScoreboardCloudClient.shared
        defer { cloud.cloudEnabled = false; try? store.setLocalConnectionsEnabled(true) }
        cloud.cloudEnabled = false
        #expect(store.availableConnectionModes == [.localNetworkOnly, .nearbyAndLocalNetwork])
        store.setRemoteDisplayNetworkMode(.localNetworkOnly)
        #expect(store.remoteDisplayNetworkMode == .localNetworkOnly)
        cloud.cloudEnabled = true
        #expect(store.availableConnectionModes == [.preferLocal, .preferCloud])
        #expect(store.remoteDisplayNetworkMode == .preferLocal)
        store.setRemoteDisplayNetworkMode(.preferCloud)
        try store.setLocalConnectionsEnabled(false)
        #expect(cloud.cloudEnabled)
        #expect(store.availableConnectionModes == [.cloudOnly] && store.remoteDisplayNetworkMode == .cloudOnly)
        #expect(!ScoreboardRemoteDisplayNetworkMode.cloudOnly.includesPeerToPeer)
        #expect(ScoreboardRemoteRoute.choose(mode: .cloudOnly, localFresh: true, cloudFresh: false,
            sameHost: true, current: .cloud, hasPendingCommand: false) == .cloud)
        store.setRemoteDisplayNetworkMode(.preferLocal)
        #expect(store.remoteDisplayNetworkMode == .cloudOnly)
        cloud.cloudEnabled = false
        #expect(store.availableConnectionModes.isEmpty && !store.localConnectionsEnabled)
        try store.setLocalConnectionsEnabled(true)
        #expect(store.remoteDisplayNetworkMode == .nearbyAndLocalNetwork)
    }

    @Test("Bonjour authorization failures have actionable messages without misclassifying network failures")
    func nearbyDiscoveryPermissionErrors() {
        #expect(ScoreboardNearbyNetworkError.requiresPermission(.dns(-65555)))
        #expect(ScoreboardNearbyNetworkError.requiresPermission(.dns(-65570)))
        #expect(ScoreboardNearbyNetworkError.requiresPermission(.posix(.EACCES)))
        #expect(!ScoreboardNearbyNetworkError.requiresPermission(.posix(.ENETDOWN)))
        #expect(!ScoreboardNearbyNetworkError.message(for: .dns(-65555)).contains("-65555"))
        #expect(!ScoreboardNearbyNetworkError.message(for: .dns(-65555)).contains("NoAuth"))
    }

    @Test("Kiosk factory reset clears cloud URL, credentials, local pairings and cached game data")
    func kioskFactoryReset() throws {
        let preferences = ScoreboardPreferences.current
        let previous = preferences.string(forKey: ScoreboardDeviceMode.preferenceKey)
        defer { preferences.set(previous, forKey: ScoreboardDeviceMode.preferenceKey) }
        let library = store.matchLibrary
        try library.start(); try library.save()
        let savedURL = URL(fileURLWithPath: try #require(store.currentMatchRecord.filePath))
        try store.setDeviceMode(.kiosk)
        let cloud = ScoreboardCloudClient.shared
        cloud.serviceMode = .selfHosted; cloud.selfHostedURL = "https://scoreboard.example.test"
        cloud.cloudFailoverEnabled = true
        store.setRemoteDisplayNetworkMode(.preferCloud)
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        receiver.configureControlTestConnection(state: store.currentWebAPIState().cloudControlPayload(allowed: true))
        let staleHosted = ScoreboardHostedMatchStorage.gameURL(for: UUID())
        try FileManager.default.createDirectory(at: staleHosted.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("legacy hosted cache".utf8).write(to: staleHosted)
        try store.resetKioskToFactoryDefaults()
        #expect(!FileManager.default.fileExists(atPath: staleHosted.path))
        #expect(!cloud.cloudEnabled && !cloud.isLinked && !cloud.cloudFailoverEnabled)
        #expect(cloud.serviceMode == .publicCloud && cloud.selfHostedURL.isEmpty)
        #expect(store.remoteDisplayNetworkMode == .nearbyAndLocalNetwork)
        #expect(receiver.state == nil && receiver.trustedHosts.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: savedURL.path))
        #expect(!store.isJoinedMatchActive)
    }

    @Test("Kiosks can control a joined match, cannot host or create files, and discard received state on disconnect")
    func kioskCapabilitiesAndDisconnect() throws {
        let preferences = ScoreboardPreferences.current
        let previous = preferences.string(forKey: ScoreboardDeviceMode.preferenceKey)
        defer {
            store.leaveJoinedMatch()
            preferences.set(previous, forKey: ScoreboardDeviceMode.preferenceKey)
        }
        #expect(ScoreboardDeviceMode.app.canHost && ScoreboardDeviceMode.app.canCreateScoreboards)
        #expect(!ScoreboardDeviceMode.kiosk.canHost && !ScoreboardDeviceMode.kiosk.canCreateScoreboards)
        let kiosk = ScoreboardRemoteDisplaySource(endpoint: .hostPort(host: "127.0.0.1", port: 1),
            discoveryInfo: ["sessionProtocolVersion": String(ScoreboardSessionTransport.protocolVersion), "canHostSession": "false"])
        #expect(kiosk.supportsSessionProtocol && !kiosk.supportsSessionHosting, "Join-only devices still need authenticated session messages and failover enrollment")
        let library = store.matchLibrary
        try library.start(); try library.save()
        let savedURL = URL(fileURLWithPath: try #require(store.currentMatchRecord.filePath))
        let saved = try Data(contentsOf: savedURL), originalID = store.currentMatchID
        try store.setDeviceMode(.kiosk)
        #expect(ScoreboardDeviceMode.current == .kiosk)
        store.setRemoteDisplayHostEnabled(true)
        #expect(!store.isRemoteDisplayHostEnabled)
        #expect(throws: (any Error).self) { try library.newMatch() }
        #expect(store.currentMatchID == originalID)
        try store.prepareJoiningMatch(asDisplay: false); store.commitJoinedMatch()
        #expect(store.isJoinedMatchActive && !store.joinedAsDisplay)
        #expect(throws: (any Error).self) { try store.setDeviceMode(.app) }
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        receiver.configureControlTestConnection(state: store.currentWebAPIState().cloudControlPayload(allowed: true))
        #expect(receiver.state != nil)
        receiver.disconnectControlTestConnection()
        #expect(receiver.state == nil)
        #expect(!receiver.canSendControlCommand)
        #expect(try Data(contentsOf: savedURL) == saved)
        store.leaveJoinedMatch()
        #expect(!store.isJoinedMatchActive && receiver.state == nil)
    }

    @Test("Library autosaves separate matches, resumes scores and makes new matches from saved setup")
    func localLibraryLifecycle() throws {
        let library = store.matchLibrary
        try library.start()
        store.homeTeamName = "Foxes"; store.guestTeamName = "Owls"
        store.adjustScore(isHome: true, by: 12)
        try library.save(); try library.refresh()
        let firstID = store.currentMatchID
        let first = try #require(library.entries.first(where: { $0.matchID == firstID }))
        let firstURL = first.url
        try library.newMatch()
        #expect(store.currentMatchID != firstID && store.homeScore == 0 && store.homeTeamName == "Foxes")
        #expect(store.currentMatchRecord.filePath != firstURL.path)
        #expect(try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: firstURL)).homeScore == 12)
        #expect(!store.currentMatchRecord.cloudEnabled)
        try library.resume(first)
        #expect(store.currentMatchID == firstID && store.homeScore == 12)
        try library.rename(first, to: "Final Match")
        let renamed = try #require(library.entries.first(where: { $0.matchID == firstID }))
        #expect(renamed.title == "Final Match" && !FileManager.default.fileExists(atPath: firstURL.path))
        store.adjustScore(isHome: true, by: 1); try library.save()
        #expect(try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: renamed.url)).homeScore == 13)
        let beforeDuplicate = Set(library.entries.compactMap(\.matchID))
        try library.duplicate(renamed)
        let copy = try #require(library.entries.first(where: { $0.matchID.map { !beforeDuplicate.contains($0) } == true }))
        #expect(copy.homeScore == 13 && store.currentMatchID == firstID)
        try library.newMatch(from: renamed)
        #expect(store.currentMatchID != firstID)
        #expect(store.homeScore == 0)
        #expect(store.homeTeamName.uppercased() == "FOXES")
        #expect(!store.currentMatchRecord.cloudEnabled)
        #expect(try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: renamed.url)).homeScore == 13)
    }

    @Test("Library listing is read-only, exposes unreadable files, and refuses to overwrite another match")
    func localLibraryFileSafety() throws {
        let library = store.matchLibrary
        try library.start(); try library.save()
        let folder = try ScoreboardFileStorage.storedGamesDirectory()
        let legacyURL = folder.appendingPathComponent("Read Only Legacy.scoreboardgame")
        let brokenURL = folder.appendingPathComponent("Unreadable.scoreboardgame")
        defer { try? FileManager.default.removeItem(at: legacyURL); try? FileManager.default.removeItem(at: brokenURL) }
        var legacy = store.currentGameSnapshot(); legacy.matchID = nil; legacy.ownerDeviceID = nil; legacy.fileVersion = 12
        try ScoreboardMatchFiles.write(legacy, to: legacyURL)
        let bytes = try Data(contentsOf: legacyURL)
        try Data("invalid game".utf8).write(to: brokenURL)
        try library.refresh()
        #expect(try Data(contentsOf: legacyURL) == bytes)
        let broken = try #require(library.entries.first(where: { $0.url.lastPathComponent == brokenURL.lastPathComponent }))
        #expect(broken.loadError != nil)
        let url = URL(fileURLWithPath: try #require(store.currentMatchRecord.filePath))
        let saved = store.currentGameSnapshot()
        defer { try? ScoreboardMatchFiles.write(saved, to: url) }
        try ScoreboardMatchFiles.write(saved.asNewMatch(ownerDeviceID: store.localSessionDeviceID), to: url)
        #expect(throws: (any Error).self) { try library.save() }
        #expect(library.saveError != nil)
        let before = store.currentMatchID
        store.newGame()
        #expect(store.currentMatchID == before)
    }

    @Test("Preparing and cancelling a join preserves the personal match before the workspace commits")
    func joinedWorkspaceTransition() throws {
        let library = store.matchLibrary
        try library.start()
        store.adjustScore(isHome: true, by: 8); try library.save()
        let before = store.currentMatchID
        let url = URL(fileURLWithPath: try #require(store.currentMatchRecord.filePath))
        let saved = try Data(contentsOf: url)
        try store.prepareJoiningMatch(asDisplay: true)
        #expect(store.isPreparingMatchJoin && !store.isJoinedMatchActive)
        #expect(throws: (any Error).self) { try store.prepareJoiningMatch() }
        try library.save()
        #expect(try Data(contentsOf: url) == saved)
        store.leaveJoinedMatch()
        #expect(!store.isPreparingMatchJoin && !store.isJoinedMatchActive)
        #expect(store.currentMatchID == before && store.homeScore == 8)
        try store.prepareJoiningMatch()
        store.commitJoinedMatch()
        #expect(store.isJoinedMatchActive && !store.isPreparingMatchJoin)
        #expect(throws: (any Error).self) { try library.newMatch() }
        store.leaveJoinedMatch()
        #expect(store.currentMatchID == before && store.homeScore == 8)
        store.setRemoteDisplayHostEnabled(true)
        let localRuntime = try #require(store.sessionDescriptor?.sessionID)
        try store.prepareJoiningMatch()
        store.leaveJoinedMatch()
        #expect(store.isRemoteDisplayHostEnabled && store.isSessionAuthority)
        #expect(store.sessionDescriptor?.sessionID == localRuntime)
        #expect(store.sessionDescriptor?.matchID == before)
        store.setRemoteDisplayHostEnabled(false)
    }

    @Test("Relay availability honors no-expiry grants, expiry boundaries and the global cloud switch")
    func cloudRelayAvailability() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let milliseconds = now.timeIntervalSince1970 * 1000
        #expect(ScoreboardRelayEntitlement(active: true, expiresAt: nil).isValid(at: now))
        #expect(ScoreboardRelayEntitlement(active: true, expiresAt: milliseconds + 1).isValid(at: now))
        #expect(!ScoreboardRelayEntitlement(active: true, expiresAt: milliseconds).isValid(at: now))
        #expect(!ScoreboardRelayEntitlement(active: true, expiresAt: milliseconds - 1).isValid(at: now))
        #expect(!ScoreboardRelayEntitlement(active: false, expiresAt: nil).isValid(at: now))
        let domain = "RelayAvailability.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let cloud = ScoreboardCloudClient(preferences: defaults)
        #expect(!cloud.canEnableOnlineSharing)
        #expect(cloud.onlineSharingGuidance.contains("Enable Cloud"))
        cloud.cloudEnabled = true
        #expect(!cloud.canEnableOnlineSharing)
        #expect(cloud.onlineSharingGuidance.contains("Sign in"))
    }

    @Test("Match identity survives saves and legacy migration while imported copies get new identities")
    func matchIdentityFiles() throws {
        store.adjustScore(isHome: true, by: 7)
        let original = store.currentGameSnapshot()
        let id = try #require(original.matchID)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: encoded)
        #expect(decoded.matchID == id && decoded.homeScore == 7)
        let imported = decoded.asNewMatch(ownerDeviceID: "receiving-device")
        #expect(imported.matchID != id && imported.ownerDeviceID == "receiving-device" && imported.homeScore == 7)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Legacy.scoreboardgame")
        var legacy = original; legacy.fileVersion = 12; legacy.matchID = nil; legacy.ownerDeviceID = nil
        try ScoreboardMatchFiles.write(legacy, to: url)
        let first = try ScoreboardMatchFiles.load(url, ownerDeviceID: store.localSessionDeviceID)
        let again = try ScoreboardMatchFiles.load(url, ownerDeviceID: store.localSessionDeviceID)
        #expect(first.matchID != nil && again.matchID == first.matchID && first.homeScore == original.homeScore)
        #expect(first.homeRoster == original.homeRoster && first.gameClockSeconds == original.gameClockSeconds)
        let foreignURL = folder.appendingPathComponent("Imported.scoreboardgame")
        try ScoreboardMatchFiles.write(imported, to: foreignURL)
        let foreignCopy = try ScoreboardMatchFiles.load(foreignURL, ownerDeviceID: store.localSessionDeviceID)
        #expect(foreignCopy.matchID != imported.matchID && foreignCopy.ownerDeviceID == store.localSessionDeviceID)
        let renamedURL = folder.appendingPathComponent("Renamed.scoreboardgame")
        try FileManager.default.moveItem(at: foreignURL, to: renamedURL)
        #expect(try ScoreboardMatchFiles.load(renamedURL, ownerDeviceID: store.localSessionDeviceID).matchID == foreignCopy.matchID)
        store.newGame()
        #expect(store.currentMatchID != id)
    }

    @Test("Joining preserves the local working match and does not persist a mandatory remote mode")
    func joinedMatchPreservesWorkingCopy() throws {
        store.adjustScore(isHome: true, by: 4)
        let before = store.currentGameSnapshot()
        try store.joinAnotherMatch(asDisplay: true)
        #expect(store.isJoinedMatchActive && store.joinedAsDisplay)
        let persisted = try #require(JSONSerialization.jsonObject(with: store.exportPersistedStateData()) as? [String: Any])
        #expect(persisted["isRemoteDisplayViewerModeEnabled"] as? Bool == false)
        store.leaveJoinedMatch()
        #expect(!store.isJoinedMatchActive && !store.isRemoteDisplayViewerModeEnabled)
        #expect(store.currentGameSnapshot().matchID == before.matchID && store.homeScore == before.homeScore)
        store.toggleClock()
        #expect(throws: (any Error).self) { try store.joinAnotherMatch() }
        store.toggleClock()
        let backup = try store.exportPersistedStateData()
        var foreign = try #require(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        let hostedMatchID = UUID()
        foreign["matchID"] = hostedMatchID.uuidString; foreign["matchOwnerDeviceID"] = "another-owner"
        let checkpointSettings = try JSONSerialization.data(withJSONObject: foreign)
        store.withControlTestFollowingSessionHost {
            #expect(throws: (any Error).self) { try store.requireMatchReplacementAllowed() }
            #expect(throws: (any Error).self) { try store.restorePersistedStateData(checkpointSettings) }
            #expect(throws: Never.self) {
                try store.withControlTestTrustedSessionUpdate { try store.restorePersistedStateData(checkpointSettings) }
            }
            #expect(store.currentMatchID == hostedMatchID && store.matchOwnerDeviceID == "another-owner")
        }
        try store.restorePersistedStateData(backup)
    }

    @Test("Invitations preserve server identity and fragment passwords; native device proofs use the persistent signing key")
    func matchInvitationAndDeviceProof() throws {
        let invite = ScoreboardMatchInvitation(server: "https://scores.example.test", code: "ABCDEFGHJK", password: "Fox & 🦊 / ?=123")
        let url = try #require(invite.url)
        #expect(ScoreboardMatchInvitation.parse(url.absoluteString) == invite)
        #expect(ScoreboardMatchInvitation.parse("smartscoreboard://join?server=https%3A%2F%2Fscores.example.test&code=ABCDEFGHJK")?.server == invite.server)
        #expect(ScoreboardMatchInvitation.parse("https://user:pass@scores.example.test/join/ABCDEFGHJK") == nil)
        var request = URLRequest(url: URL(string: "https://scores.example.test/api/sessions/ABCDEFGHJK/socket?participant=1")!)
        request.httpMethod = "GET"
        try ScoreboardDeviceIdentity.sign(&request)
        let data = try #require(Data(base64Encoded: request.value(forHTTPHeaderField: "X-Scoreboard-Device-Proof") ?? ""))
        let proof = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let timestamp = try #require(proof["timestamp"] as? Int), nonce = try #require(proof["nonce"] as? String)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: #require(Data(base64Encoded: proof["signature"] as? String ?? "")))
        let key = try P256.Signing.PublicKey(x963Representation: #require(Data(base64Encoded: ScoreboardDeviceIdentity.publicKey)))
        #expect(key.isValidSignature(signature, for: Data("GET\n/api/sessions/ABCDEFGHJK/socket?participant=1\n\(timestamp)\n\(nonce)".utf8)))
        let domain = "CloudDisabled.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain)); defer { defaults.removePersistentDomain(forName: domain) }
        let client = ScoreboardCloudClient(preferences: defaults)
        #expect(!client.cloudEnabled)
        client.beginLink()
        #expect(!client.isLinking)
    }

    @Test("Cross-match commands fail while UUID retries retain their original acknowledgement")
    func matchCommandFencing() {
        var command = cmd("score.adjust", side: .home, value: 1)
        command.matchID = store.currentMatchID
        #expect(store.performCloudControlCommand(command).success)
        store.newGame()
        #expect(store.performCloudControlCommand(command).success)
        var stale = command; stale.id = UUID()
        #expect(!store.performCloudControlCommand(stale).success)
        #expect(store.homeScore == 0)
    }
}
