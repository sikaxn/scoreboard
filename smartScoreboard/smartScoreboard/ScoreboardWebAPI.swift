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
        current(apiVersion: "v1")
    }

    static func current(apiVersion: String) -> ScoreboardWebAPIAppInfo {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Scoreboard"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return ScoreboardWebAPIAppInfo(
            name: appName,
            version: appVersion,
            build: appBuild,
            apiVersion: apiVersion
        )
    }
}

nonisolated struct ScoreboardWebAPIRuntime: Codable, Sendable {
    let isGameRunning: Bool
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
    let showsDateTimeSeconds: Bool?
    let showsTeamLogos: Bool?
    let showsEventLogo: Bool?
    let eventLogo: ScoreboardWebAPIEventLogo?
    let viewMode: ScoreboardDisplayViewMode?
    let controlStatus: ScoreboardWebAPIDisplayControlStatus?
    let broadcastControl: ScoreboardWebAPIBroadcastControlStatus?
    let playerViewRosterScope: PlayerViewRosterScope?
    let direction: ScoreboardDisplayDirection?
    let remoteExternalDirection: ScoreboardDisplayDirection?
}

nonisolated struct ScoreboardWebAPIDisplayControlStatus: Codable, Sendable {
    let currentMode: ScoreboardDisplayViewMode
    let currentModeTitle: String
    let availableModes: [ScoreboardWebAPIDisplayControlMode]
    let isBlackScreen: Bool
    let isBackgroundOnly: Bool
    let isForegroundVisible: Bool
}

nonisolated struct ScoreboardWebAPIBroadcastControlStatus: Codable, Sendable {
    let isEnabled: Bool
    let enabledDisplayCount: Int
    let enabledDisplayIDs: [Int]
    let displayIDRange: ScoreboardWebAPIBroadcastDisplayIDRange
    let currentDisplayControlMode: ScoreboardDisplayViewMode
    let assignments: [ScoreboardWebAPIBroadcastDisplayAssignment]
}

nonisolated struct ScoreboardWebAPIBroadcastDisplayIDRange: Codable, Sendable {
    let minimum: Int
    let maximum: Int
}

nonisolated struct ScoreboardWebAPIBroadcastDisplayAssignment: Codable, Sendable {
    let displayID: Int
    let isEnabled: Bool
    let assignedMode: ScoreboardWebAPIBroadcastDisplayMode
    let assignedModeTitle: String
    let effectiveRenderMode: ScoreboardDisplayViewMode
    let followsDisplayControl: Bool
    let isCustomMode: Bool
}

nonisolated struct ScoreboardWebAPIDisplayControlMode: Codable, Sendable {
    let mode: ScoreboardDisplayViewMode
    let title: String
    let isSelected: Bool
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
    let supportsPeriodWins: Bool?
    let supportsShotClock: Bool
    let usesServeTimer: Bool?
    let supportsPossession: Bool
    let supportsFouls: Bool
    let supportsTeamFouls: Bool
    let supportsPlayerTracking: Bool
    let supportsCards: Bool
    let supportsSubstitutions: Bool
    let supportsPauses: Bool?
    let supportsHockeyPenalties: Bool
    let usesChessClocks: Bool
    let supportsInjuryTime: Bool?
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
    let periodsWon: Int?
    let setsWon: Int?
    let teamFouls: Int
    let substitutionsAllowed: Int
    let substitutionsUsed: Int
    let substitutionsRemaining: Int
    let pausesAllowed: Int?
    let pausesUsed: Int?
    let pausesRemaining: Int?
}

