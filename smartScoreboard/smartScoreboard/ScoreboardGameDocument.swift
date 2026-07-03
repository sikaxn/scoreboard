import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let scoreboardGame = UTType(exportedAs: "com.ironmaple.smartscoreboard.game", conformingTo: .json)
}

struct ScoreboardGameEmbeddedImage: Codable, Equatable, Sendable {
    var id: String
    var sourceName: String?
    var mimeType: String
    var pixelWidth: Int
    var pixelHeight: Int
    var byteCount: Int
    var updatedAtUnixTime: TimeInterval
    var scale: Double?
    var offsetX: Double?
    var offsetY: Double?
    var data: Data
}

struct ScoreboardGameSnapshot: Sendable {
    var fileVersion = 12
    var sport: SportType?
    var customSportConfig: CustomSportConfig?
    var customDebatePreset: DebatePreset?
    var homeTeamName: String
    var guestTeamName: String
    var eventName: String = ""
    var homeScore: Int
    var guestScore: Int
    var period: Int
    var volleyballMatchFormat: VolleyballMatchFormat? = nil
    var volleyballSetResults: [VolleyballSetResult]? = nil
    var gameClockSeconds: Int
    var defaultClockSeconds: Int
    var isGameClockEnabled: Bool?
    var pendingInjuryTimeMinutes: Int? = nil
    var activeInjuryTimeMinutes: Int? = nil
    var hasAppliedInjuryTimeThisPeriod: Bool? = nil
    var shotClockMilliseconds: Int
    var defaultShotClockSeconds: Int
    var activeShotClockPresetSeconds: Int?
    var possessionDirection: PossessionDirection
    var areSidesSwapped: Bool
    var isPlayerTrackingEnabled: Bool?
    var isPlayerOverlayPaused: Bool?
    var rosterSizePerTeam: Int?
    var displayLineupSize: Int?
    var playerLineupOverflowMode: PlayerLineupOverflowMode?
    var playerLineupOverflowLogoOverride: PlayerLineupOverflowMode?
    var playerLineupOverflowNoLogoOverride: PlayerLineupOverflowMode?
    var playerLineupFadePageSeconds: Int?
    var playerLineupScrollSpeed: Int?
    var playerLineupScrollDirection: PlayerLineupScrollDirection?
    var playerFoulHighlightColor: PlayerFoulHighlightColor?
    var isGameClockRedEnabled: Bool?
    var gameClockRedThresholdSeconds: Int?
    var isShotClockRedEnabled: Bool?
    var shotClockRedThresholdSeconds: Int?
    var homeSubstitutionsAllowed: Int?
    var guestSubstitutionsAllowed: Int?
    var homeSubstitutionsUsed: Int?
    var guestSubstitutionsUsed: Int?
    var homePausesAllowed: Int?
    var guestPausesAllowed: Int?
    var homePausesUsed: Int?
    var guestPausesUsed: Int?
    var homeTeamFouls: Int?
    var guestTeamFouls: Int?
    var homeChessClockSeconds: Int?
    var guestChessClockSeconds: Int?
    var activeChessClockSide: TeamSide?
    var chessClockPreset: ChessClockPreset?
    var selectedDebatePresetID: String?
    var debateHomeSideLabel: String?
    var debateGuestSideLabel: String?
    var debateCurrentSegmentIndex: Int?
    var debatePrepHomeSeconds: Int?
    var debatePrepGuestSeconds: Int?
    var isDebatePrepTimeEnabled: Bool?
    var debateActiveTimer: DebateActiveTimer?
    var isDebatePrepClockRunning: Bool?
    var isDebateScoreTrackingEnabled: Bool?
    var isDebatePlayerTrackingEnabled: Bool?
    var isDebatePlayerFoulsEnabled: Bool?
    var isDebatePlayerCardsEnabled: Bool?
    var homePenaltyTimers: [HockeyPenaltyTimer]?
    var guestPenaltyTimers: [HockeyPenaltyTimer]?
    var homeRoster: TeamRoster?
    var guestRoster: TeamRoster?
    var externalDisplayBackgroundMode: ExternalDisplayBackgroundMode? = nil
    var externalDisplayBackgroundImage: ScoreboardGameEmbeddedImage? = nil
    var externalDisplayAnimatedLogoStyle: ExternalDisplayAnimatedLogoStyle? = nil
    var externalDisplayAnimatedLogoBackgroundColor: ExternalDisplayAnimatedLogoBackgroundColor? = nil
    var externalDisplayAnimatedLogoSpeed: Int? = nil
    var externalDisplayAnimatedLogoSize: Int? = nil
    var externalDisplayAnimatedLogoOpacity: Double? = nil
    var showsExternalDisplayDateTime: Bool? = nil
    var externalDisplayDateTimeFormat: ExternalDisplayDateTimeFormat? = nil
    var showsExternalDisplayDateTimeSeconds: Bool? = nil
    var showsTeamLogos: Bool? = nil
    var showsEventLogo: Bool? = nil
    var playerViewRosterScope: PlayerViewRosterScope? = nil
    var homeTeamLogoImage: ScoreboardGameEmbeddedImage? = nil
    var guestTeamLogoImage: ScoreboardGameEmbeddedImage? = nil
    var eventLogoImage: ScoreboardGameEmbeddedImage? = nil

