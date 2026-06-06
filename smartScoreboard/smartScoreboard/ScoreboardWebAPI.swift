import Combine
import Foundation
import Network
#if os(macOS)
import AppKit
#else
import UIKit
#endif
#if canImport(Darwin)
import Darwin
#endif

nonisolated enum ScoreboardWebAPIStatus: Equatable, Sendable {
    case off
    case starting
    case running(httpPort: UInt16, webSocketPort: UInt16, clientCount: Int)
    case suspended
    case permissionDenied
    case portUnavailable(String)
    case failed(String)

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .starting:
            return "Starting"
        case .running:
            return "Running"
        case .suspended:
            return "Paused in Background"
        case .permissionDenied:
            return "Local Network Denied"
        case .portUnavailable:
            return "Port Unavailable"
        case .failed:
            return "Failed"
        }
    }

    var detail: String {
        switch self {
        case .off:
            return "Web API is disabled."
        case .starting:
            return "Starting HTTP and WebSocket listeners."
        case .running(let httpPort, let webSocketPort, let clientCount):
            return "HTTP \(httpPort), WebSocket \(webSocketPort), \(clientCount) connected WS client\(clientCount == 1 ? "" : "s")."
        case .suspended:
            return "iPadOS paused the Web API while Scoreboard is not active. It will restart when you return to the app."
        case .permissionDenied:
            return "Local network access is blocked for Scoreboard."
        case .portUnavailable(let message), .failed(let message):
            return message
        }
    }

    var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }

    var isError: Bool {
        switch self {
        case .permissionDenied, .portUnavailable, .failed:
            return true
        case .off, .starting, .running, .suspended:
            return false
        }
    }

    var healthValue: String {
        switch self {
        case .off:
            return "off"
        case .starting:
            return "starting"
        case .running:
            return "running"
        case .suspended:
            return "suspended"
        case .permissionDenied:
            return "permissionDenied"
        case .portUnavailable:
            return "portUnavailable"
        case .failed:
            return "failed"
        }
    }
}

nonisolated enum ScoreboardWebAPIUpdateMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case fixedInterval
    case realTimePush

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixedInterval:
            return "Fixed Interval"
        case .realTimePush:
            return "Real-Time Push"
        }
    }

    var detail: String {
        switch self {
        case .fixedInterval:
            return "Coalesces fast changes and sends at most 10 updates per second."
        case .realTimePush:
            return "Sends every state change immediately. This is lower latency but more resource intensive."
        }
    }
}

nonisolated struct ScoreboardWebAPIState: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let generatedAtUnixTime: TimeInterval?
    let app: ScoreboardWebAPIAppInfo
    let game: ScoreboardGameSnapshot
    let runtime: ScoreboardWebAPIRuntime
    let display: ScoreboardWebAPIDisplay?
    let audio: ScoreboardWebAPIAudio?
    let rules: ScoreboardWebAPIRules
    let teams: ScoreboardWebAPITeams
    let clocks: ScoreboardWebAPIClocks
    let players: ScoreboardWebAPIPlayers
    let debate: ScoreboardWebAPIDebate?
}

nonisolated struct ScoreboardWebAPIAppInfo: Codable, Sendable {
    let name: String
    let version: String
    let build: String
    let apiVersion: String

    static var current: ScoreboardWebAPIAppInfo {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Scoreboard"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return ScoreboardWebAPIAppInfo(
            name: appName,
            version: appVersion,
            build: appBuild,
            apiVersion: "v1"
        )
    }
}

nonisolated struct ScoreboardWebAPIRuntime: Codable, Sendable {
    let isClockRunning: Bool
    let isShotClockRunning: Bool
    let isDebatePrepClockRunning: Bool
    let areSidesSwapped: Bool
    let possessionDirection: PossessionDirection
}

nonisolated struct ScoreboardWebAPIDisplay: Codable, Sendable {
    let theme: ScoreboardTheme
    let backgroundMode: ExternalDisplayBackgroundMode
    let backgroundImage: ScoreboardWebAPIBackgroundImage?
    let animatedLogoStyle: ExternalDisplayAnimatedLogoStyle?
    let animatedLogoBackgroundColor: ExternalDisplayAnimatedLogoBackgroundColor?
    let animatedLogoSpeed: Int?
    let animatedLogoSize: Int?
    let animatedLogoOpacity: Double?
    let showsDateTime: Bool?
    let dateTimeFormat: ExternalDisplayDateTimeFormat?
    let showsTeamLogos: Bool?
    let showsEventLogo: Bool?
    let eventLogo: ScoreboardWebAPIEventLogo?
    let viewMode: ScoreboardDisplayViewMode?
    let playerViewRosterScope: PlayerViewRosterScope?
}

nonisolated struct ScoreboardWebAPIAudio: Codable, Sendable {
    let isSoundEnabled: Bool
    let assignmentsBySport: [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]]
}

nonisolated struct ScoreboardWebAPIRules: Codable, Sendable {
    let sport: SportType
    let title: String
    let periodTitle: String
    let periodShortTitle: String
    let mainClockMode: MainClockMode
    let scoreStepOptions: [Int]
    let supportsScore: Bool
    let supportsPeriod: Bool
    let supportsShotClock: Bool
    let supportsPossession: Bool
    let supportsFouls: Bool
    let supportsTeamFouls: Bool
    let supportsPlayerTracking: Bool
    let supportsCards: Bool
    let supportsSubstitutions: Bool
    let supportsHockeyPenalties: Bool
    let usesChessClocks: Bool
}

