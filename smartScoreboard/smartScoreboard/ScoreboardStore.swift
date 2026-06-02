import Combine
import Foundation

enum PossessionDirection: String, Codable, CaseIterable {
    case home
    case none
    case guest

    var displayName: String {
        switch self {
        case .home:
            return "HOME"
        case .guest:
            return "GUEST"
        case .none:
            return "OFF"
        }
    }
}

enum TeamSide: String, Codable, CaseIterable, Identifiable {
    case home
    case guest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .guest:
            return "Guest"
        }
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
            return "Red"
        case .orange:
            return "Orange"
        case .yellow:
            return "Yellow"
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
            return "None"
        case .yellow:
            return "Yellow"
        case .red:
            return "Red"
        }
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

    init(
        id: UUID = UUID(),
        name: String,
        sport: SportType = .basketball,
        homeTeamName: String,
        guestTeamName: String,
        period: Int,
        clockSeconds: Int,
        shotClockSeconds: Int = 24,
        possessionDirection: PossessionDirection = .none
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
    }
}

@MainActor
final class ScoreboardStore: ObservableObject {
    static let shared = ScoreboardStore()
    nonisolated static let maxGameClockSeconds = 59 * 60 + 59
    nonisolated static let maxShotClockSeconds = 99
    nonisolated static let maxShotClockMilliseconds = maxShotClockSeconds * 1_000
    nonisolated static let defaultRosterSize = 12
    nonisolated static let minRosterSize = 5
    nonisolated static let maxRosterSize = 15
    nonisolated static let defaultDisplayLineupSize = 5

    @Published var selectedSport: SportType = .basketball
    @Published var homeTeamName = ""
    @Published var guestTeamName = ""
    @Published var homeScore = 0
    @Published var guestScore = 0
    @Published var period = 1
    @Published var gameClockSeconds = 12 * 60
    @Published var defaultClockSeconds = 12 * 60
    @Published var isGameClockEnabled = true
    @Published var shotClockMilliseconds = 24_000
    @Published var defaultShotClockSeconds = 24
    @Published var activeShotClockPresetSeconds = 24
    @Published var possessionDirection: PossessionDirection = .none
    @Published var areSidesSwapped = false
    @Published var isPlayerTrackingEnabled = false
    @Published var isPlayerOverlayPaused = false
    @Published var rosterSizePerTeam = defaultRosterSize
    @Published var displayLineupSize = defaultDisplayLineupSize
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
    @Published var homeTeamFouls = 0
    @Published var guestTeamFouls = 0
    @Published var theme: ScoreboardTheme = .classic
    @Published var externalDisplayBackgroundMode: ExternalDisplayBackgroundMode = .blurred
    @Published var isSoundEnabled = true
    @Published var isClockRunning = false
    @Published var isShotClockRunning = false
    @Published var didCompleteSetup = false
    @Published var setupPresets: [SetupPreset] = []

    private var timer: Timer?
    private var lastTimerFireDate: Date?
    private var accumulatedGameClockElapsed: TimeInterval = 0
    private var accumulatedShotClockElapsed: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    private var isAuditLoggingSuspended = false
    private let persistenceKey = "smartScoreboard.persistedState"
    private let buzzerPlayer = BuzzerPlayer()
    private let logManager = ScoreboardLogManager.shared

    private init() {
        loadPersistedState()
        configurePersistence()
    }

    var formattedClock: String {
        Self.formatGameClock(gameClockSeconds)
    }

    var formattedShotClock: String {
        Self.formatShotClock(milliseconds: shotClockMilliseconds)
    }

    var isGameClockInterlockActive: Bool {
        showsGameClock && isClockRunning
    }

    var showsGameClock: Bool {
        selectedSport != .volleyball || isGameClockEnabled
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
        selectedSport.supportsShotClock && isShotClockRedEnabled && shotClockMilliseconds <= boundedShotClockMilliseconds(shotClockRedThresholdSeconds * 1_000)
    }

    var supportsShotClock: Bool {
        selectedSport.supportsShotClock
    }

    var supportsPossession: Bool {
        selectedSport.supportsPossession
    }

    var supportsFouls: Bool {
        selectedSport.supportsFouls
    }

    var supportsCards: Bool {
        selectedSport.supportsCards
    }

    var supportsTeamFouls: Bool {
        selectedSport.supportsTeamFouls
    }

    var supportsPlayerTracking: Bool {
        selectedSport.supportsPlayerTracking
    }

    var showsSubstitutionTracking: Bool {
        selectedSport.showsSubstitutionTracking || homeSubstitutionsAllowed > 0 || guestSubstitutionsAllowed > 0
    }

    var periodTitle: String {
        selectedSport.periodTitle
    }

    var periodShortTitle: String {
        selectedSport.periodShortTitle
    }

