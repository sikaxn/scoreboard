import Foundation
@preconcurrency import LiveKitWebRTC

/// Signaling follows the existing connection’s access policy, never discovery.
nonisolated struct ScoreboardRTCSignal: Codable, Sendable {
    enum Kind: String, Codable, Sendable { case offer, answer, candidate, close }
    var kind: Kind
    var negotiationID: UUID
    var sdp: String? = nil
    var sdpMid: String? = nil
    var sdpMLineIndex: Int32? = nil
}

/// Data-only WebRTC. All libwebrtc calls, including teardown, stay off the UI
/// thread. A peer belongs to one authenticated WebSocket connection and cannot
/// survive a reconnect or host handoff. No STUN/TURN or external signaling.
nonisolated final class ScoreboardRTCPeer: NSObject, @unchecked Sendable {
    static let protocolVersion = 1
    static let maximumMessageBytes = 48 * 1024
    private static let maximumBufferedBytes = 256 * 1024
    private static let rtcQueue = DispatchQueue(label: "scoreboard.rtc", qos: .userInteractive)
    nonisolated(unsafe) private static let factory: LKRTCPeerConnectionFactory = {
        LKRTCInitializeSSL()
        return LKRTCPeerConnectionFactory(encoderFactory: nil, decoderFactory: nil)
    }()

    let negotiationID: UUID
    private let isOfferer: Bool
    private let callbackQueue: DispatchQueue
    private let onSignal: @Sendable (ScoreboardRTCSignal) -> Void
    private let onData: @Sendable (Data) -> Void
    private let onReady: @Sendable (Bool) -> Void
    private let lock = NSLock()
    // Protected by lock. The WebRTC objects below are rtcQueue-only.
    private var ready = false
    private var closed = false
    private var reservedBytes = 0
    private var peer: LKRTCPeerConnection?
    private var channel: LKRTCDataChannel?
    private var pendingCandidates: [ScoreboardRTCSignal] = []
    private var remoteDescriptionSet = false
    private var descriptionStarted = false
    private var localDescriptionPublished = false
    private var localCandidates: [ScoreboardRTCSignal] = []

    init(negotiationID: UUID = UUID(), isOfferer: Bool,
         callbackQueue: DispatchQueue = .main,
         onSignal: @escaping @Sendable (ScoreboardRTCSignal) -> Void,
         onData: @escaping @Sendable (Data) -> Void,
         onReady: @escaping @Sendable (Bool) -> Void) {
        self.negotiationID = negotiationID
        self.isOfferer = isOfferer
        self.callbackQueue = callbackQueue
        self.onSignal = onSignal
        self.onData = onData
        self.onReady = onReady
        super.init()
        Self.rtcQueue.async { [self] in
            guard !isClosed else { return }
            let config = LKRTCConfiguration()
            config.iceServers = []
            config.sdpSemantics = .unifiedPlan
            config.tcpCandidatePolicy = .disabled
            peer = Self.factory.peerConnection(with: config,
                constraints: LKRTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: self)
            guard let peer else { close(); return }
            if isOfferer {
                let config = LKRTCDataChannelConfiguration()
                config.isOrdered = true
                channel = peer.dataChannel(forLabel: "scoreboard.reliable.v1", configuration: config)
                channel?.delegate = self
                guard channel != nil else { close(); return }
                makeDescription(offer: true)
            }
        }
        Self.rtcQueue.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, !self.isReady else { return }
            self.close()
        }
    }

    var isReady: Bool { lock.withLock { ready && !closed } }
    private var isClosed: Bool { lock.withLock { closed } }

    /// False means use the existing transport immediately. Never block the UI
    /// waiting for RTC or accumulate an unbounded queue of timer snapshots.
    func send(_ data: Data) -> Bool {
        guard !data.isEmpty, data.count <= Self.maximumMessageBytes else { return false }
        let accepted = lock.withLock {
            guard ready, !closed, reservedBytes + data.count <= Self.maximumBufferedBytes else { return false }
            reservedBytes += data.count
            return true
        }
        guard accepted else { return false }
        Self.rtcQueue.async { [self] in
            defer { lock.withLock { reservedBytes -= data.count } }
            guard !isClosed, let channel, channel.readyState == .open,
                  channel.bufferedAmount < UInt64(Self.maximumBufferedBytes),
                  channel.sendData(LKRTCDataBuffer(data: data, isBinary: false)) else {
                close()
                return
            }
        }
        return true
    }

    func receive(_ signal: ScoreboardRTCSignal) {
        guard signal.negotiationID == negotiationID,
              (signal.sdp?.utf8.count ?? 0) <= 64 * 1024 else { return }
        Self.rtcQueue.async { [self] in
            guard !isClosed, let peer else { return }
            switch signal.kind {
            case .close:
                close(notifyRemote: false)
            case .candidate:
                guard let sdp = signal.sdp, !sdp.isEmpty, let index = signal.sdpMLineIndex, index >= 0 else { return }
                if !remoteDescriptionSet {
                    guard pendingCandidates.count < 128 else { close(); return }
                    pendingCandidates.append(signal)
                } else {
                    addCandidate(signal)
                }
            case .offer, .answer:
                guard !descriptionStarted, let sdp = signal.sdp,
                      !sdp.isEmpty, (signal.kind == .offer) != isOfferer else { return }
                descriptionStarted = true
                let description = LKRTCSessionDescription(type: signal.kind == .offer ? .offer : .answer, sdp: sdp)
                peer.setRemoteDescription(description) { [weak self] error in
                    Self.rtcQueue.async {
                        guard let self, !self.isClosed else { return }
                        guard error == nil else { self.close(); return }
                        self.remoteDescriptionSet = true
                        for candidate in self.pendingCandidates { self.addCandidate(candidate) }
                        self.pendingCandidates.removeAll()
                        if !self.isOfferer { self.makeDescription(offer: false) }
                    }
                }
            }
        }
    }

    private func addCandidate(_ signal: ScoreboardRTCSignal) {
        guard let sdp = signal.sdp, let index = signal.sdpMLineIndex else { return }
        peer?.add(LKRTCIceCandidate(sdp: sdp, sdpMLineIndex: index, sdpMid: signal.sdpMid)) { [weak self] error in
            if error != nil { self?.close() }
        }
    }

    private func makeDescription(offer: Bool) {
        guard let peer, !isClosed else { return }
        let constraints = LKRTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let completion: (LKRTCSessionDescription?, Error?) -> Void = { [weak self] description, error in
            Self.rtcQueue.async {
                guard let self, !self.isClosed else { return }
                guard let description, error == nil else { self.close(); return }
                self.peer?.setLocalDescription(description) { [weak self] error in
                    guard let self else { return }
                    Self.rtcQueue.async {
                        guard !self.isClosed else { return }
                        if error != nil { self.close(); return }
                        // SDP must be signaled before its trickled ICE candidates.
                        self.emit(.init(kind: offer ? .offer : .answer, negotiationID: self.negotiationID, sdp: description.sdp))
                        self.localDescriptionPublished = true
                        for signal in self.localCandidates { self.emit(signal) }
                        self.localCandidates.removeAll()
                    }
                }
            }
        }
        if offer { peer.offer(for: constraints, completionHandler: completion) }
        else { peer.answer(for: constraints, completionHandler: completion) }
    }

    private func emit(_ signal: ScoreboardRTCSignal) {
        callbackQueue.async { [self] in
            guard !isClosed || signal.kind == .close else { return }
            onSignal(signal)
        }
    }

    func close(notifyRemote: Bool = true) {
        let didClose = lock.withLock {
            guard !closed else { return false }
            closed = true
            ready = false
            return true
        }
        guard didClose else { return }
        if notifyRemote { emit(.init(kind: .close, negotiationID: negotiationID)) }
        callbackQueue.async { [self] in onReady(false) }
        Self.rtcQueue.async { [self] in
            channel?.delegate = nil
            channel?.close()
            channel = nil
            peer?.delegate = nil
            peer?.close()
            peer = nil
            pendingCandidates.removeAll()
            localCandidates.removeAll()
        }
    }
}