nonisolated struct ScoreboardWebAPITeams: Codable, Sendable {
    let home: ScoreboardWebAPITeam
    let guest: ScoreboardWebAPITeam
}

nonisolated struct ScoreboardWebAPITeam: Codable, Sendable {
    let side: TeamSide
    let name: String
    let roleLabel: String
    let logo: ScoreboardWebAPITeamLogo?
    let score: Int
    let teamFouls: Int
    let substitutionsAllowed: Int
    let substitutionsUsed: Int
    let substitutionsRemaining: Int
}

nonisolated struct ScoreboardWebAPIClocks: Codable, Sendable {
    let gameClockSeconds: Int
    let formattedGameClock: String
    let defaultClockSeconds: Int
    let showsGameClock: Bool
    let gameClockMode: GameClockMode
    let isGameClockRunning: Bool
    let shotClockMilliseconds: Int
    let formattedShotClock: String
    let defaultShotClockSeconds: Int
    let activeShotClockPresetSeconds: Int
    let isShotClockRunning: Bool
    let homeChessClockSeconds: Int
    let formattedHomeChessClock: String
    let guestChessClockSeconds: Int
    let formattedGuestChessClock: String
    let activeChessClockSide: TeamSide?
}

nonisolated enum ScoreboardWebAPILegacyScrollDirection: String, Codable, Sendable {
    case up
    case down

    var resolvedScrollMode: PlayerLineupScrollDirection {
        .bounce
    }
}

nonisolated struct ScoreboardWebAPIPlayers: Codable, Sendable {
    let isPlayerTrackingEnabled: Bool
    let isPlayerOverlayPaused: Bool
    let rosterSizePerTeam: Int
    let displayLineupSize: Int
    let lineupOverflowMode: PlayerLineupOverflowMode?
    let lineupOverflowLogoOverride: PlayerLineupOverflowMode?
    let lineupOverflowNoLogoOverride: PlayerLineupOverflowMode?
    let lineupFadePageSeconds: Int?
    let lineupScrollSpeed: Int?
    let lineupScrollMode: PlayerLineupScrollDirection?
    let lineupScrollDirection: ScoreboardWebAPILegacyScrollDirection?
    let foulHighlightColor: PlayerFoulHighlightColor
    let homeDisplayed: [TrackedPlayer]
    let guestDisplayed: [TrackedPlayer]
    let homeRoster: TeamRoster
    let guestRoster: TeamRoster
}

nonisolated struct ScoreboardWebAPIDebate: Codable, Sendable {
    let presetID: String
    let presetTitle: String
    let segmentIndex: Int
    let segmentTitle: String
    let segmentTimerMode: DebateTimerMode?
    let speakingSide: TeamSide?
    let activeTimer: DebateActiveTimer
    let homeSideLabel: String
    let guestSideLabel: String
    let prepTimeEnabled: Bool
    let prepHomeSeconds: Int
    let formattedPrepHomeClock: String
    let prepGuestSeconds: Int
    let formattedPrepGuestClock: String
    let scoreTrackingEnabled: Bool
    let playerTrackingEnabled: Bool
    let playerFoulsEnabled: Bool
    let playerCardsEnabled: Bool
}

nonisolated struct ScoreboardWebAPIImageResponse: Sendable {
    let contentType: String
    let body: Data
}

extension ScoreboardWebAPIState {
    var remoteDisplayPayload: ScoreboardWebAPIState {
        let shouldIncludeFullRoster = display?.resolvedViewMode == .playerView

        return ScoreboardWebAPIState(
            schemaVersion: schemaVersion,
            generatedAt: generatedAt,
            generatedAtUnixTime: generatedAtUnixTime,
            app: app,
            game: game.remoteDisplayPayload,
            runtime: runtime,
            display: display,
            audio: nil,
            rules: rules,
            teams: teams,
            clocks: clocks,
            players: shouldIncludeFullRoster ? players : players.remoteDisplayPayload,
            debate: debate
        )
    }
}

extension ScoreboardWebAPIDisplay {
    var resolvedViewMode: ScoreboardDisplayViewMode {
        viewMode ?? .scoreboard
    }

    var resolvedPlayerViewRosterScope: PlayerViewRosterScope {
        playerViewRosterScope ?? .fullRoster
    }

    var resolvedShowsEventLogo: Bool {
        showsEventLogo ?? true
    }

    var resolvedAnimatedLogoStyle: ExternalDisplayAnimatedLogoStyle {
        animatedLogoStyle ?? .horizontalMarquee
    }

    var resolvedAnimatedLogoBackgroundColor: ExternalDisplayAnimatedLogoBackgroundColor {
        animatedLogoBackgroundColor ?? .themeBackground
    }

    var resolvedAnimatedLogoSpeed: Int {
        max(ScoreboardStore.minAnimatedLogoSpeed, min(ScoreboardStore.maxAnimatedLogoSpeed, animatedLogoSpeed ?? ScoreboardStore.defaultAnimatedLogoSpeed))
    }

    var resolvedAnimatedLogoSize: Int {
        max(ScoreboardStore.minAnimatedLogoSize, min(ScoreboardStore.maxAnimatedLogoSize, animatedLogoSize ?? ScoreboardStore.defaultAnimatedLogoSize))
    }

