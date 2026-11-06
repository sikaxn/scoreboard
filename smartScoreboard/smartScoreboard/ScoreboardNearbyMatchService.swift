import Foundation
import Combine
import Network

nonisolated struct ScoreboardNearbyMatch: Identifiable, Sendable {
    var id: String
    var matchID: UUID
    var title: String
    var ownerName: String
    var endpoint: NWEndpoint
}

nonisolated struct ScoreboardNearbyInvitation: Equatable {
    var ownerID: String
    var code: String
    var url: URL? {
        var parts = URLComponents(); parts.scheme = "smartscoreboard"; parts.host = "nearby"
        parts.queryItems = [.init(name: "owner", value: ownerID), .init(name: "code", value: code)]
        return parts.url
    }
    static func parse(_ value: String) -> Self? {
        guard let parts = URLComponents(string: value), parts.scheme == "smartscoreboard", parts.host == "nearby",
              let owner = parts.queryItems?.first(where: { $0.name == "owner" })?.value, !owner.isEmpty,
              let code = parts.queryItems?.first(where: { $0.name == "code" })?.value,
              code.count == 6, code.allSatisfy(\.isNumber) else { return nil }
        return .init(ownerID: owner, code: code)
    }
}

/// Match discovery arranges the existing authenticated display pairing in reverse.
/// The short-lived request channel never carries game state or owner credentials.
@MainActor final class ScoreboardNearbyMatchService: ObservableObject {
    static let shared = ScoreboardNearbyMatchService()
    static let serviceType = "_scorebrd-join._tcp"
    struct Approval: Identifiable {
        var id: String
        var name: String
        var requestsControl: Bool
        var matchID: UUID
    }
    @Published private(set) var approvals: [Approval] = []
    private var approvalConnections: [String: (JoinRequest, NWConnection)] = [:]
    @Published private(set) var matches: [ScoreboardNearbyMatch] = []
    @Published private(set) var joinCode = String(format: "%06d", Int.random(in: 0...999_999))
    @Published private(set) var requestedControllers: Set<String> = []
    @Published private(set) var discoveryError: String?
    @Published private(set) var discoveryNeedsPermission = false
    private weak var owner: ScoreboardStore?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var advertisedMatchID: UUID?
    private var advertisedPeerToPeer: Bool?
    private var lastAdvertisement: Data?
    private var pending: [ObjectIdentifier: NWConnection] = [:]
    private var failures: [String: (count: Int, date: Date)] = [:]
    private var requestConnection: NWConnection?
    private var requestCompletion: ((Result<Void, Error>) -> Void)?
    private var requestTimeout: Task<Void, Never>?
    private var browserConsumers = 0

    private struct JoinRequest: Codable {
        var version = 1
        var matchID: UUID
        var code: String
        var displayID: String
        var displayCode: String
        var control: Bool
        var name: String? = nil
    }
    private struct Reply: Codable { var accepted: Bool; var message: String }

