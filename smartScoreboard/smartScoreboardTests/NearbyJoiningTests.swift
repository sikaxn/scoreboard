import Foundation
import Testing

extension ScoreboardTests {
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