    var resolvedAnimatedLogoOpacity: Double {
        max(ScoreboardStore.minAnimatedLogoOpacity, min(ScoreboardStore.maxAnimatedLogoOpacity, animatedLogoOpacity ?? ScoreboardStore.defaultAnimatedLogoOpacity))
    }

    var resolvedShowsDateTime: Bool {
        showsDateTime ?? false
    }

    var resolvedDateTimeFormat: ExternalDisplayDateTimeFormat {
        dateTimeFormat ?? .time24Hour
    }
}

extension ScoreboardWebAPIPlayers {
    var remoteDisplayPayload: ScoreboardWebAPIPlayers {
        ScoreboardWebAPIPlayers(
            isPlayerTrackingEnabled: isPlayerTrackingEnabled,
            isPlayerOverlayPaused: isPlayerOverlayPaused,
            rosterSizePerTeam: rosterSizePerTeam,
            displayLineupSize: displayLineupSize,
            lineupOverflowMode: lineupOverflowMode,
            lineupOverflowLogoOverride: lineupOverflowLogoOverride,
            lineupOverflowNoLogoOverride: lineupOverflowNoLogoOverride,
            lineupFadePageSeconds: lineupFadePageSeconds,
            lineupScrollSpeed: lineupScrollSpeed,
            lineupScrollMode: lineupScrollMode,
            lineupScrollDirection: lineupScrollDirection,
            foulHighlightColor: foulHighlightColor,
            homeDisplayed: homeDisplayed,
            guestDisplayed: guestDisplayed,
            homeRoster: TeamRoster(players: []),
            guestRoster: TeamRoster(players: [])
        )
    }
}

private extension PlayerLineupScrollDirection {
    var legacyWebAPIScrollDirection: ScoreboardWebAPILegacyScrollDirection {
        switch self {
        case .continuousDown, .throughDown:
            return .down
        case .continuousUp, .throughUp, .bounce:
            return .up
        }
    }
}