nonisolated struct ScoreboardWebAPIClocks: Codable, Sendable {
    let gameClockSeconds: Int
    let formattedGameClock: String
    let defaultClockSeconds: Int
    let showsGameClock: Bool
    let gameClockMode: GameClockMode
    let isGameClockRunning: Bool
    let pendingInjuryTimeMinutes: Int?
    let activeInjuryTimeMinutes: Int?
    let isInjuryTimeActive: Bool?
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

nonisolated enum ScoreboardWebAPIV2ResourceName: String, CaseIterable, Codable, Sendable {
    case game
    case runtime
    case display
    case rules
    case teams
    case clocks
    case players
    case debate
    case audio

    var path: String {
        "/api/v2/state/\(rawValue)"
    }
}

nonisolated struct ScoreboardWebAPIV2ResourcePayload: Sendable {
    let name: ScoreboardWebAPIV2ResourceName
    let revision: String
    let data: Data
}

nonisolated struct ScoreboardWebAPIV2StatePayload: Sendable {
    let manifestData: Data
    let resources: [ScoreboardWebAPIV2ResourcePayload]

    private let resourcesByName: [ScoreboardWebAPIV2ResourceName: ScoreboardWebAPIV2ResourcePayload]

    init(manifestData: Data, resources: [ScoreboardWebAPIV2ResourcePayload]) {
        self.manifestData = manifestData
        self.resources = resources
        self.resourcesByName = Dictionary(uniqueKeysWithValues: resources.map { ($0.name, $0) })
    }

    func resourceData(for path: String) -> Data? {
        guard path.hasPrefix("/api/v2/state/") else {
            return nil
        }
        let resourceName = String(path.dropFirst("/api/v2/state/".count))
        guard let name = ScoreboardWebAPIV2ResourceName(rawValue: resourceName) else {
            return nil
        }
        return resourcesByName[name]?.data
    }

    static let empty = ScoreboardWebAPIV2StatePayload(
        manifestData: Data(#"{"schemaVersion":2,"generatedAt":"","generatedAtUnixTime":null,"resources":[]}"#.utf8),
        resources: []
    )
}

nonisolated struct ScoreboardWebAPIV2ResourceLink: Codable, Sendable {
    let name: String
    let href: String
    let revision: String
}

nonisolated struct ScoreboardWebAPIV2StateManifest: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let generatedAtUnixTime: TimeInterval?
    let resources: [ScoreboardWebAPIV2ResourceLink]
}

nonisolated struct ScoreboardWebAPIV2ResourceEnvelope<Value: Encodable>: Encodable {
    let schemaVersion: Int
    let resource: String
    let revision: String
    let generatedAt: String
    let generatedAtUnixTime: TimeInterval?
    let data: Value
}

nonisolated struct ScoreboardWebAPIPayload: Sendable {
    let v1State: Data
    let v2State: ScoreboardWebAPIV2StatePayload

    static let empty = ScoreboardWebAPIPayload(
        v1State: Data(#"{"schemaVersion":1}"#.utf8),
        v2State: .empty
    )
}

nonisolated struct ScoreboardWebAPIRemoteDisplayStateV2: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let generatedAtUnixTime: TimeInterval?
    let game: ScoreboardGameSnapshot
    let runtime: ScoreboardWebAPIRuntime
    let display: ScoreboardWebAPIDisplay?
    let rules: ScoreboardWebAPIRules
    let teams: ScoreboardWebAPITeams
    let clocks: ScoreboardWebAPIClocks
    let players: ScoreboardWebAPIPlayers
    let debate: ScoreboardWebAPIDebate?
}

nonisolated struct ScoreboardRemoteDisplayEncodedStates: Sendable {
    let v1: Data
    let v2: Data

    func data(preferredVersion: Int) -> Data {
        preferredVersion == 2 && !v2.isEmpty ? v2 : v1
    }

    static let encodingFailed = ScoreboardRemoteDisplayEncodedStates(
        v1: Data(#"{"schemaVersion":1,"error":"encodingFailed"}"#.utf8),
        v2: Data(#"{"schemaVersion":2,"error":"encodingFailed"}"#.utf8)
    )
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

    var remoteDisplayV2Payload: ScoreboardWebAPIRemoteDisplayStateV2 {
        let payload = remoteDisplayPayload.v2ImagePathPayload
        return ScoreboardWebAPIRemoteDisplayStateV2(
            schemaVersion: 2,
            generatedAt: payload.generatedAt,
            generatedAtUnixTime: payload.generatedAtUnixTime,
            game: payload.game,
            runtime: payload.runtime,
            display: payload.display,
            rules: payload.rules,
            teams: payload.teams,
            clocks: payload.clocks,
            players: payload.players,
            debate: payload.debate
        )
    }

    var v2ImagePathPayload: ScoreboardWebAPIState {
        ScoreboardWebAPIState(
            schemaVersion: schemaVersion,
            generatedAt: generatedAt,
            generatedAtUnixTime: generatedAtUnixTime,
            app: app,
            game: game,
            runtime: runtime,
            display: display?.v2ImagePathPayload,
            audio: audio,
            rules: rules,
            teams: teams.v2ImagePathPayload,
            clocks: clocks,
            players: players,
            debate: debate
        )
    }
}

extension ScoreboardWebAPIRemoteDisplayStateV2 {
    var v1CompatibleState: ScoreboardWebAPIState {
        ScoreboardWebAPIState(
            schemaVersion: 1,
            generatedAt: generatedAt,
            generatedAtUnixTime: generatedAtUnixTime,
            app: ScoreboardWebAPIAppInfo.current(apiVersion: "v2"),
            game: game,
            runtime: runtime,
            display: display,
            audio: nil,
            rules: rules,
            teams: teams,
            clocks: clocks,
            players: players,
            debate: debate
        )
    }
}

extension ScoreboardWebAPIV2StatePayload {
    static func make(from state: ScoreboardWebAPIState) -> ScoreboardWebAPIV2StatePayload {
        let v2State = state.v2ImagePathPayload
        let generatedAt = v2State.generatedAt
        let generatedAtUnixTime = v2State.generatedAtUnixTime
        let resources: [ScoreboardWebAPIV2ResourcePayload] = [
            makeResource(.game, value: v2State.game, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime),
            makeResource(.runtime, value: v2State.runtime, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime),
            makeResource(.display, value: v2State.display, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime),
            makeResource(.rules, value: v2State.rules, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime),
            makeResource(.teams, value: v2State.teams, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime),
            makeResource(.clocks, value: v2State.clocks, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime),
            makeResource(.players, value: v2State.players, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime),
            makeResource(.debate, value: v2State.debate, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime),
            makeResource(.audio, value: v2State.audio, generatedAt: generatedAt, generatedAtUnixTime: generatedAtUnixTime)
        ]
        let manifest = ScoreboardWebAPIV2StateManifest(
            schemaVersion: 2,
            generatedAt: generatedAt,
            generatedAtUnixTime: generatedAtUnixTime,
            resources: resources.map {
                ScoreboardWebAPIV2ResourceLink(
                    name: $0.name.rawValue,
                    href: $0.name.path,
                    revision: $0.revision
                )
            }
        )
        let encoder = ScoreboardWebAPIJSON.encoder()
        let manifestData = (try? encoder.encode(manifest)) ?? Data(#"{"schemaVersion":2,"resources":[]}"#.utf8)
        return ScoreboardWebAPIV2StatePayload(manifestData: manifestData, resources: resources)
    }

    private static func makeResource<Value: Encodable>(
        _ name: ScoreboardWebAPIV2ResourceName,
        value: Value,
        generatedAt: String,
        generatedAtUnixTime: TimeInterval?
    ) -> ScoreboardWebAPIV2ResourcePayload {
        let encoder = ScoreboardWebAPIJSON.encoder()
        let bodyData = (try? encoder.encode(value)) ?? Data("null".utf8)
        let revision = bodyData.scoreboardWebAPIStableRevision
        let envelope = ScoreboardWebAPIV2ResourceEnvelope(
            schemaVersion: 2,
            resource: name.rawValue,
            revision: revision,
            generatedAt: generatedAt,
            generatedAtUnixTime: generatedAtUnixTime,
            data: value
        )
        let envelopeData = (try? encoder.encode(envelope)) ?? Data(#"{"schemaVersion":2,"resource":"\#(name.rawValue)","revision":"\#(revision)","generatedAt":"\#(generatedAt)","data":null}"#.utf8)
        return ScoreboardWebAPIV2ResourcePayload(name: name, revision: revision, data: envelopeData)
    }
}

extension ScoreboardWebAPIPayload {
    static func make(from state: ScoreboardWebAPIState) -> ScoreboardWebAPIPayload {
        let encoder = ScoreboardWebAPIJSON.encoder()
        let v1Data = (try? encoder.encode(state)) ?? Data(#"{"schemaVersion":1,"error":"encodingFailed"}"#.utf8)
        return ScoreboardWebAPIPayload(
            v1State: v1Data,
            v2State: ScoreboardWebAPIV2StatePayload.make(from: state)
        )
    }
}

extension ScoreboardWebAPIDisplay {
    var v2ImagePathPayload: ScoreboardWebAPIDisplay {
        ScoreboardWebAPIDisplay(
            theme: theme,
            backgroundMode: backgroundMode,
            backgroundImage: backgroundImage?.v2ImagePathPayload,
            animatedLogoStyle: animatedLogoStyle,
            animatedLogoBackgroundColor: animatedLogoBackgroundColor,
            animatedLogoSpeed: animatedLogoSpeed,
            animatedLogoSize: animatedLogoSize,
            animatedLogoOpacity: animatedLogoOpacity,
            showsDateTime: showsDateTime,
            dateTimeFormat: dateTimeFormat,
            showsDateTimeSeconds: showsDateTimeSeconds,
            showsTeamLogos: showsTeamLogos,
            showsEventLogo: showsEventLogo,
            eventLogo: eventLogo?.v2ImagePathPayload,
            viewMode: viewMode,
            controlStatus: controlStatus,
            broadcastControl: broadcastControl,
            playerViewRosterScope: playerViewRosterScope,
            direction: direction,
            remoteExternalDirection: remoteExternalDirection
        )
    }
}

extension ScoreboardWebAPITeams {
    var v2ImagePathPayload: ScoreboardWebAPITeams {
        ScoreboardWebAPITeams(
            home: home.v2ImagePathPayload,
            guest: guest.v2ImagePathPayload
        )
    }
}

extension ScoreboardWebAPITeam {
    var v2ImagePathPayload: ScoreboardWebAPITeam {
        ScoreboardWebAPITeam(
            side: side,
            name: name,
            roleLabel: roleLabel,
            logo: logo?.v2ImagePathPayload,
            score: score,
            periodsWon: periodsWon,
            setsWon: setsWon,
            teamFouls: teamFouls,
            substitutionsAllowed: substitutionsAllowed,
            substitutionsUsed: substitutionsUsed,
            substitutionsRemaining: substitutionsRemaining,
            pausesAllowed: pausesAllowed,
            pausesUsed: pausesUsed,
            pausesRemaining: pausesRemaining
        )
    }
}

extension ScoreboardWebAPIBackgroundImage {
    var v2ImagePathPayload: ScoreboardWebAPIBackgroundImage {
        let v2Path = path.scoreboardWebAPIV2ImagePath
        return ScoreboardWebAPIBackgroundImage(
            id: id,
            mimeType: mimeType,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            byteCount: byteCount,
            updatedAtUnixTime: updatedAtUnixTime,
            placement: placement,
            path: v2Path,
            downloadURLs: downloadURLs.scoreboardWebAPIV2ImageURLs
        )
    }
}

extension ScoreboardWebAPITeamLogo {
    var v2ImagePathPayload: ScoreboardWebAPITeamLogo {
        let v2Path = path.scoreboardWebAPIV2ImagePath
        return ScoreboardWebAPITeamLogo(
            id: id,
            mimeType: mimeType,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            byteCount: byteCount,
            updatedAtUnixTime: updatedAtUnixTime,
            path: v2Path,
            downloadURLs: downloadURLs.scoreboardWebAPIV2ImageURLs
        )
    }
}

extension ScoreboardWebAPIEventLogo {
    var v2ImagePathPayload: ScoreboardWebAPIEventLogo {
        let v2Path = path.scoreboardWebAPIV2ImagePath
        return ScoreboardWebAPIEventLogo(
            id: id,
            mimeType: mimeType,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            byteCount: byteCount,
            updatedAtUnixTime: updatedAtUnixTime,
            path: v2Path,
            downloadURLs: downloadURLs.scoreboardWebAPIV2ImageURLs
        )
    }
}

private enum ScoreboardWebAPIJSON {
    nonisolated static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

private extension String {
    var scoreboardWebAPIV2ImagePath: String {
        guard hasPrefix("/api/v1/") else {
            return self
        }
        return "/api/v2/" + dropFirst("/api/v1/".count)
    }
}

private extension Array where Element == String {
    var scoreboardWebAPIV2ImageURLs: [String] {
        map { $0.replacingOccurrences(of: "/api/v1/", with: "/api/v2/") }
    }
}

private extension Data {
    var scoreboardWebAPIStableRevision: String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in self {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

extension ScoreboardWebAPIDisplay {
    var resolvedViewMode: ScoreboardDisplayViewMode {
        viewMode ?? .scoreboard
    }

    var resolvedPlayerViewRosterScope: PlayerViewRosterScope {
        playerViewRosterScope ?? .fullRoster
    }

    var resolvedDirection: ScoreboardDisplayDirection {
        direction ?? .homeLeft
    }

    var resolvedRemoteExternalDirection: ScoreboardDisplayDirection? {
        remoteExternalDirection
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

    var resolvedShowsDateTimeSeconds: Bool {
        showsDateTimeSeconds ?? true
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
    private var latestPayload = ScoreboardWebAPIPayload.empty
    private var latestImageResponses: [String: ScoreboardWebAPIImageResponse] = [:]
    private var updateMode: ScoreboardWebAPIUpdateMode = .fixedInterval
    private var clients: [UUID: WebSocketClient] = [:]
    private var broadcastWorkItem: DispatchWorkItem?
    private var lastBroadcastDate: Date?

    func start(
        initialPayload: ScoreboardWebAPIPayload,
        updateMode: ScoreboardWebAPIUpdateMode,
        imageResponses: [String: ScoreboardWebAPIImageResponse],
        statusHandler: @escaping @Sendable (ScoreboardWebAPIStatus) -> Void
    ) {
        queue.async {
            self.statusHandler = statusHandler
            self.latestPayload = initialPayload
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

    func updateState(_ payload: ScoreboardWebAPIPayload, imageResponses: [String: ScoreboardWebAPIImageResponse]) {
        queue.async {
            self.latestPayload = payload
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

        #if ENABLE_CUSTOM_USER_PAGE
        if path == "/user" || path.hasPrefix("/user/") {
            if let response = ScoreboardCustomWebPage.response(forHTTPPath: path) {
                sendHTTPResponse(
                    connection,
                    statusCode: 200,
                    reason: "OK",
                    contentType: response.contentType,
                    body: response.body
                )
            } else {
                sendNotFoundResponse(connection, path: path)
            }
            return
        }
        #endif

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
                body: latestPayload.v1State,
                apiVersion: "v1"
            )
        case "/api/v1/health":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "application/json; charset=utf-8",
                body: healthDataLocked(),
                apiVersion: "v1"
            )
        case "/api/v2/status/api":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "application/json; charset=utf-8",
                body: apiStatusDataLocked(),
                apiVersion: "v2"
            )
        case "/api/v2/status/app":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "application/json; charset=utf-8",
                body: appStatusDataLocked(),
                apiVersion: "v2"
            )
        case "/api/v2/state":
            sendHTTPResponse(
                connection,
                statusCode: 200,
                reason: "OK",
                contentType: "application/json; charset=utf-8",
                body: latestPayload.v2State.manifestData,
                apiVersion: "v2"
            )
        default:
            if let resourceData = latestPayload.v2State.resourceData(for: path) {
                sendHTTPResponse(
                    connection,
                    statusCode: 200,
                    reason: "OK",
                    contentType: "application/json; charset=utf-8",
                    body: resourceData,
                    apiVersion: "v2"
                )
            } else if let imageResponse = latestImageResponses[path] {
                sendHTTPResponse(
                    connection,
                    statusCode: 200,
                    reason: "OK",
                    contentType: imageResponse.contentType,
                    body: imageResponse.body,
                    apiVersion: path.hasPrefix("/api/v2/") ? "v2" : "v1"
                )
            } else {
                sendNotFoundResponse(connection, path: path)
            }
        }
    }

    private func sendNotFoundResponse(_ connection: NWConnection, path: String) {
        if path.hasPrefix("/api/") {
            sendHTTPResponse(
                connection,
                statusCode: 404,
                reason: "Not Found",
                contentType: "application/json; charset=utf-8",
                body: Data(#"{"error":"notFound"}"#.utf8)
            )
            return
        }

        sendHTTPResponse(
            connection,
            statusCode: 404,
            reason: "Not Found",
            contentType: "text/html; charset=utf-8",
            body: Self.webAssetData(.notFound)
        )
    }

    private func sendHTTPResponse(
        _ connection: NWConnection,
        statusCode: Int,
        reason: String,
        contentType: String,
        body: Data,
        extraHeaders: [String] = [],
        apiVersion: String = "v1"
    ) {
        let appInfo = ScoreboardWebAPIAppInfo.current(apiVersion: apiVersion)
        var headers = [
            "HTTP/1.1 \(statusCode) \(reason)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Cache-Control: no-store",
            "X-SmartScoreboard-Version: \(Self.httpHeaderSafeValue(appInfo.version))",
            "X-SmartScoreboard-Build: \(Self.httpHeaderSafeValue(appInfo.build))",
            "X-SmartScoreboard-API-Version: \(Self.httpHeaderSafeValue(apiVersion))",
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
            latestV1EnvelopeProvider: { [weak self] in
                self?.latestEnvelopeDataLocked() ?? Data()
            },
            latestV2ManifestProvider: { [weak self] in
                self?.latestV2ManifestMessageDataLocked() ?? Data()
            },
            latestV2ResourcesProvider: { [weak self] in
                self?.latestPayload.v2State.resources ?? []
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
        for client in clients.values {
            client.sendLatestState()
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
        envelope.append(latestPayload.v1State)
        envelope.append(Data("}".utf8))
        return envelope
    }

    private func latestV2ManifestMessageDataLocked() -> Data {
        Self.v2ManifestMessageData(latestPayload.v2State.manifestData)
    }

    private static func v2ManifestMessageData(_ manifestData: Data) -> Data {
        var message = Data(#"{"type":"scoreboard.v2.manifest","schemaVersion":2,"payload":"#.utf8)
        message.append(manifestData)
        message.append(Data("}".utf8))
        return message
    }

    private static func v2ResourceMessageData(_ resource: ScoreboardWebAPIV2ResourcePayload) -> Data {
        var message = Data(#"{"type":"scoreboard.v2.resource","schemaVersion":2,"resource":"\#(resource.name.rawValue)","revision":"\#(resource.revision)","payload":"#.utf8)
        message.append(resource.data)
        message.append(Data("}".utf8))
        return message
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

    private func appStatusDataLocked() -> Data {
        let status = AppStatusResponse(
            schemaVersion: 2,
            app: ScoreboardWebAPIAppInfo.current(apiVersion: "v2"),
            generatedAt: Self.timestamp(),
            generatedAtUnixTime: Date().timeIntervalSince1970
        )
        let encoder = ScoreboardWebAPIJSON.encoder()
        return (try? encoder.encode(status)) ?? Data(#"{"schemaVersion":2,"status":"failed"}"#.utf8)
    }

    private func apiStatusDataLocked() -> Data {
        let response = APIStatusResponse(
            schemaVersion: 2,
            service: "smartscoreboard.web_api",
            apiVersion: "v2",
            supportedAPIVersions: ["v1", "v2"],
            status: status.healthValue,
            httpPort: Self.httpPort,
            webSocketPort: Self.webSocketPort,
            updateMode: updateMode.rawValue,
            maximumFixedIntervalUpdatesPerSecond: Int(1 / minimumBroadcastInterval),
            webSocketClientCount: clients.count,
            generatedAt: Self.timestamp(),
            generatedAtUnixTime: Date().timeIntervalSince1970
        )
        let encoder = ScoreboardWebAPIJSON.encoder()
        return (try? encoder.encode(response)) ?? Data(#"{"schemaVersion":2,"status":"failed"}"#.utf8)
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

    private struct AppStatusResponse: Codable {
        let schemaVersion: Int
        let app: ScoreboardWebAPIAppInfo
        let generatedAt: String
        let generatedAtUnixTime: TimeInterval
    }

    private struct APIStatusResponse: Codable {
        let schemaVersion: Int
        let service: String
        let apiVersion: String
        let supportedAPIVersions: [String]
        let status: String
        let httpPort: UInt16
        let webSocketPort: UInt16
        let updateMode: String
        let maximumFixedIntervalUpdatesPerSecond: Int
        let webSocketClientCount: Int
        let generatedAt: String
        let generatedAtUnixTime: TimeInterval
    }

    private final class WebSocketClient: @unchecked Sendable {
        let id: UUID
        private let connection: NWConnection
        private let queue: DispatchQueue
        private let maxFrameBytes: Int
        private let latestV1EnvelopeProvider: @Sendable () -> Data
        private let latestV2ManifestProvider: @Sendable () -> Data
        private let latestV2ResourcesProvider: @Sendable () -> [ScoreboardWebAPIV2ResourcePayload]
        private let onClose: @Sendable (UUID) -> Void
        private var isClosed = false
        private var pendingSends = 0
        private var initialV1WorkItem: DispatchWorkItem?
        private var isSubscribedToV2 = false
        private var sentV2ResourceRevisions: [ScoreboardWebAPIV2ResourceName: String] = [:]

        init(
            id: UUID,
            connection: NWConnection,
            queue: DispatchQueue,
            maxFrameBytes: Int,
            latestV1EnvelopeProvider: @escaping @Sendable () -> Data,
            latestV2ManifestProvider: @escaping @Sendable () -> Data,
            latestV2ResourcesProvider: @escaping @Sendable () -> [ScoreboardWebAPIV2ResourcePayload],
            onClose: @escaping @Sendable (UUID) -> Void
        ) {
            self.id = id
            self.connection = connection
            self.queue = queue
            self.maxFrameBytes = maxFrameBytes
            self.latestV1EnvelopeProvider = latestV1EnvelopeProvider
            self.latestV2ManifestProvider = latestV2ManifestProvider
            self.latestV2ResourcesProvider = latestV2ResourcesProvider
            self.onClose = onClose
        }

        func start() {
            guard !isClosed else { return }
            connection.stateUpdateHandler = { state in
                self.queue.async {
                    switch state {
                    case .ready:
                        self.receiveNextMessage()
                        self.scheduleInitialV1Send()
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

        private func scheduleInitialV1Send() {
            initialV1WorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, !self.isClosed, !self.isSubscribedToV2 else {
                    return
                }
                self.sendText(self.latestV1EnvelopeProvider())
            }
            initialV1WorkItem = item
            queue.asyncAfter(deadline: .now() + 0.10, execute: item)
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
            if isV2SubscribePayload(payload) {
                initialV1WorkItem?.cancel()
                initialV1WorkItem = nil
                isSubscribedToV2 = true
                sendV2Snapshot(forceResources: true)
            } else if normalized == "get" ||
                normalized.contains(#""type":"get""#) ||
                normalized.contains(#""type": "get""#) {
                initialV1WorkItem?.cancel()
                initialV1WorkItem = nil
                if isSubscribedToV2 {
                    sendV2Snapshot(forceResources: true)
                } else {
                    sendText(latestV1EnvelopeProvider())
                }
            } else {
                sendError("SmartScoreboard Web API is read only. Send {\"type\":\"subscribe\",\"apiVersion\":\"v2\"} for v2 resources or {\"type\":\"get\"} for v1 state.")
            }
        }

        private func isV2SubscribePayload(_ payload: Data) -> Bool {
            guard
                let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                let type = object["type"] as? String,
                type.caseInsensitiveCompare("subscribe") == .orderedSame
            else {
                return false
            }

            if let apiVersion = object["apiVersion"] as? String {
                return apiVersion.caseInsensitiveCompare("v2") == .orderedSame || apiVersion == "2"
            }
            if let apiVersion = object["apiVersion"] as? Int {
                return apiVersion == 2
            }
            return false
        }

        func sendLatestState() {
            guard !isClosed else { return }
            if isSubscribedToV2 {
                sendV2Snapshot(forceResources: false)
            } else {
                sendText(latestV1EnvelopeProvider())
            }
        }

        private func sendV2Snapshot(forceResources: Bool) {
            let resources = latestV2ResourcesProvider()
            let changedResources = resources.filter { resource in
                forceResources || sentV2ResourceRevisions[resource.name] != resource.revision
            }
            guard forceResources || !changedResources.isEmpty else {
                return
            }

            sendText(latestV2ManifestProvider())
            for resource in changedResources {
                sentV2ResourceRevisions[resource.name] = resource.revision
                sendText(ScoreboardWebAPIService.v2ResourceMessageData(resource))
            }
        }

        func sendText(_ data: Data) {
            guard !isClosed else { return }
            guard pendingSends < 32 else {
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
            initialV1WorkItem?.cancel()
            initialV1WorkItem = nil
            connection.cancel()
            onClose(id)
        }
    }

    private enum WebAsset {
        case docs
        case scoreboard
        case obs
        case notFound

        var assetName: String {
            switch self {
            case .docs:
                return "WebAPIDocs"
            case .scoreboard:
                return "WebAPIScoreboardDemo"
            case .obs:
                return "WebAPIOBSDemo"
            case .notFound:
                return "WebAPI404"
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
        currentWebAPIState(
            displayDirection: resolvedExternalDisplayDirection,
            remoteExternalDirection: nil
        )
    }

    func currentRemoteDisplayState(forDisplayID displayID: String?) -> ScoreboardWebAPIState {
        let displayDirection = displayID.map { resolvedRemoteDisplayDirection(displayID: $0) } ?? resolvedDisplayDirection(for: .homeLeft)
        let externalDirection = displayID.map { resolvedRemoteDisplayExternalDirection(displayID: $0) } ?? resolvedDisplayDirection(for: .homeLeft)
        return currentWebAPIState(
            displayDirection: displayDirection,
            remoteExternalDirection: externalDirection
        ).remoteDisplayPayload
    }

    private func currentWebAPIState(
        displayDirection: ScoreboardDisplayDirection,
        remoteExternalDirection: ScoreboardDisplayDirection?
    ) -> ScoreboardWebAPIState {
        let now = Date()
        let rules = currentRules

        return ScoreboardWebAPIState(
            schemaVersion: 1,
            generatedAt: ISO8601DateFormatter().string(from: now),
            generatedAtUnixTime: now.timeIntervalSince1970,
            app: ScoreboardWebAPIAppInfo.current,
            game: currentGameSnapshot().excludingEmbeddedImages,
            runtime: ScoreboardWebAPIRuntime(
                isGameRunning: isGameRunning,
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
                showsDateTimeSeconds: showsExternalDisplayDateTimeSeconds,
                showsTeamLogos: showsTeamLogos,
                showsEventLogo: showsEventLogo,
                eventLogo: webAPIEventLogoMetadata(),
                viewMode: publicDisplayViewMode,
                controlStatus: webAPIDisplayControlStatus(),
                broadcastControl: webAPIBroadcastControlStatus(),
                playerViewRosterScope: .fullRoster,
                direction: displayDirection,
                remoteExternalDirection: remoteExternalDirection
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
                supportsPeriodWins: supportsPeriodWinTracking,
                supportsShotClock: supportsShotClock,
                usesServeTimer: usesServeTimer,
                supportsPossession: supportsPossession,
                supportsFouls: supportsFouls,
                supportsTeamFouls: supportsTeamFouls,
                supportsPlayerTracking: supportsPlayerTracking,
                supportsCards: supportsCards,
                supportsSubstitutions: rules.showsSubstitutionTracking || showsSubstitutionTracking,
                supportsPauses: rules.showsPauseTracking || showsPauseTracking,
                supportsHockeyPenalties: supportsHockeyPenalties,
                usesChessClocks: usesChessClocks,
                supportsInjuryTime: supportsInjuryTime
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
                pendingInjuryTimeMinutes: pendingInjuryTimeMinutes,
                activeInjuryTimeMinutes: activeInjuryTimeMinutes,
                isInjuryTimeActive: isInjuryTimeActive,
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
            periodsWon: supportsPeriodWinTracking ? periodWins(for: side) : nil,
            setsWon: supportsPeriodWinTracking ? periodWins(for: side) : nil,
            teamFouls: teamFouls(for: side),
            substitutionsAllowed: substitutionsAllowed(for: side),
            substitutionsUsed: substitutionsUsed(for: side),
            substitutionsRemaining: substitutionsRemaining(for: side),
            pausesAllowed: pausesAllowed(for: side),
            pausesUsed: pausesUsed(for: side),
            pausesRemaining: pausesRemaining(for: side)
        )
    }

    private func webAPIDisplayControlStatus() -> ScoreboardWebAPIDisplayControlStatus {
        let currentMode = publicDisplayViewMode
        let modes: [ScoreboardDisplayViewMode] = [
            .blackScreen,
            .backgroundOnly,
            .eventLogo,
            .teamView,
            .playerView,
            .scoreboard
        ]
        return ScoreboardWebAPIDisplayControlStatus(
            currentMode: currentMode,
            currentModeTitle: currentMode.title,
            availableModes: modes.map { mode in
                ScoreboardWebAPIDisplayControlMode(
                    mode: mode,
                    title: mode.title,
                    isSelected: mode == currentMode
                )
            },
            isBlackScreen: currentMode == .blackScreen,
            isBackgroundOnly: currentMode == .backgroundOnly,
            isForegroundVisible: currentMode != .blackScreen && currentMode != .backgroundOnly
        )
    }

    private func webAPIBroadcastControlStatus() -> ScoreboardWebAPIBroadcastControlStatus {
        let currentMode = publicDisplayViewMode
        let enabledDisplayIDs = isWebAPIBroadcastControlEnabled
            ? Array(ScoreboardStore.minWebAPIBroadcastCustomDisplayID...webAPIBroadcastEnabledDisplayCount)
            : []
        let assignments = (ScoreboardStore.minWebAPIBroadcastDisplayID...ScoreboardStore.maxWebAPIBroadcastDisplayID).map { displayID in
            webAPIBroadcastDisplayAssignment(displayID: displayID, currentDisplayControlMode: currentMode)
        }

        return ScoreboardWebAPIBroadcastControlStatus(
            isEnabled: isWebAPIBroadcastControlEnabled,
            enabledDisplayCount: isWebAPIBroadcastControlEnabled ? webAPIBroadcastEnabledDisplayCount : 0,
            enabledDisplayIDs: enabledDisplayIDs,
            displayIDRange: ScoreboardWebAPIBroadcastDisplayIDRange(
                minimum: ScoreboardStore.minWebAPIBroadcastDisplayID,
                maximum: ScoreboardStore.maxWebAPIBroadcastDisplayID
            ),
            currentDisplayControlMode: currentMode,
            assignments: assignments
        )
    }

    private func webAPIBroadcastDisplayAssignment(
        displayID: Int,
        currentDisplayControlMode: ScoreboardDisplayViewMode
    ) -> ScoreboardWebAPIBroadcastDisplayAssignment {
        let isInternalFallbackDisplay = displayID == ScoreboardStore.minWebAPIBroadcastDisplayID
        let isEnabledDisplay = isWebAPIBroadcastControlEnabled &&
            displayID >= ScoreboardStore.minWebAPIBroadcastCustomDisplayID &&
            displayID <= webAPIBroadcastEnabledDisplayCount
        let isEnabled = isInternalFallbackDisplay || isEnabledDisplay
        let assignedMode: ScoreboardWebAPIBroadcastDisplayMode = isEnabledDisplay
            ? webAPIBroadcastDisplayMode(for: displayID)
            : .followDisplayControl

        return ScoreboardWebAPIBroadcastDisplayAssignment(
            displayID: displayID,
            isEnabled: isEnabled,
            assignedMode: assignedMode,
            assignedModeTitle: assignedMode.title,
            effectiveRenderMode: assignedMode.effectiveRenderMode(fallbackDisplayControlMode: currentDisplayControlMode),
            followsDisplayControl: assignedMode.followsDisplayControl,
            isCustomMode: assignedMode.isCustomMode
        )
    }

    func currentWebAPIImageResponses() -> [String: ScoreboardWebAPIImageResponse] {
        var responses: [String: ScoreboardWebAPIImageResponse] = [:]
        if let image = externalDisplayBackgroundImage {
            let response = ScoreboardWebAPIImageResponse(
                contentType: image.mimeType,
                body: image.data
            )
            addWebAPIImageResponse(response, path: image.path, to: &responses)
            addWebAPIImageResponse(response, path: image.versionedPath, to: &responses)
            addWebAPIImageResponse(response, path: image.legacyVersionedPath, to: &responses)
        }
        if let logo = homeTeamLogoImage {
            let response = ScoreboardWebAPIImageResponse(
                contentType: logo.mimeType,
                body: logo.data
            )
            addWebAPIImageResponse(response, path: logo.path(for: .home), to: &responses)
            addWebAPIImageResponse(response, path: logo.versionedPath(for: .home), to: &responses)
            addWebAPIImageResponse(response, path: logo.legacyVersionedPath(for: .home), to: &responses)
        }
        if let logo = guestTeamLogoImage {
            let response = ScoreboardWebAPIImageResponse(
                contentType: logo.mimeType,
                body: logo.data
            )
            addWebAPIImageResponse(response, path: logo.path(for: .guest), to: &responses)
            addWebAPIImageResponse(response, path: logo.versionedPath(for: .guest), to: &responses)
            addWebAPIImageResponse(response, path: logo.legacyVersionedPath(for: .guest), to: &responses)
        }
        if let logo = eventLogoImage {
            let response = ScoreboardWebAPIImageResponse(
                contentType: logo.mimeType,
                body: logo.data
            )
            addWebAPIImageResponse(response, path: logo.path, to: &responses)
            addWebAPIImageResponse(response, path: logo.versionedPath, to: &responses)
            addWebAPIImageResponse(response, path: logo.legacyVersionedPath, to: &responses)
        }
        return responses
    }

    private func addWebAPIImageResponse(
        _ response: ScoreboardWebAPIImageResponse,
        path: String,
        to responses: inout [String: ScoreboardWebAPIImageResponse]
    ) {
        responses[path] = response
        responses[path.scoreboardWebAPIV2ImagePath] = response
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
