
// Appended to a temporary copy of the receiver by run_remote_control_tests.py.
// This fixture never belongs to the app target and does not advertise or open sockets.
@MainActor
enum ScoreboardControlTestTransport {
    static var packets: [Data] = []
}

@MainActor
extension ScoreboardRemoteDisplayHostService {
    func refreshControlTestTrustedDisplay(_ peer: ScoreboardRemoteDisplayTrustedPeer) {
        trustDisplay(id: peer.id, name: peer.name, pairingSetID: peer.pairingSetID,
                     deviceType: peer.deviceType, pairingSecret: peer.pairingSecret)
    }
}

@MainActor
extension ScoreboardRemoteDisplayReceiver {
    func configureControlTestConnection(state: ScoreboardWebAPIState) {
        self.state = state
        status = .paired("Test main board")
        pairedHostID = "test-main-host"
        pairedHostName = "Test main board"
        pairedConnection = NWConnection(host: "127.0.0.1", port: 1, using: .tcp)
        masterClockOffset = 0
        lastClockSyncAt = Date()
        lastReceivedAt = Date()
        isRemoteControlAvailable = state.control?.remoteEnabled == true
        isControlBoardDevice = isRemoteControlAvailable
    }

    func receiveControlTestMessage(_ message: ScoreboardRemoteDisplayControlMessage) {
        handleControlMessage(message, from: pairedConnection!)
    }

    func disconnectControlTestConnection() {
        clearControlConnection()
        status = .disconnected("Test connection lost")
    }

    func simulateSilentControlTestDisconnect() {
        lastHeartbeatAt = Date().addingTimeInterval(-6)
        lastClockSyncAt = Date().addingTimeInterval(-6)
    }

    func checkControlTestConnectionHealth() {
        markStaleHostIfNeeded()
    }
}
