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
    static let maxGameClockSeconds = 59 * 60 + 59
    static let maxShotClockSeconds = 99
    static let maxShotClockMilliseconds = maxShotClockSeconds * 1_000

    @Published var homeTeamName = ""
    @Published var guestTeamName = ""
    @Published var homeScore = 0
    @Published var guestScore = 0
    @Published var period = 1
    @Published var gameClockSeconds = 12 * 60
    @Published var defaultClockSeconds = 12 * 60
    @Published var shotClockMilliseconds = 24_000
    @Published var defaultShotClockSeconds = 24
    @Published var possessionDirection: PossessionDirection = .none
    @Published var areSidesSwapped = false
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

    static func formatGameClock(_ totalSeconds: Int) -> String {
        let boundedSeconds = max(0, min(maxGameClockSeconds, totalSeconds))
        let minutes = boundedSeconds / 60
        let seconds = boundedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func formatShotClock(_ totalSeconds: Int) -> String {
        formatShotClock(milliseconds: totalSeconds * 1_000)
    }

    static func formatShotClock(milliseconds totalMilliseconds: Int) -> String {
        let boundedMilliseconds = max(0, min(maxShotClockMilliseconds, totalMilliseconds))
        return String(format: "%.1f", Double(boundedMilliseconds) / 1_000)
    }

    func updateTeamName(_ name: String, isHome: Bool) {
        let resolvedName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if isHome {
            homeTeamName = resolvedName
        } else {
            guestTeamName = resolvedName
        }
    }

    func adjustScore(isHome: Bool, by delta: Int) {
        guard !isGameClockInterlockActive else {
            return
        }

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
        if let seconds, isGameClockInterlockActive, [14, 24].contains(seconds) {
            return
        }

        pauseShotClock()
        shotClockMilliseconds = boundedShotClockMilliseconds((seconds ?? defaultShotClockSeconds) * 1_000)
    }

    func toggleClock() {
        isClockRunning ? pauseClock() : startClock()
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

    func newGame() {
        pauseClock()
        pauseShotClock()
        homeScore = 0
        guestScore = 0
        period = 1
        possessionDirection = .none
        gameClockSeconds = defaultClockSeconds
        shotClockMilliseconds = defaultShotClockSeconds * 1_000
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

    func currentGameSnapshot() -> ScoreboardGameSnapshot {
        ScoreboardGameSnapshot(
            fileVersion: 2,
            homeTeamName: homeTeamName,
            guestTeamName: guestTeamName,
            homeScore: homeScore,
            guestScore: guestScore,
            period: period,
            gameClockSeconds: gameClockSeconds,
            defaultClockSeconds: defaultClockSeconds,
            shotClockMilliseconds: shotClockMilliseconds,
            defaultShotClockSeconds: defaultShotClockSeconds,
            possessionDirection: possessionDirection,
            areSidesSwapped: areSidesSwapped
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
        possessionDirection = snapshot.possessionDirection
        areSidesSwapped = snapshot.areSidesSwapped
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
        possessionDirection = .none
        areSidesSwapped = false
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
        if isClockRunning {
            accumulatedGameClockElapsed += elapsed
            let elapsedWholeSeconds = Int(accumulatedGameClockElapsed)

            if elapsedWholeSeconds > 0 {
                accumulatedGameClockElapsed -= TimeInterval(elapsedWholeSeconds)
                gameClockSeconds = max(0, gameClockSeconds - elapsedWholeSeconds)

                if gameClockSeconds == 0 {
                    isClockRunning = false
                    accumulatedGameClockElapsed = 0
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
                }
            }
        }

        updateTimerState()
    }

    deinit {
        timer?.invalidate()
    }

    private func normalizedTeamName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
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

    private func configurePersistence() {
        Publishers.MergeMany(
            $homeTeamName.map { _ in () }.eraseToAnyPublisher(),
            $guestTeamName.map { _ in () }.eraseToAnyPublisher(),
            $homeScore.map { _ in () }.eraseToAnyPublisher(),
            $guestScore.map { _ in () }.eraseToAnyPublisher(),
            $period.map { _ in () }.eraseToAnyPublisher(),
            $gameClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $defaultClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $shotClockMilliseconds.map { _ in () }.eraseToAnyPublisher(),
            $defaultShotClockSeconds.map { _ in () }.eraseToAnyPublisher(),
            $possessionDirection.map { _ in () }.eraseToAnyPublisher(),
            $areSidesSwapped.map { _ in () }.eraseToAnyPublisher(),
            $isClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $isShotClockRunning.map { _ in () }.eraseToAnyPublisher(),
            $didCompleteSetup.map { _ in () }.eraseToAnyPublisher(),
            $setupPresets.map { _ in () }.eraseToAnyPublisher()
        )
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
        possessionDirection = persistedState.possessionDirection
        areSidesSwapped = persistedState.areSidesSwapped
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
            possessionDirection: possessionDirection,
            areSidesSwapped: areSidesSwapped,
            didCompleteSetup: didCompleteSetup,
            setupPresets: setupPresets
        )

        guard let data = try? JSONEncoder().encode(persistedState) else {
            return
        }

        UserDefaults.standard.set(data, forKey: persistenceKey)
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
    var possessionDirection: PossessionDirection
    var areSidesSwapped: Bool
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
        case possessionDirection
        case areSidesSwapped
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
        possessionDirection: PossessionDirection,
        areSidesSwapped: Bool,
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
        self.possessionDirection = possessionDirection
        self.areSidesSwapped = areSidesSwapped
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
        possessionDirection = try container.decodeIfPresent(PossessionDirection.self, forKey: .possessionDirection) ?? .none
        areSidesSwapped = try container.decodeIfPresent(Bool.self, forKey: .areSidesSwapped) ?? false
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
        try container.encode(possessionDirection, forKey: .possessionDirection)
        try container.encode(areSidesSwapped, forKey: .areSidesSwapped)
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