    var gameClockMode: GameClockMode {
        selectedSport.clockMode
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

    func teamFouls(for side: TeamSide) -> Int {
        side == .home ? homeTeamFouls : guestTeamFouls
    }

    func currentLogContext() -> ScoreboardLogContext {
        ScoreboardLogContext(
            gameFileName: nil,
            gameFilePath: nil,
            sport: selectedSport,
            period: period,
            isClockRunning: isClockRunning,
            gameClockSeconds: gameClockSeconds,
            supportsShotClock: supportsShotClock,
            isShotClockRunning: supportsShotClock ? isShotClockRunning : nil,
            shotClockMilliseconds: supportsShotClock ? shotClockMilliseconds : nil,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            homeScore: homeScore,
            guestScore: guestScore
        )
    }

    nonisolated static func formatGameClock(_ totalSeconds: Int) -> String {
        let boundedSeconds = max(0, min(maxGameClockSeconds, totalSeconds))
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

    func updateTeamName(_ name: String, isHome: Bool) {
        let resolvedName = normalizedTeamName(name)

        if isHome {
            homeTeamName = resolvedName
        } else {
            guestTeamName = resolvedName
        }
    }

    func adjustScore(isHome: Bool, by delta: Int) {
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
            summary: "\(isHome ? TeamSide.home.title : TeamSide.guest.title) score \(delta >= 0 ? "+" : "")\(delta)",
            outcome: updatedScore == previousScore ? .ignored : .applied,
            teamSide: isHome ? .home : .guest,
            delta: delta,
            value: updatedScore
        )
    }

    func adjustPeriod(by delta: Int) {
        let previousPeriod = period
        period = max(1, min(9, period + delta))
        recordLog(
            kind: .periodAdjustment,
            summary: "\(delta >= 0 ? "Next" : "Previous") \(periodTitle)",
            outcome: period == previousPeriod ? .ignored : .applied,
            delta: delta,
            value: period
        )
    }

    func setPeriod(_ value: Int) {
        period = max(1, min(9, value))
    }

    func adjustClock(by delta: Int) {
        guard showsGameClock else {
            recordLog(
                kind: .clockAdjustment,
                summary: "Game clock \(delta >= 0 ? "+" : "")\(delta)s",
                outcome: .ignored,
                delta: delta
            )
            return
        }

        let previousClock = gameClockSeconds
        gameClockSeconds = boundedGameClockSeconds(gameClockSeconds + delta)
        if gameClockMode == .countdown && gameClockSeconds == 0 {
            pauseClock()
        }

        recordLog(
            kind: .clockAdjustment,
            summary: "Game clock \(delta >= 0 ? "+" : "")\(delta)s",
            outcome: gameClockSeconds == previousClock ? .ignored : .applied,
            delta: delta,
            value: gameClockSeconds
        )
    }

    func adjustShotClock(by delta: Int) {
        guard supportsShotClock else {
            recordLog(
                kind: .shotClockAdjustment,
                summary: "Shot clock \(delta >= 0 ? "+" : "")\(delta)s",
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
            summary: "Shot clock \(delta >= 0 ? "+" : "")\(delta)s",
            outcome: shotClockMilliseconds == previousMilliseconds ? .ignored : .applied,
            delta: delta,
            value: shotClockMilliseconds / 1_000
        )
    }

    func resetClock(to seconds: Int? = nil) {
        guard showsGameClock else {
            pauseClock()
            recordLog(
                kind: .clockReset,
                summary: "Reset game clock",
                outcome: .ignored,
                value: seconds ?? defaultClockSeconds
            )
            return
        }

        guard !isGameClockInterlockActive else {
            recordLog(
                kind: .clockReset,
                summary: "Reset game clock",
                outcome: .ignored,
                value: seconds ?? defaultClockSeconds
            )
            return
        }

        pauseClock()
        gameClockSeconds = boundedGameClockSeconds(seconds ?? defaultClockSeconds)
        recordLog(
            kind: .clockReset,
            summary: "Reset game clock",
            outcome: .applied,
            value: gameClockSeconds
        )
    }

    func resetShotClock(to seconds: Int? = nil) {
        guard supportsShotClock else {
            shotClockMilliseconds = 0
            activeShotClockPresetSeconds = 0
            possessionDirection = .none
            pauseShotClock()
            recordLog(
                kind: .shotClockReset,
                summary: "Reset shot clock",
                outcome: .ignored,
                value: 0
            )
            return
        }

        pauseShotClock()
        let targetSeconds = boundedShotClockSeconds(seconds ?? defaultShotClockSeconds)
        activeShotClockPresetSeconds = targetSeconds
        shotClockMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)
        recordLog(
            kind: .shotClockReset,
            summary: "Reset shot clock",
            outcome: .applied,
            value: targetSeconds
        )
    }

    func toggleClock() {
        let wasRunning = isClockRunning
        isClockRunning ? pauseClock() : startClock()
        recordLog(
            kind: .clockToggle,
            summary: wasRunning ? "Pause game clock" : "Start game clock",
            outcome: wasRunning == isClockRunning ? .ignored : .applied
        )
    }

    func toggleSoundEnabled() {
        isSoundEnabled.toggle()

        if !isSoundEnabled {
            buzzerPlayer.stop()
        }
    }

    func playTestBuzzer() {
        guard isSoundEnabled else {
            return
        }

        buzzerPlayer.play()
    }

    func toggleShotClock() {
        guard supportsShotClock else {
            recordLog(
                kind: .shotClockToggle,
                summary: "Toggle shot clock",
                outcome: .ignored
            )
            return
        }

        let wasRunning = isShotClockRunning
        isShotClockRunning ? pauseShotClock() : startShotClock()
        recordLog(
            kind: .shotClockToggle,
            summary: wasRunning ? "Pause shot clock" : "Start shot clock",
            outcome: wasRunning == isShotClockRunning ? .ignored : .applied
        )
    }

    func setPossessionDirection(_ direction: PossessionDirection, autoStartShotClock: Bool = false) {
        guard supportsPossession else {
            possessionDirection = .none
            recordLog(
                kind: .possessionChange,
                summary: "Set possession \(direction.displayName)",
                outcome: .ignored,
                notes: "Current sport does not support possession"
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
                summary: "Set possession OFF",
                outcome: previousDirection == direction ? .ignored : .applied
            )
            return
        }

        guard autoStartShotClock, !isShotClockRunning else {
            recordLog(
                kind: .possessionChange,
                summary: "Set possession \(direction.displayName)",
                outcome: previousDirection == direction ? .ignored : .applied
            )
            return
        }

        startShotClock()
        recordLog(
            kind: .possessionChange,
            summary: "Set possession \(direction.displayName)",
            outcome: .applied,
            notes: "Shot clock auto-started"
        )
    }

    func assignShotClock(to seconds: Int, forHomeTeam isHome: Bool) {
        guard supportsShotClock else {
            recordLog(
                kind: .shotClockAssignment,
                summary: "Assign shot clock \(seconds)s to \(isHome ? TeamSide.home.title : TeamSide.guest.title)",
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
            isShotClockRunning ? pauseShotClock() : startShotClock()
            recordLog(
                kind: .shotClockAssignment,
                summary: "\(isShotClockRunning ? "Start" : "Pause") \(seconds)s shot clock for \(isHome ? TeamSide.home.title : TeamSide.guest.title)",
                outcome: .applied,
                teamSide: isHome ? .home : .guest,
                value: seconds
            )
            return
        }

        possessionDirection = targetDirection
        activeShotClockPresetSeconds = targetSeconds
        shotClockMilliseconds = targetMilliseconds
        startShotClock()
        recordLog(
            kind: .shotClockAssignment,
            summary: "Assign \(seconds)s shot clock to \(isHome ? TeamSide.home.title : TeamSide.guest.title)",
            outcome: .applied,
            teamSide: isHome ? .home : .guest,
            value: targetSeconds
        )
    }

    func resetActiveShotClock() {
        guard supportsShotClock else {
            recordLog(
                kind: .shotClockReset,
                summary: "Reset active shot clock",
                outcome: .ignored
            )
            return
        }

        let targetSeconds = boundedShotClockSeconds(activeShotClockPresetSeconds)
        let targetMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)

        shotClockMilliseconds = targetMilliseconds
        possessionDirection = .none

        pauseShotClock()
        recordLog(
            kind: .shotClockReset,
            summary: "Reset active shot clock",
            outcome: .applied,
            value: targetSeconds
        )
    }

    func newGame() {
        pauseClock()
        pauseShotClock()
        homeScore = 0
        guestScore = 0
        period = 1
        possessionDirection = .none
        activeShotClockPresetSeconds = defaultShotClockSeconds
        gameClockSeconds = defaultClockSeconds
        shotClockMilliseconds = defaultShotClockSeconds * 1_000
        homeSubstitutionsUsed = 0
        guestSubstitutionsUsed = 0
        homeTeamFouls = 0
        guestTeamFouls = 0
        isPlayerOverlayPaused = false
        resetPlayerTrackingForNewGame()
    }

    func resetScores() {
        guard !isGameClockInterlockActive else {
            recordLog(
                kind: .scoresReset,
                summary: "Zero both scores",
                outcome: .ignored
            )
            return
        }

        homeScore = 0
        guestScore = 0
        recordLog(
            kind: .scoresReset,
            summary: "Zero both scores",
            outcome: .applied
        )
    }

    func swapSides() {
        areSidesSwapped.toggle()
        recordLog(
            kind: .sideSwap,
            summary: "Swap home and guest sides",
            outcome: .applied
        )
    }

    func setPlayerTrackingEnabled(_ isEnabled: Bool) {
        isPlayerTrackingEnabled = selectedSport.supportsPlayerTracking ? isEnabled : false
    }

    func togglePlayerOverlayPaused() {
        isPlayerOverlayPaused.toggle()
        recordLog(
            kind: .playerOverlayToggle,
            summary: isPlayerOverlayPaused ? "Pause public player overlay" : "Resume public player overlay",
            outcome: .applied
        )
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
                summary: "Adjust player foul",
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
            summary: "\(side.title) player foul \(delta >= 0 ? "+" : "")\(delta)",
            outcome: playerSummary?.foulCount == updatedPlayer?.foulCount ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? playerSummary,
            delta: delta,
            value: updatedPlayer?.foulCount
        )
    }

