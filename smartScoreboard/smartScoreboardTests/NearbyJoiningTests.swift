import Foundation
import Testing

extension ScoreboardTests {
    @Test("Nearby reconnect proves saved trust without passwords and binds fresh challenges to the match, host, device and request")
    func nearbyReconnectProofs() throws {
        let secret = "existing-high-entropy-pairing-secret"
        let hello = ScoreboardNearbyReconnect.Hello(matchID: UUID(), hostID: "selected-host", displayID: "paired-client")
        let challenge = try ScoreboardNearbyReconnect.challenge(hello: hello, secret: secret)
        let payload = Data("{\"control\":false,\"displayID\":\"paired-client\"}".utf8)
        let response = try ScoreboardNearbyReconnect.response(to: challenge, hello: hello, secret: secret, request: payload)
        #expect(try ScoreboardNearbyReconnect.verify(response, challenge: challenge, hello: hello, secret: secret) == payload)
        let wire = try JSONEncoder().encode(challenge) + JSONEncoder().encode(response)
        #expect(!String(decoding: wire, as: UTF8.self).contains(secret))
        #expect(throws: (any Error).self) {
            try ScoreboardNearbyReconnect.response(to: challenge, hello: hello, secret: "wrong-secret", request: payload)
        }
        let fresh = try ScoreboardNearbyReconnect.challenge(hello: hello, secret: secret)
        #expect(throws: (any Error).self) {
            try ScoreboardNearbyReconnect.verify(response, challenge: fresh, hello: hello, secret: secret)
        }
        var tampered = response; tampered.request = Data("{\"control\":true}".utf8)
        #expect(throws: (any Error).self) {
            try ScoreboardNearbyReconnect.verify(tampered, challenge: challenge, hello: hello, secret: secret)
        }
        tampered = response; tampered.proof = challenge.proof
        #expect(throws: (any Error).self) {
            try ScoreboardNearbyReconnect.verify(tampered, challenge: challenge, hello: hello, secret: secret)
        }
        for field in ["match", "host", "client"] {
            var foreign = hello
            if field == "match" { foreign.matchID = UUID() }
            if field == "host" { foreign.hostID = "another-host" }
            if field == "client" { foreign.displayID = "another-client" }
            #expect(throws: (any Error).self) {
                try ScoreboardNearbyReconnect.response(to: challenge, hello: foreign, secret: secret, request: payload)
            }
            #expect(throws: (any Error).self) {
                try ScoreboardNearbyReconnect.verify(response, challenge: challenge, hello: foreign, secret: secret)
            }
        }
    }

    @Test("A selected paired host reconnects without a PIN while foreign hosts, wrong secrets and fresh pairing are rejected")
    func nearbySavedPairingReconnect() {
        let receiver = ScoreboardRemoteDisplayReceiver()
        receiver.configureNearbyJoinTestHistory(hostID: "selected-host")
        #expect(receiver.savedNearbyPairing(hostID: "selected-host") != nil)
        receiver.beginNearbyMatchJoin(hostID: "selected-host", reconnecting: true)
        #expect(!receiver.receiveNearbyJoinTestPairing(hostID: "foreign-host", code: "", trusted: true))
        #expect(!receiver.receiveNearbyJoinTestPairing(hostID: "selected-host", code: "", trusted: true, secret: "wrong-secret"))
        #expect(!receiver.receiveNearbyJoinTestPairing(hostID: "selected-host", code: receiver.pairingCode))
        #expect(receiver.receiveNearbyJoinTestPairing(hostID: "selected-host", code: "", trusted: true))
        receiver.finishNearbyMatchJoin(connected: true)
        #expect(receiver.connectedHostID == "selected-host")
        #expect(receiver.trustedHosts.first?.pairingSecret == "previous-secret")
        receiver.requireNewNearbyPairing(hostID: "selected-host")
        #expect(receiver.savedNearbyPairing(hostID: "selected-host") == nil)
        receiver.beginNearbyMatchJoin(hostID: "selected-host")
        #expect(receiver.receiveNearbyJoinTestPairing(hostID: "selected-host", code: receiver.pairingCode))
        receiver.finishNearbyMatchJoin(connected: true)
        #expect(receiver.savedNearbyPairing(hostID: "selected-host")?.pairingSecret == "new-secret")
    }

    @Test("Explicit nearby joining switches remembered hosts without forgetting trust or accepting the old host")
    func nearbyJoinSwitchesRememberedHost() {
        let receiver = ScoreboardRemoteDisplayReceiver()
        receiver.configureNearbyJoinTestHistory(hostID: "previous-host")
        #expect(receiver.nearbyJoinTestDiscovery["requiresTakeoverWarning"] == "true")
        receiver.beginNearbyMatchJoin(hostID: "selected-host")
        let code = receiver.pairingCode
        #expect(receiver.nearbyJoinTestDiscovery["allowsNewPairing"] == "true")
        #expect(receiver.nearbyJoinTestDiscovery["requiresTakeoverWarning"] == "false")
        receiver.rotateNearbyJoinTestPIN()
        #expect(receiver.pairingCode == code, "host confirmation must not outlive the request's PIN")
        #expect(!receiver.receiveNearbyJoinTestPairing(hostID: "previous-host", code: code, trusted: true))
        #expect(!receiver.receiveNearbyJoinTestPairing(hostID: "another-host", code: code))
        #expect(!receiver.receiveNearbyJoinTestPairing(hostID: "selected-host", code: "invalid"))
        #expect(receiver.receiveNearbyJoinTestPairing(hostID: "selected-host", code: code))
        receiver.finishNearbyMatchJoin(connected: true)
        #expect(receiver.connectedHostID == "selected-host")
        #expect(receiver.trustedHosts.contains { $0.id == "previous-host" })
        #expect(receiver.trustedHosts.contains { $0.id == "selected-host" })
    }

    @Test("Cancelling a nearby join closes its pairing window and preserves saved hosts")
    func nearbyJoinCancellation() {
        let receiver = ScoreboardRemoteDisplayReceiver()
        receiver.configureNearbyJoinTestHistory(hostID: "previous-host")
        receiver.beginNearbyMatchJoin(hostID: "selected-host")
        receiver.finishNearbyMatchJoin(connected: false)
        #expect(receiver.nearbyJoinTestDiscovery["requiresTakeoverWarning"] == "true")
        #expect(receiver.trustedHosts.map(\.id) == ["previous-host"])
        #expect(receiver.state == nil)
    }

    @Test("Nearby confirmation uses a bounded countdown and expires at its deadline")
    func nearbyApprovalCountdown() {
        let now = Date(timeIntervalSince1970: 10_000)
        let approval = ScoreboardNearbyJoinApproval(id: "display", name: "iPad", requestsControl: true,
            matchID: UUID(), expiresAt: now.addingTimeInterval(60))
        #expect(approval.remainingSeconds(at: now) == 60)
        #expect(approval.remainingSeconds(at: now.addingTimeInterval(59.2)) == 1)
        #expect(approval.remainingSeconds(at: now.addingTimeInterval(60)) == 0)
        #expect(approval.remainingSeconds(at: now.addingTimeInterval(80)) == 0)
    }
}
