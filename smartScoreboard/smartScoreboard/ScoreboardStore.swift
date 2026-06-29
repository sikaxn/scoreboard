import Combine
import Foundation

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
    NSLocalizedString(key, comment: "")
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

enum ScoreboardDisplayDirection: String, Codable, CaseIterable, Identifiable, Sendable {
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
    @Published var soundAssignmentsBySport = ScoreboardStore.defaultSoundAssignmentsBySport
    @Published var playingTestSoundEffect: ScoreboardSoundEffect?
    @Published var isCompanionVisible = false
    @Published var isCompanionEnabled = false
    @Published var companionHost = ""
    @Published var companionMode: ScoreboardCompanionMode = .tcp
    @Published var companionPort = ScoreboardCompanionMode.tcp.defaultPort
    @Published var companionAssignmentsBySport: [SportType: [ScoreboardSoundEvent: String]] = [:]
    @Published private(set) var companionLastError: String?
    @Published private(set) var companionFailureNotice: ScoreboardCompanionFailureNotice?
    @Published var isClockRunning = false
    @Published private(set) var gameClockAutosaveRevision = 0
    @Published var isShotClockRunning = false
    @Published private(set) var shotClockAutosaveRevision = 0
    @Published var didCompleteSetup = false
    @Published var areTipsEnabled = true
    @Published var showGettingStartedOnStartup = true
    @Published var didAutoShowGettingStarted = false
    @Published var setupPresets: [SetupPreset] = []
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
        remoteDisplayHostService.hostID
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
    private var cancellables = Set<AnyCancellable>()
    private var isAuditLoggingSuspended = false
    private var isReconcilingTimersFromWallClock = false
    private let persistenceKey = "smartScoreboard.persistedState"
    private let primaryTimerPersistenceKey = "smartScoreboard.primaryTimerPersistence"
    private var lastPrimaryTimerPersistenceSignature: String?
    private let buzzerPlayer = BuzzerPlayer()
    private let logManager = ScoreboardLogManager.shared
    private let webAPIService = ScoreboardWebAPIService()
    private let remoteDisplayHostService = ScoreboardRemoteDisplayHostService()
    private let companionService = ScoreboardCompanionService()
    private var isWebAPIAppLifecycleActive = true
    private var companionFailureClearTask: Task<Void, Never>?
    private var remoteDisplayConnectedDisplaysByID: [String: ScoreboardRemoteDisplayConnection] = [:]
    private var remoteDisplayDisconnectedDisplaysByID: [String: String] = [:]
    private var dismissedRemoteDisplayWarningDisplayIDs = Set<String>()
    private var intentionallyDisconnectedRemoteDisplayIDs = Set<String>()
    private var isStateSideEffectRefreshScheduled = false