extension ScoreboardRTCPeer: LKRTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: LKRTCDataChannel) {
        let state = dataChannel.readyState
        if state == .closed || state == .closing { close(); return }
        guard state == .open else { return }
        let changed = lock.withLock {
            guard !closed, !ready else { return false }
            ready = true
            return true
        }
        if changed { callbackQueue.async { [self] in onReady(true) } }
    }

    func dataChannel(_ dataChannel: LKRTCDataChannel, didReceiveMessageWith buffer: LKRTCDataBuffer) {
        let data = buffer.data
        guard !isClosed, data.count <= Self.maximumMessageBytes else { return }
        callbackQueue.async { [self] in
            guard !isClosed else { return }
            onData(data)
        }
    }
}

extension ScoreboardRTCPeer: LKRTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        if newState == .failed || newState == .disconnected || newState == .closed { close() }
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        let signal = ScoreboardRTCSignal(kind: .candidate, negotiationID: negotiationID, sdp: candidate.sdp,
                                         sdpMid: candidate.sdpMid, sdpMLineIndex: candidate.sdpMLineIndex)
        Self.rtcQueue.async { [self] in
            guard !isClosed else { return }
            if localDescriptionPublished { emit(signal) }
            else if localCandidates.count < 128 { localCandidates.append(signal) }
            else { close() }
        }
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {
        Self.rtcQueue.async { [self] in
            guard !isClosed, !isOfferer, channel == nil,
                  dataChannel.label == "scoreboard.reliable.v1", dataChannel.isOrdered else {
                dataChannel.close()
                return
            }
            channel = dataChannel
            channel?.delegate = self
            dataChannelDidChangeState(dataChannel)
        }
    }
}
