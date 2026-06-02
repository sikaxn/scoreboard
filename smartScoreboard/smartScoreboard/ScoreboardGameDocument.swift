import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let scoreboardGame = UTType(exportedAs: "com.ironmaple.smartscoreboard.game", conformingTo: .json)
}

struct ScoreboardGameSnapshot: Sendable {
    var fileVersion = 7
    var sport: SportType?
    var customSportConfig: CustomSportConfig?
    var customDebatePreset: DebatePreset?
    var homeTeamName: String
    var guestTeamName: String
    var homeScore: Int
    var guestScore: Int
    var period: Int
    var gameClockSeconds: Int
    var defaultClockSeconds: Int
    var isGameClockEnabled: Bool?
    var shotClockMilliseconds: Int
    var defaultShotClockSeconds: Int
    var activeShotClockPresetSeconds: Int?
    var possessionDirection: PossessionDirection
    var areSidesSwapped: Bool
    var isPlayerTrackingEnabled: Bool?
    var isPlayerOverlayPaused: Bool?
    var rosterSizePerTeam: Int?
    var displayLineupSize: Int?
    var playerFoulHighlightColor: PlayerFoulHighlightColor?
    var isGameClockRedEnabled: Bool?
    var gameClockRedThresholdSeconds: Int?
    var isShotClockRedEnabled: Bool?
    var shotClockRedThresholdSeconds: Int?
    var homeSubstitutionsAllowed: Int?
    var guestSubstitutionsAllowed: Int?
    var homeSubstitutionsUsed: Int?
    var guestSubstitutionsUsed: Int?
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
    var homePenaltyTimers: [HockeyPenaltyTimer]?
    var guestPenaltyTimers: [HockeyPenaltyTimer]?
    var homeRoster: TeamRoster?
    var guestRoster: TeamRoster?

    static let empty = ScoreboardGameSnapshot(
        sport: .basketball,
        customSportConfig: .default,
        customDebatePreset: .customDefault,
        homeTeamName: "",
        guestTeamName: "",
        homeScore: 0,
        guestScore: 0,
        period: 1,
        gameClockSeconds: 12 * 60,
        defaultClockSeconds: 12 * 60,
        isGameClockEnabled: true,
        shotClockMilliseconds: 24_000,
        defaultShotClockSeconds: 24,
        activeShotClockPresetSeconds: 24,
        possessionDirection: .none,
        areSidesSwapped: false,
        isPlayerTrackingEnabled: false,
        isPlayerOverlayPaused: false,
        rosterSizePerTeam: ScoreboardStore.defaultRosterSize,
        displayLineupSize: ScoreboardStore.defaultDisplayLineupSize,
        playerFoulHighlightColor: .yellow,
        isGameClockRedEnabled: false,
        gameClockRedThresholdSeconds: 60,
        isShotClockRedEnabled: false,
        shotClockRedThresholdSeconds: 5,
        homeSubstitutionsAllowed: 0,
        guestSubstitutionsAllowed: 0,
        homeSubstitutionsUsed: 0,
        guestSubstitutionsUsed: 0,
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
        homePenaltyTimers: [],
        guestPenaltyTimers: [],
        homeRoster: TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: ScoreboardStore.defaultRosterSize)),
        guestRoster: TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: ScoreboardStore.defaultRosterSize))
    )
}