    private init() {
        loadPersistedState()
        remoteDisplayHostService.migrateDisplayDirectionsIfNeeded(areSidesSwapped: areSidesSwapped)
        configurePersistence()
        configureWebAPIService()
        configureRemoteDisplayService()
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
            return uniqueSoundEvents([
                .debateSegmentStarted,
                .debateSegmentStopped,
                .debateSegmentExpired,
                .debateUnassignedSegmentStarted,
                .debateUnassignedSegmentStopped,
                .debateUnassignedSegmentExpired,
                .debatePrepStarted,
                .debatePrepStopped,
                .debatePrepExpired
            ] + sideClockSoundEvents + debatePrepClockSoundEvents + [
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
        var events: [ScoreboardSoundEvent] = []

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
        return uniqueSoundEvents(events)
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
        guard isSoundEnabled != isEnabled else {
            if !isEnabled, playingTestSoundEffect != nil {
                stopTestSound()
            }
            return
        }

        isSoundEnabled = isEnabled

        if !isSoundEnabled {
            stopTestSound()
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

        isCompanionVisible = isVisible
        if !isVisible {
            isCompanionEnabled = false
            dismissCompanionFailureNotice()
        }
    }

    func setCompanionEnabled(_ isEnabled: Bool) {
        let resolvedEnabled = isEnabled && isCompanionVisible
        guard isCompanionEnabled != resolvedEnabled else {
            return
        }

        isCompanionEnabled = resolvedEnabled
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

        companionHost = host
    }

    func setCompanionMode(_ mode: ScoreboardCompanionMode) {
        guard companionMode != mode else {
            return
        }

        companionMode = mode
        companionPort = mode.defaultPort
    }

    func setCompanionPort(_ port: Int) {
        let boundedPort = UInt16(max(1, min(65_535, port)))
        guard companionPort != boundedPort else {
            return
        }

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
        guard let location = companionLocation(for: event, sport: sport) else {
            handleCompanionSendResult(.failure(.invalidLocation))
            return
        }

        sendCompanionPress(location)
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
        soundAssignmentsBySport = Self.defaultSoundAssignmentsBySport
    }

    func playTestSound(_ event: ScoreboardSoundEvent) {
        playTestSound(event, sport: selectedSport)
    }

    func playTestSound(_ event: ScoreboardSoundEvent, sport: SportType) {
        toggleTestSound(selectedSoundEffect(for: event, sport: sport))
    }

    func playTestEffect(_ effect: ScoreboardSoundEffect) {
        toggleTestSound(effect)
    }

    func prepareTestSoundEffects() {
        buzzerPlayer.prepare(ScoreboardSoundEffect.allCases)
    }

    func toggleTestSound(_ effect: ScoreboardSoundEffect) {
        guard isSoundEnabled, effect != .none else {
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
        playingTestSoundEffect = nil
        buzzerPlayer.stop()
    }

    func canTestSoundEffect(_ effect: ScoreboardSoundEffect) -> Bool {
        isSoundEnabled && effect != .none
    }

    func isTestingSoundEffect(_ effect: ScoreboardSoundEffect) -> Bool {
        playingTestSoundEffect == effect
    }

    func toggleShotClock() {
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
        pauseClock()
        pauseShotClock()
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
        requestGameClockAutosave()
    }

    func resetScores() {
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
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].number = normalizedPlayerNumber(number)
        }
    }

    func updateTrackedPlayerName(_ name: String, for side: TeamSide, playerID: UUID) {
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].name = normalizedPlayerName(name)
        }
    }

    func adjustFoulCount(for side: TeamSide, playerID: UUID, by delta: Int) {
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
        resetFouls(for: .home)
        resetFouls(for: .guest)
    }

    func setCardStatus(_ status: PlayerCardStatus, for side: TeamSide, playerID: UUID) {
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
        resetCards(for: .home)
        resetCards(for: .guest)
    }

    func adjustTeamFouls(for side: TeamSide, by delta: Int) {
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
        isClockRunning = clockWasRunning && (showsGameClock || usesChessClocks)
        isShotClockRunning = shotClockWasRunning && supportsShotClock
        isDebatePrepClockRunning = debatePrepWasRunning && isDebateMode && isDebatePrepTimeEnabled && debateActiveTimer != .segment
        normalizeInjuryTimeState()
        updateTimerState()
    }