    private static func parameters(peerToPeer: Bool) -> NWParameters {
        let params = NWParameters.tcp
        params.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(.version13), at: 0)
        params.includePeerToPeer = peerToPeer
        return params
    }

    func update(owner store: ScoreboardStore) {
        owner = store
        let enabled = !store.isShowingFileHome && ScoreboardConnectionPolicy.allowsLocalNetworking && ScoreboardDeviceMode.current.canHost && store.isRemoteDisplayHostEnabled && store.isSessionAuthority && (!store.isRemoteDisplayViewerModeEnabled || store.isDelegatedSessionHost)
        guard enabled else {
            listener?.cancel(); listener = nil; advertisedMatchID = nil; lastAdvertisement = nil
            pending.values.forEach { $0.cancel() }; pending.removeAll()
            approvals = []; approvalConnections.removeAll()
            return
        }
        let peerToPeer = store.remoteDisplayNetworkMode.includesPeerToPeer
        if advertisedMatchID != store.currentMatchID {
            pending.values.forEach { $0.cancel() }; pending.removeAll()
            approvals = []; approvalConnections.removeAll()
            joinCode = String(format: "%06d", Int.random(in: 0...999_999)); requestedControllers = []
        }
        if listener == nil || advertisedPeerToPeer != peerToPeer {
            listener?.cancel()
            lastAdvertisement = nil
            do {
                let listener = try NWListener(using: Self.parameters(peerToPeer: peerToPeer))
                listener.newConnectionHandler = { [weak self] connection in
                    Task { @MainActor [weak self] in self?.accept(connection) }
                }
                listener.stateUpdateHandler = { [weak self, weak listener] state in
                    Task { @MainActor [weak self, weak listener] in
                    if case .failed = state, self?.listener === listener { self?.listener = nil }
                    }
                }
                self.listener = listener; advertisedPeerToPeer = peerToPeer
                listener.start(queue: .main)
            } catch { discoveryError = error.localizedDescription; return }
        }
        advertisedMatchID = store.currentMatchID
        var record = NWTXTRecord()
        record["version"] = "1"; record["ownerID"] = store.localSessionDeviceID
        record["matchID"] = store.currentMatchID.uuidString
        record["title"] = String(decoding: store.currentMatchTitle.utf8.prefix(160), as: UTF8.self)
        record["owner"] = String((ScoreboardRemoteDisplayDeviceName.current ?? "Smart Scoreboard").prefix(60))
        if lastAdvertisement != record.data {
            lastAdvertisement = record.data
            listener?.service = .init(name: "Scoreboard-\(store.localSessionDeviceID.prefix(8))", type: Self.serviceType, txtRecord: record.data)
        }
    }

    func acquireBrowser(mode: ScoreboardRemoteDisplayNetworkMode) {
        browserConsumers += 1
        startBrowser(mode: mode)
    }

    private func startBrowser(mode: ScoreboardRemoteDisplayNetworkMode) {
        guard ScoreboardConnectionPolicy.allowsLocalNetworking, mode.allowsLocalNetwork else { return }
        guard browser == nil else { return }
        discoveryError = nil; discoveryNeedsPermission = false
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: Self.serviceType, domain: nil),
                                using: Self.parameters(peerToPeer: mode.includesPeerToPeer))
        browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
            Task { @MainActor [weak self, weak browser] in
            guard let self, let browser, self.browser === browser else { return }
            let matches: [ScoreboardNearbyMatch] = results.compactMap { result in
                guard case .bonjour(let txt) = result.metadata, txt["version"] == "1",
                      let id = txt["ownerID"], id != ScoreboardStore.shared.localSessionDeviceID,
                      let rawMatchID = txt["matchID"], let matchID = UUID(uuidString: rawMatchID) else { return nil }
                return ScoreboardNearbyMatch(id: id, matchID: matchID, title: txt["title"] ?? "Match", ownerName: txt["owner"] ?? "Smart Scoreboard", endpoint: result.endpoint)
            }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            self.matches = Dictionary(matches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                .values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            self.discoveryError = nil
            }
        }
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            Task { @MainActor [weak self, weak browser] in
            guard let self, let browser, self.browser === browser else { return }
            switch state {
            case .ready:
                self.discoveryError = nil; self.discoveryNeedsPermission = false
            case .waiting(let error), .failed(let error):
                self.discoveryError = ScoreboardNearbyNetworkError.message(for: error)
                self.discoveryNeedsPermission = ScoreboardNearbyNetworkError.requiresPermission(error)
                self.matches = []
                if case .failed = state { self.browser?.cancel(); self.browser = nil }
            default: break
            }
            }
        }
        self.browser = browser; browser.start(queue: .main)
    }

    func releaseBrowser() {
        browserConsumers = max(0, browserConsumers - 1)
        if browserConsumers == 0 { browser?.cancel(); browser = nil; matches = [] }
    }

    func retryBrowser(mode: ScoreboardRemoteDisplayNetworkMode) {
        browser?.cancel(); browser = nil; matches = []
        if browserConsumers > 0 { startBrowser(mode: mode) }
    }

    func connectionsDidChange(owner store: ScoreboardStore) {
        update(owner: store)
        if ScoreboardConnectionPolicy.allowsLocalNetworking {
            if browserConsumers > 0 { startBrowser(mode: store.remoteDisplayNetworkMode) }
        } else {
            browser?.cancel(); browser = nil; matches = []
            discoveryError = nil; discoveryNeedsPermission = false
            cancelRequest()
        }
    }

    func requestJoin(_ match: ScoreboardNearbyMatch, code: String, control: Bool,
                     mode: ScoreboardRemoteDisplayNetworkMode, completion: @escaping (Result<Void, Error>) -> Void) {
        guard ScoreboardConnectionPolicy.allowsLocalNetworking else {
            completion(.failure(error("Enable LAN & Nearby in App Settings first."))); return
        }
        cancelRequest()
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        let request = JoinRequest(matchID: match.matchID, code: code,
            displayID: receiver.displayID, displayCode: receiver.pairingCode, control: control, name: ScoreboardRemoteDisplayDeviceName.current ?? "Nearby device")
        // matchID is also verified by the owner; use the latest discovery metadata.
        guard let data = try? JSONEncoder().encode(request) else { return }
        let connection = NWConnection(to: match.endpoint, using: Self.parameters(peerToPeer: mode.includesPeerToPeer))
        requestConnection = connection; requestCompletion = completion
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor [weak self, weak connection] in
            guard let self, let connection, self.requestConnection === connection else { return }
            switch state {
            case .ready:
                self.send(data, on: connection) { [weak self, weak connection] in
                    guard let connection else { return }
                    connection.receiveMessage { [weak self, weak connection] data, _, _, error in
                        Task { @MainActor [weak self, weak connection] in
                        guard let self, let connection, self.requestConnection === connection else { return }
                        if let data, let reply = try? JSONDecoder().decode(Reply.self, from: data), reply.accepted {
                            self.finishRequest(.success(()))
                        } else {
                            let detail = data.flatMap { try? JSONDecoder().decode(Reply.self, from: $0).message }
                            self.finishRequest(.failure(self.error(detail ?? error?.localizedDescription ?? "Unable to pair with this match.")))
                        }
                        }
                    }
                }
            case .failed(let error): self.finishRequest(.failure(error))
            default: break
            }
            }
        }
        connection.start(queue: .main)
        requestTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(90))
            guard !Task.isCancelled else { return }
            self?.finishRequest(.failure(URLError(.timedOut)))
        }
    }

    func cancelRequest() { finishRequest(.failure(CancellationError())) }

    private func finishRequest(_ result: Result<Void, Error>) {
        let completion = requestCompletion; requestCompletion = nil
        requestTimeout?.cancel(); requestTimeout = nil
        requestConnection?.cancel(); requestConnection = nil
        completion?(result)
    }

    private func accept(_ connection: NWConnection) {
        guard pending.count < 32 else { connection.cancel(); return }
        pending[ObjectIdentifier(connection)] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor [weak self, weak connection] in
            guard let self, let connection else { return }
            if case .ready = state { self.receiveRequest(on: connection) }
            if case .failed = state { self.pending.removeValue(forKey: ObjectIdentifier(connection)); self.removeApproval(for: connection) }
            if case .cancelled = state { self.pending.removeValue(forKey: ObjectIdentifier(connection)); self.removeApproval(for: connection) }
            }
        }
        connection.start(queue: .main)
        Task { [weak self, weak connection] in
            try? await Task.sleep(for: .seconds(90))
            if let connection { connection.cancel(); self?.pending.removeValue(forKey: ObjectIdentifier(connection)) }
        }
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, _ in
            Task { @MainActor [weak self] in
            guard let self else { return }
            guard let data, data.count <= 4096, let request = try? JSONDecoder().decode(JoinRequest.self, from: data),
                  let owner = self.owner, owner.isSessionAuthority, owner.isRemoteDisplayHostEnabled,
                  request.version == 1, request.matchID == owner.currentMatchID else {
                self.reply(false, "This match is no longer available.", on: connection); return
            }
            self.failures = self.failures.filter { Date().timeIntervalSince($0.value.date) < 60 }
            let key: String
            if case .hostPort(let host, _) = connection.endpoint { key = String(describing: host) }
            else { key = String(describing: connection.endpoint) }
            let attempt = self.failures[key]
            if let attempt, attempt.count >= 5, Date().timeIntervalSince(attempt.date) < 60 {
                self.reply(false, "Too many attempts. Wait a minute and try again.", on: connection); return
            }
            guard (request.code.isEmpty || request.code == self.joinCode), request.displayCode.count == 4, request.displayCode.allSatisfy(\.isNumber) else {
                let count = attempt.map { Date().timeIntervalSince($0.date) < 60 ? $0.count + 1 : 1 } ?? 1
                self.failures[key] = (count, Date())
                self.reply(false, "Check the nearby code shown on the owner's device.", on: connection); return
            }
            if request.code.isEmpty {
                guard self.approvalConnections[request.displayID] == nil else {
                    self.reply(false, "A request from this device is already waiting.", on: connection); return
                }
                self.approvalConnections[request.displayID] = (request, connection)
                self.approvals.append(Approval(id: request.displayID, name: String((request.name ?? "Nearby device").prefix(80)),
                    requestsControl: request.control, matchID: request.matchID))
            } else { self.pair(request, connection: connection, remaining: 30) }
            }
        }
    }

    func approve(_ approval: Approval) {
        guard let (request, connection) = approvalConnections.removeValue(forKey: approval.id),
              owner?.currentMatchID == approval.matchID else { return }
        approvals.removeAll { $0.id == approval.id }
        pair(request, connection: connection, remaining: 30, approvedControl: approval.requestsControl)
    }
    func decline(_ approval: Approval) {
        guard let (_, connection) = approvalConnections.removeValue(forKey: approval.id) else { return }
        approvals.removeAll { $0.id == approval.id }
        reply(false, "The host declined this request.", on: connection)
    }
    private func removeApproval(for connection: NWConnection) {
        let ids = approvalConnections.filter { $0.value.1 === connection }.map(\.key)
        for id in ids { approvalConnections.removeValue(forKey: id) }
        approvals.removeAll { ids.contains($0.id) }
    }

    private func pair(_ request: JoinRequest, connection: NWConnection, remaining: Int, approvedControl: Bool = false) {
        guard pending[ObjectIdentifier(connection)] != nil, let owner,
              owner.currentMatchID == request.matchID, owner.isRemoteDisplayHostEnabled else { return }
        if let source = owner.remoteDisplaySources.first(where: { $0.id == request.displayID && !$0.isSessionInfrastructure && $0.allowsNewPairing }) {
            guard !source.needsTakeoverConfirmation(currentOperatorID: owner.remoteDisplayHostID) else {
                reply(false, "This device is paired elsewhere. Forget that pairing before joining.", on: connection); return
            }
            if request.control && !approvedControl { requestedControllers.insert(source.id); owner.noteLocalControlRequest(displayID: source.id) }
            owner.setRemoteControlAllowed(displayID: source.id, isAllowed: false)
            owner.pairRemoteDisplay(source, pairingCode: request.displayCode, takeoverConfirmed: false)
            if approvedControl {
                Task { @MainActor [weak owner] in
                    for _ in 0..<150 {
                        try? await Task.sleep(for: .milliseconds(100))
                        guard let owner, owner.currentMatchID == request.matchID, owner.isRemoteDisplayHostEnabled else { return }
                        if owner.remoteSessionDevices?.contains(where: { $0.id == source.id && $0.connected }) == true {
                            owner.setRemoteControlAllowed(displayID: source.id, isAllowed: true)
                            return
                        }
                    }
                }
            }
            reply(true, "Pairing", on: connection)
        } else if remaining > 0 {
            Task { [weak self, weak connection] in
                try? await Task.sleep(for: .milliseconds(300))
                if let connection { self?.pair(request, connection: connection, remaining: remaining - 1, approvedControl: approvedControl) }
            }
        } else { reply(false, "Could not discover your device. Check Local Network permission and try again.", on: connection) }
    }

    private func reply(_ accepted: Bool, _ message: String, on connection: NWConnection) {
        if let data = try? JSONEncoder().encode(Reply(accepted: accepted, message: message)) {
            send(data, on: connection) { connection.cancel() }
        } else { connection.cancel() }
    }
    private func send(_ data: Data, on connection: NWConnection, completion: @escaping @MainActor @Sendable () -> Void) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        connection.send(content: data, contentContext: .init(identifier: "match-join", metadata: [metadata]), isComplete: true,
                        completion: .contentProcessed { _ in Task { @MainActor in completion() } })
    }
    private func error(_ message: String) -> Error {
        NSError(domain: "ScoreboardJoin", code: 409, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