extension ScoreboardGameSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case fileVersion
        case sport
        case customSportConfig
        case customDebatePreset
        case homeTeamName
        case guestTeamName
        case homeScore
        case guestScore
        case period
        case gameClockSeconds
        case defaultClockSeconds
        case isGameClockEnabled
        case shotClockMilliseconds
        case defaultShotClockSeconds
        case activeShotClockPresetSeconds
        case possessionDirection
        case areSidesSwapped
        case isPlayerTrackingEnabled
        case isPlayerOverlayPaused
        case rosterSizePerTeam
        case displayLineupSize
        case playerFoulHighlightColor
        case isGameClockRedEnabled
        case gameClockRedThresholdSeconds
        case isShotClockRedEnabled
        case shotClockRedThresholdSeconds
        case homeSubstitutionsAllowed
        case guestSubstitutionsAllowed
        case homeSubstitutionsUsed
        case guestSubstitutionsUsed
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
        case homePenaltyTimers
        case guestPenaltyTimers
        case homeRoster
        case guestRoster
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileVersion = try container.decodeIfPresent(Int.self, forKey: .fileVersion) ?? 1
        sport = try container.decodeIfPresent(SportType.self, forKey: .sport)
        customSportConfig = try container.decodeIfPresent(CustomSportConfig.self, forKey: .customSportConfig)
        customDebatePreset = try container.decodeIfPresent(DebatePreset.self, forKey: .customDebatePreset)
        homeTeamName = try container.decode(String.self, forKey: .homeTeamName)
        guestTeamName = try container.decode(String.self, forKey: .guestTeamName)
        homeScore = try container.decode(Int.self, forKey: .homeScore)
        guestScore = try container.decode(Int.self, forKey: .guestScore)
        period = try container.decode(Int.self, forKey: .period)
        gameClockSeconds = try container.decode(Int.self, forKey: .gameClockSeconds)
        defaultClockSeconds = try container.decode(Int.self, forKey: .defaultClockSeconds)
        isGameClockEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGameClockEnabled)
        shotClockMilliseconds = try container.decode(Int.self, forKey: .shotClockMilliseconds)
        defaultShotClockSeconds = try container.decode(Int.self, forKey: .defaultShotClockSeconds)
        activeShotClockPresetSeconds = try container.decodeIfPresent(Int.self, forKey: .activeShotClockPresetSeconds)
        possessionDirection = try container.decodeIfPresent(PossessionDirection.self, forKey: .possessionDirection) ?? .none
        areSidesSwapped = try container.decodeIfPresent(Bool.self, forKey: .areSidesSwapped) ?? false
        isPlayerTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPlayerTrackingEnabled)
        isPlayerOverlayPaused = try container.decodeIfPresent(Bool.self, forKey: .isPlayerOverlayPaused)
        rosterSizePerTeam = try container.decodeIfPresent(Int.self, forKey: .rosterSizePerTeam)
        displayLineupSize = try container.decodeIfPresent(Int.self, forKey: .displayLineupSize)
        playerFoulHighlightColor = try container.decodeIfPresent(PlayerFoulHighlightColor.self, forKey: .playerFoulHighlightColor)
        isGameClockRedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGameClockRedEnabled)
        gameClockRedThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .gameClockRedThresholdSeconds)
        isShotClockRedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isShotClockRedEnabled)
        shotClockRedThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .shotClockRedThresholdSeconds)
        homeSubstitutionsAllowed = try container.decodeIfPresent(Int.self, forKey: .homeSubstitutionsAllowed)
        guestSubstitutionsAllowed = try container.decodeIfPresent(Int.self, forKey: .guestSubstitutionsAllowed)
        homeSubstitutionsUsed = try container.decodeIfPresent(Int.self, forKey: .homeSubstitutionsUsed)
        guestSubstitutionsUsed = try container.decodeIfPresent(Int.self, forKey: .guestSubstitutionsUsed)
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
        homePenaltyTimers = try container.decodeIfPresent([HockeyPenaltyTimer].self, forKey: .homePenaltyTimers)
        guestPenaltyTimers = try container.decodeIfPresent([HockeyPenaltyTimer].self, forKey: .guestPenaltyTimers)
        homeRoster = try container.decodeIfPresent(TeamRoster.self, forKey: .homeRoster)
        guestRoster = try container.decodeIfPresent(TeamRoster.self, forKey: .guestRoster)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileVersion, forKey: .fileVersion)
        try container.encodeIfPresent(sport, forKey: .sport)
        try container.encodeIfPresent(customSportConfig, forKey: .customSportConfig)
        try container.encodeIfPresent(customDebatePreset, forKey: .customDebatePreset)
        try container.encode(homeTeamName, forKey: .homeTeamName)
        try container.encode(guestTeamName, forKey: .guestTeamName)
        try container.encode(homeScore, forKey: .homeScore)
        try container.encode(guestScore, forKey: .guestScore)
        try container.encode(period, forKey: .period)
        try container.encode(gameClockSeconds, forKey: .gameClockSeconds)
        try container.encode(defaultClockSeconds, forKey: .defaultClockSeconds)
        try container.encodeIfPresent(isGameClockEnabled, forKey: .isGameClockEnabled)
        try container.encode(shotClockMilliseconds, forKey: .shotClockMilliseconds)
        try container.encode(defaultShotClockSeconds, forKey: .defaultShotClockSeconds)
        try container.encode(activeShotClockPresetSeconds, forKey: .activeShotClockPresetSeconds)
        try container.encode(possessionDirection, forKey: .possessionDirection)
        try container.encode(areSidesSwapped, forKey: .areSidesSwapped)
        try container.encodeIfPresent(isPlayerTrackingEnabled, forKey: .isPlayerTrackingEnabled)
        try container.encodeIfPresent(isPlayerOverlayPaused, forKey: .isPlayerOverlayPaused)
        try container.encodeIfPresent(rosterSizePerTeam, forKey: .rosterSizePerTeam)
        try container.encodeIfPresent(displayLineupSize, forKey: .displayLineupSize)
        try container.encodeIfPresent(playerFoulHighlightColor, forKey: .playerFoulHighlightColor)
        try container.encodeIfPresent(isGameClockRedEnabled, forKey: .isGameClockRedEnabled)
        try container.encodeIfPresent(gameClockRedThresholdSeconds, forKey: .gameClockRedThresholdSeconds)
        try container.encodeIfPresent(isShotClockRedEnabled, forKey: .isShotClockRedEnabled)
        try container.encodeIfPresent(shotClockRedThresholdSeconds, forKey: .shotClockRedThresholdSeconds)
        try container.encodeIfPresent(homeSubstitutionsAllowed, forKey: .homeSubstitutionsAllowed)
        try container.encodeIfPresent(guestSubstitutionsAllowed, forKey: .guestSubstitutionsAllowed)
        try container.encodeIfPresent(homeSubstitutionsUsed, forKey: .homeSubstitutionsUsed)
        try container.encodeIfPresent(guestSubstitutionsUsed, forKey: .guestSubstitutionsUsed)
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
        try container.encodeIfPresent(homePenaltyTimers, forKey: .homePenaltyTimers)
        try container.encodeIfPresent(guestPenaltyTimers, forKey: .guestPenaltyTimers)
        try container.encodeIfPresent(homeRoster, forKey: .homeRoster)
        try container.encodeIfPresent(guestRoster, forKey: .guestRoster)
    }
}

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
