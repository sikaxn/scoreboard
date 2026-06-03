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
    nonisolated static let maxShotClockSeconds = 99
    nonisolated static let maxShotClockMilliseconds = maxShotClockSeconds * 1_000
    nonisolated static let defaultRosterSize = 12
    nonisolated static let minRosterSize = 5
    nonisolated static let maxRosterSize = 15
    nonisolated static let defaultDisplayLineupSize = 5
    nonisolated static let defaultSoundAssignments: [ScoreboardSoundEvent: ScoreboardSoundEffect] = [
        .gameClockExpired: .classicBuzzer,
        .shotClockExpired: .shotClockBeep,
        .chessClockExpired: .softChime,
        .debateSegmentExpired: .debateBell,
        .debatePrepExpired: .debateDoubleBell,
        .hockeyPenaltyExpired: .penaltyChirp,
        .gameClockStarted: .none,
        .gameClockPaused: .none,
        .shotClockStarted: .none,
        .shotClockPaused: .none,
        .shotClockReset: .none,
        .yellowCardAssigned: .none,
        .redCardAssigned: .none,
        .substitutionUsed: .none,
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

    @Published var selectedSport: SportType = .simple
    @Published var customSportConfig: CustomSportConfig = .default
    @Published var homeTeamName = ""
    @Published var guestTeamName = ""
    @Published var homeScore = 0
    @Published var guestScore = 0
    @Published var period = 1
    @Published var gameClockSeconds = 10 * 60
    @Published var defaultClockSeconds = 10 * 60
    @Published var isGameClockEnabled = true
    @Published var shotClockMilliseconds = 0
    @Published var defaultShotClockSeconds = 0
    @Published var activeShotClockPresetSeconds = 0
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
    @Published var externalDisplayBackgroundMode: ExternalDisplayBackgroundMode = .blurred
    @Published var isSoundEnabled = true
    @Published var soundAssignments = ScoreboardStore.defaultSoundAssignments
    @Published var playingTestSoundEffect: ScoreboardSoundEffect?
    @Published var isClockRunning = false
    @Published var isShotClockRunning = false
    @Published var didCompleteSetup = false
    @Published var setupPresets: [SetupPreset] = []

    private var timer: Timer?
    private var lastTimerFireDate: Date?
    private var accumulatedGameClockElapsed: TimeInterval = 0
    private var accumulatedShotClockElapsed: TimeInterval = 0
    private var accumulatedPenaltyElapsed: TimeInterval = 0
    private var accumulatedDebatePrepElapsed: TimeInterval = 0
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

    var isResetInterlockActive: Bool {
        isClockRunning ||
            isShotClockRunning ||
            isDebatePrepClockRunning ||
            homePenaltyTimers.contains(where: \.isRunning) ||
            guestPenaltyTimers.contains(where: \.isRunning)
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
            return "Segment"
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
                supportsHockeyPenalties: false,
                usesChessClocks: currentDebateSegment?.timerMode == .dualClock
            )
        }

        return selectedSport.rules(customConfig: customSportConfig)
    }

    var assignableSoundEventsForCurrentSport: [ScoreboardSoundEvent] {
        var events: [ScoreboardSoundEvent] = []

        if isDebateMode {
            if let timerMode = currentDebateSegment?.timerMode, timerMode != .none {
                events.append(.debateSegmentExpired)
                events.append(.gameClockStarted)
                events.append(.gameClockPaused)
                if timerMode == .dualClock {
                    events.append(.sideSwitched)
                }
            }
            if isDebatePrepTimeEnabled {
                events.append(.debatePrepExpired)
                events.append(.gameClockStarted)
                events.append(.gameClockPaused)
            }
            events.append(.periodChanged)
            if supportsScore {
                events.append(.scoreChanged)
            }
            if supportsPlayerTracking {
                events.append(.playerShown)
                events.append(.playerBenched)
                events.append(.playerOverlayShown)
                events.append(.playerOverlayPaused)
            }
            if supportsFouls {
                events.append(.playerFoulApplied)
            }
            if supportsCards {
                events.append(.yellowCardAssigned)
                events.append(.redCardAssigned)
            }
            return uniqueSoundEvents(events)
        }

        if usesChessClocks {
            events.append(.chessClockExpired)
            events.append(.gameClockStarted)
            events.append(.gameClockPaused)
            events.append(.sideSwitched)
        } else if currentRules.mainClockMode == .countdown {
            events.append(.gameClockExpired)
            events.append(.gameClockStarted)
            events.append(.gameClockPaused)
        } else if currentRules.mainClockMode == .countUp {
            events.append(.gameClockStarted)
            events.append(.gameClockPaused)
        }

        if supportsShotClock {
            events.append(.shotClockExpired)
            events.append(.shotClockStarted)
            events.append(.shotClockPaused)
            events.append(.shotClockReset)
        }

        if supportsScore {
            events.append(.scoreChanged)
        }

        if supportsPeriod {
            events.append(.periodChanged)
        }

        if supportsPossession {
            events.append(.possessionChanged)
        }

        if currentRules.showsSubstitutionTracking || showsSubstitutionTracking {
            events.append(.substitutionUsed)
        }

        if supportsTeamFouls {
            events.append(.teamFoulApplied)
        }

        if supportsPlayerTracking {
            events.append(.playerShown)
            events.append(.playerBenched)
            events.append(.playerOverlayShown)
            events.append(.playerOverlayPaused)
        }

        if supportsFouls {
            events.append(.playerFoulApplied)
        }

        if supportsCards {
            events.append(.yellowCardAssigned)
            events.append(.redCardAssigned)
        }

        if supportsHockeyPenalties {
            events.append(.hockeyPenaltyExpired)
            events.append(.hockeyPenaltyAdded)
            events.append(.hockeyPenaltyStarted)
            events.append(.hockeyPenaltyPaused)
        }

        events.append(.sideSwitched)
        return uniqueSoundEvents(events)
    }

    private func uniqueSoundEvents(_ events: [ScoreboardSoundEvent]) -> [ScoreboardSoundEvent] {
        var seen = Set<ScoreboardSoundEvent>()
        return events.filter { seen.insert($0).inserted }
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

    func sideRoleLabel(for side: TeamSide) -> String {
        guard isDebateMode else {
            return side.title
        }

        switch side {
        case .home:
            return debateHomeSideLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Side A" : debateHomeSideLabel
        case .guest:
            return debateGuestSideLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Side B" : debateGuestSideLabel
        }
    }

    func teamFouls(for side: TeamSide) -> Int {
        side == .home ? homeTeamFouls : guestTeamFouls
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
        guard supportsScore else {
            recordLog(
                kind: .scoreAdjustment,
                summary: "\(isHome ? TeamSide.home.title : TeamSide.guest.title) score \(delta >= 0 ? "+" : "")\(delta)",
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
            summary: "\(isHome ? TeamSide.home.title : TeamSide.guest.title) score \(delta >= 0 ? "+" : "")\(delta)",
            outcome: updatedScore == previousScore ? .ignored : .applied,
            teamSide: isHome ? .home : .guest,
            delta: delta,
            value: updatedScore
        )
        if updatedScore != previousScore {
            playSound(.scoreChanged)
        }
    }

    func adjustPeriod(by delta: Int) {
        guard supportsPeriod else {
            recordLog(
                kind: .periodAdjustment,
                summary: "\(delta >= 0 ? "Next" : "Previous") \(periodTitle)",
                outcome: .ignored,
                delta: delta
            )
            return
        }

        let previousPeriod = period
        period = max(1, min(9, period + delta))
        recordLog(
            kind: .periodAdjustment,
            summary: "\(delta >= 0 ? "Next" : "Previous") \(periodTitle)",
            outcome: period == previousPeriod ? .ignored : .applied,
            delta: delta,
            value: period
        )
        if period != previousPeriod {
            playSound(.periodChanged)
        }
    }

    func setPeriod(_ value: Int) {
        if supportsPeriod {
            period = max(1, min(9, value))
        } else {
            period = 1
        }
    }

    func adjustClock(by delta: Int) {
        if isDebateMode {
            guard currentDebateSegment?.timerMode == .masterClock else {
                recordLog(
                    kind: .debateTimerAdjustment,
                    summary: "Adjust debate timer",
                    outcome: .ignored,
                    delta: delta
                )
                return
            }
        }

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
        if isDebateMode {
            resetDebateCurrentSegment()
            return
        }

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
        if !isAuditLoggingSuspended {
            playSound(.shotClockReset)
        }
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
            summary: wasRunning ? "Pause game clock" : "Start game clock",
            outcome: wasRunning == isClockRunning ? .ignored : .applied
        )
        if wasRunning != isClockRunning {
            playSound(isClockRunning ? .gameClockStarted : .gameClockPaused)
        }
    }

    func toggleDebateSegmentClock() {
        guard isDebateMode else { return }
        guard let segment = currentDebateSegment, segment.timerMode != .none else {
            recordLog(
                kind: .debateTimerToggle,
                summary: "Toggle debate timer",
                outcome: .ignored,
                notes: debateSegmentTitle
            )
            return
        }
        isDebatePrepClockRunning = false
        debateActiveTimer = .segment
        let wasRunning = isClockRunning
        isClockRunning ? pauseClock() : startClock()
        recordLog(
            kind: .debateTimerToggle,
            summary: wasRunning ? "Pause debate timer" : "Start debate timer",
            outcome: wasRunning == isClockRunning ? .ignored : .applied,
            notes: segment.title
        )
        if wasRunning != isClockRunning {
            playSound(isClockRunning ? .gameClockStarted : .gameClockPaused)
        }
    }

    func setSoundEnabled(_ isEnabled: Bool) {
        isSoundEnabled = isEnabled

        if !isSoundEnabled {
            stopTestSound()
        }
    }

    func toggleSoundEnabled() {
        setSoundEnabled(!isSoundEnabled)
    }

    func selectedSoundEffect(for event: ScoreboardSoundEvent) -> ScoreboardSoundEffect {
        soundAssignments[event] ?? Self.defaultSoundAssignments[event] ?? .none
    }

    func setSoundEffect(_ effect: ScoreboardSoundEffect, for event: ScoreboardSoundEvent) {
        soundAssignments[event] = effect
    }

    func resetSoundSettingsToDefaults() {
        stopTestSound()
        isSoundEnabled = true
        soundAssignments = Self.defaultSoundAssignments
    }

    func playTestSound(_ event: ScoreboardSoundEvent) {
        toggleTestSound(selectedSoundEffect(for: event))
    }

    func playTestEffect(_ effect: ScoreboardSoundEffect) {
        toggleTestSound(effect)
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
            Task { @MainActor in
                guard self?.playingTestSoundEffect == finishedEffect else {
                    return
                }
                self?.playingTestSoundEffect = nil
            }
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
        if wasRunning != isShotClockRunning {
            playSound(isShotClockRunning ? .shotClockStarted : .shotClockPaused)
        }
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
            if previousDirection != direction {
                playSound(.possessionChanged)
            }
            return
        }

        guard autoStartShotClock, !isShotClockRunning else {
            recordLog(
                kind: .possessionChange,
                summary: "Set possession \(direction.displayName)",
                outcome: previousDirection == direction ? .ignored : .applied
            )
            if previousDirection != direction {
                playSound(.possessionChanged)
            }
            return
        }

        startShotClock()
        recordLog(
            kind: .possessionChange,
            summary: "Set possession \(direction.displayName)",
            outcome: .applied,
            notes: "Shot clock auto-started"
        )
        playSound(.possessionChanged)
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
            let wasRunning = isShotClockRunning
            isShotClockRunning ? pauseShotClock() : startShotClock()
            recordLog(
                kind: .shotClockAssignment,
                summary: "\(isShotClockRunning ? "Start" : "Pause") \(seconds)s shot clock for \(isHome ? TeamSide.home.title : TeamSide.guest.title)",
                outcome: .applied,
                teamSide: isHome ? .home : .guest,
                value: seconds
            )
            if wasRunning != isShotClockRunning {
                playSound(isShotClockRunning ? .shotClockStarted : .shotClockPaused)
            }
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
        playSound(.shotClockStarted)
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

        let resolvedTargetSeconds = activeShotClockPresetSeconds > 0 ? activeShotClockPresetSeconds : defaultShotClockSeconds
        let targetSeconds = boundedShotClockSeconds(resolvedTargetSeconds)
        let targetMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)

        isShotClockRunning = false
        accumulatedShotClockElapsed = 0
        activeShotClockPresetSeconds = targetSeconds
        shotClockMilliseconds = targetMilliseconds
        updateTimerState()
        recordLog(
            kind: .shotClockReset,
            summary: "Reset active shot clock",
            outcome: .applied,
            value: targetSeconds
        )
        playSound(.shotClockReset)
    }

    func newGame() {
        pauseClock()
        pauseShotClock()
        isDebatePrepClockRunning = false
        homeScore = 0
        guestScore = 0
        period = supportsPeriod ? 1 : period
        possessionDirection = .none
        activeShotClockPresetSeconds = defaultShotClockSeconds
        gameClockSeconds = defaultClockSeconds
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
    }

    func resetScores() {
        guard supportsScore else {
            recordLog(
                kind: .scoresReset,
                summary: "Zero both scores",
                outcome: .ignored
            )
            return
        }

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
        playSound(.sideSwitched)
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
            summary: isPlayerOverlayPaused ? "Pause public player overlay" : "Resume public player overlay",
            outcome: .applied
        )
        playSound(isPlayerOverlayPaused ? .playerOverlayPaused : .playerOverlayShown)
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
        if delta > 0, playerSummary?.foulCount != updatedPlayer?.foulCount {
            playSound(.playerFoulApplied)
        }
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
        if previousPlayer?.cardStatus != updatedPlayer?.cardStatus {
            switch status {
            case .yellow:
                playSound(.yellowCardAssigned)
            case .red:
                playSound(.redCardAssigned)
            case .none:
                break
            }
        }
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
        if delta > 0, teamFouls(for: side) != previousValue {
            playSound(.teamFoulApplied)
        }
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
            resolved.segments[index].durationSeconds = boundedGameClockSeconds(resolved.segments[index].durationSeconds)
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
            summary: logKind == .debatePresetChange ? "Apply debate preset" : "Reset debate round",
            outcome: .applied,
            notes: notes ?? currentDebatePreset.title
        )
    }

    func resetDebateCurrentSegment() {
        guard isDebateMode else { return }
        pauseClock()
        configureDebateSegment(index: debateCurrentSegmentIndex, preserveRunningState: false)
        recordLog(
            kind: .debateSegmentReset,
            summary: "Reset debate segment",
            outcome: .applied,
            notes: debateSegmentTitle
        )
    }

    func advanceDebateSegment(by delta: Int) {
        guard isDebateMode else { return }
        let previousIndex = debateCurrentSegmentIndex
        let boundedIndex = max(0, min(currentDebatePreset.segments.count - 1, debateCurrentSegmentIndex + delta))
        guard boundedIndex != previousIndex else {
            recordLog(
                kind: .debateSegmentChange,
                summary: delta >= 0 ? "Next debate segment" : "Previous debate segment",
                outcome: .ignored,
                notes: debateSegmentTitle
            )
            return
        }

        debateCurrentSegmentIndex = boundedIndex
        configureDebateSegment(index: boundedIndex, preserveRunningState: false)
        recordLog(
            kind: .debateSegmentChange,
            summary: delta >= 0 ? "Next debate segment" : "Previous debate segment",
            outcome: .applied,
            notes: debateSegmentTitle
        )
        playSound(.periodChanged)
    }

    func toggleDebatePrepClock(for side: TeamSide) {
        guard isDebateMode, isDebatePrepTimeEnabled else { return }
        let target: DebateActiveTimer = side == .home ? .prepHome : .prepGuest
        if debateActiveTimer != target {
            pauseClock()
            debateActiveTimer = target
            isDebatePrepClockRunning = false
        }
        let currentSeconds = side == .home ? debatePrepHomeSeconds : debatePrepGuestSeconds
        guard currentSeconds > 0 else {
            recordLog(
                kind: .debatePrepToggle,
                summary: "\(sideRoleLabel(for: side)) prep clock toggle",
                outcome: .ignored,
                teamSide: side
            )
            return
        }
        isDebatePrepClockRunning.toggle()
        updateTimerState()
        recordLog(
            kind: .debatePrepToggle,
            summary: "\(sideRoleLabel(for: side)) prep clock \(isDebatePrepClockRunning ? "start" : "pause")",
            outcome: .applied,
            teamSide: side,
            value: currentSeconds
        )
        playSound(isDebatePrepClockRunning ? .gameClockStarted : .gameClockPaused)
    }

    func returnToDebateSegmentTimer(resume: Bool = false) {
        guard isDebateMode else { return }

        let wasOnPrepTimer = debateActiveTimer != .segment
        debateActiveTimer = .segment
        isDebatePrepClockRunning = false

        if resume, currentDebateSegment?.timerMode != DebateTimerMode.none {
            startClock()
        } else {
            pauseClock()
        }

        recordLog(
            kind: .debateTimerToggle,
            summary: resume ? "Return to segment timer and resume" : "Return to segment timer",
            outcome: wasOnPrepTimer ? .applied : .ignored,
            notes: debateSegmentTitle
        )
        if wasOnPrepTimer {
            playSound(resume ? .gameClockStarted : .gameClockPaused)
        }
    }

    func resetDebatePrepClock(for side: TeamSide) {
        guard isDebateMode, isDebatePrepTimeEnabled else { return }
        let value = currentDebatePreset.prepSecondsPerSide
        switch side {
        case .home:
            debatePrepHomeSeconds = value
        case .guest:
            debatePrepGuestSeconds = value
        }
        if debateActiveTimer == (side == .home ? .prepHome : .prepGuest) {
            isDebatePrepClockRunning = false
            updateTimerState()
        }
        recordLog(
            kind: .debatePrepReset,
            summary: "Reset \(sideRoleLabel(for: side)) prep clock",
            outcome: .applied,
            teamSide: side,
            value: value
        )
    }

    func adjustDebatePrepClock(for side: TeamSide, by delta: Int) {
        guard isDebateMode, isDebatePrepTimeEnabled else { return }
        let previousValue = side == .home ? debatePrepHomeSeconds : debatePrepGuestSeconds
        switch side {
        case .home:
            debatePrepHomeSeconds = boundedGameClockSeconds(debatePrepHomeSeconds + delta)
        case .guest:
            debatePrepGuestSeconds = boundedGameClockSeconds(debatePrepGuestSeconds + delta)
        }
        let updatedValue = side == .home ? debatePrepHomeSeconds : debatePrepGuestSeconds
        recordLog(
            kind: .debatePrepAdjustment,
            summary: "\(sideRoleLabel(for: side)) prep \(delta >= 0 ? "+" : "")\(delta)s",
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
                summary: isDebateMode ? "Toggle debate timer" : "Toggle chess clock",
                outcome: .ignored
            )
            return
        }

        let wasRunning = isClockRunning
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
            summary: isDebateMode ? (wasRunning ? "Pause debate timer" : "Start debate timer") : (wasRunning ? "Pause chess clock" : "Start chess clock"),
            outcome: wasRunning == isClockRunning ? .ignored : .applied,
            teamSide: activeChessClockSide,
            notes: isDebateMode ? debateSegmentTitle : nil
        )
        if wasRunning != isClockRunning {
            playSound(isClockRunning ? .gameClockStarted : .gameClockPaused)
        }
    }

    func switchChessClock() {
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateActiveSideSwitch : .chessClockSwitch,
                summary: isDebateMode ? "Switch debate active side" : "Switch active chess clock",
                outcome: .ignored
            )
            return
        }

        let previousSide = activeChessClockSide
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
            summary: isDebateMode ? "Switch debate active side" : "Switch active chess clock",
            outcome: previousSide == activeChessClockSide ? .ignored : .applied,
            teamSide: activeChessClockSide,
            notes: isDebateMode ? debateSegmentTitle : nil
        )
        if previousSide != activeChessClockSide {
            playSound(.sideSwitched)
        }
    }

    func setActiveChessClockSide(_ side: TeamSide) {
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateActiveSideSet : .chessClockSwitch,
                summary: isDebateMode ? "Set debate active side to \(sideRoleLabel(for: side))" : "Set active chess clock to \(side.title)",
                outcome: .ignored,
                teamSide: side
            )
            return
        }

        let previousSide = activeChessClockSide
        activeChessClockSide = side
        recordLog(
            kind: isDebateMode ? .debateActiveSideSet : .chessClockSwitch,
            summary: isDebateMode ? "Set debate active side to \(sideRoleLabel(for: side))" : "Set active chess clock to \(side.title)",
            outcome: previousSide == side ? .ignored : .applied,
            teamSide: side,
            notes: isDebateMode ? debateSegmentTitle : nil
        )
        if previousSide != side {
            playSound(.sideSwitched)
        }
    }

    func adjustChessClock(for side: TeamSide, by delta: Int) {
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateTimerAdjustment : .chessClockAdjustment,
                summary: isDebateMode ? "\(sideRoleLabel(for: side)) debate clock \(delta >= 0 ? "+" : "")\(delta)s" : "\(side.title) chess clock \(delta >= 0 ? "+" : "")\(delta)s",
                outcome: .ignored,
                teamSide: side,
                delta: delta
            )
            return
        }

        let previousValue = side == .home ? homeChessClockSeconds : guestChessClockSeconds
        switch side {
        case .home:
            homeChessClockSeconds = boundedGameClockSeconds(homeChessClockSeconds + delta)
        case .guest:
            guestChessClockSeconds = boundedGameClockSeconds(guestChessClockSeconds + delta)
        }

        let updatedValue = side == .home ? homeChessClockSeconds : guestChessClockSeconds
        if updatedValue == 0, activeChessClockSide == side {
            pauseClock()
        }

        recordLog(
            kind: isDebateMode ? .debateTimerAdjustment : .chessClockAdjustment,
            summary: isDebateMode ? "\(sideRoleLabel(for: side)) debate clock \(delta >= 0 ? "+" : "")\(delta)s" : "\(side.title) chess clock \(delta >= 0 ? "+" : "")\(delta)s",
            outcome: previousValue == updatedValue ? .ignored : .applied,
            teamSide: side,
            delta: delta,
            value: updatedValue,
            notes: isDebateMode ? debateSegmentTitle : nil
        )
    }

    func resetChessClocks() {
        guard usesChessClocks else {
            recordLog(
                kind: isDebateMode ? .debateSegmentReset : .chessClockReset,
                summary: isDebateMode ? "Reset debate timer" : "Reset chess clocks",
                outcome: .ignored
            )
            return
        }

        pauseClock()
        let resetSeconds = boundedGameClockSeconds(defaultClockSeconds)
        homeChessClockSeconds = resetSeconds
        guestChessClockSeconds = usesChessClocks && selectedSport == .chess && defaultClockSeconds == 0
            ? chessClockPreset.seconds
            : resetSeconds
        activeChessClockSide = .home

        recordLog(
            kind: isDebateMode ? .debateSegmentReset : .chessClockReset,
            summary: isDebateMode ? "Reset debate timer" : "Reset chess clocks",
            outcome: .applied,
            notes: isDebateMode ? debateSegmentTitle : (selectedSport == .chess ? chessClockPreset.title : selectedSport.title)
        )
    }

    func addPenaltyTimer(for side: TeamSide, seconds: Int) {
        addPenaltyTimer(for: side, seconds: seconds, player: nil, startsRunning: false)
    }

    func addPenaltyTimer(for side: TeamSide, seconds: Int, player: TrackedPlayer?, startsRunning: Bool) {
        guard supportsHockeyPenalties else {
            recordLog(
                kind: .hockeyPenaltyAdd,
                summary: "Add \(side.title) penalty timer",
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
            summary: "Add \(side.title) penalty timer",
            outcome: .applied,
            teamSide: side,
            player: player,
            value: timer.remainingSeconds,
            notes: penaltySummaryItem(timer)
        )
        playSound(.hockeyPenaltyAdded)
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
            summary: "Remove \(side.title) penalty timer",
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
            summary: "\(side.title) penalty timer \(updated?.isRunning == true ? "start" : "pause")",
            outcome: previous?.isRunning == updated?.isRunning ? .ignored : .applied,
            teamSide: side,
            value: updated?.remainingSeconds
        )
        if previous?.isRunning != updated?.isRunning {
            playSound(updated?.isRunning == true ? .hockeyPenaltyStarted : .hockeyPenaltyPaused)
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
            summary: "\(side.title) penalty timer \(delta >= 0 ? "+" : "")\(delta)s",
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
            summary: "Edit \(side.title) penalty player",
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
            summary: "Edit \(side.title) penalty player",
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
            summary: "Assign \(side.title) penalty player",
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
    }

    func restoreRuntimeAfterSetupApply(
        clockWasRunning: Bool,
        shotClockWasRunning: Bool,
        debatePrepWasRunning: Bool
    ) {
        isClockRunning = clockWasRunning && (showsGameClock || usesChessClocks)
        isShotClockRunning = shotClockWasRunning && supportsShotClock
        isDebatePrepClockRunning = debatePrepWasRunning && isDebateMode && isDebatePrepTimeEnabled && debateActiveTimer != .segment
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
            possessionDirection = .none
            isShotClockRunning = false
            homeSubstitutionsAllowed = rules.defaultSubstitutionLimit
            guestSubstitutionsAllowed = rules.defaultSubstitutionLimit
            homeSubstitutionsUsed = 0
            guestSubstitutionsUsed = 0
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
            setRosterSizePerTeam(max(rules.defaultRosterSize, Self.minRosterSize))
            setDisplayLineupSize(max(1, rules.defaultDisplayLineupSize))
            if sport == .simple || sport == .debate {
                clearSubstitutionTracking()
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
            if !rules.supportsShotClock {
                defaultShotClockSeconds = 0
                activeShotClockPresetSeconds = 0
                shotClockMilliseconds = 0
                possessionDirection = .none
                isShotClockRunning = false
            }
            if sport == .simple || sport == .debate {
                clearSubstitutionTracking()
            }
            if sport == .debate {
                isPlayerTrackingEnabled = isDebatePlayerTrackingEnabled
            } else if !rules.supportsPlayerTracking {
                isPlayerTrackingEnabled = false
            }
        }
    }

    private func clearSubstitutionTracking() {
        homeSubstitutionsAllowed = 0
        guestSubstitutionsAllowed = 0
        homeSubstitutionsUsed = 0
        guestSubstitutionsUsed = 0
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
        if delta > 0, substitutionsUsed(for: side) != previousValue {
            playSound(.substitutionUsed)
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
            summary: "\(isActive ? "Show" : "Bench") \(side.title) player",
            outcome: previousPlayer?.isInActiveLineup == updatedPlayer?.isInActiveLineup ? .ignored : .applied,
            teamSide: side,
            player: updatedPlayer ?? previousPlayer,
            notes: updatedPlayer?.isInActiveLineup == true ? "Active lineup" : "Bench"
        )
        if previousPlayer?.isInActiveLineup != updatedPlayer?.isInActiveLineup {
            playSound(updatedPlayer?.isInActiveLineup == true ? .playerShown : .playerBenched)
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
            defaultClockSeconds = boundedGameClockSeconds(segment.durationSeconds)
            gameClockSeconds = defaultClockSeconds
            activeChessClockSide = nil
        case .dualClock:
            defaultClockSeconds = boundedGameClockSeconds(segment.durationSeconds)
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
            fileVersion: 7,
            sport: selectedSport,
            customSportConfig: customSportConfig,
            customDebatePreset: customDebatePreset,
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
            homePenaltyTimers: homePenaltyTimers,
            guestPenaltyTimers: guestPenaltyTimers,
            homeRoster: homeRoster,
            guestRoster: guestRoster
        )
    }

    func applyGameSnapshot(_ snapshot: ScoreboardGameSnapshot) {
        performWithoutAuditLogging {
            pauseClock()
            pauseShotClock()

            customSportConfig = snapshot.customSportConfig ?? .default
            customDebatePreset = snapshot.customDebatePreset ?? .customDefault
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
            isPlayerTrackingEnabled = currentRules.supportsPlayerTracking ? (snapshot.isPlayerTrackingEnabled ?? false) : false
            isPlayerOverlayPaused = snapshot.isPlayerOverlayPaused ?? false
            rosterSizePerTeam = max(Self.minRosterSize, min(Self.maxRosterSize, snapshot.rosterSizePerTeam ?? Self.defaultRosterSize))
            displayLineupSize = max(1, min(rosterSizePerTeam, snapshot.displayLineupSize ?? Self.defaultDisplayLineupSize))
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
            homeTeamFouls = max(0, snapshot.homeTeamFouls ?? 0)
            guestTeamFouls = max(0, snapshot.guestTeamFouls ?? 0)
            let defaultDualClockSeconds = boundedGameClockSeconds(snapshot.defaultClockSeconds)
            homeChessClockSeconds = boundedGameClockSeconds(snapshot.homeChessClockSeconds ?? defaultDualClockSeconds)
            guestChessClockSeconds = boundedGameClockSeconds(snapshot.guestChessClockSeconds ?? defaultDualClockSeconds)
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
            homePenaltyTimers = snapshot.homePenaltyTimers ?? []
            guestPenaltyTimers = snapshot.guestPenaltyTimers ?? []
            homeRoster = normalizedRoster(snapshot.homeRoster, fallbackCount: rosterSizePerTeam)
            guestRoster = normalizedRoster(snapshot.guestRoster, fallbackCount: rosterSizePerTeam)
            if isDebateMode {
                let preset = currentDebatePreset
                debateCurrentSegmentIndex = min(debateCurrentSegmentIndex, max(preset.segments.count - 1, 0))
                configureDebateSegment(index: debateCurrentSegmentIndex, preserveRunningState: true)
                switch currentDebateSegment?.timerMode {
                case .masterClock:
                    gameClockSeconds = boundedGameClockSeconds(snapshot.gameClockSeconds)
                case .dualClock:
                    homeChessClockSeconds = boundedGameClockSeconds(snapshot.homeChessClockSeconds ?? defaultDualClockSeconds)
                    guestChessClockSeconds = boundedGameClockSeconds(snapshot.guestChessClockSeconds ?? defaultDualClockSeconds)
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
            return
        }

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
                let now = Date()
                let elapsed = now.timeIntervalSince(self.lastTimerFireDate ?? now)
                self.lastTimerFireDate = now
                self.tick(elapsed: elapsed)
            }
        }
    }

    private func tick(elapsed: TimeInterval) {
        var soundEvents: [ScoreboardSoundEvent] = []

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
                            isClockRunning = false
                            accumulatedGameClockElapsed = 0
                            soundEvents.append(isDebateMode ? .debateSegmentExpired : .chessClockExpired)
                        }
                    case .guest:
                        guestChessClockSeconds = max(0, guestChessClockSeconds - elapsedWholeSeconds)
                        if guestChessClockSeconds == 0 {
                            isClockRunning = false
                            accumulatedGameClockElapsed = 0
                            soundEvents.append(isDebateMode ? .debateSegmentExpired : .chessClockExpired)
                        }
                    case .none:
                        isClockRunning = false
                    }
                } else {
                    switch gameClockMode {
                    case .countdown:
                        gameClockSeconds = max(0, gameClockSeconds - elapsedWholeSeconds)

                        if gameClockSeconds == 0 {
                            isClockRunning = false
                            accumulatedGameClockElapsed = 0
                            soundEvents.append(isDebateMode ? .debateSegmentExpired : .gameClockExpired)
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
                        summary: "Shot clock expired",
                        outcome: .applied,
                        value: 0
                    )
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
                        soundEvents.append(.debatePrepExpired)
                    }
                case .prepGuest:
                    debatePrepGuestSeconds = max(0, debatePrepGuestSeconds - elapsedPrepSeconds)
                    if debatePrepGuestSeconds == 0 {
                        isDebatePrepClockRunning = false
                        soundEvents.append(.debatePrepExpired)
                    }
                case .segment:
                    isDebatePrepClockRunning = false
                }
            }
        }

        updateTimerState()

        if let soundEvent = highestPrioritySoundEvent(from: soundEvents) {
            playSound(soundEvent)
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

    private func penaltyTimers(for side: TeamSide) -> [HockeyPenaltyTimer] {
        switch side {
        case .home:
            return homePenaltyTimers
        case .guest:
            return guestPenaltyTimers
        }
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

    private func playSound(_ event: ScoreboardSoundEvent) {
        guard isSoundEnabled else {
            return
        }

        if playingTestSoundEffect != nil {
            stopTestSound()
        }
        buzzerPlayer.play(resolvedSoundEffect(for: event))
    }

    private func resolvedSoundEffect(for event: ScoreboardSoundEvent) -> ScoreboardSoundEffect {
        selectedSoundEffect(for: event)
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

    private func configurePersistence() {
        let persistencePublishers: [AnyPublisher<Void, Never>] = [
            $selectedSport.map { _ in () }.eraseToAnyPublisher(),
            $customSportConfig.map { _ in () }.eraseToAnyPublisher(),
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
            $externalDisplayBackgroundMode.map { _ in () }.eraseToAnyPublisher(),
            $isSoundEnabled.map { _ in () }.eraseToAnyPublisher(),
            $soundAssignments.map { _ in () }.eraseToAnyPublisher(),
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
        customSportConfig = persistedState.customSportConfig
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
        possessionDirection = currentRules.supportsPossession ? persistedState.possessionDirection : .none
        areSidesSwapped = persistedState.areSidesSwapped
        isPlayerTrackingEnabled = selectedSport == .debate
            ? persistedState.isDebatePlayerTrackingEnabled
            : (currentRules.supportsPlayerTracking ? persistedState.isPlayerTrackingEnabled : false)
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
        homeChessClockSeconds = boundedGameClockSeconds(persistedState.homeChessClockSeconds)
        guestChessClockSeconds = boundedGameClockSeconds(persistedState.guestChessClockSeconds)
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
        homePenaltyTimers = persistedState.homePenaltyTimers
        guestPenaltyTimers = persistedState.guestPenaltyTimers
        homeRoster = normalizedRoster(persistedState.homeRoster, fallbackCount: rosterSizePerTeam)
        guestRoster = normalizedRoster(persistedState.guestRoster, fallbackCount: rosterSizePerTeam)
        theme = persistedState.theme
        externalDisplayBackgroundMode = persistedState.externalDisplayBackgroundMode
        isSoundEnabled = persistedState.isSoundEnabled
        soundAssignments = normalizedSoundAssignments(persistedState.soundAssignments)
        didCompleteSetup = persistedState.didCompleteSetup
        setupPresets = persistedState.setupPresets
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
    }

    private func persistState() {
        let persistedState = PersistedState(
            selectedSport: selectedSport,
            customSportConfig: customSportConfig,
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
            homePenaltyTimers: homePenaltyTimers,
            guestPenaltyTimers: guestPenaltyTimers,
            homeRoster: homeRoster,
            guestRoster: guestRoster,
            theme: theme,
            externalDisplayBackgroundMode: externalDisplayBackgroundMode,
            isSoundEnabled: isSoundEnabled,
            soundAssignments: soundAssignments,
            didCompleteSetup: didCompleteSetup,
            setupPresets: setupPresets
        )

        guard let data = try? JSONEncoder().encode(persistedState) else {
            return
        }

        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func normalizedSoundAssignments(_ assignments: [ScoreboardSoundEvent: ScoreboardSoundEffect]) -> [ScoreboardSoundEvent: ScoreboardSoundEffect] {
        var resolved = Self.defaultSoundAssignments
        for (event, effect) in assignments {
            guard event != .general else { continue }
            resolved[event] = effect
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
    var customSportConfig: CustomSportConfig
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
    var externalDisplayBackgroundMode: ExternalDisplayBackgroundMode
    var isSoundEnabled: Bool
    var soundAssignments: [ScoreboardSoundEvent: ScoreboardSoundEffect]
    var didCompleteSetup: Bool
    var setupPresets: [SetupPreset]

    private enum CodingKeys: String, CodingKey {
        case homeTeamName
        case selectedSport
        case customSportConfig
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
        case externalDisplayBackgroundMode
        case isSoundEnabled
        case soundAssignments
        case didCompleteSetup
        case setupPresets
    }

    init(
        selectedSport: SportType,
        customSportConfig: CustomSportConfig,
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
        externalDisplayBackgroundMode: ExternalDisplayBackgroundMode,
        isSoundEnabled: Bool,
        soundAssignments: [ScoreboardSoundEvent: ScoreboardSoundEffect],
        didCompleteSetup: Bool,
        setupPresets: [SetupPreset]
    ) {
        self.selectedSport = selectedSport
        self.customSportConfig = customSportConfig
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
        self.externalDisplayBackgroundMode = externalDisplayBackgroundMode
        self.isSoundEnabled = isSoundEnabled
        self.soundAssignments = soundAssignments
        self.didCompleteSetup = didCompleteSetup
        self.setupPresets = setupPresets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedSport = try container.decodeIfPresent(SportType.self, forKey: .selectedSport) ?? .basketball
        customSportConfig = try container.decodeIfPresent(CustomSportConfig.self, forKey: .customSportConfig) ?? .default
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
        externalDisplayBackgroundMode = try container.decodeIfPresent(ExternalDisplayBackgroundMode.self, forKey: .externalDisplayBackgroundMode) ?? .blurred
        isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        soundAssignments = try container.decodeIfPresent([ScoreboardSoundEvent: ScoreboardSoundEffect].self, forKey: .soundAssignments) ?? ScoreboardStore.defaultSoundAssignments
        didCompleteSetup = try container.decode(Bool.self, forKey: .didCompleteSetup)
        setupPresets = try container.decode([SetupPreset].self, forKey: .setupPresets)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedSport, forKey: .selectedSport)
        try container.encode(customSportConfig, forKey: .customSportConfig)
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
        try container.encode(externalDisplayBackgroundMode, forKey: .externalDisplayBackgroundMode)
        try container.encode(isSoundEnabled, forKey: .isSoundEnabled)
        try container.encode(soundAssignments, forKey: .soundAssignments)
        try container.encode(didCompleteSetup, forKey: .didCompleteSetup)
        try container.encode(setupPresets, forKey: .setupPresets)
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
