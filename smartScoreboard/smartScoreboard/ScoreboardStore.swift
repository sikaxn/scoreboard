import Combine
import Foundation
import OSLog

private enum ExternalAutomationIntegration {
    case companion
    case webAPI
}

private enum ScoreboardLocalizedFormatArgumentType {
    case object
    case signedInteger(length: String?)
    case unsignedInteger(length: String?)
    case floatingPoint
    case character
    case cString
}

private struct ScoreboardLocalizedFormatPlaceholder {
    let position: Int?
    let argumentType: ScoreboardLocalizedFormatArgumentType
}

private enum ScoreboardLocalizedFormatNormalizer {
    nonisolated private static let placeholderPattern = "%(?:(\\d+)\\$)?[-+#0 ]*(?:\\d+|\\*)?(?:\\.(?:\\d+|\\*))?(hh|h|ll|l|q|L|z|t|j)?([@diuoxXfFeEgGaAcCsS])"

    nonisolated static func normalizedArguments(for format: String, arguments: [Any]) -> [CVarArg] {
        let placeholders = placeholders(in: format)
        guard !placeholders.isEmpty else {
            return arguments.map { fallbackArgument($0) }
        }

        var argumentTypes: [Int: ScoreboardLocalizedFormatArgumentType] = [:]
        var nextSequentialIndex = 0
        for placeholder in placeholders {
            let argumentIndex: Int
            if let position = placeholder.position {
                argumentIndex = max(0, position - 1)
            } else {
                argumentIndex = nextSequentialIndex
                nextSequentialIndex += 1
            }

            if argumentTypes[argumentIndex] == nil {
                argumentTypes[argumentIndex] = placeholder.argumentType
            }
        }

        return arguments.enumerated().map { index, argument in
            normalize(argument, as: argumentTypes[index])
        }
    }

    nonisolated private static func placeholders(in format: String) -> [ScoreboardLocalizedFormatPlaceholder] {
        guard let regex = try? NSRegularExpression(pattern: placeholderPattern) else {
            return []
        }

        let range = NSRange(format.startIndex..<format.endIndex, in: format)
        return regex.matches(in: format, range: range).compactMap { match in
            let position: Int?
            if let positionRange = Range(match.range(at: 1), in: format), !positionRange.isEmpty {
                position = Int(format[positionRange])
            } else {
                position = nil
            }

            let length: String?
            if let lengthRange = Range(match.range(at: 2), in: format), !lengthRange.isEmpty {
                length = String(format[lengthRange])
            } else {
                length = nil
            }

            guard let conversionRange = Range(match.range(at: 3), in: format),
                  let conversion = format[conversionRange].first else {
                return nil
            }

            return ScoreboardLocalizedFormatPlaceholder(
                position: position,
                argumentType: argumentType(conversion: conversion, length: length)
            )
        }
    }

    nonisolated private static func argumentType(conversion: Character, length: String?) -> ScoreboardLocalizedFormatArgumentType {
        switch conversion {
        case "@":
            return .object
        case "d", "i":
            return .signedInteger(length: length)
        case "u", "o", "x", "X":
            return .unsignedInteger(length: length)
        case "f", "F", "e", "E", "g", "G", "a", "A":
            return .floatingPoint
        case "c", "C":
            return .character
        case "s", "S":
            return .cString
        default:
            return .object
        }
    }

    nonisolated private static func normalize(_ value: Any, as argumentType: ScoreboardLocalizedFormatArgumentType?) -> CVarArg {
        guard let argumentType else {
            return fallbackArgument(value)
        }

        switch argumentType {
        case .object:
            return objectArgument(value)
        case .signedInteger(let length):
            return signedIntegerArgument(value, length: length)
        case .unsignedInteger(let length):
            return unsignedIntegerArgument(value, length: length)
        case .floatingPoint:
            return doubleArgument(value)
        case .character:
            return Int32(clamping: integerValue(value))
        case .cString:
            return stringValue(value)
        }
    }

    nonisolated private static func fallbackArgument(_ value: Any) -> CVarArg {
        if let argument = value as? CVarArg {
            return argument
        }
        return stringValue(value) as NSString
    }

    nonisolated private static func objectArgument(_ value: Any) -> CVarArg {
        if let string = value as? String {
            return string as NSString
        }
        if let substring = value as? Substring {
            return String(substring) as NSString
        }
        if let object = value as? NSObject {
            return object
        }
        return stringValue(value) as NSString
    }

    nonisolated private static func signedIntegerArgument(_ value: Any, length: String?) -> CVarArg {
        let integer = integerValue(value)
        switch length {
        case "ll", "q", "j":
            return Int64(integer)
        case "l", "z", "t":
            return Int(integer)
        case "h":
            return Int16(clamping: integer)
        case "hh":
            return Int8(clamping: integer)
        default:
            return Int32(clamping: integer)
        }
    }

    nonisolated private static func unsignedIntegerArgument(_ value: Any, length: String?) -> CVarArg {
        let unsigned = unsignedIntegerValue(value)
        switch length {
        case "ll", "q", "j":
            return UInt64(unsigned)
        case "l", "z", "t":
            return UInt(unsigned)
        case "h":
            return UInt16(clamping: unsigned)
        case "hh":
            return UInt8(clamping: unsigned)
        default:
            return UInt32(clamping: unsigned)
        }
    }

    nonisolated private static func integerValue(_ value: Any) -> Int64 {
        switch value {
        case let number as Int:
            return Int64(number)
        case let number as Int8:
            return Int64(number)
        case let number as Int16:
            return Int64(number)
        case let number as Int32:
            return Int64(number)
        case let number as Int64:
            return number
        case let number as UInt:
            return Int64(clamping: number)
        case let number as UInt8:
            return Int64(number)
        case let number as UInt16:
            return Int64(number)
        case let number as UInt32:
            return Int64(number)
        case let number as UInt64:
            return Int64(clamping: number)
        case let number as Double:
            return Int64(number)
        case let number as Float:
            return Int64(number)
        case let number as Bool:
            return number ? 1 : 0
        case let number as NSNumber:
            return number.int64Value
        case let string as String:
            return Int64(string) ?? 0
        default:
            return 0
        }
    }

    nonisolated private static func unsignedIntegerValue(_ value: Any) -> UInt64 {
        switch value {
        case let number as UInt:
            return UInt64(number)
        case let number as UInt8:
            return UInt64(number)
        case let number as UInt16:
            return UInt64(number)
        case let number as UInt32:
            return UInt64(number)
        case let number as UInt64:
            return number
        case let number as Int:
            return UInt64(clamping: number)
        case let number as Int8:
            return UInt64(clamping: number)
        case let number as Int16:
            return UInt64(clamping: number)
        case let number as Int32:
            return UInt64(clamping: number)
        case let number as Int64:
            return UInt64(clamping: number)
        case let number as Double:
            return UInt64(number)
        case let number as Float:
            return UInt64(number)
        case let number as Bool:
            return number ? 1 : 0
        case let number as NSNumber:
            return number.uint64Value
        case let string as String:
            return UInt64(string) ?? 0
        default:
            return 0
        }
    }

    nonisolated private static func doubleArgument(_ value: Any) -> CVarArg {
        switch value {
        case let number as Double:
            return number
        case let number as Float:
            return Double(number)
        case let number as CGFloat:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let number as Int:
            return Double(number)
        case let number as Int64:
            return Double(number)
        case let number as UInt:
            return Double(number)
        case let number as UInt64:
            return Double(number)
        case let string as String:
            return Double(string) ?? 0
        default:
            return 0.0
        }
    }

    nonisolated private static func stringValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let substring = value as? Substring {
            return String(substring)
        }
        return String(describing: value)
    }
}

nonisolated func scoreboardLocalizedFormat(_ format: String, locale: Locale = .current, arguments: [Any]) -> String {
    String(
        format: format,
        locale: locale,
        arguments: ScoreboardLocalizedFormatNormalizer.normalizedArguments(for: format, arguments: arguments)
    )
}

nonisolated private func localizedStoreString(_ key: String) -> String {
    ScoreboardLocalization.string(key)
}

nonisolated private func localizedStoreFormat(_ key: String, _ arguments: Any...) -> String {
    scoreboardLocalizedFormat(localizedStoreString(key), locale: Locale.current, arguments: arguments)
}

private func signedStoreDelta(_ delta: Int, suffix: String = "") -> String {
    "\(delta >= 0 ? "+" : "")\(delta)\(suffix)"
}

struct ScoreboardRemoteDisplayWarningNotice: Equatable, Identifiable {
    enum Kind: Equatable {
        case disconnected
        case unresponsive
    }

    let id: UUID
    let kind: Kind
    let displayIDs: Set<String>
    let message: String
    let detail: String

    init(kind: Kind, displaysByID: [String: String]) {
        id = UUID()
        self.kind = kind
        displayIDs = Set(displaysByID.keys)

        let names = displaysByID.values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let joinedNames = names.joined(separator: ", ")

        switch kind {
        case .disconnected:
            message = localizedStoreString("Remote Display disconnected")
            if names.count == 1, let name = names.first {
                detail = localizedStoreFormat("%@ disconnected. Waiting for Remote Display to reconnect.", name)
            } else {
                detail = localizedStoreFormat("%d Remote Displays disconnected: %@", names.count, joinedNames)
            }
        case .unresponsive:
            message = localizedStoreString("Remote Display not responding")
            if names.count == 1, let name = names.first {
                detail = localizedStoreFormat("No reply from %@. Check the Remote Display connection.", name)
            } else {
                detail = localizedStoreFormat("%d Remote Displays are not replying: %@", names.count, joinedNames)
            }
        }
    }
}

enum PossessionDirection: String, Codable, CaseIterable {
    case home
    case none
    case guest

    var displayName: String {
        switch self {
        case .home:
            return NSLocalizedString("HOME", comment: "")
        case .guest:
            return NSLocalizedString("GUEST", comment: "")
        case .none:
            return NSLocalizedString("OFF", comment: "")
        }
    }
}

enum TeamSide: String, Codable, CaseIterable, Identifiable, Sendable {
    case home
    case guest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return NSLocalizedString("Home", comment: "")
        case .guest:
            return NSLocalizedString("Guest", comment: "")
        }
    }
}

enum VolleyballMatchFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case bestOf3
    case bestOf5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestOf3:
            return NSLocalizedString("Best of 3", comment: "")
        case .bestOf5:
            return NSLocalizedString("Best of 5", comment: "")
        }
    }

    var maximumSets: Int {
        switch self {
        case .bestOf3:
            return 3
        case .bestOf5:
            return 5
        }
    }

    var setsToWin: Int {
        switch self {
        case .bestOf3:
            return 2
        case .bestOf5:
            return 3
        }
    }

    func targetPoints(forSet set: Int) -> Int {
        set == maximumSets ? 15 : 25
    }
}

struct VolleyballSetResult: Codable, Equatable, Identifiable, Sendable {
    var setNumber: Int
    var winner: TeamSide
    var homeScore: Int
    var guestScore: Int

    var id: Int { setNumber }
}

nonisolated enum ScoreboardDisplayDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case homeLeft
    case guestLeft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .homeLeft:
            return NSLocalizedString("Home Left", comment: "")
        case .guestLeft:
            return NSLocalizedString("Guest Left", comment: "")
        }
    }

    var leftSide: TeamSide {
        switch self {
        case .homeLeft:
            return .home
        case .guestLeft:
            return .guest
        }
    }

    var rightSide: TeamSide {
        leftSide == .home ? .guest : .home
    }

    var areSidesSwapped: Bool {
        self == .guestLeft
    }

    init(areSidesSwapped: Bool) {
        self = areSidesSwapped ? .guestLeft : .homeLeft
    }

    func toggled() -> ScoreboardDisplayDirection {
        self == .homeLeft ? .guestLeft : .homeLeft
    }

    func applyingSideSwap(_ areSidesSwapped: Bool) -> ScoreboardDisplayDirection {
        areSidesSwapped ? toggled() : self
    }
}

enum PlayerFoulHighlightColor: String, Codable, CaseIterable, Identifiable {
    case red
    case orange
    case yellow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .red:
            return NSLocalizedString("Red", comment: "")
        case .orange:
            return NSLocalizedString("Orange", comment: "")
        case .yellow:
            return NSLocalizedString("Yellow", comment: "")
        }
    }
}

enum PlayerLineupOverflowMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case scroll
    case fade
    case fit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scroll:
            return NSLocalizedString("Auto Scroll", comment: "")
        case .fade:
            return NSLocalizedString("Paged Fade", comment: "")
        case .fit:
            return NSLocalizedString("Adaptive Fit", comment: "")
        }
    }
}

enum PlayerLineupScrollDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case continuousUp
    case throughUp
    case continuousDown
    case throughDown
    case bounce

    var id: String { rawValue }

    var title: String {
        switch self {
        case .continuousUp:
            return NSLocalizedString("Scroll Up Continuous", comment: "")
        case .throughUp:
            return NSLocalizedString("Scroll Up Through", comment: "")
        case .continuousDown:
            return NSLocalizedString("Scroll Down Continuous", comment: "")
        case .throughDown:
            return NSLocalizedString("Scroll Down Through", comment: "")
        case .bounce:
            return NSLocalizedString("Bounce Back and Forth", comment: "")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""
        switch rawValue {
        case Self.continuousUp.rawValue:
            self = .continuousUp
        case Self.throughUp.rawValue:
            self = .throughUp
        case Self.continuousDown.rawValue:
            self = .continuousDown
        case Self.throughDown.rawValue:
            self = .throughDown
        case Self.bounce.rawValue, "up", "down":
            self = .bounce
        default:
            self = .continuousUp
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum ScoreboardDisplayViewMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case scoreboard
    case blackScreen
    case backgroundOnly
    case teamView
    case playerView
    case eventLogo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scoreboard:
            return NSLocalizedString("Scoreboard", comment: "")
        case .blackScreen:
            return NSLocalizedString("Black Screen", comment: "")
        case .backgroundOnly:
            return NSLocalizedString("Background Only", comment: "")
        case .teamView:
            return NSLocalizedString("Team View", comment: "")
        case .playerView:
            return NSLocalizedString("Player View", comment: "")
        case .eventLogo:
            return NSLocalizedString("Event Logo", comment: "")
        }
    }

    var systemImage: String {
        switch self {
        case .scoreboard:
            return "display"
        case .blackScreen:
            return "rectangle.fill"
        case .backgroundOnly:
            return "photo"
        case .teamView:
            return "person.2"
        case .playerView:
            return "list.bullet"
        case .eventLogo:
            return "seal"
        }
    }
}

enum ScoreboardWebAPIBroadcastDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case followDisplayControl
    case scoreboard
    case blackScreen
    case backgroundOnly
    case eventLogo
    case teamView
    case playerView
    case custom1
    case custom2
    case custom3

    var id: String { rawValue }

    static let customizableModes: [ScoreboardWebAPIBroadcastDisplayMode] = [.custom1, .custom2, .custom3]

    var title: String {
        switch self {
        case .followDisplayControl:
            return NSLocalizedString("Follow Main", comment: "")
        case .scoreboard:
            return ScoreboardDisplayViewMode.scoreboard.title
        case .blackScreen:
            return ScoreboardDisplayViewMode.blackScreen.title
        case .backgroundOnly:
            return ScoreboardDisplayViewMode.backgroundOnly.title
        case .eventLogo:
            return ScoreboardDisplayViewMode.eventLogo.title
        case .teamView:
            return ScoreboardDisplayViewMode.teamView.title
        case .playerView:
            return ScoreboardDisplayViewMode.playerView.title
        case .custom1:
            return NSLocalizedString("Custom 1", comment: "")
        case .custom2:
            return NSLocalizedString("Custom 2", comment: "")
        case .custom3:
            return NSLocalizedString("Custom 3", comment: "")
        }
    }

    var displayViewMode: ScoreboardDisplayViewMode? {
        switch self {
        case .followDisplayControl, .custom1, .custom2, .custom3:
            return nil
        case .scoreboard:
            return .scoreboard
        case .blackScreen:
            return .blackScreen
        case .backgroundOnly:
            return .backgroundOnly
        case .eventLogo:
            return .eventLogo
        case .teamView:
            return .teamView
        case .playerView:
            return .playerView
        }
    }

    var isCustomMode: Bool {
        switch self {
        case .custom1, .custom2, .custom3:
            return true
        case .followDisplayControl, .scoreboard, .blackScreen, .backgroundOnly, .eventLogo, .teamView, .playerView:
            return false
        }
    }

    var followsDisplayControl: Bool {
        displayViewMode == nil
    }

    func effectiveRenderMode(fallbackDisplayControlMode: ScoreboardDisplayViewMode) -> ScoreboardDisplayViewMode {
        displayViewMode ?? fallbackDisplayControlMode
    }
}

enum PlayerViewRosterScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case activeLineup
    case fullRoster

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activeLineup:
            return NSLocalizedString("Active Lineup", comment: "")
        case .fullRoster:
            return NSLocalizedString("Full Roster", comment: "")
        }
    }
}

enum PlayerCardStatus: String, Codable, CaseIterable, Identifiable {
    case none
    case yellow
    case red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return NSLocalizedString("None", comment: "")
        case .yellow:
            return NSLocalizedString("Yellow", comment: "")
        case .red:
            return NSLocalizedString("Red", comment: "")
        }
    }
}

struct HockeyPenaltyTimer: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var teamSide: TeamSide
    var playerNumber: String
    var playerName: String
    var remainingSeconds: Int
    var isRunning: Bool

    init(
        id: UUID = UUID(),
        teamSide: TeamSide,
        playerNumber: String = "",
        playerName: String = "",
        remainingSeconds: Int,
        isRunning: Bool = false
    ) {
        self.id = id
        self.teamSide = teamSide
        self.playerNumber = playerNumber
        self.playerName = playerName
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
    }
}

struct TrackedPlayer: Identifiable, Codable, Equatable {
    let id: UUID
    var number: String
    var name: String
    var foulCount: Int
    var cardStatus: PlayerCardStatus
    var isInActiveLineup: Bool

    nonisolated init(
        id: UUID = UUID(),
        number: String,
        name: String = "",
        foulCount: Int = 0,
        cardStatus: PlayerCardStatus = .none,
        isInActiveLineup: Bool = false
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.foulCount = foulCount
        self.cardStatus = cardStatus
        self.isInActiveLineup = isInActiveLineup
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case number
        case name
        case foulCount
        case cardStatus
        case isInActiveLineup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        number = try container.decode(String.self, forKey: .number)
        name = try container.decode(String.self, forKey: .name)
        foulCount = try container.decodeIfPresent(Int.self, forKey: .foulCount) ?? 0
        cardStatus = try container.decodeIfPresent(PlayerCardStatus.self, forKey: .cardStatus) ?? .none
        isInActiveLineup = try container.decodeIfPresent(Bool.self, forKey: .isInActiveLineup) ?? false
    }
}

struct TeamRoster: Codable, Equatable {
    var players: [TrackedPlayer]
}

struct SetupPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sport: SportType
    var homeTeamName: String
    var guestTeamName: String
    var period: Int
    var clockSeconds: Int
    var shotClockSeconds: Int
    var possessionDirection: PossessionDirection
    var customSportConfig: CustomSportConfig?

    init(
        id: UUID = UUID(),
        name: String,
        sport: SportType = .basketball,
        homeTeamName: String,
        guestTeamName: String,
        period: Int,
        clockSeconds: Int,
        shotClockSeconds: Int = 24,
        possessionDirection: PossessionDirection = .none,
        customSportConfig: CustomSportConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.sport = sport
        self.homeTeamName = homeTeamName
        self.guestTeamName = guestTeamName
        self.period = period
        self.clockSeconds = clockSeconds
        self.shotClockSeconds = shotClockSeconds
        self.possessionDirection = possessionDirection
        self.customSportConfig = customSportConfig
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case sport
        case homeTeamName
        case guestTeamName
        case period
        case clockSeconds
        case shotClockSeconds
        case possessionDirection
        case customSportConfig
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sport = try container.decodeIfPresent(SportType.self, forKey: .sport) ?? .basketball
        homeTeamName = try container.decode(String.self, forKey: .homeTeamName)
        guestTeamName = try container.decode(String.self, forKey: .guestTeamName)
        period = try container.decode(Int.self, forKey: .period)
        clockSeconds = try container.decode(Int.self, forKey: .clockSeconds)
        shotClockSeconds = try container.decodeIfPresent(Int.self, forKey: .shotClockSeconds) ?? 24
        possessionDirection = try container.decodeIfPresent(PossessionDirection.self, forKey: .possessionDirection) ?? .none
        customSportConfig = try container.decodeIfPresent(CustomSportConfig.self, forKey: .customSportConfig)
    }
}

@MainActor
final class ScoreboardStore: ObservableObject {
    static let shared = ScoreboardStore()
    nonisolated static let maxGameClockSeconds = 59 * 60 + 59
    nonisolated static let maxDebateSegmentSeconds = 999 * 60 + 59
    nonisolated static let maxShotClockSeconds = 99
    nonisolated static let maxShotClockMilliseconds = maxShotClockSeconds * 1_000
    nonisolated static let maxInjuryTimeMinutes = 15
    nonisolated static let minWebAPIBroadcastDisplayID = 0
    nonisolated static let maxWebAPIBroadcastDisplayID = 8
    nonisolated static let minWebAPIBroadcastCustomDisplayID = 1
    nonisolated static let defaultWebAPIBroadcastEnabledDisplayCount = 2
    nonisolated static let maxCustomDisplayModeTitleLength = 32
    nonisolated static let defaultRosterSize = 12
    nonisolated static let minRosterSize = 5
    nonisolated static let maxRosterSize = 15
    nonisolated static let defaultDisplayLineupSize = 5
    nonisolated static let defaultPlayerLineupFadePageSeconds = 4
    nonisolated static let minPlayerLineupFadePageSeconds = 2
    nonisolated static let maxPlayerLineupFadePageSeconds = 15
    nonisolated static let defaultPlayerLineupScrollSpeed = 14
    nonisolated static let minPlayerLineupScrollSpeed = 6
    nonisolated static let maxPlayerLineupScrollSpeed = 40
    private static let automaticDiskWriteThrottleSeconds = 5
    nonisolated static let defaultAnimatedLogoSpeed = 42
    nonisolated static let minAnimatedLogoSpeed = 8
    nonisolated static let maxAnimatedLogoSpeed = 180
    nonisolated static let defaultAnimatedLogoSize = 112
    nonisolated static let minAnimatedLogoSize = 44
    nonisolated static let maxAnimatedLogoSize = 240
    nonisolated static let defaultAnimatedLogoOpacity = 0.23
    nonisolated static let minAnimatedLogoOpacity = 0.05
    nonisolated static let maxAnimatedLogoOpacity = 0.75
    nonisolated static let displayDirectionModelVersion = 2
    nonisolated static let defaultSoundAssignments: [ScoreboardSoundEvent: ScoreboardSoundEffect] = [
        .gameClockExpired: .classicBuzzer,
        .shotClockExpired: .shotClockBeep,
        .chessClockExpired: .softChime,
        .debateSegmentStarted: .none,
        .debateSegmentStopped: .none,
        .debateSegmentExpired: .debateBell,
        .debateUnassignedSegmentStarted: .none,
        .debateUnassignedSegmentStopped: .none,
        .debateUnassignedSegmentExpired: .none,
        .debatePrepStarted: .none,
        .debatePrepStopped: .none,
        .debatePrepExpired: .debateDoubleBell,
        .hockeyPenaltyExpired: .penaltyChirp,
        .gameClockStarted: .none,
        .gameClockPaused: .none,
        .homeSideClockStarted: .none,
        .homeSideClockStopped: .none,
        .homeSideClockExpired: .none,
        .guestSideClockStarted: .none,
        .guestSideClockStopped: .none,
        .guestSideClockExpired: .none,
        .homePrepClockStarted: .none,
        .homePrepClockStopped: .none,
        .homePrepClockExpired: .none,
        .guestPrepClockStarted: .none,
        .guestPrepClockStopped: .none,
        .guestPrepClockExpired: .none,
        .shotClockStarted: .none,
        .shotClockPaused: .none,
        .shotClockReset: .none,
        .yellowCardAssigned: .none,
        .redCardAssigned: .none,
        .substitutionUsed: .none,
        .teamPauseUsed: .none,
        .pauseStarted: .none,
        .officialPauseStarted: .none,
        .pauseTimerPaused: .none,
        .pauseTimerResumed: .none,
        .pauseEnded: .none,
        .pauseExpired: .softChime,
        .teamFoulApplied: .none,
        .playerFoulApplied: .none,
        .sideSwitched: .none,
        .playerShown: .none,
        .playerBenched: .none,
        .scoreChanged: .none,
        .periodChanged: .none,
        .possessionChanged: .none,
        .hockeyPenaltyAdded: .none,
        .hockeyPenaltyStarted: .none,
        .hockeyPenaltyPaused: .none,
        .playerOverlayShown: .none,
        .playerOverlayPaused: .none
    ]
    nonisolated static let defaultSoundAssignmentsBySport: [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]] = {
        Dictionary(uniqueKeysWithValues: SportType.allCases.map { sport in
            (sport, defaultSoundAssignments)
        })
    }()
    nonisolated static let defaultKeyboardShortcutsByAction: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut] = [
        .togglePrimaryTimer: ScoreboardKeyboardShortcut(key: " "),
        .homeScorePrimary: ScoreboardKeyboardShortcut(key: "H"),
        .guestScorePrimary: ScoreboardKeyboardShortcut(key: "G"),
        .homeScoreMinusOne: ScoreboardKeyboardShortcut(key: "H", modifiers: .shift),
        .guestScoreMinusOne: ScoreboardKeyboardShortcut(key: "G", modifiers: .shift),
        .secondaryTimerPrimary: ScoreboardKeyboardShortcut(key: "S"),
        .homeSecondaryPrimary: ScoreboardKeyboardShortcut(key: "H", modifiers: .option),
        .guestSecondaryPrimary: ScoreboardKeyboardShortcut(key: "G", modifiers: .option),
        .togglePlayersPage: ScoreboardKeyboardShortcut(key: "P")
    ]

    @Published var selectedSport: SportType = .simple
    @Published var customSportConfig: CustomSportConfig = .default
    @Published var homeTeamName = ""
    @Published var guestTeamName = ""
    @Published var eventName = ""
    @Published var homeScore = 0
    @Published var guestScore = 0
    @Published var period = 1
    @Published var volleyballMatchFormat: VolleyballMatchFormat = .bestOf5
    @Published var volleyballSetResults: [VolleyballSetResult] = []
    @Published var gameClockSeconds = 10 * 60
    @Published var defaultClockSeconds = 10 * 60
    @Published var isGameClockEnabled = true
    @Published var pendingInjuryTimeMinutes = 0
    @Published var activeInjuryTimeMinutes = 0
    @Published var hasAppliedInjuryTimeThisPeriod = false
    @Published var shotClockMilliseconds = 0
    @Published var defaultShotClockSeconds = 0
    @Published var activeShotClockPresetSeconds = 0
    @Published var possessionDirection: PossessionDirection = .none
    @Published var areSidesSwapped = false
    @Published var controlBoardDisplayDirection: ScoreboardDisplayDirection = .homeLeft
    @Published var isPlayerTrackingEnabled = false
    @Published var isPlayerOverlayPaused = false
    @Published var rosterSizePerTeam = defaultRosterSize
    @Published var displayLineupSize = defaultDisplayLineupSize
    @Published var playerLineupOverflowMode: PlayerLineupOverflowMode = .scroll
    @Published var playerLineupOverflowLogoOverride: PlayerLineupOverflowMode?
    @Published var playerLineupOverflowNoLogoOverride: PlayerLineupOverflowMode?
    @Published var playerLineupFadePageSeconds = defaultPlayerLineupFadePageSeconds
    @Published var playerLineupScrollSpeed = defaultPlayerLineupScrollSpeed
    @Published var playerLineupScrollDirection: PlayerLineupScrollDirection = .continuousUp
    @Published var publicDisplayViewMode: ScoreboardDisplayViewMode = .scoreboard
    @Published var playerViewRosterScope: PlayerViewRosterScope = .fullRoster
    @Published var playerFoulHighlightColor: PlayerFoulHighlightColor = .yellow
    @Published var isGameClockRedEnabled = false
    @Published var gameClockRedThresholdSeconds = 60
    @Published var isShotClockRedEnabled = false
    @Published var shotClockRedThresholdSeconds = 5
    @Published var homeRoster = TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: defaultRosterSize))
    @Published var guestRoster = TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: defaultRosterSize))
    @Published var homeSubstitutionsAllowed = 0
    @Published var guestSubstitutionsAllowed = 0
    @Published var homeSubstitutionsUsed = 0
    @Published var guestSubstitutionsUsed = 0
    @Published var pauseDurationSeconds = 60
    @Published var isTeamPauseIndefinite = false
    @Published var pauseTimer: ScoreboardPauseTimer?
    @Published var homePausesAllowed = 0
    @Published var guestPausesAllowed = 0
    @Published var homePausesUsed = 0
    @Published var guestPausesUsed = 0
    @Published var homeTeamFouls = 0
    @Published var guestTeamFouls = 0
    @Published var homeChessClockSeconds = ChessClockPreset.rapid.seconds
    @Published var guestChessClockSeconds = ChessClockPreset.rapid.seconds
    @Published var activeChessClockSide: TeamSide? = .home
    @Published var chessClockPreset: ChessClockPreset = .rapid
    @Published var selectedDebatePresetID = DebatePreset.publicForum.id
    @Published var customDebatePreset = DebatePreset.customDefault
    @Published var debateHomeSideLabel = DebatePreset.publicForum.homeSideLabel
    @Published var debateGuestSideLabel = DebatePreset.publicForum.guestSideLabel
    @Published var debateCurrentSegmentIndex = 0
    @Published var debatePrepHomeSeconds = DebatePreset.publicForum.prepSecondsPerSide
    @Published var debatePrepGuestSeconds = DebatePreset.publicForum.prepSecondsPerSide
    @Published var isDebatePrepTimeEnabled = DebatePreset.publicForum.isPrepTimeEnabled
    @Published var debateActiveTimer: DebateActiveTimer = .segment
    @Published var isDebatePrepClockRunning = false
    @Published var isDebateScoreTrackingEnabled = false
    @Published var isDebatePlayerTrackingEnabled = false
    @Published var isDebatePlayerFoulsEnabled = false
    @Published var isDebatePlayerCardsEnabled = false
    @Published var homePenaltyTimers: [HockeyPenaltyTimer] = []
    @Published var guestPenaltyTimers: [HockeyPenaltyTimer] = []
    @Published var theme: ScoreboardTheme = .classic
    @Published var showsLiveActivityWhenTimerRunning = true
    @Published var externalDisplayBackgroundMode: ExternalDisplayBackgroundMode = .blurred
    @Published var externalDisplayBackgroundImage: ExternalDisplayBackgroundImage?
    @Published var externalDisplayAnimatedLogoStyle: ExternalDisplayAnimatedLogoStyle = .horizontalMarquee
    @Published var externalDisplayAnimatedLogoBackgroundColor: ExternalDisplayAnimatedLogoBackgroundColor = .themeBackground
    @Published var externalDisplayAnimatedLogoSpeed = defaultAnimatedLogoSpeed
    @Published var externalDisplayAnimatedLogoSize = defaultAnimatedLogoSize
    @Published var externalDisplayAnimatedLogoOpacity = defaultAnimatedLogoOpacity
    @Published var showsExternalDisplayDateTime = false
    @Published var externalDisplayDateTimeFormat: ExternalDisplayDateTimeFormat = .time24Hour
    @Published var showsExternalDisplayDateTimeSeconds = true
    @Published var externalDisplayDirection: ScoreboardDisplayDirection = .homeLeft
    @Published var showsTeamLogos = true
    @Published var showsEventLogo = true
    @Published var homeTeamLogoImage: TeamLogoImage?
    @Published var guestTeamLogoImage: TeamLogoImage?
    @Published var eventLogoImage: EventLogoImage?
    @Published var isSoundEnabled = true
    @Published var bypassedSoundEventsBySport: [SportType: Set<ScoreboardSoundEvent>] = [:]
    @Published var bypassedCompanionEventsBySport: [SportType: Set<ScoreboardSoundEvent>] = [:]
    @Published var soundAssignmentsBySport = ScoreboardStore.defaultSoundAssignmentsBySport
    @Published var playingTestSoundEffect: ScoreboardSoundEffect?
    @Published var keyboardShortcutsByAction = ScoreboardStore.defaultKeyboardShortcutsByAction
    @Published var isCompanionVisible = false
    @Published private(set) var externalAutomationSafetyNoticeID: UUID?
    private var pendingExternalAutomationIntegration: ExternalAutomationIntegration?
    @Published var isCompanionEnabled = false
    @Published var companionHost = ""
    @Published var companionMode: ScoreboardCompanionMode = .tcp
    @Published var companionSyncWithSound = false
    @Published var companionPort = ScoreboardCompanionMode.tcp.defaultPort
    @Published var companionAssignmentsBySport: [SportType: [ScoreboardSoundEvent: String]] = [:]
    @Published private(set) var companionLastError: String?
    @Published private(set) var companionFailureNotice: ScoreboardCompanionFailureNotice?
    @Published var isClockRunning = false
    @Published private(set) var gameClockAutosaveRevision = 0
    @Published var isShotClockRunning = false
    @Published private(set) var shotClockAutosaveRevision = 0
    @Published var didCompleteSetup = false
    @Published private(set) var currentGameDisplayName: String?

    @Published private(set) var sessionDescriptor: ScoreboardSessionDescriptor?
    @Published private(set) var sessionTransferInProgress = false
    @Published private(set) var sessionStatusMessage: String?
    @Published private(set) var sessionConnectionStatus = "Local"
    @Published private(set) var sessionRoundTripSeconds: TimeInterval?
    @Published private(set) var sessionIsConnected = true
    @Published private(set) var sessionHostPeers: [ScoreboardSessionPeer] = []
    private var sessionRecoveryRole: ScoreboardSessionRecovery.Role?
    private var sessionAuthorityFenced = false
    private var isApplyingSessionUpdate = false
    private var sessionTransferID: UUID?
    private var sessionTransferTargetID: String?
    private var sessionTransferCheckpoint: ScoreboardSessionCheckpoint?
    private var sessionTransferStartedAt: Date?
    private var lastSessionPrepareSentAt: Date?
    private var lastSessionCommitSentAt: Date?
    private var sessionOwnerPairingSecret: String?
    private var sessionOwnerReceiverAcquired = false
    private var lastLogPageAtByPeer: [String: Date] = [:]
    private var lastSessionPeerReportAt: Date?
    private var lastSessionLogRequestAt: Date?
    private var pendingLogBatchByPeer: [String: ScoreboardSessionLogBatch] = [:]
    private var logCursorByPeer: [String: ScoreboardSessionLogCursor] = [:]
    private var lastOwnerSettingsData: Data?
    private var pendingOwnerSettingsSync = false
    private var lastOwnerVisualData: Data?
    private var pendingOwnerVisualSync = false
    private var pendingOwnerVisualFields = Set<String>()
    private var pendingOwnerVisualSnapshot: ScoreboardGameSnapshot?
    private var sessionSyncRevision: UInt64 = 1
    private var hostedCheckpointPersistedRevision: UInt64 = 0
    private var ownerAcknowledgedRevision: UInt64 = 0
    private var ownerAcknowledgedLogCount = -1
    private var observedHostedLogCount = -1
    private var pendingSnapshotSyncID: UUID?
    private var pendingSnapshotLogCount = -1
    private var lastSnapshotSyncSentAt: Date?
    private var disablePairingAfterHostTransfer = false
    private var disconnectClientsAfterOwnerTakeover = false
    private var exitRemoteModeAfterHostTransfer = false
    private var hostedMatchQuitCompletion: ((Bool) -> Void)?

    var localSessionDeviceID: String { ScoreboardRemoteDisplayReceiver.shared.displayID }
    var isSessionOwner: Bool { sessionDescriptor.map { $0.ownerDeviceID == localSessionDeviceID } ?? true }
    var isDelegatedSessionHost: Bool {
        guard let sessionDescriptor else { return false }
        return sessionDescriptor.hostDeviceID == localSessionDeviceID && !isSessionOwner
            && sessionRecoveryRole == .host && !sessionAuthorityFenced
    }
    var isFollowingSessionHost: Bool {
        guard let sessionDescriptor else { return false }
        return isSessionOwner && sessionDescriptor.hostDeviceID != localSessionDeviceID
    }
    var isSessionAuthority: Bool {
        guard !isRemoteControlProxy, !sessionAuthorityFenced else { return false }
        guard let sessionDescriptor else { return !isRemoteDisplayViewerModeEnabled }
        return sessionRecoveryRole == .host && sessionDescriptor.hostDeviceID == localSessionDeviceID
    }
    var routesControlToSessionHost: Bool { isRemoteControlProxy || isFollowingSessionHost }
    var canChangeSessionHost: Bool {
        isSessionOwner && !isAnyTimerRunning && !sessionTransferInProgress && (sessionDescriptor == nil ||
            (isSessionAuthority || sessionIsConnected))
    }
    var remoteSessionDeviceCounts: (connected: Int, disconnected: Int)? {
        if let clients = remoteSessionDevices {
            let connected = clients.filter(\.connected).count
            return (connected, clients.count - connected)
        }
        if routesControlToSessionHost {
            guard let control = remoteControlState?.control,
                  let connected = control.connectedDeviceCount,
                  let disconnected = control.disconnectedDeviceCount else { return nil }
            return (connected, disconnected)
        }
        return nil
    }
    var remoteSessionOwnerConnected: Bool? {
        if routesControlToSessionHost {
            if isFollowingSessionHost { return sessionIsConnected }
            return remoteControlState?.control?.ownerConnected
        }
        guard let descriptor = sessionDescriptor else { return nil }
        if descriptor.ownerDeviceID == localSessionDeviceID { return true }
        guard isSessionAuthority else { return nil }
        return remoteDisplayConnectedDisplays.contains {
            $0.id == descriptor.ownerDeviceID && ($0.quality == .live || $0.quality == .poor)
        }
    }
    var remoteSessionDevices: [ScoreboardSessionPeer]? {
        if routesControlToSessionHost {
            guard let peers = remoteControlState?.control?.devices else { return nil }
            guard let session = remoteControlState?.control?.session ?? sessionDescriptor else { return peers }
            var clients = session.clientPeers(from: peers, ownerConnected: remoteSessionOwnerConnected)
            if isFollowingSessionHost, let index = clients.firstIndex(where: { $0.id == localSessionDeviceID }) {
                clients[index].connected = sessionIsConnected
                clients[index].quality = sessionIsConnected ? (clients[index].quality == .poor ? .poor : .live) : .unresponsive
                clients[index].deviceType = .current
                clients[index].latencyMilliseconds = sessionRoundTripSeconds.map { Int(($0 * 1_000).rounded()) }
                clients[index].realtimeTransport = ScoreboardRemoteDisplayReceiver.shared.realtimeTransport
            }
            return clients
        }
        let hostID = sessionDescriptor?.hostDeviceID ?? localSessionDeviceID
        var ids = Set(remoteDisplayTrustedDisplays.map(\.id))
            .union(remoteDisplayConnectedDisplays.map(\.id)).subtracting([hostID])
        if let ownerID = sessionDescriptor?.ownerDeviceID, ownerID != hostID { ids.insert(ownerID) }
        let peers = ids.map { id in
            let connection = remoteDisplayConnectedDisplays.first { $0.id == id }
            let saved = remoteDisplayTrustedDisplays.first { $0.id == id }
            return ScoreboardSessionPeer(
                id: id,
                name: connection?.name ?? saved?.name ?? id,
                deviceType: connection?.deviceType ?? saved?.deviceType ?? .unknown,
                connected: connection?.quality == .live || connection?.quality == .poor,
                supportsHosting: connection?.supportsSessionHosting == true,
                controlEnabled: id == sessionDescriptor?.ownerDeviceID || remoteControlAllowedDisplayIDs.contains(id),
                latencyMilliseconds: connection?.latencyMilliseconds,
                lastHandshakeAgeSeconds: connection?.lastHandshakeAgeSeconds,
                appVersion: connection?.appVersion,
                quality: connection?.quality,
                realtimeTransport: connection?.realtimeTransport)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return sessionDescriptor?.clientPeers(from: peers, ownerConnected: remoteSessionOwnerConnected) ?? peers
    }
    var canRecoverSessionHost: Bool {
        guard isSessionOwner, isFollowingSessionHost, !sessionIsConnected,
              !sessionTransferInProgress, let descriptor = sessionDescriptor,
              let checkpoint = sessionTransferCheckpoint else { return false }
        return checkpoint.descriptor.sessionID == descriptor.sessionID && descriptor.epoch < UInt64.max
    }
    var hasHostedMatchToDiscard: Bool {
        guard let descriptor = sessionDescriptor else { return false }
        return descriptor.hostDeviceID == localSessionDeviceID && !isSessionOwner
            && (sessionRecoveryRole == .host || sessionRecoveryRole == .fenced || sessionRecoveryRole == .prepared)
    }
    var sessionHostDisplayName: String { sessionDescriptor?.hostName ?? remoteDisplayHostName }
    var sessionHostAddresses: [String] {
        sessionDescriptor?.hostAddresses ?? ScoreboardWebAPIService.localIPv4Addresses()
    }
    var sessionHostWebAPIStatus: ScoreboardWebAPIStatus? {
        guard isFollowingSessionHost, let value = sessionDescriptor?.hostWebAPIStatus else { return nil }
        switch value {
        case "running": return .running(httpPort: ScoreboardWebAPIService.httpPort,
                                         webSocketPort: ScoreboardWebAPIService.webSocketPort, clientCount: 0)
        case "starting": return .starting
        case "suspended": return .suspended
        default: return .off
        }
    }

    var isSessionSafeToDisconnect: Bool {
        if isDelegatedSessionHost, let descriptor = sessionDescriptor {
            return ScoreboardSessionCleanState(
                ownerConnected: remoteDisplayConnectedDisplays.contains { $0.id == descriptor.ownerDeviceID },
                anyTimerRunning: isAnyTimerRunning, transferring: sessionTransferInProgress,
                revision: sessionSyncRevision, persistedRevision: hostedCheckpointPersistedRevision,
                acknowledgedRevision: ownerAcknowledgedRevision,
                logCount: logManager.currentSessionSnapshot()?.entries.count ?? 0,
                acknowledgedLogCount: ownerAcknowledgedLogCount).isSafeToDisconnect
        }
        return sessionDescriptor?.safeToDisconnect == true &&
            (!isFollowingSessionHost || (sessionIsConnected && !pendingOwnerSettingsSync && pendingOwnerVisualFields.isEmpty))
    }

    func setCurrentGameDisplayName(_ name: String?) {
        guard !isRemoteControlProxy, currentGameDisplayName != name else { return }
        currentGameDisplayName = name
        if isFollowingSessionHost && !isApplyingSessionUpdate { sendOwnerGameName(name) }
    }
    @Published var areTipsEnabled = true
    @Published var showGettingStartedOnStartup = true
    @Published var didAutoShowGettingStarted = false
    @Published var setupPresets: [SetupPreset] = []
    @Published var isWebControlEnabled = ScoreboardPreferences.current.bool(forKey: "scoreboard.webControlEnabled") {
        didSet {
            if !isDelegatedSessionHost && !isApplyingSessionUpdate {
                ScoreboardPreferences.current.set(isWebControlEnabled, forKey: "scoreboard.webControlEnabled")
            }
            scheduleOwnerSettingsSync()
        }
    }
    @Published private(set) var remoteControlAllowedDisplayIDs = Set(ScoreboardPreferences.current.stringArray(forKey: "scoreboard.remoteControlAllowedDisplayIDs") ?? [])

    func isRemoteControlAllowed(displayID: String) -> Bool {
        if isSessionAuthority && sessionDescriptor?.ownerDeviceID == displayID { return true }
        if isDelegatedSessionHost && displayID == localSessionDeviceID {
            return ScoreboardRemoteDisplayDeviceType.current != .appleTV
                && remoteControlAllowedDisplayIDs.contains(displayID)
        }
        guard remoteControlAllowedDisplayIDs.contains(displayID),
              let peer = remoteDisplayTrustedDisplays.first(where: { $0.id == displayID }),
              peer.deviceType != .appleTV else { return false }
        return true
    }

    func setRemoteControlAllowed(displayID: String, isAllowed: Bool) {
        guard !isRemoteControlProxy else { return }
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "controlPermission", displayID: displayID, enabled: isAllowed))
            return
        }
        if isAllowed {
            guard let peer = remoteDisplayTrustedDisplays.first(where: { $0.id == displayID }),
                  peer.deviceType != .appleTV else { return }
            remoteControlAllowedDisplayIDs.insert(displayID)
        } else { remoteControlAllowedDisplayIDs.remove(displayID) }
        if !isDelegatedSessionHost {
            ScoreboardPreferences.current.set(remoteControlAllowedDisplayIDs.sorted(), forKey: "scoreboard.remoteControlAllowedDisplayIDs")
        }
        refreshRemoteDisplayState()
        remoteDisplayHostService.refreshControlPermissions()
    }
    @Published private(set) var webControlAPIKey: String = {
        if let key = ScoreboardPreferences.current.string(forKey: "scoreboard.webControlAPIKey"), key.count == 16,
           key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) { return key.uppercased() }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let key = String((0..<16).map { _ in alphabet.randomElement()! })
        ScoreboardPreferences.current.set(key, forKey: "scoreboard.webControlAPIKey")
        return key
    }()
    private var controlCommandResults: [UUID: (Data, ScoreboardControlResult, Date)] = [:]

    func resetWebControlAPIKey() {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        webControlAPIKey = String((0..<16).map { _ in alphabet.randomElement()! })
        ScoreboardPreferences.current.set(webControlAPIKey, forKey: "scoreboard.webControlAPIKey")
        scheduleOwnerSettingsSync()
    }

    func performControlCommand(_ command: ScoreboardControlCommand, remote: Bool) -> ScoreboardControlResult {
        controlCommandResults = controlCommandResults.filter { Date().timeIntervalSince($0.value.2) < 120 }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(command)) ?? Data()
        if let cached = controlCommandResults[command.id] {
            guard cached.0 == data else { return .failure(command.id, "conflict", "Command ID was reused with different parameters.") }
            return cached.1
        }
        let result = executeControlCommand(command, remote: remote)
        if controlCommandResults.count >= 512, let oldest = controlCommandResults.min(by: { $0.value.2 < $1.value.2 })?.key {
            controlCommandResults.removeValue(forKey: oldest)
        }
        controlCommandResults[command.id] = (data, result, Date())
        refreshWebAPIState()
        refreshRemoteDisplayState()
        return result
    }

    @Published var isWebAPIEnabled = false
    @Published var webAPIUpdateMode: ScoreboardWebAPIUpdateMode = .fixedInterval
    @Published var isWebAPIBroadcastControlEnabled = false
    @Published var webAPIBroadcastEnabledDisplayCount = ScoreboardStore.defaultWebAPIBroadcastEnabledDisplayCount
    @Published var webAPIBroadcastDisplayModesByID: [Int: ScoreboardWebAPIBroadcastDisplayMode] = [:]
    @Published var customDisplayModeTitlesByMode: [String: String] = [:]
    @Published private(set) var webAPIStatus: ScoreboardWebAPIStatus = .off
    @Published private(set) var webAPILocalAddresses: [String] = []
    @Published var isRemoteDisplayHostEnabled = false
    @Published var isRemoteDisplayViewerModeEnabled = false
    @Published var isRemoteDisplayIndividualControlEnabled = false
    @Published var remoteDisplayNetworkMode: ScoreboardRemoteDisplayNetworkMode = .nearbyAndLocalNetwork
    @Published private(set) var remoteDisplayHostStatus: ScoreboardRemoteDisplayHostStatus = .off
    @Published private(set) var remoteDisplaySources: [ScoreboardRemoteDisplaySource] = []
    @Published private(set) var remoteDisplayConnectedDisplays: [ScoreboardRemoteDisplayConnection] = []
    @Published private(set) var remoteDisplayTrustedDisplays: [ScoreboardRemoteDisplayTrustedPeer] = []
    @Published private(set) var remoteDisplayMutedDisplayIDs: Set<String> = []
    @Published private(set) var remoteDisplayDirectionsByID: [String: ScoreboardRemoteDisplayDirectionSettings] = [:]
    @Published private(set) var remoteDisplayCustomDisplayIDsByDisplayID: [String: Int] = [:]
    @Published private(set) var remoteDisplayWarningNotice: ScoreboardRemoteDisplayWarningNotice?

    var remoteDisplayHostID: String {
        sessionDescriptor?.ownerHostID ?? remoteDisplayHostService.hostID
    }

    var resolvedControlBoardDisplayDirection: ScoreboardDisplayDirection {
        resolvedDisplayDirection(for: controlBoardDisplayDirection)
    }

    var resolvedExternalDisplayDirection: ScoreboardDisplayDirection {
        resolvedDisplayDirection(for: externalDisplayDirection)
    }

    func resolvedDisplayDirection(for configuredDirection: ScoreboardDisplayDirection) -> ScoreboardDisplayDirection {
        configuredDirection.applyingSideSwap(areSidesSwapped)
    }

    private var timer: Timer?
    private var lastTimerFireDate: Date?
    private var accumulatedGameClockElapsed: TimeInterval = 0
    private var accumulatedShotClockElapsed: TimeInterval = 0
    private var accumulatedPenaltyElapsed: TimeInterval = 0
    private var accumulatedDebatePrepElapsed: TimeInterval = 0
    private var accumulatedPauseElapsed: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    private var isAuditLoggingSuspended = false
    private var isReconcilingTimersFromWallClock = false
    private let persistenceKey = "smartScoreboard.persistedState"
    private let primaryTimerPersistenceKey = "smartScoreboard.primaryTimerPersistence"
    private var lastPrimaryTimerPersistenceSignature: String?
    private let buzzerPlayer = BuzzerPlayer()
    private struct QueuedEventAction {
        let effect: ScoreboardSoundEffect
        let triggerEvent: ScoreboardSoundEvent
        let soundEvent: ScoreboardSoundEvent?
        let companionEvent: ScoreboardSoundEvent?
        let sport: SportType
        let companionLocation: ScoreboardCompanionLocation?
        let companionGeneration: UUID
    }
    private var queuedEventActions: [QueuedEventAction] = []
    private var activeEventAction: QueuedEventAction?
    @Published private var activeEventPlaybackID: UUID?
    private var activeEventDidStart = false
    private var companionCommandGeneration = UUID()
    private let logManager = ScoreboardLogManager.shared
    #if SCOREBOARD_TESTING
    private let webAPIService = ScoreboardWebAPIService(httpPort: 0, webSocketPort: 0, advertisesService: false)
    #else
    private let webAPIService = ScoreboardWebAPIService()
    #endif
    private let remoteDisplayHostService = ScoreboardRemoteDisplayHostService()
    private let companionService = ScoreboardCompanionService()
    private var isWebAPIAppLifecycleActive = true
    private var companionFailureClearTask: Task<Void, Never>?
    private var remoteDisplayConnectedDisplaysByID: [String: ScoreboardRemoteDisplayConnection] = [:]
    private var remoteDisplayDisconnectedDisplaysByID: [String: String] = [:]
    private var dismissedRemoteDisplayWarningDisplayIDs = Set<String>()
    private var intentionallyDisconnectedRemoteDisplayIDs = Set<String>()
    private var isStateSideEffectRefreshScheduled = false

    private var remoteControlReceiver: ScoreboardRemoteDisplayReceiver?
    private var remoteCommandSender: ((ScoreboardControlCommand) -> Void)?
    private var isApplyingRemoteControlState = false
    private var remoteProjectionTimer: Timer?
    private var remoteControlGameConfiguration: ScoreboardGameSnapshot?
    private var remoteControlState: ScoreboardWebAPIState?

    var isRemoteControlProxy: Bool { remoteControlReceiver != nil }

    static func makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver,
                                       sendCommand: ((ScoreboardControlCommand) -> Void)? = nil) -> ScoreboardStore {
        ScoreboardStore(remoteReceiver: receiver, sendCommand: sendCommand)
    }

    private init(remoteReceiver: ScoreboardRemoteDisplayReceiver? = nil,
                 sendCommand: ((ScoreboardControlCommand) -> Void)? = nil) {
        if let receiver = remoteReceiver {
            remoteControlReceiver = receiver
            remoteCommandSender = sendCommand ?? { [weak receiver] in receiver?.sendCommand($0) }
            didCompleteSetup = true
            keyboardShortcutsByAction = ScoreboardStore.shared.keyboardShortcutsByAction
            controlBoardDisplayDirection = ScoreboardStore.shared.controlBoardDisplayDirection
            areTipsEnabled = false
            showGettingStartedOnStartup = false
            receiver.$state.sink { [weak self] state in
                if let state { self?.applyRemoteControlState(state) }
            }.store(in: &cancellables)
            receiver.$pendingControlCommandID.sink { [weak self] _ in
                guard let self, let state = self.remoteControlState else { return }
                self.applyRemoteControlState(state)
            }.store(in: &cancellables)
            receiver.$imageAssetsByID.sink { [weak self] _ in
                guard let self, let state = self.remoteControlState else { return }
                self.applyRemoteControlImages(state)
            }.store(in: &cancellables)
            let projectionTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.projectRemoteControlClocks() }
            }
            RunLoop.main.add(projectionTimer, forMode: .common)
            remoteProjectionTimer = projectionTimer
            return
        }
        /* APP_STORE_PREVIEW_CAPTURE_BEGIN
        #if DEBUG && targetEnvironment(simulator)
        // The preview workflow supplies fixture data only to simulator Debug builds.
        if let encoded = ProcessInfo.processInfo.environment["SCOREBOARD_PREVIEW_STATE"],
           let data = Data(base64Encoded: encoded) {
            do {
                _ = try JSONDecoder().decode(PersistedState.self, from: data)
            } catch {
                fatalError("Invalid App Store preview fixture: \(error)")
            }
            ScoreboardPreferences.current.set(data, forKey: persistenceKey)
            ScoreboardPreferences.current.set(
                ProcessInfo.processInfo.environment["SCOREBOARD_PREVIEW_SCREEN"] == "merged",
                forKey: "showsMergedView"
            )
        }
        #endif
        APP_STORE_PREVIEW_CAPTURE_END */
        do {
            let savedRecovery = try ScoreboardSessionRecovery.load()
            if let staleClient = savedRecovery, staleClient.role == .follower,
               staleClient.descriptor.ownerDeviceID != localSessionDeviceID {
                // Older versions retained a dehosted remote's session record.
                // Client pairing is stored separately; no authority copy is needed.
                try? removeHostedSessionData(sessionID: staleClient.descriptor.sessionID)
            }
            if let recovery = savedRecovery,
               recovery.role != .follower || recovery.descriptor.ownerDeviceID == localSessionDeviceID {
                sessionDescriptor = recovery.descriptor
                sessionRecoveryRole = recovery.role
                sessionAuthorityFenced = recovery.role == .fenced || recovery.role == .prepared
                sessionTransferID = recovery.transferID
                sessionTransferCheckpoint = recovery.checkpoint
                if recovery.role == .host,
                   recovery.descriptor.ownerDeviceID != localSessionDeviceID,
                   let isolated = try? ScoreboardHostedMatchStorage.load(sessionID: recovery.descriptor.sessionID),
                   isolated.descriptor.epoch == recovery.descriptor.epoch {
                    if let authority = sessionTransferCheckpoint, authority.capturedAt > isolated.capturedAt {
                        if isolated.log.entries.count > authority.log.entries.count,
                           zip(authority.log.entries, isolated.log.entries).allSatisfy({ $0.id == $1.id }) {
                            var restored = authority
                            restored.log = isolated.log
                            sessionTransferCheckpoint = restored
                        }
                    } else {
                        sessionTransferCheckpoint = isolated
                    }
                }
                if recovery.role == .host,
                   recovery.descriptor.ownerDeviceID != localSessionDeviceID,
                   var restored = sessionTransferCheckpoint,
                   let log = try? ScoreboardHostedMatchStorage.loadLog(sessionID: recovery.descriptor.sessionID),
                   log.sessionID == restored.log.sessionID,
                   log.entries.count > restored.log.entries.count,
                   zip(restored.log.entries, log.entries).allSatisfy({ $0.id == $1.id }) {
                    restored.log = log
                    sessionTransferCheckpoint = restored
                }
            }
        } catch {
            // A damaged authority record must never restart an old clock.
            sessionAuthorityFenced = true
            sessionStatusMessage = "Session authority could not be restored: \(error.localizedDescription)"
        }
        loadPersistedState()
        #if DEBUG && !SCOREBOARD_TESTING
        ScoreboardUITestLaunch.configure(self)
        #endif
        if sessionRecoveryRole == .host, let checkpoint = sessionTransferCheckpoint,
           checkpoint.descriptor.hostDeviceID == localSessionDeviceID {
            activateSessionCheckpoint(checkpoint, fromRecovery: true)
        }
        remoteDisplayHostService.migrateDisplayDirectionsIfNeeded(areSidesSwapped: areSidesSwapped)
        configurePersistence()
        configureWebAPIService()
        configureRemoteDisplayService()
        configureSessionService()
        if sessionRecoveryRole == .fenced, let descriptor = sessionDescriptor,
           descriptor.hostDeviceID != localSessionDeviceID,
           let checkpoint = sessionTransferCheckpoint, sessionTransferID != nil {
            sessionTransferTargetID = descriptor.hostDeviceID
            sessionTransferInProgress = true
            remoteDisplayHostService.startCommitRecovery(targetID: descriptor.hostDeviceID,
                pairings: checkpoint.pairings, networkMode: remoteDisplayNetworkMode)
            sessionStatusMessage = "Resuming host handoff to \(descriptor.hostName)…"
        }
        refreshWebAPIState()
        refreshRemoteDisplayState()
    }

    var formattedClock: String {
        Self.formatGameClock(gameClockSeconds)
    }

    var formattedHomeChessClock: String {
        Self.formatGameClock(homeChessClockSeconds)
    }

    var formattedGuestChessClock: String {
        Self.formatGameClock(guestChessClockSeconds)
    }

    var formattedShotClock: String {
        Self.formatShotClock(milliseconds: shotClockMilliseconds)
    }

    var isDebateMode: Bool {
        selectedSport == .debate
    }

    var currentDebatePreset: DebatePreset {
        selectedDebatePresetID == DebatePreset.customID ? customDebatePreset : DebatePreset.preset(id: selectedDebatePresetID)
    }

    var currentDebateSegment: DebateSegment? {
        guard isDebateMode, currentDebatePreset.segments.indices.contains(debateCurrentSegmentIndex) else {
            return nil
        }

        return currentDebatePreset.segments[debateCurrentSegmentIndex]
    }

    var debateSegmentTitle: String {
        currentDebateSegment?.title ?? "Debate Segment"
    }

    var debateSpeakingSide: TeamSide? {
        currentDebateSegment?.speakingSide
    }

    var formattedDebatePrepHomeClock: String {
        Self.formatGameClock(debatePrepHomeSeconds)
    }

    var formattedDebatePrepGuestClock: String {
        Self.formatGameClock(debatePrepGuestSeconds)
    }

    var showsDebatePrepTime: Bool {
        isDebateMode && isDebatePrepTimeEnabled
    }

    var isGameClockInterlockActive: Bool {
        showsGameClock && isClockRunning
    }

    var isAnyTimerRunning: Bool {
        pauseTimer?.isRunning == true ||
            isClockRunning ||
            isShotClockRunning ||
            isDebatePrepClockRunning ||
            homePenaltyTimers.contains(where: \.isRunning) ||
            guestPenaltyTimers.contains(where: \.isRunning)
    }

    var isGameRunning: Bool {
        isClockRunning || isDebatePrepClockRunning
    }

    var isResetInterlockActive: Bool {
        isAnyTimerRunning
    }

    var showsGameClock: Bool {
        if isDebateMode {
            return currentDebateSegment?.timerMode == .masterClock
        }

        switch currentRules.mainClockMode {
        case .disabled:
            return false
        case .countdown, .countUp:
            return currentRules.sport != .volleyball || isGameClockEnabled
        }
    }

    var supportsInjuryTime: Bool {
        guard showsGameClock, !usesChessClocks, gameClockMode == .countdown else {
            return false
        }

        if selectedSport == .soccer {
            return true
        }

        return selectedSport == .custom &&
            isGameClockEnabled &&
            customSportConfig.mainClockMode == .countdown &&
            !customSportConfig.usesChessClocks
    }

    var isInjuryTimeActive: Bool {
        activeInjuryTimeMinutes > 0
    }

    var formattedInjuryTime: String {
        localizedStoreFormat("+%d min", max(0, activeInjuryTimeMinutes))
    }

    var displayedHomePlayers: [TrackedPlayer] {
        activeLineupPlayers(for: .home)
    }

    var displayedGuestPlayers: [TrackedPlayer] {
        activeLineupPlayers(for: .guest)
    }

    var isDisplayGameClockAlertActive: Bool {
        showsGameClock && gameClockMode == .countdown && isGameClockRedEnabled && gameClockSeconds <= boundedGameClockSeconds(gameClockRedThresholdSeconds)
    }

    var isDisplayShotClockAlertActive: Bool {
        currentRules.supportsShotClock && isShotClockRedEnabled && shotClockMilliseconds <= boundedShotClockMilliseconds(shotClockRedThresholdSeconds * 1_000)
    }

    var supportsShotClock: Bool {
        currentRules.supportsShotClock
    }

    var supportsPossession: Bool {
        currentRules.supportsPossession
    }

    var usesServeTimer: Bool {
        selectedSport == .volleyball ||
            (selectedSport == .custom && customSportConfig.isShotClockEnabled && customSportConfig.shotClockMode == .serve)
    }

    var secondaryTimerTitle: String {
        usesServeTimer ? localizedStoreString("Serve Timer") : localizedStoreString("Shot Clock")
    }

    var secondaryTimerShortTitle: String {
        usesServeTimer ? localizedStoreString("SERVE") : localizedStoreString("SHOT")
    }

    var secondaryTimerActionTitle: String {
        usesServeTimer ? localizedStoreString("Serve") : localizedStoreString("Shot")
    }

    var secondaryTimerOwnerTitle: String {
        usesServeTimer ? localizedStoreString("Serving") : localizedStoreString("Possession")
    }

    var supportsPeriodWinTracking: Bool {
        selectedSport == .volleyball ||
            (selectedSport == .custom && customSportConfig.isPeriodWinTrackingEnabled && supportsPeriod && supportsScore)
    }

    var homePeriodWins: Int {
        periodWins(for: .home)
    }

    var guestPeriodWins: Int {
        periodWins(for: .guest)
    }

    var homeVolleyballSetsWon: Int {
        periodWins(for: .home)
    }

    var guestVolleyballSetsWon: Int {
        periodWins(for: .guest)
    }

    var volleyballMatchWinner: TeamSide? {
        guard selectedSport == .volleyball else {
            return nil
        }

        if homeVolleyballSetsWon >= volleyballMatchFormat.setsToWin {
            return .home
        }

        if guestVolleyballSetsWon >= volleyballMatchFormat.setsToWin {
            return .guest
        }

        return nil
    }

    var periodWinMatchWinner: TeamSide? {
        selectedSport == .volleyball ? volleyballMatchWinner : nil
    }

    var volleyballCurrentSetTarget: Int {
        volleyballMatchFormat.targetPoints(forSet: period)
    }

    var isVolleyballSetScoreLegalForHome: Bool {
        isLegalVolleyballSetWin(for: .home)
    }

    var isVolleyballSetScoreLegalForGuest: Bool {
        isLegalVolleyballSetWin(for: .guest)
    }

    var supportsFouls: Bool {
        if isDebateMode {
            return isDebatePlayerTrackingEnabled && isDebatePlayerFoulsEnabled
        }

        return currentRules.supportsFouls
    }

    var supportsCards: Bool {
        if isDebateMode {
            return isDebatePlayerTrackingEnabled && isDebatePlayerCardsEnabled
        }

        return currentRules.supportsCards
    }

    var supportsTeamFouls: Bool {
        currentRules.supportsTeamFouls
    }

    var supportsPlayerTracking: Bool {
        if isDebateMode {
            return isDebatePlayerTrackingEnabled
        }

        return currentRules.supportsPlayerTracking
    }

    var showsSubstitutionTracking: Bool {
        homeSubstitutionsAllowed > 0 || guestSubstitutionsAllowed > 0
    }

    var supportsPauseTracking: Bool {
        currentRules.showsPauseTracking
    }

    var showsPauseTracking: Bool {
        homePausesAllowed > 0 || guestPausesAllowed > 0
    }

    var supportsScore: Bool {
        if isDebateMode {
            return isDebateScoreTrackingEnabled
        }

        return currentRules.supportsScore
    }

    var supportsPeriod: Bool {
        if isDebateMode {
            return false
        }

        return currentRules.supportsPeriod
    }

    var periodUpperBound: Int {
        selectedSport == .volleyball ? volleyballMatchFormat.maximumSets : 9
    }

    var supportsHockeyPenalties: Bool {
        currentRules.supportsHockeyPenalties
    }

    var usesChessClocks: Bool {
        if isDebateMode {
            return currentDebateSegment?.timerMode == .dualClock
        }

        return currentRules.usesChessClocks
    }

    var periodTitle: String {
        if isDebateMode {
            return localizedStoreString("Segment")
        }

        return currentRules.periodTitle
    }

    var periodShortTitle: String {
        currentRules.periodShortTitle
    }

    var gameClockMode: GameClockMode {
        switch currentRules.mainClockMode {
        case .countdown:
            return .countdown
        case .countUp:
            return .countUp
        case .disabled:
            return .countdown
        }
    }

    var currentRules: SportRules {
        if isDebateMode {
            return SportRules(
                sport: .debate,
                title: "Debate",
                periodTitle: "Round",
                periodShortTitle: "R",
                scoreStepOptions: [],
                defaultClockSeconds: 7 * 60,
                defaultShotClockSeconds: 0,
                defaultRosterSize: isDebatePlayerTrackingEnabled ? max(rosterSizePerTeam, Self.minRosterSize) : 0,
                defaultDisplayLineupSize: isDebatePlayerTrackingEnabled ? max(1, displayLineupSize) : 0,
                defaultSubstitutionLimit: 0,
                defaultPauseLimit: 0,
                mainClockMode: .disabled,
                supportsScore: isDebateScoreTrackingEnabled,
                supportsPeriod: false,
                supportsShotClock: false,
                supportsPossession: false,
                supportsFouls: isDebatePlayerTrackingEnabled && isDebatePlayerFoulsEnabled,
                supportsTeamFouls: false,
                supportsPlayerTracking: isDebatePlayerTrackingEnabled,
                usesCenterPlayerStrip: false,
                supportsCards: isDebatePlayerTrackingEnabled && isDebatePlayerCardsEnabled,
                showsSubstitutionTracking: false,
                showsPauseTracking: false,
                supportsHockeyPenalties: false,
                usesChessClocks: currentDebateSegment?.timerMode == .dualClock
            )
        }

        return selectedSport.rules(customConfig: customSportConfig)
    }

    var assignableSoundEventsForCurrentSport: [ScoreboardSoundEvent] {
        assignableSoundEvents(for: selectedSport)
    }

    func assignableSoundEvents(for sport: SportType) -> [ScoreboardSoundEvent] {
        if sport == .debate {
            return orderedSoundEvents(timerOutcomeSoundEvents(hasExpiration: true, supportsScore: true) + [
                .debateSegmentStarted,
                .debateSegmentStopped,
                .debateSegmentExpired,
                .debateUnassignedSegmentStarted,
                .debateUnassignedSegmentStopped,
                .debateUnassignedSegmentExpired,
                .debatePrepStarted,
                .debatePrepStopped,
                .debatePrepExpired
            ] + pauseSoundEvents + sideClockSoundEvents + debatePrepClockSoundEvents + [
                .sideSwitched,
                .periodChanged,
                .scoreChanged,
                .playerShown,
                .playerBenched,
                .playerOverlayShown,
                .playerOverlayPaused,
                .playerFoulApplied,
                .yellowCardAssigned,
                .redCardAssigned
            ])
        }

        let rules = sport.rules(customConfig: sport == .custom ? customSportConfig : nil)
        return assignableSoundEvents(for: rules)
    }

    private func assignableSoundEvents(for rules: SportRules) -> [ScoreboardSoundEvent] {
        var events: [ScoreboardSoundEvent] = pauseSoundEvents

        if rules.usesChessClocks {
            events.append(.chessClockExpired)
            events.append(.gameClockStarted)
            events.append(.gameClockPaused)
            events.append(contentsOf: sideClockSoundEvents)
            events.append(.sideSwitched)
        } else if rules.mainClockMode == .countdown {
            events.append(.gameClockExpired)
            events.append(.gameClockStarted)
            events.append(.gameClockPaused)
        } else if rules.mainClockMode == .countUp {
            events.append(.gameClockStarted)
            events.append(.gameClockPaused)
        }

        if rules.supportsShotClock {
            events.append(.shotClockExpired)
            events.append(.shotClockStarted)
            events.append(.shotClockPaused)
            events.append(.shotClockReset)
        }

        if rules.supportsScore {
            events.append(.scoreChanged)
        }

        if rules.supportsPeriod {
            events.append(.periodChanged)
        }

        if rules.supportsPossession {
            events.append(.possessionChanged)
        }

        if rules.showsSubstitutionTracking {
            events.append(.substitutionUsed)
        }

        if rules.showsPauseTracking {
            events.append(.teamPauseUsed)
        }

        if rules.supportsTeamFouls {
            events.append(.teamFoulApplied)
        }

        if rules.supportsPlayerTracking {
            events.append(.playerShown)
            events.append(.playerBenched)
            events.append(.playerOverlayShown)
            events.append(.playerOverlayPaused)
        }

        if rules.supportsFouls {
            events.append(.playerFoulApplied)
        }

        if rules.supportsCards {
            events.append(.yellowCardAssigned)
            events.append(.redCardAssigned)
        }

        if rules.supportsHockeyPenalties {
            events.append(.hockeyPenaltyExpired)
            events.append(.hockeyPenaltyAdded)
            events.append(.hockeyPenaltyStarted)
            events.append(.hockeyPenaltyPaused)
        }

        events.append(.sideSwitched)
        events += timerOutcomeSoundEvents(
            hasExpiration: rules.usesChessClocks || rules.mainClockMode == .countdown,
            supportsScore: rules.supportsScore,
            hasTimer: rules.usesChessClocks || rules.mainClockMode != .disabled
        )
        return orderedSoundEvents(events)
    }

    private func timerOutcomeSoundEvents(
        hasExpiration: Bool, supportsScore: Bool, hasTimer: Bool = true
    ) -> [ScoreboardSoundEvent] {
        guard hasTimer else { return [] }
        var events: [ScoreboardSoundEvent] = [.timerPaused]
        if hasExpiration { events.append(.timerExpired) }
        if supportsScore {
            events += [.timerPausedHomeAhead, .timerPausedHomeBehind,
                       .timerPausedGuestAhead, .timerPausedGuestBehind, .timerPausedTie]
            if hasExpiration {
                events += [.timerExpiredHomeAhead, .timerExpiredHomeBehind,
                           .timerExpiredGuestAhead, .timerExpiredGuestBehind, .timerExpiredTie,
                           .homeWin, .homeLose, .guestWin, .guestLose]
            }
        }
        return events
    }

    private func orderedSoundEvents(_ events: [ScoreboardSoundEvent]) -> [ScoreboardSoundEvent] {
        let includedEvents = Set(events)
        return ScoreboardSoundEvent.executionOrder.filter { includedEvents.contains($0) }
    }

    private var sideClockSoundEvents: [ScoreboardSoundEvent] {
        [
            .homeSideClockStarted,
            .homeSideClockStopped,
            .homeSideClockExpired,
            .guestSideClockStarted,
            .guestSideClockStopped,
            .guestSideClockExpired
        ]
    }

    private var debatePrepClockSoundEvents: [ScoreboardSoundEvent] {
        [
            .homePrepClockStarted,
            .homePrepClockStopped,
            .homePrepClockExpired,
            .guestPrepClockStarted,
            .guestPrepClockStopped,
            .guestPrepClockExpired
        ]
    }

    private func uniqueSoundEvents(_ events: [ScoreboardSoundEvent]) -> [ScoreboardSoundEvent] {
        var seen = Set<ScoreboardSoundEvent>()
        return events.filter { seen.insert($0).inserted }
    }

    private func uniqueScoreboardEventDispatches(_ dispatches: [ScoreboardEventDispatch]) -> [ScoreboardEventDispatch] {
        var seen = Set<ScoreboardSoundEvent>()
        return dispatches.filter { seen.insert($0.event).inserted }
    }

    func substitutionsAllowed(for side: TeamSide) -> Int {
        side == .home ? homeSubstitutionsAllowed : guestSubstitutionsAllowed
    }

    func substitutionsUsed(for side: TeamSide) -> Int {
        side == .home ? homeSubstitutionsUsed : guestSubstitutionsUsed
    }

    func substitutionsRemaining(for side: TeamSide) -> Int {
        max(0, substitutionsAllowed(for: side) - substitutionsUsed(for: side))
    }

    func pausesAllowed(for side: TeamSide) -> Int {
        side == .home ? homePausesAllowed : guestPausesAllowed
    }

    func pausesUsed(for side: TeamSide) -> Int {
        side == .home ? homePausesUsed : guestPausesUsed
    }

    func pausesRemaining(for side: TeamSide) -> Int {
        max(0, pausesAllowed(for: side) - pausesUsed(for: side))
    }

    func sideRoleLabel(for side: TeamSide) -> String {
        guard isDebateMode else {
            return side.title
        }

        switch side {
        case .home:
            return debateHomeSideLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSLocalizedString("Side A", comment: "") : debateHomeSideLabel
        case .guest:
            return debateGuestSideLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSLocalizedString("Side B", comment: "") : debateGuestSideLabel
        }
    }

    func teamFouls(for side: TeamSide) -> Int {
        side == .home ? homeTeamFouls : guestTeamFouls
    }

    func periodWins(for side: TeamSide) -> Int {
        volleyballSetResults.filter { $0.winner == side }.count
    }

    func volleyballSetsWon(for side: TeamSide) -> Int {
        periodWins(for: side)
    }

    func isLegalVolleyballSetWin(for side: TeamSide) -> Bool {
        guard selectedSport == .volleyball else {
            return false
        }

        let winnerScore = side == .home ? homeScore : guestScore
        let loserScore = side == .home ? guestScore : homeScore
        return winnerScore >= volleyballCurrentSetTarget && winnerScore - loserScore >= 2
    }

    func currentLogContext() -> ScoreboardLogContext {
        ScoreboardLogContext(
            gameFileName: nil,
            gameFilePath: nil,
            sport: selectedSport,
            customSportTitle: selectedSport == .custom ? currentRules.title : nil,
            period: period,
            showsGameClock: showsGameClock,
            isClockRunning: isClockRunning,
            gameClockSeconds: gameClockSeconds,
            supportsShotClock: supportsShotClock,
            isShotClockRunning: supportsShotClock ? isShotClockRunning : nil,
            shotClockMilliseconds: supportsShotClock ? shotClockMilliseconds : nil,
            homeChessClockSeconds: usesChessClocks ? homeChessClockSeconds : nil,
            guestChessClockSeconds: usesChessClocks ? guestChessClockSeconds : nil,
            activeChessClockSide: usesChessClocks ? activeChessClockSide : nil,
            debatePresetTitle: isDebateMode ? currentDebatePreset.title : nil,
            debateSegmentTitle: isDebateMode ? currentDebateSegment?.title : nil,
            debateTimerMode: isDebateMode ? currentDebateSegment?.timerMode : nil,
            debateHomeSideLabel: isDebateMode ? sideRoleLabel(for: .home) : nil,
            debateGuestSideLabel: isDebateMode ? sideRoleLabel(for: .guest) : nil,
            debateActiveTimer: isDebateMode ? debateActiveTimer : nil,
            debatePrepHomeSeconds: showsDebatePrepTime ? debatePrepHomeSeconds : nil,
            debatePrepGuestSeconds: showsDebatePrepTime ? debatePrepGuestSeconds : nil,
            hockeyPenaltySummary: supportsHockeyPenalties ? penaltySummaryText : nil,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            homeScore: homeScore,
            guestScore: guestScore
        )
    }

    var penaltySummaryText: String {
        let home = homePenaltyTimers.map { penaltySummaryItem($0) }.joined(separator: " | ")
        let guest = guestPenaltyTimers.map { penaltySummaryItem($0) }.joined(separator: " | ")
        return "HOME[\(home)] GUEST[\(guest)]"
    }

    nonisolated static func formatGameClock(_ totalSeconds: Int) -> String {
        let boundedSeconds = max(0, totalSeconds)
        let minutes = boundedSeconds / 60
        let seconds = boundedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    nonisolated static func formatShotClock(_ totalSeconds: Int) -> String {
        formatShotClock(milliseconds: totalSeconds * 1_000)
    }

    nonisolated static func formatShotClock(milliseconds totalMilliseconds: Int) -> String {
        let boundedMilliseconds = max(0, min(maxShotClockMilliseconds, totalMilliseconds))
        return String(format: "%.1f", Double(boundedMilliseconds) / 1_000)
    }

    nonisolated static func makeDefaultRosterPlayers(count: Int) -> [TrackedPlayer] {
        (0..<count).map { index in
            TrackedPlayer(number: "\(index + 1)", isInActiveLineup: index < defaultDisplayLineupSize)
        }
    }

    private static func asciiDigits(in value: String) -> String {
        var digits = ""
        for scalar in value.unicodeScalars where scalar.value >= 48 && scalar.value <= 57 {
            digits.unicodeScalars.append(scalar)
        }
        return digits
    }

    private static func formattedCompanionLocationText(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return ""
        }

        let separatorSet = CharacterSet(charactersIn: ":/")
        if trimmedValue.unicodeScalars.contains(where: { separatorSet.contains($0) }) {
            let normalizedValue = trimmedValue.replacingOccurrences(of: "/", with: ":")
            let parts = normalizedValue
                .split(separator: ":", omittingEmptySubsequences: false)
                .prefix(3)
                .map { asciiDigits(in: String($0)) }

            if parts.contains(where: { $0.count > 2 }) {
                return groupedCompanionLocationDigits(asciiDigits(in: trimmedValue))
            }

            var displayParts = Array(parts)
            while displayParts.last == "" {
                displayParts.removeLast()
            }
            return displayParts.joined(separator: ":")
        }

        let digits = asciiDigits(in: trimmedValue)
        guard !digits.isEmpty else {
            return ""
        }

        return groupedCompanionLocationDigits(digits)
    }

    private static func groupedCompanionLocationDigits(_ digits: String) -> String {
        var groups: [String] = []
        var currentIndex = digits.startIndex
        while currentIndex < digits.endIndex && groups.count < 3 {
            let endIndex = digits.index(
                currentIndex,
                offsetBy: 2,
                limitedBy: digits.endIndex
            ) ?? digits.endIndex
            groups.append(String(digits[currentIndex..<endIndex]))
            currentIndex = endIndex
        }
        return groups.joined(separator: ":")
    }

    func updateTeamName(_ name: String, isHome: Bool) {
        let resolvedName = normalizedTeamName(name)

        if isHome {
            homeTeamName = resolvedName
        } else {
            guestTeamName = resolvedName
        }
    }

    func adjustScore(isHome: Bool, by delta: Int) {
        if routeRemoteControlCommand("score.adjust", side: isHome ? .home : .guest, value: delta) { return }
        guard supportsScore else {
            recordLog(
                kind: .scoreAdjustment,
                summary: localizedStoreFormat("%@ score %@", isHome ? TeamSide.home.title : TeamSide.guest.title, signedStoreDelta(delta)),
                outcome: .ignored,
                teamSide: isHome ? .home : .guest,
                delta: delta
            )
            return
        }

        let previousHomeScore = homeScore
        let previousGuestScore = guestScore

        if isHome {
            homeScore = max(0, homeScore + delta)
        } else {
            guestScore = max(0, guestScore + delta)
        }

        let updatedScore = isHome ? homeScore : guestScore
        let previousScore = isHome ? previousHomeScore : previousGuestScore
        recordLog(
            kind: .scoreAdjustment,
            summary: localizedStoreFormat("%@ score %@", isHome ? TeamSide.home.title : TeamSide.guest.title, signedStoreDelta(delta)),
            outcome: updatedScore == previousScore ? .ignored : .applied,
            teamSide: isHome ? .home : .guest,
            delta: delta,
            value: updatedScore
        )
        if updatedScore != previousScore {
            if usesServeTimer, delta > 0 {
                resetServeTimer(for: isHome ? .home : .guest)
            }
            handleScoreboardEvent(.scoreChanged)
        }
    }

    func setVolleyballServingSide(_ side: TeamSide) {
        setServeTimerSide(side)
    }

    func setServeTimerSide(_ side: TeamSide) {
        if routeRemoteControlCommand("serve.set", side: side) { return }
        guard usesServeTimer, supportsShotClock else {
            recordLog(
                kind: .possessionChange,
                summary: localizedStoreFormat("Set serving side %@", side.title),
                outcome: .ignored,
                teamSide: side,
                notes: localizedStoreString("Current sport does not support serving side")
            )
            return
        }

        let previousDirection = possessionDirection
        let wasShotClockRunning = isShotClockRunning
        resetServeTimer(for: side)
        startShotClock()
        recordLog(
            kind: .possessionChange,
            summary: localizedStoreFormat("Start serve timer for %@", side.title),
            outcome: .applied,
            teamSide: side,
            notes: localizedStoreString("Serve timer auto-started")
        )
        if previousDirection != possessionDirection {
            handleScoreboardEvent(.possessionChanged)
        }
        if !wasShotClockRunning, isShotClockRunning {
            handleScoreboardEvent(.shotClockStarted)
            requestShotClockAutosave()
        }
    }

    func awardVolleyballSet(to side: TeamSide) {
        awardPeriod(to: side)
    }

    func awardPeriod(to side: TeamSide) {
        if routeRemoteControlCommand("period.award", side: side) { return }
        guard supportsPeriodWinTracking else {
            recordLog(
                kind: .volleyballSetAward,
                summary: localizedStoreFormat("%@ wins period", side.title),
                outcome: .ignored,
                teamSide: side,
                notes: localizedStoreString("Current sport does not track period wins")
            )
            return
        }

        guard periodWinMatchWinner == nil else {
            recordLog(
                kind: .volleyballSetAward,
                summary: localizedStoreFormat("%@ wins period", side.title),
                outcome: .ignored,
                teamSide: side,
                notes: localizedStoreString("Match already has a winner")
            )
            return
        }

        let result = VolleyballSetResult(
            setNumber: period,
            winner: side,
            homeScore: homeScore,
            guestScore: guestScore
        )
        volleyballSetResults.removeAll { $0.setNumber >= period }
        volleyballSetResults.append(result)

        homeScore = 0
        guestScore = 0
        pauseShotClock()
        possessionDirection = .none
        activeShotClockPresetSeconds = defaultShotClockSeconds
        shotClockMilliseconds = defaultShotClockSeconds * 1_000

        if periodWinMatchWinner == nil {
            period = min(periodUpperBound, period + 1)
            resetClockForPeriodTransition(direction: 1)
        }

        recordLog(
            kind: .volleyballSetAward,
            summary: localizedStoreFormat("%@ wins Period %d", side.title, result.setNumber),
            outcome: .applied,
            teamSide: side,
            value: periodWins(for: side),
            notes: localizedStoreFormat("%d-%d", result.homeScore, result.guestScore)
        )
        handleScoreboardEvent(.periodChanged)
        requestShotClockAutosave()
    }

    func undoLastVolleyballSet() {
        undoLastPeriodWin()
    }

    func undoLastPeriodWin() {
        if routeRemoteControlCommand("period.undo") { return }
        guard supportsPeriodWinTracking, let result = volleyballSetResults.last else {
            recordLog(
                kind: .volleyballSetUndo,
                summary: localizedStoreString("Undo last period win"),
                outcome: .ignored
            )
            return
        }

        volleyballSetResults.removeLast()
        period = max(1, min(periodUpperBound, result.setNumber))
        resetInjuryTimeForPeriod()
        homeScore = result.homeScore
        guestScore = result.guestScore
        pauseShotClock()
        possessionDirection = .none
        activeShotClockPresetSeconds = defaultShotClockSeconds
        shotClockMilliseconds = defaultShotClockSeconds * 1_000
        recordLog(
            kind: .volleyballSetUndo,
            summary: localizedStoreFormat("Undo Period %d", result.setNumber),
            outcome: .applied,
            teamSide: result.winner,
            notes: localizedStoreFormat("%d-%d", result.homeScore, result.guestScore)
        )
        handleScoreboardEvent(.periodChanged)
        requestShotClockAutosave()
    }

    func adjustPeriod(by delta: Int) {
        if routeRemoteControlCommand("period.adjust", value: delta) { return }
        guard supportsPeriod else {
            recordLog(
                kind: .periodAdjustment,
                summary: localizedStoreFormat(delta >= 0 ? "Next %@" : "Previous %@", localizedStoreString(periodTitle)),
                outcome: .ignored,
                delta: delta
            )
            return
        }

        let previousPeriod = period
        period = max(1, min(periodUpperBound, period + delta))
        if period != previousPeriod {
            resetClockForPeriodTransition(direction: delta)
        }
        recordLog(
            kind: .periodAdjustment,
            summary: localizedStoreFormat(delta >= 0 ? "Next %@" : "Previous %@", localizedStoreString(periodTitle)),
            outcome: period == previousPeriod ? .ignored : .applied,
            delta: delta,
            value: period
        )
        if period != previousPeriod {
            handleScoreboardEvent(.periodChanged)
        }
    }

    func setPeriod(_ value: Int) {
        if routeRemoteControlCommand("period.set", value: value) { return }
        let previousPeriod = period
        if supportsPeriod {
            period = max(1, min(periodUpperBound, value))
        } else {
            period = 1
        }
        if period != previousPeriod {
            resetInjuryTimeForPeriod()
        }
    }

    func adjustClock(by delta: Int) {
        if routeRemoteControlCommand("clock.adjust", value: delta) { return }
        reconcileRunningTimersWithWallClock()

        if isDebateMode {
            guard currentDebateSegment?.timerMode == .masterClock else {
                recordLog(
                    kind: .debateTimerAdjustment,
                    summary: localizedStoreString("Adjust debate timer"),
                    outcome: .ignored,
                    delta: delta
                )
                return
            }
        }

        guard showsGameClock else {
            recordLog(
                kind: .clockAdjustment,
                summary: localizedStoreFormat("Game clock %@", signedStoreDelta(delta, suffix: "s")),
                outcome: .ignored,
                delta: delta
            )
            return
        }

        let previousClock = gameClockSeconds
        gameClockSeconds = boundedRuntimeClockSeconds(gameClockSeconds + delta)
        if gameClockMode == .countdown && gameClockSeconds == 0 {
            pauseClock()
        } else if isClockRunning {
            refreshPrimaryTimerPersistence()
        }

        recordLog(
            kind: .clockAdjustment,
            summary: localizedStoreFormat("Game clock %@", signedStoreDelta(delta, suffix: "s")),
            outcome: gameClockSeconds == previousClock ? .ignored : .applied,
            delta: delta,
            value: gameClockSeconds
        )
        if gameClockSeconds != previousClock, !isClockRunning {
            requestGameClockAutosave()
        }
    }

    func adjustShotClock(by delta: Int) {
        if routeRemoteControlCommand("shot.adjust", value: delta) { return }
        reconcileRunningTimersWithWallClock()

        guard supportsShotClock else {
            recordLog(
                kind: .shotClockAdjustment,
                summary: localizedStoreFormat("%@ %@", secondaryTimerTitle, signedStoreDelta(delta, suffix: "s")),
                outcome: .ignored,
                delta: delta
            )
            return
        }

        let previousMilliseconds = shotClockMilliseconds
        shotClockMilliseconds = boundedShotClockMilliseconds(shotClockMilliseconds + (delta * 1_000))
        if shotClockMilliseconds == 0 {
            pauseShotClock()
        }

        recordLog(
            kind: .shotClockAdjustment,
            summary: localizedStoreFormat("%@ %@", secondaryTimerTitle, signedStoreDelta(delta, suffix: "s")),
            outcome: shotClockMilliseconds == previousMilliseconds ? .ignored : .applied,
            delta: delta,
            value: shotClockMilliseconds / 1_000
        )
        if shotClockMilliseconds != previousMilliseconds, !isShotClockRunning {
            requestShotClockAutosave()
        }
    }

    func resetClock(to seconds: Int? = nil) {
        if routeRemoteControlCommand("clock.reset", value: seconds ?? defaultClockSeconds) { return }
        if isDebateMode {
            resetDebateCurrentSegment()
            return
        }

        guard showsGameClock else {
            pauseClock()
            resetInjuryTimeForPeriod()
            recordLog(
                kind: .clockReset,
                summary: localizedStoreString("Reset game clock"),
                outcome: .ignored,
                value: seconds ?? defaultClockSeconds
            )
            return
        }

        guard !isGameClockInterlockActive else {
            recordLog(
                kind: .clockReset,
                summary: localizedStoreString("Reset game clock"),
                outcome: .ignored,
                value: seconds ?? defaultClockSeconds
            )
            return
        }

        pauseClock()
        gameClockSeconds = boundedGameClockSeconds(seconds ?? defaultClockSeconds)
        resetInjuryTimeForPeriod()
        recordLog(
            kind: .clockReset,
            summary: localizedStoreString("Reset game clock"),
            outcome: .applied,
            value: gameClockSeconds
        )
        requestGameClockAutosave()
    }

    func resetShotClock(to seconds: Int? = nil) {
        if routeRemoteControlCommand("shot.reset", value: seconds ?? defaultShotClockSeconds) { return }
        guard supportsShotClock else {
            shotClockMilliseconds = 0
            activeShotClockPresetSeconds = 0
            possessionDirection = .none
            pauseShotClock()
            recordLog(
                kind: .shotClockReset,
                summary: localizedStoreFormat("Reset %@", secondaryTimerTitle.lowercased()),
                outcome: .ignored,
                value: 0
            )
            return
        }

        pauseShotClock()
        let targetSeconds = boundedShotClockSeconds(seconds ?? defaultShotClockSeconds)
        activeShotClockPresetSeconds = targetSeconds
        shotClockMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)
        if !usesServeTimer {
            possessionDirection = .none
        }
        recordLog(
            kind: .shotClockReset,
            summary: localizedStoreFormat("Reset %@", secondaryTimerTitle.lowercased()),
            outcome: .applied,
            value: targetSeconds
        )
        if !isAuditLoggingSuspended {
            handleScoreboardEvent(.shotClockReset)
        }
        requestShotClockAutosave()
    }

    func toggleClock() {
        if routeRemoteControlCommand("clock.toggle") { return }
        if isDebateMode {
            toggleDebateSegmentClock()
            return
        }

        if usesChessClocks {
            toggleChessClock()
            return
        }

        let wasRunning = isClockRunning
        isClockRunning ? pauseClock() : startClock()
        recordLog(
            kind: .clockToggle,
            summary: localizedStoreString(wasRunning ? "Pause game clock" : "Start game clock"),
            outcome: wasRunning == isClockRunning ? .ignored : .applied
        )
        if wasRunning != isClockRunning {
            handleScoreboardEvent(isClockRunning ? .gameClockStarted : .gameClockPaused)
            requestGameClockAutosave()
        }
    }

    func toggleDebateSegmentClock() {
        if routeRemoteControlCommand("clock.toggle") { return }
        guard isDebateMode else { return }
        guard let segment = currentDebateSegment, segment.timerMode != .none else {
            recordLog(
                kind: .debateTimerToggle,
                summary: localizedStoreString("Toggle debate timer"),
                outcome: .ignored,
                notes: debateSegmentTitle
            )
            return
        }
        let interruptedDispatch = currentRunningClockStoppedDispatch()
        isDebatePrepClockRunning = false
        debateActiveTimer = .segment
        let wasRunning = isClockRunning
        let stoppedDispatch = wasRunning ? currentClockStoppedDispatch() : interruptedDispatch
        isClockRunning ? pauseClock() : startClock()
        recordLog(
            kind: .debateTimerToggle,
            summary: localizedStoreString(wasRunning ? "Pause debate timer" : "Start debate timer"),
            outcome: wasRunning == isClockRunning ? .ignored : .applied,
            notes: segment.title
        )
        if wasRunning != isClockRunning || interruptedDispatch != nil {
            var dispatches = [stoppedDispatch].compactMap(\.self)
            if isClockRunning {
                dispatches.append(currentClockStartedDispatch())
            }
            if !dispatches.isEmpty {
                handleScoreboardEventDispatches(dispatches)
            }
            requestGameClockAutosave()
        }
    }

    func setSoundEnabled(_ isEnabled: Bool) {
        if routeRemoteControlCommand("sound.enabled", enabled: isEnabled) { return }
        guard isSoundEnabled != isEnabled else {
            if !isEnabled, playingTestSoundEffect != nil {
                stopTestSound()
            }
            return
        }

        isSoundEnabled = isEnabled

        if !isSoundEnabled {
            stopTestSound()
            interruptEventSoundPlayback()
        }
    }

    func toggleSoundEnabled() {
        setSoundEnabled(!isSoundEnabled)
    }

    func setCompanionVisible(_ isVisible: Bool) {
        guard isCompanionVisible != isVisible else {
            if !isVisible {
                dismissCompanionFailureNotice()
            }
            return
        }

        if isVisible {
            pendingExternalAutomationIntegration = .companion
            externalAutomationSafetyNoticeID = UUID()
        } else {
            isCompanionVisible = false
            isCompanionEnabled = false
            invalidateQueuedCompanionCommands()
            dismissCompanionFailureNotice()
        }
    }

    func setCompanionEnabled(_ isEnabled: Bool) {
        let resolvedEnabled = isEnabled && isCompanionVisible
        guard isCompanionEnabled != resolvedEnabled else {
            return
        }

        isCompanionEnabled = resolvedEnabled
        if !resolvedEnabled { invalidateQueuedCompanionCommands() }
    }

    func toggleCompanionEnabled() {
        guard isCompanionVisible else {
            setCompanionEnabled(false)
            return
        }

        setCompanionEnabled(!isCompanionEnabled)
    }

    func dismissRemoteDisplayWarningNotice() {
        if let notice = remoteDisplayWarningNotice {
            dismissedRemoteDisplayWarningDisplayIDs.formUnion(notice.displayIDs)
        }
        remoteDisplayWarningNotice = nil
    }

    func setCompanionHost(_ host: String) {
        guard companionHost != host else {
            return
        }

        invalidateQueuedCompanionCommands()
        companionHost = host
    }

    func setCompanionMode(_ mode: ScoreboardCompanionMode) {
        guard companionMode != mode else {
            return
        }

        invalidateQueuedCompanionCommands()
        companionMode = mode
        companionPort = mode.defaultPort
    }

    func setCompanionPort(_ port: Int) {
        let boundedPort = UInt16(max(1, min(65_535, port)))
        guard companionPort != boundedPort else {
            return
        }

        invalidateQueuedCompanionCommands()
        companionPort = boundedPort
    }

    func companionPortText() -> String {
        "\(companionPort)"
    }

    func setCompanionPortText(_ value: String) {
        let digits = Self.asciiDigits(in: value)
        guard !digits.isEmpty, let port = Int(digits) else {
            return
        }

        setCompanionPort(port)
    }

    func companionLocationText(for event: ScoreboardSoundEvent) -> String {
        companionLocationText(for: event, sport: selectedSport)
    }

    func companionLocationText(for event: ScoreboardSoundEvent, sport: SportType) -> String {
        companionAssignmentsBySport[sport]?[event] ?? ""
    }

    func companionLocationDisplayText(for event: ScoreboardSoundEvent, sport: SportType) -> String {
        Self.formattedCompanionLocationText(companionLocationText(for: event, sport: sport))
    }

    func setCompanionLocationText(_ value: String, for event: ScoreboardSoundEvent) {
        setCompanionLocationText(value, for: event, sport: selectedSport)
    }

    func setCompanionLocationText(_ value: String, for event: ScoreboardSoundEvent, sport: SportType) {
        guard event != .general else {
            return
        }

        var assignmentsBySport = companionAssignmentsBySport
        var sportAssignments = assignmentsBySport[sport] ?? [:]
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentValue = sportAssignments[event] ?? ""
        guard currentValue != trimmedValue else {
            return
        }

        if trimmedValue.isEmpty {
            sportAssignments.removeValue(forKey: event)
        } else {
            sportAssignments[event] = trimmedValue
        }
        if sportAssignments.isEmpty {
            assignmentsBySport.removeValue(forKey: sport)
        } else {
            assignmentsBySport[sport] = sportAssignments
        }
        companionAssignmentsBySport = assignmentsBySport
    }

    func setCompanionLocationDisplayText(_ value: String, for event: ScoreboardSoundEvent, sport: SportType) {
        setCompanionLocationText(Self.formattedCompanionLocationText(value), for: event, sport: sport)
    }

    func companionLocationValidationMessage(for event: ScoreboardSoundEvent) -> String? {
        companionLocationValidationMessage(for: event, sport: selectedSport)
    }

    func companionLocationValidationMessage(for event: ScoreboardSoundEvent, sport: SportType) -> String? {
        ScoreboardCompanionLocation.validationMessage(for: companionLocationText(for: event, sport: sport))
    }

    func canTestCompanionCommand(for event: ScoreboardSoundEvent) -> Bool {
        canTestCompanionCommand(for: event, sport: selectedSport)
    }

    func canTestCompanionCommand(for event: ScoreboardSoundEvent, sport: SportType) -> Bool {
        isCompanionVisible &&
            isCompanionEnabled &&
            !companionHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            companionLocation(for: event, sport: sport) != nil
    }

    func testCompanionCommand(for event: ScoreboardSoundEvent) {
        testCompanionCommand(for: event, sport: selectedSport)
    }

    func testCompanionCommand(for event: ScoreboardSoundEvent, sport: SportType) {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "companionTest", displayID: "",
                                            sport: sport, soundEvent: event))
            return
        }
        guard !isCompanionEventBypassed(event, sport: sport) else { return }
        guard let location = companionLocation(for: event, sport: sport) else {
            handleCompanionSendResult(.failure(.invalidLocation))
            return
        }

        sendCompanionPress(location)
    }

    func isSoundEventBypassed(_ event: ScoreboardSoundEvent, sport: SportType) -> Bool {
        bypassedSoundEventsBySport[sport]?.contains(event) == true
    }

    func setSoundEventBypassed(_ isBypassed: Bool, event: ScoreboardSoundEvent, sport: SportType) {
        var events = bypassedSoundEventsBySport[sport] ?? []
        if isBypassed { events.insert(event) } else { events.remove(event) }
        bypassedSoundEventsBySport[sport] = events
        if isBypassed, playingTestSoundEffect == selectedSoundEffect(for: event, sport: sport) {
            stopTestSound()
        }
        if isBypassed, let action = activeEventAction, action.sport == sport,
           action.triggerEvent == event || action.soundEvent == event {
            interruptEventSoundPlayback()
        }
    }

    func isCompanionEventBypassed(_ event: ScoreboardSoundEvent, sport: SportType) -> Bool {
        bypassedCompanionEventsBySport[sport]?.contains(event) == true
    }

    func setCompanionEventBypassed(_ isBypassed: Bool, event: ScoreboardSoundEvent, sport: SportType) {
        var events = bypassedCompanionEventsBySport[sport] ?? []
        if isBypassed { events.insert(event) } else { events.remove(event) }
        bypassedCompanionEventsBySport[sport] = events
        if isBypassed {
            companionService.cancelPendingPresses(eventKey: "\(sport.rawValue):\(event.rawValue)")
        }
    }

    func selectedSoundEffect(for event: ScoreboardSoundEvent) -> ScoreboardSoundEffect {
        selectedSoundEffect(for: event, sport: selectedSport)
    }

    func selectedSoundEffect(for event: ScoreboardSoundEvent, sport: SportType) -> ScoreboardSoundEffect {
        soundAssignmentsBySport[sport]?[event] ?? Self.defaultSoundAssignments[event] ?? .none
    }

    func setSoundEffect(_ effect: ScoreboardSoundEffect, for event: ScoreboardSoundEvent) {
        setSoundEffect(effect, for: event, sport: selectedSport)
    }

    func setSoundEffect(_ effect: ScoreboardSoundEffect, for event: ScoreboardSoundEvent, sport: SportType) {
        guard selectedSoundEffect(for: event, sport: sport) != effect else {
            return
        }

        var assignmentsBySport = soundAssignmentsBySport
        var sportAssignments = assignmentsBySport[sport] ?? Self.defaultSoundAssignments
        sportAssignments[event] = effect
        assignmentsBySport[sport] = sportAssignments
        soundAssignmentsBySport = assignmentsBySport
    }

    func resetSoundSettingsToDefaults() {
        stopTestSound()
        isSoundEnabled = true
        bypassedSoundEventsBySport = [:]
        soundAssignmentsBySport = Self.defaultSoundAssignmentsBySport
    }

    func keyboardShortcut(for action: ScoreboardKeyboardShortcutAction) -> ScoreboardKeyboardShortcut? {
        keyboardShortcutsByAction[action]?.normalized
    }

    func keyboardShortcutAction(for shortcut: ScoreboardKeyboardShortcut) -> ScoreboardKeyboardShortcutAction? {
        guard let normalizedShortcut = shortcut.normalized else {
            return nil
        }
        return ScoreboardKeyboardShortcutAction.allCases.first {
            keyboardShortcutsByAction[$0]?.normalized == normalizedShortcut
        }
    }

    func setKeyboardShortcut(_ shortcut: ScoreboardKeyboardShortcut?, for action: ScoreboardKeyboardShortcutAction) {
        var assignments = keyboardShortcutsByAction
        assignments.removeValue(forKey: action)

        if let normalizedShortcut = shortcut?.normalized {
            for (assignedAction, assignedShortcut) in assignments where assignedShortcut.normalized == normalizedShortcut {
                assignments.removeValue(forKey: assignedAction)
            }
            assignments[action] = normalizedShortcut
        }

        keyboardShortcutsByAction = Self.normalizedKeyboardShortcuts(assignments)
    }

    func clearKeyboardShortcut(for action: ScoreboardKeyboardShortcutAction) {
        setKeyboardShortcut(nil, for: action)
    }

    func resetKeyboardShortcutsToDefaults() {
        keyboardShortcutsByAction = Self.defaultKeyboardShortcutsByAction
    }

    func playTestSound(_ event: ScoreboardSoundEvent) {
        playTestSound(event, sport: selectedSport)
    }

    func playTestSound(_ event: ScoreboardSoundEvent, sport: SportType) {
        guard !isSoundEventBypassed(event, sport: sport) else { return }
        toggleTestSound(selectedSoundEffect(for: event, sport: sport))
    }

    func playTestEffect(_ effect: ScoreboardSoundEffect) {
        toggleTestSound(effect)
    }

    func playControlSound(_ effect: ScoreboardSoundEffect) {
        if routeRemoteControlCommand("sound.play", text: effect.rawValue) { return }
        // Use the normal event queue so the same sound reaches paired displays,
        // while explicit sound playback never sends a Companion command.
        guard isSoundEnabled, effect != .none else { return }
        queuedEventActions.append(QueuedEventAction(
            effect: effect, triggerEvent: .general, soundEvent: .general, companionEvent: nil,
            sport: selectedSport, companionLocation: nil, companionGeneration: companionCommandGeneration
        ))
        playNextEventAction()
    }

    func prepareTestSoundEffects() {
        buzzerPlayer.prepare(ScoreboardSoundEffect.allCases)
    }

    func toggleTestSound(_ effect: ScoreboardSoundEffect) {
        guard isSoundEnabled, effect != .none, activeEventPlaybackID == nil else {
            return
        }

        if playingTestSoundEffect == effect {
            stopTestSound()
            return
        }

        stopTestSound()
        playingTestSoundEffect = effect
        buzzerPlayer.play(effect) { [weak self] finishedEffect in
            guard self?.playingTestSoundEffect == finishedEffect else {
                return
            }
            self?.playingTestSoundEffect = nil
        }
    }

    func stopTestSound() {
        guard playingTestSoundEffect != nil else { return }
        playingTestSoundEffect = nil
        buzzerPlayer.stop()
    }

    func canTestSoundEffect(_ effect: ScoreboardSoundEffect) -> Bool {
        isSoundEnabled && effect != .none && activeEventPlaybackID == nil
    }

    func isTestingSoundEffect(_ effect: ScoreboardSoundEffect) -> Bool {
        playingTestSoundEffect == effect
    }

    func toggleShotClock() {
        if routeRemoteControlCommand("shot.toggle") { return }
        guard supportsShotClock else {
            recordLog(
                kind: .shotClockToggle,
                summary: localizedStoreFormat("Toggle %@", secondaryTimerTitle.lowercased()),
                outcome: .ignored
            )
            return
        }

        let wasRunning = isShotClockRunning
        isShotClockRunning ? pauseShotClock() : startShotClock()
        recordLog(
            kind: .shotClockToggle,
            summary: localizedStoreFormat(wasRunning ? "Pause %@" : "Start %@", secondaryTimerTitle.lowercased()),
            outcome: wasRunning == isShotClockRunning ? .ignored : .applied
        )
        if wasRunning != isShotClockRunning {
            handleScoreboardEvent(isShotClockRunning ? .shotClockStarted : .shotClockPaused)
            requestShotClockAutosave()
        }
    }

    func setPossessionDirection(_ direction: PossessionDirection, autoStartShotClock: Bool = false) {
        if routeRemoteControlCommand("possession.set", text: direction.rawValue, enabled: autoStartShotClock) { return }
        guard supportsPossession else {
            possessionDirection = .none
            recordLog(
                kind: .possessionChange,
                summary: localizedStoreFormat("Set possession %@", direction.displayName),
                outcome: .ignored,
                notes: localizedStoreString("Current sport does not support possession")
            )
            return
        }

        let previousDirection = possessionDirection
        possessionDirection = direction

        if direction == .none {
            performWithoutAuditLogging {
                resetShotClock()
            }
            recordLog(
                kind: .possessionChange,
                summary: localizedStoreFormat("Set possession %@", PossessionDirection.none.displayName),
                outcome: previousDirection == direction ? .ignored : .applied
            )
            if previousDirection != direction {
                handleScoreboardEvent(.possessionChanged)
            }
            return
        }

        guard autoStartShotClock, !isShotClockRunning else {
            recordLog(
                kind: .possessionChange,
                summary: localizedStoreFormat("Set possession %@", direction.displayName),
                outcome: previousDirection == direction ? .ignored : .applied
            )
            if previousDirection != direction {
                handleScoreboardEvent(.possessionChanged)
            }
            return
        }

        let wasShotClockRunning = isShotClockRunning
        startShotClock()
        recordLog(
            kind: .possessionChange,
            summary: localizedStoreFormat("Set possession %@", direction.displayName),
            outcome: .applied,
            notes: localizedStoreString("Shot clock auto-started")
        )
        handleScoreboardEvent(.possessionChanged)
        if wasShotClockRunning != isShotClockRunning {
            requestShotClockAutosave()
        }
    }

    func assignShotClock(to seconds: Int, forHomeTeam isHome: Bool) {
        if routeRemoteControlCommand("shot.assign", side: isHome ? .home : .guest, value: seconds) { return }
        guard supportsShotClock else {
            recordLog(
                kind: .shotClockAssignment,
                summary: localizedStoreFormat("Assign shot clock %@ to %@", "\(seconds)s", isHome ? TeamSide.home.title : TeamSide.guest.title),
                outcome: .ignored,
                teamSide: isHome ? .home : .guest,
                value: seconds
            )
            return
        }

        let targetDirection: PossessionDirection = isHome ? .home : .guest
        let targetSeconds = boundedShotClockSeconds(seconds)
        let targetMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)
        let isSameSelection = possessionDirection == targetDirection && activeShotClockPresetSeconds == targetSeconds

        if isSameSelection {
            let wasRunning = isShotClockRunning
            isShotClockRunning ? pauseShotClock() : startShotClock()
            recordLog(
                kind: .shotClockAssignment,
                summary: localizedStoreFormat("%@ %@ shot clock for %@", localizedStoreString(isShotClockRunning ? "Start" : "Pause"), "\(seconds)s", isHome ? TeamSide.home.title : TeamSide.guest.title),
                outcome: .applied,
                teamSide: isHome ? .home : .guest,
                value: seconds
            )
            if wasRunning != isShotClockRunning {
                handleScoreboardEvent(isShotClockRunning ? .shotClockStarted : .shotClockPaused)
                requestShotClockAutosave()
            }
            return
        }

        possessionDirection = targetDirection
        activeShotClockPresetSeconds = targetSeconds
        shotClockMilliseconds = targetMilliseconds
        startShotClock()
        recordLog(
            kind: .shotClockAssignment,
            summary: localizedStoreFormat("Assign %@ shot clock to %@", "\(seconds)s", isHome ? TeamSide.home.title : TeamSide.guest.title),
            outcome: .applied,
            teamSide: isHome ? .home : .guest,
            value: targetSeconds
        )
        handleScoreboardEvent(.shotClockStarted)
        requestShotClockAutosave()
    }

    func resetActiveShotClock() {
        if routeRemoteControlCommand("shot.activeReset") { return }
        guard supportsShotClock else {
            recordLog(
                kind: .shotClockReset,
                summary: localizedStoreFormat("Reset active %@", secondaryTimerTitle.lowercased()),
                outcome: .ignored
            )
            return
        }

        let resolvedTargetSeconds = activeShotClockPresetSeconds > 0 ? activeShotClockPresetSeconds : defaultShotClockSeconds
        let targetSeconds = boundedShotClockSeconds(resolvedTargetSeconds)
        let targetMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)

        isShotClockRunning = false
        accumulatedShotClockElapsed = 0
        activeShotClockPresetSeconds = targetSeconds
        shotClockMilliseconds = targetMilliseconds
        if !usesServeTimer {
            possessionDirection = .none
        }
        updateTimerState()
        recordLog(
            kind: .shotClockReset,
            summary: localizedStoreFormat("Reset active %@", secondaryTimerTitle.lowercased()),
            outcome: .applied,
            value: targetSeconds
        )
        handleScoreboardEvent(.shotClockReset)
        requestShotClockAutosave()
    }

    func newGame() {
        if routeRemoteControlCommand("game.new") { return }
        pauseClock()
        pauseShotClock()
        clearQueuedEventActions()
        isDebatePrepClockRunning = false
        homeScore = 0
        guestScore = 0
        period = supportsPeriod ? 1 : period
        volleyballSetResults = []
        possessionDirection = .none
        activeShotClockPresetSeconds = defaultShotClockSeconds
        gameClockSeconds = defaultClockSeconds
        resetInjuryTimeForPeriod()
        shotClockMilliseconds = defaultShotClockSeconds * 1_000
        pauseTimer = nil
        accumulatedPauseElapsed = 0
        homePausesUsed = 0
        guestPausesUsed = 0
        homeSubstitutionsUsed = 0
        guestSubstitutionsUsed = 0
        homeTeamFouls = 0
        guestTeamFouls = 0
        homeChessClockSeconds = chessClockPreset.seconds
        guestChessClockSeconds = chessClockPreset.seconds
        activeChessClockSide = .home
        homePenaltyTimers = []
        guestPenaltyTimers = []
        isPlayerOverlayPaused = false
        if isDebateMode {
            debatePrepHomeSeconds = isDebatePrepTimeEnabled ? currentDebatePreset.prepSecondsPerSide : 0
            debatePrepGuestSeconds = isDebatePrepTimeEnabled ? currentDebatePreset.prepSecondsPerSide : 0
            configureDebateSegment(index: 0, preserveRunningState: false)
        }
        resetPlayerTrackingForNewGame()
        updateTimerState()
        requestGameClockAutosave()
    }

    func resetScores() {
        if routeRemoteControlCommand("score.reset") { return }
        guard supportsScore else {
            recordLog(
                kind: .scoresReset,
                summary: localizedStoreString("Zero both scores"),
                outcome: .ignored
            )
            return
        }

        guard !isGameClockInterlockActive else {
            recordLog(
                kind: .scoresReset,
                summary: localizedStoreString("Zero both scores"),
                outcome: .ignored
            )
            return
        }

        homeScore = 0
        guestScore = 0
        recordLog(
            kind: .scoresReset,
            summary: localizedStoreString("Zero both scores"),
            outcome: .applied
        )
    }

    func swapSides() {
        if routeRemoteControlCommand("sides.swap") { return }
        areSidesSwapped.toggle()
        recordLog(
            kind: .sideSwap,
            summary: localizedStoreString("Swap home and guest sides"),
            outcome: .applied
        )
        handleScoreboardEvent(.sideSwitched)
    }

    func setControlBoardDisplayDirection(_ direction: ScoreboardDisplayDirection) {
        controlBoardDisplayDirection = direction
    }

    func setPlayerTrackingEnabled(_ isEnabled: Bool) {
        if isDebateMode {
            setDebatePlayerTrackingEnabled(isEnabled)
            return
        }

        isPlayerTrackingEnabled = supportsPlayerTracking ? isEnabled : false
    }

    func togglePlayerOverlayPaused() {
        if routeRemoteControlCommand("player.overlay") { return }
        isPlayerOverlayPaused.toggle()
        recordLog(
            kind: .playerOverlayToggle,
            summary: localizedStoreString(isPlayerOverlayPaused ? "Pause public player overlay" : "Resume public player overlay"),
            outcome: .applied
        )
        handleScoreboardEvent(isPlayerOverlayPaused ? .playerOverlayPaused : .playerOverlayShown)
    }

    func setRosterSizePerTeam(_ size: Int) {
        let boundedSize = max(Self.minRosterSize, min(Self.maxRosterSize, size))
        rosterSizePerTeam = boundedSize
        displayLineupSize = min(displayLineupSize, boundedSize)
        resizeRoster(for: .home, to: boundedSize)
        resizeRoster(for: .guest, to: boundedSize)
    }

    func setDisplayLineupSize(_ size: Int) {
        displayLineupSize = max(1, min(rosterSizePerTeam, size))
        homeRoster = normalizedRoster(homeRoster, fallbackCount: rosterSizePerTeam)
        guestRoster = normalizedRoster(guestRoster, fallbackCount: rosterSizePerTeam)
    }

    func setPlayerLineupFadePageSeconds(_ seconds: Int) {
        playerLineupFadePageSeconds = max(Self.minPlayerLineupFadePageSeconds, min(Self.maxPlayerLineupFadePageSeconds, seconds))
    }

    func setPlayerLineupScrollSpeed(_ speed: Int) {
        playerLineupScrollSpeed = max(Self.minPlayerLineupScrollSpeed, min(Self.maxPlayerLineupScrollSpeed, speed))
    }

    func trackedPlayers(for side: TeamSide) -> [TrackedPlayer] {
        roster(for: side).players
    }

    func updateTrackedPlayerNumber(_ number: String, for side: TeamSide, playerID: UUID) {
        if routeRemoteControlCommand("player.number", side: side, text: number, playerID: playerID) { return }
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].number = normalizedPlayerNumber(number)
        }
    }

    func updateTrackedPlayerName(_ name: String, for side: TeamSide, playerID: UUID) {
        if routeRemoteControlCommand("player.name", side: side, text: name, playerID: playerID) { return }
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].name = normalizedPlayerName(name)
        }
    }

    func adjustFoulCount(for side: TeamSide, playerID: UUID, by delta: Int) {
        if routeRemoteControlCommand("player.foul", side: side, value: delta, playerID: playerID) { return }
        guard supportsFouls else {
            recordLog(
                kind: .playerFoulAdjustment,
                summary: localizedStoreString("Adjust player foul"),
                outcome: .ignored,
                teamSide: side,
                delta: delta
            )
            return
        }

        let playerSummary = trackedPlayers(for: side).first { $0.id == playerID }
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].foulCount = max(0, roster.players[index].foulCount + delta)
        }
        let updatedPlayer = trackedPlayers(for: side).first { $0.id == playerID }
        recordLog(
            kind: .playerFoulAdjustment,
            summary: localizedStoreFormat("%@ player foul %@", side.title, signedStoreDelta(delta)),
            outcome: playerSummary?.foulCount == updatedPlayer?.foulCount ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? playerSummary,
            delta: delta,
            value: updatedPlayer?.foulCount
        )
        if delta > 0, playerSummary?.foulCount != updatedPlayer?.foulCount {
            handleScoreboardEvent(.playerFoulApplied)
        }
    }

    func resetFouls(for side: TeamSide, playerID: UUID) {
        if routeRemoteControlCommand("player.foulsReset", side: side, playerID: playerID) { return }
        guard supportsFouls else {
            recordLog(
                kind: .playerFoulReset,
                summary: localizedStoreString("Reset player foul"),
                outcome: .ignored,
                teamSide: side
            )
            return
        }

        let previousPlayer = trackedPlayers(for: side).first { $0.id == playerID }
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].foulCount = 0
        }
        let updatedPlayer = trackedPlayers(for: side).first { $0.id == playerID }
        recordLog(
            kind: .playerFoulReset,
            summary: localizedStoreFormat("Reset %@ player foul", side.title),
            outcome: previousPlayer?.foulCount == updatedPlayer?.foulCount ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? previousPlayer
        )
    }

    func resetFouls(for side: TeamSide) {
        if routeRemoteControlCommand("team.playerFoulsReset", side: side) { return }
        guard supportsFouls else {
            recordLog(
                kind: .playerFoulResetAll,
                summary: localizedStoreFormat("Reset %@ player fouls", side.title),
                outcome: .ignored,
                teamSide: side
            )
            return
        }

        let hadFouls = trackedPlayers(for: side).contains { $0.foulCount > 0 }
        updateRoster(for: side) { roster in
            for index in roster.players.indices {
                roster.players[index].foulCount = 0
            }
        }
        recordLog(
            kind: .playerFoulResetAll,
            summary: localizedStoreFormat("Reset %@ player fouls", side.title),
            outcome: hadFouls ? .applied : .ignored,
            teamSide: side
        )
    }

    func resetAllPlayerFouls() {
        if routeRemoteControlCommand("all.playerFoulsReset") { return }
        resetFouls(for: .home)
        resetFouls(for: .guest)
    }

    func setCardStatus(_ status: PlayerCardStatus, for side: TeamSide, playerID: UUID) {
        if routeRemoteControlCommand("player.card", side: side, text: status.rawValue, playerID: playerID) { return }
        guard supportsCards else {
            recordLog(
                kind: .playerCardSet,
                summary: localizedStoreFormat("Set player card %@", status.title),
                outcome: .ignored,
                teamSide: side
            )
            return
        }

        let previousPlayer = trackedPlayers(for: side).first { $0.id == playerID }
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].cardStatus = status
        }
        let updatedPlayer = trackedPlayers(for: side).first { $0.id == playerID }
        recordLog(
            kind: .playerCardSet,
            summary: localizedStoreFormat("Set %@ player card %@", side.title, status.title),
            outcome: previousPlayer?.cardStatus == updatedPlayer?.cardStatus ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? previousPlayer,
            value: cardLogValue(for: status)
        )
        if previousPlayer?.cardStatus != updatedPlayer?.cardStatus {
            switch status {
            case .yellow:
                handleScoreboardEvent(.yellowCardAssigned)
            case .red:
                handleScoreboardEvent(.redCardAssigned)
            case .none:
                break
            }
        }
    }

    func resetCards(for side: TeamSide) {
        if routeRemoteControlCommand("team.cardsReset", side: side) { return }
        guard supportsCards else {
            recordLog(
                kind: .playerCardReset,
                summary: localizedStoreFormat("Reset %@ cards", side.title),
                outcome: .ignored,
                teamSide: side
            )
            return
        }

        let hadCards = trackedPlayers(for: side).contains { $0.cardStatus != .none }
        updateRoster(for: side) { roster in
            for index in roster.players.indices {
                roster.players[index].cardStatus = .none
            }
        }
        recordLog(
            kind: .playerCardReset,
            summary: localizedStoreFormat("Reset %@ cards", side.title),
            outcome: hadCards ? .applied : .ignored,
            teamSide: side
        )
    }

    func resetAllPlayerCards() {
        if routeRemoteControlCommand("all.cardsReset") { return }
        resetCards(for: .home)
        resetCards(for: .guest)
    }

    func adjustTeamFouls(for side: TeamSide, by delta: Int) {
        if routeRemoteControlCommand("team.foul", side: side, value: delta) { return }
        guard supportsTeamFouls else {
            recordLog(
                kind: .teamFoulAdjustment,
                summary: localizedStoreFormat("%@ team fouls %@", side.title, signedStoreDelta(delta)),
                outcome: .ignored,
                teamSide: side,
                delta: delta
            )
            return
        }

        let previousValue = teamFouls(for: side)
        switch side {
        case .home:
            homeTeamFouls = max(0, homeTeamFouls + delta)
        case .guest:
            guestTeamFouls = max(0, guestTeamFouls + delta)
        }
        recordLog(
            kind: .teamFoulAdjustment,
            summary: localizedStoreFormat("%@ team fouls %@", side.title, signedStoreDelta(delta)),
            outcome: teamFouls(for: side) == previousValue ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: teamFouls(for: side)
        )
        if delta > 0, teamFouls(for: side) != previousValue {
            handleScoreboardEvent(.teamFoulApplied)
        }
    }

    func resetTeamFouls(for side: TeamSide) {
        if routeRemoteControlCommand("team.foulsReset", side: side) { return }
        guard supportsTeamFouls else {
            recordLog(
                kind: .teamFoulReset,
                summary: localizedStoreFormat("Reset %@ team fouls", side.title),
                outcome: .ignored,
                teamSide: side
            )
            return
        }

        let previousValue = teamFouls(for: side)
        switch side {
        case .home:
            homeTeamFouls = 0
        case .guest:
            guestTeamFouls = 0
        }
        recordLog(
            kind: .teamFoulReset,
            summary: localizedStoreFormat("Reset %@ team fouls", side.title),
            outcome: previousValue == 0 ? .ignored : .applied,
            teamSide: side
        )
    }

    func resetAllTeamFouls() {
        if routeRemoteControlCommand("all.teamFoulsReset") { return }
        resetTeamFouls(for: .home)
        resetTeamFouls(for: .guest)
    }

    func applyDebatePreset(id: String, resetRound: Bool = true) {
        let preset = id == DebatePreset.customID ? customDebatePreset : DebatePreset.preset(id: id)
        selectedDebatePresetID = preset.id
        debateHomeSideLabel = preset.homeSideLabel
        debateGuestSideLabel = preset.guestSideLabel
        isDebatePrepTimeEnabled = preset.isPrepTimeEnabled
        isDebateScoreTrackingEnabled = preset.defaultScoreTrackingEnabled
        isDebatePlayerTrackingEnabled = preset.defaultPlayerTrackingEnabled
        isDebatePlayerFoulsEnabled = preset.defaultPlayerFoulsEnabled
        isDebatePlayerCardsEnabled = preset.defaultPlayerCardsEnabled

        if resetRound {
            resetDebateRound(logKind: .debatePresetChange, notes: preset.title)
        } else {
            configureDebateSegment(index: min(debateCurrentSegmentIndex, max(preset.segments.count - 1, 0)), preserveRunningState: false)
            debatePrepHomeSeconds = isDebatePrepTimeEnabled ? preset.prepSecondsPerSide : 0
            debatePrepGuestSeconds = isDebatePrepTimeEnabled ? preset.prepSecondsPerSide : 0
        }
    }

    func updateCustomDebatePreset(_ preset: DebatePreset, resetRound: Bool = false) {
        var resolved = preset
        resolved.id = DebatePreset.customID
        if resolved.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved.title = DebatePreset.customDefault.title
        }
        if resolved.homeSideLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved.homeSideLabel = DebatePreset.customDefault.homeSideLabel
        }
        if resolved.guestSideLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved.guestSideLabel = DebatePreset.customDefault.guestSideLabel
        }
        if resolved.segments.isEmpty {
            resolved.segments = DebatePreset.customDefault.segments
        }
        if !resolved.isPrepTimeEnabled {
            resolved.prepSecondsPerSide = 0
        }
        resolved.prepSecondsPerSide = boundedGameClockSeconds(resolved.prepSecondsPerSide)
        for index in resolved.segments.indices {
            resolved.segments[index].durationSeconds = boundedDebateSegmentSeconds(resolved.segments[index].durationSeconds)
            if resolved.segments[index].timerMode != .dualClock {
                resolved.segments[index].startingSide = nil
                resolved.segments[index].allowsSideSwitching = false
            } else if resolved.segments[index].startingSide == nil {
                resolved.segments[index].startingSide = .home
            }
        }

        customDebatePreset = resolved
        if selectedDebatePresetID == DebatePreset.customID {
            debateHomeSideLabel = resolved.homeSideLabel
            debateGuestSideLabel = resolved.guestSideLabel
            isDebatePrepTimeEnabled = resolved.isPrepTimeEnabled
            isDebateScoreTrackingEnabled = resolved.defaultScoreTrackingEnabled
            isDebatePlayerTrackingEnabled = resolved.defaultPlayerTrackingEnabled
            isDebatePlayerFoulsEnabled = resolved.defaultPlayerFoulsEnabled
            isDebatePlayerCardsEnabled = resolved.defaultPlayerCardsEnabled
            if resetRound {
                resetDebateRound(logKind: .debatePresetChange, notes: resolved.title)
            } else {
                configureDebateSegment(index: min(debateCurrentSegmentIndex, max(resolved.segments.count - 1, 0)), preserveRunningState: false)
                debatePrepHomeSeconds = resolved.isPrepTimeEnabled ? resolved.prepSecondsPerSide : 0
                debatePrepGuestSeconds = resolved.isPrepTimeEnabled ? resolved.prepSecondsPerSide : 0
            }
        }
    }

    func updateDebateSideLabel(_ label: String, for side: TeamSide) {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch side {
        case .home:
            debateHomeSideLabel = normalized
        case .guest:
            debateGuestSideLabel = normalized
        }
    }

    func setDebateScoreTrackingEnabled(_ isEnabled: Bool) {
        isDebateScoreTrackingEnabled = isEnabled
        if !isEnabled {
            homeScore = 0
            guestScore = 0
        }
    }

    func setDebatePrepTimeEnabled(_ isEnabled: Bool) {
        isDebatePrepTimeEnabled = isEnabled
        if isEnabled {
            debatePrepHomeSeconds = currentDebatePreset.prepSecondsPerSide
            debatePrepGuestSeconds = currentDebatePreset.prepSecondsPerSide
        } else {
            if debateActiveTimer != .segment {
                returnToDebateSegmentTimer()
            }
            debatePrepHomeSeconds = 0
            debatePrepGuestSeconds = 0
        }
    }

    func setDebatePlayerTrackingEnabled(_ isEnabled: Bool) {
        isDebatePlayerTrackingEnabled = isEnabled
        isPlayerTrackingEnabled = isEnabled
        if !isEnabled {
            isPlayerOverlayPaused = false
        }
    }

    func setDebatePlayerFoulsEnabled(_ isEnabled: Bool) {
        if !isEnabled {
            resetAllPlayerFouls()
        }
        isDebatePlayerFoulsEnabled = isEnabled
    }

    func setDebatePlayerCardsEnabled(_ isEnabled: Bool) {
        if !isEnabled {
            resetAllPlayerCards()
        }
        isDebatePlayerCardsEnabled = isEnabled
    }

    func resetDebateRound(logKind: ScoreboardLogOperationKind = .debateRoundReset, notes: String? = nil) {
        if routeRemoteControlCommand("debate.resetRound") { return }
        guard isDebateMode else { return }
        pauseClock()
        isDebatePrepClockRunning = false
        debateActiveTimer = .segment
        debateCurrentSegmentIndex = 0
        homeScore = isDebateScoreTrackingEnabled ? homeScore : 0
        guestScore = isDebateScoreTrackingEnabled ? guestScore : 0
        debatePrepHomeSeconds = isDebatePrepTimeEnabled ? currentDebatePreset.prepSecondsPerSide : 0
        debatePrepGuestSeconds = isDebatePrepTimeEnabled ? currentDebatePreset.prepSecondsPerSide : 0
        configureDebateSegment(index: 0, preserveRunningState: false)
        if !isDebateScoreTrackingEnabled {
            homeScore = 0
            guestScore = 0
        }
        resetPlayerTrackingForNewGame()
        recordLog(
            kind: logKind,
            summary: localizedStoreString(logKind == .debatePresetChange ? "Apply debate preset" : "Reset debate round"),
            outcome: .applied,
            notes: notes ?? currentDebatePreset.title
        )
        requestGameClockAutosave()
    }

    func resetDebateCurrentSegment() {
        if routeRemoteControlCommand("debate.resetSegment") { return }
        guard isDebateMode else { return }
        pauseClock()
        configureDebateSegment(index: debateCurrentSegmentIndex, preserveRunningState: false)
        recordLog(
            kind: .debateSegmentReset,
            summary: localizedStoreString("Reset debate segment"),
            outcome: .applied,
            notes: debateSegmentTitle
        )
        requestGameClockAutosave()
    }

    func advanceDebateSegment(by delta: Int) {
        if routeRemoteControlCommand("debate.segment", value: delta) { return }
        guard isDebateMode else { return }
        let previousIndex = debateCurrentSegmentIndex
        let boundedIndex = max(0, min(currentDebatePreset.segments.count - 1, debateCurrentSegmentIndex + delta))
        guard boundedIndex != previousIndex else {
            recordLog(
                kind: .debateSegmentChange,
                summary: localizedStoreString(delta >= 0 ? "Next debate segment" : "Previous debate segment"),
                outcome: .ignored,
                notes: debateSegmentTitle
            )
            return
        }

        debateCurrentSegmentIndex = boundedIndex
        configureDebateSegment(index: boundedIndex, preserveRunningState: false)
        recordLog(
            kind: .debateSegmentChange,
            summary: localizedStoreString(delta >= 0 ? "Next debate segment" : "Previous debate segment"),
            outcome: .applied,
            notes: debateSegmentTitle
        )
        handleScoreboardEvent(.periodChanged)
        requestGameClockAutosave()
    }

    func toggleDebatePrepClock(for side: TeamSide) {
        if routeRemoteControlCommand("debate.prepToggle", side: side) { return }
        guard pauseTimer == nil else { return }
        guard isDebateMode, isDebatePrepTimeEnabled else { return }
        reconcileRunningTimersWithWallClock()
        let target: DebateActiveTimer = side == .home ? .prepHome : .prepGuest
        let wasClockRunning = isClockRunning
        var dispatches: [ScoreboardEventDispatch] = []
        if debateActiveTimer != target {
            if let stoppedDispatch = currentRunningClockStoppedDispatch() {
                dispatches.append(stoppedDispatch)
            }
            pauseClock()
            debateActiveTimer = target
            isDebatePrepClockRunning = false
        }
        let currentSeconds = side == .home ? debatePrepHomeSeconds : debatePrepGuestSeconds
        guard currentSeconds > 0 else {
            recordLog(
                kind: .debatePrepToggle,
                summary: localizedStoreFormat("%@ prep clock toggle", sideRoleLabel(for: side)),
                outcome: .ignored,
                teamSide: side
            )
            if wasClockRunning, !isClockRunning {
                requestGameClockAutosave()
            }
            if !dispatches.isEmpty {
                handleScoreboardEventDispatches(dispatches)
            }
            return
        }
        isDebatePrepClockRunning.toggle()
        dispatches.append(isDebatePrepClockRunning ? prepClockStartedDispatch(for: side) : prepClockStoppedDispatch(for: side))
        updateTimerState()
        refreshPrimaryTimerPersistence()
        recordLog(
            kind: .debatePrepToggle,
            summary: localizedStoreFormat("%@ prep clock %@", sideRoleLabel(for: side), localizedStoreString(isDebatePrepClockRunning ? "start" : "pause")),
            outcome: .applied,
            teamSide: side,
            value: currentSeconds
        )
        handleScoreboardEventDispatches(dispatches)
        if wasClockRunning, !isClockRunning {
            requestGameClockAutosave()
        }
    }

    func returnToDebateSegmentTimer(resume: Bool = false) {
        if routeRemoteControlCommand("debate.return", enabled: resume) { return }
        guard isDebateMode else { return }
        reconcileRunningTimersWithWallClock()

        let wasOnPrepTimer = debateActiveTimer != .segment
        let stoppedDispatch = wasOnPrepTimer ? currentRunningClockStoppedDispatch() : nil
        debateActiveTimer = .segment
        isDebatePrepClockRunning = false

        if resume, currentDebateSegment?.timerMode != DebateTimerMode.none {
            startClock()
        } else {
            pauseClock()
        }

        recordLog(
            kind: .debateTimerToggle,
            summary: localizedStoreString(resume ? "Return to segment timer and resume" : "Return to segment timer"),
            outcome: wasOnPrepTimer ? .applied : .ignored,
            notes: debateSegmentTitle
        )
        if wasOnPrepTimer {
            var dispatches = [stoppedDispatch].compactMap(\.self)
            if resume {
                dispatches.append(currentClockStartedDispatch())
            }
            if !dispatches.isEmpty {
                handleScoreboardEventDispatches(dispatches)
            }
            requestGameClockAutosave()
        }
    }

    func resetDebatePrepClock(for side: TeamSide) {
        if routeRemoteControlCommand("debate.prepReset", side: side) { return }
        guard isDebateMode, isDebatePrepTimeEnabled else { return }
        reconcileRunningTimersWithWallClock()
        let value = currentDebatePreset.prepSecondsPerSide
        switch side {
        case .home:
            debatePrepHomeSeconds = value
        case .guest:
            debatePrepGuestSeconds = value
        }
        let wasRunningTargetPrepClock = isDebatePrepClockRunning && debateActiveTimer == (side == .home ? .prepHome : .prepGuest)
        if debateActiveTimer == (side == .home ? .prepHome : .prepGuest) {
            isDebatePrepClockRunning = false
            updateTimerState()
            refreshPrimaryTimerPersistence()
        }
        recordLog(
            kind: .debatePrepReset,
            summary: localizedStoreFormat("Reset %@ prep clock", sideRoleLabel(for: side)),
            outcome: .applied,
            teamSide: side,
            value: value
        )
        if wasRunningTargetPrepClock {
            handleScoreboardEventDispatches([prepClockStoppedDispatch(for: side)])
        }
    }

    func adjustDebatePrepClock(for side: TeamSide, by delta: Int) {
        if routeRemoteControlCommand("debate.prepAdjust", side: side, value: delta) { return }
        guard isDebateMode, isDebatePrepTimeEnabled else { return }
        reconcileRunningTimersWithWallClock()
        let previousValue = side == .home ? debatePrepHomeSeconds : debatePrepGuestSeconds
        switch side {
        case .home:
            debatePrepHomeSeconds = boundedGameClockSeconds(debatePrepHomeSeconds + delta)
        case .guest:
            debatePrepGuestSeconds = boundedGameClockSeconds(debatePrepGuestSeconds + delta)
        }
        if isDebatePrepClockRunning && debateActiveTimer == (side == .home ? .prepHome : .prepGuest) {
            refreshPrimaryTimerPersistence()
        }
        let updatedValue = side == .home ? debatePrepHomeSeconds : debatePrepGuestSeconds
        recordLog(
            kind: .debatePrepAdjustment,
            summary: localizedStoreFormat("%@ prep %@", sideRoleLabel(for: side), signedStoreDelta(delta, suffix: "s")),
            outcome: previousValue == updatedValue ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: updatedValue
        )
    }

    func toggleChessClock() {
        if routeRemoteControlCommand("clock.toggle") { return }
        guard pauseTimer == nil else { return }
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateTimerToggle : .chessClockToggle,
                summary: localizedStoreString(isDebateMode ? "Toggle debate timer" : "Toggle chess clock"),
                outcome: .ignored
            )
            return
        }

        let wasRunning = isClockRunning
        let stoppedDispatch = wasRunning ? currentClockStoppedDispatch() : nil
        if isClockRunning {
            pauseClock()
        } else {
            if activeChessClockSide == nil {
                activeChessClockSide = .home
            }
            startClock()
        }

        recordLog(
            kind: isDebateMode ? .debateTimerToggle : .chessClockToggle,
            summary: localizedStoreString(isDebateMode ? (wasRunning ? "Pause debate timer" : "Start debate timer") : (wasRunning ? "Pause chess clock" : "Start chess clock")),
            outcome: wasRunning == isClockRunning ? .ignored : .applied,
            teamSide: activeChessClockSide,
            notes: isDebateMode ? debateSegmentTitle : nil
        )
        if wasRunning != isClockRunning {
            if isClockRunning {
                handleScoreboardEventDispatches([currentClockStartedDispatch()])
            } else if let stoppedDispatch {
                handleScoreboardEventDispatches([stoppedDispatch])
            } else {
                handleScoreboardEvent(clockStoppedFallbackEvent)
            }
            requestGameClockAutosave()
        }
    }

    func switchChessClock() {
        if routeRemoteControlCommand("chess.switch") { return }
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateActiveSideSwitch : .chessClockSwitch,
                summary: localizedStoreString(isDebateMode ? "Switch debate active side" : "Switch active chess clock"),
                outcome: .ignored
            )
            return
        }

        reconcileRunningTimersWithWallClock()
        let previousSide = activeChessClockSide
        let stoppedDispatch = isClockRunning
            ? previousSide.map { eventDispatch(sideClockStoppedEvent(for: $0), fallbackEvent: .sideSwitched) }
            : nil
        switch activeChessClockSide {
        case .home:
            activeChessClockSide = .guest
        case .guest:
            activeChessClockSide = .home
        case .none:
            activeChessClockSide = .home
        }

        recordLog(
            kind: isDebateMode ? .debateActiveSideSwitch : .chessClockSwitch,
            summary: localizedStoreString(isDebateMode ? "Switch debate active side" : "Switch active chess clock"),
            outcome: previousSide == activeChessClockSide ? .ignored : .applied,
            teamSide: activeChessClockSide,
            notes: isDebateMode ? debateSegmentTitle : nil
        )
        if previousSide != activeChessClockSide {
            if isClockRunning, let activeChessClockSide {
                handleScoreboardEventDispatches([
                    stoppedDispatch,
                    eventDispatch(sideClockStartedEvent(for: activeChessClockSide), fallbackEvent: .sideSwitched)
                ].compactMap(\.self))
            } else {
                handleScoreboardEvent(.sideSwitched)
            }
            refreshPrimaryTimerPersistence()
        }
    }

    func setActiveChessClockSide(_ side: TeamSide) {
        if routeRemoteControlCommand("chess.side", side: side) { return }
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateActiveSideSet : .chessClockSwitch,
                summary: isDebateMode ? localizedStoreFormat("Set debate active side to %@", sideRoleLabel(for: side)) : localizedStoreFormat("Set active chess clock to %@", side.title),
                outcome: .ignored,
                teamSide: side
            )
            return
        }

        reconcileRunningTimersWithWallClock()
        let previousSide = activeChessClockSide
        let stoppedDispatch = isClockRunning
            ? previousSide.map { eventDispatch(sideClockStoppedEvent(for: $0), fallbackEvent: .sideSwitched) }
            : nil
        activeChessClockSide = side
        recordLog(
            kind: isDebateMode ? .debateActiveSideSet : .chessClockSwitch,
            summary: isDebateMode ? localizedStoreFormat("Set debate active side to %@", sideRoleLabel(for: side)) : localizedStoreFormat("Set active chess clock to %@", side.title),
            outcome: previousSide == side ? .ignored : .applied,
            teamSide: side,
            notes: isDebateMode ? debateSegmentTitle : nil
        )
        if previousSide != side {
            if isClockRunning {
                handleScoreboardEventDispatches([
                    stoppedDispatch,
                    eventDispatch(sideClockStartedEvent(for: side), fallbackEvent: .sideSwitched)
                ].compactMap(\.self))
            } else {
                handleScoreboardEvent(.sideSwitched)
            }
            refreshPrimaryTimerPersistence()
        }
    }

    func adjustChessClock(for side: TeamSide, by delta: Int) {
        if routeRemoteControlCommand("chess.adjust", side: side, value: delta) { return }
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateTimerAdjustment : .chessClockAdjustment,
                summary: isDebateMode ? localizedStoreFormat("%@ debate clock %@", sideRoleLabel(for: side), signedStoreDelta(delta, suffix: "s")) : localizedStoreFormat("%@ chess clock %@", side.title, signedStoreDelta(delta, suffix: "s")),
                outcome: .ignored,
                teamSide: side,
                delta: delta
            )
            return
        }

        reconcileRunningTimersWithWallClock()
        let previousValue = side == .home ? homeChessClockSeconds : guestChessClockSeconds
        switch side {
        case .home:
            homeChessClockSeconds = boundedRuntimeClockSeconds(homeChessClockSeconds + delta)
        case .guest:
            guestChessClockSeconds = boundedRuntimeClockSeconds(guestChessClockSeconds + delta)
        }

        let updatedValue = side == .home ? homeChessClockSeconds : guestChessClockSeconds
        if updatedValue == 0, activeChessClockSide == side {
            pauseClock()
        } else if isClockRunning {
            refreshPrimaryTimerPersistence()
        }

        recordLog(
            kind: isDebateMode ? .debateTimerAdjustment : .chessClockAdjustment,
            summary: isDebateMode ? localizedStoreFormat("%@ debate clock %@", sideRoleLabel(for: side), signedStoreDelta(delta, suffix: "s")) : localizedStoreFormat("%@ chess clock %@", side.title, signedStoreDelta(delta, suffix: "s")),
            outcome: previousValue == updatedValue ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: updatedValue,
            notes: isDebateMode ? debateSegmentTitle : nil
        )
        if previousValue != updatedValue, !isClockRunning {
            requestGameClockAutosave()
        }
    }

    func resetChessClocks() {
        if routeRemoteControlCommand("chess.reset") { return }
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateSegmentReset : .chessClockReset,
                summary: localizedStoreString(isDebateMode ? "Reset debate timer" : "Reset chess clocks"),
                outcome: .ignored
            )
            return
        }

        pauseClock()
        let resetSeconds = boundedRuntimeClockSeconds(defaultClockSeconds)
        homeChessClockSeconds = resetSeconds
        guestChessClockSeconds = usesChessClocks && selectedSport == .chess && defaultClockSeconds == 0
            ? chessClockPreset.seconds
            : resetSeconds
        activeChessClockSide = .home

        recordLog(
            kind: isDebateMode ? .debateSegmentReset : .chessClockReset,
            summary: localizedStoreString(isDebateMode ? "Reset debate timer" : "Reset chess clocks"),
            outcome: .applied,
            notes: isDebateMode ? debateSegmentTitle : (selectedSport == .chess ? chessClockPreset.title : selectedSport.title)
        )
        requestGameClockAutosave()
    }

    func addPenaltyTimer(for side: TeamSide, seconds: Int) {
        addPenaltyTimer(for: side, seconds: seconds, player: nil, startsRunning: false)
    }

    func addPenaltyTimer(for side: TeamSide, seconds: Int, player: TrackedPlayer?, startsRunning: Bool) {
        if routeRemoteControlCommand("penalty.add", side: side, value: seconds, enabled: startsRunning, playerID: player?.id) { return }
        guard pauseTimer == nil || !startsRunning else { return }
        guard supportsHockeyPenalties else {
            recordLog(
                kind: .hockeyPenaltyAdd,
                summary: localizedStoreFormat("Add %@ penalty timer", side.title),
                outcome: .ignored,
                teamSide: side,
                value: seconds
            )
            return
        }

        let timer = HockeyPenaltyTimer(
            teamSide: side,
            playerNumber: player.map { normalizedPlayerNumber($0.number) } ?? "",
            playerName: player.map { normalizedPlayerName($0.name) } ?? "",
            remainingSeconds: boundedGameClockSeconds(seconds),
            isRunning: startsRunning
        )
        switch side {
        case .home:
            homePenaltyTimers.append(timer)
        case .guest:
            guestPenaltyTimers.append(timer)
        }
        updateTimerState()

        recordLog(
            kind: .hockeyPenaltyAdd,
            summary: localizedStoreFormat("Add %@ penalty timer", side.title),
            outcome: .applied,
            teamSide: side,
            player: player,
            value: timer.remainingSeconds,
            notes: penaltySummaryItem(timer)
        )
        handleScoreboardEvent(.hockeyPenaltyAdded)
    }

    func removePenaltyTimer(for side: TeamSide, timerID: UUID) {
        if routeRemoteControlCommand("penalty.remove", side: side, timerID: timerID) { return }
        guard supportsHockeyPenalties else { return }
        let removed: HockeyPenaltyTimer?
        switch side {
        case .home:
            removed = homePenaltyTimers.first { $0.id == timerID }
            homePenaltyTimers.removeAll { $0.id == timerID }
        case .guest:
            removed = guestPenaltyTimers.first { $0.id == timerID }
            guestPenaltyTimers.removeAll { $0.id == timerID }
        }
        if !homePenaltyTimers.contains(where: \.isRunning) && !guestPenaltyTimers.contains(where: \.isRunning) {
            updateTimerState()
        }
        recordLog(
            kind: .hockeyPenaltyRemove,
            summary: localizedStoreFormat("Remove %@ penalty timer", side.title),
            outcome: removed == nil ? .ignored : .applied,
            teamSide: side,
            value: removed?.remainingSeconds
        )
    }

    func togglePenaltyTimer(for side: TeamSide, timerID: UUID) {
        if routeRemoteControlCommand("penalty.toggle", side: side, timerID: timerID) { return }
        guard pauseTimer == nil else { return }
        guard supportsHockeyPenalties else { return }
        let previous = penaltyTimer(for: side, timerID: timerID)
        updatePenaltyTimers(for: side) { timers in
            guard let index = timers.firstIndex(where: { $0.id == timerID }) else { return }
            timers[index].isRunning.toggle()
        }
        updateTimerState()
        let updated = penaltyTimer(for: side, timerID: timerID)
        recordLog(
            kind: .hockeyPenaltyToggle,
            summary: localizedStoreFormat("%@ penalty timer %@", side.title, localizedStoreString(updated?.isRunning == true ? "start" : "pause")),
            outcome: previous?.isRunning == updated?.isRunning ? .ignored : .applied,
            teamSide: side,
            value: updated?.remainingSeconds
        )
        if previous?.isRunning != updated?.isRunning {
            handleScoreboardEvent(updated?.isRunning == true ? .hockeyPenaltyStarted : .hockeyPenaltyPaused)
        }
    }

    func adjustPenaltyTimer(for side: TeamSide, timerID: UUID, by delta: Int) {
        if routeRemoteControlCommand("penalty.adjust", side: side, value: delta, timerID: timerID) { return }
        guard supportsHockeyPenalties else { return }
        let previous = penaltyTimer(for: side, timerID: timerID)
        updatePenaltyTimers(for: side) { timers in
            guard let index = timers.firstIndex(where: { $0.id == timerID }) else { return }
            timers[index].remainingSeconds = boundedGameClockSeconds(timers[index].remainingSeconds + delta)
            if timers[index].remainingSeconds == 0 {
                timers[index].isRunning = false
            }
        }
        updateTimerState()
        let updated = penaltyTimer(for: side, timerID: timerID)
        recordLog(
            kind: .hockeyPenaltyAdjustment,
            summary: localizedStoreFormat("%@ penalty timer %@", side.title, signedStoreDelta(delta, suffix: "s")),
            outcome: previous?.remainingSeconds == updated?.remainingSeconds ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: updated?.remainingSeconds
        )
    }

    func updatePenaltyTimerPlayerNumber(_ number: String, for side: TeamSide, timerID: UUID) {
        if routeRemoteControlCommand("penalty.number", side: side, text: number, timerID: timerID) { return }
        guard supportsHockeyPenalties else { return }
        let previous = penaltyTimer(for: side, timerID: timerID)
        updatePenaltyTimers(for: side) { timers in
            guard let index = timers.firstIndex(where: { $0.id == timerID }) else { return }
            timers[index].playerNumber = normalizedPlayerNumber(number)
        }
        let updated = penaltyTimer(for: side, timerID: timerID)
        recordLog(
            kind: .hockeyPenaltyPlayerEdit,
            summary: localizedStoreFormat("Edit %@ penalty player", side.title),
            outcome: previous?.playerNumber == updated?.playerNumber ? .ignored : .applied,
            teamSide: side,
            notes: penaltySummaryItem(updated)
        )
    }

    func updatePenaltyTimerPlayerName(_ name: String, for side: TeamSide, timerID: UUID) {
        if routeRemoteControlCommand("penalty.name", side: side, text: name, timerID: timerID) { return }
        guard supportsHockeyPenalties else { return }
        let previous = penaltyTimer(for: side, timerID: timerID)
        updatePenaltyTimers(for: side) { timers in
            guard let index = timers.firstIndex(where: { $0.id == timerID }) else { return }
            timers[index].playerName = normalizedPlayerName(name)
        }
        let updated = penaltyTimer(for: side, timerID: timerID)
        recordLog(
            kind: .hockeyPenaltyPlayerEdit,
            summary: localizedStoreFormat("Edit %@ penalty player", side.title),
            outcome: previous?.playerName == updated?.playerName ? .ignored : .applied,
            teamSide: side,
            notes: penaltySummaryItem(updated)
        )
    }

    func assignPenaltyTimerPlayer(_ player: TrackedPlayer, for side: TeamSide, timerID: UUID) {
        if routeRemoteControlCommand("penalty.player", side: side, playerID: player.id, timerID: timerID) { return }
        guard supportsHockeyPenalties else { return }
        let previous = penaltyTimer(for: side, timerID: timerID)
        updatePenaltyTimers(for: side) { timers in
            guard let index = timers.firstIndex(where: { $0.id == timerID }) else { return }
            timers[index].playerNumber = normalizedPlayerNumber(player.number)
            timers[index].playerName = normalizedPlayerName(player.name)
        }
        let updated = penaltyTimer(for: side, timerID: timerID)
        recordLog(
            kind: .hockeyPenaltyPlayerEdit,
            summary: localizedStoreFormat("Assign %@ penalty player", side.title),
            outcome: previous?.playerNumber == updated?.playerNumber && previous?.playerName == updated?.playerName ? .ignored : .applied,
            teamSide: side,
            player: player,
            notes: penaltySummaryItem(updated)
        )
    }

    func setGameClockEnabled(_ isEnabled: Bool) {
        if selectedSport == .volleyball || selectedSport == .custom {
            isGameClockEnabled = isEnabled
        } else {
            isGameClockEnabled = true
        }

        if !showsGameClock {
            pauseClock()
        }
        normalizeInjuryTimeState()
    }

    func setPendingInjuryTimeMinutes(_ minutes: Int) {
        if routeRemoteControlCommand("injury.set", value: minutes) { return }
        normalizeInjuryTimeState()
        guard supportsInjuryTime, !hasAppliedInjuryTimeThisPeriod else {
            return
        }

        pendingInjuryTimeMinutes = boundedInjuryTimeMinutes(minutes)
    }

    func restoreRuntimeAfterSetupApply(
        clockWasRunning: Bool,
        shotClockWasRunning: Bool,
        debatePrepWasRunning: Bool
    ) {
        isClockRunning = pauseTimer == nil && clockWasRunning && (showsGameClock || usesChessClocks)
        isShotClockRunning = pauseTimer == nil && shotClockWasRunning && supportsShotClock
        isDebatePrepClockRunning = pauseTimer == nil && debatePrepWasRunning && isDebateMode && isDebatePrepTimeEnabled && debateActiveTimer != .segment
        normalizeInjuryTimeState()
        updateTimerState()
    }

    func setSelectedSport(_ sport: SportType, applyDefaults: Bool = true) {
        if sport != selectedSport || applyDefaults {
            clearQueuedEventActions()
            pauseTimer = nil
            accumulatedPauseElapsed = 0
        }
        selectedSport = sport
        let rules = currentRules

        if applyDefaults {
            defaultClockSeconds = boundedGameClockSeconds(rules.defaultClockSeconds)
            gameClockSeconds = defaultClockSeconds
            isGameClockEnabled = sport == .volleyball || sport == .custom ? isGameClockEnabled : true
            defaultShotClockSeconds = boundedShotClockSeconds(rules.defaultShotClockSeconds)
            activeShotClockPresetSeconds = defaultShotClockSeconds
            shotClockMilliseconds = boundedShotClockMilliseconds(defaultShotClockSeconds * 1_000)
            period = rules.supportsPeriod ? 1 : 1
            volleyballMatchFormat = .bestOf5
            volleyballSetResults = []
            possessionDirection = .none
            isShotClockRunning = false
            homeSubstitutionsAllowed = rules.defaultSubstitutionLimit
            guestSubstitutionsAllowed = rules.defaultSubstitutionLimit
            homeSubstitutionsUsed = 0
            guestSubstitutionsUsed = 0
            pauseDurationSeconds = sport == .volleyball ? 30 : 60
            isTeamPauseIndefinite = false
            homePausesAllowed = rules.defaultPauseLimit
            guestPausesAllowed = rules.defaultPauseLimit
            homePausesUsed = 0
            guestPausesUsed = 0
            homeTeamFouls = 0
            guestTeamFouls = 0
            homeChessClockSeconds = boundedGameClockSeconds(rules.defaultClockSeconds)
            guestChessClockSeconds = boundedGameClockSeconds(rules.defaultClockSeconds)
            activeChessClockSide = .home
            selectedDebatePresetID = DebatePreset.publicForum.id
            debateHomeSideLabel = DebatePreset.publicForum.homeSideLabel
            debateGuestSideLabel = DebatePreset.publicForum.guestSideLabel
            debateCurrentSegmentIndex = 0
            isDebatePrepTimeEnabled = DebatePreset.publicForum.isPrepTimeEnabled
            debatePrepHomeSeconds = DebatePreset.publicForum.isPrepTimeEnabled ? DebatePreset.publicForum.prepSecondsPerSide : 0
            debatePrepGuestSeconds = DebatePreset.publicForum.isPrepTimeEnabled ? DebatePreset.publicForum.prepSecondsPerSide : 0
            debateActiveTimer = .segment
            isDebatePrepClockRunning = false
            isDebateScoreTrackingEnabled = false
            isDebatePlayerTrackingEnabled = false
            isDebatePlayerFoulsEnabled = false
            isDebatePlayerCardsEnabled = false
            homePenaltyTimers = []
            guestPenaltyTimers = []
            resetInjuryTimeForPeriod()
            setRosterSizePerTeam(max(rules.defaultRosterSize, Self.minRosterSize))
            setDisplayLineupSize(max(1, rules.defaultDisplayLineupSize))
            if sport == .simple || sport == .debate {
                clearSubstitutionTracking()
            }
            if !rules.showsPauseTracking || sport == .debate {
                clearPauseTracking()
            }
            if sport == .debate {
                applyDebatePreset(id: DebatePreset.publicForum.id, resetRound: true)
                setDebatePlayerTrackingEnabled(DebatePreset.publicForum.defaultPlayerTrackingEnabled)
                isPlayerTrackingEnabled = isDebatePlayerTrackingEnabled
            } else if !rules.supportsPlayerTracking {
                isPlayerTrackingEnabled = false
            }
        } else {
            if sport != .volleyball && sport != .custom {
                isGameClockEnabled = true
            }
            if !supportsPeriodWinTracking {
                volleyballMatchFormat = .bestOf5
                volleyballSetResults = []
            }
            if !rules.supportsShotClock {
                defaultShotClockSeconds = 0
                activeShotClockPresetSeconds = 0
                shotClockMilliseconds = 0
                possessionDirection = .none
                isShotClockRunning = false
            }
            if !rules.supportsHockeyPenalties {
                homePenaltyTimers = []
                guestPenaltyTimers = []
            }
            if sport == .simple || sport == .debate {
                clearSubstitutionTracking()
            }
            if !rules.showsPauseTracking || sport == .debate {
                clearPauseTracking()
            }
            if sport == .debate {
                isPlayerTrackingEnabled = isDebatePlayerTrackingEnabled
            } else if !rules.supportsPlayerTracking {
                isPlayerTrackingEnabled = false
            }
        }
        normalizeInjuryTimeState()
    }

    private func clearSubstitutionTracking() {
        homeSubstitutionsAllowed = 0
        guestSubstitutionsAllowed = 0
        homeSubstitutionsUsed = 0
        guestSubstitutionsUsed = 0
    }

    private func clearPauseTracking() {
        homePausesAllowed = 0
        guestPausesAllowed = 0
        homePausesUsed = 0
        guestPausesUsed = 0
    }

    func setSubstitutionsAllowed(for side: TeamSide, to value: Int) {
        let boundedValue = max(0, min(99, value))

        switch side {
        case .home:
            homeSubstitutionsAllowed = boundedValue
            homeSubstitutionsUsed = min(homeSubstitutionsUsed, boundedValue)
        case .guest:
            guestSubstitutionsAllowed = boundedValue
            guestSubstitutionsUsed = min(guestSubstitutionsUsed, boundedValue)
        }
    }

    func adjustSubstitutionsUsed(for side: TeamSide, by delta: Int) {
        if routeRemoteControlCommand("substitution.adjust", side: side, value: delta) { return }
        let previousValue = substitutionsUsed(for: side)
        switch side {
        case .home:
            homeSubstitutionsUsed = max(0, min(homeSubstitutionsAllowed, homeSubstitutionsUsed + delta))
        case .guest:
            guestSubstitutionsUsed = max(0, min(guestSubstitutionsAllowed, guestSubstitutionsUsed + delta))
        }
        recordLog(
            kind: .substitutionsAdjustment,
            summary: localizedStoreFormat("%@ swaps %@", side.title, signedStoreDelta(delta)),
            outcome: substitutionsUsed(for: side) == previousValue ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: substitutionsUsed(for: side)
        )
        if delta > 0, substitutionsUsed(for: side) != previousValue {
            handleScoreboardEvent(.substitutionUsed)
        }
    }

    private var pauseSoundEvents: [ScoreboardSoundEvent] {
        [.pauseStarted, .officialPauseStarted, .pauseTimerPaused, .pauseTimerResumed, .pauseEnded, .pauseExpired]
    }

    var pauseTitle: String? {
        pauseTimer?.title(homeTeamName: homeTeamName, guestTeamName: guestTeamName)
    }

    func setPauseDurationSeconds(_ seconds: Int) {
        pauseDurationSeconds = max(1, min(Self.maxGameClockSeconds, seconds))
    }

    func setTeamPauseIndefinite(_ isIndefinite: Bool) {
        isTeamPauseIndefinite = isIndefinite
    }

    /// Official pauses do not consume a team allowance. Zero means indefinite for either kind of pause.
    func startPause(for side: TeamSide? = nil, seconds: Int? = nil) {
        let duration = seconds ?? pauseDurationSeconds
        if routeRemoteControlCommand(side == nil ? "pause.official" : "pause.start", side: side, value: duration) { return }
        guard pauseTimer == nil, duration >= 0, duration <= Self.maxGameClockSeconds else { return }
        if let side {
            guard supportsPauseTracking, pausesRemaining(for: side) > 0 else { return }
        }
        reconcileRunningTimersWithWallClock()
        var stoppedDispatches = [currentRunningClockStoppedDispatch()].compactMap { $0 }
        if isShotClockRunning { stoppedDispatches.append(eventDispatch(.shotClockPaused)) }
        if (homePenaltyTimers + guestPenaltyTimers).contains(where: \.isRunning) {
            stoppedDispatches.append(eventDispatch(.hockeyPenaltyPaused))
        }
        isClockRunning = false
        isShotClockRunning = false
        isDebatePrepClockRunning = false
        for side in TeamSide.allCases {
            updatePenaltyTimers(for: side) { timers in
                for index in timers.indices { timers[index].isRunning = false }
            }
        }
        if let side { adjustPausesUsed(for: side, by: 1) }
        accumulatedPauseElapsed = 0
        pauseTimer = ScoreboardPauseTimer(side: side, remainingSeconds: duration == 0 ? nil : duration, isRunning: duration > 0)
        updateTimerState()
        refreshPrimaryTimerPersistence()
        handleScoreboardEventDispatches(stoppedDispatches)
        recordLog(kind: .pauseTimerChange, summary: pauseTitle ?? "", outcome: .applied, teamSide: side, value: duration)
        handleScoreboardEvent(.pauseStarted)
        if side == nil { handleScoreboardEvent(.officialPauseStarted) }
    }

    func setPauseTimerRunning(_ running: Bool) {
        if routeRemoteControlCommand("pause.running", enabled: running) { return }
        reconcileRunningTimersWithWallClock()
        guard var pause = pauseTimer, let seconds = pause.remainingSeconds, seconds > 0,
              pause.isRunning != running else { return }
        pause.isRunning = running
        pauseTimer = pause
        updateTimerState()
        recordLog(kind: .pauseTimerChange, summary: localizedStoreString(running ? "Pause Timer Resumed" : "Pause Timer Paused"), outcome: .applied, teamSide: pause.side, value: seconds)
        handleScoreboardEvent(running ? .pauseTimerResumed : .pauseTimerPaused)
    }

    func cancelPause() {
        if routeRemoteControlCommand("pause.cancel") { return }
        guard let pause = pauseTimer else { return }
        pauseTimer = nil
        accumulatedPauseElapsed = 0
        updateTimerState()
        recordLog(kind: .pauseTimerChange, summary: localizedStoreString("Pause Ended"), outcome: .applied, teamSide: pause.side)
        handleScoreboardEvent(.pauseEnded)
    }

    private func normalizedPauseTimer(_ source: ScoreboardPauseTimer?, preserveRunning: Bool) -> ScoreboardPauseTimer? {
        guard var pause = source, pause.side == nil || supportsPauseTracking else { return nil }
        if let seconds = pause.remainingSeconds { pause.remainingSeconds = max(0, min(Self.maxGameClockSeconds, seconds)) }
        pause.isRunning = preserveRunning && pause.isRunning && (pause.remainingSeconds ?? 0) > 0
        return pause
    }

    func setPausesAllowed(for side: TeamSide, to value: Int) {
        let boundedValue = max(0, min(99, value))

        switch side {
        case .home:
            homePausesAllowed = boundedValue
            homePausesUsed = min(homePausesUsed, boundedValue)
        case .guest:
            guestPausesAllowed = boundedValue
            guestPausesUsed = min(guestPausesUsed, boundedValue)
        }
    }

    func adjustPausesUsed(for side: TeamSide, by delta: Int) {
        if routeRemoteControlCommand("pause.adjust", side: side, value: delta) { return }
        guard supportsPauseTracking else {
            recordLog(
                kind: .teamPauseAdjustment,
                summary: localizedStoreFormat("%@ pauses %@", side.title, signedStoreDelta(delta)),
                outcome: .ignored,
                teamSide: side,
                delta: delta
            )
            return
        }

        let previousValue = pausesUsed(for: side)
        switch side {
        case .home:
            homePausesUsed = max(0, min(homePausesAllowed, homePausesUsed + delta))
        case .guest:
            guestPausesUsed = max(0, min(guestPausesAllowed, guestPausesUsed + delta))
        }
        recordLog(
            kind: .teamPauseAdjustment,
            summary: localizedStoreFormat("%@ pauses %@", side.title, signedStoreDelta(delta)),
            outcome: pausesUsed(for: side) == previousValue ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: pausesUsed(for: side)
        )
        if delta > 0, pausesUsed(for: side) != previousValue {
            handleScoreboardEvent(.teamPauseUsed)
        }
    }

    func setPlayerActiveLineup(_ isActive: Bool, for side: TeamSide, playerID: UUID) {
        if routeRemoteControlCommand("player.lineup", side: side, enabled: isActive, playerID: playerID) { return }
        let previousPlayer = trackedPlayers(for: side).first { $0.id == playerID }
        updateRoster(for: side) { roster in
            guard let targetIndex = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            if isActive {
                let activeIDs = roster.players
                    .filter { $0.isInActiveLineup && $0.id != playerID }
                    .map(\.id)
                let retainedIDs = Set([playerID] + Array(activeIDs.prefix(max(activeLineupCountLimit - 1, 0))))

                for index in roster.players.indices {
                    roster.players[index].isInActiveLineup = retainedIDs.contains(roster.players[index].id)
                }
            } else {
                roster.players[targetIndex].isInActiveLineup = false
            }
        }
        let updatedPlayer = trackedPlayers(for: side).first { $0.id == playerID }
        recordLog(
            kind: .lineupToggle,
            summary: localizedStoreFormat("%@ %@ player", localizedStoreString(isActive ? "Show" : "Bench"), side.title),
            outcome: previousPlayer?.isInActiveLineup == updatedPlayer?.isInActiveLineup ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? previousPlayer,
            notes: localizedStoreString(updatedPlayer?.isInActiveLineup == true ? "Active lineup" : "Bench")
        )
        if previousPlayer?.isInActiveLineup != updatedPlayer?.isInActiveLineup {
            handleScoreboardEvent(updatedPlayer?.isInActiveLineup == true ? .playerShown : .playerBenched)
        }
    }

    private func configureDebateSegment(index: Int, preserveRunningState: Bool) {
        guard isDebateMode else { return }
        guard currentDebatePreset.segments.indices.contains(index) else { return }

        let segment = currentDebatePreset.segments[index]
        debateCurrentSegmentIndex = index
        debateActiveTimer = .segment
        isDebatePrepClockRunning = false

        switch segment.timerMode {
        case .masterClock:
            defaultClockSeconds = boundedDebateSegmentSeconds(segment.durationSeconds)
            gameClockSeconds = defaultClockSeconds
            activeChessClockSide = nil
        case .dualClock:
            defaultClockSeconds = boundedDebateSegmentSeconds(segment.durationSeconds)
            homeChessClockSeconds = defaultClockSeconds
            guestChessClockSeconds = defaultClockSeconds
            activeChessClockSide = segment.startingSide ?? .home
        case .none:
            defaultClockSeconds = 0
            gameClockSeconds = 0
            activeChessClockSide = nil
        }

        if preserveRunningState {
            return
        }

        if segment.startsPaused || segment.timerMode == .none {
            pauseClock()
        } else {
            startClock()
        }
    }

    func currentGameSnapshot() -> ScoreboardGameSnapshot {
        ScoreboardGameSnapshot(
            fileVersion: 12,
            sport: selectedSport,
            customSportConfig: customSportConfig,
            customDebatePreset: customDebatePreset,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            eventName: eventName,
            homeScore: homeScore,
            guestScore: guestScore,
            period: period,
            volleyballMatchFormat: selectedSport == .volleyball ? volleyballMatchFormat : nil,
            volleyballSetResults: supportsPeriodWinTracking ? volleyballSetResults : nil,
            gameClockSeconds: gameClockSeconds,
            defaultClockSeconds: defaultClockSeconds,
            isGameClockEnabled: isGameClockEnabled,
            pendingInjuryTimeMinutes: pendingInjuryTimeMinutes,
            activeInjuryTimeMinutes: activeInjuryTimeMinutes,
            hasAppliedInjuryTimeThisPeriod: hasAppliedInjuryTimeThisPeriod,
            shotClockMilliseconds: shotClockMilliseconds,
            defaultShotClockSeconds: defaultShotClockSeconds,
            activeShotClockPresetSeconds: activeShotClockPresetSeconds,
            possessionDirection: possessionDirection,
            areSidesSwapped: false,
            isPlayerTrackingEnabled: isPlayerTrackingEnabled,
            isPlayerOverlayPaused: isPlayerOverlayPaused,
            rosterSizePerTeam: rosterSizePerTeam,
            displayLineupSize: displayLineupSize,
            playerLineupOverflowMode: playerLineupOverflowMode,
            playerLineupOverflowLogoOverride: playerLineupOverflowLogoOverride,
            playerLineupOverflowNoLogoOverride: playerLineupOverflowNoLogoOverride,
            playerLineupFadePageSeconds: playerLineupFadePageSeconds,
            playerLineupScrollSpeed: playerLineupScrollSpeed,
            playerLineupScrollDirection: playerLineupScrollDirection,
            playerFoulHighlightColor: playerFoulHighlightColor,
            isGameClockRedEnabled: isGameClockRedEnabled,
            gameClockRedThresholdSeconds: gameClockRedThresholdSeconds,
            isShotClockRedEnabled: isShotClockRedEnabled,
            shotClockRedThresholdSeconds: shotClockRedThresholdSeconds,
            homeSubstitutionsAllowed: homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: guestSubstitutionsAllowed,
            homeSubstitutionsUsed: homeSubstitutionsUsed,
            guestSubstitutionsUsed: guestSubstitutionsUsed,
            homePausesAllowed: homePausesAllowed,
            guestPausesAllowed: guestPausesAllowed,
            homePausesUsed: homePausesUsed,
            guestPausesUsed: guestPausesUsed,
            homeTeamFouls: homeTeamFouls,
            guestTeamFouls: guestTeamFouls,
            homeChessClockSeconds: homeChessClockSeconds,
            guestChessClockSeconds: guestChessClockSeconds,
            activeChessClockSide: activeChessClockSide,
            chessClockPreset: chessClockPreset,
            selectedDebatePresetID: selectedDebatePresetID,
            debateHomeSideLabel: debateHomeSideLabel,
            debateGuestSideLabel: debateGuestSideLabel,
            debateCurrentSegmentIndex: debateCurrentSegmentIndex,
            debatePrepHomeSeconds: debatePrepHomeSeconds,
            debatePrepGuestSeconds: debatePrepGuestSeconds,
            isDebatePrepTimeEnabled: isDebatePrepTimeEnabled,
            debateActiveTimer: debateActiveTimer,
            isDebatePrepClockRunning: isDebatePrepClockRunning,
            isDebateScoreTrackingEnabled: isDebateScoreTrackingEnabled,
            isDebatePlayerTrackingEnabled: isDebatePlayerTrackingEnabled,
            isDebatePlayerFoulsEnabled: isDebatePlayerFoulsEnabled,
            isDebatePlayerCardsEnabled: isDebatePlayerCardsEnabled,
            homePenaltyTimers: supportsHockeyPenalties ? homePenaltyTimers : [],
            guestPenaltyTimers: supportsHockeyPenalties ? guestPenaltyTimers : [],
            homeRoster: homeRoster,
            guestRoster: guestRoster,
            externalDisplayBackgroundMode: externalDisplayBackgroundMode,
            externalDisplayBackgroundImage: embeddedExternalDisplayBackgroundImage(),
            externalDisplayAnimatedLogoStyle: externalDisplayAnimatedLogoStyle,
            externalDisplayAnimatedLogoBackgroundColor: externalDisplayAnimatedLogoBackgroundColor,
            externalDisplayAnimatedLogoSpeed: externalDisplayAnimatedLogoSpeed,
            externalDisplayAnimatedLogoSize: externalDisplayAnimatedLogoSize,
            externalDisplayAnimatedLogoOpacity: externalDisplayAnimatedLogoOpacity,
            showsExternalDisplayDateTime: showsExternalDisplayDateTime,
            externalDisplayDateTimeFormat: externalDisplayDateTimeFormat,
            showsExternalDisplayDateTimeSeconds: showsExternalDisplayDateTimeSeconds,
            showsTeamLogos: showsTeamLogos,
            showsEventLogo: showsEventLogo,
            playerViewRosterScope: .fullRoster,
            homeTeamLogoImage: embeddedTeamLogoImage(for: .home),
            guestTeamLogoImage: embeddedTeamLogoImage(for: .guest),
            eventLogoImage: embeddedEventLogoImage(),
            pauseDurationSeconds: pauseDurationSeconds,
            pauseTimer: pauseTimer,
            isTeamPauseIndefinite: isTeamPauseIndefinite
        )
    }

    private func embeddedExternalDisplayBackgroundImage() -> ScoreboardGameEmbeddedImage? {
        guard let externalDisplayBackgroundImage else {
            return nil
        }

        return ScoreboardGameEmbeddedImage(backgroundImage: externalDisplayBackgroundImage)
    }

    private func embeddedTeamLogoImage(for side: TeamSide) -> ScoreboardGameEmbeddedImage? {
        guard let logo = teamLogoImage(for: side) else {
            return nil
        }

        return ScoreboardGameEmbeddedImage(teamLogoImage: logo)
    }

    private func embeddedEventLogoImage() -> ScoreboardGameEmbeddedImage? {
        guard let eventLogoImage else {
            return nil
        }

        return ScoreboardGameEmbeddedImage(eventLogoImage: eventLogoImage)
    }

    func setExternalDisplayBackgroundImage(_ image: ExternalDisplayBackgroundImage) {
        externalDisplayBackgroundImage = image
        externalDisplayBackgroundMode = .image
    }

    func updateExternalDisplayBackgroundPlacement(scale: Double, offsetX: Double, offsetY: Double) {
        guard let image = externalDisplayBackgroundImage else {
            return
        }

        externalDisplayBackgroundImage = image.withPlacement(scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    func setExternalDisplayAnimatedLogoSpeed(_ value: Int) {
        externalDisplayAnimatedLogoSpeed = max(Self.minAnimatedLogoSpeed, min(Self.maxAnimatedLogoSpeed, value))
    }

    func setExternalDisplayAnimatedLogoSize(_ value: Int) {
        externalDisplayAnimatedLogoSize = max(Self.minAnimatedLogoSize, min(Self.maxAnimatedLogoSize, value))
    }

    func setExternalDisplayAnimatedLogoOpacity(_ value: Double) {
        externalDisplayAnimatedLogoOpacity = max(Self.minAnimatedLogoOpacity, min(Self.maxAnimatedLogoOpacity, value))
    }

    func clearExternalDisplayBackgroundImage() {
        externalDisplayBackgroundImage = nil
        if externalDisplayBackgroundMode == .image || externalDisplayBackgroundMode == .animatedLogo {
            externalDisplayBackgroundMode = .blurred
        }
    }

    func teamLogoImage(for side: TeamSide) -> TeamLogoImage? {
        switch side {
        case .home:
            return homeTeamLogoImage
        case .guest:
            return guestTeamLogoImage
        }
    }

    func setTeamLogoImage(_ image: TeamLogoImage, for side: TeamSide) {
        switch side {
        case .home:
            homeTeamLogoImage = image
        case .guest:
            guestTeamLogoImage = image
        }
    }

    func clearTeamLogoImage(for side: TeamSide) {
        switch side {
        case .home:
            homeTeamLogoImage = nil
        case .guest:
            guestTeamLogoImage = nil
        }
    }

    func setEventLogoImage(_ image: EventLogoImage) {
        eventLogoImage = image
    }

    func clearEventLogoImage() {
        eventLogoImage = nil
    }

    func applyGameSnapshot(_ snapshot: ScoreboardGameSnapshot) {
        if isFollowingSessionHost && !isApplyingSessionUpdate && !isApplyingRemoteControlState {
            sendOwnerGameSnapshot(snapshot)
            return
        }
        performWithoutAuditLogging {
            if !isRemoteControlProxy {
                pauseClock()
                pauseShotClock()
                clearQueuedEventActions()
            }

            let snapshotSport = snapshot.sport ?? .basketball
            customSportConfig = snapshot.customSportConfig ?? .default
            customDebatePreset = snapshot.customDebatePreset ?? .customDefault
            setSelectedSport(snapshotSport, applyDefaults: false)
            homeTeamName = normalizedTeamName(snapshot.homeTeamName)
            guestTeamName = normalizedTeamName(snapshot.guestTeamName)
            eventName = normalizedEventName(snapshot.eventName)
            homeScore = max(0, snapshot.homeScore)
            guestScore = max(0, snapshot.guestScore)
            period = max(1, min(9, snapshot.period))
            volleyballMatchFormat = selectedSport == .volleyball ? (snapshot.volleyballMatchFormat ?? .bestOf5) : .bestOf5
            if supportsPeriodWinTracking {
                volleyballSetResults = selectedSport == .volleyball
                    ? normalizedVolleyballSetResults(snapshot.volleyballSetResults ?? [], format: volleyballMatchFormat)
                    : normalizedPeriodWinResults(snapshot.volleyballSetResults ?? [], maximumPeriod: periodUpperBound)
            } else {
                volleyballSetResults = []
            }
            if supportsPeriodWinTracking {
                period = max(1, min(periodUpperBound, period))
            }
            gameClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(snapshot.gameClockSeconds) : boundedGameClockSeconds(snapshot.gameClockSeconds)
            defaultClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(snapshot.defaultClockSeconds) : boundedGameClockSeconds(snapshot.defaultClockSeconds)
            isGameClockEnabled = snapshot.isGameClockEnabled ?? true
            pendingInjuryTimeMinutes = boundedInjuryTimeMinutes(snapshot.pendingInjuryTimeMinutes ?? 0)
            activeInjuryTimeMinutes = boundedInjuryTimeMinutes(snapshot.activeInjuryTimeMinutes ?? 0)
            hasAppliedInjuryTimeThisPeriod = snapshot.hasAppliedInjuryTimeThisPeriod ?? (activeInjuryTimeMinutes > 0)
            normalizeInjuryTimeState()
            shotClockMilliseconds = boundedShotClockMilliseconds(snapshot.shotClockMilliseconds)
            defaultShotClockSeconds = boundedShotClockSeconds(snapshot.defaultShotClockSeconds)
            activeShotClockPresetSeconds = boundedShotClockSeconds(snapshot.activeShotClockPresetSeconds ?? snapshot.defaultShotClockSeconds)
            possessionDirection = supportsPossession ? snapshot.possessionDirection : .none
            isPlayerTrackingEnabled = currentRules.supportsPlayerTracking ? (snapshot.isPlayerTrackingEnabled ?? false) : false
            isPlayerOverlayPaused = snapshot.isPlayerOverlayPaused ?? false
            rosterSizePerTeam = max(Self.minRosterSize, min(Self.maxRosterSize, snapshot.rosterSizePerTeam ?? Self.defaultRosterSize))
            displayLineupSize = max(1, min(rosterSizePerTeam, snapshot.displayLineupSize ?? Self.defaultDisplayLineupSize))
            playerLineupOverflowMode = snapshot.playerLineupOverflowMode ?? .scroll
            playerLineupOverflowLogoOverride = snapshot.playerLineupOverflowLogoOverride
            playerLineupOverflowNoLogoOverride = snapshot.playerLineupOverflowNoLogoOverride
            playerLineupFadePageSeconds = max(Self.minPlayerLineupFadePageSeconds, min(Self.maxPlayerLineupFadePageSeconds, snapshot.playerLineupFadePageSeconds ?? Self.defaultPlayerLineupFadePageSeconds))
            playerLineupScrollSpeed = max(Self.minPlayerLineupScrollSpeed, min(Self.maxPlayerLineupScrollSpeed, snapshot.playerLineupScrollSpeed ?? Self.defaultPlayerLineupScrollSpeed))
            playerLineupScrollDirection = snapshot.playerLineupScrollDirection ?? .continuousUp
            playerFoulHighlightColor = snapshot.playerFoulHighlightColor ?? .yellow
            isGameClockRedEnabled = snapshot.isGameClockRedEnabled ?? false
            gameClockRedThresholdSeconds = boundedGameClockSeconds(snapshot.gameClockRedThresholdSeconds ?? 60)
            isShotClockRedEnabled = snapshot.isShotClockRedEnabled ?? false
            shotClockRedThresholdSeconds = boundedShotClockSeconds(snapshot.shotClockRedThresholdSeconds ?? 5)
            homeSubstitutionsAllowed = max(0, snapshot.homeSubstitutionsAllowed ?? currentRules.defaultSubstitutionLimit)
            guestSubstitutionsAllowed = max(0, snapshot.guestSubstitutionsAllowed ?? currentRules.defaultSubstitutionLimit)
            homeSubstitutionsUsed = max(0, min(homeSubstitutionsAllowed, snapshot.homeSubstitutionsUsed ?? 0))
            guestSubstitutionsUsed = max(0, min(guestSubstitutionsAllowed, snapshot.guestSubstitutionsUsed ?? 0))
            if isDebateMode {
                clearSubstitutionTracking()
            }
            pauseDurationSeconds = max(1, min(Self.maxGameClockSeconds, snapshot.pauseDurationSeconds ?? (selectedSport == .volleyball ? 30 : 60)))
            isTeamPauseIndefinite = snapshot.isTeamPauseIndefinite ?? false
            pauseTimer = normalizedPauseTimer(snapshot.pauseTimer, preserveRunning: isApplyingRemoteControlState || isApplyingSessionUpdate)
            accumulatedPauseElapsed = 0
            homePausesAllowed = max(0, snapshot.homePausesAllowed ?? currentRules.defaultPauseLimit)
            guestPausesAllowed = max(0, snapshot.guestPausesAllowed ?? currentRules.defaultPauseLimit)
            homePausesUsed = max(0, min(homePausesAllowed, snapshot.homePausesUsed ?? 0))
            guestPausesUsed = max(0, min(guestPausesAllowed, snapshot.guestPausesUsed ?? 0))
            if !currentRules.showsPauseTracking {
                clearPauseTracking()
            }
            homeTeamFouls = max(0, snapshot.homeTeamFouls ?? 0)
            guestTeamFouls = max(0, snapshot.guestTeamFouls ?? 0)
            let defaultDualClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(snapshot.defaultClockSeconds) : boundedGameClockSeconds(snapshot.defaultClockSeconds)
            homeChessClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(snapshot.homeChessClockSeconds ?? defaultDualClockSeconds) : boundedGameClockSeconds(snapshot.homeChessClockSeconds ?? defaultDualClockSeconds)
            guestChessClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(snapshot.guestChessClockSeconds ?? defaultDualClockSeconds) : boundedGameClockSeconds(snapshot.guestChessClockSeconds ?? defaultDualClockSeconds)
            activeChessClockSide = snapshot.activeChessClockSide ?? .home
            chessClockPreset = snapshot.chessClockPreset ?? .rapid
            selectedDebatePresetID = snapshot.selectedDebatePresetID ?? DebatePreset.publicForum.id
            let debatePreset = selectedDebatePresetID == DebatePreset.customID ? customDebatePreset : DebatePreset.preset(id: selectedDebatePresetID)
            debateHomeSideLabel = snapshot.debateHomeSideLabel ?? debatePreset.homeSideLabel
            debateGuestSideLabel = snapshot.debateGuestSideLabel ?? debatePreset.guestSideLabel
            debateCurrentSegmentIndex = max(0, snapshot.debateCurrentSegmentIndex ?? 0)
            isDebatePrepTimeEnabled = snapshot.isDebatePrepTimeEnabled ?? debatePreset.isPrepTimeEnabled
            debatePrepHomeSeconds = isDebatePrepTimeEnabled ? boundedGameClockSeconds(snapshot.debatePrepHomeSeconds ?? debatePreset.prepSecondsPerSide) : 0
            debatePrepGuestSeconds = isDebatePrepTimeEnabled ? boundedGameClockSeconds(snapshot.debatePrepGuestSeconds ?? debatePreset.prepSecondsPerSide) : 0
            debateActiveTimer = snapshot.debateActiveTimer ?? .segment
            isDebatePrepClockRunning = snapshot.isDebatePrepClockRunning ?? false
            isDebateScoreTrackingEnabled = snapshot.isDebateScoreTrackingEnabled ?? debatePreset.defaultScoreTrackingEnabled
            isDebatePlayerTrackingEnabled = snapshot.isDebatePlayerTrackingEnabled ?? debatePreset.defaultPlayerTrackingEnabled
            isDebatePlayerFoulsEnabled = snapshot.isDebatePlayerFoulsEnabled ?? debatePreset.defaultPlayerFoulsEnabled
            isDebatePlayerCardsEnabled = snapshot.isDebatePlayerCardsEnabled ?? debatePreset.defaultPlayerCardsEnabled
            homePenaltyTimers = supportsHockeyPenalties ? (snapshot.homePenaltyTimers ?? []) : []
            guestPenaltyTimers = supportsHockeyPenalties ? (snapshot.guestPenaltyTimers ?? []) : []
            homeRoster = normalizedRoster(snapshot.homeRoster, fallbackCount: rosterSizePerTeam)
            guestRoster = normalizedRoster(snapshot.guestRoster, fallbackCount: rosterSizePerTeam)
            externalDisplayAnimatedLogoStyle = snapshot.externalDisplayAnimatedLogoStyle ?? .horizontalMarquee
            externalDisplayAnimatedLogoBackgroundColor = snapshot.externalDisplayAnimatedLogoBackgroundColor ?? .themeBackground
            setExternalDisplayAnimatedLogoSpeed(snapshot.externalDisplayAnimatedLogoSpeed ?? Self.defaultAnimatedLogoSpeed)
            setExternalDisplayAnimatedLogoSize(snapshot.externalDisplayAnimatedLogoSize ?? Self.defaultAnimatedLogoSize)
            setExternalDisplayAnimatedLogoOpacity(snapshot.externalDisplayAnimatedLogoOpacity ?? Self.defaultAnimatedLogoOpacity)
            showsExternalDisplayDateTime = snapshot.showsExternalDisplayDateTime ?? false
            externalDisplayDateTimeFormat = snapshot.externalDisplayDateTimeFormat ?? .time24Hour
            showsExternalDisplayDateTimeSeconds = snapshot.showsExternalDisplayDateTimeSeconds ?? true
            showsTeamLogos = snapshot.showsTeamLogos ?? true
            showsEventLogo = snapshot.showsEventLogo ?? true
            playerViewRosterScope = .fullRoster
            restoreDisplayImages(from: snapshot)
            if isDebateMode {
                let preset = currentDebatePreset
                debateCurrentSegmentIndex = min(debateCurrentSegmentIndex, max(preset.segments.count - 1, 0))
                configureDebateSegment(index: debateCurrentSegmentIndex, preserveRunningState: true)
                switch currentDebateSegment?.timerMode {
                case .masterClock:
                    gameClockSeconds = boundedDebateSegmentSeconds(snapshot.gameClockSeconds)
                case .dualClock:
                    homeChessClockSeconds = boundedDebateSegmentSeconds(snapshot.homeChessClockSeconds ?? defaultDualClockSeconds)
                    guestChessClockSeconds = boundedDebateSegmentSeconds(snapshot.guestChessClockSeconds ?? defaultDualClockSeconds)
                case .some(.none), nil:
                    gameClockSeconds = 0
                }
                if let restoredActiveSide = snapshot.activeChessClockSide, currentDebateSegment?.timerMode == .dualClock {
                    activeChessClockSide = restoredActiveSide
                }
                if let restoredTimerMode = snapshot.debateActiveTimer {
                    debateActiveTimer = restoredTimerMode
                }
                isPlayerTrackingEnabled = isDebatePlayerTrackingEnabled && (snapshot.isPlayerTrackingEnabled ?? true)
            }
            if !supportsShotClock {
                defaultShotClockSeconds = 0
                activeShotClockPresetSeconds = 0
                shotClockMilliseconds = 0
            }
            if !showsGameClock {
                pauseClock()
            }
            if pauseTimer != nil {
                isClockRunning = false
                isShotClockRunning = false
                isDebatePrepClockRunning = false
                for side in TeamSide.allCases {
                    updatePenaltyTimers(for: side) { timers in
                        for index in timers.indices { timers[index].isRunning = false }
                    }
                }
            }
            updateTimerState()
            normalizeInjuryTimeState()
            didCompleteSetup = true
        }
    }

    private func restoreDisplayImages(from snapshot: ScoreboardGameSnapshot) {
        externalDisplayBackgroundImage = snapshot.externalDisplayBackgroundImage.flatMap(ExternalDisplayBackgroundImage.init(embeddedImage:))
        homeTeamLogoImage = snapshot.homeTeamLogoImage.flatMap(TeamLogoImage.init(embeddedImage:))
        guestTeamLogoImage = snapshot.guestTeamLogoImage.flatMap(TeamLogoImage.init(embeddedImage:))
        eventLogoImage = snapshot.eventLogoImage.flatMap(EventLogoImage.init(embeddedImage:))

        let restoredBackgroundMode = snapshot.externalDisplayBackgroundMode ?? .blurred
        if (restoredBackgroundMode == .image || restoredBackgroundMode == .animatedLogo), externalDisplayBackgroundImage == nil {
            externalDisplayBackgroundMode = .blurred
        } else {
            externalDisplayBackgroundMode = restoredBackgroundMode
        }
    }

    func applySetup(
        sport: SportType,
        homeName: String,
        guestName: String,
        period: Int,
        clockSeconds: Int,
        isGameClockEnabled: Bool = true,
        shotClockSeconds: Int,
        customSportConfig: CustomSportConfig? = nil
    ) {
        performWithoutAuditLogging {
            if let customSportConfig {
                self.customSportConfig = customSportConfig
            }
            setSelectedSport(sport, applyDefaults: true)
            updateTeamName(homeName, isHome: true)
            updateTeamName(guestName, isHome: false)
            homeScore = 0
            guestScore = 0
            setPeriod(period)
            defaultClockSeconds = boundedGameClockSeconds(clockSeconds)
            setGameClockEnabled(isGameClockEnabled)
            defaultShotClockSeconds = currentRules.supportsShotClock ? boundedShotClockSeconds(shotClockSeconds) : 0
            activeShotClockPresetSeconds = defaultShotClockSeconds
            possessionDirection = .none
            isPlayerOverlayPaused = false
            resetPlayerTrackingForNewGame()
            didCompleteSetup = true
            resetClock(to: defaultClockSeconds)
            resetShotClock(to: defaultShotClockSeconds)
        }
    }

    func savePreset(
        named name: String,
        sport: SportType,
        homeName: String,
        guestName: String,
        period: Int,
        clockSeconds: Int,
        shotClockSeconds: Int,
        possessionDirection: PossessionDirection
    ) {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedName.isEmpty else {
            return
        }

        let preset = SetupPreset(
            id: existingPresetID(named: resolvedName) ?? UUID(),
            name: resolvedName,
            sport: sport,
            homeTeamName: normalizedTeamName(homeName),
            guestTeamName: normalizedTeamName(guestName),
            period: max(1, min(9, period)),
            clockSeconds: boundedGameClockSeconds(clockSeconds),
            shotClockSeconds: boundedShotClockSeconds(shotClockSeconds),
            possessionDirection: possessionDirection
        )

        setupPresets.removeAll {
            $0.id == preset.id ||
            $0.name.caseInsensitiveCompare(resolvedName) == .orderedSame
        }
        setupPresets.insert(preset, at: 0)
    }

    func deletePreset(_ preset: SetupPreset) {
        setupPresets.removeAll { $0.id == preset.id }
    }

    private func startClock() {
        guard pauseTimer == nil else { return }
        if usesChessClocks {
            guard activeChessClockSide != nil else {
                activeChessClockSide = .home
                return
            }
            guard (homeChessClockSeconds > 0 || guestChessClockSeconds > 0) else {
                return
            }
            isClockRunning = true
            updateTimerState()
            refreshPrimaryTimerPersistence()
            return
        }

        guard showsGameClock else {
            return
        }

        if gameClockMode == .countdown && gameClockSeconds == 0 {
            if hasAppliedInjuryTimeThisPeriod && activeInjuryTimeMinutes > 0 {
                return
            }
            resetInjuryTimeForPeriod()
            gameClockSeconds = defaultClockSeconds
        }

        if gameClockMode == .countdown {
            guard gameClockSeconds > 0 else {
                return
            }
        } else {
            guard gameClockSeconds < Self.maxGameClockSeconds else {
                return
            }
        }

        isClockRunning = true
        updateTimerState()
        refreshPrimaryTimerPersistence()
    }

    private func pauseClock() {
        if isClockRunning, !isAuditLoggingSuspended {
            reconcileRunningTimersWithWallClock()
        }
        isClockRunning = false
        updateTimerState()
        refreshPrimaryTimerPersistence()
    }

    private func startShotClock() {
        guard pauseTimer == nil else { return }
        guard supportsShotClock else {
            return
        }

        if shotClockMilliseconds == 0 {
            shotClockMilliseconds = defaultShotClockSeconds * 1_000
        }

        guard shotClockMilliseconds > 0 else {
            return
        }

        isShotClockRunning = true
        updateTimerState()
    }

    private func pauseShotClock() {
        if isShotClockRunning, !isAuditLoggingSuspended {
            reconcileRunningTimersWithWallClock()
        }
        isShotClockRunning = false
        updateTimerState()
    }

    private func resetServeTimer(for side: TeamSide) {
        guard usesServeTimer, supportsShotClock else {
            return
        }

        if isShotClockRunning {
            pauseShotClock()
        } else {
            isShotClockRunning = false
            updateTimerState()
        }

        possessionDirection = side == .home ? .home : .guest
        activeShotClockPresetSeconds = defaultShotClockSeconds
        shotClockMilliseconds = defaultShotClockSeconds * 1_000
        requestShotClockAutosave()
    }

    private func requestGameClockAutosave() {
        gameClockAutosaveRevision &+= 1
    }

    private func requestShotClockAutosave() {
        shotClockAutosaveRevision &+= 1
    }

    private func updateTimerState() {
        guard isSessionAuthority else {
            timer?.invalidate(); timer = nil; lastTimerFireDate = nil
            return
        }
        let hasRunningPenalty = homePenaltyTimers.contains(where: \.isRunning) || guestPenaltyTimers.contains(where: \.isRunning)
        guard isClockRunning || isShotClockRunning || hasRunningPenalty || isDebatePrepClockRunning || pauseTimer?.isRunning == true else {
            timer?.invalidate()
            timer = nil
            lastTimerFireDate = nil
            accumulatedGameClockElapsed = 0
            accumulatedShotClockElapsed = 0
            accumulatedPenaltyElapsed = 0
            accumulatedDebatePrepElapsed = 0
            return
        }

        #if !SCOREBOARD_TESTING
        // Unit tests retain the reset logic above and advance tick explicitly.
        guard timer == nil else {
            return
        }

        lastTimerFireDate = Date()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.reconcileRunningTimersWithWallClock()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        #endif
    }

    func reconcileRunningTimersWithWallClock() {
        reconcileRunningTimersWithWallClock(now: Date())
    }

    private func reconcileRunningTimersWithWallClock(now: Date) {
        guard isSessionAuthority else { return }
        guard !isReconcilingTimersFromWallClock else {
            return
        }

        let hasRunningPenalty = homePenaltyTimers.contains(where: \.isRunning) || guestPenaltyTimers.contains(where: \.isRunning)
        guard isClockRunning || isShotClockRunning || hasRunningPenalty || isDebatePrepClockRunning || pauseTimer?.isRunning == true else {
            lastTimerFireDate = nil
            return
        }

        guard let lastTimerFireDate else {
            self.lastTimerFireDate = now
            return
        }

        let elapsed = now.timeIntervalSince(lastTimerFireDate)
        guard elapsed > 0 else {
            return
        }

        self.lastTimerFireDate = now
        isReconcilingTimersFromWallClock = true
        tick(elapsed: elapsed)
        isReconcilingTimersFromWallClock = false
        refreshPrimaryTimerPersistence()
    }

    private func tick(elapsed: TimeInterval) {
        var soundEvents: [ScoreboardSoundEvent] = []
        var clockEventDispatches: [ScoreboardEventDispatch] = []

        if isClockRunning {
            accumulatedGameClockElapsed += elapsed
            let elapsedWholeSeconds = Int(accumulatedGameClockElapsed)

            if elapsedWholeSeconds > 0 {
                accumulatedGameClockElapsed -= TimeInterval(elapsedWholeSeconds)
                if usesChessClocks {
                    switch activeChessClockSide {
                    case .home:
                        homeChessClockSeconds = max(0, homeChessClockSeconds - elapsedWholeSeconds)
                        if homeChessClockSeconds == 0 {
                            let fallbackEvent: ScoreboardSoundEvent = isDebateMode ? .debateSegmentExpired : .chessClockExpired
                            isClockRunning = false
                            accumulatedGameClockElapsed = 0
                            clockEventDispatches.append(eventDispatch(sideClockExpiredEvent(for: .home), fallbackEvent: fallbackEvent))
                            soundEvents.append(fallbackEvent)
                            requestGameClockAutosave()
                        }
                    case .guest:
                        guestChessClockSeconds = max(0, guestChessClockSeconds - elapsedWholeSeconds)
                        if guestChessClockSeconds == 0 {
                            let fallbackEvent: ScoreboardSoundEvent = isDebateMode ? .debateSegmentExpired : .chessClockExpired
                            isClockRunning = false
                            accumulatedGameClockElapsed = 0
                            clockEventDispatches.append(eventDispatch(sideClockExpiredEvent(for: .guest), fallbackEvent: fallbackEvent))
                            soundEvents.append(fallbackEvent)
                            requestGameClockAutosave()
                        }
                    case .none:
                        isClockRunning = false
                        requestGameClockAutosave()
                    }
                } else {
                    switch gameClockMode {
                    case .countdown:
                        advanceCountdownGameClock(
                            by: elapsedWholeSeconds,
                            soundEvents: &soundEvents,
                            clockEventDispatches: &clockEventDispatches
                        )
                    case .countUp:
                        gameClockSeconds = min(Self.maxGameClockSeconds, gameClockSeconds + elapsedWholeSeconds)

                        if gameClockSeconds == Self.maxGameClockSeconds {
                            isClockRunning = false
                            accumulatedGameClockElapsed = 0
                            requestGameClockAutosave()
                        }
                    }
                }
            }
        }

        if isShotClockRunning {
            guard supportsShotClock else {
                isShotClockRunning = false
                accumulatedShotClockElapsed = 0
                updateTimerState()
                return
            }

            accumulatedShotClockElapsed += elapsed
            let elapsedMilliseconds = Int(accumulatedShotClockElapsed * 1_000)

            if elapsedMilliseconds > 0 {
                accumulatedShotClockElapsed -= TimeInterval(elapsedMilliseconds) / 1_000
                shotClockMilliseconds = max(0, shotClockMilliseconds - elapsedMilliseconds)

                if shotClockMilliseconds == 0 {
                    isShotClockRunning = false
                    accumulatedShotClockElapsed = 0
                    soundEvents.append(.shotClockExpired)
                    recordLog(
                        kind: .shotClockExpired,
                        summary: localizedStoreString("Shot clock expired"),
                        outcome: .applied,
                        value: 0
                    )
                    requestShotClockAutosave()
                }
            }
        }

        let hasRunningPenalty = homePenaltyTimers.contains(where: \.isRunning) || guestPenaltyTimers.contains(where: \.isRunning)
        if hasRunningPenalty {
            accumulatedPenaltyElapsed += elapsed
            let elapsedPenaltySeconds = Int(accumulatedPenaltyElapsed)
            if elapsedPenaltySeconds > 0 {
                accumulatedPenaltyElapsed -= TimeInterval(elapsedPenaltySeconds)
                for side in TeamSide.allCases {
                    updatePenaltyTimers(for: side) { timers in
                        for index in timers.indices where timers[index].isRunning {
                            timers[index].remainingSeconds = max(0, timers[index].remainingSeconds - elapsedPenaltySeconds)
                            if timers[index].remainingSeconds == 0 {
                                timers[index].isRunning = false
                                soundEvents.append(.hockeyPenaltyExpired)
                            }
                        }
                    }
                }
            }
        }

        if isDebatePrepClockRunning {
            accumulatedDebatePrepElapsed += elapsed
            let elapsedPrepSeconds = Int(accumulatedDebatePrepElapsed)
            if elapsedPrepSeconds > 0 {
                accumulatedDebatePrepElapsed -= TimeInterval(elapsedPrepSeconds)
                switch debateActiveTimer {
                case .prepHome:
                    debatePrepHomeSeconds = max(0, debatePrepHomeSeconds - elapsedPrepSeconds)
                    if debatePrepHomeSeconds == 0 {
                        isDebatePrepClockRunning = false
                        clockEventDispatches.append(prepClockExpiredDispatch(for: .home))
                        soundEvents.append(.debatePrepExpired)
                    }
                case .prepGuest:
                    debatePrepGuestSeconds = max(0, debatePrepGuestSeconds - elapsedPrepSeconds)
                    if debatePrepGuestSeconds == 0 {
                        isDebatePrepClockRunning = false
                        clockEventDispatches.append(prepClockExpiredDispatch(for: .guest))
                        soundEvents.append(.debatePrepExpired)
                    }
                case .segment:
                    isDebatePrepClockRunning = false
                }
            }
        }

        if var pause = pauseTimer, pause.isRunning, let remaining = pause.remainingSeconds {
            accumulatedPauseElapsed += elapsed
            let wholeSeconds = Int(accumulatedPauseElapsed)
            if wholeSeconds > 0 {
                accumulatedPauseElapsed -= Double(wholeSeconds)
                pause.remainingSeconds = max(0, remaining - wholeSeconds)
                if pause.remainingSeconds == 0 {
                    pause.isRunning = false
                    accumulatedPauseElapsed = 0
                    recordLog(kind: .pauseTimerChange, summary: localizedStoreString("Pause Timer Expired"), outcome: .applied, teamSide: pause.side, value: 0)
                    soundEvents.append(.pauseExpired)
                }
                pauseTimer = pause
            }
        }

        updateTimerState()

        let representedFallbacks = Set(clockEventDispatches.compactMap(\.fallbackEvent))
        let remainingDispatches = soundEvents
            .filter { !representedFallbacks.contains($0) }
            .map { eventDispatch($0) }
        handleScoreboardEventDispatches(clockEventDispatches + remainingDispatches)
    }

    deinit {
        remoteProjectionTimer?.invalidate()
        timer?.invalidate()
    }

    private func resetInjuryTimeForPeriod() {
        pendingInjuryTimeMinutes = 0
        activeInjuryTimeMinutes = 0
        hasAppliedInjuryTimeThisPeriod = false
    }

    private func resetClockForPeriodTransition(direction: Int) {
        resetInjuryTimeForPeriod()

        guard direction > 0, showsGameClock, !usesChessClocks else { return }

        pauseClock()
        gameClockSeconds = boundedGameClockSeconds(defaultClockSeconds)
        requestGameClockAutosave()
    }

    private func normalizeInjuryTimeState() {
        pendingInjuryTimeMinutes = boundedInjuryTimeMinutes(pendingInjuryTimeMinutes)
        activeInjuryTimeMinutes = boundedInjuryTimeMinutes(activeInjuryTimeMinutes)
        if !supportsInjuryTime {
            resetInjuryTimeForPeriod()
        } else if !hasAppliedInjuryTimeThisPeriod {
            activeInjuryTimeMinutes = 0
        }
    }

    private func normalizedTeamName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func normalizedEventName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedPlayerName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func normalizedPlayerNumber(_ number: String) -> String {
        number.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func boundedGameClockSeconds(_ value: Int) -> Int {
        max(0, min(Self.maxGameClockSeconds, value))
    }

    private func boundedInjuryTimeMinutes(_ value: Int) -> Int {
        max(0, min(Self.maxInjuryTimeMinutes, value))
    }

    private func boundedDebateSegmentSeconds(_ value: Int) -> Int {
        max(0, min(Self.maxDebateSegmentSeconds, value))
    }

    private func boundedRuntimeClockSeconds(_ value: Int) -> Int {
        isDebateMode ? boundedDebateSegmentSeconds(value) : boundedGameClockSeconds(value)
    }

    private func boundedShotClockSeconds(_ value: Int) -> Int {
        max(0, min(Self.maxShotClockSeconds, value))
    }

    private func boundedShotClockMilliseconds(_ value: Int) -> Int {
        max(0, min(Self.maxShotClockMilliseconds, value))
    }

    private func existingPresetID(named name: String) -> UUID? {
        setupPresets.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }?.id
    }

    private func penaltyTimers(for side: TeamSide) -> [HockeyPenaltyTimer] {
        switch side {
        case .home:
            return homePenaltyTimers
        case .guest:
            return guestPenaltyTimers
        }
    }

    private func advanceCountdownGameClock(
        by elapsedWholeSeconds: Int,
        soundEvents: inout [ScoreboardSoundEvent],
        clockEventDispatches: inout [ScoreboardEventDispatch]
    ) {
        guard elapsedWholeSeconds > 0 else {
            return
        }

        normalizeInjuryTimeState()
        if supportsInjuryTime,
           !hasAppliedInjuryTimeThisPeriod,
           pendingInjuryTimeMinutes > 0,
           elapsedWholeSeconds >= gameClockSeconds {
            let overflowSeconds = max(0, elapsedWholeSeconds - gameClockSeconds)
            hasAppliedInjuryTimeThisPeriod = true
            activeInjuryTimeMinutes = pendingInjuryTimeMinutes
            gameClockSeconds = max(0, (activeInjuryTimeMinutes * 60) - overflowSeconds)

            if gameClockSeconds == 0 {
                expireCountdownGameClock(soundEvents: &soundEvents, clockEventDispatches: &clockEventDispatches)
            } else {
                requestGameClockAutosave()
            }
            return
        }

        gameClockSeconds = max(0, gameClockSeconds - elapsedWholeSeconds)
        if gameClockSeconds == 0 {
            expireCountdownGameClock(soundEvents: &soundEvents, clockEventDispatches: &clockEventDispatches)
        }
    }

    private func expireCountdownGameClock(
        soundEvents: inout [ScoreboardSoundEvent],
        clockEventDispatches: inout [ScoreboardEventDispatch]
    ) {
        let fallbackEvent: ScoreboardSoundEvent = isDebateMode ? .debateSegmentExpired : .gameClockExpired
        isClockRunning = false
        accumulatedGameClockElapsed = 0
        if isDebateMode, debateActiveTimer == .segment, let speakingSide = currentDebateSegment?.speakingSide {
            clockEventDispatches.append(eventDispatch(sideClockExpiredEvent(for: speakingSide), fallbackEvent: fallbackEvent))
        } else if isDebateMode, debateActiveTimer == .segment {
            clockEventDispatches.append(eventDispatch(debateUnassignedClockExpiredEvent(), fallbackEvent: fallbackEvent))
        }
        soundEvents.append(fallbackEvent)
        recordLog(
            kind: .clockExpired,
            summary: localizedStoreString("Game clock expired"),
            outcome: .applied,
            value: gameClockSeconds
        )
        requestGameClockAutosave()
    }

    private func updatePenaltyTimers(for side: TeamSide, mutate: (inout [HockeyPenaltyTimer]) -> Void) {
        switch side {
        case .home:
            var timers = homePenaltyTimers
            mutate(&timers)
            homePenaltyTimers = timers
        case .guest:
            var timers = guestPenaltyTimers
            mutate(&timers)
            guestPenaltyTimers = timers
        }
    }

    private func penaltyTimer(for side: TeamSide, timerID: UUID) -> HockeyPenaltyTimer? {
        penaltyTimers(for: side).first { $0.id == timerID }
    }

    private func penaltySummaryItem(_ timer: HockeyPenaltyTimer?) -> String {
        guard let timer else {
            return ""
        }

        let playerBits = [timer.playerNumber, timer.playerName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let playerText = playerBits.isEmpty ? "OPEN" : playerBits
        return "\(playerText) \(Self.formatGameClock(timer.remainingSeconds)) \(timer.isRunning ? "RUN" : "STOP")"
    }

    private typealias ScoreboardEventDispatch = (event: ScoreboardSoundEvent, fallbackEvent: ScoreboardSoundEvent?)

    private func eventDispatch(
        _ event: ScoreboardSoundEvent,
        fallbackEvent: ScoreboardSoundEvent? = nil
    ) -> ScoreboardEventDispatch {
        (event: event, fallbackEvent: fallbackEvent)
    }

    private func sideClockStartedEvent(for side: TeamSide) -> ScoreboardSoundEvent {
        side == .home ? .homeSideClockStarted : .guestSideClockStarted
    }

    private func sideClockStoppedEvent(for side: TeamSide) -> ScoreboardSoundEvent {
        side == .home ? .homeSideClockStopped : .guestSideClockStopped
    }

    private func sideClockExpiredEvent(for side: TeamSide) -> ScoreboardSoundEvent {
        side == .home ? .homeSideClockExpired : .guestSideClockExpired
    }

    private func debateUnassignedClockStartedEvent() -> ScoreboardSoundEvent {
        .debateUnassignedSegmentStarted
    }

    private func debateUnassignedClockStoppedEvent() -> ScoreboardSoundEvent {
        .debateUnassignedSegmentStopped
    }

    private func debateUnassignedClockExpiredEvent() -> ScoreboardSoundEvent {
        .debateUnassignedSegmentExpired
    }

    private func prepClockStartedEvent(for side: TeamSide) -> ScoreboardSoundEvent {
        side == .home ? .homePrepClockStarted : .guestPrepClockStarted
    }

    private func prepClockStoppedEvent(for side: TeamSide) -> ScoreboardSoundEvent {
        side == .home ? .homePrepClockStopped : .guestPrepClockStopped
    }

    private func prepClockExpiredEvent(for side: TeamSide) -> ScoreboardSoundEvent {
        side == .home ? .homePrepClockExpired : .guestPrepClockExpired
    }

    private var clockStartedFallbackEvent: ScoreboardSoundEvent {
        isDebateMode ? .debateSegmentStarted : .gameClockStarted
    }

    private var clockStoppedFallbackEvent: ScoreboardSoundEvent {
        isDebateMode ? .debateSegmentStopped : .gameClockPaused
    }

    private func currentClockStartedDispatch(fallbackEvent: ScoreboardSoundEvent? = nil) -> ScoreboardEventDispatch {
        let resolvedFallbackEvent = fallbackEvent ?? clockStartedFallbackEvent
        if isDebateMode, debateActiveTimer == .segment {
            if let event = currentSideClockStartedEvent() {
                return eventDispatch(event, fallbackEvent: resolvedFallbackEvent)
            }
            return eventDispatch(debateUnassignedClockStartedEvent(), fallbackEvent: resolvedFallbackEvent)
        }

        if let event = currentSideClockStartedEvent() {
            return eventDispatch(event, fallbackEvent: resolvedFallbackEvent)
        }
        return eventDispatch(resolvedFallbackEvent)
    }

    private func currentClockStoppedDispatch(fallbackEvent: ScoreboardSoundEvent? = nil) -> ScoreboardEventDispatch {
        let resolvedFallbackEvent = fallbackEvent ?? clockStoppedFallbackEvent
        if isDebateMode, debateActiveTimer == .segment {
            if let event = currentSideClockStoppedEvent() {
                return eventDispatch(event, fallbackEvent: resolvedFallbackEvent)
            }
            return eventDispatch(debateUnassignedClockStoppedEvent(), fallbackEvent: resolvedFallbackEvent)
        }

        if let event = currentSideClockStoppedEvent() {
            return eventDispatch(event, fallbackEvent: resolvedFallbackEvent)
        }
        return eventDispatch(resolvedFallbackEvent)
    }

    private func prepClockStartedDispatch(for side: TeamSide) -> ScoreboardEventDispatch {
        eventDispatch(prepClockStartedEvent(for: side), fallbackEvent: .debatePrepStarted)
    }

    private func prepClockStoppedDispatch(for side: TeamSide) -> ScoreboardEventDispatch {
        eventDispatch(prepClockStoppedEvent(for: side), fallbackEvent: .debatePrepStopped)
    }

    private func prepClockExpiredDispatch(for side: TeamSide) -> ScoreboardEventDispatch {
        eventDispatch(prepClockExpiredEvent(for: side), fallbackEvent: .debatePrepExpired)
    }

    private func currentSideClockStartedEvent() -> ScoreboardSoundEvent? {
        if usesChessClocks, let activeChessClockSide {
            return sideClockStartedEvent(for: activeChessClockSide)
        }

        if isDebateMode, debateActiveTimer == .segment, let speakingSide = currentDebateSegment?.speakingSide {
            return sideClockStartedEvent(for: speakingSide)
        }

        return nil
    }

    private func currentSideClockStoppedEvent() -> ScoreboardSoundEvent? {
        if usesChessClocks, let activeChessClockSide {
            return sideClockStoppedEvent(for: activeChessClockSide)
        }

        if isDebateMode, debateActiveTimer == .segment, let speakingSide = currentDebateSegment?.speakingSide {
            return sideClockStoppedEvent(for: speakingSide)
        }

        return nil
    }

    private func currentRunningClockStoppedDispatch() -> ScoreboardEventDispatch? {
        if isDebatePrepClockRunning {
            switch debateActiveTimer {
            case .prepHome:
                return prepClockStoppedDispatch(for: .home)
            case .prepGuest:
                return prepClockStoppedDispatch(for: .guest)
            case .segment:
                return nil
            }
        }

        guard isClockRunning else {
            return nil
        }

        return currentClockStoppedDispatch()
    }

    private func handleScoreboardEvent(_ event: ScoreboardSoundEvent) {
        handleScoreboardEvents([event])
    }

    private func handleScoreboardEvent(_ event: ScoreboardSoundEvent, fallbackEvent: ScoreboardSoundEvent) {
        handleScoreboardEvents([event], fallbackEvent: fallbackEvent)
    }

    private func handleScoreboardEvents(_ events: [ScoreboardSoundEvent], fallbackEvent: ScoreboardSoundEvent? = nil) {
        let resolvedEvents = uniqueSoundEvents(events)
        let dispatches = resolvedEvents.map { eventDispatch($0, fallbackEvent: fallbackEvent) }
        handleScoreboardEventDispatches(dispatches)
    }

    private func handleScoreboardEventDispatches(_ dispatches: [ScoreboardEventDispatch]) {
        guard !isRemoteControlProxy else { return }
        guard !dispatches.isEmpty else { return }
        let expanded = dispatches + timerOutcomeDispatches(for: dispatches)
        let order = Dictionary(uniqueKeysWithValues: ScoreboardSoundEvent.executionOrder.enumerated().map { ($0.element, $0.offset) })
        let ordered = uniqueScoreboardEventDispatches(expanded).sorted {
            order[$0.event, default: 0] < order[$1.event, default: 0]
        }
        var soundedEvents = Set<ScoreboardSoundEvent>()
        var commandedEvents = Set<ScoreboardSoundEvent>()
        for dispatch in ordered {
            let soundEvent = selectedSoundEffect(for: dispatch.event) != .none
                ? dispatch.event : dispatch.fallbackEvent
            let effect: ScoreboardSoundEffect
            if !isSoundEventBypassed(dispatch.event, sport: selectedSport),
               let soundEvent, !isSoundEventBypassed(soundEvent, sport: selectedSport),
               soundedEvents.insert(soundEvent).inserted {
                effect = isSoundEnabled ? selectedSoundEffect(for: soundEvent) : .none
            } else {
                effect = .none
            }
            let commandEvent = companionLocation(for: dispatch.event) != nil
                ? dispatch.event : dispatch.fallbackEvent
            var location: ScoreboardCompanionLocation?
            if isCompanionVisible, isCompanionEnabled,
               !isCompanionEventBypassed(dispatch.event, sport: selectedSport),
               let commandEvent, !isCompanionEventBypassed(commandEvent, sport: selectedSport),
               commandedEvents.insert(commandEvent).inserted {
                location = companionLocation(for: commandEvent)
            }
            if !companionSyncWithSound, let immediateLocation = location {
                sendCompanionPress(immediateLocation,
                                   events: [dispatch.event] + [commandEvent].compactMap { $0 },
                                   sport: selectedSport)
                location = nil
            }
            if effect != .none || location != nil {
                queuedEventActions.append(QueuedEventAction(
                    effect: effect, triggerEvent: dispatch.event,
                    soundEvent: soundEvent, companionEvent: commandEvent,
                    sport: selectedSport, companionLocation: location,
                    companionGeneration: companionCommandGeneration
                ))
            }
        }
        playNextEventAction()
    }

    private func timerOutcomeDispatches(for dispatches: [ScoreboardEventDispatch]) -> [ScoreboardEventDispatch] {
        let events = Set(dispatches.flatMap { [$0.event] + [$0.fallbackEvent].compactMap { $0 } })
        let expired = !events.isDisjoint(with: [
            .gameClockExpired, .chessClockExpired, .debateSegmentExpired,
            .homeSideClockExpired, .guestSideClockExpired, .debateUnassignedSegmentExpired
        ])
        let hasTimeRemaining = usesChessClocks
            ? (activeChessClockSide == .home ? homeChessClockSeconds : guestChessClockSeconds) > 0
            : gameClockMode == .countUp || gameClockSeconds > 0
        let paused = !expired && hasTimeRemaining && !events.isDisjoint(with: [
            .gameClockPaused, .debateSegmentStopped, .homeSideClockStopped,
            .guestSideClockStopped, .debateUnassignedSegmentStopped
        ])
        var outcomes: [ScoreboardSoundEvent] = []
        if expired {
            outcomes.append(.timerExpired)
            if supportsScore {
                if homeScore > guestScore {
                    outcomes += [.timerExpiredHomeAhead, .timerExpiredGuestBehind, .homeWin, .guestLose]
                } else if homeScore < guestScore {
                    outcomes += [.timerExpiredHomeBehind, .timerExpiredGuestAhead, .homeLose, .guestWin]
                } else {
                    outcomes.append(.timerExpiredTie)
                }
            }
        }
        if paused {
            outcomes.append(.timerPaused)
            if supportsScore {
                if homeScore > guestScore {
                    outcomes += [.timerPausedHomeAhead, .timerPausedGuestBehind]
                } else if homeScore < guestScore {
                    outcomes += [.timerPausedHomeBehind, .timerPausedGuestAhead]
                } else {
                    outcomes.append(.timerPausedTie)
                }
            }
        }
        return outcomes.map { eventDispatch($0) }
    }

    private func playNextEventAction() {
        guard isSessionAuthority else { clearQueuedEventActions(); return }
        guard activeEventPlaybackID == nil else { return }
        while !queuedEventActions.isEmpty {
            let action = queuedEventActions.removeFirst()
            guard isSoundEnabled, action.effect != .none,
                  !isSoundEventBypassed(action.triggerEvent, sport: action.sport),
                  !isSoundEventBypassed(action.soundEvent ?? .general, sport: action.sport) else {
                sendQueuedCompanionCommand(for: action)
                continue
            }
            stopTestSound()
            let playbackID = UUID()
            activeEventPlaybackID = playbackID
            activeEventAction = action
            activeEventDidStart = false
            buzzerPlayer.play(action.effect, onStarted: { [weak self] in
                guard let self, self.activeEventPlaybackID == playbackID else { return }
                self.activeEventDidStart = true
                self.sendQueuedCompanionCommand(for: action)
                self.remoteDisplayHostService.sendSoundEffect(action.effect)
            }, onFinished: { [weak self] _ in
                guard let self, self.activeEventPlaybackID == playbackID else { return }
                // A missing/unplayable local sound must not drop its automation command.
                if !self.activeEventDidStart { self.sendQueuedCompanionCommand(for: action) }
                self.activeEventPlaybackID = nil
                self.activeEventAction = nil
                self.playNextEventAction()
            })
            return
        }
    }

    private func sendQueuedCompanionCommand(for action: QueuedEventAction) {
        guard isCompanionVisible, isCompanionEnabled,
              action.companionGeneration == companionCommandGeneration,
              !isCompanionEventBypassed(action.triggerEvent, sport: action.sport),
              !isCompanionEventBypassed(action.companionEvent ?? .general, sport: action.sport),
              let location = action.companionLocation else { return }
        sendCompanionPress(location,
                           events: [action.triggerEvent] + [action.companionEvent].compactMap { $0 },
                           sport: action.sport)
    }

    private func interruptEventSoundPlayback() {
        if let action = activeEventAction, !activeEventDidStart {
            sendQueuedCompanionCommand(for: action)
        }
        activeEventPlaybackID = nil
        activeEventAction = nil
        buzzerPlayer.stop()
        playNextEventAction()
    }

    private func clearQueuedEventActions() {
        queuedEventActions.removeAll()
        activeEventPlaybackID = nil
        activeEventAction = nil
        buzzerPlayer.stop()
        invalidateQueuedCompanionCommands()
    }

    private func invalidateQueuedCompanionCommands() {
        companionCommandGeneration = UUID()
        companionService.cancelPendingPresses()
    }

    private func companionLocation(for event: ScoreboardSoundEvent) -> ScoreboardCompanionLocation? {
        companionLocation(for: event, sport: selectedSport)
    }

    private func companionLocation(for event: ScoreboardSoundEvent, sport: SportType) -> ScoreboardCompanionLocation? {
        ScoreboardCompanionLocation(rawValue: companionLocationText(for: event, sport: sport))
    }

    private func sendCompanionPress(
        _ location: ScoreboardCompanionLocation,
        events: [ScoreboardSoundEvent] = [], sport: SportType? = nil
    ) {
        guard isSessionAuthority else { return }
        let commandGeneration = companionCommandGeneration
        let eventSport = sport ?? selectedSport
        companionService.sendPress(
            host: companionHost,
            port: companionPort,
            mode: companionMode,
            location: location,
            eventKeys: events.map { "\(eventSport.rawValue):\($0.rawValue)" }
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard self?.companionCommandGeneration == commandGeneration else { return }
                self?.handleCompanionSendResult(result)
            }
        }
    }

    private func handleCompanionSendResult(_ result: Result<Void, ScoreboardCompanionSendError>) {
        switch result {
        case .success:
            companionLastError = nil
        case .failure(let error):
            presentCompanionFailure(error)
        }
    }

    private func presentCompanionFailure(_ error: ScoreboardCompanionSendError) {
        let detail = error.localizedDescription
        companionLastError = detail
        let notice = ScoreboardCompanionFailureNotice(detail: detail)
        companionFailureNotice = notice
        companionFailureClearTask?.cancel()
        companionFailureClearTask = Task { [weak self, notice] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                guard self?.companionFailureNotice?.id == notice.id else {
                    return
                }
                self?.companionFailureNotice = nil
            }
        }
    }

    func dismissCompanionFailureNotice() {
        companionFailureClearTask?.cancel()
        companionFailureClearTask = nil
        companionFailureNotice = nil
    }

    private func performWithoutAuditLogging(_ action: () -> Void) {
        let previousValue = isAuditLoggingSuspended
        isAuditLoggingSuspended = true
        defer { isAuditLoggingSuspended = previousValue }
        action()
    }

    private func recordLog(
        kind: ScoreboardLogOperationKind,
        summary: String,
        outcome: ScoreboardLogOutcome,
        teamSide: TeamSide? = nil,
        player: TrackedPlayer? = nil,
        delta: Int? = nil,
        value: Int? = nil,
        fileName: String? = nil,
        notes: String? = nil
    ) {
        guard isSessionAuthority, !isAuditLoggingSuspended else {
            return
        }

        logManager.record(
            operation: ScoreboardLogOperation(
                kind: kind,
                summary: summary,
                teamSide: teamSide,
                playerID: player?.id,
                playerNumber: player?.number,
                playerName: player?.name,
                delta: delta,
                value: value,
                fileName: fileName,
                notes: notes
            ),
            context: currentLogContext(),
            outcome: outcome
        )
    }

    private func cardLogValue(for status: PlayerCardStatus) -> Int {
        switch status {
        case .none:
            return 0
        case .yellow:
            return 1
        case .red:
            return 2
        }
    }

    func setWebAPIEnabled(_ isEnabled: Bool) {
        guard isWebAPIEnabled != isEnabled else {
            return
        }

        if isEnabled {
            pendingExternalAutomationIntegration = .webAPI
            externalAutomationSafetyNoticeID = UUID()
        } else {
            isWebAPIEnabled = false
        }
    }

    func agreeToExternalAutomationSafetyNotice() {
        switch pendingExternalAutomationIntegration {
        case .companion:
            isCompanionVisible = true
        case .webAPI:
            isWebAPIEnabled = true
        case nil:
            break
        }
        cancelExternalAutomationSafetyNotice()
    }

    func cancelExternalAutomationSafetyNotice() {
        pendingExternalAutomationIntegration = nil
        externalAutomationSafetyNoticeID = nil
    }

    func setWebAPIUpdateMode(_ mode: ScoreboardWebAPIUpdateMode) {
        webAPIUpdateMode = mode
    }

    var customDisplayEnabledDisplayIDs: [Int] {
        let enabledDisplayCount = Self.boundedWebAPIBroadcastEnabledDisplayCount(webAPIBroadcastEnabledDisplayCount)
        guard enabledDisplayCount >= Self.minWebAPIBroadcastCustomDisplayID else {
            return []
        }

        return Array(Self.minWebAPIBroadcastCustomDisplayID...enabledDisplayCount)
    }

    var webAPIBroadcastEnabledDisplayIDs: [Int] {
        guard isWebAPIBroadcastControlEnabled else {
            return []
        }

        return customDisplayEnabledDisplayIDs
    }

    var isCustomDisplayControlVisible: Bool {
        isWebAPIBroadcastControlEnabled || isRemoteDisplayIndividualControlEnabled
    }

    func setWebAPIBroadcastControlEnabled(_ isEnabled: Bool) {
        if isWebAPIBroadcastControlEnabled != isEnabled {
            isWebAPIBroadcastControlEnabled = isEnabled
        }
        normalizeWebAPIBroadcastControlState()
    }

    func setWebAPIBroadcastEnabledDisplayCount(_ count: Int) {
        let boundedCount = Self.boundedWebAPIBroadcastEnabledDisplayCount(count)
        if webAPIBroadcastEnabledDisplayCount != boundedCount {
            webAPIBroadcastEnabledDisplayCount = boundedCount
        }
    }

    func webAPIBroadcastDisplayMode(for displayID: Int) -> ScoreboardWebAPIBroadcastDisplayMode {
        guard Self.isWebAPIBroadcastCustomDisplayID(displayID) else {
            return .followDisplayControl
        }

        return webAPIBroadcastDisplayModesByID[displayID] ?? .followDisplayControl
    }

    func setWebAPIBroadcastDisplayMode(_ mode: ScoreboardWebAPIBroadcastDisplayMode, for displayID: Int) {
        if routeRemoteControlCommand("display.broadcast", value: displayID, text: mode.rawValue) { return }
        guard Self.isWebAPIBroadcastCustomDisplayID(displayID) else {
            return
        }

        var modes = webAPIBroadcastDisplayModesByID
        if mode == .followDisplayControl {
            modes.removeValue(forKey: displayID)
        } else {
            modes[displayID] = mode
        }
        let normalizedModes = Self.normalizedWebAPIBroadcastDisplayModes(modes)
        if webAPIBroadcastDisplayModesByID != normalizedModes {
            webAPIBroadcastDisplayModesByID = normalizedModes
        }
    }

    func customDisplayModeTitle(for mode: ScoreboardWebAPIBroadcastDisplayMode) -> String {
        guard mode.isCustomMode else {
            return mode.title
        }

        return customDisplayModeTitlesByMode[mode.rawValue] ?? mode.title
    }

    func setCustomDisplayModeTitle(_ title: String, for mode: ScoreboardWebAPIBroadcastDisplayMode) {
        guard mode.isCustomMode else {
            return
        }

        var titles = customDisplayModeTitlesByMode
        if let normalizedTitle = Self.normalizedCustomDisplayModeTitle(title), normalizedTitle != mode.title {
            titles[mode.rawValue] = normalizedTitle
        } else {
            titles.removeValue(forKey: mode.rawValue)
        }

        let normalizedTitles = Self.normalizedCustomDisplayModeTitles(titles)
        if customDisplayModeTitlesByMode != normalizedTitles {
            customDisplayModeTitlesByMode = normalizedTitles
        }
    }

    func setRemoteDisplayIndividualControlEnabled(_ isEnabled: Bool) {
        guard isRemoteDisplayIndividualControlEnabled != isEnabled else {
            return
        }

        isRemoteDisplayIndividualControlEnabled = isEnabled
    }

    func remoteDisplayCustomDisplayID(displayID: String) -> Int {
        guard isRemoteDisplayIndividualControlEnabled else {
            return Self.minWebAPIBroadcastDisplayID
        }

        let assignedDisplayID = remoteDisplayHostService.customDisplayID(id: displayID)
        guard assignedDisplayID == Self.minWebAPIBroadcastDisplayID || customDisplayEnabledDisplayIDs.contains(assignedDisplayID) else {
            return Self.minWebAPIBroadcastDisplayID
        }
        return assignedDisplayID
    }

    func setRemoteDisplayCustomDisplayID(displayID: String, customDisplayID: Int) {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "customDisplay", displayID: displayID, number: customDisplayID))
            return
        }
        let normalizedDisplayID = Self.normalizedWebAPIBroadcastDisplayID(customDisplayID)
        let resolvedDisplayID = normalizedDisplayID == Self.minWebAPIBroadcastDisplayID || customDisplayEnabledDisplayIDs.contains(normalizedDisplayID)
            ? normalizedDisplayID
            : Self.minWebAPIBroadcastDisplayID
        remoteDisplayHostService.setCustomDisplayID(id: displayID, customDisplayID: resolvedDisplayID)
        refreshRemoteDisplayState()
    }

    fileprivate static func boundedWebAPIBroadcastEnabledDisplayCount(_ count: Int) -> Int {
        max(minWebAPIBroadcastCustomDisplayID, min(maxWebAPIBroadcastDisplayID, count))
    }

    nonisolated static func normalizedWebAPIBroadcastDisplayID(_ displayID: Int) -> Int {
        guard displayID >= minWebAPIBroadcastDisplayID && displayID <= maxWebAPIBroadcastDisplayID else {
            return minWebAPIBroadcastDisplayID
        }
        return displayID
    }

    private static func isWebAPIBroadcastCustomDisplayID(_ displayID: Int) -> Bool {
        displayID >= minWebAPIBroadcastCustomDisplayID && displayID <= maxWebAPIBroadcastDisplayID
    }

    fileprivate static func normalizedWebAPIBroadcastDisplayModes(_ modes: [Int: ScoreboardWebAPIBroadcastDisplayMode]) -> [Int: ScoreboardWebAPIBroadcastDisplayMode] {
        var normalized: [Int: ScoreboardWebAPIBroadcastDisplayMode] = [:]
        for (displayID, mode) in modes where isWebAPIBroadcastCustomDisplayID(displayID) && mode != .followDisplayControl {
            normalized[displayID] = mode
        }
        return normalized
    }

    fileprivate static func normalizedCustomDisplayModeTitles(_ titles: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for mode in ScoreboardWebAPIBroadcastDisplayMode.customizableModes {
            guard let title = normalizedCustomDisplayModeTitle(titles[mode.rawValue] ?? ""), title != mode.title else {
                continue
            }
            normalized[mode.rawValue] = title
        }
        return normalized
    }

    private static func normalizedCustomDisplayModeTitle(_ title: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return nil
        }
        return String(trimmedTitle.prefix(maxCustomDisplayModeTitleLength))
    }

    private func normalizeWebAPIBroadcastControlState() {
        let boundedDisplayCount = Self.boundedWebAPIBroadcastEnabledDisplayCount(webAPIBroadcastEnabledDisplayCount)
        if webAPIBroadcastEnabledDisplayCount != boundedDisplayCount {
            webAPIBroadcastEnabledDisplayCount = boundedDisplayCount
        }

        let normalizedModes = Self.normalizedWebAPIBroadcastDisplayModes(webAPIBroadcastDisplayModesByID)
        if webAPIBroadcastDisplayModesByID != normalizedModes {
            webAPIBroadcastDisplayModesByID = normalizedModes
        }

        let normalizedTitles = Self.normalizedCustomDisplayModeTitles(customDisplayModeTitlesByMode)
        if customDisplayModeTitlesByMode != normalizedTitles {
            customDisplayModeTitlesByMode = normalizedTitles
        }
    }

    func setRemoteDisplayHostEnabled(_ isEnabled: Bool) {
        if !isEnabled && (isFollowingSessionHost || isDelegatedSessionHost) {
            guard !isAnyTimerRunning, !sessionTransferInProgress else {
                sessionStatusMessage = "Stop all timers and finish the host handoff before turning pairing off."
                return
            }
            if isSessionOwner {
                guard canHostOnOwnerAndDisconnectOthers else {
                    sessionStatusMessage = "Reconnect to the session host before turning pairing off."
                    return
                }
                disablePairingAfterHostTransfer = true
                hostOnOwnerAndDisconnectOthers()
                if !sessionTransferInProgress { disablePairingAfterHostTransfer = false }
            } else {
                guard isSessionSafeToDisconnect, let ownerID = sessionDescriptor?.ownerDeviceID else {
                    sessionStatusMessage = "The match has not synced to its owner. Reconnect and wait, or choose Delete Local Match."
                    return
                }
                disablePairingAfterHostTransfer = true
                exitRemoteModeAfterHostTransfer = true
                beginSessionTransfer(to: ownerID)
                if !sessionTransferInProgress {
                    disablePairingAfterHostTransfer = false
                    exitRemoteModeAfterHostTransfer = false
                }
            }
            return
        }
        if !isEnabled && sessionTransferInProgress {
            sessionStatusMessage = "Stop all timers and finish the host handoff before turning pairing off."
            return
        }
        if !isEnabled && isSessionOwner && isSessionAuthority {
            disconnectRemoteDisplays()
        }
        isRemoteDisplayHostEnabled = isEnabled
        if isEnabled && sessionDescriptor == nil { ensureOwnedSessionDescriptor() }
        if !isEnabled && isSessionOwner && isSessionAuthority && sessionDescriptor != nil {
            ScoreboardRemoteDisplayReceiver.shared.stopHostingSession()
            if sessionOwnerReceiverAcquired {
                ScoreboardRemoteDisplayReceiver.shared.release()
                sessionOwnerReceiverAcquired = false
            }
            sessionDescriptor = nil
            sessionRecoveryRole = nil
            sessionTransferCheckpoint = nil
            try? FileManager.default.removeItem(at: ScoreboardSessionRecovery.url)
        }
        if !isEnabled {
            resetRemoteDisplayWarningState()
        }
    }

    func setRemoteDisplayViewerModeEnabled(_ isEnabled: Bool) {
        if isFollowingSessionHost && isEnabled {
            sessionStatusMessage = "This device owns the session. Keep its control board and game files open here."
            return
        }
        if isDelegatedSessionHost && !isEnabled {
            guard isSessionSafeToDisconnect, let ownerID = sessionDescriptor?.ownerDeviceID else {
                sessionStatusMessage = "The match has not synced to its owner. Reconnect and wait, or choose Delete Local Match."
                return
            }
            exitRemoteModeAfterHostTransfer = true
            beginSessionTransfer(to: ownerID)
            return
        }
        if isEnabled, isSessionOwner, isSessionAuthority, sessionDescriptor != nil {
            guard !isAnyTimerRunning, !sessionTransferInProgress else {
                sessionStatusMessage = "Stop all timers and finish the host handoff before entering remote mode."
                return
            }
            // Entering remote mode leaves this local session's authority behind.
            // Keep the owner's game and settings, but do not carry that session
            // identity into the next device's authenticated pairing.
            ScoreboardRemoteDisplayReceiver.shared.stopHostingSession()
            if sessionOwnerReceiverAcquired {
                ScoreboardRemoteDisplayReceiver.shared.release()
                sessionOwnerReceiverAcquired = false
            }
            sessionDescriptor = nil
            sessionRecoveryRole = nil
            sessionTransferCheckpoint = nil
            sessionTransferID = nil
            sessionTransferTargetID = nil
            sessionAuthorityFenced = false
            try? FileManager.default.removeItem(at: ScoreboardSessionRecovery.url)
        }
        #if !os(tvOS)
        if isEnabled {
            stopRemoteDisplayHostService()
        } else {
            ScoreboardRemoteDisplayReceiver.shared.stop()
        }
        #endif

        isRemoteDisplayViewerModeEnabled = isEnabled
        if !isEnabled && !isSessionOwner {
            sessionDescriptor = nil
            sessionRecoveryRole = nil
            sessionAuthorityFenced = false
            sessionTransferCheckpoint = nil
            sessionTransferID = nil
            sessionTransferTargetID = nil
            try? FileManager.default.removeItem(at: ScoreboardSessionRecovery.url)
            loadPersistedState()
            // The personal snapshot may remember that this device was a viewer.
            // Leaving remote mode must also update that saved preference.
            isRemoteDisplayViewerModeEnabled = false
            persistState()
        }
        if isEnabled {
            resetRemoteDisplayWarningState()
        }
    }

    /// Explicit data-loss choice from the hosted display's exit confirmation.
    @discardableResult
    func deleteHostedMatchAndExitRemoteMode() -> Bool {
        discardHostedMatch(leaveRemoteMode: true)
    }

    @discardableResult
    func discardHostedMatchAndReturnToPairing() -> Bool {
        discardHostedMatch(leaveRemoteMode: false)
    }

    private func discardHostedMatch(leaveRemoteMode: Bool) -> Bool {
        guard hasHostedMatchToDiscard, let sessionID = sessionDescriptor?.sessionID else { return false }
        do {
            try removeHostedSessionData(sessionID: sessionID)
        } catch {
            sessionStatusMessage = "Could not delete the hosted match: \(error.localizedDescription)"
            return false
        }
        sessionAuthorityFenced = true
        stopWebAPIService()
        stopRemoteDisplayHostService()
        ScoreboardRemoteDisplayReceiver.shared.stopHostingSession()
        clearHostedSessionBookkeeping()
        remoteDisplayHostService.clearSessionPairings()
        ScoreboardRemoteDisplayReceiver.shared.forgetTrustedHosts()
        sessionAuthorityFenced = false
        loadPersistedState()
        isRemoteDisplayViewerModeEnabled = !leaveRemoteMode
        sessionStatusMessage = nil
        persistState()
        return true
    }

    private func removeHostedSessionData(sessionID: UUID) throws {
        logManager.releaseHostedSession(sessionID: sessionID)
        try ScoreboardHostedMatchStorage.remove(sessionID: sessionID)
        if FileManager.default.fileExists(atPath: ScoreboardSessionRecovery.url.path) {
            try FileManager.default.removeItem(at: ScoreboardSessionRecovery.url)
        }
    }

    private func clearHostedSessionBookkeeping() {
        sessionDescriptor = nil
        sessionRecoveryRole = nil
        sessionTransferCheckpoint = nil
        sessionTransferID = nil
        sessionTransferTargetID = nil
        sessionTransferStartedAt = nil
        sessionTransferInProgress = false
        lastSessionPrepareSentAt = nil
        lastSessionCommitSentAt = nil
        sessionHostPeers = []
        pendingLogBatchByPeer.removeAll()
        logCursorByPeer.removeAll()
        lastLogPageAtByPeer.removeAll()
        lastSessionPeerReportAt = nil
        lastSessionLogRequestAt = nil
        pendingSnapshotSyncID = nil
        pendingSnapshotLogCount = -1
        lastSnapshotSyncSentAt = nil
        sessionSyncRevision = 1
        hostedCheckpointPersistedRevision = 0
        ownerAcknowledgedRevision = 0
        ownerAcknowledgedLogCount = -1
        observedHostedLogCount = -1
        exitRemoteModeAfterHostTransfer = false
        disconnectClientsAfterOwnerTakeover = false
        disablePairingAfterHostTransfer = false
        remoteControlState = nil
        remoteControlGameConfiguration = nil
        controlCommandResults.removeAll()
        sessionOwnerPairingSecret = nil
        lastOwnerSettingsData = nil
        lastOwnerVisualData = nil
        pendingOwnerSettingsSync = false
        pendingOwnerVisualSync = false
        pendingOwnerVisualFields.removeAll()
        pendingOwnerVisualSnapshot = nil
    }

    /// Take over from the last checkpoint acknowledged by this owner when its
    /// delegated host is permanently unavailable. No unsynced host changes can
    /// be recovered, and clocks deliberately remain stopped.
    func recoverSessionHostOnOwner() {
        guard canRecoverSessionHost, let descriptor = sessionDescriptor,
              var checkpoint = sessionTransferCheckpoint else { return }
        var recoveredDescriptor = descriptor
        recoveredDescriptor.epoch += 1
        recoveredDescriptor.hostDeviceID = localSessionDeviceID
        recoveredDescriptor.hostName = remoteDisplayHostName
        recoveredDescriptor.hostAddresses = ScoreboardWebAPIService.localIPv4Addresses()
        recoveredDescriptor.safeToDisconnect = nil
        checkpoint.descriptor = recoveredDescriptor
        checkpoint.game.pauseTimer?.isRunning = false
        checkpoint.runtime = ScoreboardWebAPIRuntime(
            isGameRunning: checkpoint.runtime.isGameRunning,
            isClockRunning: false, isShotClockRunning: false,
            isDebatePrepClockRunning: false,
            areSidesSwapped: checkpoint.runtime.areSidesSwapped,
            possessionDirection: checkpoint.runtime.possessionDirection)
        do {
            // The owner owns setup and integrations; the delegated host never
            // replaces these settings when control returns here.
            checkpoint.settings = try exportPersistedStateData()
            if let localLog = logManager.currentSessionSnapshot(),
               localLog.sessionID == checkpoint.log.sessionID,
               localLog.startedAt.ISO8601Format() == checkpoint.log.startedAt.ISO8601Format(),
               localLog.entries.count >= checkpoint.log.entries.count,
               zip(checkpoint.log.entries, localLog.entries).allSatisfy({ $0.id == $1.id }) {
                checkpoint.log = localLog
            } else {
                try logManager.adoptAuthoritativeSession(checkpoint.log, gameDisplayName: checkpoint.gameName)
            }
            try persistOwnerSessionFile(checkpoint)
            try ScoreboardSessionRecovery(role: .host, descriptor: recoveredDescriptor,
                                          checkpoint: checkpoint, transferID: nil).save()
            if sessionOwnerReceiverAcquired {
                ScoreboardRemoteDisplayReceiver.shared.release()
                sessionOwnerReceiverAcquired = false
            }
            sessionTransferInProgress = false
            sessionTransferID = nil
            sessionTransferTargetID = nil
            sessionTransferCheckpoint = checkpoint
            activateSessionCheckpoint(checkpoint, fromRecovery: false)
        } catch {
            sessionStatusMessage = "Could not recover this session: \(error.localizedDescription)"
        }
    }

    func handoffHostedMatchForQuit(completion: @escaping (Bool) -> Void) {
        guard isDelegatedSessionHost, isSessionSafeToDisconnect,
              let ownerID = sessionDescriptor?.ownerDeviceID else { completion(false); return }
        hostedMatchQuitCompletion = completion
        beginSessionTransfer(to: ownerID)
        if !sessionTransferInProgress, hostedMatchQuitCompletion != nil {
            hostedMatchQuitCompletion = nil
            completion(false)
        }
    }

    func prepareHostedMatchForBackground() {
        guard isDelegatedSessionHost, isSessionSafeToDisconnect, !sessionTransferInProgress,
              let ownerID = sessionDescriptor?.ownerDeviceID else { return }
        beginSessionTransfer(to: ownerID)
    }

    func setRemoteDisplayNetworkMode(_ mode: ScoreboardRemoteDisplayNetworkMode) {
        guard remoteDisplayNetworkMode != mode else {
            return
        }
        remoteDisplayNetworkMode = mode
        remoteDisplayWarningNotice = nil
        if isRemoteDisplayViewerModeEnabled {
            ScoreboardRemoteDisplayReceiver.shared.updateNetworkMode(mode)
        }
    }

    func pairRemoteDisplay(
        _ source: ScoreboardRemoteDisplaySource,
        pairingCode: String,
        takeoverConfirmed: Bool = false
    ) {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "pair", displayID: source.id,
                                            enabled: takeoverConfirmed, text: pairingCode))
            return
        }
        remoteDisplayHostService.pair(
            with: source,
            pairingCode: pairingCode,
            takeoverConfirmed: takeoverConfirmed
        )
    }

    func connectTrustedRemoteDisplay(
        _ source: ScoreboardRemoteDisplaySource,
        takeoverConfirmed: Bool = false
    ) {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "connect", displayID: source.id,
                                            enabled: takeoverConfirmed))
            return
        }
        remoteDisplayHostService.connectTrustedDisplay(
            source,
            takeoverConfirmed: takeoverConfirmed
        )
    }

    func removeRemoteDisplayPairing(displayID: String) {
        guard sessionDescriptor?.hostDeviceID != displayID else {
            sessionStatusMessage = "Move hosting to another device before removing the session host."
            return
        }
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "remove", displayID: displayID))
            return
        }
        setRemoteControlAllowed(displayID: displayID, isAllowed: false)
        if remoteDisplayConnectedDisplays.contains(where: { $0.id == displayID }) {
            intentionallyDisconnectedRemoteDisplayIDs.insert(displayID)
        }
        remoteDisplayDisconnectedDisplaysByID.removeValue(forKey: displayID)
        dismissedRemoteDisplayWarningDisplayIDs.remove(displayID)
        if remoteDisplayWarningNotice?.displayIDs.contains(displayID) == true {
            remoteDisplayWarningNotice = nil
        }
        remoteDisplayHostService.removeTrustedDisplay(id: displayID)
    }

    func isTrustedRemoteDisplay(_ source: ScoreboardRemoteDisplaySource) -> Bool {
        if isFollowingSessionHost {
            return remoteDisplayTrustedDisplays.contains { $0.id == source.id && $0.pairingSecret?.isEmpty == false }
        }
        return remoteDisplayHostService.isTrustedDisplay(source)
    }

    func disconnectRemoteDisplays() {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "disconnectAll", displayID: ""))
            return
        }
        intentionallyDisconnectedRemoteDisplayIDs.formUnion(remoteDisplayConnectedDisplays.map(\.id))
        remoteDisplayDisconnectedDisplaysByID.removeAll()
        remoteDisplayWarningNotice = nil
        remoteDisplayHostService.disconnectDisplays()
    }

    func disconnectRemoteDisplay(displayID: String) {
        guard sessionDescriptor?.hostDeviceID != displayID else {
            sessionStatusMessage = "Move hosting to another device before disconnecting the session host."
            return
        }
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "disconnect", displayID: displayID))
            return
        }
        if remoteDisplayConnectedDisplays.contains(where: { $0.id == displayID }) {
            intentionallyDisconnectedRemoteDisplayIDs.insert(displayID)
        }
        remoteDisplayDisconnectedDisplaysByID.removeValue(forKey: displayID)
        if remoteDisplayWarningNotice?.displayIDs.contains(displayID) == true {
            remoteDisplayWarningNotice = nil
        }
        remoteDisplayHostService.disconnectDisplay(id: displayID)
    }

    func sendRemoteDisplaySoundTest(displayID: String) {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "soundTest", displayID: displayID))
            return
        }
        remoteDisplayHostService.sendSoundTest(toDisplayID: displayID)
    }

    func setRemoteDisplayMuted(displayID: String, isMuted: Bool) {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "mute", displayID: displayID, enabled: isMuted))
            return
        }
        remoteDisplayHostService.setDisplayMuted(id: displayID, isMuted: isMuted)
    }

    func isRemoteDisplayMuted(displayID: String) -> Bool {
        remoteDisplayMutedDisplayIDs.contains(displayID)
    }

    func remoteDisplayDirection(displayID: String) -> ScoreboardDisplayDirection {
        remoteDisplayHostService.displayDirection(id: displayID)
    }

    func remoteDisplayExternalDirection(displayID: String) -> ScoreboardDisplayDirection {
        remoteDisplayHostService.externalDisplayDirection(id: displayID)
    }

    func resolvedRemoteDisplayDirection(displayID: String) -> ScoreboardDisplayDirection {
        resolvedDisplayDirection(for: remoteDisplayDirection(displayID: displayID))
    }

    func resolvedRemoteDisplayExternalDirection(displayID: String) -> ScoreboardDisplayDirection {
        resolvedDisplayDirection(for: remoteDisplayExternalDirection(displayID: displayID))
    }

    func setRemoteDisplayDirection(displayID: String, direction: ScoreboardDisplayDirection) {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "direction", displayID: displayID, text: direction.rawValue))
            return
        }
        remoteDisplayHostService.setDisplayDirection(id: displayID, direction: direction)
        refreshRemoteDisplayState()
    }

    func setRemoteDisplayExternalDirection(displayID: String, direction: ScoreboardDisplayDirection) {
        if isFollowingSessionHost {
            sendSessionAdministration(.init(action: "externalDirection", displayID: displayID, text: direction.rawValue))
            return
        }
        remoteDisplayHostService.setExternalDisplayDirection(id: displayID, direction: direction)
        refreshRemoteDisplayState()
    }

    func refreshWebAPILocalAddresses() {
        webAPILocalAddresses = ScoreboardWebAPIService.localIPv4Addresses()
        if isSessionAuthority, var descriptor = sessionDescriptor,
           descriptor.hostAddresses != webAPILocalAddresses {
            descriptor.hostAddresses = webAPILocalAddresses
            sessionDescriptor = descriptor
            refreshRemoteDisplayState()
        }
    }

    func resumeWebAPIForAppLifecycle() {
        #if os(iOS)
        isWebAPIAppLifecycleActive = true
        guard isWebAPIEnabled else {
            return
        }
        startWebAPIService()
        #endif
    }

    func suspendWebAPIForAppLifecycle() {
        #if os(iOS)
        guard isWebAPIAppLifecycleActive else {
            return
        }
        isWebAPIAppLifecycleActive = false
        guard isWebAPIEnabled else {
            return
        }
        webAPIService.stop(notify: false)
        webAPIStatus = .suspended
        #endif
    }

    #if os(iOS)
    func prepareForBackgroundRuntime() {
        reconcileRunningTimersWithWallClock()
        refreshPrimaryTimerPersistence()
        persistState()
        syncLiveActivityForCurrentState()
    }

    func resumeFromBackgroundRuntime() {
        reconcileRunningTimersWithWallClock()
        refreshPrimaryTimerPersistence()
        persistState()
        syncLiveActivityForCurrentState()
        resumeWebAPIForAppLifecycle()
        refreshWebAPILocalAddresses()
    }

    func expireBackgroundWebAPIGrace() {
        reconcileRunningTimersWithWallClock()
        refreshPrimaryTimerPersistence()
        persistState()
        syncLiveActivityForCurrentState()
        isWebAPIAppLifecycleActive = false
        guard isWebAPIEnabled else {
            return
        }
        webAPIService.stop(notify: false)
        webAPIStatus = .suspended
    }

    func performBackgroundTimerMaintenance() {
        reconcileRunningTimersWithWallClock()
        refreshPrimaryTimerPersistence()
        persistState()
        syncLiveActivityForCurrentState()
    }
    #endif

    private func configureWebAPIService() {
        webAPILocalAddresses = ScoreboardWebAPIService.localIPv4Addresses()
        webAPIService.controlHandler = { [weak self] command, key, completion in
            Task { @MainActor [weak self] in
                guard let self, self.isSessionAuthority, self.isWebAPIEnabled, self.isWebControlEnabled else {
                    completion(.failure(command.id, "disabled", "Web control is disabled.")); return
                }
                guard key.uppercased() == self.webControlAPIKey else {
                    completion(.failure(command.id, "unauthorized", "Invalid API key.")); return
                }
                completion(self.performControlCommand(command, remote: false))
            }
        }

        $webAPIUpdateMode
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.webAPIService.setUpdateMode(mode)
            }
            .store(in: &cancellables)

        $isWebAPIEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                if isEnabled && self.isSessionAuthority {
                    if self.isWebAPIAppLifecycleActive {
                        self.startWebAPIService()
                    } else {
                        self.webAPIStatus = .suspended
                    }
                } else {
                    self.stopWebAPIService()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .scoreboardLogCurrentSessionDidChange)
            .sink { [weak self] _ in
                self?.scheduleStateSideEffectRefresh()
            }
            .store(in: &cancellables)
    }

    private func configureRemoteDisplayService() {
        remoteDisplayHostService.controlPermissionProvider = { [weak self] displayID in
            self?.isRemoteControlAllowed(displayID: displayID) ?? false
        }
        remoteDisplayHostService.controlCommandHandler = { [weak self] command, displayID in
            guard let self, self.isSessionAuthority, self.isRemoteDisplayHostEnabled,
                  self.isRemoteControlAllowed(displayID: displayID) else {
                return .failure(command.id, "disabled", "This device is not allowed to control the main board.")
            }
            return self.performControlCommand(command, remote: true)
        }
        remoteDisplayHostService.$status
            .sink { [weak self] status in
                self?.remoteDisplayHostStatus = status
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$sources
            .sink { [weak self] sources in
                self?.remoteDisplaySources = sources
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$connectedDisplays
            .sink { [weak self] connectedDisplays in
                guard let self, !self.isFollowingSessionHost else { return }
                self.handleRemoteDisplayConnectedDisplaysChanged(connectedDisplays)
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$trustedDisplays
            .sink { [weak self] trustedDisplays in
                guard let self, !self.isFollowingSessionHost else { return }
                self.handleRemoteDisplayTrustedDisplaysChanged(trustedDisplays)
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$mutedDisplayIDs
            .sink { [weak self] mutedDisplayIDs in
                guard let self, !self.isFollowingSessionHost else { return }
                self.remoteDisplayMutedDisplayIDs = mutedDisplayIDs
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$displayDirectionsByID
            .sink { [weak self] displayDirectionsByID in
                guard let self, !self.isFollowingSessionHost else { return }
                self.remoteDisplayDirectionsByID = displayDirectionsByID
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$customDisplayIDsByID
            .sink { [weak self] customDisplayIDsByID in
                guard let self, !self.isFollowingSessionHost else { return }
                self.remoteDisplayCustomDisplayIDsByDisplayID = customDisplayIDsByID
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$displayInitiatedDisconnectNotice
            .compactMap { $0 }
            .sink { [weak self] notice in
                self?.handleRemoteDisplayInitiatedDisconnect(notice)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            $isRemoteDisplayHostEnabled.removeDuplicates(),
            $isRemoteDisplayViewerModeEnabled.removeDuplicates(),
            $remoteDisplayNetworkMode.removeDuplicates()
        )
        .sink { [weak self] isHostEnabled, isViewerModeEnabled, _ in
            guard let self else { return }
            if self.isFollowingSessionHost {
                self.remoteDisplayHostService.startDiscoveryOnly(networkMode: self.remoteDisplayNetworkMode)
            } else if self.isSessionAuthority && isHostEnabled && (!isViewerModeEnabled || self.isDelegatedSessionHost) {
                self.startRemoteDisplayHostService()
            } else {
                self.stopRemoteDisplayHostService()
            }
        }
        .store(in: &cancellables)
    }

    private func handleRemoteDisplayInitiatedDisconnect(_ notice: ScoreboardRemoteDisplayDisconnectNotice) {
        intentionallyDisconnectedRemoteDisplayIDs.insert(notice.displayID)
        remoteDisplayDisconnectedDisplaysByID.removeValue(forKey: notice.displayID)
        dismissedRemoteDisplayWarningDisplayIDs.remove(notice.displayID)
        if remoteDisplayWarningNotice?.displayIDs.contains(notice.displayID) == true {
            remoteDisplayWarningNotice = nil
        }
    }

    private func handleRemoteDisplayConnectedDisplaysChanged(_ connectedDisplays: [ScoreboardRemoteDisplayConnection]) {
        let uniqueConnectedDisplays = uniqueRemoteDisplayConnections(connectedDisplays)
        remoteDisplayConnectedDisplays = uniqueConnectedDisplays

        guard isRemoteDisplayHostEnabled, (!isRemoteDisplayViewerModeEnabled || isDelegatedSessionHost) else {
            resetRemoteDisplayWarningState(connectedDisplays: uniqueConnectedDisplays)
            return
        }

        let connectedDisplaysByID = keyedRemoteDisplayConnections(uniqueConnectedDisplays)
        let droppedDisplays = remoteDisplayConnectedDisplaysByID.filter { connectedDisplaysByID[$0.key] == nil }

        for (displayID, display) in droppedDisplays {
            if intentionallyDisconnectedRemoteDisplayIDs.remove(displayID) != nil {
                continue
            }
            remoteDisplayDisconnectedDisplaysByID[displayID] = display.name
        }

        for displayID in connectedDisplaysByID.keys {
            remoteDisplayDisconnectedDisplaysByID.removeValue(forKey: displayID)
            dismissedRemoteDisplayWarningDisplayIDs.remove(displayID)
            intentionallyDisconnectedRemoteDisplayIDs.remove(displayID)
        }

        remoteDisplayConnectedDisplaysByID = connectedDisplaysByID
        refreshRemoteDisplayWarningNotice(
            unresponsiveDisplays: uniqueConnectedDisplays.filter { $0.quality == .unresponsive }
        )
    }

    private func handleRemoteDisplayTrustedDisplaysChanged(_ trustedDisplays: [ScoreboardRemoteDisplayTrustedPeer]) {
        remoteDisplayTrustedDisplays = trustedDisplays
        let permitted = remoteControlAllowedDisplayIDs.intersection(Set(trustedDisplays.filter { $0.deviceType != .appleTV }.map(\.id)))
        if permitted != remoteControlAllowedDisplayIDs {
            remoteControlAllowedDisplayIDs = permitted
            if !isDelegatedSessionHost {
                ScoreboardPreferences.current.set(permitted.sorted(), forKey: "scoreboard.remoteControlAllowedDisplayIDs")
            }
        }

        let trustedDisplayIDs = Set(trustedDisplays.map(\.id))
        remoteDisplayDisconnectedDisplaysByID = remoteDisplayDisconnectedDisplaysByID.filter { trustedDisplayIDs.contains($0.key) }
        dismissedRemoteDisplayWarningDisplayIDs.formIntersection(
            trustedDisplayIDs.union(remoteDisplayConnectedDisplays.map(\.id))
        )
        refreshRemoteDisplayWarningNotice(
            unresponsiveDisplays: remoteDisplayConnectedDisplays.filter { $0.quality == .unresponsive }
        )
    }

    private func refreshRemoteDisplayWarningNotice(unresponsiveDisplays: [ScoreboardRemoteDisplayConnection]) {
        let unresponsiveDisplaysByID = keyedRemoteDisplayNames(unresponsiveDisplays)
        let problemDisplayIDs = Set(remoteDisplayDisconnectedDisplaysByID.keys).union(unresponsiveDisplaysByID.keys)

        dismissedRemoteDisplayWarningDisplayIDs.formIntersection(problemDisplayIDs)

        guard !problemDisplayIDs.isEmpty else {
            remoteDisplayWarningNotice = nil
            return
        }

        let unsuppressedDisconnectedDisplays = remoteDisplayDisconnectedDisplaysByID.filter {
            !dismissedRemoteDisplayWarningDisplayIDs.contains($0.key)
        }
        if !unsuppressedDisconnectedDisplays.isEmpty {
            presentRemoteDisplayWarningNotice(kind: .disconnected, displaysByID: unsuppressedDisconnectedDisplays)
            return
        }

        let unsuppressedUnresponsiveDisplays = unresponsiveDisplaysByID.filter {
            !dismissedRemoteDisplayWarningDisplayIDs.contains($0.key)
        }
        if !unsuppressedUnresponsiveDisplays.isEmpty {
            presentRemoteDisplayWarningNotice(kind: .unresponsive, displaysByID: unsuppressedUnresponsiveDisplays)
            return
        }

        remoteDisplayWarningNotice = nil
    }

    private func presentRemoteDisplayWarningNotice(
        kind: ScoreboardRemoteDisplayWarningNotice.Kind,
        displaysByID: [String: String]
    ) {
        let displayIDs = Set(displaysByID.keys)
        if remoteDisplayWarningNotice?.kind == kind, remoteDisplayWarningNotice?.displayIDs == displayIDs {
            return
        }
        remoteDisplayWarningNotice = ScoreboardRemoteDisplayWarningNotice(kind: kind, displaysByID: displaysByID)
    }

    private func resetRemoteDisplayWarningState(connectedDisplays: [ScoreboardRemoteDisplayConnection] = []) {
        remoteDisplayConnectedDisplaysByID = keyedRemoteDisplayConnections(connectedDisplays)
        remoteDisplayDisconnectedDisplaysByID.removeAll()
        dismissedRemoteDisplayWarningDisplayIDs.removeAll()
        intentionallyDisconnectedRemoteDisplayIDs.removeAll()
        remoteDisplayWarningNotice = nil
    }

    private func keyedRemoteDisplayConnections(_ connectedDisplays: [ScoreboardRemoteDisplayConnection]) -> [String: ScoreboardRemoteDisplayConnection] {
        connectedDisplays.reduce(into: [:]) { displaysByID, display in
            displaysByID[display.id] = display
        }
    }

    private func keyedRemoteDisplayNames(_ connectedDisplays: [ScoreboardRemoteDisplayConnection]) -> [String: String] {
        connectedDisplays.reduce(into: [:]) { namesByID, display in
            namesByID[display.id] = display.name
        }
    }

    private func uniqueRemoteDisplayConnections(_ connectedDisplays: [ScoreboardRemoteDisplayConnection]) -> [ScoreboardRemoteDisplayConnection] {
        keyedRemoteDisplayConnections(connectedDisplays).values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func startWebAPIService() {
        guard isSessionAuthority else { return }
        webAPILocalAddresses = ScoreboardWebAPIService.localIPv4Addresses()
        webAPIStatus = .starting
        let payloads = encodedWebAPIOutputPayloads()
        webAPIService.start(
            initialPayload: payloads.state,
            initialCommentatorPayload: payloads.commentator,
            updateMode: webAPIUpdateMode,
            imageResponses: currentWebAPIImageResponses()
        ) { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.webAPIStatus = status
                self.webAPILocalAddresses = ScoreboardWebAPIService.localIPv4Addresses()
            }
        }
    }

    private func stopWebAPIService() {
        webAPIService.stop()
        webAPIStatus = .off
    }

    private func refreshWebAPIState() {
        let payloads = encodedWebAPIOutputPayloads()
        webAPIService.updateState(
            payloads.state,
            imageResponses: currentWebAPIImageResponses(),
            commentatorPayload: payloads.commentator
        )
    }

    private func startRemoteDisplayHostService() {
        guard isSessionAuthority else { return }
        remoteDisplayHostService.start(
            initialState: encodedRemoteDisplayStates(),
            displayName: remoteDisplayHostName,
            networkMode: remoteDisplayNetworkMode,
            currentStateProvider: { [weak self] displayID, version in
                self?.encodedRemoteDisplayStates(forDisplayID: displayID).data(preferredVersion: version)
                    ?? ScoreboardRemoteDisplayEncodedStates.encodingFailed.data(preferredVersion: version)
            },
            currentImageResponsesProvider: { [weak self] in
                self?.currentWebAPIImageResponses() ?? [:]
            }
        )
    }

    private func stopRemoteDisplayHostService() {
        resetRemoteDisplayWarningState()
        remoteDisplayHostService.stop()
    }

    private func refreshRemoteDisplayState() {
        guard isSessionAuthority else { return }
        remoteDisplayHostService.updateState(encodedRemoteDisplayStates())
        if isDelegatedSessionHost {
            ScoreboardRemoteDisplayReceiver.shared.updateHostedState(state: currentRemoteDisplayState(forDisplayID: localSessionDeviceID),
                images: currentWebAPIImageResponses())
        }
    }

    private func encodedWebAPIPayload() -> ScoreboardWebAPIPayload {
        ScoreboardWebAPIPayload.make(from: currentWebAPIState())
    }

    private func encodedWebAPIOutputPayloads() -> (state: ScoreboardWebAPIPayload, commentator: ScoreboardWebAPICommentatorPayload) {
        let state = currentWebAPIState()
        return (
            state: ScoreboardWebAPIPayload.make(from: state),
            commentator: ScoreboardWebAPICommentatorPayload.make(
                from: state,
                logSession: logManager.currentSessionSnapshot()
            )
        )
    }

    private func encodedRemoteDisplayState() -> Data {
        encodedRemoteDisplayState(forDisplayID: nil)
    }

    private func encodedRemoteDisplayState(forDisplayID displayID: String?) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(currentRemoteDisplayState(forDisplayID: displayID))) ?? Data(#"{"schemaVersion":1,"error":"encodingFailed"}"#.utf8)
    }

    private func encodedRemoteDisplayStates() -> ScoreboardRemoteDisplayEncodedStates {
        encodedRemoteDisplayStates(forDisplayID: nil)
    }

    private func encodedRemoteDisplayStates(forDisplayID displayID: String?) -> ScoreboardRemoteDisplayEncodedStates {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let state = currentRemoteDisplayState(forDisplayID: displayID)
        return ScoreboardRemoteDisplayEncodedStates(
            v1: (try? encoder.encode(state)) ?? ScoreboardRemoteDisplayEncodedStates.encodingFailed.v1,
            v2: (try? encoder.encode(state.remoteDisplayV2Payload)) ?? ScoreboardRemoteDisplayEncodedStates.encodingFailed.v2
        )
    }

    private var remoteDisplayHostName: String {
        ScoreboardRemoteDisplayDeviceName.current ?? "Smart Scoreboard Operator"
    }

    private func configurePersistence() {
        let persistencePublishers: [AnyPublisher<Void, Never>] = [
            $selectedSport.map { _ in () }.eraseToAnyPublisher(),
            $customSportConfig.map { _ in () }.eraseToAnyPublisher(),
            $homeTeamName.map { _ in () }.eraseToAnyPublisher(),
            $guestTeamName.map { _ in () }.eraseToAnyPublisher(),
            $eventName.map { _ in () }.eraseToAnyPublisher(),
            $homeScore.map { _ in () }.eraseToAnyPublisher(),
            $guestScore.map { _ in () }.eraseToAnyPublisher(),
            $period.map { _ in () }.eraseToAnyPublisher(),
            $volleyballMatchFormat.map { _ in () }.eraseToAnyPublisher(),
            $volleyballSetResults.map { _ in () }.eraseToAnyPublisher(),
            $gameClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $defaultClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $isGameClockEnabled.map { _ in () }.eraseToAnyPublisher(),
            $pendingInjuryTimeMinutes.map { _ in () }.eraseToAnyPublisher(),
            $activeInjuryTimeMinutes.map { _ in () }.eraseToAnyPublisher(),
            $hasAppliedInjuryTimeThisPeriod.map { _ in () }.eraseToAnyPublisher(),
            $shotClockMilliseconds.map { _ in () }.eraseToAnyPublisher(),
            $defaultShotClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $activeShotClockPresetSeconds.map { _ in () }.eraseToAnyPublisher(),
            $possessionDirection.map { _ in () }.eraseToAnyPublisher(),
            $areSidesSwapped.map { _ in () }.eraseToAnyPublisher(),
            $controlBoardDisplayDirection.map { _ in () }.eraseToAnyPublisher(),
            $isPlayerTrackingEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isPlayerOverlayPaused.map { _ in () }.eraseToAnyPublisher(),
            $rosterSizePerTeam.map { _ in () }.eraseToAnyPublisher(),
            $displayLineupSize.map { _ in () }.eraseToAnyPublisher(),
            $playerLineupOverflowMode.map { _ in () }.eraseToAnyPublisher(),
            $playerLineupOverflowLogoOverride.map { _ in () }.eraseToAnyPublisher(),
            $playerLineupOverflowNoLogoOverride.map { _ in () }.eraseToAnyPublisher(),
            $playerLineupFadePageSeconds.map { _ in () }.eraseToAnyPublisher(),
            $playerLineupScrollSpeed.map { _ in () }.eraseToAnyPublisher(),
            $playerLineupScrollDirection.map { _ in () }.eraseToAnyPublisher(),
            $publicDisplayViewMode.map { _ in () }.eraseToAnyPublisher(),
            $playerViewRosterScope.map { _ in () }.eraseToAnyPublisher(),
            $playerFoulHighlightColor.map { _ in () }.eraseToAnyPublisher(),
            $isGameClockRedEnabled.map { _ in () }.eraseToAnyPublisher(),
            $gameClockRedThresholdSeconds.map { _ in () }.eraseToAnyPublisher(),
            $isShotClockRedEnabled.map { _ in () }.eraseToAnyPublisher(),
            $shotClockRedThresholdSeconds.map { _ in () }.eraseToAnyPublisher(),
            $homeSubstitutionsAllowed.map { _ in () }.eraseToAnyPublisher(),
            $guestSubstitutionsAllowed.map { _ in () }.eraseToAnyPublisher(),
            $homeSubstitutionsUsed.map { _ in () }.eraseToAnyPublisher(),
            $guestSubstitutionsUsed.map { _ in () }.eraseToAnyPublisher(),
            $pauseTimer.map { _ in () }.eraseToAnyPublisher(),
            $pauseDurationSeconds.map { _ in () }.eraseToAnyPublisher(),
            $isTeamPauseIndefinite.map { _ in () }.eraseToAnyPublisher(),
            $homePausesAllowed.map { _ in () }.eraseToAnyPublisher(),
            $guestPausesAllowed.map { _ in () }.eraseToAnyPublisher(),
            $homePausesUsed.map { _ in () }.eraseToAnyPublisher(),
            $guestPausesUsed.map { _ in () }.eraseToAnyPublisher(),
            $homeTeamFouls.map { _ in () }.eraseToAnyPublisher(),
            $guestTeamFouls.map { _ in () }.eraseToAnyPublisher(),
            $homeChessClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $guestChessClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $activeChessClockSide.map { _ in () }.eraseToAnyPublisher(),
            $chessClockPreset.map { _ in () }.eraseToAnyPublisher(),
            $selectedDebatePresetID.map { _ in () }.eraseToAnyPublisher(),
            $customDebatePreset.map { _ in () }.eraseToAnyPublisher(),
            $debateHomeSideLabel.map { _ in () }.eraseToAnyPublisher(),
            $debateGuestSideLabel.map { _ in () }.eraseToAnyPublisher(),
            $debateCurrentSegmentIndex.map { _ in () }.eraseToAnyPublisher(),
            $debatePrepHomeSeconds.map { _ in () }.eraseToAnyPublisher(),
            $debatePrepGuestSeconds.map { _ in () }.eraseToAnyPublisher(),
            $isDebatePrepTimeEnabled.map { _ in () }.eraseToAnyPublisher(),
            $debateActiveTimer.map { _ in () }.eraseToAnyPublisher(),
            $isDebatePrepClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $isDebateScoreTrackingEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isDebatePlayerTrackingEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isDebatePlayerFoulsEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isDebatePlayerCardsEnabled.map { _ in () }.eraseToAnyPublisher(),
            $homePenaltyTimers.map { _ in () }.eraseToAnyPublisher(),
            $guestPenaltyTimers.map { _ in () }.eraseToAnyPublisher(),
            $homeRoster.map { _ in () }.eraseToAnyPublisher(),
            $guestRoster.map { _ in () }.eraseToAnyPublisher(),
            $theme.map { _ in () }.eraseToAnyPublisher(),
            $showsLiveActivityWhenTimerRunning.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayBackgroundMode.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayBackgroundImage.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoStyle.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoBackgroundColor.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoSpeed.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoSize.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoOpacity.map { _ in () }.eraseToAnyPublisher(),
            $showsExternalDisplayDateTime.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayDateTimeFormat.map { _ in () }.eraseToAnyPublisher(),
            $showsExternalDisplayDateTimeSeconds.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayDirection.map { _ in () }.eraseToAnyPublisher(),
            $showsTeamLogos.map { _ in () }.eraseToAnyPublisher(),
            $showsEventLogo.map { _ in () }.eraseToAnyPublisher(),
            $homeTeamLogoImage.map { _ in () }.eraseToAnyPublisher(),
            $guestTeamLogoImage.map { _ in () }.eraseToAnyPublisher(),
            $eventLogoImage.map { _ in () }.eraseToAnyPublisher(),
            $isSoundEnabled.map { _ in () }.eraseToAnyPublisher(),
            $bypassedSoundEventsBySport.map { _ in () }.eraseToAnyPublisher(),
            $bypassedCompanionEventsBySport.map { _ in () }.eraseToAnyPublisher(),
            $soundAssignmentsBySport.map { _ in () }.eraseToAnyPublisher(),
            $keyboardShortcutsByAction.map { _ in () }.eraseToAnyPublisher(),
            $isCompanionVisible.map { _ in () }.eraseToAnyPublisher(),
            $isCompanionEnabled.map { _ in () }.eraseToAnyPublisher(),
            $companionHost.map { _ in () }.eraseToAnyPublisher(),
            $companionMode.map { _ in () }.eraseToAnyPublisher(),
            $companionSyncWithSound.map { _ in () }.eraseToAnyPublisher(),
            $companionPort.map { _ in () }.eraseToAnyPublisher(),
            $companionAssignmentsBySport.map { _ in () }.eraseToAnyPublisher(),
            $isClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $isShotClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $didCompleteSetup.map { _ in () }.eraseToAnyPublisher(),
            $currentGameDisplayName.map { _ in () }.eraseToAnyPublisher(),
            $areTipsEnabled.map { _ in () }.eraseToAnyPublisher(),
            $showGettingStartedOnStartup.map { _ in () }.eraseToAnyPublisher(),
            $didAutoShowGettingStarted.map { _ in () }.eraseToAnyPublisher(),
            $setupPresets.map { _ in () }.eraseToAnyPublisher(),
            $isWebAPIEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isWebControlEnabled.map { _ in () }.eraseToAnyPublisher(),
            $remoteControlAllowedDisplayIDs.map { _ in () }.eraseToAnyPublisher(),
            $webAPIUpdateMode.map { _ in () }.eraseToAnyPublisher(),
            $isWebAPIBroadcastControlEnabled.map { _ in () }.eraseToAnyPublisher(),
            $webAPIBroadcastEnabledDisplayCount.map { _ in () }.eraseToAnyPublisher(),
            $webAPIBroadcastDisplayModesByID.map { _ in () }.eraseToAnyPublisher(),
            $customDisplayModeTitlesByMode.map { _ in () }.eraseToAnyPublisher(),
            $isRemoteDisplayHostEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isRemoteDisplayViewerModeEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isRemoteDisplayIndividualControlEnabled.map { _ in () }.eraseToAnyPublisher(),
            $remoteDisplayNetworkMode.map { _ in () }.eraseToAnyPublisher(),
            $remoteDisplayCustomDisplayIDsByDisplayID.map { _ in () }.eraseToAnyPublisher()
        ]

        let stateChanges = Publishers.MergeMany(persistencePublishers)

        stateChanges
            .sink { [weak self] _ in
                if self?.isDelegatedSessionHost == true, self?.isApplyingSessionUpdate == false {
                    self?.sessionSyncRevision &+= 1
                }
                self?.scheduleStateSideEffectRefresh()
            }
            .store(in: &cancellables)

        stateChanges
            .throttle(for: .seconds(Self.automaticDiskWriteThrottleSeconds), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.persistState()
            }
            .store(in: &cancellables)
    }

    private func scheduleStateSideEffectRefresh() {
        guard !isStateSideEffectRefreshScheduled else {
            return
        }

        isStateSideEffectRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.isStateSideEffectRefreshScheduled = false
            self.refreshPrimaryTimerPersistence()
            self.refreshWebAPIState()
            self.refreshRemoteDisplayState()
            #if os(iOS)
            self.syncLiveActivityForCurrentState()
            #endif
        }
    }

    func exportPersistedStateData() throws -> Data {
        try JSONEncoder().encode(currentPersistedState().excludingRemoteDisplayPairingState)
    }

    func validatePersistedStateData(_ data: Data) throws {
        _ = try JSONDecoder().decode(PersistedState.self, from: data)
    }

    func restorePersistedStateData(_ data: Data) throws {
        let persistedState = try JSONDecoder().decode(PersistedState.self, from: data)
        clearPrimaryTimerPersistence()
        applyPersistedState(persistedState.excludingRemoteDisplayPairingState)
        persistState()
    }

    func resetToFactoryDefaults() {
        sessionDescriptor = nil
        sessionRecoveryRole = nil
        sessionAuthorityFenced = false
        sessionTransferCheckpoint = nil
        sessionTransferID = nil
        sessionTransferTargetID = nil
        try? FileManager.default.removeItem(at: ScoreboardSessionRecovery.url)
        clearPrimaryTimerPersistence()
        applyPersistedState(.factoryDefault)
        isWebControlEnabled = false
        remoteControlAllowedDisplayIDs.removeAll()
        ScoreboardPreferences.current.removeObject(forKey: "scoreboard.remoteControlAllowedDisplayIDs")
        ScoreboardPreferences.current.removeObject(forKey: ScoreboardControlBoardPreferences.storageKey)
        resetWebControlAPIKey()
        controlCommandResults.removeAll()
        ScoreboardPreferences.current.removeObject(forKey: persistenceKey)
        persistState()
    }

    func setGettingStartedStartupEnabled(_ isEnabled: Bool) {
        showGettingStartedOnStartup = isEnabled
        if isEnabled {
            didAutoShowGettingStarted = false
        }
    }

    func markGettingStartedAutoShown() {
        didAutoShowGettingStarted = true
        showGettingStartedOnStartup = false
    }

    func skipGettingStartedAndDisableTips() {
        areTipsEnabled = false
        showGettingStartedOnStartup = false
        didAutoShowGettingStarted = true
    }

    func replaceRosters(home: TeamRoster, guest: TeamRoster, rosterSize: Int) {
        let boundedSize = max(Self.minRosterSize, min(Self.maxRosterSize, rosterSize))
        rosterSizePerTeam = boundedSize
        displayLineupSize = max(1, min(boundedSize, displayLineupSize))
        homeRoster = normalizedRoster(home, fallbackCount: boundedSize)
        guestRoster = normalizedRoster(guest, fallbackCount: boundedSize)
    }

    private func loadPersistedState() {
        guard
            let data = ScoreboardPreferences.current.data(forKey: persistenceKey),
            let persistedState = try? JSONDecoder().decode(PersistedState.self, from: data)
        else {
            clearPrimaryTimerPersistence()
            return
        }

        applyPersistedState(persistedState)
        restorePrimaryTimerPersistenceIfNeeded()
    }

    private func applyPersistedState(_ persistedState: PersistedState) {
        performWithoutAuditLogging {
            pauseClock()
            pauseShotClock()
            stopTestSound()
            clearQueuedEventActions()
            dismissCompanionFailureNotice()
            resetRemoteDisplayWarningState()
            companionLastError = nil

            selectedSport = persistedState.selectedSport
            customSportConfig = persistedState.customSportConfig
            homeTeamName = persistedState.homeTeamName
            guestTeamName = persistedState.guestTeamName
            eventName = persistedState.eventName
            homeScore = persistedState.homeScore
            guestScore = persistedState.guestScore
            period = max(1, min(9, persistedState.period))
            volleyballMatchFormat = selectedSport == .volleyball ? persistedState.volleyballMatchFormat : .bestOf5
            if supportsPeriodWinTracking {
                volleyballSetResults = selectedSport == .volleyball
                    ? normalizedVolleyballSetResults(persistedState.volleyballSetResults, format: volleyballMatchFormat)
                    : normalizedPeriodWinResults(persistedState.volleyballSetResults, maximumPeriod: periodUpperBound)
            } else {
                volleyballSetResults = []
            }
            if supportsPeriodWinTracking {
                period = max(1, min(periodUpperBound, period))
            }
            gameClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(persistedState.gameClockSeconds) : boundedGameClockSeconds(persistedState.gameClockSeconds)
            defaultClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(persistedState.defaultClockSeconds) : boundedGameClockSeconds(persistedState.defaultClockSeconds)
            isGameClockEnabled = persistedState.isGameClockEnabled
            pendingInjuryTimeMinutes = boundedInjuryTimeMinutes(persistedState.pendingInjuryTimeMinutes)
            activeInjuryTimeMinutes = boundedInjuryTimeMinutes(persistedState.activeInjuryTimeMinutes)
            hasAppliedInjuryTimeThisPeriod = persistedState.hasAppliedInjuryTimeThisPeriod || activeInjuryTimeMinutes > 0
            normalizeInjuryTimeState()
            shotClockMilliseconds = boundedShotClockMilliseconds(persistedState.shotClockMilliseconds)
            defaultShotClockSeconds = boundedShotClockSeconds(persistedState.defaultShotClockSeconds)
            activeShotClockPresetSeconds = boundedShotClockSeconds(persistedState.activeShotClockPresetSeconds)
            possessionDirection = currentRules.supportsPossession ? persistedState.possessionDirection : .none
            controlBoardDisplayDirection = persistedState.controlBoardDisplayDirection
            areSidesSwapped = persistedState.areSidesSwapped
            isPlayerTrackingEnabled = selectedSport == .debate
                ? persistedState.isDebatePlayerTrackingEnabled
                : (currentRules.supportsPlayerTracking ? persistedState.isPlayerTrackingEnabled : false)
            isPlayerOverlayPaused = persistedState.isPlayerOverlayPaused
            rosterSizePerTeam = max(Self.minRosterSize, min(Self.maxRosterSize, persistedState.rosterSizePerTeam))
            displayLineupSize = max(1, min(rosterSizePerTeam, persistedState.displayLineupSize))
            playerLineupOverflowMode = persistedState.playerLineupOverflowMode
            playerLineupOverflowLogoOverride = persistedState.playerLineupOverflowLogoOverride
            playerLineupOverflowNoLogoOverride = persistedState.playerLineupOverflowNoLogoOverride
            playerLineupFadePageSeconds = max(Self.minPlayerLineupFadePageSeconds, min(Self.maxPlayerLineupFadePageSeconds, persistedState.playerLineupFadePageSeconds))
            playerLineupScrollSpeed = max(Self.minPlayerLineupScrollSpeed, min(Self.maxPlayerLineupScrollSpeed, persistedState.playerLineupScrollSpeed))
            playerLineupScrollDirection = persistedState.playerLineupScrollDirection
            publicDisplayViewMode = .scoreboard
            playerViewRosterScope = .fullRoster
            playerFoulHighlightColor = persistedState.playerFoulHighlightColor
            isGameClockRedEnabled = persistedState.isGameClockRedEnabled
            gameClockRedThresholdSeconds = boundedGameClockSeconds(persistedState.gameClockRedThresholdSeconds)
            isShotClockRedEnabled = persistedState.isShotClockRedEnabled
            shotClockRedThresholdSeconds = boundedShotClockSeconds(persistedState.shotClockRedThresholdSeconds)
            homeSubstitutionsAllowed = max(0, persistedState.homeSubstitutionsAllowed)
            guestSubstitutionsAllowed = max(0, persistedState.guestSubstitutionsAllowed)
            homeSubstitutionsUsed = max(0, min(homeSubstitutionsAllowed, persistedState.homeSubstitutionsUsed))
            guestSubstitutionsUsed = max(0, min(guestSubstitutionsAllowed, persistedState.guestSubstitutionsUsed))
            pauseDurationSeconds = max(1, min(Self.maxGameClockSeconds, persistedState.pauseDurationSeconds ?? (selectedSport == .volleyball ? 30 : 60)))
            isTeamPauseIndefinite = persistedState.isTeamPauseIndefinite ?? false
            pauseTimer = normalizedPauseTimer(persistedState.pauseTimer, preserveRunning: false)
            accumulatedPauseElapsed = 0
            homePausesAllowed = max(0, persistedState.homePausesAllowed)
            guestPausesAllowed = max(0, persistedState.guestPausesAllowed)
            homePausesUsed = max(0, min(homePausesAllowed, persistedState.homePausesUsed))
            guestPausesUsed = max(0, min(guestPausesAllowed, persistedState.guestPausesUsed))
            if !currentRules.showsPauseTracking {
                clearPauseTracking()
            }
            normalizeInjuryTimeState()
            homeTeamFouls = max(0, persistedState.homeTeamFouls)
            guestTeamFouls = max(0, persistedState.guestTeamFouls)
            homeChessClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(persistedState.homeChessClockSeconds) : boundedGameClockSeconds(persistedState.homeChessClockSeconds)
            guestChessClockSeconds = isDebateMode ? boundedDebateSegmentSeconds(persistedState.guestChessClockSeconds) : boundedGameClockSeconds(persistedState.guestChessClockSeconds)
            activeChessClockSide = persistedState.activeChessClockSide
            chessClockPreset = persistedState.chessClockPreset
            selectedDebatePresetID = persistedState.selectedDebatePresetID
            customDebatePreset = persistedState.customDebatePreset
            debateHomeSideLabel = persistedState.debateHomeSideLabel
            debateGuestSideLabel = persistedState.debateGuestSideLabel
            debateCurrentSegmentIndex = persistedState.debateCurrentSegmentIndex
            isDebatePrepTimeEnabled = persistedState.isDebatePrepTimeEnabled
            debatePrepHomeSeconds = isDebatePrepTimeEnabled ? boundedGameClockSeconds(persistedState.debatePrepHomeSeconds) : 0
            debatePrepGuestSeconds = isDebatePrepTimeEnabled ? boundedGameClockSeconds(persistedState.debatePrepGuestSeconds) : 0
            debateActiveTimer = persistedState.debateActiveTimer
            isDebatePrepClockRunning = persistedState.isDebatePrepClockRunning
            isDebateScoreTrackingEnabled = persistedState.isDebateScoreTrackingEnabled
            isDebatePlayerTrackingEnabled = persistedState.isDebatePlayerTrackingEnabled
            isDebatePlayerFoulsEnabled = persistedState.isDebatePlayerFoulsEnabled
            isDebatePlayerCardsEnabled = persistedState.isDebatePlayerCardsEnabled
            homePenaltyTimers = supportsHockeyPenalties ? persistedState.homePenaltyTimers : []
            guestPenaltyTimers = supportsHockeyPenalties ? persistedState.guestPenaltyTimers : []
            homeRoster = normalizedRoster(persistedState.homeRoster, fallbackCount: rosterSizePerTeam)
            guestRoster = normalizedRoster(persistedState.guestRoster, fallbackCount: rosterSizePerTeam)
            theme = persistedState.theme
            externalDisplayBackgroundImage = nil
            externalDisplayAnimatedLogoStyle = persistedState.externalDisplayAnimatedLogoStyle
            externalDisplayAnimatedLogoBackgroundColor = persistedState.externalDisplayAnimatedLogoBackgroundColor
            setExternalDisplayAnimatedLogoSpeed(persistedState.externalDisplayAnimatedLogoSpeed)
            setExternalDisplayAnimatedLogoSize(persistedState.externalDisplayAnimatedLogoSize)
            setExternalDisplayAnimatedLogoOpacity(persistedState.externalDisplayAnimatedLogoOpacity)
            showsExternalDisplayDateTime = persistedState.showsExternalDisplayDateTime
            externalDisplayDateTimeFormat = persistedState.externalDisplayDateTimeFormat
            showsExternalDisplayDateTimeSeconds = persistedState.showsExternalDisplayDateTimeSeconds
            externalDisplayDirection = persistedState.externalDisplayDirection
            showsTeamLogos = persistedState.showsTeamLogos
            showsEventLogo = persistedState.showsEventLogo
            homeTeamLogoImage = nil
            guestTeamLogoImage = nil
            eventLogoImage = nil
            externalDisplayBackgroundMode = persistedState.externalDisplayBackgroundMode == .image || persistedState.externalDisplayBackgroundMode == .animatedLogo ? .blurred : persistedState.externalDisplayBackgroundMode
            isSoundEnabled = persistedState.isSoundEnabled
            bypassedSoundEventsBySport = persistedState.bypassedSoundEventsBySport
            bypassedCompanionEventsBySport = persistedState.bypassedCompanionEventsBySport
            soundAssignmentsBySport = normalizedSoundAssignmentsBySport(persistedState.soundAssignmentsBySport)
            keyboardShortcutsByAction = Self.normalizedKeyboardShortcuts(persistedState.keyboardShortcutsByAction)
            isCompanionVisible = persistedState.isCompanionVisible
            isCompanionEnabled = persistedState.isCompanionVisible && persistedState.isCompanionEnabled
            companionSyncWithSound = persistedState.companionSyncWithSound
            companionHost = persistedState.companionHost
            companionMode = persistedState.companionMode
            companionPort = persistedState.companionPort == 0 ? persistedState.companionMode.defaultPort : persistedState.companionPort
            companionAssignmentsBySport = normalizedCompanionAssignmentsBySport(persistedState.companionAssignmentsBySport)
            didCompleteSetup = persistedState.didCompleteSetup
            setupPresets = persistedState.setupPresets
            isWebAPIEnabled = persistedState.isWebAPIEnabled
            webAPIUpdateMode = persistedState.webAPIUpdateMode
            isWebAPIBroadcastControlEnabled = persistedState.isWebAPIBroadcastControlEnabled
            webAPIBroadcastEnabledDisplayCount = Self.boundedWebAPIBroadcastEnabledDisplayCount(persistedState.webAPIBroadcastEnabledDisplayCount)
            webAPIBroadcastDisplayModesByID = Self.normalizedWebAPIBroadcastDisplayModes(persistedState.webAPIBroadcastDisplayModesByID)
            customDisplayModeTitlesByMode = Self.normalizedCustomDisplayModeTitles(persistedState.customDisplayModeTitlesByMode)
            isRemoteDisplayHostEnabled = persistedState.isRemoteDisplayHostEnabled
            isRemoteDisplayViewerModeEnabled = persistedState.isRemoteDisplayViewerModeEnabled
            isRemoteDisplayIndividualControlEnabled = persistedState.isRemoteDisplayIndividualControlEnabled
            remoteDisplayNetworkMode = persistedState.remoteDisplayNetworkMode
            if !currentRules.supportsShotClock {
                defaultShotClockSeconds = 0
                activeShotClockPresetSeconds = 0
                shotClockMilliseconds = 0
            }
            if selectedSport != .volleyball {
                isGameClockEnabled = selectedSport == .custom ? isGameClockEnabled : true
            }
            if isDebateMode {
                let preset = currentDebatePreset
                debateCurrentSegmentIndex = min(debateCurrentSegmentIndex, max(preset.segments.count - 1, 0))
                configureDebateSegment(index: debateCurrentSegmentIndex, preserveRunningState: true)
                if debateActiveTimer != .segment {
                    pauseClock()
                }
                if !isDebatePlayerTrackingEnabled {
                    isPlayerTrackingEnabled = false
                }
            }
            isClockRunning = false
            isShotClockRunning = false
            isDebatePrepClockRunning = false
            areTipsEnabled = persistedState.areTipsEnabled
            showGettingStartedOnStartup = persistedState.showGettingStartedOnStartup
            didAutoShowGettingStarted = persistedState.didAutoShowGettingStarted
            updateTimerState()
            refreshWebAPIState()
            refreshRemoteDisplayState()
        }
    }

    private func persistState() {
        guard !isRemoteControlProxy else { return }
        if isSessionAuthority, !isApplyingSessionUpdate, let descriptor = sessionDescriptor {
            do {
                let checkpoint = try makeSessionCheckpoint(descriptor: descriptor)
                if isDelegatedSessionHost {
                    try ScoreboardHostedMatchStorage.save(checkpoint)
                    hostedCheckpointPersistedRevision = sessionSyncRevision
                }
                try ScoreboardSessionRecovery(role: .host, descriptor: descriptor,
                                              checkpoint: checkpoint, transferID: nil).save()
                sessionTransferCheckpoint = checkpoint
            } catch {
                sessionStatusMessage = "Session recovery could not be saved: \(error.localizedDescription)"
            }
        }
        guard !isDelegatedSessionHost else { return }
        guard let data = try? encodedPersistedStateData() else {
            return
        }

        ScoreboardPreferences.current.set(data, forKey: persistenceKey)
    }

    private func refreshPrimaryTimerPersistence() {
        guard isSessionAuthority, !isDelegatedSessionHost else { return }
        guard let snapshot = currentPrimaryTimerPersistenceSnapshot(now: Date()) else {
            clearPrimaryTimerPersistence()
            return
        }

        guard snapshot.signature != lastPrimaryTimerPersistenceSignature else {
            return
        }

        if let data = try? JSONEncoder().encode(snapshot) {
            ScoreboardPreferences.current.set(data, forKey: primaryTimerPersistenceKey)
            lastPrimaryTimerPersistenceSignature = snapshot.signature
        }
    }

    private func clearPrimaryTimerPersistence() {
        guard !isRemoteControlProxy, !isDelegatedSessionHost else { return }
        ScoreboardPreferences.current.removeObject(forKey: primaryTimerPersistenceKey)
        lastPrimaryTimerPersistenceSignature = nil
    }

    private func restorePrimaryTimerPersistenceIfNeeded() {
        guard sessionDescriptor == nil else { return }
        guard pauseTimer == nil else { clearPrimaryTimerPersistence(); return }
        guard
            let data = ScoreboardPreferences.current.data(forKey: primaryTimerPersistenceKey),
            let snapshot = try? JSONDecoder().decode(PrimaryTimerPersistenceSnapshot.self, from: data)
        else {
            return
        }

        switch snapshot.kind {
        case .standardClock:
            guard showsGameClock, !usesChessClocks else {
                clearPrimaryTimerPersistence()
                return
            }
            gameClockSeconds = boundedRuntimeClockSeconds(snapshot.gameClockSeconds)
            isClockRunning = gameClockSeconds > 0 || gameClockMode == .countUp
            isDebatePrepClockRunning = false

        case .dualClock:
            guard usesChessClocks else {
                clearPrimaryTimerPersistence()
                return
            }
            homeChessClockSeconds = boundedRuntimeClockSeconds(snapshot.homeChessClockSeconds)
            guestChessClockSeconds = boundedRuntimeClockSeconds(snapshot.guestChessClockSeconds)
            activeChessClockSide = snapshot.activeChessClockSide ?? activeChessClockSide ?? .home
            isClockRunning = homeChessClockSeconds > 0 || guestChessClockSeconds > 0
            isDebatePrepClockRunning = false

        case .debatePrep:
            guard isDebateMode, isDebatePrepTimeEnabled else {
                clearPrimaryTimerPersistence()
                return
            }
            debateActiveTimer = snapshot.debateActiveTimer
            debatePrepHomeSeconds = boundedGameClockSeconds(snapshot.debatePrepHomeSeconds)
            debatePrepGuestSeconds = boundedGameClockSeconds(snapshot.debatePrepGuestSeconds)
            isClockRunning = false
            switch debateActiveTimer {
            case .prepHome:
                isDebatePrepClockRunning = debatePrepHomeSeconds > 0
            case .prepGuest:
                isDebatePrepClockRunning = debatePrepGuestSeconds > 0
            case .segment:
                isDebatePrepClockRunning = false
            }
        }

        pendingInjuryTimeMinutes = boundedInjuryTimeMinutes(snapshot.pendingInjuryTimeMinutes ?? pendingInjuryTimeMinutes)
        activeInjuryTimeMinutes = boundedInjuryTimeMinutes(snapshot.activeInjuryTimeMinutes ?? activeInjuryTimeMinutes)
        hasAppliedInjuryTimeThisPeriod = snapshot.hasAppliedInjuryTimeThisPeriod ?? (hasAppliedInjuryTimeThisPeriod || activeInjuryTimeMinutes > 0)
        normalizeInjuryTimeState()
        lastTimerFireDate = Date(timeIntervalSince1970: snapshot.savedAtUnixTime)
        lastPrimaryTimerPersistenceSignature = snapshot.signature
        updateTimerState()
        reconcileRunningTimersWithWallClock()
        refreshPrimaryTimerPersistence()
    }

    private func currentPrimaryTimerPersistenceSnapshot(now: Date) -> PrimaryTimerPersistenceSnapshot? {
        guard isGameRunning else {
            return nil
        }

        let roundedNow = floor(now.timeIntervalSince1970)
        if isDebatePrepClockRunning {
            let signature: String
            switch debateActiveTimer {
            case .prepHome:
                signature = "debatePrep-home-\(Int(roundedNow) + debatePrepHomeSeconds)-\(debatePrepGuestSeconds)"
            case .prepGuest:
                signature = "debatePrep-guest-\(Int(roundedNow) + debatePrepGuestSeconds)-\(debatePrepHomeSeconds)"
            case .segment:
                return nil
            }

            return PrimaryTimerPersistenceSnapshot(
                kind: .debatePrep,
                savedAtUnixTime: now.timeIntervalSince1970,
                signature: signature,
                gameClockSeconds: gameClockSeconds,
                homeChessClockSeconds: homeChessClockSeconds,
                guestChessClockSeconds: guestChessClockSeconds,
                activeChessClockSide: activeChessClockSide,
                debateActiveTimer: debateActiveTimer,
                debatePrepHomeSeconds: debatePrepHomeSeconds,
                debatePrepGuestSeconds: debatePrepGuestSeconds,
                pendingInjuryTimeMinutes: pendingInjuryTimeMinutes,
                activeInjuryTimeMinutes: activeInjuryTimeMinutes,
                hasAppliedInjuryTimeThisPeriod: hasAppliedInjuryTimeThisPeriod
            )
        }

        if isClockRunning, usesChessClocks {
            let activeSeconds: Int
            let inactiveSeconds: Int
            switch activeChessClockSide {
            case .home:
                activeSeconds = homeChessClockSeconds
                inactiveSeconds = guestChessClockSeconds
            case .guest:
                activeSeconds = guestChessClockSeconds
                inactiveSeconds = homeChessClockSeconds
            case .none:
                return nil
            }
            let signature = "dual-\(activeChessClockSide?.rawValue ?? "none")-\(Int(roundedNow) + activeSeconds)-\(inactiveSeconds)"
            return PrimaryTimerPersistenceSnapshot(
                kind: .dualClock,
                savedAtUnixTime: now.timeIntervalSince1970,
                signature: signature,
                gameClockSeconds: gameClockSeconds,
                homeChessClockSeconds: homeChessClockSeconds,
                guestChessClockSeconds: guestChessClockSeconds,
                activeChessClockSide: activeChessClockSide,
                debateActiveTimer: debateActiveTimer,
                debatePrepHomeSeconds: debatePrepHomeSeconds,
                debatePrepGuestSeconds: debatePrepGuestSeconds,
                pendingInjuryTimeMinutes: pendingInjuryTimeMinutes,
                activeInjuryTimeMinutes: activeInjuryTimeMinutes,
                hasAppliedInjuryTimeThisPeriod: hasAppliedInjuryTimeThisPeriod
            )
        }

        guard isClockRunning else {
            return nil
        }

        let signature: String
        switch gameClockMode {
        case .countdown:
            signature = "standard-countdown-\(Int(roundedNow) + gameClockSeconds)-injury-\(pendingInjuryTimeMinutes)-\(activeInjuryTimeMinutes)-\(hasAppliedInjuryTimeThisPeriod)"
        case .countUp:
            signature = "standard-countUp-\(Int(roundedNow) - gameClockSeconds)-injury-\(pendingInjuryTimeMinutes)-\(activeInjuryTimeMinutes)-\(hasAppliedInjuryTimeThisPeriod)"
        }

        return PrimaryTimerPersistenceSnapshot(
            kind: .standardClock,
            savedAtUnixTime: now.timeIntervalSince1970,
            signature: signature,
            gameClockSeconds: gameClockSeconds,
            homeChessClockSeconds: homeChessClockSeconds,
            guestChessClockSeconds: guestChessClockSeconds,
            activeChessClockSide: activeChessClockSide,
            debateActiveTimer: debateActiveTimer,
            debatePrepHomeSeconds: debatePrepHomeSeconds,
            debatePrepGuestSeconds: debatePrepGuestSeconds,
            pendingInjuryTimeMinutes: pendingInjuryTimeMinutes,
            activeInjuryTimeMinutes: activeInjuryTimeMinutes,
            hasAppliedInjuryTimeThisPeriod: hasAppliedInjuryTimeThisPeriod
        )
    }

    private func encodedPersistedStateData() throws -> Data {
        try JSONEncoder().encode(currentPersistedState())
    }

    private func currentPersistedState() -> PersistedState {
        PersistedState(
            selectedSport: selectedSport,
            customSportConfig: customSportConfig,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            eventName: eventName,
            homeScore: homeScore,
            guestScore: guestScore,
            period: period,
            volleyballMatchFormat: volleyballMatchFormat,
            volleyballSetResults: volleyballSetResults,
            gameClockSeconds: gameClockSeconds,
            defaultClockSeconds: defaultClockSeconds,
            isGameClockEnabled: isGameClockEnabled,
            pendingInjuryTimeMinutes: pendingInjuryTimeMinutes,
            activeInjuryTimeMinutes: activeInjuryTimeMinutes,
            hasAppliedInjuryTimeThisPeriod: hasAppliedInjuryTimeThisPeriod,
            shotClockMilliseconds: shotClockMilliseconds,
            defaultShotClockSeconds: defaultShotClockSeconds,
            activeShotClockPresetSeconds: activeShotClockPresetSeconds,
            possessionDirection: possessionDirection,
            areSidesSwapped: areSidesSwapped,
            controlBoardDisplayDirection: controlBoardDisplayDirection,
            isPlayerTrackingEnabled: isPlayerTrackingEnabled,
            isPlayerOverlayPaused: isPlayerOverlayPaused,
            rosterSizePerTeam: rosterSizePerTeam,
            displayLineupSize: displayLineupSize,
            playerLineupOverflowMode: playerLineupOverflowMode,
            playerLineupOverflowLogoOverride: playerLineupOverflowLogoOverride,
            playerLineupOverflowNoLogoOverride: playerLineupOverflowNoLogoOverride,
            playerLineupFadePageSeconds: playerLineupFadePageSeconds,
            playerLineupScrollSpeed: playerLineupScrollSpeed,
            playerLineupScrollDirection: playerLineupScrollDirection,
            playerViewRosterScope: .fullRoster,
            playerFoulHighlightColor: playerFoulHighlightColor,
            isGameClockRedEnabled: isGameClockRedEnabled,
            gameClockRedThresholdSeconds: gameClockRedThresholdSeconds,
            isShotClockRedEnabled: isShotClockRedEnabled,
            shotClockRedThresholdSeconds: shotClockRedThresholdSeconds,
            homeSubstitutionsAllowed: homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: guestSubstitutionsAllowed,
            homeSubstitutionsUsed: homeSubstitutionsUsed,
            guestSubstitutionsUsed: guestSubstitutionsUsed,
            homePausesAllowed: homePausesAllowed,
            guestPausesAllowed: guestPausesAllowed,
            homePausesUsed: homePausesUsed,
            guestPausesUsed: guestPausesUsed,
            homeTeamFouls: homeTeamFouls,
            guestTeamFouls: guestTeamFouls,
            homeChessClockSeconds: homeChessClockSeconds,
            guestChessClockSeconds: guestChessClockSeconds,
            activeChessClockSide: activeChessClockSide,
            chessClockPreset: chessClockPreset,
            selectedDebatePresetID: selectedDebatePresetID,
            customDebatePreset: customDebatePreset,
            debateHomeSideLabel: debateHomeSideLabel,
            debateGuestSideLabel: debateGuestSideLabel,
            debateCurrentSegmentIndex: debateCurrentSegmentIndex,
            debatePrepHomeSeconds: debatePrepHomeSeconds,
            debatePrepGuestSeconds: debatePrepGuestSeconds,
            isDebatePrepTimeEnabled: isDebatePrepTimeEnabled,
            debateActiveTimer: debateActiveTimer,
            isDebatePrepClockRunning: isDebatePrepClockRunning,
            isDebateScoreTrackingEnabled: isDebateScoreTrackingEnabled,
            isDebatePlayerTrackingEnabled: isDebatePlayerTrackingEnabled,
            isDebatePlayerFoulsEnabled: isDebatePlayerFoulsEnabled,
            isDebatePlayerCardsEnabled: isDebatePlayerCardsEnabled,
            homePenaltyTimers: supportsHockeyPenalties ? homePenaltyTimers : [],
            guestPenaltyTimers: supportsHockeyPenalties ? guestPenaltyTimers : [],
            homeRoster: homeRoster,
            guestRoster: guestRoster,
            theme: theme,
            showsLiveActivityWhenTimerRunning: showsLiveActivityWhenTimerRunning,
            externalDisplayBackgroundMode: externalDisplayBackgroundMode == .image || externalDisplayBackgroundMode == .animatedLogo ? .blurred : externalDisplayBackgroundMode,
            externalDisplayAnimatedLogoStyle: externalDisplayAnimatedLogoStyle,
            externalDisplayAnimatedLogoBackgroundColor: externalDisplayAnimatedLogoBackgroundColor,
            externalDisplayAnimatedLogoSpeed: externalDisplayAnimatedLogoSpeed,
            externalDisplayAnimatedLogoSize: externalDisplayAnimatedLogoSize,
            externalDisplayAnimatedLogoOpacity: externalDisplayAnimatedLogoOpacity,
            showsExternalDisplayDateTime: showsExternalDisplayDateTime,
            externalDisplayDateTimeFormat: externalDisplayDateTimeFormat,
            showsExternalDisplayDateTimeSeconds: showsExternalDisplayDateTimeSeconds,
            externalDisplayDirection: externalDisplayDirection,
            showsTeamLogos: showsTeamLogos,
            showsEventLogo: showsEventLogo,
            isSoundEnabled: isSoundEnabled,
            bypassedSoundEventsBySport: bypassedSoundEventsBySport,
            bypassedCompanionEventsBySport: bypassedCompanionEventsBySport,
            soundAssignmentsBySport: soundAssignmentsBySport,
            keyboardShortcutsByAction: keyboardShortcutsByAction,
            isCompanionVisible: isCompanionVisible,
            isCompanionEnabled: isCompanionEnabled,
            companionHost: companionHost,
            companionMode: companionMode,
            companionSyncWithSound: companionSyncWithSound,
            companionPort: companionPort,
            companionAssignmentsBySport: companionAssignmentsBySport,
            didCompleteSetup: didCompleteSetup,
            areTipsEnabled: areTipsEnabled,
            showGettingStartedOnStartup: showGettingStartedOnStartup,
            didAutoShowGettingStarted: didAutoShowGettingStarted,
            setupPresets: setupPresets,
            isWebAPIEnabled: isWebAPIEnabled,
            webAPIUpdateMode: webAPIUpdateMode,
            isWebAPIBroadcastControlEnabled: isWebAPIBroadcastControlEnabled,
            webAPIBroadcastEnabledDisplayCount: webAPIBroadcastEnabledDisplayCount,
            webAPIBroadcastDisplayModesByID: webAPIBroadcastDisplayModesByID,
            customDisplayModeTitlesByMode: customDisplayModeTitlesByMode,
            isRemoteDisplayHostEnabled: isRemoteDisplayHostEnabled,
            isRemoteDisplayViewerModeEnabled: isRemoteDisplayViewerModeEnabled,
            isRemoteDisplayIndividualControlEnabled: isRemoteDisplayIndividualControlEnabled,
            remoteDisplayNetworkMode: remoteDisplayNetworkMode,
            pauseDurationSeconds: pauseDurationSeconds,
            pauseTimer: pauseTimer,
            isTeamPauseIndefinite: isTeamPauseIndefinite
        )
    }

    private func normalizedSoundAssignmentsBySport(_ assignmentsBySport: [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]]) -> [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]] {
        var resolved = Self.defaultSoundAssignmentsBySport
        for sport in SportType.allCases {
            var sportAssignments = Self.defaultSoundAssignments
            for (event, effect) in assignmentsBySport[sport] ?? [:] {
                guard event != .general else { continue }
                sportAssignments[event] = effect
            }
            resolved[sport] = sportAssignments
        }
        return resolved
    }

    static func normalizedKeyboardShortcuts(_ assignments: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut]) -> [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut] {
        var resolved: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut] = [:]
        var usedShortcuts = Set<ScoreboardKeyboardShortcut>()
        for action in ScoreboardKeyboardShortcutAction.allCases {
            guard let shortcut = assignments[action]?.normalized, !usedShortcuts.contains(shortcut) else {
                continue
            }
            resolved[action] = shortcut
            usedShortcuts.insert(shortcut)
        }
        return resolved
    }

    private func normalizedCompanionAssignmentsBySport(_ assignmentsBySport: [SportType: [ScoreboardSoundEvent: String]]) -> [SportType: [ScoreboardSoundEvent: String]] {
        var resolved: [SportType: [ScoreboardSoundEvent: String]] = [:]
        for sport in SportType.allCases {
            var sportAssignments: [ScoreboardSoundEvent: String] = [:]
            for (event, locationText) in assignmentsBySport[sport] ?? [:] {
                guard event != .general, !locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                sportAssignments[event] = locationText
            }
            if !sportAssignments.isEmpty {
                resolved[sport] = sportAssignments
            }
        }
        return resolved
    }

    private var activeLineupCountLimit: Int {
        min(displayLineupSize, rosterSizePerTeam)
    }

    private func resetPlayerTrackingForNewGame() {
        resetRosterForNewGame(.home)
        resetRosterForNewGame(.guest)
    }

    private func resetRosterForNewGame(_ side: TeamSide) {
        updateRoster(for: side) { roster in
            for index in roster.players.indices {
                roster.players[index].foulCount = 0
                roster.players[index].cardStatus = .none
                roster.players[index].isInActiveLineup = index < activeLineupCountLimit
            }
        }
    }

    private func resizeRoster(for side: TeamSide, to count: Int) {
        updateRoster(for: side) { roster in
            if roster.players.count > count {
                roster.players = Array(roster.players.prefix(count))
            } else if roster.players.count < count {
                let startIndex = roster.players.count
                roster.players.append(contentsOf: (startIndex..<count).map { index in
                    TrackedPlayer(number: "\(index + 1)", isInActiveLineup: index < activeLineupCountLimit)
                })
            }

            normalizeActiveLineup(in: &roster)
        }
    }

    private func activeLineupPlayers(for side: TeamSide) -> [TrackedPlayer] {
        Array(roster(for: side).players.filter(\.isInActiveLineup).prefix(activeLineupCountLimit))
    }

    private func roster(for side: TeamSide) -> TeamRoster {
        switch side {
        case .home:
            return homeRoster
        case .guest:
            return guestRoster
        }
    }

    private func updateRoster(for side: TeamSide, mutate: (inout TeamRoster) -> Void) {
        switch side {
        case .home:
            var roster = homeRoster
            mutate(&roster)
            let normalized = normalizedRoster(roster, fallbackCount: rosterSizePerTeam)
            if normalized != homeRoster {
                homeRoster = normalized
            }
        case .guest:
            var roster = guestRoster
            mutate(&roster)
            let normalized = normalizedRoster(roster, fallbackCount: rosterSizePerTeam)
            if normalized != guestRoster {
                guestRoster = normalized
            }
        }
    }

    private func normalizedRoster(_ roster: TeamRoster?, fallbackCount: Int) -> TeamRoster {
        var resolved = roster ?? TeamRoster(players: Self.makeDefaultRosterPlayers(count: fallbackCount))

        if resolved.players.count > fallbackCount {
            resolved.players = Array(resolved.players.prefix(fallbackCount))
        } else if resolved.players.count < fallbackCount {
            let startIndex = resolved.players.count
            resolved.players.append(contentsOf: (startIndex..<fallbackCount).map { index in
                TrackedPlayer(number: "\(index + 1)", isInActiveLineup: index < activeLineupCountLimit)
            })
        }

        for index in resolved.players.indices {
            resolved.players[index].number = normalizedPlayerNumber(resolved.players[index].number)
            resolved.players[index].name = normalizedPlayerName(resolved.players[index].name)
            resolved.players[index].foulCount = max(0, resolved.players[index].foulCount)
        }

        normalizeActiveLineup(in: &resolved)
        return resolved
    }

    private func normalizedVolleyballSetResults(_ results: [VolleyballSetResult], format: VolleyballMatchFormat) -> [VolleyballSetResult] {
        normalizedPeriodWinResults(results, maximumPeriod: format.maximumSets)
    }

    private func normalizedPeriodWinResults(_ results: [VolleyballSetResult], maximumPeriod: Int) -> [VolleyballSetResult] {
        var seenSetNumbers = Set<Int>()
        return results
            .filter { result in
                result.setNumber >= 1 &&
                    result.setNumber <= maximumPeriod &&
                    result.homeScore >= 0 &&
                    result.guestScore >= 0 &&
                    seenSetNumbers.insert(result.setNumber).inserted
            }
            .sorted { $0.setNumber < $1.setNumber }
    }

    private func normalizeActiveLineup(in roster: inout TeamRoster) {
        let activeIndices = roster.players.indices.filter { roster.players[$0].isInActiveLineup }
        if activeIndices.count > activeLineupCountLimit {
            for index in activeIndices.dropFirst(activeLineupCountLimit) {
                roster.players[index].isInActiveLineup = false
            }
        }
    }
}

private enum PrimaryTimerPersistenceKind: String, Codable {
    case standardClock
    case dualClock
    case debatePrep
}

private struct PrimaryTimerPersistenceSnapshot: Codable {
    var kind: PrimaryTimerPersistenceKind
    var savedAtUnixTime: TimeInterval
    var signature: String
    var gameClockSeconds: Int
    var homeChessClockSeconds: Int
    var guestChessClockSeconds: Int
    var activeChessClockSide: TeamSide?
    var debateActiveTimer: DebateActiveTimer
    var debatePrepHomeSeconds: Int
    var debatePrepGuestSeconds: Int
    var pendingInjuryTimeMinutes: Int?
    var activeInjuryTimeMinutes: Int?
    var hasAppliedInjuryTimeThisPeriod: Bool?
}

private struct PersistedState: Codable {
    var selectedSport: SportType
    var customSportConfig: CustomSportConfig
    var homeTeamName: String
    var guestTeamName: String
    var eventName: String
    var homeScore: Int
    var guestScore: Int
    var period: Int
    var volleyballMatchFormat: VolleyballMatchFormat
    var volleyballSetResults: [VolleyballSetResult]
    var gameClockSeconds: Int
    var defaultClockSeconds: Int
    var isGameClockEnabled: Bool
    var pendingInjuryTimeMinutes: Int
    var activeInjuryTimeMinutes: Int
    var hasAppliedInjuryTimeThisPeriod: Bool
    var shotClockMilliseconds: Int
    var defaultShotClockSeconds: Int
    var activeShotClockPresetSeconds: Int
    var possessionDirection: PossessionDirection
    var areSidesSwapped: Bool
    var controlBoardDisplayDirection: ScoreboardDisplayDirection
    var isPlayerTrackingEnabled: Bool
    var isPlayerOverlayPaused: Bool
    var rosterSizePerTeam: Int
    var displayLineupSize: Int
    var playerLineupOverflowMode: PlayerLineupOverflowMode
    var playerLineupOverflowLogoOverride: PlayerLineupOverflowMode?
    var playerLineupOverflowNoLogoOverride: PlayerLineupOverflowMode?
    var playerLineupFadePageSeconds: Int
    var playerLineupScrollSpeed: Int
    var playerLineupScrollDirection: PlayerLineupScrollDirection
    var playerViewRosterScope: PlayerViewRosterScope
    var playerFoulHighlightColor: PlayerFoulHighlightColor
    var isGameClockRedEnabled: Bool
    var gameClockRedThresholdSeconds: Int
    var isShotClockRedEnabled: Bool
    var shotClockRedThresholdSeconds: Int
    var homeSubstitutionsAllowed: Int
    var guestSubstitutionsAllowed: Int
    var homeSubstitutionsUsed: Int
    var guestSubstitutionsUsed: Int
    var homePausesAllowed: Int
    var guestPausesAllowed: Int
    var homePausesUsed: Int
    var guestPausesUsed: Int
    var homeTeamFouls: Int
    var guestTeamFouls: Int
    var homeChessClockSeconds: Int
    var guestChessClockSeconds: Int
    var activeChessClockSide: TeamSide?
    var chessClockPreset: ChessClockPreset
    var selectedDebatePresetID: String
    var customDebatePreset: DebatePreset
    var debateHomeSideLabel: String
    var debateGuestSideLabel: String
    var debateCurrentSegmentIndex: Int
    var debatePrepHomeSeconds: Int
    var debatePrepGuestSeconds: Int
    var isDebatePrepTimeEnabled: Bool
    var debateActiveTimer: DebateActiveTimer
    var isDebatePrepClockRunning: Bool
    var isDebateScoreTrackingEnabled: Bool
    var isDebatePlayerTrackingEnabled: Bool
    var isDebatePlayerFoulsEnabled: Bool
    var isDebatePlayerCardsEnabled: Bool
    var homePenaltyTimers: [HockeyPenaltyTimer]
    var guestPenaltyTimers: [HockeyPenaltyTimer]
    var homeRoster: TeamRoster
    var guestRoster: TeamRoster
    var theme: ScoreboardTheme
    var showsLiveActivityWhenTimerRunning: Bool
    var externalDisplayBackgroundMode: ExternalDisplayBackgroundMode
    var externalDisplayAnimatedLogoStyle: ExternalDisplayAnimatedLogoStyle
    var externalDisplayAnimatedLogoBackgroundColor: ExternalDisplayAnimatedLogoBackgroundColor
    var externalDisplayAnimatedLogoSpeed: Int
    var externalDisplayAnimatedLogoSize: Int
    var externalDisplayAnimatedLogoOpacity: Double
    var showsExternalDisplayDateTime: Bool
    var externalDisplayDateTimeFormat: ExternalDisplayDateTimeFormat
    var showsExternalDisplayDateTimeSeconds: Bool
    var externalDisplayDirection: ScoreboardDisplayDirection
    var showsTeamLogos: Bool
    var showsEventLogo: Bool
    var isSoundEnabled: Bool
    var bypassedSoundEventsBySport: [SportType: Set<ScoreboardSoundEvent>]
    var bypassedCompanionEventsBySport: [SportType: Set<ScoreboardSoundEvent>]
    var soundAssignmentsBySport: [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]]
    var keyboardShortcutsByAction: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut]
    var isCompanionVisible: Bool
    var isCompanionEnabled: Bool
    var companionHost: String
    var companionMode: ScoreboardCompanionMode
    var companionSyncWithSound: Bool
    var companionPort: UInt16
    var companionAssignmentsBySport: [SportType: [ScoreboardSoundEvent: String]]
    var didCompleteSetup: Bool
    var areTipsEnabled: Bool
    var showGettingStartedOnStartup: Bool
    var didAutoShowGettingStarted: Bool
    var setupPresets: [SetupPreset]
    var isWebAPIEnabled: Bool
    var webAPIUpdateMode: ScoreboardWebAPIUpdateMode
    var isWebAPIBroadcastControlEnabled: Bool
    var webAPIBroadcastEnabledDisplayCount: Int
    var webAPIBroadcastDisplayModesByID: [Int: ScoreboardWebAPIBroadcastDisplayMode]
    var customDisplayModeTitlesByMode: [String: String]
    var isRemoteDisplayHostEnabled: Bool
    var isRemoteDisplayViewerModeEnabled: Bool
    var isRemoteDisplayIndividualControlEnabled: Bool
    var remoteDisplayNetworkMode: ScoreboardRemoteDisplayNetworkMode
    var pauseDurationSeconds: Int?
    var pauseTimer: ScoreboardPauseTimer?
    var isTeamPauseIndefinite: Bool?

    private enum CodingKeys: String, CodingKey {
        case homeTeamName
        case selectedSport
        case customSportConfig
        case guestTeamName
        case eventName
        case homeScore
        case guestScore
        case period
        case volleyballMatchFormat
        case volleyballSetResults
        case gameClockSeconds
        case defaultClockSeconds
        case isGameClockEnabled
        case pendingInjuryTimeMinutes
        case activeInjuryTimeMinutes
        case hasAppliedInjuryTimeThisPeriod
        case shotClockMilliseconds
        case shotClockSeconds
        case defaultShotClockSeconds
        case activeShotClockPresetSeconds
        case possessionDirection
        case areSidesSwapped
        case displayDirectionModelVersion
        case controlBoardDisplayDirection
        case isPlayerTrackingEnabled
        case isPlayerOverlayPaused
        case rosterSizePerTeam
        case displayLineupSize
        case playerLineupOverflowMode
        case playerLineupOverflowLogoOverride
        case playerLineupOverflowNoLogoOverride
        case playerLineupFadePageSeconds
        case playerLineupScrollSpeed
        case playerLineupScrollDirection
        case playerViewRosterScope
        case playerFoulHighlightColor
        case isGameClockRedEnabled
        case gameClockRedThresholdSeconds
        case isShotClockRedEnabled
        case shotClockRedThresholdSeconds
        case homeSubstitutionsAllowed
        case guestSubstitutionsAllowed
        case homeSubstitutionsUsed
        case guestSubstitutionsUsed
        case homePausesAllowed
        case guestPausesAllowed
        case homePausesUsed
        case guestPausesUsed
        case homeTeamFouls
        case guestTeamFouls
        case homeChessClockSeconds
        case guestChessClockSeconds
        case activeChessClockSide
        case chessClockPreset
        case selectedDebatePresetID
        case customDebatePreset
        case debateHomeSideLabel
        case debateGuestSideLabel
        case debateCurrentSegmentIndex
        case debatePrepHomeSeconds
        case debatePrepGuestSeconds
        case isDebatePrepTimeEnabled
        case debateActiveTimer
        case isDebatePrepClockRunning
        case isDebateScoreTrackingEnabled
        case isDebatePlayerTrackingEnabled
        case isDebatePlayerFoulsEnabled
        case isDebatePlayerCardsEnabled
        case homePenaltyTimers
        case guestPenaltyTimers
        case homeRoster
        case guestRoster
        case theme
        case showsLiveActivityWhenTimerRunning
        case externalDisplayBackgroundMode
        case externalDisplayAnimatedLogoStyle
        case externalDisplayAnimatedLogoBackgroundColor
        case externalDisplayAnimatedLogoSpeed
        case externalDisplayAnimatedLogoSize
        case externalDisplayAnimatedLogoOpacity
        case showsExternalDisplayDateTime
        case externalDisplayDateTimeFormat
        case showsExternalDisplayDateTimeSeconds
        case externalDisplayDirection
        case showsTeamLogos
        case showsEventLogo
        case isSoundEnabled
        case soundAssignments
        case bypassedSoundEventsBySport
        case bypassedCompanionEventsBySport
        case soundAssignmentsBySport
        case keyboardShortcutsByAction
        case isCompanionVisible
        case isCompanionEnabled
        case companionHost
        case companionMode
        case companionSyncWithSound
        case companionPort
        case companionAssignments
        case companionAssignmentsBySport
        case didCompleteSetup
        case areTipsEnabled
        case showGettingStartedOnStartup
        case didAutoShowGettingStarted
        case setupPresets
        case isWebAPIEnabled
        case webAPIUpdateMode
        case isWebAPIBroadcastControlEnabled
        case webAPIBroadcastEnabledDisplayCount
        case webAPIBroadcastDisplayModesByID
        case customDisplayModeTitlesByMode
        case isRemoteDisplayHostEnabled
        case isRemoteDisplayViewerModeEnabled
        case isRemoteDisplayIndividualControlEnabled
        case remoteDisplayNetworkMode
        case pauseDurationSeconds
        case pauseTimer
        case isTeamPauseIndefinite
    }

    init(
        selectedSport: SportType,
        customSportConfig: CustomSportConfig,
        homeTeamName: String,
        guestTeamName: String,
        eventName: String,
        homeScore: Int,
        guestScore: Int,
        period: Int,
        volleyballMatchFormat: VolleyballMatchFormat,
        volleyballSetResults: [VolleyballSetResult],
        gameClockSeconds: Int,
        defaultClockSeconds: Int,
        isGameClockEnabled: Bool,
        pendingInjuryTimeMinutes: Int,
        activeInjuryTimeMinutes: Int,
        hasAppliedInjuryTimeThisPeriod: Bool,
        shotClockMilliseconds: Int,
        defaultShotClockSeconds: Int,
        activeShotClockPresetSeconds: Int,
        possessionDirection: PossessionDirection,
        areSidesSwapped: Bool,
        controlBoardDisplayDirection: ScoreboardDisplayDirection,
        isPlayerTrackingEnabled: Bool,
        isPlayerOverlayPaused: Bool,
        rosterSizePerTeam: Int,
        displayLineupSize: Int,
        playerLineupOverflowMode: PlayerLineupOverflowMode,
        playerLineupOverflowLogoOverride: PlayerLineupOverflowMode?,
        playerLineupOverflowNoLogoOverride: PlayerLineupOverflowMode?,
        playerLineupFadePageSeconds: Int,
        playerLineupScrollSpeed: Int,
        playerLineupScrollDirection: PlayerLineupScrollDirection,
        playerViewRosterScope: PlayerViewRosterScope,
        playerFoulHighlightColor: PlayerFoulHighlightColor,
        isGameClockRedEnabled: Bool,
        gameClockRedThresholdSeconds: Int,
        isShotClockRedEnabled: Bool,
        shotClockRedThresholdSeconds: Int,
        homeSubstitutionsAllowed: Int,
        guestSubstitutionsAllowed: Int,
        homeSubstitutionsUsed: Int,
        guestSubstitutionsUsed: Int,
        homePausesAllowed: Int,
        guestPausesAllowed: Int,
        homePausesUsed: Int,
        guestPausesUsed: Int,
        homeTeamFouls: Int,
        guestTeamFouls: Int,
        homeChessClockSeconds: Int,
        guestChessClockSeconds: Int,
        activeChessClockSide: TeamSide?,
        chessClockPreset: ChessClockPreset,
        selectedDebatePresetID: String,
        customDebatePreset: DebatePreset,
        debateHomeSideLabel: String,
        debateGuestSideLabel: String,
        debateCurrentSegmentIndex: Int,
        debatePrepHomeSeconds: Int,
        debatePrepGuestSeconds: Int,
        isDebatePrepTimeEnabled: Bool,
        debateActiveTimer: DebateActiveTimer,
        isDebatePrepClockRunning: Bool,
        isDebateScoreTrackingEnabled: Bool,
        isDebatePlayerTrackingEnabled: Bool,
        isDebatePlayerFoulsEnabled: Bool,
        isDebatePlayerCardsEnabled: Bool,
        homePenaltyTimers: [HockeyPenaltyTimer],
        guestPenaltyTimers: [HockeyPenaltyTimer],
        homeRoster: TeamRoster,
        guestRoster: TeamRoster,
        theme: ScoreboardTheme,
        showsLiveActivityWhenTimerRunning: Bool,
        externalDisplayBackgroundMode: ExternalDisplayBackgroundMode,
        externalDisplayAnimatedLogoStyle: ExternalDisplayAnimatedLogoStyle,
        externalDisplayAnimatedLogoBackgroundColor: ExternalDisplayAnimatedLogoBackgroundColor,
        externalDisplayAnimatedLogoSpeed: Int,
        externalDisplayAnimatedLogoSize: Int,
        externalDisplayAnimatedLogoOpacity: Double,
        showsExternalDisplayDateTime: Bool,
        externalDisplayDateTimeFormat: ExternalDisplayDateTimeFormat,
        showsExternalDisplayDateTimeSeconds: Bool,
        externalDisplayDirection: ScoreboardDisplayDirection,
        showsTeamLogos: Bool,
        showsEventLogo: Bool,
        isSoundEnabled: Bool,
        bypassedSoundEventsBySport: [SportType: Set<ScoreboardSoundEvent>],
        bypassedCompanionEventsBySport: [SportType: Set<ScoreboardSoundEvent>],
        soundAssignmentsBySport: [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]],
        keyboardShortcutsByAction: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut],
        isCompanionVisible: Bool,
        isCompanionEnabled: Bool,
        companionHost: String,
        companionMode: ScoreboardCompanionMode,
        companionSyncWithSound: Bool,
        companionPort: UInt16,
        companionAssignmentsBySport: [SportType: [ScoreboardSoundEvent: String]],
        didCompleteSetup: Bool,
        areTipsEnabled: Bool,
        showGettingStartedOnStartup: Bool,
        didAutoShowGettingStarted: Bool,
        setupPresets: [SetupPreset],
        isWebAPIEnabled: Bool,
        webAPIUpdateMode: ScoreboardWebAPIUpdateMode,
        isWebAPIBroadcastControlEnabled: Bool,
        webAPIBroadcastEnabledDisplayCount: Int,
        webAPIBroadcastDisplayModesByID: [Int: ScoreboardWebAPIBroadcastDisplayMode],
        customDisplayModeTitlesByMode: [String: String],
        isRemoteDisplayHostEnabled: Bool,
        isRemoteDisplayViewerModeEnabled: Bool,
        isRemoteDisplayIndividualControlEnabled: Bool,
        remoteDisplayNetworkMode: ScoreboardRemoteDisplayNetworkMode,
        pauseDurationSeconds: Int? = nil,
        pauseTimer: ScoreboardPauseTimer? = nil,
        isTeamPauseIndefinite: Bool? = nil
    ) {
        self.selectedSport = selectedSport
        self.customSportConfig = customSportConfig
        self.homeTeamName = homeTeamName
        self.guestTeamName = guestTeamName
        self.eventName = eventName
        self.homeScore = homeScore
        self.guestScore = guestScore
        self.period = period
        self.volleyballMatchFormat = volleyballMatchFormat
        self.volleyballSetResults = volleyballSetResults
        self.gameClockSeconds = gameClockSeconds
        self.defaultClockSeconds = defaultClockSeconds
        self.isGameClockEnabled = isGameClockEnabled
        self.pendingInjuryTimeMinutes = pendingInjuryTimeMinutes
        self.activeInjuryTimeMinutes = activeInjuryTimeMinutes
        self.hasAppliedInjuryTimeThisPeriod = hasAppliedInjuryTimeThisPeriod
        self.shotClockMilliseconds = shotClockMilliseconds
        self.defaultShotClockSeconds = defaultShotClockSeconds
        self.activeShotClockPresetSeconds = activeShotClockPresetSeconds
        self.possessionDirection = possessionDirection
        self.areSidesSwapped = areSidesSwapped
        self.controlBoardDisplayDirection = controlBoardDisplayDirection
        self.isPlayerTrackingEnabled = isPlayerTrackingEnabled
        self.isPlayerOverlayPaused = isPlayerOverlayPaused
        self.rosterSizePerTeam = rosterSizePerTeam
        self.displayLineupSize = displayLineupSize
        self.playerLineupOverflowMode = playerLineupOverflowMode
        self.playerLineupOverflowLogoOverride = playerLineupOverflowLogoOverride
        self.playerLineupOverflowNoLogoOverride = playerLineupOverflowNoLogoOverride
        self.playerLineupFadePageSeconds = playerLineupFadePageSeconds
        self.playerLineupScrollSpeed = playerLineupScrollSpeed
        self.playerLineupScrollDirection = playerLineupScrollDirection
        self.playerViewRosterScope = playerViewRosterScope
        self.playerFoulHighlightColor = playerFoulHighlightColor
        self.isGameClockRedEnabled = isGameClockRedEnabled
        self.gameClockRedThresholdSeconds = gameClockRedThresholdSeconds
        self.isShotClockRedEnabled = isShotClockRedEnabled
        self.shotClockRedThresholdSeconds = shotClockRedThresholdSeconds
        self.homeSubstitutionsAllowed = homeSubstitutionsAllowed
        self.guestSubstitutionsAllowed = guestSubstitutionsAllowed
        self.homeSubstitutionsUsed = homeSubstitutionsUsed
        self.guestSubstitutionsUsed = guestSubstitutionsUsed
        self.homePausesAllowed = homePausesAllowed
        self.guestPausesAllowed = guestPausesAllowed
        self.homePausesUsed = homePausesUsed
        self.guestPausesUsed = guestPausesUsed
        self.homeTeamFouls = homeTeamFouls
        self.guestTeamFouls = guestTeamFouls
        self.homeChessClockSeconds = homeChessClockSeconds
        self.guestChessClockSeconds = guestChessClockSeconds
        self.activeChessClockSide = activeChessClockSide
        self.chessClockPreset = chessClockPreset
        self.selectedDebatePresetID = selectedDebatePresetID
        self.customDebatePreset = customDebatePreset
        self.debateHomeSideLabel = debateHomeSideLabel
        self.debateGuestSideLabel = debateGuestSideLabel
        self.debateCurrentSegmentIndex = debateCurrentSegmentIndex
        self.debatePrepHomeSeconds = debatePrepHomeSeconds
        self.debatePrepGuestSeconds = debatePrepGuestSeconds
        self.isDebatePrepTimeEnabled = isDebatePrepTimeEnabled
        self.debateActiveTimer = debateActiveTimer
        self.isDebatePrepClockRunning = isDebatePrepClockRunning
        self.isDebateScoreTrackingEnabled = isDebateScoreTrackingEnabled
        self.isDebatePlayerTrackingEnabled = isDebatePlayerTrackingEnabled
        self.isDebatePlayerFoulsEnabled = isDebatePlayerFoulsEnabled
        self.isDebatePlayerCardsEnabled = isDebatePlayerCardsEnabled
        self.homePenaltyTimers = homePenaltyTimers
        self.guestPenaltyTimers = guestPenaltyTimers
        self.homeRoster = homeRoster
        self.guestRoster = guestRoster
        self.theme = theme
        self.showsLiveActivityWhenTimerRunning = showsLiveActivityWhenTimerRunning
        self.externalDisplayBackgroundMode = externalDisplayBackgroundMode
        self.externalDisplayAnimatedLogoStyle = externalDisplayAnimatedLogoStyle
        self.externalDisplayAnimatedLogoBackgroundColor = externalDisplayAnimatedLogoBackgroundColor
        self.externalDisplayAnimatedLogoSpeed = externalDisplayAnimatedLogoSpeed
        self.externalDisplayAnimatedLogoSize = externalDisplayAnimatedLogoSize
        self.externalDisplayAnimatedLogoOpacity = externalDisplayAnimatedLogoOpacity
        self.showsExternalDisplayDateTime = showsExternalDisplayDateTime
        self.externalDisplayDateTimeFormat = externalDisplayDateTimeFormat
        self.showsExternalDisplayDateTimeSeconds = showsExternalDisplayDateTimeSeconds
        self.externalDisplayDirection = externalDisplayDirection
        self.showsTeamLogos = showsTeamLogos
        self.showsEventLogo = showsEventLogo
        self.isSoundEnabled = isSoundEnabled
        self.bypassedSoundEventsBySport = bypassedSoundEventsBySport
        self.bypassedCompanionEventsBySport = bypassedCompanionEventsBySport
        self.soundAssignmentsBySport = soundAssignmentsBySport
        self.keyboardShortcutsByAction = ScoreboardStore.normalizedKeyboardShortcuts(keyboardShortcutsByAction)
        self.isCompanionVisible = isCompanionVisible
        self.isCompanionEnabled = isCompanionEnabled
        self.companionHost = companionHost
        self.companionMode = companionMode
        self.companionSyncWithSound = companionSyncWithSound
        self.companionPort = companionPort
        self.companionAssignmentsBySport = companionAssignmentsBySport
        self.didCompleteSetup = didCompleteSetup
        self.areTipsEnabled = areTipsEnabled
        self.showGettingStartedOnStartup = showGettingStartedOnStartup
        self.didAutoShowGettingStarted = didAutoShowGettingStarted
        self.setupPresets = setupPresets
        self.isWebAPIEnabled = isWebAPIEnabled
        self.webAPIUpdateMode = webAPIUpdateMode
        self.isWebAPIBroadcastControlEnabled = isWebAPIBroadcastControlEnabled
        self.webAPIBroadcastEnabledDisplayCount = ScoreboardStore.boundedWebAPIBroadcastEnabledDisplayCount(webAPIBroadcastEnabledDisplayCount)
        self.webAPIBroadcastDisplayModesByID = ScoreboardStore.normalizedWebAPIBroadcastDisplayModes(webAPIBroadcastDisplayModesByID)
        self.customDisplayModeTitlesByMode = ScoreboardStore.normalizedCustomDisplayModeTitles(customDisplayModeTitlesByMode)
        self.isRemoteDisplayHostEnabled = isRemoteDisplayHostEnabled
        self.isRemoteDisplayViewerModeEnabled = isRemoteDisplayViewerModeEnabled
        self.isRemoteDisplayIndividualControlEnabled = isRemoteDisplayIndividualControlEnabled
        self.remoteDisplayNetworkMode = remoteDisplayNetworkMode
        self.pauseDurationSeconds = pauseDurationSeconds
        self.pauseTimer = pauseTimer
        self.isTeamPauseIndefinite = isTeamPauseIndefinite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedSport = try container.decodeIfPresent(SportType.self, forKey: .selectedSport) ?? .basketball
        customSportConfig = try container.decodeIfPresent(CustomSportConfig.self, forKey: .customSportConfig) ?? .default
        homeTeamName = try container.decode(String.self, forKey: .homeTeamName)
        guestTeamName = try container.decode(String.self, forKey: .guestTeamName)
        eventName = try container.decodeIfPresent(String.self, forKey: .eventName) ?? ""
        homeScore = try container.decode(Int.self, forKey: .homeScore)
        guestScore = try container.decode(Int.self, forKey: .guestScore)
        period = try container.decode(Int.self, forKey: .period)
        volleyballMatchFormat = try container.decodeIfPresent(VolleyballMatchFormat.self, forKey: .volleyballMatchFormat) ?? .bestOf5
        volleyballSetResults = try container.decodeIfPresent([VolleyballSetResult].self, forKey: .volleyballSetResults) ?? []
        gameClockSeconds = try container.decode(Int.self, forKey: .gameClockSeconds)
        defaultClockSeconds = try container.decode(Int.self, forKey: .defaultClockSeconds)
        isGameClockEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGameClockEnabled) ?? true
        pendingInjuryTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .pendingInjuryTimeMinutes) ?? 0
        activeInjuryTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .activeInjuryTimeMinutes) ?? 0
        hasAppliedInjuryTimeThisPeriod = try container.decodeIfPresent(Bool.self, forKey: .hasAppliedInjuryTimeThisPeriod) ?? (activeInjuryTimeMinutes > 0)
        if let shotClockMilliseconds = try container.decodeIfPresent(Int.self, forKey: .shotClockMilliseconds) {
            self.shotClockMilliseconds = shotClockMilliseconds
        } else {
            let shotClockSeconds = try container.decodeIfPresent(Int.self, forKey: .shotClockSeconds) ?? 24
            self.shotClockMilliseconds = shotClockSeconds * 1_000
        }
        defaultShotClockSeconds = try container.decodeIfPresent(Int.self, forKey: .defaultShotClockSeconds) ?? 24
        activeShotClockPresetSeconds = try container.decodeIfPresent(Int.self, forKey: .activeShotClockPresetSeconds) ?? defaultShotClockSeconds
        possessionDirection = try container.decodeIfPresent(PossessionDirection.self, forKey: .possessionDirection) ?? .none
        areSidesSwapped = try container.decodeIfPresent(Bool.self, forKey: .areSidesSwapped) ?? false
        let displayDirectionModelVersion = try container.decodeIfPresent(Int.self, forKey: .displayDirectionModelVersion) ?? 1
        let legacyDisplayDirection = ScoreboardDisplayDirection(areSidesSwapped: areSidesSwapped)
        let decodedControlBoardDisplayDirection = try container.decodeIfPresent(ScoreboardDisplayDirection.self, forKey: .controlBoardDisplayDirection) ?? legacyDisplayDirection
        controlBoardDisplayDirection = displayDirectionModelVersion < ScoreboardStore.displayDirectionModelVersion
            ? decodedControlBoardDisplayDirection.applyingSideSwap(areSidesSwapped)
            : decodedControlBoardDisplayDirection
        isPlayerTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPlayerTrackingEnabled) ?? false
        isPlayerOverlayPaused = try container.decodeIfPresent(Bool.self, forKey: .isPlayerOverlayPaused) ?? false
        rosterSizePerTeam = try container.decodeIfPresent(Int.self, forKey: .rosterSizePerTeam) ?? ScoreboardStore.defaultRosterSize
        displayLineupSize = try container.decodeIfPresent(Int.self, forKey: .displayLineupSize) ?? ScoreboardStore.defaultDisplayLineupSize
        playerLineupOverflowMode = try container.decodeIfPresent(PlayerLineupOverflowMode.self, forKey: .playerLineupOverflowMode) ?? .scroll
        playerLineupOverflowLogoOverride = try container.decodeIfPresent(PlayerLineupOverflowMode.self, forKey: .playerLineupOverflowLogoOverride)
        playerLineupOverflowNoLogoOverride = try container.decodeIfPresent(PlayerLineupOverflowMode.self, forKey: .playerLineupOverflowNoLogoOverride)
        playerLineupFadePageSeconds = try container.decodeIfPresent(Int.self, forKey: .playerLineupFadePageSeconds) ?? ScoreboardStore.defaultPlayerLineupFadePageSeconds
        playerLineupScrollSpeed = try container.decodeIfPresent(Int.self, forKey: .playerLineupScrollSpeed) ?? ScoreboardStore.defaultPlayerLineupScrollSpeed
        playerLineupScrollDirection = try container.decodeIfPresent(PlayerLineupScrollDirection.self, forKey: .playerLineupScrollDirection) ?? .continuousUp
        playerViewRosterScope = try container.decodeIfPresent(PlayerViewRosterScope.self, forKey: .playerViewRosterScope) ?? .fullRoster
        playerFoulHighlightColor = try container.decodeIfPresent(PlayerFoulHighlightColor.self, forKey: .playerFoulHighlightColor) ?? .yellow
        isGameClockRedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGameClockRedEnabled) ?? false
        gameClockRedThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .gameClockRedThresholdSeconds) ?? 60
        isShotClockRedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isShotClockRedEnabled) ?? false
        shotClockRedThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .shotClockRedThresholdSeconds) ?? 5
        homeSubstitutionsAllowed = try container.decodeIfPresent(Int.self, forKey: .homeSubstitutionsAllowed) ?? selectedSport.defaultSubstitutionLimit
        guestSubstitutionsAllowed = try container.decodeIfPresent(Int.self, forKey: .guestSubstitutionsAllowed) ?? selectedSport.defaultSubstitutionLimit
        homeSubstitutionsUsed = try container.decodeIfPresent(Int.self, forKey: .homeSubstitutionsUsed) ?? 0
        guestSubstitutionsUsed = try container.decodeIfPresent(Int.self, forKey: .guestSubstitutionsUsed) ?? 0
        let decodedDefaultPauseLimit = selectedSport.rules(customConfig: customSportConfig).defaultPauseLimit
        homePausesAllowed = try container.decodeIfPresent(Int.self, forKey: .homePausesAllowed) ?? decodedDefaultPauseLimit
        guestPausesAllowed = try container.decodeIfPresent(Int.self, forKey: .guestPausesAllowed) ?? decodedDefaultPauseLimit
        homePausesUsed = try container.decodeIfPresent(Int.self, forKey: .homePausesUsed) ?? 0
        guestPausesUsed = try container.decodeIfPresent(Int.self, forKey: .guestPausesUsed) ?? 0
        homeTeamFouls = try container.decodeIfPresent(Int.self, forKey: .homeTeamFouls) ?? 0
        guestTeamFouls = try container.decodeIfPresent(Int.self, forKey: .guestTeamFouls) ?? 0
        homeChessClockSeconds = try container.decodeIfPresent(Int.self, forKey: .homeChessClockSeconds) ?? ChessClockPreset.rapid.seconds
        guestChessClockSeconds = try container.decodeIfPresent(Int.self, forKey: .guestChessClockSeconds) ?? ChessClockPreset.rapid.seconds
        activeChessClockSide = try container.decodeIfPresent(TeamSide.self, forKey: .activeChessClockSide) ?? .home
        chessClockPreset = try container.decodeIfPresent(ChessClockPreset.self, forKey: .chessClockPreset) ?? .rapid
        selectedDebatePresetID = try container.decodeIfPresent(String.self, forKey: .selectedDebatePresetID) ?? DebatePreset.publicForum.id
        customDebatePreset = try container.decodeIfPresent(DebatePreset.self, forKey: .customDebatePreset) ?? .customDefault
        let preset = selectedDebatePresetID == DebatePreset.customID ? customDebatePreset : DebatePreset.preset(id: selectedDebatePresetID)
        debateHomeSideLabel = try container.decodeIfPresent(String.self, forKey: .debateHomeSideLabel) ?? preset.homeSideLabel
        debateGuestSideLabel = try container.decodeIfPresent(String.self, forKey: .debateGuestSideLabel) ?? preset.guestSideLabel
        debateCurrentSegmentIndex = try container.decodeIfPresent(Int.self, forKey: .debateCurrentSegmentIndex) ?? 0
        isDebatePrepTimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebatePrepTimeEnabled) ?? preset.isPrepTimeEnabled
        debatePrepHomeSeconds = isDebatePrepTimeEnabled ? (try container.decodeIfPresent(Int.self, forKey: .debatePrepHomeSeconds) ?? preset.prepSecondsPerSide) : 0
        debatePrepGuestSeconds = isDebatePrepTimeEnabled ? (try container.decodeIfPresent(Int.self, forKey: .debatePrepGuestSeconds) ?? preset.prepSecondsPerSide) : 0
        debateActiveTimer = try container.decodeIfPresent(DebateActiveTimer.self, forKey: .debateActiveTimer) ?? .segment
        isDebatePrepClockRunning = try container.decodeIfPresent(Bool.self, forKey: .isDebatePrepClockRunning) ?? false
        isDebateScoreTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebateScoreTrackingEnabled) ?? preset.defaultScoreTrackingEnabled
        isDebatePlayerTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebatePlayerTrackingEnabled) ?? preset.defaultPlayerTrackingEnabled
        isDebatePlayerFoulsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebatePlayerFoulsEnabled) ?? preset.defaultPlayerFoulsEnabled
        isDebatePlayerCardsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebatePlayerCardsEnabled) ?? preset.defaultPlayerCardsEnabled
        homePenaltyTimers = try container.decodeIfPresent([HockeyPenaltyTimer].self, forKey: .homePenaltyTimers) ?? []
        guestPenaltyTimers = try container.decodeIfPresent([HockeyPenaltyTimer].self, forKey: .guestPenaltyTimers) ?? []
        homeRoster = try container.decodeIfPresent(TeamRoster.self, forKey: .homeRoster) ?? TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: rosterSizePerTeam))
        guestRoster = try container.decodeIfPresent(TeamRoster.self, forKey: .guestRoster) ?? TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: rosterSizePerTeam))
        theme = try container.decodeIfPresent(ScoreboardTheme.self, forKey: .theme) ?? .classic
        showsLiveActivityWhenTimerRunning = try container.decodeIfPresent(Bool.self, forKey: .showsLiveActivityWhenTimerRunning) ?? true
        externalDisplayBackgroundMode = try container.decodeIfPresent(ExternalDisplayBackgroundMode.self, forKey: .externalDisplayBackgroundMode) ?? .blurred
        externalDisplayAnimatedLogoStyle = try container.decodeIfPresent(ExternalDisplayAnimatedLogoStyle.self, forKey: .externalDisplayAnimatedLogoStyle) ?? .horizontalMarquee
        externalDisplayAnimatedLogoBackgroundColor = try container.decodeIfPresent(ExternalDisplayAnimatedLogoBackgroundColor.self, forKey: .externalDisplayAnimatedLogoBackgroundColor) ?? .themeBackground
        externalDisplayAnimatedLogoSpeed = max(
            ScoreboardStore.minAnimatedLogoSpeed,
            min(ScoreboardStore.maxAnimatedLogoSpeed, try container.decodeIfPresent(Int.self, forKey: .externalDisplayAnimatedLogoSpeed) ?? ScoreboardStore.defaultAnimatedLogoSpeed)
        )
        externalDisplayAnimatedLogoSize = max(
            ScoreboardStore.minAnimatedLogoSize,
            min(ScoreboardStore.maxAnimatedLogoSize, try container.decodeIfPresent(Int.self, forKey: .externalDisplayAnimatedLogoSize) ?? ScoreboardStore.defaultAnimatedLogoSize)
        )
        externalDisplayAnimatedLogoOpacity = max(
            ScoreboardStore.minAnimatedLogoOpacity,
            min(ScoreboardStore.maxAnimatedLogoOpacity, try container.decodeIfPresent(Double.self, forKey: .externalDisplayAnimatedLogoOpacity) ?? ScoreboardStore.defaultAnimatedLogoOpacity)
        )
        showsExternalDisplayDateTime = try container.decodeIfPresent(Bool.self, forKey: .showsExternalDisplayDateTime) ?? false
        externalDisplayDateTimeFormat = try container.decodeIfPresent(ExternalDisplayDateTimeFormat.self, forKey: .externalDisplayDateTimeFormat) ?? .time24Hour
        showsExternalDisplayDateTimeSeconds = try container.decodeIfPresent(Bool.self, forKey: .showsExternalDisplayDateTimeSeconds) ?? true
        let decodedExternalDisplayDirection = try container.decodeIfPresent(ScoreboardDisplayDirection.self, forKey: .externalDisplayDirection) ?? legacyDisplayDirection
        externalDisplayDirection = displayDirectionModelVersion < ScoreboardStore.displayDirectionModelVersion
            ? decodedExternalDisplayDirection.applyingSideSwap(areSidesSwapped)
            : decodedExternalDisplayDirection
        showsTeamLogos = try container.decodeIfPresent(Bool.self, forKey: .showsTeamLogos) ?? true
        showsEventLogo = try container.decodeIfPresent(Bool.self, forKey: .showsEventLogo) ?? true
        isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        bypassedSoundEventsBySport = try container.decodeIfPresent([SportType: Set<ScoreboardSoundEvent>].self, forKey: .bypassedSoundEventsBySport) ?? [:]
        bypassedCompanionEventsBySport = try container.decodeIfPresent([SportType: Set<ScoreboardSoundEvent>].self, forKey: .bypassedCompanionEventsBySport) ?? [:]
        if let assignmentsBySport = try container.decodeIfPresent([SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]].self, forKey: .soundAssignmentsBySport) {
            soundAssignmentsBySport = assignmentsBySport
        } else if let legacyAssignments = try container.decodeIfPresent([ScoreboardSoundEvent: ScoreboardSoundEffect].self, forKey: .soundAssignments) {
            soundAssignmentsBySport = Dictionary(uniqueKeysWithValues: SportType.allCases.map { sport in
                (sport, legacyAssignments)
            })
        } else {
            soundAssignmentsBySport = ScoreboardStore.defaultSoundAssignmentsBySport
        }
        keyboardShortcutsByAction = ScoreboardStore.normalizedKeyboardShortcuts(
            try container.decodeIfPresent([ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut].self, forKey: .keyboardShortcutsByAction)
                ?? ScoreboardStore.defaultKeyboardShortcutsByAction
        )
        isCompanionVisible = try container.decodeIfPresent(Bool.self, forKey: .isCompanionVisible) ?? false
        let decodedCompanionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCompanionEnabled) ?? false
        isCompanionEnabled = isCompanionVisible && decodedCompanionEnabled
        companionHost = try container.decodeIfPresent(String.self, forKey: .companionHost) ?? ""
        companionMode = try container.decodeIfPresent(ScoreboardCompanionMode.self, forKey: .companionMode) ?? .tcp
        companionSyncWithSound = try container.decodeIfPresent(Bool.self, forKey: .companionSyncWithSound) ?? false
        companionPort = try container.decodeIfPresent(UInt16.self, forKey: .companionPort) ?? companionMode.defaultPort
        if let assignmentsBySport = try container.decodeIfPresent([SportType: [ScoreboardSoundEvent: String]].self, forKey: .companionAssignmentsBySport) {
            companionAssignmentsBySport = assignmentsBySport
        } else if let legacyAssignments = try container.decodeIfPresent([ScoreboardSoundEvent: String].self, forKey: .companionAssignments) {
            companionAssignmentsBySport = Dictionary(uniqueKeysWithValues: SportType.allCases.map { sport in
                (sport, legacyAssignments)
            })
        } else {
            companionAssignmentsBySport = [:]
        }
        didCompleteSetup = try container.decode(Bool.self, forKey: .didCompleteSetup)
        areTipsEnabled = try container.decodeIfPresent(Bool.self, forKey: .areTipsEnabled) ?? true
        showGettingStartedOnStartup = try container.decodeIfPresent(Bool.self, forKey: .showGettingStartedOnStartup) ?? true
        didAutoShowGettingStarted = try container.decodeIfPresent(Bool.self, forKey: .didAutoShowGettingStarted) ?? false
        setupPresets = try container.decode([SetupPreset].self, forKey: .setupPresets)
        isWebAPIEnabled = try container.decodeIfPresent(Bool.self, forKey: .isWebAPIEnabled) ?? false
        webAPIUpdateMode = try container.decodeIfPresent(ScoreboardWebAPIUpdateMode.self, forKey: .webAPIUpdateMode) ?? .fixedInterval
        isWebAPIBroadcastControlEnabled = try container.decodeIfPresent(Bool.self, forKey: .isWebAPIBroadcastControlEnabled) ?? false
        webAPIBroadcastEnabledDisplayCount = ScoreboardStore.boundedWebAPIBroadcastEnabledDisplayCount(
            try container.decodeIfPresent(Int.self, forKey: .webAPIBroadcastEnabledDisplayCount) ?? ScoreboardStore.defaultWebAPIBroadcastEnabledDisplayCount
        )
        webAPIBroadcastDisplayModesByID = ScoreboardStore.normalizedWebAPIBroadcastDisplayModes(
            try container.decodeIfPresent([Int: ScoreboardWebAPIBroadcastDisplayMode].self, forKey: .webAPIBroadcastDisplayModesByID) ?? [:]
        )
        customDisplayModeTitlesByMode = ScoreboardStore.normalizedCustomDisplayModeTitles(
            try container.decodeIfPresent([String: String].self, forKey: .customDisplayModeTitlesByMode) ?? [:]
        )
        isRemoteDisplayHostEnabled = try container.decodeIfPresent(Bool.self, forKey: .isRemoteDisplayHostEnabled) ?? false
        isRemoteDisplayViewerModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isRemoteDisplayViewerModeEnabled) ?? false
        isRemoteDisplayIndividualControlEnabled = try container.decodeIfPresent(Bool.self, forKey: .isRemoteDisplayIndividualControlEnabled) ?? false
        remoteDisplayNetworkMode = try container.decodeIfPresent(ScoreboardRemoteDisplayNetworkMode.self, forKey: .remoteDisplayNetworkMode) ?? .nearbyAndLocalNetwork
        pauseDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .pauseDurationSeconds)
        pauseTimer = try container.decodeIfPresent(ScoreboardPauseTimer.self, forKey: .pauseTimer)
        isTeamPauseIndefinite = try container.decodeIfPresent(Bool.self, forKey: .isTeamPauseIndefinite)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedSport, forKey: .selectedSport)
        try container.encode(customSportConfig, forKey: .customSportConfig)
        try container.encode(homeTeamName, forKey: .homeTeamName)
        try container.encode(guestTeamName, forKey: .guestTeamName)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(homeScore, forKey: .homeScore)
        try container.encode(guestScore, forKey: .guestScore)
        try container.encode(period, forKey: .period)
        try container.encode(volleyballMatchFormat, forKey: .volleyballMatchFormat)
        try container.encode(volleyballSetResults, forKey: .volleyballSetResults)
        try container.encode(gameClockSeconds, forKey: .gameClockSeconds)
        try container.encode(defaultClockSeconds, forKey: .defaultClockSeconds)
        try container.encode(isGameClockEnabled, forKey: .isGameClockEnabled)
        try container.encode(pendingInjuryTimeMinutes, forKey: .pendingInjuryTimeMinutes)
        try container.encode(activeInjuryTimeMinutes, forKey: .activeInjuryTimeMinutes)
        try container.encode(hasAppliedInjuryTimeThisPeriod, forKey: .hasAppliedInjuryTimeThisPeriod)
        try container.encode(shotClockMilliseconds, forKey: .shotClockMilliseconds)
        try container.encode(defaultShotClockSeconds, forKey: .defaultShotClockSeconds)
        try container.encode(activeShotClockPresetSeconds, forKey: .activeShotClockPresetSeconds)
        try container.encode(possessionDirection, forKey: .possessionDirection)
        try container.encode(areSidesSwapped, forKey: .areSidesSwapped)
        try container.encode(ScoreboardStore.displayDirectionModelVersion, forKey: .displayDirectionModelVersion)
        try container.encode(controlBoardDisplayDirection, forKey: .controlBoardDisplayDirection)
        try container.encode(isPlayerTrackingEnabled, forKey: .isPlayerTrackingEnabled)
        try container.encode(isPlayerOverlayPaused, forKey: .isPlayerOverlayPaused)
        try container.encode(rosterSizePerTeam, forKey: .rosterSizePerTeam)
        try container.encode(displayLineupSize, forKey: .displayLineupSize)
        try container.encode(playerLineupOverflowMode, forKey: .playerLineupOverflowMode)
        try container.encodeIfPresent(playerLineupOverflowLogoOverride, forKey: .playerLineupOverflowLogoOverride)
        try container.encodeIfPresent(playerLineupOverflowNoLogoOverride, forKey: .playerLineupOverflowNoLogoOverride)
        try container.encode(playerLineupFadePageSeconds, forKey: .playerLineupFadePageSeconds)
        try container.encode(playerLineupScrollSpeed, forKey: .playerLineupScrollSpeed)
        try container.encode(playerLineupScrollDirection, forKey: .playerLineupScrollDirection)
        try container.encode(playerViewRosterScope, forKey: .playerViewRosterScope)
        try container.encode(playerFoulHighlightColor, forKey: .playerFoulHighlightColor)
        try container.encode(isGameClockRedEnabled, forKey: .isGameClockRedEnabled)
        try container.encode(gameClockRedThresholdSeconds, forKey: .gameClockRedThresholdSeconds)
        try container.encode(isShotClockRedEnabled, forKey: .isShotClockRedEnabled)
        try container.encode(shotClockRedThresholdSeconds, forKey: .shotClockRedThresholdSeconds)
        try container.encode(homeSubstitutionsAllowed, forKey: .homeSubstitutionsAllowed)
        try container.encode(guestSubstitutionsAllowed, forKey: .guestSubstitutionsAllowed)
        try container.encode(homeSubstitutionsUsed, forKey: .homeSubstitutionsUsed)
        try container.encode(guestSubstitutionsUsed, forKey: .guestSubstitutionsUsed)
        try container.encode(homePausesAllowed, forKey: .homePausesAllowed)
        try container.encode(guestPausesAllowed, forKey: .guestPausesAllowed)
        try container.encode(homePausesUsed, forKey: .homePausesUsed)
        try container.encode(guestPausesUsed, forKey: .guestPausesUsed)
        try container.encode(homeTeamFouls, forKey: .homeTeamFouls)
        try container.encode(guestTeamFouls, forKey: .guestTeamFouls)
        try container.encode(homeChessClockSeconds, forKey: .homeChessClockSeconds)
        try container.encode(guestChessClockSeconds, forKey: .guestChessClockSeconds)
        try container.encode(activeChessClockSide, forKey: .activeChessClockSide)
        try container.encode(chessClockPreset, forKey: .chessClockPreset)
        try container.encode(selectedDebatePresetID, forKey: .selectedDebatePresetID)
        try container.encode(customDebatePreset, forKey: .customDebatePreset)
        try container.encode(debateHomeSideLabel, forKey: .debateHomeSideLabel)
        try container.encode(debateGuestSideLabel, forKey: .debateGuestSideLabel)
        try container.encode(debateCurrentSegmentIndex, forKey: .debateCurrentSegmentIndex)
        try container.encode(debatePrepHomeSeconds, forKey: .debatePrepHomeSeconds)
        try container.encode(debatePrepGuestSeconds, forKey: .debatePrepGuestSeconds)
        try container.encode(isDebatePrepTimeEnabled, forKey: .isDebatePrepTimeEnabled)
        try container.encode(debateActiveTimer, forKey: .debateActiveTimer)
        try container.encode(isDebatePrepClockRunning, forKey: .isDebatePrepClockRunning)
        try container.encode(isDebateScoreTrackingEnabled, forKey: .isDebateScoreTrackingEnabled)
        try container.encode(isDebatePlayerTrackingEnabled, forKey: .isDebatePlayerTrackingEnabled)
        try container.encode(isDebatePlayerFoulsEnabled, forKey: .isDebatePlayerFoulsEnabled)
        try container.encode(isDebatePlayerCardsEnabled, forKey: .isDebatePlayerCardsEnabled)
        try container.encode(homePenaltyTimers, forKey: .homePenaltyTimers)
        try container.encode(guestPenaltyTimers, forKey: .guestPenaltyTimers)
        try container.encode(homeRoster, forKey: .homeRoster)
        try container.encode(guestRoster, forKey: .guestRoster)
        try container.encode(theme, forKey: .theme)
        try container.encode(showsLiveActivityWhenTimerRunning, forKey: .showsLiveActivityWhenTimerRunning)
        try container.encode(externalDisplayBackgroundMode, forKey: .externalDisplayBackgroundMode)
        try container.encode(externalDisplayAnimatedLogoStyle, forKey: .externalDisplayAnimatedLogoStyle)
        try container.encode(externalDisplayAnimatedLogoBackgroundColor, forKey: .externalDisplayAnimatedLogoBackgroundColor)
        try container.encode(externalDisplayAnimatedLogoSpeed, forKey: .externalDisplayAnimatedLogoSpeed)
        try container.encode(externalDisplayAnimatedLogoSize, forKey: .externalDisplayAnimatedLogoSize)
        try container.encode(externalDisplayAnimatedLogoOpacity, forKey: .externalDisplayAnimatedLogoOpacity)
        try container.encode(showsExternalDisplayDateTime, forKey: .showsExternalDisplayDateTime)
        try container.encode(externalDisplayDateTimeFormat, forKey: .externalDisplayDateTimeFormat)
        try container.encode(showsExternalDisplayDateTimeSeconds, forKey: .showsExternalDisplayDateTimeSeconds)
        try container.encode(externalDisplayDirection, forKey: .externalDisplayDirection)
        try container.encode(showsTeamLogos, forKey: .showsTeamLogos)
        try container.encode(showsEventLogo, forKey: .showsEventLogo)
        try container.encode(isSoundEnabled, forKey: .isSoundEnabled)
        try container.encode(bypassedSoundEventsBySport, forKey: .bypassedSoundEventsBySport)
        try container.encode(bypassedCompanionEventsBySport, forKey: .bypassedCompanionEventsBySport)
        try container.encode(soundAssignmentsBySport, forKey: .soundAssignmentsBySport)
        try container.encode(keyboardShortcutsByAction, forKey: .keyboardShortcutsByAction)
        try container.encode(isCompanionVisible, forKey: .isCompanionVisible)
        try container.encode(isCompanionEnabled, forKey: .isCompanionEnabled)
        try container.encode(companionHost, forKey: .companionHost)
        try container.encode(companionMode, forKey: .companionMode)
        try container.encode(companionSyncWithSound, forKey: .companionSyncWithSound)
        try container.encode(companionPort, forKey: .companionPort)
        try container.encode(companionAssignmentsBySport, forKey: .companionAssignmentsBySport)
        try container.encode(didCompleteSetup, forKey: .didCompleteSetup)
        try container.encode(areTipsEnabled, forKey: .areTipsEnabled)
        try container.encode(showGettingStartedOnStartup, forKey: .showGettingStartedOnStartup)
        try container.encode(didAutoShowGettingStarted, forKey: .didAutoShowGettingStarted)
        try container.encode(setupPresets, forKey: .setupPresets)
        try container.encode(isWebAPIEnabled, forKey: .isWebAPIEnabled)
        try container.encode(webAPIUpdateMode, forKey: .webAPIUpdateMode)
        try container.encode(isWebAPIBroadcastControlEnabled, forKey: .isWebAPIBroadcastControlEnabled)
        try container.encode(webAPIBroadcastEnabledDisplayCount, forKey: .webAPIBroadcastEnabledDisplayCount)
        try container.encode(webAPIBroadcastDisplayModesByID, forKey: .webAPIBroadcastDisplayModesByID)
        try container.encode(customDisplayModeTitlesByMode, forKey: .customDisplayModeTitlesByMode)
        try container.encode(isRemoteDisplayHostEnabled, forKey: .isRemoteDisplayHostEnabled)
        try container.encode(isRemoteDisplayViewerModeEnabled, forKey: .isRemoteDisplayViewerModeEnabled)
        try container.encode(isRemoteDisplayIndividualControlEnabled, forKey: .isRemoteDisplayIndividualControlEnabled)
        try container.encode(remoteDisplayNetworkMode, forKey: .remoteDisplayNetworkMode)
        try container.encodeIfPresent(pauseDurationSeconds, forKey: .pauseDurationSeconds)
        try container.encodeIfPresent(pauseTimer, forKey: .pauseTimer)
        try container.encodeIfPresent(isTeamPauseIndefinite, forKey: .isTeamPauseIndefinite)
    }
}

private extension PersistedState {
    var excludingRemoteDisplayPairingState: PersistedState {
        var state = self
        state.isRemoteDisplayHostEnabled = false
        state.isRemoteDisplayViewerModeEnabled = false
        return state
    }

    static var factoryDefault: PersistedState {
        let defaultRoster = TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: ScoreboardStore.defaultRosterSize))
        return PersistedState(
            selectedSport: .simple,
            customSportConfig: .default,
            homeTeamName: "",
            guestTeamName: "",
            eventName: "",
            homeScore: 0,
            guestScore: 0,
            period: 1,
            volleyballMatchFormat: .bestOf5,
            volleyballSetResults: [],
            gameClockSeconds: 10 * 60,
            defaultClockSeconds: 10 * 60,
            isGameClockEnabled: true,
            pendingInjuryTimeMinutes: 0,
            activeInjuryTimeMinutes: 0,
            hasAppliedInjuryTimeThisPeriod: false,
            shotClockMilliseconds: 0,
            defaultShotClockSeconds: 0,
            activeShotClockPresetSeconds: 0,
            possessionDirection: .none,
            areSidesSwapped: false,
            controlBoardDisplayDirection: .homeLeft,
            isPlayerTrackingEnabled: false,
            isPlayerOverlayPaused: false,
            rosterSizePerTeam: ScoreboardStore.defaultRosterSize,
            displayLineupSize: ScoreboardStore.defaultDisplayLineupSize,
            playerLineupOverflowMode: .scroll,
            playerLineupOverflowLogoOverride: nil,
            playerLineupOverflowNoLogoOverride: nil,
            playerLineupFadePageSeconds: ScoreboardStore.defaultPlayerLineupFadePageSeconds,
            playerLineupScrollSpeed: ScoreboardStore.defaultPlayerLineupScrollSpeed,
            playerLineupScrollDirection: .continuousUp,
            playerViewRosterScope: .fullRoster,
            playerFoulHighlightColor: .yellow,
            isGameClockRedEnabled: false,
            gameClockRedThresholdSeconds: 60,
            isShotClockRedEnabled: false,
            shotClockRedThresholdSeconds: 5,
            homeSubstitutionsAllowed: 0,
            guestSubstitutionsAllowed: 0,
            homeSubstitutionsUsed: 0,
            guestSubstitutionsUsed: 0,
            homePausesAllowed: 0,
            guestPausesAllowed: 0,
            homePausesUsed: 0,
            guestPausesUsed: 0,
            homeTeamFouls: 0,
            guestTeamFouls: 0,
            homeChessClockSeconds: ChessClockPreset.rapid.seconds,
            guestChessClockSeconds: ChessClockPreset.rapid.seconds,
            activeChessClockSide: .home,
            chessClockPreset: .rapid,
            selectedDebatePresetID: DebatePreset.publicForum.id,
            customDebatePreset: .customDefault,
            debateHomeSideLabel: DebatePreset.publicForum.homeSideLabel,
            debateGuestSideLabel: DebatePreset.publicForum.guestSideLabel,
            debateCurrentSegmentIndex: 0,
            debatePrepHomeSeconds: DebatePreset.publicForum.prepSecondsPerSide,
            debatePrepGuestSeconds: DebatePreset.publicForum.prepSecondsPerSide,
            isDebatePrepTimeEnabled: DebatePreset.publicForum.isPrepTimeEnabled,
            debateActiveTimer: .segment,
            isDebatePrepClockRunning: false,
            isDebateScoreTrackingEnabled: DebatePreset.publicForum.defaultScoreTrackingEnabled,
            isDebatePlayerTrackingEnabled: DebatePreset.publicForum.defaultPlayerTrackingEnabled,
            isDebatePlayerFoulsEnabled: DebatePreset.publicForum.defaultPlayerFoulsEnabled,
            isDebatePlayerCardsEnabled: DebatePreset.publicForum.defaultPlayerCardsEnabled,
            homePenaltyTimers: [],
            guestPenaltyTimers: [],
            homeRoster: defaultRoster,
            guestRoster: defaultRoster,
            theme: .classic,
            showsLiveActivityWhenTimerRunning: true,
            externalDisplayBackgroundMode: .blurred,
            externalDisplayAnimatedLogoStyle: .horizontalMarquee,
            externalDisplayAnimatedLogoBackgroundColor: .themeBackground,
            externalDisplayAnimatedLogoSpeed: ScoreboardStore.defaultAnimatedLogoSpeed,
            externalDisplayAnimatedLogoSize: ScoreboardStore.defaultAnimatedLogoSize,
            externalDisplayAnimatedLogoOpacity: ScoreboardStore.defaultAnimatedLogoOpacity,
            showsExternalDisplayDateTime: false,
            externalDisplayDateTimeFormat: .time24Hour,
            showsExternalDisplayDateTimeSeconds: true,
            externalDisplayDirection: .homeLeft,
            showsTeamLogos: true,
            showsEventLogo: true,
            isSoundEnabled: true,
            bypassedSoundEventsBySport: [:],
            bypassedCompanionEventsBySport: [:],
            soundAssignmentsBySport: ScoreboardStore.defaultSoundAssignmentsBySport,
            keyboardShortcutsByAction: ScoreboardStore.defaultKeyboardShortcutsByAction,
            isCompanionVisible: false,
            isCompanionEnabled: false,
            companionHost: "",
            companionMode: .tcp,
            companionSyncWithSound: false,
            companionPort: ScoreboardCompanionMode.tcp.defaultPort,
            companionAssignmentsBySport: [:],
            didCompleteSetup: false,
            areTipsEnabled: true,
            showGettingStartedOnStartup: true,
            didAutoShowGettingStarted: false,
            setupPresets: [],
            isWebAPIEnabled: false,
            webAPIUpdateMode: .fixedInterval,
            isWebAPIBroadcastControlEnabled: false,
            webAPIBroadcastEnabledDisplayCount: ScoreboardStore.defaultWebAPIBroadcastEnabledDisplayCount,
            webAPIBroadcastDisplayModesByID: [:],
            customDisplayModeTitlesByMode: [:],
            isRemoteDisplayHostEnabled: false,
            isRemoteDisplayViewerModeEnabled: false,
            isRemoteDisplayIndividualControlEnabled: false,
            remoteDisplayNetworkMode: .nearbyAndLocalNetwork
        )
    }
}

@MainActor
final class PublicBoardState: ObservableObject {
    static let shared = PublicBoardState()

    @Published var isPresented = false
    @Published var fullscreenRequestID = UUID()

    private init() {}

    func requestFullscreen() {
        fullscreenRequestID = UUID()
    }
}

// Only the clock(s) touched by a remote operation are moved back to the tap time.
// The existing timer engine then advances them through the command's travel time,
// preserving its expiration, sound, and Companion behavior on this main device.

@MainActor
extension ScoreboardStore {
    private static let sessionLogger = Logger(subsystem: "IronMaple.smartScoreboard", category: "SessionHandoff")

    private func canAcceptIncomingSession(_ incoming: ScoreboardSessionDescriptor) -> Bool {
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        guard receiver.authenticatedSessionOwnerHostID == incoming.ownerHostID else { return false }
        guard let current = sessionDescriptor else { return true }
        if current.accepts(incoming) { return true }
        // Pairing authorizes an idle display/controller to join a new match.
        // Epoch checks still apply within the same match; a live or unresolved
        // host must finish its handoff or explicitly discard its working copy.
        return current.sessionID != incoming.sessionID && !hasHostedMatchToDiscard
            && sessionRecoveryRole != .prepared && !sessionTransferInProgress
            && (isRemoteDisplayViewerModeEnabled || !isSessionOwner ||
                ScoreboardRemoteDisplayDeviceType.current == .appleTV)
    }

    private func configureSessionService() {
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        remoteDisplayHostService.sessionMessageHandler = { [weak self] data, senderID in
            self?.receiveSessionMessage(data, senderID: senderID, fromHost: false)
        }
        remoteDisplayHostService.commandSessionValidator = { [weak self] id, epoch in
            guard let self, self.isSessionAuthority else { return false }
            guard let descriptor = self.sessionDescriptor else { return id == nil && epoch == nil }
            if descriptor.epoch == 0 && id == nil && epoch == nil { return true }
            return descriptor.sessionID == id && descriptor.epoch == epoch
        }
        remoteDisplayHostService.maintenanceHandler = { [weak self] in self?.maintainSession() }
        receiver.sessionMessageHandler = { [weak self] data in
            self?.receiveSessionMessage(data, senderID: nil, fromHost: true)
        }
        receiver.commandSessionProvider = { [weak receiver] in
            guard let descriptor = receiver?.state?.control?.session else { return nil }
            return (descriptor.sessionID, descriptor.epoch)
        }
        receiver.$state.sink { [weak self] state in
            guard let self, let state else { return }
            if let incoming = state.control?.session {
                // Locally published hosted state is already authoritative.
                if !receiver.isHostingSession && !self.canAcceptIncomingSession(incoming) { return }
                if !receiver.isHostingSession, self.sessionDescriptor?.sessionID != incoming.sessionID {
                    self.sessionRecoveryRole = .follower
                    self.sessionAuthorityFenced = true
                    self.sessionTransferCheckpoint = nil
                    self.sessionTransferID = nil
                    self.sessionTransferTargetID = nil
                    // Ordinary remote clients keep their active session only
                    // in memory. Only the owner needs a durable recovery copy.
                    if incoming.ownerDeviceID == self.localSessionDeviceID {
                        try? ScoreboardSessionRecovery(role: .follower, descriptor: incoming,
                                                       checkpoint: nil, transferID: nil).save()
                    }
                    Self.sessionLogger.notice("Adopted the authenticated paired session")
                }
                if self.sessionRecoveryRole == .fenced,
                   incoming.hostDeviceID == self.sessionTransferTargetID,
                   incoming.epoch == self.sessionDescriptor?.epoch {
                    self.completeSessionTransfer(incoming)
                }
                if self.sessionDescriptor == nil || self.sessionDescriptor != incoming {
                    self.sessionDescriptor = incoming
                    if incoming.ownerDeviceID == self.localSessionDeviceID && incoming.hostDeviceID != self.localSessionDeviceID {
                        self.sessionRecoveryRole = .follower
                        try? ScoreboardSessionRecovery(role: .follower, descriptor: incoming,
                                                       checkpoint: self.sessionTransferCheckpoint, transferID: nil).save()
                    }
                }
                self.requestSessionLogsIfNeeded()
            }
            if self.isFollowingSessionHost { self.applyRemoteControlState(state) }
        }.store(in: &cancellables)
        receiver.$status.sink { [weak self] status in
            guard let self, self.isFollowingSessionHost else { return }
            self.sessionConnectionStatus = status.isLive ? "Connected" : "Disconnected"
            self.sessionIsConnected = status.isLive
            self.sessionRoundTripSeconds = status.isLive ? receiver.roundTripSeconds : nil
            let message = self.sessionStatusMessage
            if !self.sessionTransferInProgress,
               message == nil || message?.hasPrefix("Waiting for ") == true || message?.hasPrefix("Connected to ") == true {
                self.sessionStatusMessage = status.isLive
                    ? "Connected to \(self.sessionHostDisplayName)."
                    : "Waiting for \(self.sessionHostDisplayName) to connect…"
            }
            if status.isLive {
                self.scheduleOwnerSettingsSync()
                if !self.pendingOwnerVisualFields.isEmpty { self.scheduleOwnerVisualSync() }
            }
        }.store(in: &cancellables)
        receiver.$roundTripSeconds.sink { [weak self] latency in
            guard let self, self.isFollowingSessionHost else { return }
            self.sessionRoundTripSeconds = latency
        }.store(in: &cancellables)
        receiver.$imageAssetsByID.sink { [weak self] _ in
            guard let self, self.isFollowingSessionHost,
                  let state = self.remoteControlState else { return }
            self.isApplyingSessionUpdate = true
            self.applyRemoteControlImages(state)
            self.isApplyingSessionUpdate = false
        }.store(in: &cancellables)
        $webAPIStatus.sink { [weak self] status in
            guard let self, self.isSessionAuthority, var descriptor = self.sessionDescriptor else { return }
            let value = status.healthValue
            if descriptor.hostWebAPIStatus != value {
                descriptor.hostWebAPIStatus = value
                self.sessionDescriptor = descriptor
                self.refreshRemoteDisplayState()
            }
        }.store(in: &cancellables)
        objectWillChange.sink { [weak self] _ in
            self?.scheduleOwnerSettingsSync()
        }.store(in: &cancellables)
        let visualChanges: [AnyPublisher<String, Never>] = [
            $externalDisplayBackgroundMode.dropFirst().map { _ in "backgroundMode" }.eraseToAnyPublisher(),
            $externalDisplayBackgroundImage.dropFirst().map { _ in "backgroundImage" }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoStyle.dropFirst().map { _ in "logoStyle" }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoBackgroundColor.dropFirst().map { _ in "logoColor" }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoSpeed.dropFirst().map { _ in "logoSpeed" }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoSize.dropFirst().map { _ in "logoSize" }.eraseToAnyPublisher(),
            $externalDisplayAnimatedLogoOpacity.dropFirst().map { _ in "logoOpacity" }.eraseToAnyPublisher(),
            $showsExternalDisplayDateTime.dropFirst().map { _ in "dateTime" }.eraseToAnyPublisher(),
            $externalDisplayDateTimeFormat.dropFirst().map { _ in "dateTimeFormat" }.eraseToAnyPublisher(),
            $showsExternalDisplayDateTimeSeconds.dropFirst().map { _ in "dateTimeSeconds" }.eraseToAnyPublisher(),
            $showsTeamLogos.dropFirst().map { _ in "teamLogosVisible" }.eraseToAnyPublisher(),
            $showsEventLogo.dropFirst().map { _ in "eventLogoVisible" }.eraseToAnyPublisher(),
            $homeTeamLogoImage.dropFirst().map { _ in "homeLogo" }.eraseToAnyPublisher(),
            $guestTeamLogoImage.dropFirst().map { _ in "guestLogo" }.eraseToAnyPublisher(),
            $eventLogoImage.dropFirst().map { _ in "eventLogo" }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(visualChanges).sink { [weak self] field in
            guard let self, !self.isApplyingRemoteControlState, !self.isApplyingSessionUpdate else { return }
            self.scheduleOwnerVisualSync(field: field)
        }.store(in: &cancellables)
        let sessionTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isFollowingSessionHost { self.projectRemoteControlClocks() }
                self.maintainSession()
            }
        }
        RunLoop.main.add(sessionTimer, forMode: .common)
        if isFollowingSessionHost { attachOwnerReceiver() }
        else if isRemoteDisplayHostEnabled && sessionDescriptor == nil { ensureOwnedSessionDescriptor() }
    }

    private func ensureOwnedSessionDescriptor() {
        guard sessionDescriptor == nil, isSessionAuthority, !isRemoteControlProxy else { return }
        let descriptor = ScoreboardSessionDescriptor(sessionID: UUID(), epoch: 0,
            ownerDeviceID: localSessionDeviceID, ownerHostID: remoteDisplayHostID,
            ownerName: remoteDisplayHostName, hostDeviceID: localSessionDeviceID,
            hostName: remoteDisplayHostName,
            hostAddresses: ScoreboardWebAPIService.localIPv4Addresses(),
            hostWebAPIStatus: webAPIStatus.healthValue, hostCompanionEnabled: isCompanionEnabled,
            logSessionID: logManager.currentSessionSnapshot()?.sessionID)
        sessionDescriptor = descriptor
        sessionRecoveryRole = .host
        do {
            let checkpoint = try makeSessionCheckpoint(descriptor: descriptor)
            try ScoreboardSessionRecovery(role: .host, descriptor: descriptor,
                                          checkpoint: checkpoint, transferID: nil).save()
            sessionTransferCheckpoint = checkpoint
        } catch {
            sessionStatusMessage = "Session recovery could not be saved: \(error.localizedDescription)"
        }
    }

    private func attachOwnerReceiver() {
        guard isSessionOwner, let descriptor = sessionDescriptor,
              let checkpoint = sessionTransferCheckpoint,
              let peer = checkpoint.pairings.peers.first(where: { $0.id == localSessionDeviceID }),
              let secret = peer.pairingSecret else { return }
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        if !sessionOwnerReceiverAcquired {
            receiver.acquire(networkMode: remoteDisplayNetworkMode)
            sessionOwnerReceiverAcquired = true
        }
        receiver.trustSessionHost(ownerHostID: descriptor.ownerHostID,
                                  ownerName: descriptor.ownerName, pairingSecret: secret, isOwner: true)
        sessionOwnerPairingSecret = secret
        lastOwnerSettingsData = nil
        lastOwnerVisualData = nil
    }

    private func sendSession(_ message: ScoreboardSessionMessage, to displayID: String? = nil,
                             lowPriority: Bool = false) -> Bool {
        guard let data = try? JSONEncoder().encode(message) else { return false }
        if let displayID { return remoteDisplayHostService.sendSessionMessage(data, toDisplayID: displayID,
                                                                               lowPriority: lowPriority) }
        return ScoreboardRemoteDisplayReceiver.shared.sendSessionMessage(data)
    }

    private func recordSessionFailure(_ message: String) {
        Self.sessionLogger.error("Host handoff failed: \(message, privacy: .public)")
        sessionStatusMessage = message
        sessionTransferInProgress = false
        sessionTransferID = nil
        sessionTransferTargetID = nil
        sessionTransferStartedAt = nil
        lastSessionPrepareSentAt = nil
        disconnectClientsAfterOwnerTakeover = false
        disablePairingAfterHostTransfer = false
        exitRemoteModeAfterHostTransfer = false
        let completion = hostedMatchQuitCompletion
        hostedMatchQuitCompletion = nil
        completion?(false)
    }

    private func resumeAfterRejectedHostCommit(_ detail: String) {
        guard sessionRecoveryRole == .fenced, let checkpoint = sessionTransferCheckpoint,
              checkpoint.descriptor.epoch < UInt64.max else {
            sessionStatusMessage = detail
            return
        }
        var restored = checkpoint
        restored.descriptor.epoch += 1
        restored.descriptor.hostDeviceID = localSessionDeviceID
        restored.descriptor.hostName = remoteDisplayHostName
        restored.descriptor.hostAddresses = ScoreboardWebAPIService.localIPv4Addresses()
        restored.descriptor.safeToDisconnect = nil
        do {
            try ScoreboardSessionRecovery(role: .host, descriptor: restored.descriptor,
                                          checkpoint: restored, transferID: nil).save()
            sessionTransferInProgress = false
            sessionTransferID = nil
            sessionTransferTargetID = nil
            sessionTransferStartedAt = nil
            lastSessionCommitSentAt = nil
            sessionTransferCheckpoint = restored
            activateSessionCheckpoint(restored, fromRecovery: false)
            if isSessionAuthority {
                sessionStatusMessage = "Host transfer failed; this device is still hosting. \(detail)"
            }
        } catch {
            sessionStatusMessage = "Could not resume the previous host: \(error.localizedDescription)"
        }
    }

    private func makeSessionCheckpoint(descriptor: ScoreboardSessionDescriptor) throws -> ScoreboardSessionCheckpoint {
        var pairings = remoteDisplayHostService.exportSessionPairings()
        if descriptor.ownerDeviceID == localSessionDeviceID,
           !pairings.peers.contains(where: { $0.id == localSessionDeviceID }) {
            let secret = sessionOwnerPairingSecret ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
            sessionOwnerPairingSecret = secret
            pairings.peers.append(.init(id: localSessionDeviceID, name: descriptor.ownerName,
                                        deviceType: ScoreboardRemoteDisplayDeviceType.current,
                                        pairingSecret: secret))
        }
        return ScoreboardSessionCheckpoint(
            descriptor: descriptor, settings: try exportPersistedStateData(), game: currentGameSnapshot(),
            runtime: currentWebAPIState().runtime, gameName: currentGameDisplayName,
            ownerGameFilename: isSessionOwner
                ? ScoreboardPreferences.current.string(forKey: "scoreboard.workingGameFilename")
                : sessionTransferCheckpoint?.ownerGameFilename,
            mainDisplayMode: publicDisplayViewMode, pairings: pairings,
            allowedControllers: remoteControlAllowedDisplayIDs,
            webControlEnabled: isWebControlEnabled, webControlKey: webControlAPIKey,
            log: logManager.currentSessionSnapshot() ?? ScoreboardLogSession(),
            capturedAt: Date().timeIntervalSince1970,
            gameElapsed: accumulatedGameClockElapsed, shotElapsed: accumulatedShotClockElapsed,
            penaltyElapsed: accumulatedPenaltyElapsed, prepElapsed: accumulatedDebatePrepElapsed,
            pauseElapsed: accumulatedPauseElapsed)
    }

    private func persistOwnerSessionFile(_ checkpoint: ScoreboardSessionCheckpoint) throws {
        guard checkpoint.descriptor.ownerDeviceID == localSessionDeviceID else { return }
        let directory = try ScoreboardFileStorage.storedGamesDirectory()
        let proposed = checkpoint.ownerGameFilename ?? ""
        let isSafeFilename = !proposed.isEmpty && proposed == URL(fileURLWithPath: proposed).lastPathComponent
            && URL(fileURLWithPath: proposed).pathExtension.lowercased() == "scoreboardgame"
        let filename = isSafeFilename ? proposed : "Recovered-\(checkpoint.descriptor.sessionID.uuidString).scoreboardgame"
        let url = directory.appendingPathComponent(filename)
        try JSONEncoder().encode(checkpoint.game).write(to: url, options: .atomic)
        ScoreboardPreferences.current.set(filename, forKey: "scoreboard.workingGameFilename")
    }

    var canHostOnOwnerAndDisconnectOthers: Bool {
        isSessionOwner && !isRemoteControlProxy && !isAnyTimerRunning && !sessionTransferInProgress &&
            (isSessionAuthority || canChangeSessionHost)
    }

    func hostOnOwnerAndDisconnectOthers() {
        guard canHostOnOwnerAndDisconnectOthers else { return }
        if isSessionAuthority {
            if !isRemoteDisplayHostEnabled { setRemoteDisplayHostEnabled(true) }
            disconnectClientsAfterOwnerTakeover = true
            finishOwnerTakeoverDisconnect()
        } else {
            // Keep the current host and clients connected until the final match
            // and logs have been persisted and authority has transferred here.
            disconnectClientsAfterOwnerTakeover = true
            assignSessionHost(displayID: localSessionDeviceID)
            if !sessionTransferInProgress { disconnectClientsAfterOwnerTakeover = false }
        }
    }

    private func finishOwnerTakeoverDisconnect() {
        guard disconnectClientsAfterOwnerTakeover, isSessionOwner, isSessionAuthority else { return }
        disconnectClientsAfterOwnerTakeover = false
        intentionallyDisconnectedRemoteDisplayIDs.formUnion(remoteDisplayConnectedDisplays.map(\.id))
        remoteDisplayDisconnectedDisplaysByID.removeAll()
        remoteDisplayWarningNotice = nil
        remoteDisplayHostService.disconnectDisplays(includingSavedDisplays: true)
        sessionStatusMessage = "Hosting on this device. Other devices disconnected."
    }

    func assignSessionHost(displayID: String) {
        guard !isAnyTimerRunning else {
            sessionStatusMessage = "Stop all timers before moving the session host."
            return
        }
        guard canChangeSessionHost else {
            recordSessionFailure("Connect to the current host before moving the session.")
            return
        }
        if isFollowingSessionHost {
            guard let descriptor = sessionDescriptor else { return }
            let request = ScoreboardSessionMessage(kind: .requestHost, descriptor: descriptor, targetID: displayID)
            if sendSession(request) {
                sessionTransferInProgress = true
                sessionTransferStartedAt = Date()
                sessionStatusMessage = "Preparing host transfer…"
            }
            else { recordSessionFailure("The current host is disconnected. Reconnect before moving the session.") }
            return
        }
        beginSessionTransfer(to: displayID)
    }

    private func rejectHostTransferForRunningTimers() {
        let detail = "Stop all timers before moving the session host."
        recordSessionFailure(detail)
        if isDelegatedSessionHost, let descriptor = sessionDescriptor {
            _ = sendSession(.init(kind: .error, descriptor: descriptor, detail: detail),
                            to: descriptor.ownerDeviceID)
        }
    }

    private func beginSessionTransfer(to targetID: String) {
        guard isSessionAuthority, !sessionTransferInProgress else { return }
        guard !isAnyTimerRunning else {
            rejectHostTransferForRunningTimers()
            return
        }
        guard targetID != localSessionDeviceID,
              let target = remoteDisplayConnectedDisplays.first(where: { $0.id == targetID && $0.supportsSessionHosting }) else {
            recordSessionFailure("The selected device must be connected and support session hosting.")
            return
        }
        let old: ScoreboardSessionDescriptor
        if let sessionDescriptor { old = sessionDescriptor }
        else {
            old = ScoreboardSessionDescriptor(sessionID: UUID(), epoch: 0,
                ownerDeviceID: localSessionDeviceID, ownerHostID: remoteDisplayHostID,
                ownerName: remoteDisplayHostName, hostDeviceID: localSessionDeviceID,
                hostName: remoteDisplayHostName,
                hostAddresses: ScoreboardWebAPIService.localIPv4Addresses(),
                hostWebAPIStatus: webAPIStatus.healthValue, hostCompanionEnabled: isCompanionEnabled,
                logSessionID: logManager.currentSessionSnapshot()?.sessionID)
            sessionDescriptor = old
            sessionRecoveryRole = .host
            if let checkpoint = try? makeSessionCheckpoint(descriptor: old) {
                sessionTransferCheckpoint = checkpoint
                try? ScoreboardSessionRecovery(role: .host, descriptor: old,
                                               checkpoint: checkpoint, transferID: nil).save()
            }
        }
        guard old.epoch < UInt64.max else { recordSessionFailure("Session version limit reached."); return }
        var next = old
        next.epoch += 1
        next.hostDeviceID = targetID
        next.hostName = target.name
        next.hostAddresses = []
        next.hostWebAPIStatus = "starting"
        let transferID = UUID()
        do {
            let checkpoint = try makeSessionCheckpoint(descriptor: next)
            let prepare = ScoreboardSessionMessage(kind: .prepare, id: transferID,
                                                   descriptor: next, targetID: targetID, checkpoint: checkpoint)
            guard sendSession(prepare, to: targetID) else {
                recordSessionFailure("The selected host stopped responding before transfer.")
                return
            }
            sessionTransferID = transferID
            sessionTransferTargetID = targetID
            sessionTransferCheckpoint = checkpoint
            sessionTransferStartedAt = Date()
            lastSessionPrepareSentAt = Date()
            sessionTransferInProgress = true
            sessionStatusMessage = "Preparing \(target.name)…"
            Self.sessionLogger.notice("Sent host preparation; waiting for acknowledgement")
        } catch { recordSessionFailure("Could not prepare the session: \(error.localizedDescription)") }
    }

    private func receiveSessionMessage(_ data: Data, senderID: String?, fromHost: Bool) {
        guard data.count <= ScoreboardSessionTransport.maximumMessageBytes,
              let message = try? JSONDecoder().decode(ScoreboardSessionMessage.self, from: data) else {
            Self.sessionLogger.error("Rejected an unreadable session message")
            return
        }
        if let current = sessionDescriptor,
           current.sessionID != message.descriptor.sessionID && message.kind != .prepare { return }
        switch message.kind {
        case .requestHost:
            guard !fromHost, senderID == sessionDescriptor?.ownerDeviceID,
                  let current = sessionDescriptor, current.accepts(message.descriptor),
                  message.descriptor.epoch == current.epoch, let target = message.targetID else { return }
            if target == localSessionDeviceID {
                let error = ScoreboardSessionMessage(kind: .error, id: message.id,
                    descriptor: message.descriptor, detail: "This device is already the host.")
                _ = sendSession(error, to: senderID)
            } else { beginSessionTransfer(to: target) }
        case .prepare:
            guard fromHost, message.targetID == localSessionDeviceID else { return }
            Self.sessionLogger.notice("Received host preparation")
            guard let checkpoint = message.checkpoint,
                  checkpoint.descriptor == message.descriptor,
                  message.descriptor.epoch > 0,
                  canAcceptIncomingSession(message.descriptor) else {
                let detail: String
                if hasHostedMatchToDiscard || sessionRecoveryRole == .prepared {
                    detail = "This device still holds a hosted match or unfinished handoff. Finish that handoff, or discard its local match from the device's pairing screen before trying again."
                } else {
                    detail = "The proposed host session does not match this device's authenticated pairing or session version. Reconnect it to the current owner and retry."
                }
                sessionStatusMessage = detail
                disconnectClientsAfterOwnerTakeover = false
                disablePairingAfterHostTransfer = false
                Self.sessionLogger.error("Rejected host preparation: local session \(self.sessionDescriptor?.sessionID.uuidString ?? "none", privacy: .public), epoch \(self.sessionDescriptor?.epoch ?? 0); proposed session \(message.descriptor.sessionID.uuidString, privacy: .public), epoch \(message.descriptor.epoch)")
                _ = sendSession(.init(kind: .error, id: message.id,
                                      descriptor: message.descriptor, detail: detail))
                return
            }
            if sessionRecoveryRole == .host && sessionDescriptor?.epoch == message.descriptor.epoch { return }
            do {
                if message.descriptor.ownerDeviceID != localSessionDeviceID {
                    try validatePersistedStateData(checkpoint.settings)
                }
                try ScoreboardSessionRecovery(role: .prepared, descriptor: message.descriptor,
                                              checkpoint: checkpoint, transferID: message.id).save()
                sessionDescriptor = message.descriptor
                sessionRecoveryRole = .prepared
                sessionAuthorityFenced = true
                sessionTransferID = message.id
                sessionTransferCheckpoint = checkpoint
                sessionStatusMessage = "Waiting for host handoff…"
                Self.sessionLogger.notice("Saved incoming host preparation; sending acknowledgement")
                _ = sendSession(.init(kind: .prepared, id: message.id, descriptor: message.descriptor))
            } catch {
                let detail = "Cannot save incoming host handoff: \(error.localizedDescription)"
                disconnectClientsAfterOwnerTakeover = false
                disablePairingAfterHostTransfer = false
                sessionStatusMessage = detail
                Self.sessionLogger.error("\(detail, privacy: .public)")
                _ = sendSession(.init(kind: .error, id: message.id,
                                      descriptor: message.descriptor, detail: detail))
            }
        case .prepared:
            guard !fromHost, senderID == sessionTransferTargetID,
                  message.id == sessionTransferID, sessionTransferInProgress,
                  isSessionAuthority, let targetID = sessionTransferTargetID else { return }
            guard !isAnyTimerRunning else {
                _ = sendSession(.init(kind: .abort, id: message.id, descriptor: message.descriptor), to: targetID)
                rejectHostTransferForRunningTimers()
                return
            }
            lastSessionPrepareSentAt = nil
            Self.sessionLogger.notice("Received host preparation acknowledgement; fencing local authority")
            do {
                reconcileRunningTimersWithWallClock()
                let final = try makeSessionCheckpoint(descriptor: message.descriptor)
                // The durable fence precedes the commit packet. A lost ACK must
                // never restart this clock or trigger duplicate Companion actions.
                try ScoreboardSessionRecovery(role: .fenced, descriptor: message.descriptor,
                                              checkpoint: final, transferID: message.id).save()
                sessionAuthorityFenced = true
                sessionRecoveryRole = .fenced
                sessionDescriptor = message.descriptor
                sessionTransferCheckpoint = final
                timer?.invalidate(); timer = nil; lastTimerFireDate = nil
                clearQueuedEventActions()
                stopWebAPIService()
                remoteDisplayHostService.fenceSessionTraffic(to: targetID)
                let commit = ScoreboardSessionMessage(kind: .commit, id: message.id,
                    descriptor: message.descriptor, targetID: targetID, checkpoint: final)
                guard sendSession(commit, to: targetID) else {
                    sessionStatusMessage = "Handoff is fenced; waiting to retry delivery to \(message.descriptor.hostName)."
                    return
                }
                lastSessionCommitSentAt = Date()
                sessionStatusMessage = "Activating \(message.descriptor.hostName)…"
            } catch { recordSessionFailure("Could not fence old host: \(error.localizedDescription)") }
        case .commit:
            guard fromHost, message.targetID == localSessionDeviceID,
                  let checkpoint = message.checkpoint,
                  checkpoint.descriptor == message.descriptor,
                  sessionTransferID == message.id,
                  sessionRecoveryRole == .prepared || sessionRecoveryRole == .host else { return }
            if isSessionAuthority, let current = sessionDescriptor,
               current.sessionID == message.descriptor.sessionID,
               current.epoch == message.descriptor.epoch,
               current.hostDeviceID == message.descriptor.hostDeviceID {
                // Addresses and sync status can change immediately after
                // activation. A retried commit acknowledges that authority;
                // it must never reapply the old game checkpoint.
                _ = sendSession(.init(kind: .committed, id: message.id, descriptor: current))
                return
            }
            do {
                if message.descriptor.ownerDeviceID == localSessionDeviceID {
                    try persistOwnerSessionFile(checkpoint)
                    try logManager.adoptAuthoritativeSession(checkpoint.log, gameDisplayName: checkpoint.gameName)
                    logManager.flushPendingWrites()
                } else {
                    try ScoreboardHostedMatchStorage.save(checkpoint)
                    try logManager.adoptAuthoritativeSession(checkpoint.log, gameDisplayName: checkpoint.gameName,
                        storageURL: ScoreboardHostedMatchStorage.logURL(for: message.descriptor.sessionID))
                }
                try ScoreboardSessionRecovery(role: .host, descriptor: message.descriptor,
                                              checkpoint: checkpoint, transferID: message.id).save()
                sessionTransferCheckpoint = checkpoint
                activateSessionCheckpoint(checkpoint, fromRecovery: false)
                if isSessionAuthority {
                    _ = sendSession(.init(kind: .committed, id: message.id,
                                          descriptor: sessionDescriptor ?? message.descriptor))
                } else {
                    disconnectClientsAfterOwnerTakeover = false
                    disablePairingAfterHostTransfer = false
                    try? ScoreboardSessionRecovery(role: .fenced, descriptor: message.descriptor,
                                                   checkpoint: checkpoint, transferID: message.id).save()
                    _ = sendSession(.init(kind: .error, id: message.id,
                        descriptor: message.descriptor,
                        detail: sessionStatusMessage ?? "The new host could not activate the match."))
                }
            } catch {
                let detail = "Cannot activate host: \(error.localizedDescription)"
                disconnectClientsAfterOwnerTakeover = false
                disablePairingAfterHostTransfer = false
                sessionStatusMessage = detail
                sessionRecoveryRole = .fenced
                sessionAuthorityFenced = true
                try? ScoreboardSessionRecovery(role: .fenced, descriptor: message.descriptor,
                                               checkpoint: checkpoint, transferID: message.id).save()
                _ = sendSession(.init(kind: .error, id: message.id,
                                      descriptor: message.descriptor, detail: detail))
            }
        case .committed:
            if fromHost, disablePairingAfterHostTransfer, isSessionOwner, isSessionAuthority,
               message.id == sessionTransferID,
               message.descriptor.sessionID == sessionDescriptor?.sessionID,
               message.descriptor.epoch == sessionDescriptor?.epoch {
                finishDisablingOwnerPairing()
                return
            }
            guard !fromHost, senderID == sessionTransferTargetID,
                  message.id == sessionTransferID, sessionRecoveryRole == .fenced,
                  message.descriptor.sessionID == sessionDescriptor?.sessionID,
                  message.descriptor.epoch == sessionDescriptor?.epoch else { return }
            // Confirm receipt before dropping the old host transport. An owner
            // ending pairing waits for this before closing its receiver.
            _ = sendSession(.init(kind: .committed, id: message.id, descriptor: message.descriptor),
                            to: senderID)
            completeSessionTransfer(message.descriptor)
        case .abort:
            guard fromHost, sessionRecoveryRole == .prepared, message.id == sessionTransferID else { return }
            disconnectClientsAfterOwnerTakeover = false
            disablePairingAfterHostTransfer = false
            sessionTransferCheckpoint = nil
            sessionTransferID = nil
            sessionRecoveryRole = nil
            sessionAuthorityFenced = false
            sessionDescriptor = nil
            try? FileManager.default.removeItem(at: ScoreboardSessionRecovery.url)
        case .settings:
            if fromHost { return }
            guard senderID == sessionDescriptor?.ownerDeviceID, isSessionAuthority,
                  message.descriptor.epoch == sessionDescriptor?.epoch else { return }
            if let settings = message.integrationSettings { applySessionIntegrationSettings(settings) }
            if let visual = message.game, let fields = message.visualFields {
                applySessionVisualSnapshot(visual, fields: fields)
            }
            if let name = message.gameName { currentGameDisplayName = name; logManager.setCurrentGameDisplayName(name) }
        case .game:
            guard !fromHost, senderID == sessionDescriptor?.ownerDeviceID, isSessionAuthority,
                  message.descriptor.epoch == sessionDescriptor?.epoch,
                  let snapshot = message.game else { return }
            isApplyingSessionUpdate = true
            applyGameSnapshot(snapshot)
            if let name = message.gameName { currentGameDisplayName = name; logManager.setCurrentGameDisplayName(name) }
            isApplyingSessionUpdate = false
        case .administration:
            guard !fromHost, senderID == sessionDescriptor?.ownerDeviceID, isSessionAuthority,
                  message.descriptor.epoch == sessionDescriptor?.epoch,
                  let admin = message.administration else { return }
            applySessionAdministration(admin)
        case .peers:
            guard fromHost, isSessionOwner, isFollowingSessionHost,
                  sessionDescriptor?.accepts(message.descriptor) == true else { return }
            if let peers = message.peers { sessionHostPeers = peers }
            if let pairings = message.pairingConfiguration {
                remoteDisplayTrustedDisplays = pairings.peers.filter { $0.id != localSessionDeviceID }
                remoteDisplayMutedDisplayIDs = pairings.mutedDisplayIDs
                remoteDisplayDirectionsByID = pairings.displayDirectionsByID
                remoteDisplayCustomDisplayIDsByDisplayID = pairings.customDisplayIDsByID
                ScoreboardRemoteDisplayPairingStore.saveTrustedDisplays(remoteDisplayTrustedDisplays)
                ScoreboardRemoteDisplayPairingStore.saveMutedDisplayIDs(pairings.mutedDisplayIDs)
                ScoreboardRemoteDisplayPairingStore.saveDisplayDirectionsByID(pairings.displayDirectionsByID)
                ScoreboardRemoteDisplayPairingStore.saveCustomDisplayIDsByID(pairings.customDisplayIDsByID)
            }
            if let peers = message.peers {
                remoteDisplayConnectedDisplays = peers.filter { $0.connected && $0.id != localSessionDeviceID }.map { peer in
                    ScoreboardRemoteDisplayConnection(id: peer.id, name: peer.name, quality: peer.quality ?? .live,
                        latencyMilliseconds: peer.latencyMilliseconds,
                        lastHandshakeAgeSeconds: peer.lastHandshakeAgeSeconds, appVersion: peer.appVersion,
                        deviceType: peer.deviceType,
                        isMuted: remoteDisplayMutedDisplayIDs.contains(peer.id),
                        supportsSessionHosting: peer.supportsHosting)
                }
            }
            if let allowed = message.allowedControllers {
                remoteControlAllowedDisplayIDs = allowed
                ScoreboardPreferences.current.set(allowed.sorted(), forKey: "scoreboard.remoteControlAllowedDisplayIDs")
            }
        case .logRequest:
            guard !fromHost, isSessionAuthority, let senderID,
                  remoteDisplayConnectedDisplays.contains(where: { $0.id == senderID }) else { return }
            if let cursor = message.cursor { logCursorByPeer[senderID] = cursor }
            else { logCursorByPeer.removeValue(forKey: senderID) }
            pendingLogBatchByPeer.removeValue(forKey: senderID)
            sendNextLogPage(to: senderID)
        case .logBatch:
            guard fromHost, let batch = message.batch,
                  sessionDescriptor?.accepts(message.descriptor) == true else { return }
            do {
                let cursor = try logManager.mergeReplicatedLogBatch(batch)
                _ = sendSession(.init(kind: .logAck, descriptor: message.descriptor, cursor: cursor))
            } catch { sessionStatusMessage = "Log synchronization will retry: \(error.localizedDescription)" }
        case .logAck:
            guard !fromHost, isSessionAuthority, let senderID, let cursor = message.cursor,
                  let pending = pendingLogBatchByPeer[senderID], cursor.sessionID == pending.sessionID,
                  cursor.nextIndex >= pending.nextCursor.nextIndex else { return }
            logCursorByPeer[senderID] = cursor
            pendingLogBatchByPeer.removeValue(forKey: senderID)
        case .snapshot:
            guard fromHost, isFollowingSessionHost,
                  sessionDescriptor?.accepts(message.descriptor) == true,
                  let checkpoint = message.checkpoint,
                  checkpoint.descriptor.sessionID == message.descriptor.sessionID,
                  checkpoint.descriptor.epoch == message.descriptor.epoch,
                  let revision = message.syncRevision else { return }
            do {
                try persistOwnerSessionFile(checkpoint)
                try logManager.adoptAuthoritativeSession(checkpoint.log, gameDisplayName: checkpoint.gameName)
                logManager.flushPendingWrites()
                try ScoreboardSessionRecovery(role: .follower, descriptor: message.descriptor,
                                              checkpoint: checkpoint, transferID: nil).save()
                sessionTransferCheckpoint = checkpoint
                _ = sendSession(.init(kind: .snapshotAck, id: message.id,
                                      descriptor: message.descriptor, syncRevision: revision))
            } catch {
                sessionStatusMessage = "Could not save the host's match copy: \(error.localizedDescription)"
            }
        case .snapshotAck:
            guard !fromHost, isDelegatedSessionHost,
                  senderID == sessionDescriptor?.ownerDeviceID,
                  message.id == pendingSnapshotSyncID,
                  message.syncRevision == sessionSyncRevision else { return }
            ownerAcknowledgedRevision = sessionSyncRevision
            ownerAcknowledgedLogCount = pendingSnapshotLogCount
            pendingSnapshotSyncID = nil
            updateSessionSafeDisconnectStatus()
        case .error:
            if fromHost {
                recordSessionFailure(message.detail ?? "Host transfer failed.")
            } else if senderID == sessionTransferTargetID,
                      message.id == sessionTransferID, sessionTransferInProgress {
                let detail = message.detail ?? "The selected host could not activate the match."
                if sessionRecoveryRole == .fenced { resumeAfterRejectedHostCommit(detail) }
                else if sessionRecoveryRole == .host { recordSessionFailure(detail) }
            }
        }
    }

    private func activateSessionCheckpoint(_ checkpoint: ScoreboardSessionCheckpoint, fromRecovery: Bool) {
        let descriptor = checkpoint.descriptor
        guard descriptor.hostDeviceID == localSessionDeviceID else { return }
        let wasRemoteViewer = isRemoteDisplayViewerModeEnabled
        isApplyingSessionUpdate = true
        sessionDescriptor = descriptor
        sessionRecoveryRole = .host
        sessionAuthorityFenced = false
        do {
            if fromRecovery && descriptor.ownerDeviceID != localSessionDeviceID {
                try logManager.adoptAuthoritativeSession(checkpoint.log, gameDisplayName: checkpoint.gameName,
                    storageURL: ScoreboardHostedMatchStorage.logURL(for: descriptor.sessionID))
            }
            if descriptor.ownerDeviceID != localSessionDeviceID {
                try restorePersistedStateData(checkpoint.settings)
            }
        } catch {
            sessionAuthorityFenced = true
            sessionRecoveryRole = .fenced
            sessionStatusMessage = "Host recovery failed: \(error.localizedDescription)"
            Self.sessionLogger.error("Host recovery failed: \(error.localizedDescription, privacy: .public)")
            try? ScoreboardSessionRecovery(role: .fenced, descriptor: descriptor,
                                           checkpoint: checkpoint, transferID: sessionTransferID).save()
            isApplyingSessionUpdate = false
            return
        }
        if descriptor.ownerDeviceID != localSessionDeviceID {
            isRemoteDisplayViewerModeEnabled = wasRemoteViewer
        }
        applyGameSnapshot(checkpoint.game)
        currentGameDisplayName = checkpoint.gameName
        publicDisplayViewMode = checkpoint.mainDisplayMode
        areSidesSwapped = checkpoint.runtime.areSidesSwapped
        possessionDirection = checkpoint.runtime.possessionDirection
        isClockRunning = checkpoint.runtime.isClockRunning
        isShotClockRunning = checkpoint.runtime.isShotClockRunning
        isDebatePrepClockRunning = checkpoint.runtime.isDebatePrepClockRunning
        accumulatedGameClockElapsed = checkpoint.gameElapsed
        accumulatedShotClockElapsed = checkpoint.shotElapsed
        accumulatedPenaltyElapsed = checkpoint.penaltyElapsed
        accumulatedDebatePrepElapsed = checkpoint.prepElapsed
        accumulatedPauseElapsed = checkpoint.pauseElapsed ?? 0
        remoteDisplayHostService.installSessionPairings(checkpoint.pairings)
        remoteControlAllowedDisplayIDs = checkpoint.allowedControllers
        isWebControlEnabled = checkpoint.webControlEnabled
        webControlAPIKey = checkpoint.webControlKey
        isRemoteDisplayHostEnabled = true
        isApplyingSessionUpdate = false
        if descriptor.ownerDeviceID != localSessionDeviceID {
            sessionSyncRevision = 1
            hostedCheckpointPersistedRevision = 1
            ownerAcknowledgedRevision = 0
            ownerAcknowledgedLogCount = -1
            observedHostedLogCount = checkpoint.log.entries.count
        }
        let receiver = ScoreboardRemoteDisplayReceiver.shared
        receiver.hostedControlCommandHandler = { [weak self] command in
            guard let self, self.isSessionAuthority,
                  self.isRemoteControlAllowed(displayID: self.localSessionDeviceID) else {
                return .failure(command.id, "disabled", "This device is no longer the session host.")
            }
            // This command originated on the host itself; there is no network
            // timestamp or transit delay to validate or compensate.
            return self.performControlCommand(command, remote: false)
        }
        let previousHostOffset = receiver.masterClockOffset ?? 0
        receiver.updateHostedState(state: currentRemoteDisplayState(forDisplayID: localSessionDeviceID),
                                   images: currentWebAPIImageResponses())
        updateTimerState()
        // The packet timestamp is in the old host's wall clock. Clock sync turns
        // it into this device's time; a bounded gap covers the handoff network hop.
        let gap = max(0, min(10, Date().timeIntervalSince1970 - (checkpoint.capturedAt - previousHostOffset)))
        if timer != nil {
            lastTimerFireDate = Date().addingTimeInterval(-gap)
            reconcileRunningTimersWithWallClock()
        }
        startRemoteDisplayHostService()
        if isWebAPIEnabled { startWebAPIService() }
        var updated = descriptor
        updated.hostAddresses = ScoreboardWebAPIService.localIPv4Addresses()
        updated.hostWebAPIStatus = webAPIStatus.healthValue
        updated.hostCompanionEnabled = isCompanionEnabled
        sessionDescriptor = updated
        sessionTransferInProgress = false
        sessionTransferStartedAt = nil
        sessionStatusMessage = "Hosting this session."
        sessionConnectionStatus = "Hosting"
        sessionIsConnected = true
        refreshRemoteDisplayState()
        finishOwnerTakeoverDisconnect()
    }

    private func completeSessionTransfer(_ descriptor: ScoreboardSessionDescriptor) {
        let wasOwner = isSessionOwner
        // The outgoing host is already fenced, so isDelegatedSessionHost is
        // false here even though it still owns an isolated working copy.
        let hostedSessionID = wasOwner ? nil : sessionDescriptor?.sessionID
        let followerPairing = sessionTransferCheckpoint?.pairings.peers.first { $0.id == localSessionDeviceID }
        let shouldExitRemoteMode = exitRemoteModeAfterHostTransfer
        let shouldDisablePairing = disablePairingAfterHostTransfer
        Self.sessionLogger.notice("Host handoff completed at epoch \(descriptor.epoch); restoring client pairing")
        sessionTransferInProgress = false
        sessionTransferTargetID = nil
        sessionTransferStartedAt = nil
        lastSessionPrepareSentAt = nil
        lastSessionCommitSentAt = nil
        sessionRecoveryRole = .follower
        sessionAuthorityFenced = true
        sessionDescriptor = descriptor
        stopRemoteDisplayHostService()
        remoteDisplayHostService.clearSessionPairings()
        ScoreboardRemoteDisplayReceiver.shared.stopHostingSession()
        let quitCompletion = hostedMatchQuitCompletion
        hostedMatchQuitCompletion = nil
        if wasOwner {
            try? ScoreboardSessionRecovery(role: .follower, descriptor: descriptor,
                                           checkpoint: sessionTransferCheckpoint, transferID: nil).save()
            attachOwnerReceiver()
            remoteDisplayHostService.startDiscoveryOnly(networkMode: remoteDisplayNetworkMode)
            sessionStatusMessage = "Waiting for \(descriptor.hostName) to connect…"
            sessionConnectionStatus = "Connecting"
            sessionIsConnected = false
        } else {
            // A completed handoff clears the same isolated data as Discard.
            // Retain only receiver pairing so the new host can reconnect it.
            var cleanupError: String?
            if let hostedSessionID {
                do { try removeHostedSessionData(sessionID: hostedSessionID) }
                catch {
                    cleanupError = "Could not remove the old host's match copy: \(error.localizedDescription)"
                    // If deletion failed, replace any authority record with a
                    // non-host marker so a restart cannot revive the old host.
                    try? ScoreboardSessionRecovery(role: .follower, descriptor: descriptor,
                                                   checkpoint: nil, transferID: nil).save()
                }
            }
            clearHostedSessionBookkeeping()
            isApplyingSessionUpdate = true
            loadPersistedState()
            isRemoteDisplayViewerModeEnabled = true
            isApplyingSessionUpdate = false
            sessionConnectionStatus = "Connecting"
            sessionIsConnected = false
            sessionRoundTripSeconds = nil
            if let secret = followerPairing?.pairingSecret, !secret.isEmpty {
                ScoreboardRemoteDisplayReceiver.shared.trustSessionHost(
                    ownerHostID: descriptor.ownerHostID, ownerName: descriptor.hostName,
                    pairingSecret: secret)
            }
            sessionStatusMessage = cleanupError ?? "Waiting for \(descriptor.hostName) to connect…"
            if shouldExitRemoteMode {
                sessionAuthorityFenced = false
                setRemoteDisplayViewerModeEnabled(false)
            }
            persistState()
        }
        if shouldDisablePairing && !wasOwner {
            disablePairingAfterHostTransfer = false
            setRemoteDisplayHostEnabled(false)
        }
        quitCompletion?(true)
    }

    private func finishDisablingOwnerPairing() {
        guard disablePairingAfterHostTransfer, isSessionOwner, isSessionAuthority else { return }
        disablePairingAfterHostTransfer = false
        setRemoteDisplayHostEnabled(false)
        sessionStatusMessage = "Remote Display / Control Pairing is off."
    }

    private func maintainSession() {
        if disablePairingAfterHostTransfer, isSessionOwner, isSessionAuthority,
           !ScoreboardRemoteDisplayReceiver.shared.hasSessionConnection {
            finishDisablingOwnerPairing()
        }
        guard let descriptor = sessionDescriptor else { return }
        if isFollowingSessionHost, sessionTransferInProgress,
           let started = sessionTransferStartedAt, Date().timeIntervalSince(started) > 12 {
            sessionTransferInProgress = false
            sessionTransferStartedAt = nil
            disconnectClientsAfterOwnerTakeover = false
            disablePairingAfterHostTransfer = false
            sessionStatusMessage = "Host transfer did not complete. Reconnect to the host or recover from the owner's last saved copy."
        }
        if sessionTransferInProgress, sessionRecoveryRole == .host,
           let targetID = sessionTransferTargetID,
           let transferID = sessionTransferID,
           let checkpoint = sessionTransferCheckpoint,
           let lastSent = lastSessionPrepareSentAt,
           Date().timeIntervalSince(lastSent) > 2 {
            let prepare = ScoreboardSessionMessage(kind: .prepare, id: transferID,
                descriptor: checkpoint.descriptor, targetID: targetID, checkpoint: checkpoint)
            lastSessionPrepareSentAt = Date()
            if sendSession(prepare, to: targetID) {
                Self.sessionLogger.notice("Retried host preparation")
            } else {
                Self.sessionLogger.warning("Could not retry host preparation; waiting for the display connection")
            }
        }
        if sessionRecoveryRole == .fenced,
           let targetID = sessionTransferTargetID,
           let transferID = sessionTransferID,
           let checkpoint = sessionTransferCheckpoint,
           lastSessionCommitSentAt.map({ Date().timeIntervalSince($0) > 2 }) ?? true {
            let commit = ScoreboardSessionMessage(kind: .commit, id: transferID,
                descriptor: descriptor, targetID: targetID, checkpoint: checkpoint)
            if sendSession(commit, to: targetID) { lastSessionCommitSentAt = Date() }
        }
        if sessionTransferInProgress, sessionRecoveryRole == .host,
           let started = sessionTransferStartedAt, Date().timeIntervalSince(started) > 12 {
            if let target = sessionTransferTargetID, let id = sessionTransferID {
                _ = sendSession(.init(kind: .abort, id: id, descriptor: descriptor), to: target)
            }
            sessionTransferInProgress = false
            sessionTransferID = nil
            sessionTransferTargetID = nil
            sessionTransferStartedAt = nil
            lastSessionPrepareSentAt = nil
            exitRemoteModeAfterHostTransfer = false
            disablePairingAfterHostTransfer = false
            sessionStatusMessage = "Host preparation timed out; the current host is still active. Keep Scoreboard open on the selected display and retry."
            Self.sessionLogger.error("Host preparation timed out; local authority remains active")
            let completion = hostedMatchQuitCompletion
            hostedMatchQuitCompletion = nil
            completion?(false)
        }
        if isSessionAuthority {
            if isDelegatedSessionHost {
                let logCount = logManager.currentSessionSnapshot()?.entries.count ?? 0
                if observedHostedLogCount != logCount {
                    observedHostedLogCount = logCount
                    sessionSyncRevision &+= 1
                }
                let ownerConnected = remoteDisplayConnectedDisplays.contains { $0.id == descriptor.ownerDeviceID }
                if ownerConnected && !isAnyTimerRunning && !sessionTransferInProgress {
                    if hostedCheckpointPersistedRevision != sessionSyncRevision { persistState() }
                    if hostedCheckpointPersistedRevision == sessionSyncRevision,
                       ownerAcknowledgedRevision != sessionSyncRevision,
                       lastSnapshotSyncSentAt.map({ Date().timeIntervalSince($0) > 3 }) ?? true,
                       let checkpoint = try? makeSessionCheckpoint(descriptor: descriptor) {
                        let message = ScoreboardSessionMessage(kind: .snapshot, descriptor: descriptor,
                            checkpoint: checkpoint, syncRevision: sessionSyncRevision)
                        if sendSession(message, to: descriptor.ownerDeviceID, lowPriority: true) {
                            pendingSnapshotSyncID = message.id
                            pendingSnapshotLogCount = checkpoint.log.entries.count
                            lastSnapshotSyncSentAt = Date()
                        }
                    }
                }
                updateSessionSafeDisconnectStatus()
            }
            if lastSessionPeerReportAt.map({ Date().timeIntervalSince($0) > 1 }) ?? true {
                lastSessionPeerReportAt = Date()
                let peers = remoteDisplayHostService.exportSessionPairings()
                let connected = Set(remoteDisplayConnectedDisplays.map(\.id))
                let rows = peers.peers.map { peer in
                    let connection = remoteDisplayConnectedDisplays.first { $0.id == peer.id }
                    return ScoreboardSessionPeer(id: peer.id, name: peer.name,
                        deviceType: peer.deviceType ?? .unknown,
                        connected: connected.contains(peer.id) || peer.id == localSessionDeviceID,
                        supportsHosting: peer.id == localSessionDeviceID ||
                            connection?.supportsSessionHosting == true,
                        latencyMilliseconds: connection?.latencyMilliseconds,
                        lastHandshakeAgeSeconds: connection?.lastHandshakeAgeSeconds,
                        appVersion: connection?.appVersion ?? (peer.id == localSessionDeviceID ? .current : nil),
                        quality: connection?.quality,
                        realtimeTransport: connection?.realtimeTransport)
                }
                let report = ScoreboardSessionMessage(kind: .peers, descriptor: descriptor,
                    peers: rows, pairingConfiguration: peers,
                    allowedControllers: remoteControlAllowedDisplayIDs)
                if descriptor.ownerDeviceID != localSessionDeviceID {
                    _ = sendSession(report, to: descriptor.ownerDeviceID, lowPriority: true)
                }
            }
            for peer in remoteDisplayConnectedDisplays where peer.supportsSessionHosting {
                sendNextLogPage(to: peer.id)
            }
        } else if !ScoreboardRemoteDisplayReceiver.shared.isHostingSession {
            requestSessionLogsIfNeeded()
        }
    }

    private func updateSessionSafeDisconnectStatus() {
        guard isDelegatedSessionHost, var descriptor = sessionDescriptor else { return }
        let ownerConnected = remoteDisplayConnectedDisplays.contains { $0.id == descriptor.ownerDeviceID }
        let logCount = logManager.currentSessionSnapshot()?.entries.count ?? 0
        let clean = ScoreboardSessionCleanState(ownerConnected: ownerConnected,
            anyTimerRunning: isAnyTimerRunning, transferring: sessionTransferInProgress,
            revision: sessionSyncRevision, persistedRevision: hostedCheckpointPersistedRevision,
            acknowledgedRevision: ownerAcknowledgedRevision, logCount: logCount,
            acknowledgedLogCount: ownerAcknowledgedLogCount).isSafeToDisconnect
        if descriptor.safeToDisconnect != clean {
            descriptor.safeToDisconnect = clean
            sessionDescriptor = descriptor
            refreshRemoteDisplayState()
        }
    }

    private func requestSessionLogsIfNeeded() {
        guard !isSessionAuthority, let descriptor = sessionDescriptor,
              ScoreboardRemoteDisplayReceiver.shared.status.isLive,
              lastSessionLogRequestAt.map({ Date().timeIntervalSince($0) > 3 }) ?? true else { return }
        let cursor = logManager.receivedLogCursor(for: descriptor.logSessionID ?? UUID())
        if sendSession(.init(kind: .logRequest, descriptor: descriptor, cursor: cursor)) {
            lastSessionLogRequestAt = Date()
        }
    }

    private func sendNextLogPage(to peerID: String) {
        guard isSessionAuthority, !sessionTransferInProgress, let descriptor = sessionDescriptor,
              lastLogPageAtByPeer[peerID].map({ Date().timeIntervalSince($0) > 1 }) ?? true else { return }
        if let pending = pendingLogBatchByPeer[peerID] {
            guard lastLogPageAtByPeer[peerID].map({ Date().timeIntervalSince($0) > 3 }) ?? true else { return }
            let resend = ScoreboardSessionMessage(kind: .logBatch, descriptor: descriptor, batch: pending)
            if sendSession(resend, to: peerID, lowPriority: true) { lastLogPageAtByPeer[peerID] = Date() }
            return
        }
        guard let batch = try? logManager.sessionLogBatch(after: logCursorByPeer[peerID]) else { return }
        let message = ScoreboardSessionMessage(kind: .logBatch, descriptor: descriptor, batch: batch)
        if sendSession(message, to: peerID, lowPriority: true) {
            pendingLogBatchByPeer[peerID] = batch
            lastLogPageAtByPeer[peerID] = Date()
        }
    }

    private func currentSessionIntegrationSettings() -> ScoreboardSessionIntegrationSettings {
        .init(webAPIEnabled: isWebAPIEnabled, webControlEnabled: isWebControlEnabled,
              webControlKey: webControlAPIKey, webUpdateMode: webAPIUpdateMode,
              companionEnabled: isCompanionEnabled, companionHost: companionHost,
              companionMode: companionMode, companionPort: companionPort,
              companionSyncWithSound: companionSyncWithSound,
              companionAssignments: companionAssignmentsBySport,
              soundEnabled: isSoundEnabled, soundAssignments: soundAssignmentsBySport,
              bypassedSoundEvents: bypassedSoundEventsBySport,
              bypassedCompanionEvents: bypassedCompanionEventsBySport,
              broadcastControlEnabled: isWebAPIBroadcastControlEnabled,
              broadcastDisplayCount: webAPIBroadcastEnabledDisplayCount,
              broadcastModes: webAPIBroadcastDisplayModesByID,
              customDisplayTitles: customDisplayModeTitlesByMode,
              remoteIndividualControlEnabled: isRemoteDisplayIndividualControlEnabled,
              remoteNetworkMode: remoteDisplayNetworkMode)
    }

    private func applySessionIntegrationSettings(_ settings: ScoreboardSessionIntegrationSettings) {
        guard isSessionAuthority else { return }
        isApplyingSessionUpdate = true
        isWebAPIEnabled = settings.webAPIEnabled
        isWebControlEnabled = settings.webControlEnabled
        webControlAPIKey = settings.webControlKey
        webAPIUpdateMode = settings.webUpdateMode
        isCompanionEnabled = settings.companionEnabled
        companionHost = settings.companionHost
        companionMode = settings.companionMode
        companionPort = settings.companionPort
        companionSyncWithSound = settings.companionSyncWithSound
        companionAssignmentsBySport = settings.companionAssignments
        isSoundEnabled = settings.soundEnabled
        soundAssignmentsBySport = settings.soundAssignments
        bypassedSoundEventsBySport = settings.bypassedSoundEvents
        bypassedCompanionEventsBySport = settings.bypassedCompanionEvents
        isWebAPIBroadcastControlEnabled = settings.broadcastControlEnabled
        webAPIBroadcastEnabledDisplayCount = settings.broadcastDisplayCount
        webAPIBroadcastDisplayModesByID = settings.broadcastModes
        customDisplayModeTitlesByMode = settings.customDisplayTitles
        isRemoteDisplayIndividualControlEnabled = settings.remoteIndividualControlEnabled
        remoteDisplayNetworkMode = settings.remoteNetworkMode
        isApplyingSessionUpdate = false
        refreshWebAPIState()
        refreshRemoteDisplayState()
    }

    private func scheduleOwnerSettingsSync() {
        guard isFollowingSessionHost, !isApplyingSessionUpdate, !pendingOwnerSettingsSync else { return }
        pendingOwnerSettingsSync = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.pendingOwnerSettingsSync = false
            guard self.isFollowingSessionHost, self.sessionIsConnected,
                  let descriptor = self.sessionDescriptor else { return }
            let settings = self.currentSessionIntegrationSettings()
            guard let data = try? JSONEncoder().encode(settings), data != self.lastOwnerSettingsData else { return }
            if self.sendSession(.init(kind: .settings, descriptor: descriptor, integrationSettings: settings)) {
                self.lastOwnerSettingsData = data
            }
        }
    }

    private func currentSessionVisualSnapshot() -> ScoreboardGameSnapshot {
        let current = currentGameSnapshot()
        var visual = ScoreboardGameSnapshot.empty
        visual.externalDisplayBackgroundMode = current.externalDisplayBackgroundMode
        visual.externalDisplayBackgroundImage = current.externalDisplayBackgroundImage
        visual.externalDisplayAnimatedLogoStyle = current.externalDisplayAnimatedLogoStyle
        visual.externalDisplayAnimatedLogoBackgroundColor = current.externalDisplayAnimatedLogoBackgroundColor
        visual.externalDisplayAnimatedLogoSpeed = current.externalDisplayAnimatedLogoSpeed
        visual.externalDisplayAnimatedLogoSize = current.externalDisplayAnimatedLogoSize
        visual.externalDisplayAnimatedLogoOpacity = current.externalDisplayAnimatedLogoOpacity
        visual.showsExternalDisplayDateTime = current.showsExternalDisplayDateTime
        visual.externalDisplayDateTimeFormat = current.externalDisplayDateTimeFormat
        visual.showsExternalDisplayDateTimeSeconds = current.showsExternalDisplayDateTimeSeconds
        visual.showsTeamLogos = current.showsTeamLogos
        visual.showsEventLogo = current.showsEventLogo
        visual.homeTeamLogoImage = current.homeTeamLogoImage
        visual.guestTeamLogoImage = current.guestTeamLogoImage
        visual.eventLogoImage = current.eventLogoImage
        return visual
    }

    private func scheduleOwnerVisualSync(field: String? = nil) {
        guard isFollowingSessionHost, !isApplyingRemoteControlState,
              !isApplyingSessionUpdate else { return }
        if let field {
            pendingOwnerVisualFields.insert(field)
            // @Published emits before storage changes. Capture on the next main
            // turn so reconnects cannot replace an offline owner edit.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isFollowingSessionHost else { return }
                self.pendingOwnerVisualSnapshot = self.currentSessionVisualSnapshot()
            }
        }
        guard !pendingOwnerVisualSync else { return }
        pendingOwnerVisualSync = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.pendingOwnerVisualSync = false
            guard self.isFollowingSessionHost, let descriptor = self.sessionDescriptor else { return }
            guard self.sessionIsConnected else {
                self.sessionStatusMessage = "Visual settings will sync when the session host reconnects."
                return
            }
            let visual = self.pendingOwnerVisualSnapshot ?? self.currentSessionVisualSnapshot()
            let fields = self.pendingOwnerVisualFields
            guard !fields.isEmpty else { return }
            if self.sendSession(.init(kind: .settings, descriptor: descriptor,
                                      game: visual, visualFields: fields)) {
                self.pendingOwnerVisualFields.subtract(fields)
                if self.pendingOwnerVisualFields.isEmpty { self.pendingOwnerVisualSnapshot = nil }
                self.lastOwnerVisualData = try? JSONEncoder().encode(visual)
            }
        }
    }

    private func applySessionVisualSnapshot(_ visual: ScoreboardGameSnapshot, fields: Set<String>) {
        guard isSessionAuthority else { return }
        isApplyingSessionUpdate = true
        if fields.contains("backgroundImage") {
            externalDisplayBackgroundImage = visual.externalDisplayBackgroundImage.flatMap(ExternalDisplayBackgroundImage.init(embeddedImage:))
        }
        if fields.contains("backgroundMode") { externalDisplayBackgroundMode = visual.externalDisplayBackgroundMode ?? .blurred }
        if fields.contains("logoStyle") { externalDisplayAnimatedLogoStyle = visual.externalDisplayAnimatedLogoStyle ?? .horizontalMarquee }
        if fields.contains("logoColor") { externalDisplayAnimatedLogoBackgroundColor = visual.externalDisplayAnimatedLogoBackgroundColor ?? .themeBackground }
        if fields.contains("logoSpeed") { setExternalDisplayAnimatedLogoSpeed(visual.externalDisplayAnimatedLogoSpeed ?? Self.defaultAnimatedLogoSpeed) }
        if fields.contains("logoSize") { setExternalDisplayAnimatedLogoSize(visual.externalDisplayAnimatedLogoSize ?? Self.defaultAnimatedLogoSize) }
        if fields.contains("logoOpacity") { setExternalDisplayAnimatedLogoOpacity(visual.externalDisplayAnimatedLogoOpacity ?? Self.defaultAnimatedLogoOpacity) }
        if fields.contains("dateTime") { showsExternalDisplayDateTime = visual.showsExternalDisplayDateTime ?? false }
        if fields.contains("dateTimeFormat") { externalDisplayDateTimeFormat = visual.externalDisplayDateTimeFormat ?? .time24Hour }
        if fields.contains("dateTimeSeconds") { showsExternalDisplayDateTimeSeconds = visual.showsExternalDisplayDateTimeSeconds ?? true }
        if fields.contains("teamLogosVisible") { showsTeamLogos = visual.showsTeamLogos ?? true }
        if fields.contains("eventLogoVisible") { showsEventLogo = visual.showsEventLogo ?? true }
        if fields.contains("homeLogo") { homeTeamLogoImage = visual.homeTeamLogoImage.flatMap(TeamLogoImage.init(embeddedImage:)) }
        if fields.contains("guestLogo") { guestTeamLogoImage = visual.guestTeamLogoImage.flatMap(TeamLogoImage.init(embeddedImage:)) }
        if fields.contains("eventLogo") { eventLogoImage = visual.eventLogoImage.flatMap(EventLogoImage.init(embeddedImage:)) }
        isApplyingSessionUpdate = false
        refreshWebAPIState()
        refreshRemoteDisplayState()
    }

    private func sendOwnerGameName(_ name: String?) {
        guard let descriptor = sessionDescriptor, sessionIsConnected else { return }
        _ = sendSession(.init(kind: .settings, descriptor: descriptor, gameName: name ?? ""))
    }

    private func sendOwnerGameSnapshot(_ snapshot: ScoreboardGameSnapshot) {
        guard let descriptor = sessionDescriptor, sessionIsConnected else {
            sessionStatusMessage = "Connect to the session host before changing game setup."
            return
        }
        if !sendSession(.init(kind: .game, descriptor: descriptor, game: snapshot,
                              gameName: currentGameDisplayName)) {
            sessionStatusMessage = "Game setup was not sent. Reconnect and retry."
        }
    }

    private func sendSessionAdministration(_ admin: ScoreboardSessionAdministration) {
        guard let descriptor = sessionDescriptor, sessionIsConnected else {
            sessionStatusMessage = "Connect to the session host before changing paired devices."
            return
        }
        if !sendSession(.init(kind: .administration, descriptor: descriptor, administration: admin)) {
            sessionStatusMessage = "Device change was not sent. Reconnect and retry."
        }
    }

    private func applySessionAdministration(_ admin: ScoreboardSessionAdministration) {
        switch admin.action {
        case "controlPermission": setRemoteControlAllowed(displayID: admin.displayID, isAllowed: admin.enabled == true)
        case "pair":
            if let source = remoteDisplaySources.first(where: { $0.id == admin.displayID }), let code = admin.text {
                pairRemoteDisplay(source, pairingCode: code, takeoverConfirmed: admin.enabled == true)
            }
        case "connect":
            if let source = remoteDisplaySources.first(where: { $0.id == admin.displayID }) {
                connectTrustedRemoteDisplay(source, takeoverConfirmed: admin.enabled == true)
            }
        case "remove": removeRemoteDisplayPairing(displayID: admin.displayID)
        case "disconnect": disconnectRemoteDisplay(displayID: admin.displayID)
        case "disconnectAll": disconnectRemoteDisplays()
        case "soundTest": sendRemoteDisplaySoundTest(displayID: admin.displayID)
        case "mute": setRemoteDisplayMuted(displayID: admin.displayID, isMuted: admin.enabled == true)
        case "direction":
            if let value = admin.text.flatMap(ScoreboardDisplayDirection.init(rawValue:)) {
                setRemoteDisplayDirection(displayID: admin.displayID, direction: value)
            }
        case "externalDirection":
            if let value = admin.text.flatMap(ScoreboardDisplayDirection.init(rawValue:)) {
                setRemoteDisplayExternalDirection(displayID: admin.displayID, direction: value)
            }
        case "customDisplay":
            if let value = admin.number { setRemoteDisplayCustomDisplayID(displayID: admin.displayID, customDisplayID: value) }
        case "companionTest":
            if let event = admin.soundEvent, let sport = admin.sport { testCompanionCommand(for: event, sport: sport) }
        default: break
        }
    }
}

struct ScoreboardRemoteTimerOperation {
    var primary = false
    var shot = false
    var prep = false
    var pause = false
    var allPenalties = false
    var penaltyID: UUID?
}

@MainActor
extension ScoreboardStore {
    func beginRemoteTimerOperation(_ command: ScoreboardControlCommand, delay: TimeInterval) -> ScoreboardRemoteTimerOperation {
        var scope = ScoreboardRemoteTimerOperation()
        guard delay > 0 else { return scope }
        scope.pause = command.action.hasPrefix("pause.") && command.action != "pause.adjust"
        let startsPause = command.action == "pause.start" || command.action == "pause.official"
        scope.allPenalties = startsPause
        scope.primary = startsPause || command.action.hasPrefix("clock.") || command.action.hasPrefix("chess.") || command.action.hasPrefix("debate.")
        scope.prep = startsPause || command.action.hasPrefix("debate.") || (isDebateMode && command.action.hasPrefix("clock."))
        scope.shot = startsPause || command.action.hasPrefix("shot.") || command.action == "serve.set" || command.action == "possession.set"
        scope.penaltyID = command.action.hasPrefix("penalty.") ? command.timerID : nil
        func rewind(_ seconds: inout Int, fraction: inout TimeInterval, countdown: Bool) {
            let exact = countdown ? Double(seconds) - fraction + delay : Double(seconds) + fraction - delay
            if countdown {
                seconds = max(0, Int(ceil(exact)))
                fraction = max(0, Double(seconds) - exact)
            } else {
                seconds = max(0, Int(floor(exact)))
                fraction = max(0, exact - Double(seconds))
            }
        }
        if scope.pause, var pause = pauseTimer, pause.isRunning, var seconds = pause.remainingSeconds {
            rewind(&seconds, fraction: &accumulatedPauseElapsed, countdown: true)
            pause.remainingSeconds = seconds
            pauseTimer = pause
        }
        if scope.primary && isClockRunning {
            if usesChessClocks {
                if activeChessClockSide == .home { rewind(&homeChessClockSeconds, fraction: &accumulatedGameClockElapsed, countdown: true) }
                else { rewind(&guestChessClockSeconds, fraction: &accumulatedGameClockElapsed, countdown: true) }
            } else { rewind(&gameClockSeconds, fraction: &accumulatedGameClockElapsed, countdown: gameClockMode == .countdown) }
        }
        if scope.shot && isShotClockRunning {
            shotClockMilliseconds += Int(delay * 1000)
        }
        if scope.prep && isDebatePrepClockRunning {
            if debateActiveTimer == .prepHome { rewind(&debatePrepHomeSeconds, fraction: &accumulatedDebatePrepElapsed, countdown: true) }
            else { rewind(&debatePrepGuestSeconds, fraction: &accumulatedDebatePrepElapsed, countdown: true) }
        }
        if scope.allPenalties || scope.penaltyID != nil {
            for side in TeamSide.allCases {
                updatePenaltyTimers(for: side) { timers in
                    for index in timers.indices where timers[index].isRunning && (scope.allPenalties || timers[index].id == scope.penaltyID) {
                        timers[index].remainingSeconds += Int(ceil(delay - accumulatedPenaltyElapsed))
                    }
                }
            }
        }
        return scope
    }

    func finishRemoteTimerOperation(_ scope: ScoreboardRemoteTimerOperation, delay: TimeInterval) {
        guard delay > 0 else { return }
        let savedPause = pauseTimer
        let pauseFraction = accumulatedPauseElapsed
        if !scope.pause { pauseTimer?.isRunning = false }
        let primaryRunning = isClockRunning
        let shotRunning = isShotClockRunning
        let prepRunning = isDebatePrepClockRunning
        let primaryFraction = accumulatedGameClockElapsed
        let shotFraction = accumulatedShotClockElapsed
        let prepFraction = accumulatedDebatePrepElapsed
        let penaltyFraction = accumulatedPenaltyElapsed
        let unrelatedPenalties = (homePenaltyTimers + guestPenaltyTimers).filter { !scope.allPenalties && $0.id != scope.penaltyID && $0.isRunning }.map(\.id)
        if !scope.primary { isClockRunning = false }
        if !scope.shot { isShotClockRunning = false }
        if !scope.prep { isDebatePrepClockRunning = false }
        for side in TeamSide.allCases {
            updatePenaltyTimers(for: side) { timers in
                for index in timers.indices where unrelatedPenalties.contains(timers[index].id) { timers[index].isRunning = false }
            }
        }
        tick(elapsed: delay)
        if !scope.pause { pauseTimer = savedPause; accumulatedPauseElapsed = pauseFraction }
        if !scope.primary { isClockRunning = primaryRunning; accumulatedGameClockElapsed = primaryFraction }
        if !scope.shot { isShotClockRunning = shotRunning; accumulatedShotClockElapsed = shotFraction }
        if !scope.prep { isDebatePrepClockRunning = prepRunning; accumulatedDebatePrepElapsed = prepFraction }
        for side in TeamSide.allCases {
            updatePenaltyTimers(for: side) { timers in
                for index in timers.indices where unrelatedPenalties.contains(timers[index].id) { timers[index].isRunning = true }
            }
        }
        accumulatedPenaltyElapsed = penaltyFraction
        updateTimerState()
        if timer != nil { lastTimerFireDate = Date() }
        refreshPrimaryTimerPersistence()
    }
}

@MainActor
extension ScoreboardStore {
    @discardableResult
    func routeRemoteControlCommand(_ action: String, side: TeamSide? = nil, value: Int? = nil,
                                   text: String? = nil, enabled: Bool? = nil,
                                   playerID: UUID? = nil, timerID: UUID? = nil) -> Bool {
        if sessionAuthorityFenced && !routesControlToSessionHost {
            sessionStatusMessage = "Session authority is unavailable. Reconnect to the host before controlling."
            return true
        }
        guard routesControlToSessionHost, !isApplyingRemoteControlState, !isApplyingSessionUpdate else { return false }
        var command = ScoreboardControlCommand(action: action, sport: selectedSport, side: side,
            value: value, text: text, enabled: enabled, playerID: playerID, timerID: timerID)
        // Running-state commands allow quick start/pause taps without interpreting
        // a second tap using a scoreboard snapshot still in transit.
        if action == "clock.toggle" {
            command.action = "clock.running"
            command.enabled = !isClockRunning
            command.expectedRunning = isClockRunning
        } else if action == "shot.toggle" {
            command.action = "shot.running"
            command.enabled = !isShotClockRunning
            command.expectedRunning = isShotClockRunning
        }
        if let remoteCommandSender { remoteCommandSender(command) }
        else { ScoreboardRemoteDisplayReceiver.shared.sendCommand(command) }
        return true
    }

    func setPublicDisplayViewMode(_ mode: ScoreboardDisplayViewMode) {
        if routeRemoteControlCommand("display.mode", text: mode.rawValue) { return }
        publicDisplayViewMode = mode
    }

    func setTheme(_ theme: ScoreboardTheme) {
        if routeRemoteControlCommand("display.theme", text: theme.rawValue) { return }
        self.theme = theme
    }

    func turnDebateClockHere(_ side: TeamSide) {
        if routeRemoteControlCommand("debate.turn", side: side) { return }
        if debateActiveTimer != .segment { returnToDebateSegmentTimer() }
        if activeChessClockSide == side { toggleChessClock() }
        else {
            setActiveChessClockSide(side)
            if !isClockRunning { toggleChessClock() }
        }
    }

    func clearTrackedPlayerState(for side: TeamSide, playerID: UUID) {
        if routeRemoteControlCommand("player.clear", side: side, playerID: playerID) { return }
        if supportsCards { setCardStatus(.none, for: side, playerID: playerID) }
        if supportsFouls { resetFouls(for: side, playerID: playerID) }
    }

    private func assignRemoteValue<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<ScoreboardStore, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    func applyRemoteControlState(_ state: ScoreboardWebAPIState) {
        guard isRemoteControlProxy || isFollowingSessionHost else { return }
        isApplyingRemoteControlState = true
        defer { isApplyingRemoteControlState = false }
        if remoteControlState?.control?.connectedDeviceCount != state.control?.connectedDeviceCount ||
            remoteControlState?.control?.disconnectedDeviceCount != state.control?.disconnectedDeviceCount ||
            remoteControlState?.control?.ownerConnected != state.control?.ownerConnected {
            objectWillChange.send()
        }
        remoteControlState = state
        assignRemoteValue(\.currentGameDisplayName, state.control?.gameName)
        var snapshot = state.game
        snapshot.homeRoster = state.players.homeRoster
        snapshot.guestRoster = state.players.guestRoster
        let pendingCommands = remoteControlReceiver?.pendingCommandsForDisplay ?? []
        // Overlay text in the value snapshot before publishing. Incoming packets
        // must not briefly replace in-flight edits with older roster text.
        for command in pendingCommands where command.action == "player.name" || command.action == "player.number" {
            guard let side = command.side, let id = command.playerID, let text = command.text else { continue }
            var roster = side == .home ? snapshot.homeRoster! : snapshot.guestRoster!
            if let index = roster.players.firstIndex(where: { $0.id == id }) {
                if command.action == "player.name" { roster.players[index].name = text }
                else { roster.players[index].number = text }
            }
            if side == .home { snapshot.homeRoster = roster }
            else { snapshot.guestRoster = roster }
        }
        var configuration = snapshot
        // Timer values change much more often than game/roster configuration.
        configuration.gameClockSeconds = 0
        configuration.shotClockMilliseconds = 0
        configuration.homeChessClockSeconds = nil
        configuration.guestChessClockSeconds = nil
        configuration.debatePrepHomeSeconds = nil
        configuration.debatePrepGuestSeconds = nil
        configuration.isDebatePrepClockRunning = nil
        configuration.pauseTimer = nil
        configuration.homePenaltyTimers = nil
        configuration.guestPenaltyTimers = nil
        configuration.homeRoster = nil
        configuration.guestRoster = nil
        if remoteControlGameConfiguration != configuration {
            applyGameSnapshot(snapshot)
            remoteControlGameConfiguration = configuration
        } else {
            assignRemoteValue(\.gameClockSeconds, snapshot.gameClockSeconds)
            assignRemoteValue(\.shotClockMilliseconds, snapshot.shotClockMilliseconds)
            assignRemoteValue(\.homeChessClockSeconds, snapshot.homeChessClockSeconds ?? snapshot.defaultClockSeconds)
            assignRemoteValue(\.guestChessClockSeconds, snapshot.guestChessClockSeconds ?? snapshot.defaultClockSeconds)
            assignRemoteValue(\.debatePrepHomeSeconds, snapshot.debatePrepHomeSeconds ?? 0)
            assignRemoteValue(\.debatePrepGuestSeconds, snapshot.debatePrepGuestSeconds ?? 0)
            assignRemoteValue(\.homePenaltyTimers, snapshot.homePenaltyTimers ?? [])
            assignRemoteValue(\.guestPenaltyTimers, snapshot.guestPenaltyTimers ?? [])
        }
        assignRemoteValue(\.pauseTimer, snapshot.pauseTimer)
        // The display payload may be assigned to this device's external screen;
        // operator buttons always show the main board's display control mode.
        assignRemoteValue(\.publicDisplayViewMode, state.control?.mainDisplayMode ?? state.display?.viewMode ?? .scoreboard)
        assignRemoteValue(\.theme, state.display?.theme ?? theme)
        assignRemoteValue(\.isSoundEnabled, state.control?.isSoundEnabled ?? true)
        assignRemoteValue(\.isClockRunning, state.runtime.isClockRunning)
        assignRemoteValue(\.isShotClockRunning, state.runtime.isShotClockRunning)
        assignRemoteValue(\.isDebatePrepClockRunning, state.runtime.isDebatePrepClockRunning)
        assignRemoteValue(\.areSidesSwapped, state.runtime.areSidesSwapped)
        assignRemoteValue(\.possessionDirection, state.runtime.possessionDirection)
        assignRemoteValue(\.homeRoster, normalizedRoster(snapshot.homeRoster, fallbackCount: rosterSizePerTeam))
        assignRemoteValue(\.guestRoster, normalizedRoster(snapshot.guestRoster, fallbackCount: rosterSizePerTeam))
        if isRemoteControlProxy {
            assignRemoteValue(\.isCompanionVisible, false)
            assignRemoteValue(\.isCompanionEnabled, false)
        }
        if let display = state.display {
            assignRemoteValue(\.isWebAPIBroadcastControlEnabled, display.broadcastControl?.isEnabled == true)
            assignRemoteValue(\.isRemoteDisplayIndividualControlEnabled, state.control?.customDisplayControlVisible == true && !isWebAPIBroadcastControlEnabled)
            assignRemoteValue(\.webAPIBroadcastEnabledDisplayCount, state.control?.customDisplayEnabledIDs?.last ?? display.broadcastControl?.enabledDisplayIDs.last ?? 0)
            assignRemoteValue(\.webAPIBroadcastDisplayModesByID, state.control?.customDisplayModes ?? Dictionary(uniqueKeysWithValues:
                (display.broadcastControl?.assignments ?? []).filter { $0.displayID > 0 }.map { ($0.displayID, $0.assignedMode) }))
            // The payload direction is resolved with the current side swap.
            assignRemoteValue(\.externalDisplayDirection, (display.remoteExternalDirection ?? display.direction ?? .homeLeft).applyingSideSwap(areSidesSwapped))
            assignRemoteValue(\.showsExternalDisplayDateTime, display.showsDateTime ?? false)
            assignRemoteValue(\.showsExternalDisplayDateTimeSeconds, display.showsDateTimeSeconds ?? true)
        }
        // Pending absolute values are safe to display over older snapshots. They
        // are discarded at acknowledgement/disconnect and never run game logic.
        for command in pendingCommands {
            switch command.action {
            case "clock.running": isClockRunning = command.enabled ?? isClockRunning
            case "shot.running": isShotClockRunning = command.enabled ?? isShotClockRunning
            case "penalty.name", "penalty.number":
                if let side = command.side, let id = command.timerID, let text = command.text {
                    updatePenaltyTimers(for: side) { timers in
                        if let index = timers.firstIndex(where: { $0.id == id }) {
                            if command.action == "penalty.name" { timers[index].playerName = text }
                            else { timers[index].playerNumber = text }
                        }
                    }
                }
            default: break
            }
        }
        applyRemoteControlImages(state)
    }

    private func applyRemoteControlImages(_ state: ScoreboardWebAPIState) {
        guard let receiver = remoteControlReceiver ?? (isFollowingSessionHost ? ScoreboardRemoteDisplayReceiver.shared : nil) else { return }
        if let metadata = state.display?.backgroundImage, let data = receiver.imageData(for: metadata.id) {
            assignRemoteValue(\.externalDisplayBackgroundImage, ExternalDisplayBackgroundImage(id: metadata.id, sourceName: nil,
                mimeType: metadata.mimeType, pixelWidth: metadata.pixelWidth, pixelHeight: metadata.pixelHeight,
                byteCount: metadata.byteCount, updatedAtUnixTime: metadata.updatedAtUnixTime,
                scale: metadata.placement.scale, offsetX: metadata.placement.offsetX, offsetY: metadata.placement.offsetY, data: data))
        } else { assignRemoteValue(\.externalDisplayBackgroundImage, nil) }
        if let metadata = state.teams.home.logo, let data = receiver.imageData(for: metadata.id) {
            assignRemoteValue(\.homeTeamLogoImage, TeamLogoImage(id: metadata.id, sourceName: nil, mimeType: metadata.mimeType,
                pixelWidth: metadata.pixelWidth, pixelHeight: metadata.pixelHeight, byteCount: metadata.byteCount,
                updatedAtUnixTime: metadata.updatedAtUnixTime, data: data))
        } else { assignRemoteValue(\.homeTeamLogoImage, nil) }
        if let metadata = state.teams.guest.logo, let data = receiver.imageData(for: metadata.id) {
            assignRemoteValue(\.guestTeamLogoImage, TeamLogoImage(id: metadata.id, sourceName: nil, mimeType: metadata.mimeType,
                pixelWidth: metadata.pixelWidth, pixelHeight: metadata.pixelHeight, byteCount: metadata.byteCount,
                updatedAtUnixTime: metadata.updatedAtUnixTime, data: data))
        } else { assignRemoteValue(\.guestTeamLogoImage, nil) }
        if let metadata = state.display?.eventLogo, let data = receiver.imageData(for: metadata.id) {
            assignRemoteValue(\.eventLogoImage, EventLogoImage(id: metadata.id, sourceName: nil, mimeType: metadata.mimeType,
                pixelWidth: metadata.pixelWidth, pixelHeight: metadata.pixelHeight, byteCount: metadata.byteCount,
                updatedAtUnixTime: metadata.updatedAtUnixTime, data: data))
        } else { assignRemoteValue(\.eventLogoImage, nil) }
        assignRemoteValue(\.externalDisplayBackgroundMode, state.display?.backgroundMode ?? .blurred)
    }

    private func projectRemoteControlClocks() {
        guard let receiver = remoteControlReceiver ?? (isFollowingSessionHost ? ScoreboardRemoteDisplayReceiver.shared : nil),
              receiver.status.isLive,
              let state = remoteControlState else { return }
        let projection = RemoteScoreboardProjection(state: state, lastReceivedAt: receiver.lastReceivedAt,
            masterClockOffset: receiver.masterClockOffset, now: Date())
        if gameClockSeconds != projection.gameClockSeconds { gameClockSeconds = projection.gameClockSeconds }
        if shotClockMilliseconds != projection.shotClockMilliseconds { shotClockMilliseconds = projection.shotClockMilliseconds }
        if homeChessClockSeconds != projection.homeChessClockSeconds { homeChessClockSeconds = projection.homeChessClockSeconds }
        if guestChessClockSeconds != projection.guestChessClockSeconds { guestChessClockSeconds = projection.guestChessClockSeconds }
        if debatePrepHomeSeconds != projection.projectedDebatePrepSeconds(for: .home) { debatePrepHomeSeconds = projection.projectedDebatePrepSeconds(for: .home) }
        if debatePrepGuestSeconds != projection.projectedDebatePrepSeconds(for: .guest) { debatePrepGuestSeconds = projection.projectedDebatePrepSeconds(for: .guest) }
        if pauseTimer != projection.pauseTimer { pauseTimer = projection.pauseTimer }
        if homePenaltyTimers != projection.homePenaltyTimers { homePenaltyTimers = projection.homePenaltyTimers }
        if guestPenaltyTimers != projection.guestPenaltyTimers { guestPenaltyTimers = projection.guestPenaltyTimers }
        // Projection is visual only. Expiry events and automation remain on the main board.
    }
}

#if SCOREBOARD_TESTING
// Private-state fixtures are compiled only into the hostless unit test bundle.

@MainActor
extension ScoreboardStore {
    func withControlTestFollowingSessionHost(_ action: () -> Void) {
        let previousDescriptor = sessionDescriptor
        let previousRole = sessionRecoveryRole
        let previousConnection = sessionIsConnected
        defer {
            sessionDescriptor = previousDescriptor
            sessionRecoveryRole = previousRole
            sessionIsConnected = previousConnection
        }
        sessionDescriptor = ScoreboardSessionDescriptor(sessionID: UUID(), epoch: 1,
            ownerDeviceID: localSessionDeviceID, ownerHostID: "test-owner", ownerName: "Owner",
            hostDeviceID: "test-delegated-host", hostName: "Host", hostAddresses: [])
        sessionRecoveryRole = .follower
        sessionIsConnected = false
        action()
    }
    // Hold playback as if another sound is active, then inspect the real event
    // queue without playing audio or contacting a Companion server.
    func captureControlTestEventActions(_ action: () -> Void)
        -> [(event: ScoreboardSoundEvent, effect: ScoreboardSoundEffect, location: String?)] {
        clearQueuedEventActions()
        activeEventPlaybackID = UUID()
        action()
        let actions = queuedEventActions.map { ($0.triggerEvent, $0.effect, $0.companionLocation?.rawValue) }
        clearQueuedEventActions()
        return actions
    }
    func advanceControlTestTimers(by elapsed: TimeInterval) {
        tick(elapsed: elapsed)
        lastTimerFireDate = Date()
    }
    func refreshControlTestTrustedDisplay(_ peer: ScoreboardRemoteDisplayTrustedPeer) {
        remoteDisplayHostService.refreshControlTestTrustedDisplay(peer)
    }
}

#endif
