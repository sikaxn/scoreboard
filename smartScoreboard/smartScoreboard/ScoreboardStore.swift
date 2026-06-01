import Combine
import Foundation

struct SetupPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var homeTeamName: String
    var guestTeamName: String
    var period: Int
    var clockSeconds: Int

    init(
        id: UUID = UUID(),
        name: String,
        homeTeamName: String,
        guestTeamName: String,
        period: Int,
        clockSeconds: Int
    ) {
        self.id = id
        self.name = name
        self.homeTeamName = homeTeamName
        self.guestTeamName = guestTeamName
        self.period = period
        self.clockSeconds = clockSeconds
    }
}

@MainActor
final class ScoreboardStore: ObservableObject {
    static let shared = ScoreboardStore()

    @Published var homeTeamName = ""
    @Published var guestTeamName = ""
    @Published var homeScore = 0
    @Published var guestScore = 0
    @Published var period = 1
    @Published var gameClockSeconds = 12 * 60
    @Published var defaultClockSeconds = 12 * 60
    @Published var isClockRunning = false
    @Published var didCompleteSetup = false
    @Published var setupPresets: [SetupPreset] = []

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let persistenceKey = "smartScoreboard.persistedState"

    private init() {
        loadPersistedState()
        configurePersistence()
    }

    var formattedClock: String {
        let minutes = gameClockSeconds / 60
        let seconds = gameClockSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
        gameClockSeconds = max(0, min(59 * 60 + 59, gameClockSeconds + delta))
        if gameClockSeconds == 0 {
            pauseClock()
        }
    }

    func resetClock(to seconds: Int? = nil) {
        pauseClock()
        gameClockSeconds = boundedClockSeconds(seconds ?? defaultClockSeconds)
    }

    func toggleClock() {
        isClockRunning ? pauseClock() : startClock()
    }

    func newGame() {
        pauseClock()
        homeScore = 0
        guestScore = 0
        period = 1
        gameClockSeconds = defaultClockSeconds
    }

    func applySetup(homeName: String, guestName: String, period: Int, clockSeconds: Int) {
        updateTeamName(homeName, isHome: true)
        updateTeamName(guestName, isHome: false)
        homeScore = 0
        guestScore = 0
        setPeriod(period)
        defaultClockSeconds = boundedClockSeconds(clockSeconds)
        didCompleteSetup = true
        resetClock(to: defaultClockSeconds)
    }

    func savePreset(
        named name: String,
        homeName: String,
        guestName: String,
        period: Int,
        clockSeconds: Int
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
            clockSeconds: boundedClockSeconds(clockSeconds)
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

        isClockRunning = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.tick()
            }
        }
    }

    private func pauseClock() {
        isClockRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isClockRunning else {
            return
        }

        guard gameClockSeconds > 0 else {
            pauseClock()
            return
        }

        gameClockSeconds -= 1

        if gameClockSeconds == 0 {
            pauseClock()
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

    private func boundedClockSeconds(_ value: Int) -> Int {
        max(0, min(59 * 60 + 59, value))
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
            $isClockRunning.map { _ in () }.eraseToAnyPublisher(),
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
        gameClockSeconds = boundedClockSeconds(persistedState.gameClockSeconds)
        defaultClockSeconds = boundedClockSeconds(persistedState.defaultClockSeconds)
        didCompleteSetup = persistedState.didCompleteSetup
        setupPresets = persistedState.setupPresets
        isClockRunning = false
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
    var didCompleteSetup: Bool
    var setupPresets: [SetupPreset]
}

@MainActor
final class PublicBoardState: ObservableObject {
    static let shared = PublicBoardState()

    @Published var isPresented = false

    private init() {}
}
