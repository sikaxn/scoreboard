import Foundation
import Testing
import CryptoKit

extension ScoreboardTests {
    @Test("LAN cloud enrollment is encrypted for the paired device and rejects tampering and replay")
    func encryptedCloudEnrollment() throws {
        let domain = "ScoreboardEncryptedEnrollment.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let client = ScoreboardCloudClient(preferences: defaults)
        let grant = ScoreboardCloudEnrollment(serviceURL: "https://scores.example.com", token: "private-device-credential",
            sessionID: "ABCDEFGHJK", accountID: "account-a", hostLocalID: "host-a", remoteDeviceID: "display-a")
        let data = try JSONEncoder().encode(grant)
        let encrypted = try ScoreboardCloudEnrollmentCrypto.seal(data, recipient: ScoreboardCloudEnrollmentCrypto.publicKey,
            pairingSecret: "trusted-pairing-secret", hostID: "host-a", deviceID: "display-a")
        #expect(!String(decoding: encrypted, as: UTF8.self).contains(grant.token))
        #expect(try ScoreboardCloudEnrollmentCrypto.open(encrypted, pairingSecret: "trusted-pairing-secret", hostID: "host-a", deviceID: "display-a") == data)
        #expect(throws: (any Error).self) {
            try ScoreboardCloudEnrollmentCrypto.open(encrypted, pairingSecret: "wrong", hostID: "host-a", deviceID: "display-a")
        }
        #expect(throws: (any Error).self) {
            try ScoreboardCloudEnrollmentCrypto.open(encrypted, pairingSecret: "trusted-pairing-secret", hostID: "host-a", deviceID: "other-display")
        }
        let otherDevice = P256.KeyAgreement.PrivateKey().publicKey.x963Representation.base64EncodedString()
        let encryptedForOtherDevice = try ScoreboardCloudEnrollmentCrypto.seal(data, recipient: otherDevice,
            pairingSecret: "trusted-pairing-secret", hostID: "host-a", deviceID: "display-a")
        #expect(throws: (any Error).self) {
            try ScoreboardCloudEnrollmentCrypto.open(encryptedForOtherDevice, pairingSecret: "trusted-pairing-secret", hostID: "host-a", deviceID: "display-a")
        }
        var object = try #require(JSONSerialization.jsonObject(with: encrypted) as? [String: Any])
        var ciphertext = try #require(Data(base64Encoded: object["ciphertext"] as? String ?? ""))
        ciphertext[ciphertext.count - 1] ^= 1; object["ciphertext"] = ciphertext.base64EncodedString()
        #expect(throws: (any Error).self) {
            try ScoreboardCloudEnrollmentCrypto.open(JSONSerialization.data(withJSONObject: object), pairingSecret: "trusted-pairing-secret", hostID: "host-a", deviceID: "display-a")
        }
        #expect(client.acceptEncryptedEnrollment(encrypted, pairingSecret: "wrong", authenticatedHostID: "host-a", localDeviceID: "display-a"))
        #expect(!client.isLinked)
        #expect(client.acceptEncryptedEnrollment(encrypted, pairingSecret: "trusted-pairing-secret", authenticatedHostID: "host-a", localDeviceID: "display-a"))
        #expect(client.isLinked && client.selectedSessionID == "ABCDEFGHJK")
        client.didPairLocalHost("new-offline-host")
        #expect(client.acceptEncryptedEnrollment(encrypted, pairingSecret: "trusted-pairing-secret", authenticatedHostID: "host-a", localDeviceID: "display-a"))
        #expect(client.selectedSessionID.isEmpty, "Replaying an older enrollment cannot restore a previous cloud target")
        client.disconnect()
    }

    @Test("Connection preferences keep strict local modes local and fail over only to the selected host")
    func cloudRoutePreferences() {
        for mode in [ScoreboardRemoteDisplayNetworkMode.localNetworkOnly, .nearbyAndLocalNetwork] {
            #expect(!mode.allowsCloud)
            #expect(ScoreboardRemoteRoute.choose(mode: mode, localFresh: false, cloudFresh: true,
                sameHost: true, current: .cloud, hasPendingCommand: false) == .local)
        }
        #expect(!ScoreboardRemoteDisplayNetworkMode.localNetworkOnly.includesPeerToPeer)
        #expect(ScoreboardRemoteDisplayNetworkMode.preferLocal.includesPeerToPeer)
        #expect(ScoreboardRemoteRoute.choose(mode: .preferLocal, localFresh: true, cloudFresh: true,
            sameHost: true, current: .cloud, hasPendingCommand: false) == .local)
        #expect(ScoreboardRemoteRoute.choose(mode: .preferLocal, localFresh: false, cloudFresh: true,
            sameHost: true, current: .local, hasPendingCommand: false) == .cloud)
        #expect(ScoreboardRemoteRoute.choose(mode: .preferCloud, localFresh: true, cloudFresh: true,
            sameHost: true, current: .local, hasPendingCommand: false) == .cloud)
        #expect(ScoreboardRemoteRoute.choose(mode: .preferCloud, localFresh: true, cloudFresh: false,
            sameHost: true, current: .cloud, hasPendingCommand: false) == .local)
        #expect(ScoreboardRemoteRoute.choose(mode: .preferCloud, localFresh: true, cloudFresh: false,
            sameHost: false, current: .cloud, hasPendingCommand: false) == .cloud)
        #expect(ScoreboardRemoteRoute.choose(mode: .preferLocal, localFresh: true, cloudFresh: true,
            sameHost: true, current: .cloud, hasPendingCommand: true) == .cloud)
    }

    @Test("QR pairing binds nearby codes to a device and cloud codes to a service origin")
    func cloudPairingLinks() {
        let link = ScoreboardPairingLink.nearbyURL(deviceID: "display-123", code: "0123")
        #expect(ScoreboardPairingLink.parse(link) == .nearby(deviceID: "display-123", code: "0123"))
        #expect(ScoreboardPairingLink.parse("https://scores.example.com/?link=ABCDEFGHJK") == .cloud(code: "ABCDEFGHJK", origin: "https://scores.example.com"))
        for invalid in ["smartscoreboard://pair?device=x&code=123", "smartscoreboard://pair?device=x&code=1234&code=5678",
                        "https://user:pass@scores.example.com/?link=ABCDEFGHJK", "http://scores.example.com/?link=ABCDEFGHJK", "just text"] {
            #expect(ScoreboardPairingLink.parse(invalid) == nil)
        }
    }

    @Test("Failover enrollment requires the authenticated host and never silently changes account or service")
    func cloudEnrollmentIdentity() throws {
        let domain = "ScoreboardCloudEnrollmentTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let client = ScoreboardCloudClient(preferences: defaults)
        var grant = ScoreboardCloudEnrollment(serviceURL: "https://scores.example.com", token: "test-only-opaque-token", sessionID: "ABCDEFGHJK",
            accountID: "test-account", hostLocalID: "host-123", remoteDeviceID: "display-123")
        let wire = try JSONEncoder().encode(grant)
        #expect(client.acceptEnrollment(wire, authenticatedHostID: "wrong-host", localDeviceID: "display-123"))
        #expect(!client.isLinked)
        #expect(client.acceptEnrollment(wire, authenticatedHostID: "host-123", localDeviceID: "wrong-display"))
        #expect(!client.isLinked)
        #expect(client.acceptEnrollment(wire, authenticatedHostID: "host-123", localDeviceID: "display-123"))
        #expect(client.isLinked && client.isRemoteRegistration && client.selectedSessionID == "ABCDEFGHJK")
        #expect(client.serviceMode == .selfHosted && client.serviceURL == "https://scores.example.com")
        grant.accountID = "other-account"; grant.sessionID = "KJHGFEDCBA"
        #expect(client.acceptEnrollment(try JSONEncoder().encode(grant), authenticatedHostID: "host-123", localDeviceID: "display-123"))
        #expect(client.selectedSessionID == "ABCDEFGHJK")
        #expect(client.status.contains("different account"))
        #expect(!client.acceptEnrollment(Data("{}".utf8), authenticatedHostID: "host-123", localDeviceID: "display-123"))
        client.didPairLocalHost("offline-host-456")
        #expect(client.isLinked && client.selectedSessionID.isEmpty)
        #expect(client.selectedHostLocalID == "offline-host-456", "Pairing a new offline LAN host cannot leave a different cloud game selected")
        client.disconnect()
    }

    @Test("Cloud service selection remembers custom servers and migrates existing settings")
    func cloudServiceSelection() throws {
        let domain = "ScoreboardCloudServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let publicURL = "https://scoreboardcloud.studenttechsupport.com"
        let customURL = "https://scores.example.com"
        let fresh = ScoreboardCloudClient(preferences: defaults)
        #expect(fresh.serviceMode == .publicCloud && fresh.serviceURL == publicURL)
        #expect(fresh.selfHostedURL.isEmpty && !fresh.isLinked)

        fresh.selfHostedURL = customURL
        fresh.serviceMode = .selfHosted
        let restored = ScoreboardCloudClient(preferences: defaults)
        #expect(restored.serviceMode == .selfHosted && restored.serviceURL == customURL)
        restored.serviceMode = .publicCloud
        #expect(restored.serviceURL == publicURL && restored.selfHostedURL == customURL)
        restored.serviceMode = .selfHosted
        #expect(restored.serviceURL == customURL)
        restored.selectService(for: publicURL + "/")
        #expect(restored.serviceMode == .publicCloud && restored.selfHostedURL == customURL)
        restored.selectService(for: publicURL + ":8443")
        #expect(restored.serviceMode == .selfHosted, "A different port is a separate server")
        restored.resetServiceSettings()
        #expect(restored.serviceMode == .publicCloud && restored.selfHostedURL.isEmpty)
        #expect(defaults.string(forKey: "scoreboard.cloudServiceMode") == nil)

        defaults.set(customURL, forKey: "scoreboard.cloudServiceURL")
        let legacy = ScoreboardCloudClient(preferences: defaults)
        #expect(legacy.serviceMode == .selfHosted && legacy.serviceURL == customURL,
                "An upgrade cannot redirect an existing custom server to the public service")
        defaults.set(publicURL + "/", forKey: "scoreboard.cloudServiceURL")
        let legacyPublic = ScoreboardCloudClient(preferences: defaults)
        #expect(legacyPublic.serviceMode == .publicCloud && legacyPublic.selfHostedURL.isEmpty)
    }

    @Test("LAN and cloud commands share authority and deduplication while cloud outages preserve local play")
    func hybridCloudAndLAN() async throws {
        store.isWebControlEnabled = true
        store.isWebAPIEnabled = true
        store.setRemoteDisplayHostEnabled(true)
        defer { store.setWebAPIEnabled(false); store.setRemoteDisplayHostEnabled(false) }
        for _ in 0..<100 {
            if store.webAPIStatus.isRunning { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let port = try #require({ () -> UInt16? in
            guard case .running(let port, _, _) = store.webAPIStatus else { return nil }
            return port
        }())
        let sharedCommand = cmd("score.adjust", side: .home, value: 1)
        #expect(store.performCloudControlCommand(sharedCommand).success)
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/v2/control")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(store.webControlAPIKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try JSONEncoder().encode(sharedCommand)
        let (_, duplicateResponse) = try await URLSession.shared.data(for: request)
        #expect((duplicateResponse as? HTTPURLResponse)?.statusCode == 200)
        #expect(store.homeScore == 1, "A retry across cloud and LAN must apply only once")
        request.httpBody = try JSONEncoder().encode(cmd("score.adjust", side: .guest, value: 2))
        let (_, lanResponse) = try await URLSession.shared.data(for: request)
        #expect((lanResponse as? HTTPURLResponse)?.statusCode == 200 && store.guestScore == 2)
        let cloudState = store.currentWebAPIState().cloudControlPayload(allowed: true).remoteDisplayPayload
        #expect(cloudState.teams.home.score == 1 && cloudState.teams.guest.score == 2)
        store.resetClock(to: 60)
        #expect(store.performCloudControlCommand(cmd("clock.running", enabled: true)).success)
        ScoreboardCloudClient.shared.disconnect()
        store.advanceControlTestTimers(by: 2)
        #expect(store.isClockRunning && store.gameClockSeconds == 58)
        #expect(store.isRemoteDisplayHostEnabled && store.isWebAPIEnabled, "Internet/cloud loss cannot stop LAN integrations")
        #expect(store.performControlCommand(cmd("score.adjust", side: .home, value: 1, delay: 0), remote: true).success)
        #expect(store.homeScore == 2)
        store.withControlTestFollowingSessionHost {
            #expect(store.performCloudControlCommand(cmd("score.adjust", side: .home, value: 1)).error == "conflict")
        }
    }

    @Test("Cloud endpoints require an HTTPS origin and allow localhost development")
    func cloudEndpoints() throws {
        #expect(try ScoreboardCloudEndpoint.validate("https://scores.example.com").host == "scores.example.com")
        #expect(try ScoreboardCloudEndpoint.validate("http://localhost:8787").port == 8787)
        for value in ["http://scores.example.com", "https://user:secret@scores.example.com", "https://scores.example.com/path", "https://scores.example.com?token=x", "file:///tmp/test", ""] {
            #expect(throws: (any Error).self) { try ScoreboardCloudEndpoint.validate(value) }
        }
        ScoreboardCloudClient.shared.selectService(for: "https://scores.example.com")
        store.resetToFactoryDefaults()
        #expect(ScoreboardCloudClient.shared.serviceMode == .publicCloud && !ScoreboardCloudClient.shared.isLinked)
        #expect(ScoreboardCloudClient.shared.selfHostedURL.isEmpty)
    }

    @Test("Cloud receivers mirror the game, enforce permissions, and stop control on disconnect")
    func cloudReceiver() throws {
        let receiver = ScoreboardRemoteDisplayReceiver()
        var commands: [ScoreboardControlCommand] = []
        receiver.beginCloudConnection { commands.append($0) }
        defer { receiver.endCloudConnection() }
        let state = store.currentWebAPIState().cloudControlPayload(allowed: true).remoteDisplayPayload
        receiver.receiveCloudState(state, controlAllowed: false, hostName: "Court 1")
        #expect(receiver.status.isLive && !receiver.canSendControlCommand)
        receiver.sendCommand(cmd("score.adjust", side: .home, value: 1))
        #expect(commands.isEmpty)
        receiver.setCloudControlAllowed(true)
        #expect(receiver.canSendControlCommand)
        let command = cmd("score.adjust", side: .home, value: 1)
        receiver.sendCommand(command)
        #expect(commands.map(\.id) == [command.id])
        #expect(receiver.pendingControlCommandID == command.id)
        receiver.receiveCloudResult(.init(id: command.id, success: true, error: nil, message: nil))
        #expect(receiver.pendingControlCommandID == nil && receiver.controlResult?.success == true)
        let mirror = ScoreboardStore.makeRemoteControlStore(receiver: receiver)
        receiver.receiveCloudState(state, controlAllowed: true, hostName: "Court 1")
        #expect(mirror.homeScore == state.teams.home.score)
        let hostScore = store.homeScore
        mirror.adjustScore(isHome: true, by: 1)
        #expect(commands.last?.action == "score.adjust")
        #expect(store.homeScore == hostScore, "Cloud mirrors must not mutate the local authoritative game")
        receiver.cloudDisconnected("Host offline")
        #expect(!receiver.canSendControlCommand && !receiver.status.isLive)
        #expect(receiver.pendingControlCommandID == nil)
        receiver.setCloudControlAllowed(true)
        #expect(!receiver.canSendControlCommand, "Permission alone cannot make an offline receiver live")
    }

    @Test("Cloud commentary uses current game logs, bounds the timeline, and follows host authority")
    func cloudCommentator() throws {
        for _ in 0..<125 {
            #expect(store.performCloudControlCommand(cmd("score.adjust", side: .home, value: 1)).success)
        }
        let payload = try #require(store.currentCloudCommentatorPayload())
        #expect(payload.schemaVersion == 2 && payload.summary.home.score == 125)
        #expect(payload.entries.count == 120)
        #expect(payload.entries.contains { $0.kind == .scoreAdjustment && $0.side == .home })
        let wire = try JSONEncoder().encode(payload)
        #expect(wire.count < 1_048_576)
        store.withControlTestFollowingSessionHost {
            #expect(store.currentCloudCommentatorPayload() == nil)
        }
    }

    @Test("Cloud state preserves command data and excludes embedded game assets")
    func cloudStateWire() throws {
        let state = store.currentWebAPIState().cloudControlPayload(allowed: true).remoteDisplayPayload
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ScoreboardWebAPIState.self, from: data)
        #expect(decoded.game.sport == store.selectedSport)
        #expect(decoded.control?.remoteEnabled == true)
        #expect(decoded.control?.webEnabled == false)
        #expect(decoded.audio == nil)
        #expect(data.count < 1_048_576)
    }
}