nonisolated final class ScoreboardWebAPIService: @unchecked Sendable {
    static let httpPort: UInt16 = 5516
    static let webSocketPort: UInt16 = 5517
    static let bonjourServiceType = "_smartscoreboard._tcp"

    private let queue = DispatchQueue(label: "com.ironmaple.smartscoreboard.webapi", qos: .utility)
    private let maxHTTPHeaderBytes = 16 * 1024
    private let maxWebSocketClients = 16
    private let maxWebSocketFrameBytes = 1 * 1024 * 1024
    private let minimumBroadcastInterval: TimeInterval = 0.10

    private var httpListener: NWListener?
    private var webSocketListener: NWListener?
    private var httpReady = false
    private var webSocketReady = false
    private var status: ScoreboardWebAPIStatus = .off
    private var statusHandler: (@Sendable (ScoreboardWebAPIStatus) -> Void)?
    private var latestStateData = Data("{}".utf8)
    private var latestImageResponses: [String: ScoreboardWebAPIImageResponse] = [:]
    private var updateMode: ScoreboardWebAPIUpdateMode = .fixedInterval
    private var clients: [UUID: WebSocketClient] = [:]
    private var broadcastWorkItem: DispatchWorkItem?
    private var lastBroadcastDate: Date?

    func start(
        initialState: Data,
        updateMode: ScoreboardWebAPIUpdateMode,
        imageResponses: [String: ScoreboardWebAPIImageResponse],
        statusHandler: @escaping @Sendable (ScoreboardWebAPIStatus) -> Void
    ) {
        queue.async {
            self.statusHandler = statusHandler
            self.latestStateData = initialState
            self.latestImageResponses = imageResponses
            self.updateMode = updateMode
            self.stopLocked(notify: false)
            self.httpReady = false
            self.webSocketReady = false
            self.updateStatusLocked(.starting)

            guard
                let httpPort = NWEndpoint.Port(rawValue: Self.httpPort),
                let webSocketPort = NWEndpoint.Port(rawValue: Self.webSocketPort)
            else {
                self.updateStatusLocked(.failed("Invalid Web API port configuration."))
                return
            }

            do {
                let httpListener = try NWListener(using: .tcp, on: httpPort)
                let webSocketListener = try NWListener(using: Self.webSocketParameters(), on: webSocketPort)
                httpListener.service = NWListener.Service(
                    name: nil,
                    type: Self.bonjourServiceType,
                    domain: nil,
                    txtRecord: nil
                )
                self.configureHTTPListener(httpListener)
                self.configureWebSocketListener(webSocketListener)
                self.httpListener = httpListener
                self.webSocketListener = webSocketListener

                httpListener.start(queue: self.queue)
                webSocketListener.start(queue: self.queue)
            } catch {
                self.stopLocked(notify: false)
                self.updateStatusLocked(self.status(for: error, port: nil))
            }
        }
    }

    func stop(notify: Bool = true) {
        queue.async {
            self.stopLocked(notify: notify)
        }
    }

    func updateState(_ data: Data, imageResponses: [String: ScoreboardWebAPIImageResponse]) {
        queue.async {
            self.latestStateData = data
            self.latestImageResponses = imageResponses
            guard self.status.isRunning, !self.clients.isEmpty else {
                return
            }
            self.broadcastChangedStateLocked()
        }
    }

    func setUpdateMode(_ mode: ScoreboardWebAPIUpdateMode) {
        queue.async {
            self.updateMode = mode
            guard self.status.isRunning, !self.clients.isEmpty else {
                return
            }

            switch mode {
            case .fixedInterval:
                break
            case .realTimePush:
                self.broadcastWorkItem?.cancel()
                self.broadcastWorkItem = nil
                self.broadcastStateLocked()
            }
        }
    }

    static func localIPv4Addresses() -> [String] {
        #if canImport(Darwin)
        var addresses: [String] = []
        var interfaces: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return []
        }
        defer { freeifaddrs(interfaces) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = firstInterface
        while let interface = pointer?.pointee {
            defer { pointer = interface.ifa_next }

            let flags = Int32(interface.ifa_flags)
            guard
                (flags & IFF_UP) != 0,
                (flags & IFF_RUNNING) != 0,
                (flags & IFF_LOOPBACK) == 0,
                let address = interface.ifa_addr,
                address.pointee.sa_family == UInt8(AF_INET)
            else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                let value = String(cString: hostname)
                if !addresses.contains(value) {
                    addresses.append(value)
                }
            }
        }

        return addresses.sorted()
        #else
        return []
        #endif
    }

    private func configureHTTPListener(_ listener: NWListener) {
        listener.newConnectionHandler = { [weak self] connection in
            self?.acceptHTTPConnection(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state, service: .http)
        }
    }

    private func configureWebSocketListener(_ listener: NWListener) {
        listener.newConnectionHandler = { [weak self] connection in
            self?.acceptWebSocketConnection(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state, service: .webSocket)
        }
    }

    private func handleListenerState(_ state: NWListener.State, service: ListenerService) {
        switch state {
        case .ready:
            switch service {
            case .http:
                httpReady = true
            case .webSocket:
                webSocketReady = true
            }
            updateRunningStatusLocked()
        case .waiting(let error):
            updateStatusLocked(status(for: error, port: service.port))
        case .failed(let error):
            stopLocked(notify: false)
            updateStatusLocked(status(for: error, port: service.port))
        case .cancelled:
            break
        case .setup:
            break
        @unknown default:
            break
        }
    }

    private func acceptHTTPConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .failed = state {
                connection.cancel()
            }
        }
        connection.start(queue: queue)
        receiveHTTPRequest(connection, buffer: Data())
    }

    private func receiveHTTPRequest(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: maxHTTPHeaderBytes) { data, _, _, error in
            if error != nil {
                connection.cancel()
                return
            }

            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            guard nextBuffer.count <= self.maxHTTPHeaderBytes else {
                self.sendHTTPResponse(
                    connection,
                    statusCode: 431,
                    reason: "Request Header Fields Too Large",
                    contentType: "text/plain; charset=utf-8",
                    body: Data("Request headers are too large.".utf8)
                )
                return
            }

            guard self.headerEndIndex(in: nextBuffer) != nil else {
                self.receiveHTTPRequest(connection, buffer: nextBuffer)
                return
            }

            self.handleHTTPRequest(connection, data: nextBuffer)
        }
    }

    private func handleHTTPRequest(_ connection: NWConnection, data: Data) {
        guard
            let text = String(data: data, encoding: .utf8),
            let firstLine = text.components(separatedBy: "\r\n").first
        else {
            sendHTTPResponse(
                connection,
                statusCode: 400,
                reason: "Bad Request",
                contentType: "text/plain; charset=utf-8",
                body: Data("Bad request.".utf8)
            )
            return
        }

        let parts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else {
            sendHTTPResponse(
                connection,
                statusCode: 400,
                reason: "Bad Request",
                contentType: "text/plain; charset=utf-8",
                body: Data("Bad request.".utf8)
            )
            return
        }

        let method = parts[0].uppercased()
        let path = parts[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"

        guard method == "GET" else {
            sendHTTPResponse(
                connection,
                statusCode: 405,
                reason: "Method Not Allowed",
                contentType: "application/json; charset=utf-8",
                body: Data(#"{"error":"readOnly","message":"SmartScoreboard Web API is read only."}"#.utf8),
                extraHeaders: ["Allow: GET"]
            )
            return
        }

        switch path {
        case "/", "/index.html":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "text/html; charset=utf-8",
                body: Self.webAssetData(.docs)
            )
        case "/demo/scoreboard", "/demo/scoreboard.html":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "text/html; charset=utf-8",
                body: Self.webAssetData(.scoreboard)
            )
        case "/demo/obs", "/demo/obs.html":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "text/html; charset=utf-8",
                body: Self.webAssetData(.obs)
            )
        case "/api/v1/state":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "application/json; charset=utf-8",
                body: latestStateData
            )
        case "/api/v1/health":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "application/json; charset=utf-8",
                body: healthDataLocked()
            )
        default:
            if let imageResponse = latestImageResponses[path] {
                sendHTTPResponse(
                    connection,
                    statusCode: 200,
                    reason: "OK",
                    contentType: imageResponse.contentType,
                    body: imageResponse.body
                )
            } else {
                sendHTTPResponse(
                    connection,
                    statusCode: 404,
                    reason: "Not Found",
                    contentType: "application/json; charset=utf-8",
                    body: Data(#"{"error":"notFound"}"#.utf8)
                )
            }
        }
    }

    private func sendHTTPResponse(
        _ connection: NWConnection,
        statusCode: Int,
        reason: String,
        contentType: String,
        body: Data,
        extraHeaders: [String] = []
    ) {
        var headers = [
            "HTTP/1.1 \(statusCode) \(reason)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Cache-Control: no-store",
            "X-SmartScoreboard-Version: \(Self.httpHeaderSafeValue(ScoreboardWebAPIAppInfo.current.version))",
            "X-SmartScoreboard-Build: \(Self.httpHeaderSafeValue(ScoreboardWebAPIAppInfo.current.build))",
            "X-SmartScoreboard-API-Version: \(Self.httpHeaderSafeValue(ScoreboardWebAPIAppInfo.current.apiVersion))",
            "Connection: close"
        ]
        headers.append(contentsOf: extraHeaders)
        headers.append("")
        headers.append("")

        var response = Data(headers.joined(separator: "\r\n").utf8)
        response.append(body)

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func acceptWebSocketConnection(_ connection: NWConnection) {
        guard clients.count < maxWebSocketClients else {
            connection.cancel()
            return
        }

        let id = UUID()
        let client = WebSocketClient(
            id: id,
            connection: connection,
            queue: queue,
            maxFrameBytes: maxWebSocketFrameBytes,
            latestEnvelopeProvider: { [weak self] in
                self?.latestEnvelopeDataLocked() ?? Data()
            },
            onClose: { [weak self] clientID in
                self?.queue.async {
                    self?.clients[clientID] = nil
                    self?.updateRunningStatusLocked()
                }
            }
        )
        clients[id] = client
        updateRunningStatusLocked()
        client.start()
    }

    private func broadcastChangedStateLocked() {
        switch updateMode {
        case .fixedInterval:
            scheduleBroadcastLocked()
        case .realTimePush:
            broadcastStateLocked()
        }
    }

    private func scheduleBroadcastLocked() {
        guard broadcastWorkItem == nil else {
            return
        }

        let now = Date()
        guard let lastBroadcastDate else {
            broadcastStateLocked()
            return
        }

        let elapsed = now.timeIntervalSince(lastBroadcastDate)
        guard elapsed < minimumBroadcastInterval else {
            broadcastStateLocked()
            return
        }

        let item = DispatchWorkItem { [weak self] in
            self?.broadcastWorkItem = nil
            self?.broadcastStateLocked()
        }
        broadcastWorkItem = item
        queue.asyncAfter(deadline: .now() + (minimumBroadcastInterval - elapsed), execute: item)
    }

    private func broadcastStateLocked() {
        lastBroadcastDate = Date()
        let envelope = latestEnvelopeDataLocked()
        for client in clients.values {
            client.sendText(envelope)
        }
    }

    private func stopLocked(notify: Bool) {
        broadcastWorkItem?.cancel()
        broadcastWorkItem = nil
        lastBroadcastDate = nil
        httpListener?.cancel()
        webSocketListener?.cancel()
        httpListener = nil
        webSocketListener = nil
        httpReady = false
        webSocketReady = false
        for client in clients.values {
            client.close()
        }
        clients.removeAll()
        if notify {
            updateStatusLocked(.off)
        }
    }

    private func updateRunningStatusLocked() {
        guard httpReady, webSocketReady else {
            return
        }
        updateStatusLocked(.running(
            httpPort: Self.httpPort,
            webSocketPort: Self.webSocketPort,
            clientCount: clients.count
        ))
    }

    private func updateStatusLocked(_ status: ScoreboardWebAPIStatus) {
        self.status = status
        statusHandler?(status)
    }

    private func status(for error: Error, port: UInt16?) -> ScoreboardWebAPIStatus {
        if let nwError = error as? NWError {
            if case .posix(let code) = nwError, code == .EADDRINUSE {
                return .portUnavailable("Port \(port.map(String.init) ?? "5516/5517") is already in use.")
            }
        }

        let description = String(describing: error)
        let lowercasedDescription = description.lowercased()
        if lowercasedDescription.contains("denied") ||
            lowercasedDescription.contains("policy") ||
            lowercasedDescription.contains("localnetwork") {
            return .permissionDenied
        }
        if lowercasedDescription.contains("address already in use") ||
            lowercasedDescription.contains("eaddrinuse") {
            return .portUnavailable("Port \(port.map(String.init) ?? "5516/5517") is already in use.")
        }

        return .failed(description)
    }

    private func latestEnvelopeDataLocked() -> Data {
        let appData = (try? JSONEncoder().encode(ScoreboardWebAPIAppInfo.current)) ?? Data(#"{"name":"Scoreboard","version":"unknown","build":"unknown","apiVersion":"v1"}"#.utf8)
        var envelope = Data(#"{"type":"scoreboard.state","schemaVersion":1,"app":"#.utf8)
        envelope.append(appData)
        envelope.append(Data(#","payload":"#.utf8))
        envelope.append(latestStateData)
        envelope.append(Data("}".utf8))
        return envelope
    }

    private func healthDataLocked() -> Data {
        let health = HealthResponse(
            schemaVersion: 1,
            service: "smartscoreboard.web_api",
            app: ScoreboardWebAPIAppInfo.current,
            status: status.healthValue,
            httpPort: Self.httpPort,
            webSocketPort: Self.webSocketPort,
            updateMode: updateMode.rawValue,
            maximumFixedIntervalUpdatesPerSecond: Int(1 / minimumBroadcastInterval),
            webSocketClientCount: clients.count,
            generatedAt: Self.timestamp()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(health)) ?? Data(#"{"status":"failed"}"#.utf8)
    }

    private func headerEndIndex(in data: Data) -> Data.Index? {
        let delimiter = Data("\r\n\r\n".utf8)
        return data.range(of: delimiter)?.upperBound
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func httpHeaderSafeValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    private static func webSocketParameters() -> NWParameters {
        let options = NWProtocolWebSocket.Options(.version13)
        options.autoReplyPing = true
        options.maximumMessageSize = 1 * 1024 * 1024
        options.setClientRequestHandler(DispatchQueue.global(qos: .utility)) { _, _ in
            NWProtocolWebSocket.Response(
                status: .accept,
                subprotocol: nil,
                additionalHeaders: [
                    (name: "Cache-Control", value: "no-store")
                ]
            )
        }

        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        return parameters
    }

    private enum ListenerService {
        case http
        case webSocket

        var port: UInt16 {
            switch self {
            case .http:
                return ScoreboardWebAPIService.httpPort
            case .webSocket:
                return ScoreboardWebAPIService.webSocketPort
            }
        }
    }

    private struct HealthResponse: Codable {
        let schemaVersion: Int
        let service: String
        let app: ScoreboardWebAPIAppInfo
        let status: String
        let httpPort: UInt16
        let webSocketPort: UInt16
        let updateMode: String
        let maximumFixedIntervalUpdatesPerSecond: Int
        let webSocketClientCount: Int
        let generatedAt: String
    }

    private final class WebSocketClient: @unchecked Sendable {
        let id: UUID
        private let connection: NWConnection
        private let queue: DispatchQueue
        private let maxFrameBytes: Int
        private let latestEnvelopeProvider: @Sendable () -> Data
        private let onClose: @Sendable (UUID) -> Void
        private var isClosed = false
        private var pendingSends = 0

        init(
            id: UUID,
            connection: NWConnection,
            queue: DispatchQueue,
            maxFrameBytes: Int,
            latestEnvelopeProvider: @escaping @Sendable () -> Data,
            onClose: @escaping @Sendable (UUID) -> Void
        ) {
            self.id = id
            self.connection = connection
            self.queue = queue
            self.maxFrameBytes = maxFrameBytes
            self.latestEnvelopeProvider = latestEnvelopeProvider
            self.onClose = onClose
        }

        func start() {
            guard !isClosed else { return }
            connection.stateUpdateHandler = { state in
                self.queue.async {
                    switch state {
                    case .ready:
                        self.sendText(self.latestEnvelopeProvider())
                        self.receiveNextMessage()
                    case .failed, .cancelled:
                        self.close()
                    case .setup, .preparing, .waiting:
                        break
                    @unknown default:
                        break
                    }
                }
            }
            connection.start(queue: queue)
        }

        private func receiveNextMessage() {
            guard !isClosed else { return }
            connection.receiveMessage { data, context, _, error in
                self.queue.async {
                    guard error == nil else {
                        self.close()
                        return
                    }

                    let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
                    switch metadata?.opcode {
                    case .text:
                        self.handleTextPayload(data ?? Data())
                        self.receiveNextMessage()
                    case .binary:
                        self.sendError("Only UTF-8 JSON text messages are supported.")
                        self.receiveNextMessage()
                    case .close:
                        self.close()
                    case .ping, .pong, .cont:
                        self.receiveNextMessage()
                    case .none:
                        self.close()
                    @unknown default:
                        self.receiveNextMessage()
                    }
                }
            }
        }

        private func handleTextPayload(_ payload: Data) {
            guard payload.count <= maxFrameBytes else {
                close()
                return
            }

            guard let text = String(data: payload, encoding: .utf8) else {
                sendError("Only UTF-8 JSON text messages are supported.")
                return
            }

            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "get" ||
                normalized.contains(#""type":"get""#) ||
                normalized.contains(#""type": "get""#) {
                sendText(latestEnvelopeProvider())
            } else {
                sendError("SmartScoreboard Web API is read only. Send {\"type\":\"get\"} to request the latest state.")
            }
        }

        func sendText(_ data: Data) {
            guard !isClosed else { return }
            guard pendingSends < 8 else {
                return
            }

            let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
            let context = NWConnection.ContentContext(
                identifier: "scoreboard.state",
                metadata: [metadata]
            )

            pendingSends += 1
            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
                self.queue.async {
                    self.pendingSends = max(0, self.pendingSends - 1)
                    if error != nil {
                        self.close()
                        return
                    }
                }
            })
        }

        private func sendError(_ message: String) {
            let escapedMessage = message
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            sendText(Data(#"{"type":"error","message":"\#(escapedMessage)"}"#.utf8))
        }

        func close() {
            guard !isClosed else { return }
            isClosed = true
            connection.cancel()
            onClose(id)
        }
    }

    private enum WebAsset {
        case docs
        case scoreboard
        case obs

        var assetName: String {
            switch self {
            case .docs:
                return "WebAPIDocs"
            case .scoreboard:
                return "WebAPIScoreboardDemo"
            case .obs:
                return "WebAPIOBSDemo"
            }
        }
    }

    private static func webAssetData(_ asset: WebAsset) -> Data {
        NSDataAsset(name: asset.assetName)?.data
            ?? Data("Missing Web API asset: \(asset.assetName)".utf8)
    }
}

@MainActor
extension ScoreboardStore {
    func currentWebAPIState() -> ScoreboardWebAPIState {
        let now = Date()
        let rules = currentRules

        return ScoreboardWebAPIState(
            schemaVersion: 1,
            generatedAt: ISO8601DateFormatter().string(from: now),
            generatedAtUnixTime: now.timeIntervalSince1970,
            app: ScoreboardWebAPIAppInfo.current,
            game: currentGameSnapshot().excludingEmbeddedImages,
            runtime: ScoreboardWebAPIRuntime(
                isClockRunning: isClockRunning,
                isShotClockRunning: isShotClockRunning,
                isDebatePrepClockRunning: isDebatePrepClockRunning,
                areSidesSwapped: areSidesSwapped,
                possessionDirection: possessionDirection
            ),
            display: ScoreboardWebAPIDisplay(
                theme: theme,
                backgroundMode: externalDisplayBackgroundMode.resolvedForRendering,
                backgroundImage: webAPIBackgroundImageMetadata(),
                animatedLogoStyle: externalDisplayAnimatedLogoStyle,
                animatedLogoBackgroundColor: externalDisplayAnimatedLogoBackgroundColor,
                animatedLogoSpeed: externalDisplayAnimatedLogoSpeed,
                animatedLogoSize: externalDisplayAnimatedLogoSize,
                animatedLogoOpacity: externalDisplayAnimatedLogoOpacity,
                showsDateTime: showsExternalDisplayDateTime,
                dateTimeFormat: externalDisplayDateTimeFormat,
                showsTeamLogos: showsTeamLogos,
                showsEventLogo: showsEventLogo,
                eventLogo: webAPIEventLogoMetadata(),
                viewMode: publicDisplayViewMode,
                playerViewRosterScope: .fullRoster
            ),
            audio: ScoreboardWebAPIAudio(
                isSoundEnabled: isSoundEnabled,
                assignmentsBySport: soundAssignmentsBySport
            ),
            rules: ScoreboardWebAPIRules(
                sport: selectedSport,
                title: rules.title,
                periodTitle: rules.periodTitle,
                periodShortTitle: rules.periodShortTitle,
                mainClockMode: rules.mainClockMode,
                scoreStepOptions: rules.scoreStepOptions,
                supportsScore: supportsScore,
                supportsPeriod: supportsPeriod,
                supportsShotClock: supportsShotClock,
                supportsPossession: supportsPossession,
                supportsFouls: supportsFouls,
                supportsTeamFouls: supportsTeamFouls,
                supportsPlayerTracking: supportsPlayerTracking,
                supportsCards: supportsCards,
                supportsSubstitutions: rules.showsSubstitutionTracking || showsSubstitutionTracking,
                supportsHockeyPenalties: supportsHockeyPenalties,
                usesChessClocks: usesChessClocks
            ),
            teams: ScoreboardWebAPITeams(
                home: webAPITeam(for: .home),
                guest: webAPITeam(for: .guest)
            ),
            clocks: ScoreboardWebAPIClocks(
                gameClockSeconds: gameClockSeconds,
                formattedGameClock: formattedClock,
                defaultClockSeconds: defaultClockSeconds,
                showsGameClock: showsGameClock,
                gameClockMode: gameClockMode,
                isGameClockRunning: isClockRunning,
                shotClockMilliseconds: shotClockMilliseconds,
                formattedShotClock: formattedShotClock,
                defaultShotClockSeconds: defaultShotClockSeconds,
                activeShotClockPresetSeconds: activeShotClockPresetSeconds,
                isShotClockRunning: isShotClockRunning,
                homeChessClockSeconds: homeChessClockSeconds,
                formattedHomeChessClock: formattedHomeChessClock,
                guestChessClockSeconds: guestChessClockSeconds,
                formattedGuestChessClock: formattedGuestChessClock,
                activeChessClockSide: activeChessClockSide
            ),
            players: ScoreboardWebAPIPlayers(
                isPlayerTrackingEnabled: isPlayerTrackingEnabled,
                isPlayerOverlayPaused: isPlayerOverlayPaused,
                rosterSizePerTeam: rosterSizePerTeam,
                displayLineupSize: displayLineupSize,
                lineupOverflowMode: playerLineupOverflowMode,
                lineupOverflowLogoOverride: playerLineupOverflowLogoOverride,
                lineupOverflowNoLogoOverride: playerLineupOverflowNoLogoOverride,
                lineupFadePageSeconds: playerLineupFadePageSeconds,
                lineupScrollSpeed: playerLineupScrollSpeed,
                lineupScrollMode: playerLineupScrollDirection,
                lineupScrollDirection: playerLineupScrollDirection.legacyWebAPIScrollDirection,
                foulHighlightColor: playerFoulHighlightColor,
                homeDisplayed: displayedHomePlayers,
                guestDisplayed: displayedGuestPlayers,
                homeRoster: homeRoster,
                guestRoster: guestRoster
            ),
            debate: isDebateMode ? ScoreboardWebAPIDebate(
                presetID: selectedDebatePresetID,
                presetTitle: currentDebatePreset.title,
                segmentIndex: debateCurrentSegmentIndex,
                segmentTitle: debateSegmentTitle,
                segmentTimerMode: currentDebateSegment?.timerMode,
                speakingSide: debateSpeakingSide,
                activeTimer: debateActiveTimer,
                homeSideLabel: sideRoleLabel(for: .home),
                guestSideLabel: sideRoleLabel(for: .guest),
                prepTimeEnabled: isDebatePrepTimeEnabled,
                prepHomeSeconds: debatePrepHomeSeconds,
                formattedPrepHomeClock: formattedDebatePrepHomeClock,
                prepGuestSeconds: debatePrepGuestSeconds,
                formattedPrepGuestClock: formattedDebatePrepGuestClock,
                scoreTrackingEnabled: isDebateScoreTrackingEnabled,
                playerTrackingEnabled: isDebatePlayerTrackingEnabled,
                playerFoulsEnabled: isDebatePlayerFoulsEnabled,
                playerCardsEnabled: isDebatePlayerCardsEnabled
            ) : nil
        )
    }

    private func webAPITeam(for side: TeamSide) -> ScoreboardWebAPITeam {
        ScoreboardWebAPITeam(
            side: side,
            name: side == .home ? homeTeamName : guestTeamName,
            roleLabel: sideRoleLabel(for: side),
            logo: webAPITeamLogoMetadata(for: side),
            score: side == .home ? homeScore : guestScore,
            teamFouls: teamFouls(for: side),
            substitutionsAllowed: substitutionsAllowed(for: side),
            substitutionsUsed: substitutionsUsed(for: side),
            substitutionsRemaining: substitutionsRemaining(for: side)
        )
    }

    func currentWebAPIImageResponses() -> [String: ScoreboardWebAPIImageResponse] {
        var responses: [String: ScoreboardWebAPIImageResponse] = [:]
        if let image = externalDisplayBackgroundImage {
            let response = ScoreboardWebAPIImageResponse(
                contentType: image.mimeType,
                body: image.data
            )
            responses[image.path] = response
            responses[image.versionedPath] = response
            responses[image.legacyVersionedPath] = response
        }
        if let logo = homeTeamLogoImage {
            let response = ScoreboardWebAPIImageResponse(
                contentType: logo.mimeType,
                body: logo.data
            )
            responses[logo.path(for: .home)] = response
            responses[logo.versionedPath(for: .home)] = response
            responses[logo.legacyVersionedPath(for: .home)] = response
        }
        if let logo = guestTeamLogoImage {
            let response = ScoreboardWebAPIImageResponse(
                contentType: logo.mimeType,
                body: logo.data
            )
            responses[logo.path(for: .guest)] = response
            responses[logo.versionedPath(for: .guest)] = response
            responses[logo.legacyVersionedPath(for: .guest)] = response
        }
        if let logo = eventLogoImage {
            let response = ScoreboardWebAPIImageResponse(
                contentType: logo.mimeType,
                body: logo.data
            )
            responses[logo.path] = response
            responses[logo.versionedPath] = response
            responses[logo.legacyVersionedPath] = response
        }
        return responses
    }

    private func webAPIBackgroundImageMetadata() -> ScoreboardWebAPIBackgroundImage? {
        guard let image = externalDisplayBackgroundImage else {
            return nil
        }

        let path = image.path
        return ScoreboardWebAPIBackgroundImage(
            id: image.id,
            mimeType: image.mimeType,
            pixelWidth: image.pixelWidth,
            pixelHeight: image.pixelHeight,
            byteCount: image.byteCount,
            updatedAtUnixTime: image.updatedAtUnixTime,
            placement: ScoreboardWebAPIBackgroundImagePlacement(
                scale: image.scale,
                offsetX: image.offsetX,
                offsetY: image.offsetY
            ),
            path: path,
            downloadURLs: webAPIAbsoluteURLs(for: path)
        )
    }

    private func webAPITeamLogoMetadata(for side: TeamSide) -> ScoreboardWebAPITeamLogo? {
        guard showsTeamLogos else {
            return nil
        }
        guard let logo = teamLogoImage(for: side) else {
            return nil
        }

        let path = logo.path(for: side)
        return ScoreboardWebAPITeamLogo(
            id: logo.id,
            mimeType: logo.mimeType,
            pixelWidth: logo.pixelWidth,
            pixelHeight: logo.pixelHeight,
            byteCount: logo.byteCount,
            updatedAtUnixTime: logo.updatedAtUnixTime,
            path: path,
            downloadURLs: webAPIAbsoluteURLs(for: path)
        )
    }

    private func webAPIEventLogoMetadata() -> ScoreboardWebAPIEventLogo? {
        guard showsEventLogo else {
            return nil
        }
        guard let logo = eventLogoImage else {
            return nil
        }

        let path = logo.path
        return ScoreboardWebAPIEventLogo(
            id: logo.id,
            mimeType: logo.mimeType,
            pixelWidth: logo.pixelWidth,
            pixelHeight: logo.pixelHeight,
            byteCount: logo.byteCount,
            updatedAtUnixTime: logo.updatedAtUnixTime,
            path: path,
            downloadURLs: webAPIAbsoluteURLs(for: path)
        )
    }

    private func webAPIAbsoluteURLs(for path: String) -> [String] {
        let addresses = webAPILocalAddresses.isEmpty ? ScoreboardWebAPIService.localIPv4Addresses() : webAPILocalAddresses
        let resolvedAddresses = addresses.isEmpty ? ["127.0.0.1"] : addresses
        return resolvedAddresses.map { address in
            "http://\(address):\(ScoreboardWebAPIService.httpPort)\(path)"
        }
    }
}
