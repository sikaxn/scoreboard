import Foundation
import Network
import XCTest

/// A local Companion HTTP endpoint. Its own queue keeps networking independent
/// of synchronous accessibility queries in the UI test process.
nonisolated final class CompanionPeer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "scoreboard.ui-tests.companion")
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var listeningPort: UInt16 = 0
    private var isReady = false
    private var receivedPaths: [String] = []
    private var receivedMethods: [String] = []
    private var requestObserver: (@Sendable () -> Void)?

    var port: UInt16 { queue.sync { listeningPort } }
    var ready: Bool { queue.sync { isReady } }
    var paths: [String] { queue.sync { receivedPaths } }
    var methods: [String] { queue.sync { receivedMethods } }
    var onRequest: (@Sendable () -> Void)? {
        get { queue.sync { requestObserver } }
        set { queue.sync { requestObserver = newValue } }
    }

    func start() throws {
        try queue.sync {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: listeningPort)!)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self, self.listener === listener else { return }
                if case .ready = state { self.listeningPort = listener?.port?.rawValue ?? 0; self.isReady = true }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                self.connections.append(connection)
                connection.start(queue: self.queue)
                self.receive(connection, buffer: Data())
            }
            listener.start(queue: queue)
        }
    }

    func stop() {
        queue.sync {
            isReady = false
            listener?.cancel()
            listener = nil
            connections.forEach { $0.cancel() }
            connections.removeAll()
        }
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self, error == nil else { return }
            var next = buffer
            if let data { next.append(data) }
            guard let text = String(data: next, encoding: .utf8), text.contains("\r\n\r\n") else {
                if !complete { self.receive(connection, buffer: next) }
                return
            }
            let request = text.components(separatedBy: " ")
            self.receivedMethods.append(request.first ?? "")
            self.receivedPaths.append(request.dropFirst().first ?? "")
            self.requestObserver?()
            let response = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}".utf8)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}

/// A display/client speaking the production Bonjour + WebSocket protocol. No
/// app transport is replaced. RTC is omitted to verify WebSocket fallback.
nonisolated final class RemoteDisplayPeer: @unchecked Sendable {
    let id = "ui-display-\(UUID().uuidString)"
    let name = "UI Test Display \(UUID().uuidString.prefix(6))"
    let pairingCode = "1234"
    private let queue = DispatchQueue(label: "scoreboard.ui-tests.remote-display")
    private let pairingSetID = UUID().uuidString
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var hostID: String?
    private var secret: String?
    private var version = ""
    private var build = ""
    private var isReady = false
    private var acceptedPairings = 0
    private var receivedStates = 0
    private var latestHomeScore: Int?
    private var receivedDisconnects = 0
    private var validationFailures: [String] = []
    private var events: [String] = []

    var ready: Bool { queue.sync { isReady } }
    var pairingCount: Int { queue.sync { acceptedPairings } }
    var stateCount: Int { queue.sync { receivedStates } }
    var homeScore: Int? { queue.sync { latestHomeScore } }
    var operatorDisconnectCount: Int { queue.sync { receivedDisconnects } }
    var errors: [String] { queue.sync { validationFailures } }
    var diagnostics: String { queue.sync { "Pairings: \(acceptedPairings), states: \(receivedStates), home score: \(String(describing: latestHomeScore)), errors: \(validationFailures)\n" + events.suffix(40).joined(separator: "\n") } }

    func start() throws {
        try queue.sync {
            if version.isEmpty {
                let url = try XCTUnwrap(Bundle(for: ScoreboardUITestCase.self)
                    .url(forResource: "Info", withExtension: "plist", subdirectory: "AppMetadata"),
                    "The native Copy Files phase must bundle the app's compatibility metadata")
                let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
                version = try XCTUnwrap(info["CFBundleShortVersionString"] as? String)
                build = try XCTUnwrap(info["CFBundleVersion"] as? String)
            }
            let parameters = NWParameters.tcp
            parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(.version13), at: 0)
            let listener = try NWListener(using: parameters)
            self.listener = listener
            var info = ["app": "Smart Scoreboard", "role": "display", "name": name,
                "displayID": id, "pairingSetID": pairingSetID, "deviceType": "ipad",
                "appVersion": version, "appBuild": build, "remoteStateVersions": "1",
                "receiverState": secret == nil ? "waitingUnpaired" : "waitingPaired",
                "allowsNewPairing": "true"]
            if let hostID {
                info["lastActiveOperatorID"] = hostID
                info["lastActiveOperatorName"] = "Test operator"
            }
            listener.service = NWListener.Service(name: name, type: "_scorebrd-tv._tcp",
                txtRecord: NetService.data(fromTXTRecord: info.mapValues { Data($0.utf8) }))
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self, self.listener === listener else { return }
                if case .ready = state { self.isReady = true }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                self.connections.append(connection)
                connection.start(queue: self.queue)
                self.receive(connection)
            }
            listener.start(queue: queue)
        }
    }

    func stop() {
        queue.sync {
            isReady = false
            listener?.cancel()
            listener = nil
            connections.forEach { $0.cancel() }
            connections.removeAll()
        }
    }

    private func receive(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let error { self.events.append("Receive failed: \(error)"); return }
            if let data, let packet = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.handle(packet, on: connection)
            }
            self.receive(connection)
        }
    }

    private func handle(_ packet: [String: Any], on connection: NWConnection) {
        events.append("Received \(packet["kind"] as? String ?? (packet["schemaVersion"] != nil ? "state" : "pairing"))")
        if packet["pairingCode"] != nil || packet["trustedReconnect"] != nil {
            if packet["trustedReconnect"] as? Bool == true {
                guard packet["pairingSecret"] as? String == secret else {
                    validationFailures.append("Reconnection did not reuse the saved pairing secret")
                    connection.cancel()
                    return
                }
            } else {
                guard packet["pairingCode"] as? String == pairingCode else {
                    validationFailures.append("Unexpected pairing code")
                    connection.cancel()
                    return
                }
                secret = packet["pairingSecret"] as? String
            }
            hostID = packet["hostID"] as? String
            acceptedPairings += 1
        } else if packet["kind"] as? String == "heartbeat" {
            let reply: [String: Any] = ["kind": "heartbeatAck", "sequence": packet["sequence"] ?? 0,
                "sentAt": packet["sentAt"] ?? Date().timeIntervalSince1970,
                "receivedAt": Date().timeIntervalSince1970,
                "hostID": hostID ?? "", "displayID": id, "displayName": name,
                "deviceType": "ipad", "appVersion": version, "appBuild": build]
            if let data = try? JSONSerialization.data(withJSONObject: reply) {
                let context = NWConnection.ContentContext(identifier: "remote-ui-test", metadata: [NWProtocolWebSocket.Metadata(opcode: .binary)])
                connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self] error in
                    self?.events.append(error.map { "Ack failed: \($0)" } ?? "Ack sent")
                })
            }
        } else if packet["kind"] as? String == "disconnect" {
            receivedDisconnects += 1
            connection.cancel()
        } else if packet["schemaVersion"] != nil {
            receivedStates += 1
            latestHomeScore = (packet["game"] as? [String: Any])?["homeScore"] as? Int
        }
    }
}
