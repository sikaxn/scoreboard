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

struct TrackedPlayer: Identifiable, Codable, Equatable {
    let id: UUID
    var number: String
    var name: String
    var foulCount: Int
    var isInActiveLineup: Bool

    init(
        id: UUID = UUID(),
        number: String,
        name: String = "",
        foulCount: Int = 0,
        isInActiveLineup: Bool = false
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.foulCount = foulCount
        self.isInActiveLineup = isInActiveLineup
    }
}

struct TeamRoster: Codable, Equatable {
    var players: [TrackedPlayer]
}

struct SetupPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var homeTeamName: String
    var guestTeamName: String
    var period: Int
    var clockSeconds: Int
    var shotClockSeconds: Int
    var possessionDirection: PossessionDirection

    init(
        id: UUID = UUID(),
        name: String,
        homeTeamName: String,
        guestTeamName: String,
        period: Int,
        clockSeconds: Int,
        shotClockSeconds: Int = 24,
        possessionDirection: PossessionDirection = .none
    ) {
        self.id = id
        self.name = name
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

    @Published var homeTeamName = ""
    @Published var guestTeamName = ""
    @Published var homeScore = 0
    @Published var guestScore = 0
    @Published var period = 1
    @Published var gameClockSeconds = 12 * 60
    @Published var defaultClockSeconds = 12 * 60
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
    private let persistenceKey = "smartScoreboard.persistedState"
    private let buzzerPlayer = BuzzerPlayer()

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
        isClockRunning
    }

    var displayedHomePlayers: [TrackedPlayer] {
        activeLineupPlayers(for: .home)
    }

    var displayedGuestPlayers: [TrackedPlayer] {
        activeLineupPlayers(for: .guest)
    }

    var isDisplayGameClockAlertActive: Bool {
        isGameClockRedEnabled && gameClockSeconds <= boundedGameClockSeconds(gameClockRedThresholdSeconds)
    }

    var isDisplayShotClockAlertActive: Bool {
        isShotClockRedEnabled && shotClockMilliseconds <= boundedShotClockMilliseconds(shotClockRedThresholdSeconds * 1_000)
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
        if isHome {
            homeScore = max(0, homeScore + delta)
        } else {
            guestScore = max(0, guestScore + delta)
        }
    }

    func adjustPeriod(by delta: Int) {
        period = max(1, min(9, period + delta))
    }

    func setPeriod(_ value: Int) {
        period = max(1, min(9, value))
    }

    func adjustClock(by delta: Int) {
        gameClockSeconds = boundedGameClockSeconds(gameClockSeconds + delta)
        if gameClockSeconds == 0 {
            pauseClock()
        }
    }

    func adjustShotClock(by delta: Int) {
        shotClockMilliseconds = boundedShotClockMilliseconds(shotClockMilliseconds + (delta * 1_000))
        if shotClockMilliseconds == 0 {
            pauseShotClock()
        }
    }

    func resetClock(to seconds: Int? = nil) {
        guard !isGameClockInterlockActive else {
            return
        }

        pauseClock()
        gameClockSeconds = boundedGameClockSeconds(seconds ?? defaultClockSeconds)
    }

    func resetShotClock(to seconds: Int? = nil) {
        pauseShotClock()
        let targetSeconds = boundedShotClockSeconds(seconds ?? defaultShotClockSeconds)
        activeShotClockPresetSeconds = targetSeconds
        shotClockMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)
    }

    func toggleClock() {
        isClockRunning ? pauseClock() : startClock()
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
        isShotClockRunning ? pauseShotClock() : startShotClock()
    }

    func setPossessionDirection(_ direction: PossessionDirection, autoStartShotClock: Bool = false) {
        possessionDirection = direction

        if direction == .none {
            resetShotClock()
            return
        }

        guard autoStartShotClock, !isShotClockRunning else {
            return
        }

        startShotClock()
    }

    func assignShotClock(to seconds: Int, forHomeTeam isHome: Bool) {
        let targetDirection: PossessionDirection = isHome ? .home : .guest
        let targetSeconds = boundedShotClockSeconds(seconds)
        let targetMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)
        let isSameSelection = possessionDirection == targetDirection && activeShotClockPresetSeconds == targetSeconds

        if isSameSelection {
            isShotClockRunning ? pauseShotClock() : startShotClock()
            return
        }

        possessionDirection = targetDirection
        activeShotClockPresetSeconds = targetSeconds
        shotClockMilliseconds = targetMilliseconds
        startShotClock()
    }

    func resetActiveShotClock() {
        let targetSeconds = boundedShotClockSeconds(activeShotClockPresetSeconds)
        let targetMilliseconds = boundedShotClockMilliseconds(targetSeconds * 1_000)

        shotClockMilliseconds = targetMilliseconds
        possessionDirection = .none

        pauseShotClock()
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
        isPlayerOverlayPaused = false
        resetPlayerTrackingForNewGame()
    }

    func resetScores() {
        guard !isGameClockInterlockActive else {
            return
        }

        homeScore = 0
        guestScore = 0
    }

    func swapSides() {
        areSidesSwapped.toggle()
    }

    func setPlayerTrackingEnabled(_ isEnabled: Bool) {
        isPlayerTrackingEnabled = isEnabled
    }

    func togglePlayerOverlayPaused() {
        isPlayerOverlayPaused.toggle()
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
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].foulCount = max(0, roster.players[index].foulCount + delta)
        }
    }

    func resetFouls(for side: TeamSide, playerID: UUID) {
        updateRoster(for: side) { roster in
            guard let index = roster.players.firstIndex(where: { $0.id == playerID }) else {
                return
            }

            roster.players[index].foulCount = 0
        }
    }

    func resetFouls(for side: TeamSide) {
        updateRoster(for: side) { roster in
            for index in roster.players.indices {
                roster.players[index].foulCount = 0
            }
        }
    }

    func resetAllPlayerFouls() {
        resetFouls(for: .home)
        resetFouls(for: .guest)
    }

    func setPlayerActiveLineup(_ isActive: Bool, for side: TeamSide, playerID: UUID) {
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
    }

    func currentGameSnapshot() -> ScoreboardGameSnapshot {
        ScoreboardGameSnapshot(
            fileVersion: 3,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            homeScore: homeScore,
            guestScore: guestScore,
            period: period,
            gameClockSeconds: gameClockSeconds,
            defaultClockSeconds: defaultClockSeconds,
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
            homeRoster: homeRoster,
            guestRoster: guestRoster
        )
    }

    func applyGameSnapshot(_ snapshot: ScoreboardGameSnapshot) {
        pauseClock()
        pauseShotClock()

        homeTeamName = normalizedTeamName(snapshot.homeTeamName)
        guestTeamName = normalizedTeamName(snapshot.guestTeamName)
        homeScore = max(0, snapshot.homeScore)
        guestScore = max(0, snapshot.guestScore)
        period = max(1, min(9, snapshot.period))
        gameClockSeconds = boundedGameClockSeconds(snapshot.gameClockSeconds)
        defaultClockSeconds = boundedGameClockSeconds(snapshot.defaultClockSeconds)
        shotClockMilliseconds = boundedShotClockMilliseconds(snapshot.shotClockMilliseconds)
        defaultShotClockSeconds = boundedShotClockSeconds(snapshot.defaultShotClockSeconds)
        activeShotClockPresetSeconds = boundedShotClockSeconds(snapshot.activeShotClockPresetSeconds ?? snapshot.defaultShotClockSeconds)
        possessionDirection = snapshot.possessionDirection
        areSidesSwapped = snapshot.areSidesSwapped
        isPlayerTrackingEnabled = snapshot.isPlayerTrackingEnabled ?? false
        isPlayerOverlayPaused = snapshot.isPlayerOverlayPaused ?? false
        rosterSizePerTeam = max(Self.minRosterSize, min(Self.maxRosterSize, snapshot.rosterSizePerTeam ?? Self.defaultRosterSize))
        displayLineupSize = max(1, min(rosterSizePerTeam, snapshot.displayLineupSize ?? Self.defaultDisplayLineupSize))
        playerFoulHighlightColor = snapshot.playerFoulHighlightColor ?? .yellow
        isGameClockRedEnabled = snapshot.isGameClockRedEnabled ?? false
        gameClockRedThresholdSeconds = boundedGameClockSeconds(snapshot.gameClockRedThresholdSeconds ?? 60)
        isShotClockRedEnabled = snapshot.isShotClockRedEnabled ?? false
        shotClockRedThresholdSeconds = boundedShotClockSeconds(snapshot.shotClockRedThresholdSeconds ?? 5)
        homeRoster = normalizedRoster(snapshot.homeRoster, fallbackCount: rosterSizePerTeam)
        guestRoster = normalizedRoster(snapshot.guestRoster, fallbackCount: rosterSizePerTeam)
        didCompleteSetup = true
    }

    func applySetup(
        homeName: String,
        guestName: String,
        period: Int,
        clockSeconds: Int,
        shotClockSeconds: Int
    ) {
        updateTeamName(homeName, isHome: true)
        updateTeamName(guestName, isHome: false)
        homeScore = 0
        guestScore = 0
        setPeriod(period)
        defaultClockSeconds = boundedGameClockSeconds(clockSeconds)
        defaultShotClockSeconds = boundedShotClockSeconds(shotClockSeconds)
        activeShotClockPresetSeconds = defaultShotClockSeconds
        possessionDirection = .none
        areSidesSwapped = false
        isPlayerOverlayPaused = false
        resetPlayerTrackingForNewGame()
        didCompleteSetup = true
        resetClock(to: defaultClockSeconds)
        resetShotClock(to: defaultShotClockSeconds)
    }

    func savePreset(
        named name: String,
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
        if gameClockSeconds == 0 {
            gameClockSeconds = defaultClockSeconds
        }

        guard gameClockSeconds > 0 else {
            return
        }

        isClockRunning = true
        updateTimerState()
    }

    private func pauseClock() {
        isClockRunning = false
        updateTimerState()
    }

    private func startShotClock() {
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
                gameClockSeconds = max(0, gameClockSeconds - elapsedWholeSeconds)

                if gameClockSeconds == 0 {
                    isClockRunning = false
                    accumulatedGameClockElapsed = 0
                    shouldPlayBuzzer = true
                }
            }
        }

        if isShotClockRunning {
            accumulatedShotClockElapsed += elapsed
            let elapsedMilliseconds = Int(accumulatedShotClockElapsed * 1_000)

            if elapsedMilliseconds > 0 {
                accumulatedShotClockElapsed -= TimeInterval(elapsedMilliseconds) / 1_000
                shotClockMilliseconds = max(0, shotClockMilliseconds - elapsedMilliseconds)

                if shotClockMilliseconds == 0 {
                    isShotClockRunning = false
                    accumulatedShotClockElapsed = 0
                    shouldPlayBuzzer = true
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

    private func configurePersistence() {
        let persistencePublishers: [AnyPublisher<Void, Never>] = [
            $homeTeamName.map { _ in () }.eraseToAnyPublisher(),
            $guestTeamName.map { _ in () }.eraseToAnyPublisher(),
            $homeScore.map { _ in () }.eraseToAnyPublisher(),
            $guestScore.map { _ in () }.eraseToAnyPublisher(),
            $period.map { _ in () }.eraseToAnyPublisher(),
            $gameClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $defaultClockSeconds.map { _ in () }.eraseToAnyPublisher(),
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

        homeTeamName = persistedState.homeTeamName
        guestTeamName = persistedState.guestTeamName
        homeScore = persistedState.homeScore
        guestScore = persistedState.guestScore
        period = max(1, min(9, persistedState.period))
        gameClockSeconds = boundedGameClockSeconds(persistedState.gameClockSeconds)
        defaultClockSeconds = boundedGameClockSeconds(persistedState.defaultClockSeconds)
        shotClockMilliseconds = boundedShotClockMilliseconds(persistedState.shotClockMilliseconds)
        defaultShotClockSeconds = boundedShotClockSeconds(persistedState.defaultShotClockSeconds)
        activeShotClockPresetSeconds = boundedShotClockSeconds(persistedState.activeShotClockPresetSeconds)
        possessionDirection = persistedState.possessionDirection
        areSidesSwapped = persistedState.areSidesSwapped
        isPlayerTrackingEnabled = persistedState.isPlayerTrackingEnabled
        isPlayerOverlayPaused = persistedState.isPlayerOverlayPaused
        rosterSizePerTeam = max(Self.minRosterSize, min(Self.maxRosterSize, persistedState.rosterSizePerTeam))
        displayLineupSize = max(1, min(rosterSizePerTeam, persistedState.displayLineupSize))
        playerFoulHighlightColor = persistedState.playerFoulHighlightColor
        isGameClockRedEnabled = persistedState.isGameClockRedEnabled
        gameClockRedThresholdSeconds = boundedGameClockSeconds(persistedState.gameClockRedThresholdSeconds)
        isShotClockRedEnabled = persistedState.isShotClockRedEnabled
        shotClockRedThresholdSeconds = boundedShotClockSeconds(persistedState.shotClockRedThresholdSeconds)
        homeRoster = normalizedRoster(persistedState.homeRoster, fallbackCount: rosterSizePerTeam)
        guestRoster = normalizedRoster(persistedState.guestRoster, fallbackCount: rosterSizePerTeam)
        theme = persistedState.theme
        externalDisplayBackgroundMode = persistedState.externalDisplayBackgroundMode
        isSoundEnabled = persistedState.isSoundEnabled
        didCompleteSetup = persistedState.didCompleteSetup
        setupPresets = persistedState.setupPresets
        isClockRunning = false
        isShotClockRunning = false
    }

    private func persistState() {
        let persistedState = PersistedState(
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            homeScore: homeScore,
            guestScore: guestScore,
            period: period,
            gameClockSeconds: gameClockSeconds,
            defaultClockSeconds: defaultClockSeconds,
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
    var homeTeamName: String
    var guestTeamName: String
    var homeScore: Int
    var guestScore: Int
    var period: Int
    var gameClockSeconds: Int
    var defaultClockSeconds: Int
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
    var homeRoster: TeamRoster
    var guestRoster: TeamRoster
    var theme: ScoreboardTheme
    var externalDisplayBackgroundMode: ExternalDisplayBackgroundMode
    var isSoundEnabled: Bool
    var didCompleteSetup: Bool
    var setupPresets: [SetupPreset]

    private enum CodingKeys: String, CodingKey {
        case homeTeamName
        case guestTeamName
        case homeScore
        case guestScore
        case period
        case gameClockSeconds
        case defaultClockSeconds
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
        case homeRoster
        case guestRoster
        case theme
        case externalDisplayBackgroundMode
        case isSoundEnabled
        case didCompleteSetup
        case setupPresets
    }

    init(
        homeTeamName: String,
        guestTeamName: String,
        homeScore: Int,
        guestScore: Int,
        period: Int,
        gameClockSeconds: Int,
        defaultClockSeconds: Int,
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
        homeRoster: TeamRoster,
        guestRoster: TeamRoster,
        theme: ScoreboardTheme,
        externalDisplayBackgroundMode: ExternalDisplayBackgroundMode,
        isSoundEnabled: Bool,
        didCompleteSetup: Bool,
        setupPresets: [SetupPreset]
    ) {
        self.homeTeamName = homeTeamName
        self.guestTeamName = guestTeamName
        self.homeScore = homeScore
        self.guestScore = guestScore
        self.period = period
        self.gameClockSeconds = gameClockSeconds
        self.defaultClockSeconds = defaultClockSeconds
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
        homeTeamName = try container.decode(String.self, forKey: .homeTeamName)
        guestTeamName = try container.decode(String.self, forKey: .guestTeamName)
        homeScore = try container.decode(Int.self, forKey: .homeScore)
        guestScore = try container.decode(Int.self, forKey: .guestScore)
        period = try container.decode(Int.self, forKey: .period)
        gameClockSeconds = try container.decode(Int.self, forKey: .gameClockSeconds)
        defaultClockSeconds = try container.decode(Int.self, forKey: .defaultClockSeconds)
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
        try container.encode(homeTeamName, forKey: .homeTeamName)
        try container.encode(guestTeamName, forKey: .guestTeamName)
        try container.encode(homeScore, forKey: .homeScore)
        try container.encode(guestScore, forKey: .guestScore)
        try container.encode(period, forKey: .period)
        try container.encode(gameClockSeconds, forKey: .gameClockSeconds)
        try container.encode(defaultClockSeconds, forKey: .defaultClockSeconds)
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