    func setSelectedSport(_ sport: SportType, applyDefaults: Bool = true) {
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
            eventLogoImage: embeddedEventLogoImage()
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
        performWithoutAuditLogging {
            pauseClock()
            pauseShotClock()

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
        let hasRunningPenalty = homePenaltyTimers.contains(where: \.isRunning) || guestPenaltyTimers.contains(where: \.isRunning)
        guard isClockRunning || isShotClockRunning || hasRunningPenalty || isDebatePrepClockRunning else {
            timer?.invalidate()
            timer = nil
            lastTimerFireDate = nil
            accumulatedGameClockElapsed = 0
            accumulatedShotClockElapsed = 0
            accumulatedPenaltyElapsed = 0
            accumulatedDebatePrepElapsed = 0
            return
        }

        guard timer == nil else {
            return
        }

        lastTimerFireDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.reconcileRunningTimersWithWallClock()
            }
        }
    }

    func reconcileRunningTimersWithWallClock() {
        reconcileRunningTimersWithWallClock(now: Date())
    }

    private func reconcileRunningTimersWithWallClock(now: Date) {
        guard !isReconcilingTimersFromWallClock else {
            return
        }

        let hasRunningPenalty = homePenaltyTimers.contains(where: \.isRunning) || guestPenaltyTimers.contains(where: \.isRunning)
        guard isClockRunning || isShotClockRunning || hasRunningPenalty || isDebatePrepClockRunning else {
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

        updateTimerState()

        if let soundEvent = highestPrioritySoundEvent(from: soundEvents) {
            let primaryDispatches = clockEventDispatches
                .filter { $0.fallbackEvent == soundEvent }
            if primaryDispatches.isEmpty {
                handleScoreboardEvent(soundEvent)
            } else {
                handleScoreboardEventDispatches(primaryDispatches)
            }
        }
    }

    deinit {
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
        let resolvedDispatches = uniqueScoreboardEventDispatches(dispatches)
        playSound(for: resolvedDispatches)
        triggerCompanionCommands(for: resolvedDispatches)
    }

    private func playSound(for event: ScoreboardSoundEvent) {
        playSound(for: [event], fallbackEvent: nil)
    }

    private func playSound(for events: [ScoreboardSoundEvent], fallbackEvent: ScoreboardSoundEvent?) {
        let dispatches = uniqueSoundEvents(events).map { eventDispatch($0, fallbackEvent: fallbackEvent) }
        playSound(for: dispatches)
    }

    private func playSound(for dispatches: [ScoreboardEventDispatch]) {
        guard isSoundEnabled else {
            return
        }

        guard let event = preferredSoundEvent(from: dispatches) else {
            return
        }

        if playingTestSoundEffect != nil {
            stopTestSound()
        }
        let effect = resolvedSoundEffect(for: event)
        guard effect != .none else {
            return
        }
        buzzerPlayer.play(effect)
        remoteDisplayHostService.sendSoundEffect(effect)
    }

    private func triggerCompanionCommand(for event: ScoreboardSoundEvent) {
        triggerCompanionCommands(for: [event], fallbackEvent: nil)
    }

    private func triggerCompanionCommands(for events: [ScoreboardSoundEvent], fallbackEvent: ScoreboardSoundEvent?) {
        let dispatches = uniqueSoundEvents(events).map { eventDispatch($0, fallbackEvent: fallbackEvent) }
        triggerCompanionCommands(for: dispatches)
    }

    private func triggerCompanionCommands(for dispatches: [ScoreboardEventDispatch]) {
        guard isCompanionVisible, isCompanionEnabled else {
            return
        }

        var sentLocations = Set<ScoreboardCompanionLocation>()
        for dispatch in dispatches {
            if let location = companionLocation(for: dispatch.event) {
                if sentLocations.insert(location).inserted {
                    sendCompanionPress(location)
                }
                continue
            }

            if let fallbackEvent = dispatch.fallbackEvent, let location = companionLocation(for: fallbackEvent) {
                if sentLocations.insert(location).inserted {
                    sendCompanionPress(location)
                }
            }
        }
    }

    private func companionLocation(for event: ScoreboardSoundEvent) -> ScoreboardCompanionLocation? {
        companionLocation(for: event, sport: selectedSport)
    }

    private func companionLocation(for event: ScoreboardSoundEvent, sport: SportType) -> ScoreboardCompanionLocation? {
        ScoreboardCompanionLocation(rawValue: companionLocationText(for: event, sport: sport))
    }

    private func sendCompanionPress(_ location: ScoreboardCompanionLocation) {
        companionService.sendPress(
            host: companionHost,
            port: companionPort,
            mode: companionMode,
            location: location
        ) { [weak self] result in
            Task { @MainActor in
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

    private func resolvedSoundEffect(for event: ScoreboardSoundEvent) -> ScoreboardSoundEffect {
        selectedSoundEffect(for: event)
    }

    private func preferredSoundEvent(from dispatches: [ScoreboardEventDispatch]) -> ScoreboardSoundEvent? {
        if let assignedDispatch = dispatches.first(where: { selectedSoundEffect(for: $0.event) != .none }) {
            return assignedDispatch.event
        }
        if let fallbackEvent = dispatches
            .compactMap(\.fallbackEvent)
            .first(where: { selectedSoundEffect(for: $0) != .none }) {
            return fallbackEvent
        }
        return dispatches.first?.event ?? dispatches.compactMap(\.fallbackEvent).first
    }

    private func highestPrioritySoundEvent(from events: [ScoreboardSoundEvent]) -> ScoreboardSoundEvent? {
        let priorities: [ScoreboardSoundEvent] = [
            .shotClockExpired,
            .gameClockExpired,
            .chessClockExpired,
            .debateSegmentExpired,
            .hockeyPenaltyExpired,
            .debatePrepExpired,
            .general
        ]

        return priorities.first { events.contains($0) }
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
        guard !isAuditLoggingSuspended else {
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
        isWebAPIEnabled = isEnabled
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
        isRemoteDisplayHostEnabled = isEnabled
        if !isEnabled {
            resetRemoteDisplayWarningState()
        }
    }

    func setRemoteDisplayViewerModeEnabled(_ isEnabled: Bool) {
        #if !os(tvOS)
        if isEnabled {
            stopRemoteDisplayHostService()
        } else {
            ScoreboardRemoteDisplayReceiver.shared.stop()
        }
        #endif

        isRemoteDisplayViewerModeEnabled = isEnabled
        if isEnabled {
            resetRemoteDisplayWarningState()
        }
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
        remoteDisplayHostService.connectTrustedDisplay(
            source,
            takeoverConfirmed: takeoverConfirmed
        )
    }

    func removeRemoteDisplayPairing(displayID: String) {
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
        remoteDisplayHostService.isTrustedDisplay(source)
    }

    func disconnectRemoteDisplays() {
        intentionallyDisconnectedRemoteDisplayIDs.formUnion(remoteDisplayConnectedDisplays.map(\.id))
        remoteDisplayDisconnectedDisplaysByID.removeAll()
        remoteDisplayWarningNotice = nil
        remoteDisplayHostService.disconnectDisplays()
    }

    func disconnectRemoteDisplay(displayID: String) {
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
        remoteDisplayHostService.sendSoundTest(toDisplayID: displayID)
    }

    func setRemoteDisplayMuted(displayID: String, isMuted: Bool) {
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
        remoteDisplayHostService.setDisplayDirection(id: displayID, direction: direction)
        refreshRemoteDisplayState()
    }

    func setRemoteDisplayExternalDirection(displayID: String, direction: ScoreboardDisplayDirection) {
        remoteDisplayHostService.setExternalDisplayDirection(id: displayID, direction: direction)
        refreshRemoteDisplayState()
    }

    func refreshWebAPILocalAddresses() {
        webAPILocalAddresses = ScoreboardWebAPIService.localIPv4Addresses()
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
                if isEnabled {
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
                self?.handleRemoteDisplayConnectedDisplaysChanged(connectedDisplays)
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$trustedDisplays
            .sink { [weak self] trustedDisplays in
                self?.handleRemoteDisplayTrustedDisplaysChanged(trustedDisplays)
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$mutedDisplayIDs
            .sink { [weak self] mutedDisplayIDs in
                self?.remoteDisplayMutedDisplayIDs = mutedDisplayIDs
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$displayDirectionsByID
            .sink { [weak self] displayDirectionsByID in
                self?.remoteDisplayDirectionsByID = displayDirectionsByID
            }
            .store(in: &cancellables)

        remoteDisplayHostService.$customDisplayIDsByID
            .sink { [weak self] customDisplayIDsByID in
                self?.remoteDisplayCustomDisplayIDsByDisplayID = customDisplayIDsByID
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
            if isHostEnabled && !isViewerModeEnabled {
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

        guard isRemoteDisplayHostEnabled, !isRemoteDisplayViewerModeEnabled else {
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
        webAPILocalAddresses = ScoreboardWebAPIService.localIPv4Addresses()
        webAPIStatus = .starting
        let payloads = encodedWebAPIOutputPayloads()
        webAPIService.start(
            initialPayload: payloads.state,
            initialCommentatorPayload: payloads.commentator,
            updateMode: webAPIUpdateMode,
            imageResponses: currentWebAPIImageResponses()
        ) { [weak self] status in
            Task { @MainActor in
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
        remoteDisplayHostService.updateState(encodedRemoteDisplayStates())
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
            $soundAssignmentsBySport.map { _ in () }.eraseToAnyPublisher(),
            $isCompanionVisible.map { _ in () }.eraseToAnyPublisher(),
            $isCompanionEnabled.map { _ in () }.eraseToAnyPublisher(),
            $companionHost.map { _ in () }.eraseToAnyPublisher(),
            $companionMode.map { _ in () }.eraseToAnyPublisher(),
            $companionPort.map { _ in () }.eraseToAnyPublisher(),
            $companionAssignmentsBySport.map { _ in () }.eraseToAnyPublisher(),
            $isClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $isShotClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $didCompleteSetup.map { _ in () }.eraseToAnyPublisher(),
            $areTipsEnabled.map { _ in () }.eraseToAnyPublisher(),
            $showGettingStartedOnStartup.map { _ in () }.eraseToAnyPublisher(),
            $didAutoShowGettingStarted.map { _ in () }.eraseToAnyPublisher(),
            $setupPresets.map { _ in () }.eraseToAnyPublisher(),
            $isWebAPIEnabled.map { _ in () }.eraseToAnyPublisher(),
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
        clearPrimaryTimerPersistence()
        applyPersistedState(.factoryDefault)
        UserDefaults.standard.removeObject(forKey: persistenceKey)
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
            let data = UserDefaults.standard.data(forKey: persistenceKey),
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
            soundAssignmentsBySport = normalizedSoundAssignmentsBySport(persistedState.soundAssignmentsBySport)
            isCompanionVisible = persistedState.isCompanionVisible
            isCompanionEnabled = persistedState.isCompanionVisible && persistedState.isCompanionEnabled
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
        guard let data = try? encodedPersistedStateData() else {
            return
        }

        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func refreshPrimaryTimerPersistence() {
        guard let snapshot = currentPrimaryTimerPersistenceSnapshot(now: Date()) else {
            clearPrimaryTimerPersistence()
            return
        }

        guard snapshot.signature != lastPrimaryTimerPersistenceSignature else {
            return
        }

        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: primaryTimerPersistenceKey)
            lastPrimaryTimerPersistenceSignature = snapshot.signature
        }
    }

    private func clearPrimaryTimerPersistence() {
        UserDefaults.standard.removeObject(forKey: primaryTimerPersistenceKey)
        lastPrimaryTimerPersistenceSignature = nil
    }

    private func restorePrimaryTimerPersistenceIfNeeded() {
        guard
            let data = UserDefaults.standard.data(forKey: primaryTimerPersistenceKey),
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
            soundAssignmentsBySport: soundAssignmentsBySport,
            isCompanionVisible: isCompanionVisible,
            isCompanionEnabled: isCompanionEnabled,
            companionHost: companionHost,
            companionMode: companionMode,
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
            remoteDisplayNetworkMode: remoteDisplayNetworkMode
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
    var soundAssignmentsBySport: [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]]
    var isCompanionVisible: Bool
    var isCompanionEnabled: Bool
    var companionHost: String
    var companionMode: ScoreboardCompanionMode
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
        case soundAssignmentsBySport
        case isCompanionVisible
        case isCompanionEnabled
        case companionHost
        case companionMode
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
        soundAssignmentsBySport: [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]],
        isCompanionVisible: Bool,
        isCompanionEnabled: Bool,
        companionHost: String,
        companionMode: ScoreboardCompanionMode,
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
        remoteDisplayNetworkMode: ScoreboardRemoteDisplayNetworkMode
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
        self.soundAssignmentsBySport = soundAssignmentsBySport
        self.isCompanionVisible = isCompanionVisible
        self.isCompanionEnabled = isCompanionEnabled
        self.companionHost = companionHost
        self.companionMode = companionMode
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
        if let assignmentsBySport = try container.decodeIfPresent([SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]].self, forKey: .soundAssignmentsBySport) {
            soundAssignmentsBySport = assignmentsBySport
        } else if let legacyAssignments = try container.decodeIfPresent([ScoreboardSoundEvent: ScoreboardSoundEffect].self, forKey: .soundAssignments) {
            soundAssignmentsBySport = Dictionary(uniqueKeysWithValues: SportType.allCases.map { sport in
                (sport, legacyAssignments)
            })
        } else {
            soundAssignmentsBySport = ScoreboardStore.defaultSoundAssignmentsBySport
        }
        isCompanionVisible = try container.decodeIfPresent(Bool.self, forKey: .isCompanionVisible) ?? false
        let decodedCompanionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCompanionEnabled) ?? false
        isCompanionEnabled = isCompanionVisible && decodedCompanionEnabled
        companionHost = try container.decodeIfPresent(String.self, forKey: .companionHost) ?? ""
        companionMode = try container.decodeIfPresent(ScoreboardCompanionMode.self, forKey: .companionMode) ?? .tcp
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
        try container.encode(soundAssignmentsBySport, forKey: .soundAssignmentsBySport)
        try container.encode(isCompanionVisible, forKey: .isCompanionVisible)
        try container.encode(isCompanionEnabled, forKey: .isCompanionEnabled)
        try container.encode(companionHost, forKey: .companionHost)
        try container.encode(companionMode, forKey: .companionMode)
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
            soundAssignmentsBySport: ScoreboardStore.defaultSoundAssignmentsBySport,
            isCompanionVisible: false,
            isCompanionEnabled: false,
            companionHost: "",
            companionMode: .tcp,
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
