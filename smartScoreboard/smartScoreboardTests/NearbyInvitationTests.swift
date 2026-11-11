import Foundation
import Testing

extension ScoreboardTests {
    private func invitationFixture() throws -> ScoreboardNearbyCloudInvitation {
        try ScoreboardInvitationPAKE.makeVerifier(.init(enabled: true, code: "ABCDEFGHJK", revision: "revision-1",
            salt: "00000000-0000-0000-0000-000000000001",
            hash: "3697e801a81fbe6f8804f67c124191f5a41a58a79c3fb1644e2aada908c5546a", matchID: UUID()),
            server: "https://scores.example.test/", hostID: "native-host")
    }

    @Test("Offline invitation PAKE authenticates both devices and encrypts the pairing PIN")
    func offlineInvitationAuthentication() async throws {
        let invitation = try invitationFixture()
        #expect(try ScoreboardInvitationPAKE.passwordHash("courtside-123", salt: invitation.passwordSalt) ==
            "3697e801a81fbe6f8804f67c124191f5a41a58a79c3fb1644e2aada908c5546a")
        let client = ScoreboardInvitationPAKE(), host = ScoreboardInvitationPAKE()
        let publicKey = try await client.beginClient()
        let challenge = try await host.beginServer(clientKey: publicKey, invitation: invitation)
        let proof = try await client.clientProof(challenge: challenge, password: "courtside-123", username: invitation.username)
        let answer = try await host.verifyClient(proof, invitation: invitation)
        let payload = Data("{\"displayCode\":\"1234\"}".utf8)
        let sealed = try await client.verifyServerAndSeal(answer, payload: payload)
        #expect(sealed != payload)
        #expect(try await host.open(sealed) == payload)
        await #expect(throws: (any Error).self) { try await host.open(sealed) }
        // Persisted host material has no plaintext password or PBKDF2 hash.
        let saved = try JSONEncoder().encode(invitation)
        let restored = try JSONDecoder().decode(ScoreboardNearbyCloudInvitation.self, from: saved)
        #expect(restored == invitation)
        #expect(!String(decoding: saved, as: UTF8.self).contains("courtside-123"))
        #expect(!String(decoding: saved, as: UTF8.self).contains("3697e801"))
    }

    @Test("Nearby invitations reject wrong passwords, foreign identity, stale proofs and invalid keys")
    func offlineInvitationRejectsImpersonation() async throws {
        let invitation = try invitationFixture()
        for username in [invitation.username, invitation.username + "other-match"] {
            let client = ScoreboardInvitationPAKE(), host = ScoreboardInvitationPAKE()
            let key = try await client.beginClient()
            let challenge = try await host.beginServer(clientKey: key, invitation: invitation)
            let proof = try await client.clientProof(challenge: challenge,
                password: username == invitation.username ? "wrong-password" : "courtside-123", username: username)
            await #expect(throws: (any Error).self) { try await host.verifyClient(proof, invitation: invitation) }
        }
        let client = ScoreboardInvitationPAKE(), host = ScoreboardInvitationPAKE(), otherHost = ScoreboardInvitationPAKE()
        let key = try await client.beginClient()
        let challenge = try await host.beginServer(clientKey: key, invitation: invitation)
        let proof = try await client.clientProof(challenge: challenge, password: "courtside-123", username: invitation.username)
        _ = try await otherHost.beginServer(clientKey: key, invitation: invitation)
        await #expect(throws: (any Error).self) { try await otherHost.verifyClient(proof, invitation: invitation) }
        await #expect(throws: (any Error).self) { try await client.verifyServerAndSeal(Data(repeating: 0, count: 32), payload: Data()) }
        await #expect(throws: (any Error).self) {
            try await ScoreboardInvitationPAKE().beginServer(clientKey: Data(repeating: 0, count: 384), invitation: invitation)
        }
        let malformedClient = ScoreboardInvitationPAKE()
        _ = try await malformedClient.beginClient()
        var malformedChallenge = challenge
        malformedChallenge.passwordSalt = ""
        await #expect(throws: (any Error).self) {
            try await malformedClient.clientProof(challenge: malformedChallenge, password: "courtside-123", username: invitation.username)
        }
        #expect(invitation.matches(server: nil, code: invitation.code, matchID: invitation.matchID, hostID: invitation.hostID))
        #expect(!invitation.matches(server: "https://another.example.test", code: invitation.code, matchID: invitation.matchID, hostID: invitation.hostID))
        #expect(!invitation.matches(server: nil, code: invitation.code, matchID: UUID(), hostID: invitation.hostID))
    }

    @Test("Joined match routing never selects cached scores from another match")
    func invitationRouteIsolation() {
        let target = UUID(), other = UUID()
        for mode: ScoreboardRemoteDisplayNetworkMode in [.preferLocal, .preferCloud] {
            #expect(ScoreboardRemoteRoute.choose(mode: mode, localFresh: true, cloudFresh: true,
                sameHost: false, current: .cloud, hasPendingCommand: false,
                targetMatchID: target, localMatchID: target, cloudMatchID: other) == .local)
            #expect(ScoreboardRemoteRoute.choose(mode: mode, localFresh: true, cloudFresh: true,
                sameHost: false, current: .local, hasPendingCommand: false,
                targetMatchID: target, localMatchID: other, cloudMatchID: target) == .cloud)
        }
        let receiver = ScoreboardRemoteDisplayReceiver()
        receiver.beginCloudConnection { _ in }
        receiver.bindJoinedMatch(target)
        let foreign = store.currentWebAPIState()
        #expect(foreign.game.matchID != target)
        receiver.receiveCloudState(foreign, controlAllowed: true, hostName: "Another match")
        #expect(receiver.state == nil && receiver.lastReceivedAt == nil)
        receiver.bindJoinedMatch(foreign.game.matchID)
        receiver.receiveCloudState(foreign, controlAllowed: false, hostName: "Selected match")
        #expect(receiver.state?.game.matchID == foreign.game.matchID)
        receiver.bindJoinedMatch(target)
        #expect(receiver.state == nil)
    }

    @Test("Invitation pairings expire with their match or password while independent LAN pairings remain")
    func invitationPairingScope() throws {
        let host = ScoreboardRemoteDisplayHostService(), matchID = UUID()
        var guest = ScoreboardRemoteDisplayTrustedPeer(id: "invited-display", name: "Guest", pairingSecret: "ephemeral-guest-secret")
        guest.invitationMatchID = matchID; guest.invitationRevision = "revision-1"
        let independent = ScoreboardRemoteDisplayTrustedPeer(id: "local-display", name: "Independent", pairingSecret: "local-secret")
        #expect(guest.allowsNearbyReconnect(matchID: matchID, invitationRevision: "revision-1"))
        #expect(!guest.allowsNearbyReconnect(matchID: UUID(), invitationRevision: "revision-1"))
        #expect(!guest.allowsNearbyReconnect(matchID: matchID, invitationRevision: "revision-2"))
        #expect(!guest.allowsNearbyReconnect(matchID: matchID, invitationRevision: nil))
        #expect(independent.allowsNearbyReconnect(matchID: UUID(), invitationRevision: nil))
        host.refreshControlTestTrustedDisplay(guest); host.refreshControlTestTrustedDisplay(independent)
        host.removeExpiredInvitationPairings(matchID: matchID, revision: "revision-1")
        #expect(host.trustedDisplays.contains { $0.id == guest.id })
        host.removeExpiredInvitationPairings(matchID: matchID, revision: "revision-2")
        #expect(!host.trustedDisplays.contains { $0.id == guest.id })
        #expect(host.trustedDisplays.contains { $0.id == independent.id })
        host.refreshControlTestTrustedDisplay(guest)
        host.removeExpiredInvitationPairings(matchID: UUID(), revision: "revision-1")
        #expect(!host.trustedDisplays.contains { $0.id == guest.id })
        #expect(host.trustedDisplays.contains { $0.id == independent.id })
    }

    @Test("Invitation channels detect tampering and password rotation invalidates previous proofs")
    func offlineInvitationRotationAndTamper() async throws {
        let invitation = try invitationFixture()
        let client = ScoreboardInvitationPAKE(), host = ScoreboardInvitationPAKE()
        let challenge = try await host.beginServer(clientKey: client.beginClient(), invitation: invitation)
        let proof = try await client.clientProof(challenge: challenge, password: "courtside-123", username: invitation.username)
        let answer = try await host.verifyClient(proof, invitation: invitation)
        var sealed = try await client.verifyServerAndSeal(answer, payload: Data("pairing-pin".utf8))
        sealed[sealed.count - 1] ^= 1
        await #expect(throws: (any Error).self) { try await host.open(sealed) }
        let rotated = try ScoreboardInvitationPAKE.makeVerifier(.init(enabled: true, code: invitation.code, revision: "revision-2",
            salt: invitation.passwordSalt, hash: String(repeating: "a", count: 64), matchID: invitation.matchID),
            server: invitation.server, hostID: invitation.hostID)
        let newClient = ScoreboardInvitationPAKE(), newHost = ScoreboardInvitationPAKE()
        let next = try await newHost.beginServer(clientKey: newClient.beginClient(), invitation: rotated)
        let staleProof = try await newClient.clientProof(challenge: next, password: "courtside-123", username: rotated.username)
        await #expect(throws: (any Error).self) { try await newHost.verifyClient(staleProof, invitation: rotated) }
        let legacy = ScoreboardRemoteDisplayTrustedPeer(id: "display", name: "Display", pairingSecret: "secret")
        let decoded = try JSONDecoder().decode(ScoreboardRemoteDisplayTrustedPeer.self, from: JSONEncoder().encode(legacy))
        #expect(decoded.invitationMatchID == nil && decoded.invitationRevision == nil)
    }
}