    func resetFouls(for side: TeamSide, playerID: UUID) {
        guard supportsFouls else {
            recordLog(
                kind: .playerFoulReset,
                summary: "Reset player foul",
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
            summary: "Reset \(side.title) player foul",
            outcome: previousPlayer?.foulCount == updatedPlayer?.foulCount ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? previousPlayer
        )
    }

    func resetFouls(for side: TeamSide) {
        guard supportsFouls else {
            recordLog(
                kind: .playerFoulResetAll,
                summary: "Reset \(side.title) player fouls",
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
            summary: "Reset \(side.title) player fouls",
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
                summary: "Set player card \(status.title)",
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
            summary: "Set \(side.title) player card \(status.title)",
            outcome: previousPlayer?.cardStatus == updatedPlayer?.cardStatus ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? previousPlayer,
            value: cardLogValue(for: status)
        )
    }

    func resetCards(for side: TeamSide) {
        guard supportsCards else {
            recordLog(
                kind: .playerCardReset,
                summary: "Reset \(side.title) cards",
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
            summary: "Reset \(side.title) cards",
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
                summary: "\(side.title) team fouls \(delta >= 0 ? "+" : "")\(delta)",
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
            summary: "\(side.title) team fouls \(delta >= 0 ? "+" : "")\(delta)",
            outcome: teamFouls(for: side) == previousValue ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: teamFouls(for: side)
        )
    }

    func resetTeamFouls(for side: TeamSide) {
        guard supportsTeamFouls else {
            recordLog(
                kind: .teamFoulReset,
                summary: "Reset \(side.title) team fouls",
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
            summary: "Reset \(side.title) team fouls",
            outcome: previousValue == 0 ? .ignored : .applied,
            teamSide: side
        )
    }

    func resetAllTeamFouls() {
        resetTeamFouls(for: .home)
        resetTeamFouls(for: .guest)
    }

    func setGameClockEnabled(_ isEnabled: Bool) {
        isGameClockEnabled = selectedSport == .volleyball ? isEnabled : true

        if !showsGameClock {
            pauseClock()
        }
    }

    func setSelectedSport(_ sport: SportType, applyDefaults: Bool = true) {
        selectedSport = sport

        if applyDefaults {
            defaultClockSeconds = boundedGameClockSeconds(sport.defaultClockSeconds)
            gameClockSeconds = defaultClockSeconds
            isGameClockEnabled = sport == .volleyball ? isGameClockEnabled : true
            defaultShotClockSeconds = boundedShotClockSeconds(sport.defaultShotClockSeconds)
            activeShotClockPresetSeconds = defaultShotClockSeconds
            shotClockMilliseconds = boundedShotClockMilliseconds(defaultShotClockSeconds * 1_000)
            setPeriod(1)
            possessionDirection = .none
            isShotClockRunning = false
            homeSubstitutionsAllowed = sport.defaultSubstitutionLimit
            guestSubstitutionsAllowed = sport.defaultSubstitutionLimit
            homeSubstitutionsUsed = 0
            guestSubstitutionsUsed = 0
            homeTeamFouls = 0
            guestTeamFouls = 0
            setRosterSizePerTeam(sport.defaultRosterSize)
            setDisplayLineupSize(sport.defaultDisplayLineupSize)
            if !sport.supportsPlayerTracking {
                isPlayerTrackingEnabled = false
            }
        } else {
            if sport != .volleyball {
                isGameClockEnabled = true
            }
            if !sport.supportsShotClock {
                defaultShotClockSeconds = 0
                activeShotClockPresetSeconds = 0
                shotClockMilliseconds = 0
                possessionDirection = .none
                isShotClockRunning = false
            }
            if !sport.supportsPlayerTracking {
                isPlayerTrackingEnabled = false
            }
        }
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
            summary: "\(side.title) swaps \(delta >= 0 ? "+" : "")\(delta)",
            outcome: substitutionsUsed(for: side) == previousValue ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: substitutionsUsed(for: side)
        )
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
            summary: "\(isActive ? "Show" : "Bench") \(side.title) player",
            outcome: previousPlayer?.isInActiveLineup == updatedPlayer?.isInActiveLineup ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? previousPlayer,
            notes: updatedPlayer?.isInActiveLineup == true ? "Active lineup" : "Bench"
        )
    }

    func currentGameSnapshot() -> ScoreboardGameSnapshot {
        ScoreboardGameSnapshot(
            fileVersion: 5,
            sport: selectedSport,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            homeScore: homeScore,
            guestScore: guestScore,
            period: period,
            gameClockSeconds: gameClockSeconds,
            defaultClockSeconds: defaultClockSeconds,
            isGameClockEnabled: isGameClockEnabled,
            shotClockMilliseconds: shotClockMilliseconds,
            defaultShotClockSeconds: defaultShotClockSeconds,
            activeShotClockPresetSeconds: activeShotClockPresetSeconds,
            possessionDirection: possessionDirection,
            areSidesSwapped: areSidesSwapped,
            isPlayerTrackingEnabled: isPlayerTrackingEnabled,
            isPlayerOverlayPaused: isPlayerOverlayPaused,
            rosterSizePerTeam: rosterSizePerTeam,
            displayLineupSize: displayLineupSize,
            playerFoulHighlightColor: playerFoulHighlightColor,
            isGameClockRedEnabled: isGameClockRedEnabled,
            gameClockRedThresholdSeconds: gameClockRedThresholdSeconds,
            isShotClockRedEnabled: isShotClockRedEnabled,
            shotClockRedThresholdSeconds: shotClockRedThresholdSeconds,
            homeSubstitutionsAllowed: homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: guestSubstitutionsAllowed,
            homeSubstitutionsUsed: homeSubstitutionsUsed,
            guestSubstitutionsUsed: guestSubstitutionsUsed,
            homeTeamFouls: homeTeamFouls,
            guestTeamFouls: guestTeamFouls,
            homeRoster: homeRoster,
            guestRoster: guestRoster
        )
    }

    func applyGameSnapshot(_ snapshot: ScoreboardGameSnapshot) {
        performWithoutAuditLogging {
            pauseClock()
            pauseShotClock()

            setSelectedSport(snapshot.sport ?? .basketball, applyDefaults: false)
            homeTeamName = normalizedTeamName(snapshot.homeTeamName)
            guestTeamName = normalizedTeamName(snapshot.guestTeamName)
            homeScore = max(0, snapshot.homeScore)
            guestScore = max(0, snapshot.guestScore)
            period = max(1, min(9, snapshot.period))
            gameClockSeconds = boundedGameClockSeconds(snapshot.gameClockSeconds)
            defaultClockSeconds = boundedGameClockSeconds(snapshot.defaultClockSeconds)
            isGameClockEnabled = snapshot.isGameClockEnabled ?? true
            shotClockMilliseconds = boundedShotClockMilliseconds(snapshot.shotClockMilliseconds)
            defaultShotClockSeconds = boundedShotClockSeconds(snapshot.defaultShotClockSeconds)
            activeShotClockPresetSeconds = boundedShotClockSeconds(snapshot.activeShotClockPresetSeconds ?? snapshot.defaultShotClockSeconds)
            possessionDirection = supportsPossession ? snapshot.possessionDirection : .none
            areSidesSwapped = snapshot.areSidesSwapped
            isPlayerTrackingEnabled = supportsPlayerTracking ? (snapshot.isPlayerTrackingEnabled ?? false) : false
            isPlayerOverlayPaused = snapshot.isPlayerOverlayPaused ?? false
            rosterSizePerTeam = max(Self.minRosterSize, min(Self.maxRosterSize, snapshot.rosterSizePerTeam ?? Self.defaultRosterSize))
            displayLineupSize = max(1, min(rosterSizePerTeam, snapshot.displayLineupSize ?? Self.defaultDisplayLineupSize))
            playerFoulHighlightColor = snapshot.playerFoulHighlightColor ?? .yellow
            isGameClockRedEnabled = snapshot.isGameClockRedEnabled ?? false
            gameClockRedThresholdSeconds = boundedGameClockSeconds(snapshot.gameClockRedThresholdSeconds ?? 60)
            isShotClockRedEnabled = snapshot.isShotClockRedEnabled ?? false
            shotClockRedThresholdSeconds = boundedShotClockSeconds(snapshot.shotClockRedThresholdSeconds ?? 5)
            homeSubstitutionsAllowed = max(0, snapshot.homeSubstitutionsAllowed ?? selectedSport.defaultSubstitutionLimit)
            guestSubstitutionsAllowed = max(0, snapshot.guestSubstitutionsAllowed ?? selectedSport.defaultSubstitutionLimit)
            homeSubstitutionsUsed = max(0, min(homeSubstitutionsAllowed, snapshot.homeSubstitutionsUsed ?? 0))
            guestSubstitutionsUsed = max(0, min(guestSubstitutionsAllowed, snapshot.guestSubstitutionsUsed ?? 0))
            homeTeamFouls = max(0, snapshot.homeTeamFouls ?? 0)
            guestTeamFouls = max(0, snapshot.guestTeamFouls ?? 0)
            homeRoster = normalizedRoster(snapshot.homeRoster, fallbackCount: rosterSizePerTeam)
            guestRoster = normalizedRoster(snapshot.guestRoster, fallbackCount: rosterSizePerTeam)
            if !supportsShotClock {
                defaultShotClockSeconds = 0
                activeShotClockPresetSeconds = 0
                shotClockMilliseconds = 0
            }
            if !showsGameClock {
                pauseClock()
            }
            didCompleteSetup = true
        }
    }

    func applySetup(
        sport: SportType,
        homeName: String,
        guestName: String,
        period: Int,
        clockSeconds: Int,
        isGameClockEnabled: Bool = true,
        shotClockSeconds: Int
    ) {
        performWithoutAuditLogging {
            setSelectedSport(sport, applyDefaults: true)
            updateTeamName(homeName, isHome: true)
            updateTeamName(guestName, isHome: false)
            homeScore = 0
            guestScore = 0
            setPeriod(period)
            defaultClockSeconds = boundedGameClockSeconds(clockSeconds)
            setGameClockEnabled(isGameClockEnabled)
            defaultShotClockSeconds = sport.supportsShotClock ? boundedShotClockSeconds(shotClockSeconds) : 0
            activeShotClockPresetSeconds = defaultShotClockSeconds
            possessionDirection = .none
            areSidesSwapped = false
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
        guard showsGameClock else {
            return
        }

        if gameClockMode == .countdown && gameClockSeconds == 0 {
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
    }

    private func pauseClock() {
        isClockRunning = false
        updateTimerState()
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
        isShotClockRunning = false
        updateTimerState()
    }

    private func updateTimerState() {
        guard isClockRunning || isShotClockRunning else {
            timer?.invalidate()
            timer = nil
            lastTimerFireDate = nil
            accumulatedGameClockElapsed = 0
            accumulatedShotClockElapsed = 0
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
                let now = Date()
                let elapsed = now.timeIntervalSince(self.lastTimerFireDate ?? now)
                self.lastTimerFireDate = now
                self.tick(elapsed: elapsed)
            }
        }
    }

    private func tick(elapsed: TimeInterval) {
        var shouldPlayBuzzer = false

        if isClockRunning {
            accumulatedGameClockElapsed += elapsed
            let elapsedWholeSeconds = Int(accumulatedGameClockElapsed)

            if elapsedWholeSeconds > 0 {
                accumulatedGameClockElapsed -= TimeInterval(elapsedWholeSeconds)
                switch gameClockMode {
                case .countdown:
                    gameClockSeconds = max(0, gameClockSeconds - elapsedWholeSeconds)

                    if gameClockSeconds == 0 {
                        isClockRunning = false
                        accumulatedGameClockElapsed = 0
                        shouldPlayBuzzer = true
                        recordLog(
                            kind: .clockExpired,
                            summary: "Game clock expired",
                            outcome: .applied,
                            value: gameClockSeconds
                        )
                    }
                case .countUp:
                    gameClockSeconds = min(Self.maxGameClockSeconds, gameClockSeconds + elapsedWholeSeconds)

                    if gameClockSeconds == Self.maxGameClockSeconds {
                        isClockRunning = false
                        accumulatedGameClockElapsed = 0
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
                    shouldPlayBuzzer = true
                    recordLog(
                        kind: .shotClockExpired,
                        summary: "Shot clock expired",
                        outcome: .applied,
                        value: 0
                    )
                }
            }
        }

        updateTimerState()

        if shouldPlayBuzzer {
            playBuzzer()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func normalizedTeamName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
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

    private func playBuzzer() {
        guard isSoundEnabled else {
            return
        }

        buzzerPlayer.play()
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

    private func configurePersistence() {
        let persistencePublishers: [AnyPublisher<Void, Never>] = [
            $selectedSport.map { _ in () }.eraseToAnyPublisher(),
            $homeTeamName.map { _ in () }.eraseToAnyPublisher(),
            $guestTeamName.map { _ in () }.eraseToAnyPublisher(),
            $homeScore.map { _ in () }.eraseToAnyPublisher(),
            $guestScore.map { _ in () }.eraseToAnyPublisher(),
            $period.map { _ in () }.eraseToAnyPublisher(),
            $gameClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $defaultClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $isGameClockEnabled.map { _ in () }.eraseToAnyPublisher(),
            $shotClockMilliseconds.map { _ in () }.eraseToAnyPublisher(),
            $defaultShotClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $activeShotClockPresetSeconds.map { _ in () }.eraseToAnyPublisher(),
            $possessionDirection.map { _ in () }.eraseToAnyPublisher(),
            $areSidesSwapped.map { _ in () }.eraseToAnyPublisher(),
            $isPlayerTrackingEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isPlayerOverlayPaused.map { _ in () }.eraseToAnyPublisher(),
            $rosterSizePerTeam.map { _ in () }.eraseToAnyPublisher(),
            $displayLineupSize.map { _ in () }.eraseToAnyPublisher(),
            $playerFoulHighlightColor.map { _ in () }.eraseToAnyPublisher(),
            $isGameClockRedEnabled.map { _ in () }.eraseToAnyPublisher(),
            $gameClockRedThresholdSeconds.map { _ in () }.eraseToAnyPublisher(),
            $isShotClockRedEnabled.map { _ in () }.eraseToAnyPublisher(),
            $shotClockRedThresholdSeconds.map { _ in () }.eraseToAnyPublisher(),
            $homeSubstitutionsAllowed.map { _ in () }.eraseToAnyPublisher(),
            $guestSubstitutionsAllowed.map { _ in () }.eraseToAnyPublisher(),
            $homeSubstitutionsUsed.map { _ in () }.eraseToAnyPublisher(),
            $guestSubstitutionsUsed.map { _ in () }.eraseToAnyPublisher(),
            $homeTeamFouls.map { _ in () }.eraseToAnyPublisher(),
            $guestTeamFouls.map { _ in () }.eraseToAnyPublisher(),
            $homeRoster.map { _ in () }.eraseToAnyPublisher(),
            $guestRoster.map { _ in () }.eraseToAnyPublisher(),
            $theme.map { _ in () }.eraseToAnyPublisher(),
            $externalDisplayBackgroundMode.map { _ in () }.eraseToAnyPublisher(),
            $isSoundEnabled.map { _ in () }.eraseToAnyPublisher(),
            $isClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $isShotClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $didCompleteSetup.map { _ in () }.eraseToAnyPublisher(),
            $setupPresets.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(persistencePublishers)
            .sink { [weak self] _ in
                self?.persistState()
            }
            .store(in: &cancellables)
    }

    private func loadPersistedState() {
        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let persistedState = try? JSONDecoder().decode(PersistedState.self, from: data)
        else {
            return
        }

        selectedSport = persistedState.selectedSport
        homeTeamName = persistedState.homeTeamName
        guestTeamName = persistedState.guestTeamName
        homeScore = persistedState.homeScore
        guestScore = persistedState.guestScore
        period = max(1, min(9, persistedState.period))
        gameClockSeconds = boundedGameClockSeconds(persistedState.gameClockSeconds)
        defaultClockSeconds = boundedGameClockSeconds(persistedState.defaultClockSeconds)
        isGameClockEnabled = persistedState.isGameClockEnabled
        shotClockMilliseconds = boundedShotClockMilliseconds(persistedState.shotClockMilliseconds)
        defaultShotClockSeconds = boundedShotClockSeconds(persistedState.defaultShotClockSeconds)
        activeShotClockPresetSeconds = boundedShotClockSeconds(persistedState.activeShotClockPresetSeconds)
        possessionDirection = persistedState.selectedSport.supportsPossession ? persistedState.possessionDirection : .none
        areSidesSwapped = persistedState.areSidesSwapped
        isPlayerTrackingEnabled = persistedState.selectedSport.supportsPlayerTracking ? persistedState.isPlayerTrackingEnabled : false
        isPlayerOverlayPaused = persistedState.isPlayerOverlayPaused
        rosterSizePerTeam = max(Self.minRosterSize, min(Self.maxRosterSize, persistedState.rosterSizePerTeam))
        displayLineupSize = max(1, min(rosterSizePerTeam, persistedState.displayLineupSize))
        playerFoulHighlightColor = persistedState.playerFoulHighlightColor
        isGameClockRedEnabled = persistedState.isGameClockRedEnabled
        gameClockRedThresholdSeconds = boundedGameClockSeconds(persistedState.gameClockRedThresholdSeconds)
        isShotClockRedEnabled = persistedState.isShotClockRedEnabled
        shotClockRedThresholdSeconds = boundedShotClockSeconds(persistedState.shotClockRedThresholdSeconds)
        homeSubstitutionsAllowed = max(0, persistedState.homeSubstitutionsAllowed)
        guestSubstitutionsAllowed = max(0, persistedState.guestSubstitutionsAllowed)
        homeSubstitutionsUsed = max(0, min(homeSubstitutionsAllowed, persistedState.homeSubstitutionsUsed))
        guestSubstitutionsUsed = max(0, min(guestSubstitutionsAllowed, persistedState.guestSubstitutionsUsed))
        homeTeamFouls = max(0, persistedState.homeTeamFouls)
        guestTeamFouls = max(0, persistedState.guestTeamFouls)
        homeRoster = normalizedRoster(persistedState.homeRoster, fallbackCount: rosterSizePerTeam)
        guestRoster = normalizedRoster(persistedState.guestRoster, fallbackCount: rosterSizePerTeam)
        theme = persistedState.theme
        externalDisplayBackgroundMode = persistedState.externalDisplayBackgroundMode
        isSoundEnabled = persistedState.isSoundEnabled
        didCompleteSetup = persistedState.didCompleteSetup
        setupPresets = persistedState.setupPresets
        if !selectedSport.supportsShotClock {
            defaultShotClockSeconds = 0
            activeShotClockPresetSeconds = 0
            shotClockMilliseconds = 0
        }
        if selectedSport != .volleyball {
            isGameClockEnabled = true
        }
        isClockRunning = false
        isShotClockRunning = false
    }

    private func persistState() {
        let persistedState = PersistedState(
            selectedSport: selectedSport,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            homeScore: homeScore,
            guestScore: guestScore,
            period: period,
            gameClockSeconds: gameClockSeconds,
            defaultClockSeconds: defaultClockSeconds,
            isGameClockEnabled: isGameClockEnabled,
            shotClockMilliseconds: shotClockMilliseconds,
            defaultShotClockSeconds: defaultShotClockSeconds,
            activeShotClockPresetSeconds: activeShotClockPresetSeconds,
            possessionDirection: possessionDirection,
            areSidesSwapped: areSidesSwapped,
            isPlayerTrackingEnabled: isPlayerTrackingEnabled,
            isPlayerOverlayPaused: isPlayerOverlayPaused,
            rosterSizePerTeam: rosterSizePerTeam,
            displayLineupSize: displayLineupSize,
            playerFoulHighlightColor: playerFoulHighlightColor,
            isGameClockRedEnabled: isGameClockRedEnabled,
            gameClockRedThresholdSeconds: gameClockRedThresholdSeconds,
            isShotClockRedEnabled: isShotClockRedEnabled,
            shotClockRedThresholdSeconds: shotClockRedThresholdSeconds,
            homeSubstitutionsAllowed: homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: guestSubstitutionsAllowed,
            homeSubstitutionsUsed: homeSubstitutionsUsed,
            guestSubstitutionsUsed: guestSubstitutionsUsed,
            homeTeamFouls: homeTeamFouls,
            guestTeamFouls: guestTeamFouls,
            homeRoster: homeRoster,
            guestRoster: guestRoster,
            theme: theme,
            externalDisplayBackgroundMode: externalDisplayBackgroundMode,
            isSoundEnabled: isSoundEnabled,
            didCompleteSetup: didCompleteSetup,
            setupPresets: setupPresets
        )

        guard let data = try? JSONEncoder().encode(persistedState) else {
            return
        }

        UserDefaults.standard.set(data, forKey: persistenceKey)
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
            homeRoster = normalizedRoster(roster, fallbackCount: rosterSizePerTeam)
        case .guest:
            var roster = guestRoster
            mutate(&roster)
            guestRoster = normalizedRoster(roster, fallbackCount: rosterSizePerTeam)
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

    private func normalizeActiveLineup(in roster: inout TeamRoster) {
        let activeIndices = roster.players.indices.filter { roster.players[$0].isInActiveLineup }
        if activeIndices.count > activeLineupCountLimit {
            for index in activeIndices.dropFirst(activeLineupCountLimit) {
                roster.players[index].isInActiveLineup = false
            }
        }
    }
}

private struct PersistedState: Codable {
    var selectedSport: SportType
    var homeTeamName: String
    var guestTeamName: String
    var homeScore: Int
    var guestScore: Int
    var period: Int
    var gameClockSeconds: Int
    var defaultClockSeconds: Int
    var isGameClockEnabled: Bool
    var shotClockMilliseconds: Int
    var defaultShotClockSeconds: Int
    var activeShotClockPresetSeconds: Int
    var possessionDirection: PossessionDirection
    var areSidesSwapped: Bool
    var isPlayerTrackingEnabled: Bool
    var isPlayerOverlayPaused: Bool
    var rosterSizePerTeam: Int
    var displayLineupSize: Int
    var playerFoulHighlightColor: PlayerFoulHighlightColor
    var isGameClockRedEnabled: Bool
    var gameClockRedThresholdSeconds: Int
    var isShotClockRedEnabled: Bool
    var shotClockRedThresholdSeconds: Int
    var homeSubstitutionsAllowed: Int
    var guestSubstitutionsAllowed: Int
    var homeSubstitutionsUsed: Int
    var guestSubstitutionsUsed: Int
    var homeTeamFouls: Int
    var guestTeamFouls: Int
    var homeRoster: TeamRoster
    var guestRoster: TeamRoster
    var theme: ScoreboardTheme
    var externalDisplayBackgroundMode: ExternalDisplayBackgroundMode
    var isSoundEnabled: Bool
    var didCompleteSetup: Bool
    var setupPresets: [SetupPreset]

    private enum CodingKeys: String, CodingKey {
        case homeTeamName
        case selectedSport
        case guestTeamName
        case homeScore
        case guestScore
        case period
        case gameClockSeconds
        case defaultClockSeconds
        case isGameClockEnabled
        case shotClockMilliseconds
        case shotClockSeconds
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
        case homeRoster
        case guestRoster
        case theme
        case externalDisplayBackgroundMode
        case isSoundEnabled
        case didCompleteSetup
        case setupPresets
    }

    init(
        selectedSport: SportType,
        homeTeamName: String,
        guestTeamName: String,
        homeScore: Int,
        guestScore: Int,
        period: Int,
        gameClockSeconds: Int,
        defaultClockSeconds: Int,
        isGameClockEnabled: Bool,
        shotClockMilliseconds: Int,
        defaultShotClockSeconds: Int,
        activeShotClockPresetSeconds: Int,
        possessionDirection: PossessionDirection,
        areSidesSwapped: Bool,
        isPlayerTrackingEnabled: Bool,
        isPlayerOverlayPaused: Bool,
        rosterSizePerTeam: Int,
        displayLineupSize: Int,
        playerFoulHighlightColor: PlayerFoulHighlightColor,
        isGameClockRedEnabled: Bool,
        gameClockRedThresholdSeconds: Int,
        isShotClockRedEnabled: Bool,
        shotClockRedThresholdSeconds: Int,
        homeSubstitutionsAllowed: Int,
        guestSubstitutionsAllowed: Int,
        homeSubstitutionsUsed: Int,
        guestSubstitutionsUsed: Int,
        homeTeamFouls: Int,
        guestTeamFouls: Int,
        homeRoster: TeamRoster,
        guestRoster: TeamRoster,
        theme: ScoreboardTheme,
        externalDisplayBackgroundMode: ExternalDisplayBackgroundMode,
        isSoundEnabled: Bool,
        didCompleteSetup: Bool,
        setupPresets: [SetupPreset]
    ) {
        self.selectedSport = selectedSport
        self.homeTeamName = homeTeamName
        self.guestTeamName = guestTeamName
        self.homeScore = homeScore
        self.guestScore = guestScore
        self.period = period
        self.gameClockSeconds = gameClockSeconds
        self.defaultClockSeconds = defaultClockSeconds
        self.isGameClockEnabled = isGameClockEnabled
        self.shotClockMilliseconds = shotClockMilliseconds
        self.defaultShotClockSeconds = defaultShotClockSeconds
        self.activeShotClockPresetSeconds = activeShotClockPresetSeconds
        self.possessionDirection = possessionDirection
        self.areSidesSwapped = areSidesSwapped
        self.isPlayerTrackingEnabled = isPlayerTrackingEnabled
        self.isPlayerOverlayPaused = isPlayerOverlayPaused
        self.rosterSizePerTeam = rosterSizePerTeam
        self.displayLineupSize = displayLineupSize
        self.playerFoulHighlightColor = playerFoulHighlightColor
        self.isGameClockRedEnabled = isGameClockRedEnabled
        self.gameClockRedThresholdSeconds = gameClockRedThresholdSeconds
        self.isShotClockRedEnabled = isShotClockRedEnabled
        self.shotClockRedThresholdSeconds = shotClockRedThresholdSeconds
        self.homeSubstitutionsAllowed = homeSubstitutionsAllowed
        self.guestSubstitutionsAllowed = guestSubstitutionsAllowed
        self.homeSubstitutionsUsed = homeSubstitutionsUsed
        self.guestSubstitutionsUsed = guestSubstitutionsUsed
        self.homeTeamFouls = homeTeamFouls
        self.guestTeamFouls = guestTeamFouls
        self.homeRoster = homeRoster
        self.guestRoster = guestRoster
        self.theme = theme
        self.externalDisplayBackgroundMode = externalDisplayBackgroundMode
        self.isSoundEnabled = isSoundEnabled
        self.didCompleteSetup = didCompleteSetup
        self.setupPresets = setupPresets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedSport = try container.decodeIfPresent(SportType.self, forKey: .selectedSport) ?? .basketball
        homeTeamName = try container.decode(String.self, forKey: .homeTeamName)
        guestTeamName = try container.decode(String.self, forKey: .guestTeamName)
        homeScore = try container.decode(Int.self, forKey: .homeScore)
        guestScore = try container.decode(Int.self, forKey: .guestScore)
        period = try container.decode(Int.self, forKey: .period)
        gameClockSeconds = try container.decode(Int.self, forKey: .gameClockSeconds)
        defaultClockSeconds = try container.decode(Int.self, forKey: .defaultClockSeconds)
        isGameClockEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGameClockEnabled) ?? true
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
        isPlayerTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPlayerTrackingEnabled) ?? false
        isPlayerOverlayPaused = try container.decodeIfPresent(Bool.self, forKey: .isPlayerOverlayPaused) ?? false
        rosterSizePerTeam = try container.decodeIfPresent(Int.self, forKey: .rosterSizePerTeam) ?? ScoreboardStore.defaultRosterSize
        displayLineupSize = try container.decodeIfPresent(Int.self, forKey: .displayLineupSize) ?? ScoreboardStore.defaultDisplayLineupSize
        playerFoulHighlightColor = try container.decodeIfPresent(PlayerFoulHighlightColor.self, forKey: .playerFoulHighlightColor) ?? .yellow
        isGameClockRedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGameClockRedEnabled) ?? false
        gameClockRedThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .gameClockRedThresholdSeconds) ?? 60
        isShotClockRedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isShotClockRedEnabled) ?? false
        shotClockRedThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .shotClockRedThresholdSeconds) ?? 5
        homeSubstitutionsAllowed = try container.decodeIfPresent(Int.self, forKey: .homeSubstitutionsAllowed) ?? selectedSport.defaultSubstitutionLimit
        guestSubstitutionsAllowed = try container.decodeIfPresent(Int.self, forKey: .guestSubstitutionsAllowed) ?? selectedSport.defaultSubstitutionLimit
        homeSubstitutionsUsed = try container.decodeIfPresent(Int.self, forKey: .homeSubstitutionsUsed) ?? 0
        guestSubstitutionsUsed = try container.decodeIfPresent(Int.self, forKey: .guestSubstitutionsUsed) ?? 0
        homeTeamFouls = try container.decodeIfPresent(Int.self, forKey: .homeTeamFouls) ?? 0
        guestTeamFouls = try container.decodeIfPresent(Int.self, forKey: .guestTeamFouls) ?? 0
        homeRoster = try container.decodeIfPresent(TeamRoster.self, forKey: .homeRoster) ?? TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: rosterSizePerTeam))
        guestRoster = try container.decodeIfPresent(TeamRoster.self, forKey: .guestRoster) ?? TeamRoster(players: ScoreboardStore.makeDefaultRosterPlayers(count: rosterSizePerTeam))
        theme = try container.decodeIfPresent(ScoreboardTheme.self, forKey: .theme) ?? .classic
        externalDisplayBackgroundMode = try container.decodeIfPresent(ExternalDisplayBackgroundMode.self, forKey: .externalDisplayBackgroundMode) ?? .blurred
        isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        didCompleteSetup = try container.decode(Bool.self, forKey: .didCompleteSetup)
        setupPresets = try container.decode([SetupPreset].self, forKey: .setupPresets)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedSport, forKey: .selectedSport)
        try container.encode(homeTeamName, forKey: .homeTeamName)
        try container.encode(guestTeamName, forKey: .guestTeamName)
        try container.encode(homeScore, forKey: .homeScore)
        try container.encode(guestScore, forKey: .guestScore)
        try container.encode(period, forKey: .period)
        try container.encode(gameClockSeconds, forKey: .gameClockSeconds)
        try container.encode(defaultClockSeconds, forKey: .defaultClockSeconds)
        try container.encode(isGameClockEnabled, forKey: .isGameClockEnabled)
        try container.encode(shotClockMilliseconds, forKey: .shotClockMilliseconds)
        try container.encode(defaultShotClockSeconds, forKey: .defaultShotClockSeconds)
        try container.encode(activeShotClockPresetSeconds, forKey: .activeShotClockPresetSeconds)
        try container.encode(possessionDirection, forKey: .possessionDirection)
        try container.encode(areSidesSwapped, forKey: .areSidesSwapped)
        try container.encode(isPlayerTrackingEnabled, forKey: .isPlayerTrackingEnabled)
        try container.encode(isPlayerOverlayPaused, forKey: .isPlayerOverlayPaused)
        try container.encode(rosterSizePerTeam, forKey: .rosterSizePerTeam)
        try container.encode(displayLineupSize, forKey: .displayLineupSize)
        try container.encode(playerFoulHighlightColor, forKey: .playerFoulHighlightColor)
        try container.encode(isGameClockRedEnabled, forKey: .isGameClockRedEnabled)
        try container.encode(gameClockRedThresholdSeconds, forKey: .gameClockRedThresholdSeconds)
        try container.encode(isShotClockRedEnabled, forKey: .isShotClockRedEnabled)
        try container.encode(shotClockRedThresholdSeconds, forKey: .shotClockRedThresholdSeconds)
        try container.encode(homeSubstitutionsAllowed, forKey: .homeSubstitutionsAllowed)
        try container.encode(guestSubstitutionsAllowed, forKey: .guestSubstitutionsAllowed)
        try container.encode(homeSubstitutionsUsed, forKey: .homeSubstitutionsUsed)
        try container.encode(guestSubstitutionsUsed, forKey: .guestSubstitutionsUsed)
        try container.encode(homeTeamFouls, forKey: .homeTeamFouls)
        try container.encode(guestTeamFouls, forKey: .guestTeamFouls)
        try container.encode(homeRoster, forKey: .homeRoster)
        try container.encode(guestRoster, forKey: .guestRoster)
        try container.encode(theme, forKey: .theme)
        try container.encode(externalDisplayBackgroundMode, forKey: .externalDisplayBackgroundMode)
        try container.encode(isSoundEnabled, forKey: .isSoundEnabled)
        try container.encode(didCompleteSetup, forKey: .didCompleteSetup)
        try container.encode(setupPresets, forKey: .setupPresets)
    }
}

@MainActor
final class PublicBoardState: ObservableObject {
    static let shared = PublicBoardState()

    @Published var isPresented = false

    private init() {}
}