    static let empty = ScoreboardGameSnapshot(
        sport: .simple,
        customSportConfig: .default,
        customDebatePreset: .customDefault,
        homeTeamName: "",
        guestTeamName: "",
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
        debateHomeSideLabel: DebatePreset.publicForum.homeSideLabel,
        debateGuestSideLabel: DebatePreset.publicForum.guestSideLabel,
        debateCurrentSegmentIndex: 0,
        debatePrepHomeSeconds: DebatePreset.publicForum.prepSecondsPerSide,
        debatePrepGuestSeconds: DebatePreset.publicForum.prepSecondsPerSide,
        isDebatePrepTimeEnabled: true,
        debateActiveTimer: .segment,
        isDebatePrepClockRunning: false,
        isDebateScoreTrackingEnabled: false,
        isDebatePlayerTrackingEnabled: false,
        isDebatePlayerFoulsEnabled: false,
        isDebatePlayerCardsEnabled: false,
        homePenaltyTimers: [],
        guestPenaltyTimers: [],
        homeRoster: TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: ScoreboardStore.defaultRosterSize)),
        guestRoster: TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: ScoreboardStore.defaultRosterSize)),
        showsExternalDisplayDateTimeSeconds: true
    )

    var excludingEmbeddedImages: ScoreboardGameSnapshot {
        var snapshot = self
        snapshot.externalDisplayBackgroundImage = nil
        snapshot.homeTeamLogoImage = nil
        snapshot.guestTeamLogoImage = nil
        snapshot.eventLogoImage = nil
        return snapshot
    }

    var remoteDisplayPayload: ScoreboardGameSnapshot {
        var snapshot = excludingEmbeddedImages
        snapshot.homeRoster = nil
        snapshot.guestRoster = nil
        return snapshot
    }
}

