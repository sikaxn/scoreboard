import Foundation
import Network

/// Pairs with the real receiver over Bonjour and WebSocket, so layout checks
/// exercise the extra paired-device actions without changing application state.
nonisolated final class RemoteDisplayOperatorPeer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "scoreboard.ui-tests.operator")
    private var browser: NWBrowser?
    private var connection: NWConnection?

    func pair(displayID: String, code: String) {
        queue.async { [self] in
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_scorebrd-tv._tcp", domain: nil), using: parameters)
            self.browser = browser
            browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
                guard let self, self.browser === browser, self.connection == nil else { return }
                guard let result = results.first(where: {
                    guard case .bonjour(let record) = $0.metadata else { return false }
                    return record["displayID"] == displayID
                }) else { return }
                let transport = NWParameters.tcp
                transport.includePeerToPeer = true
                transport.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(.version13), at: 0)
                let connection = NWConnection(to: result.endpoint, using: transport)
                self.connection = connection
                connection.stateUpdateHandler = { state in
                    guard case .ready = state else { return }
                    let request: [String: Any] = [
                        "hostID": UUID().uuidString,
                        "hostName": "Paired operator with a long name to verify the connection panel fits",
                        "displayID": displayID, "pairingCode": code,
                        "pairingSecret": UUID().uuidString, "trustedReconnect": false,
                        "takeoverConfirmed": false
                    ]
                    guard let data = try? JSONSerialization.data(withJSONObject: request) else { return }
                    let context = NWConnection.ContentContext(identifier: "pairing-layout-test",
                        metadata: [NWProtocolWebSocket.Metadata(opcode: .binary)])
                    connection.send(content: data, contentContext: context, isComplete: true,
                                    completion: .contentProcessed { _ in })
                }
                connection.start(queue: self.queue)
            }
            browser.start(queue: queue)
        }
    }

    func stop() {
        queue.sync {
            browser?.cancel()
            browser = nil
            connection?.stateUpdateHandler = nil
            connection?.cancel()
            connection = nil
        }
    }
}
