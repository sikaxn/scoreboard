import Foundation
import Testing

extension ScoreboardTests {
    private var connectionTestSession: ScoreboardSessionDescriptor {
        ScoreboardSessionDescriptor(sessionID: UUID(), epoch: 2, ownerDeviceID: "owner", ownerHostID: "owner-pairing",
            ownerName: "Owner iPad", hostDeviceID: "host", hostName: "Host TV", hostAddresses: [])
    }

    @Test("Host-centric clients include a non-host owner with link telemetry")
    func ownerIsAClientOfDelegatedHost() throws {
        let session = connectionTestSession
        let peers = [
            ScoreboardSessionPeer(id: "host", name: "Host TV", deviceType: .appleTV, connected: true, supportsHosting: true),
            ScoreboardSessionPeer(id: "owner", name: "iPad", deviceType: .ipad, connected: true, supportsHosting: true,
                latencyMilliseconds: 17, quality: .poor, realtimeTransport: "WebRTC"),
            ScoreboardSessionPeer(id: "display", name: "Court Display", deviceType: .mac, connected: false, supportsHosting: true)
        ]
        let clients = session.clientPeers(from: peers, ownerConnected: true)
        #expect(clients.map(\.id) == ["owner", "display"])
        let owner = try #require(clients.first)
        #expect(owner.name == "Owner iPad" && owner.controlEnabled == true && owner.connected)
        #expect(owner.latencyMilliseconds == 17 && owner.quality == .poor && owner.realtimeTransport == "WebRTC")
        let disconnected = session.clientPeers(from: peers, ownerConnected: false)
        #expect(disconnected.first?.connected == false && disconnected.first?.quality == .unresponsive)
    }

    @Test("Owner-host is excluded, legacy owner rows are supplied, and duplicates are safe")
    func connectionClientCompatibility() {
        var session = connectionTestSession
        let host = ScoreboardSessionPeer(id: "host", name: "Host TV", deviceType: .appleTV, connected: true, supportsHosting: true)
        let clients = session.clientPeers(from: [host, host], ownerConnected: false)
        #expect(clients.count == 1 && clients[0].id == "owner" && !clients[0].connected)
        session.hostDeviceID = "owner"
        let owner = ScoreboardSessionPeer(id: "owner", name: "Owner", deviceType: .ipad, connected: true, supportsHosting: true)
        #expect(session.clientPeers(from: [owner, host], ownerConnected: true).map(\.id) == ["host"])
    }

    @Test("Remote control counts and device rows share the same host-centric projection")
    func remoteConnectionCountsIncludeOwner() throws {
        var state = store.currentWebAPIState()
        state.control?.session = connectionTestSession
        state.control?.ownerConnected = false
        state.control?.devices = [
            ScoreboardSessionPeer(id: "host", name: "Host", deviceType: .appleTV, connected: true, supportsHosting: true),
            ScoreboardSessionPeer(id: "client", name: "Client", deviceType: .mac, connected: true, supportsHosting: true)
        ]
        let mirror = ScoreboardStore.makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver())
        mirror.applyRemoteControlState(state)
        let clients = try #require(mirror.remoteSessionDevices)
        #expect(Set(clients.map(\.id)) == ["owner", "client"])
        #expect(mirror.remoteSessionDeviceCounts?.connected == 1)
        #expect(mirror.remoteSessionDeviceCounts?.disconnected == 1)
    }

    @Test("The following owner uses its own link status over a stale host report")
    func followingOwnerConnectionStatus() {
        store.withControlTestFollowingSessionHost {
            guard let session = store.sessionDescriptor else {
                Issue.record("The following-owner fixture must provide its session")
                return
            }
            var state = store.currentWebAPIState()
            state.control?.session = session
            state.control?.ownerConnected = true
            state.control?.devices = [
                ScoreboardSessionPeer(id: session.ownerDeviceID, name: session.ownerName, deviceType: .unknown,
                    connected: true, supportsHosting: true, quality: .live)
            ]
            store.applyRemoteControlState(state)
            let owner = store.remoteSessionDevices?.first
            #expect(owner?.id == store.localSessionDeviceID && owner?.connected == false)
            #expect(owner?.quality == .unresponsive && owner?.deviceType == .current)
            #expect(store.remoteSessionDeviceCounts?.connected == 0)
            #expect(store.remoteSessionDeviceCounts?.disconnected == 1)
        }
    }
}