extension ScoreboardGameSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case fileVersion
        case sport
        case customSportConfig
        case customDebatePreset
        case homeTeamName
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
        case defaultShotClockSeconds
        case activeShotClockPresetSeconds
        case possessionDirection
        case areSidesSwapped
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
        case externalDisplayBackgroundMode
        case externalDisplayBackgroundImage
        case externalDisplayAnimatedLogoStyle
        case externalDisplayAnimatedLogoBackgroundColor
        case externalDisplayAnimatedLogoSpeed
        case externalDisplayAnimatedLogoSize
        case externalDisplayAnimatedLogoOpacity
        case showsExternalDisplayDateTime
        case externalDisplayDateTimeFormat
        case showsExternalDisplayDateTimeSeconds
        case showsTeamLogos
        case showsEventLogo
        case playerViewRosterScope
        case homeTeamLogoImage
        case guestTeamLogoImage
        case eventLogoImage
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileVersion = try container.decodeIfPresent(Int.self, forKey: .fileVersion) ?? 1
        sport = try container.decodeIfPresent(SportType.self, forKey: .sport)
        customSportConfig = try container.decodeIfPresent(CustomSportConfig.self, forKey: .customSportConfig)
        customDebatePreset = try container.decodeIfPresent(DebatePreset.self, forKey: .customDebatePreset)
        homeTeamName = try container.decode(String.self, forKey: .homeTeamName)
        guestTeamName = try container.decode(String.self, forKey: .guestTeamName)
        eventName = try container.decodeIfPresent(String.self, forKey: .eventName) ?? ""
        homeScore = try container.decode(Int.self, forKey: .homeScore)
        guestScore = try container.decode(Int.self, forKey: .guestScore)
        period = try container.decode(Int.self, forKey: .period)
        volleyballMatchFormat = try container.decodeIfPresent(VolleyballMatchFormat.self, forKey: .volleyballMatchFormat)
        volleyballSetResults = try container.decodeIfPresent([VolleyballSetResult].self, forKey: .volleyballSetResults)
        gameClockSeconds = try container.decode(Int.self, forKey: .gameClockSeconds)
        defaultClockSeconds = try container.decode(Int.self, forKey: .defaultClockSeconds)
        isGameClockEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGameClockEnabled)
        pendingInjuryTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .pendingInjuryTimeMinutes)
        activeInjuryTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .activeInjuryTimeMinutes)
        hasAppliedInjuryTimeThisPeriod = try container.decodeIfPresent(Bool.self, forKey: .hasAppliedInjuryTimeThisPeriod)
        shotClockMilliseconds = try container.decode(Int.self, forKey: .shotClockMilliseconds)
        defaultShotClockSeconds = try container.decode(Int.self, forKey: .defaultShotClockSeconds)
        activeShotClockPresetSeconds = try container.decodeIfPresent(Int.self, forKey: .activeShotClockPresetSeconds)
        possessionDirection = try container.decodeIfPresent(PossessionDirection.self, forKey: .possessionDirection) ?? .none
        areSidesSwapped = try container.decodeIfPresent(Bool.self, forKey: .areSidesSwapped) ?? false
        isPlayerTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPlayerTrackingEnabled)
        isPlayerOverlayPaused = try container.decodeIfPresent(Bool.self, forKey: .isPlayerOverlayPaused)
        rosterSizePerTeam = try container.decodeIfPresent(Int.self, forKey: .rosterSizePerTeam)
        displayLineupSize = try container.decodeIfPresent(Int.self, forKey: .displayLineupSize)
        playerLineupOverflowMode = try container.decodeIfPresent(PlayerLineupOverflowMode.self, forKey: .playerLineupOverflowMode)
        playerLineupOverflowLogoOverride = try container.decodeIfPresent(PlayerLineupOverflowMode.self, forKey: .playerLineupOverflowLogoOverride)
        playerLineupOverflowNoLogoOverride = try container.decodeIfPresent(PlayerLineupOverflowMode.self, forKey: .playerLineupOverflowNoLogoOverride)
        playerLineupFadePageSeconds = try container.decodeIfPresent(Int.self, forKey: .playerLineupFadePageSeconds)
        playerLineupScrollSpeed = try container.decodeIfPresent(Int.self, forKey: .playerLineupScrollSpeed)
        playerLineupScrollDirection = try container.decodeIfPresent(PlayerLineupScrollDirection.self, forKey: .playerLineupScrollDirection)
        playerFoulHighlightColor = try container.decodeIfPresent(PlayerFoulHighlightColor.self, forKey: .playerFoulHighlightColor)
        isGameClockRedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGameClockRedEnabled)
        gameClockRedThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .gameClockRedThresholdSeconds)
        isShotClockRedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isShotClockRedEnabled)
        shotClockRedThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .shotClockRedThresholdSeconds)
        homeSubstitutionsAllowed = try container.decodeIfPresent(Int.self, forKey: .homeSubstitutionsAllowed)
        guestSubstitutionsAllowed = try container.decodeIfPresent(Int.self, forKey: .guestSubstitutionsAllowed)
        homeSubstitutionsUsed = try container.decodeIfPresent(Int.self, forKey: .homeSubstitutionsUsed)
        guestSubstitutionsUsed = try container.decodeIfPresent(Int.self, forKey: .guestSubstitutionsUsed)
        homePausesAllowed = try container.decodeIfPresent(Int.self, forKey: .homePausesAllowed)
        guestPausesAllowed = try container.decodeIfPresent(Int.self, forKey: .guestPausesAllowed)
        homePausesUsed = try container.decodeIfPresent(Int.self, forKey: .homePausesUsed)
        guestPausesUsed = try container.decodeIfPresent(Int.self, forKey: .guestPausesUsed)
        homeTeamFouls = try container.decodeIfPresent(Int.self, forKey: .homeTeamFouls)
        guestTeamFouls = try container.decodeIfPresent(Int.self, forKey: .guestTeamFouls)
        homeChessClockSeconds = try container.decodeIfPresent(Int.self, forKey: .homeChessClockSeconds)
        guestChessClockSeconds = try container.decodeIfPresent(Int.self, forKey: .guestChessClockSeconds)
        activeChessClockSide = try container.decodeIfPresent(TeamSide.self, forKey: .activeChessClockSide)
        chessClockPreset = try container.decodeIfPresent(ChessClockPreset.self, forKey: .chessClockPreset)
        selectedDebatePresetID = try container.decodeIfPresent(String.self, forKey: .selectedDebatePresetID)
        debateHomeSideLabel = try container.decodeIfPresent(String.self, forKey: .debateHomeSideLabel)
        debateGuestSideLabel = try container.decodeIfPresent(String.self, forKey: .debateGuestSideLabel)
        debateCurrentSegmentIndex = try container.decodeIfPresent(Int.self, forKey: .debateCurrentSegmentIndex)
        debatePrepHomeSeconds = try container.decodeIfPresent(Int.self, forKey: .debatePrepHomeSeconds)
        debatePrepGuestSeconds = try container.decodeIfPresent(Int.self, forKey: .debatePrepGuestSeconds)
        isDebatePrepTimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebatePrepTimeEnabled)
        debateActiveTimer = try container.decodeIfPresent(DebateActiveTimer.self, forKey: .debateActiveTimer)
        isDebatePrepClockRunning = try container.decodeIfPresent(Bool.self, forKey: .isDebatePrepClockRunning)
        isDebateScoreTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebateScoreTrackingEnabled)
        isDebatePlayerTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebatePlayerTrackingEnabled)
        isDebatePlayerFoulsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebatePlayerFoulsEnabled)
        isDebatePlayerCardsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDebatePlayerCardsEnabled)
        homePenaltyTimers = try container.decodeIfPresent([HockeyPenaltyTimer].self, forKey: .homePenaltyTimers)
        guestPenaltyTimers = try container.decodeIfPresent([HockeyPenaltyTimer].self, forKey: .guestPenaltyTimers)
        homeRoster = try container.decodeIfPresent(TeamRoster.self, forKey: .homeRoster)
        guestRoster = try container.decodeIfPresent(TeamRoster.self, forKey: .guestRoster)
        externalDisplayBackgroundMode = try container.decodeIfPresent(ExternalDisplayBackgroundMode.self, forKey: .externalDisplayBackgroundMode)
        externalDisplayBackgroundImage = try container.decodeIfPresent(ScoreboardGameEmbeddedImage.self, forKey: .externalDisplayBackgroundImage)
        externalDisplayAnimatedLogoStyle = try container.decodeIfPresent(ExternalDisplayAnimatedLogoStyle.self, forKey: .externalDisplayAnimatedLogoStyle)
        externalDisplayAnimatedLogoBackgroundColor = try container.decodeIfPresent(ExternalDisplayAnimatedLogoBackgroundColor.self, forKey: .externalDisplayAnimatedLogoBackgroundColor)
        externalDisplayAnimatedLogoSpeed = try container.decodeIfPresent(Int.self, forKey: .externalDisplayAnimatedLogoSpeed)
        externalDisplayAnimatedLogoSize = try container.decodeIfPresent(Int.self, forKey: .externalDisplayAnimatedLogoSize)
        externalDisplayAnimatedLogoOpacity = try container.decodeIfPresent(Double.self, forKey: .externalDisplayAnimatedLogoOpacity)
        showsExternalDisplayDateTime = try container.decodeIfPresent(Bool.self, forKey: .showsExternalDisplayDateTime)
        externalDisplayDateTimeFormat = try container.decodeIfPresent(ExternalDisplayDateTimeFormat.self, forKey: .externalDisplayDateTimeFormat)
        showsExternalDisplayDateTimeSeconds = try container.decodeIfPresent(Bool.self, forKey: .showsExternalDisplayDateTimeSeconds)
        showsTeamLogos = try container.decodeIfPresent(Bool.self, forKey: .showsTeamLogos)
        showsEventLogo = try container.decodeIfPresent(Bool.self, forKey: .showsEventLogo)
        playerViewRosterScope = try container.decodeIfPresent(PlayerViewRosterScope.self, forKey: .playerViewRosterScope)
        homeTeamLogoImage = try container.decodeIfPresent(ScoreboardGameEmbeddedImage.self, forKey: .homeTeamLogoImage)
        guestTeamLogoImage = try container.decodeIfPresent(ScoreboardGameEmbeddedImage.self, forKey: .guestTeamLogoImage)
        eventLogoImage = try container.decodeIfPresent(ScoreboardGameEmbeddedImage.self, forKey: .eventLogoImage)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileVersion, forKey: .fileVersion)
        try container.encodeIfPresent(sport, forKey: .sport)
        try container.encodeIfPresent(customSportConfig, forKey: .customSportConfig)
        try container.encodeIfPresent(customDebatePreset, forKey: .customDebatePreset)
        try container.encode(homeTeamName, forKey: .homeTeamName)
        try container.encode(guestTeamName, forKey: .guestTeamName)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(homeScore, forKey: .homeScore)
        try container.encode(guestScore, forKey: .guestScore)
        try container.encode(period, forKey: .period)
        try container.encodeIfPresent(volleyballMatchFormat, forKey: .volleyballMatchFormat)
        try container.encodeIfPresent(volleyballSetResults, forKey: .volleyballSetResults)
        try container.encode(gameClockSeconds, forKey: .gameClockSeconds)
        try container.encode(defaultClockSeconds, forKey: .defaultClockSeconds)
        try container.encodeIfPresent(isGameClockEnabled, forKey: .isGameClockEnabled)
        try container.encodeIfPresent(pendingInjuryTimeMinutes, forKey: .pendingInjuryTimeMinutes)
        try container.encodeIfPresent(activeInjuryTimeMinutes, forKey: .activeInjuryTimeMinutes)
        try container.encodeIfPresent(hasAppliedInjuryTimeThisPeriod, forKey: .hasAppliedInjuryTimeThisPeriod)
        try container.encode(shotClockMilliseconds, forKey: .shotClockMilliseconds)
        try container.encode(defaultShotClockSeconds, forKey: .defaultShotClockSeconds)
        try container.encode(activeShotClockPresetSeconds, forKey: .activeShotClockPresetSeconds)
        try container.encode(possessionDirection, forKey: .possessionDirection)
        try container.encode(areSidesSwapped, forKey: .areSidesSwapped)
        try container.encodeIfPresent(isPlayerTrackingEnabled, forKey: .isPlayerTrackingEnabled)
        try container.encodeIfPresent(isPlayerOverlayPaused, forKey: .isPlayerOverlayPaused)
        try container.encodeIfPresent(rosterSizePerTeam, forKey: .rosterSizePerTeam)
        try container.encodeIfPresent(displayLineupSize, forKey: .displayLineupSize)
        try container.encodeIfPresent(playerLineupOverflowMode, forKey: .playerLineupOverflowMode)
        try container.encodeIfPresent(playerLineupOverflowLogoOverride, forKey: .playerLineupOverflowLogoOverride)
        try container.encodeIfPresent(playerLineupOverflowNoLogoOverride, forKey: .playerLineupOverflowNoLogoOverride)
        try container.encodeIfPresent(playerLineupFadePageSeconds, forKey: .playerLineupFadePageSeconds)
        try container.encodeIfPresent(playerLineupScrollSpeed, forKey: .playerLineupScrollSpeed)
        try container.encodeIfPresent(playerLineupScrollDirection, forKey: .playerLineupScrollDirection)
        try container.encodeIfPresent(playerFoulHighlightColor, forKey: .playerFoulHighlightColor)
        try container.encodeIfPresent(isGameClockRedEnabled, forKey: .isGameClockRedEnabled)
        try container.encodeIfPresent(gameClockRedThresholdSeconds, forKey: .gameClockRedThresholdSeconds)
        try container.encodeIfPresent(isShotClockRedEnabled, forKey: .isShotClockRedEnabled)
        try container.encodeIfPresent(shotClockRedThresholdSeconds, forKey: .shotClockRedThresholdSeconds)
        try container.encodeIfPresent(homeSubstitutionsAllowed, forKey: .homeSubstitutionsAllowed)
        try container.encodeIfPresent(guestSubstitutionsAllowed, forKey: .guestSubstitutionsAllowed)
        try container.encodeIfPresent(homeSubstitutionsUsed, forKey: .homeSubstitutionsUsed)
        try container.encodeIfPresent(guestSubstitutionsUsed, forKey: .guestSubstitutionsUsed)
        try container.encodeIfPresent(homePausesAllowed, forKey: .homePausesAllowed)
        try container.encodeIfPresent(guestPausesAllowed, forKey: .guestPausesAllowed)
        try container.encodeIfPresent(homePausesUsed, forKey: .homePausesUsed)
        try container.encodeIfPresent(guestPausesUsed, forKey: .guestPausesUsed)
        try container.encodeIfPresent(homeTeamFouls, forKey: .homeTeamFouls)
        try container.encodeIfPresent(guestTeamFouls, forKey: .guestTeamFouls)
        try container.encodeIfPresent(homeChessClockSeconds, forKey: .homeChessClockSeconds)
        try container.encodeIfPresent(guestChessClockSeconds, forKey: .guestChessClockSeconds)
        try container.encodeIfPresent(activeChessClockSide, forKey: .activeChessClockSide)
        try container.encodeIfPresent(chessClockPreset, forKey: .chessClockPreset)
        try container.encodeIfPresent(selectedDebatePresetID, forKey: .selectedDebatePresetID)
        try container.encodeIfPresent(debateHomeSideLabel, forKey: .debateHomeSideLabel)
        try container.encodeIfPresent(debateGuestSideLabel, forKey: .debateGuestSideLabel)
        try container.encodeIfPresent(debateCurrentSegmentIndex, forKey: .debateCurrentSegmentIndex)
        try container.encodeIfPresent(debatePrepHomeSeconds, forKey: .debatePrepHomeSeconds)
        try container.encodeIfPresent(debatePrepGuestSeconds, forKey: .debatePrepGuestSeconds)
        try container.encodeIfPresent(isDebatePrepTimeEnabled, forKey: .isDebatePrepTimeEnabled)
        try container.encodeIfPresent(debateActiveTimer, forKey: .debateActiveTimer)
        try container.encodeIfPresent(isDebatePrepClockRunning, forKey: .isDebatePrepClockRunning)
        try container.encodeIfPresent(isDebateScoreTrackingEnabled, forKey: .isDebateScoreTrackingEnabled)
        try container.encodeIfPresent(isDebatePlayerTrackingEnabled, forKey: .isDebatePlayerTrackingEnabled)
        try container.encodeIfPresent(isDebatePlayerFoulsEnabled, forKey: .isDebatePlayerFoulsEnabled)
        try container.encodeIfPresent(isDebatePlayerCardsEnabled, forKey: .isDebatePlayerCardsEnabled)
        try container.encodeIfPresent(homePenaltyTimers, forKey: .homePenaltyTimers)
        try container.encodeIfPresent(guestPenaltyTimers, forKey: .guestPenaltyTimers)
        try container.encodeIfPresent(homeRoster, forKey: .homeRoster)
        try container.encodeIfPresent(guestRoster, forKey: .guestRoster)
        try container.encodeIfPresent(externalDisplayBackgroundMode, forKey: .externalDisplayBackgroundMode)
        try container.encodeIfPresent(externalDisplayBackgroundImage, forKey: .externalDisplayBackgroundImage)
        try container.encodeIfPresent(externalDisplayAnimatedLogoStyle, forKey: .externalDisplayAnimatedLogoStyle)
        try container.encodeIfPresent(externalDisplayAnimatedLogoBackgroundColor, forKey: .externalDisplayAnimatedLogoBackgroundColor)
        try container.encodeIfPresent(externalDisplayAnimatedLogoSpeed, forKey: .externalDisplayAnimatedLogoSpeed)
        try container.encodeIfPresent(externalDisplayAnimatedLogoSize, forKey: .externalDisplayAnimatedLogoSize)
        try container.encodeIfPresent(externalDisplayAnimatedLogoOpacity, forKey: .externalDisplayAnimatedLogoOpacity)
        try container.encodeIfPresent(showsExternalDisplayDateTime, forKey: .showsExternalDisplayDateTime)
        try container.encodeIfPresent(externalDisplayDateTimeFormat, forKey: .externalDisplayDateTimeFormat)
        try container.encodeIfPresent(showsExternalDisplayDateTimeSeconds, forKey: .showsExternalDisplayDateTimeSeconds)
        try container.encodeIfPresent(showsTeamLogos, forKey: .showsTeamLogos)
        try container.encodeIfPresent(showsEventLogo, forKey: .showsEventLogo)
        try container.encodeIfPresent(playerViewRosterScope, forKey: .playerViewRosterScope)
        try container.encodeIfPresent(homeTeamLogoImage, forKey: .homeTeamLogoImage)
        try container.encodeIfPresent(guestTeamLogoImage, forKey: .guestTeamLogoImage)
        try container.encodeIfPresent(eventLogoImage, forKey: .eventLogoImage)
    }
}

extension ScoreboardGameEmbeddedImage {
    init(backgroundImage: ExternalDisplayBackgroundImage) {
        id = backgroundImage.id
        sourceName = backgroundImage.sourceName
        mimeType = backgroundImage.mimeType
        pixelWidth = backgroundImage.pixelWidth
        pixelHeight = backgroundImage.pixelHeight
        byteCount = backgroundImage.byteCount
        updatedAtUnixTime = backgroundImage.updatedAtUnixTime
        scale = backgroundImage.scale
        offsetX = backgroundImage.offsetX
        offsetY = backgroundImage.offsetY
        data = backgroundImage.data
    }

    init(teamLogoImage: TeamLogoImage) {
        id = teamLogoImage.id
        sourceName = teamLogoImage.sourceName
        mimeType = teamLogoImage.mimeType
        pixelWidth = teamLogoImage.pixelWidth
        pixelHeight = teamLogoImage.pixelHeight
        byteCount = teamLogoImage.byteCount
        updatedAtUnixTime = teamLogoImage.updatedAtUnixTime
        scale = nil
        offsetX = nil
        offsetY = nil
        data = teamLogoImage.data
    }

    init(eventLogoImage: EventLogoImage) {
        id = eventLogoImage.id
        sourceName = eventLogoImage.sourceName
        mimeType = eventLogoImage.mimeType
        pixelWidth = eventLogoImage.pixelWidth
        pixelHeight = eventLogoImage.pixelHeight
        byteCount = eventLogoImage.byteCount
        updatedAtUnixTime = eventLogoImage.updatedAtUnixTime
        scale = nil
        offsetX = nil
        offsetY = nil
        data = eventLogoImage.data
    }
}

extension ExternalDisplayBackgroundImage {
    init?(embeddedImage: ScoreboardGameEmbeddedImage) {
        guard !embeddedImage.data.isEmpty else {
            return nil
        }

        self.init(
            id: embeddedImage.id.isEmpty ? UUID().uuidString : embeddedImage.id,
            sourceName: embeddedImage.sourceName,
            mimeType: embeddedImage.mimeType.isEmpty ? "image/jpeg" : embeddedImage.mimeType,
            pixelWidth: max(1, embeddedImage.pixelWidth),
            pixelHeight: max(1, embeddedImage.pixelHeight),
            byteCount: embeddedImage.byteCount > 0 ? embeddedImage.byteCount : embeddedImage.data.count,
            updatedAtUnixTime: embeddedImage.updatedAtUnixTime,
            scale: embeddedImage.scale ?? 1,
            offsetX: embeddedImage.offsetX ?? 0,
            offsetY: embeddedImage.offsetY ?? 0,
            data: embeddedImage.data
        )
    }
}

extension TeamLogoImage {
    init?(embeddedImage: ScoreboardGameEmbeddedImage) {
        guard !embeddedImage.data.isEmpty else {
            return nil
        }

        self.init(
            id: embeddedImage.id.isEmpty ? UUID().uuidString : embeddedImage.id,
            sourceName: embeddedImage.sourceName,
            mimeType: embeddedImage.mimeType.isEmpty ? "image/png" : embeddedImage.mimeType,
            pixelWidth: max(1, embeddedImage.pixelWidth),
            pixelHeight: max(1, embeddedImage.pixelHeight),
            byteCount: embeddedImage.byteCount > 0 ? embeddedImage.byteCount : embeddedImage.data.count,
            updatedAtUnixTime: embeddedImage.updatedAtUnixTime,
            data: embeddedImage.data
        )
    }
}

extension EventLogoImage {
    init?(embeddedImage: ScoreboardGameEmbeddedImage) {
        guard !embeddedImage.data.isEmpty else {
            return nil
        }

        self.init(
            id: embeddedImage.id.isEmpty ? UUID().uuidString : embeddedImage.id,
            sourceName: embeddedImage.sourceName,
            mimeType: embeddedImage.mimeType.isEmpty ? "image/png" : embeddedImage.mimeType,
            pixelWidth: max(1, embeddedImage.pixelWidth),
            pixelHeight: max(1, embeddedImage.pixelHeight),
            byteCount: embeddedImage.byteCount > 0 ? embeddedImage.byteCount : embeddedImage.data.count,
            updatedAtUnixTime: embeddedImage.updatedAtUnixTime,
            data: embeddedImage.data
        )
    }
}

#if !os(tvOS)
struct ScoreboardGameDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.scoreboardGame] }

    var snapshot: ScoreboardGameSnapshot

    init(snapshot: ScoreboardGameSnapshot) {
        self.snapshot = snapshot
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        snapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(snapshot)
        return .init(regularFileWithContents: data)
    }
}
#endif
