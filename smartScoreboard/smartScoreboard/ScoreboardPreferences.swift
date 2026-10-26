import Foundation

/// One preference domain for the core, with an isolated domain in the test bundle.
nonisolated enum ScoreboardPreferences {
    nonisolated(unsafe) static let current: UserDefaults = {
        #if SCOREBOARD_TESTING
        return ScoreboardTestEnvironment.defaults
        #else
        #if DEBUG
        if let defaults = ScoreboardUITestLaunch.defaults { return defaults }
        #endif
        return .standard
        #endif
    }()
}

#if DEBUG
/// Launch fixtures for the real app process. UI tests keep real timers and networking.
nonisolated enum ScoreboardUITestLaunch {
    static let sessionID = ProcessInfo.processInfo.environment["SCOREBOARD_UI_TEST_ID"].flatMap(UUID.init(uuidString:))
    static var isEnabled: Bool { sessionID != nil }
    static let storageRoot: URL? = sessionID.map {
        FileManager.default.temporaryDirectory.appendingPathComponent("ScoreboardUITests-\($0.uuidString)", isDirectory: true)
    }
    nonisolated(unsafe) static let defaults: UserDefaults? = {
        guard let sessionID else { return nil }
        let domain = "ScoreboardUITests.\(sessionID.uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defaults.set(false, forKey: "showsMergedView")
        return defaults
    }()

    /// The runner reads a named JSON resource and passes its contents, rather
    /// than a filesystem path across the simulator app's sandbox boundary.
    private struct Configuration: Decodable {
        var sport: SportType
        var eventName: String?
        var homeTeamName: String?
        var guestTeamName: String?
        var period: Int?
        var clockSeconds: Int?
        var guestClockSeconds: Int?
        var isGameClockEnabled: Bool?
        var volleyballMatchFormat: VolleyballMatchFormat?
        var chessClockPreset: ChessClockPreset?
        var customSportConfig: CustomSportConfig?
        var debatePresetID: String?
        var customDebatePreset: DebatePreset?
        var debateHomeSideLabel: String?
        var debateGuestSideLabel: String?
        var isDebateScoreTrackingEnabled: Bool?
        var isDebatePlayerTrackingEnabled: Bool?
        var isDebatePlayerFoulsEnabled: Bool?
        var isDebatePlayerCardsEnabled: Bool?
        var isDebatePrepTimeEnabled: Bool?
    }

    @MainActor private static func loadConfiguration() -> Configuration? {
        guard isEnabled,
              let json = ProcessInfo.processInfo.environment["SCOREBOARD_UI_TEST_CONFIGURATION"] else { return nil }
        do {
            return try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        } catch {
            preconditionFailure("Invalid UI test launch configuration: \(error)")
        }
    }

    @MainActor static func configure(_ store: ScoreboardStore) {
        guard isEnabled else { return }
        let configuration = loadConfiguration()
        let scenario = ProcessInfo.processInfo.environment["SCOREBOARD_UI_TEST_SCENARIO"] ?? "setup"
        store.setSelectedSport(configuration?.sport ?? SportType(rawValue: scenario) ?? .simple)
        if let preset = configuration?.customDebatePreset {
            store.updateCustomDebatePreset(preset)
        }
        if let presetID = configuration?.debatePresetID {
            store.applyDebatePreset(id: presetID)
        }
        store.newGame()
        if let configuration { apply(configuration, to: store) }
        store.didCompleteSetup = scenario != "setup"
        store.areTipsEnabled = false
        store.showGettingStartedOnStartup = false
        store.isSoundEnabled = false
        if let portText = ProcessInfo.processInfo.environment["SCOREBOARD_UI_TEST_COMPANION_PORT"], let port = UInt16(portText) {
            store.companionHost = "127.0.0.1"
            store.companionMode = .http
            store.companionPort = port
            store.setCompanionLocationText("1/0/1", for: .gameClockStarted)
            store.setCompanionLocationText("1/0/2", for: .scoreChanged)
            store.setCompanionLocationText("1/0/3", for: .pauseEnded)
        }
        if scenario == "remote" { store.isRemoteDisplayViewerModeEnabled = true }
    }

    @MainActor private static func apply(_ config: Configuration, to store: ScoreboardStore) {
        var snapshot = store.currentGameSnapshot()
        snapshot.eventName = config.eventName ?? snapshot.eventName
        snapshot.homeTeamName = config.homeTeamName ?? snapshot.homeTeamName
        snapshot.guestTeamName = config.guestTeamName ?? snapshot.guestTeamName
        snapshot.period = config.period ?? snapshot.period
        snapshot.customSportConfig = config.customSportConfig ?? snapshot.customSportConfig
        let clock = config.clockSeconds ?? config.customSportConfig?.defaultClockSeconds ?? snapshot.defaultClockSeconds
        snapshot.defaultClockSeconds = clock
        snapshot.gameClockSeconds = clock
        snapshot.homeChessClockSeconds = clock
        snapshot.guestChessClockSeconds = config.guestClockSeconds ?? clock
        if let custom = config.customSportConfig {
            snapshot.defaultShotClockSeconds = custom.isShotClockEnabled ? custom.defaultShotClockSeconds : 0
            snapshot.activeShotClockPresetSeconds = snapshot.defaultShotClockSeconds
            snapshot.shotClockMilliseconds = snapshot.defaultShotClockSeconds * 1_000
            snapshot.isPlayerTrackingEnabled = custom.isPlayerTrackingEnabled
            snapshot.homePausesAllowed = custom.isPauseTrackingEnabled ? custom.defaultPauseLimit : 0
            snapshot.guestPausesAllowed = snapshot.homePausesAllowed
        }
        snapshot.isGameClockEnabled = config.isGameClockEnabled ?? snapshot.isGameClockEnabled
        snapshot.volleyballMatchFormat = config.volleyballMatchFormat ?? snapshot.volleyballMatchFormat
        snapshot.chessClockPreset = config.chessClockPreset ?? snapshot.chessClockPreset
        snapshot.debateHomeSideLabel = config.debateHomeSideLabel ?? snapshot.debateHomeSideLabel
        snapshot.debateGuestSideLabel = config.debateGuestSideLabel ?? snapshot.debateGuestSideLabel
        snapshot.isDebateScoreTrackingEnabled = config.isDebateScoreTrackingEnabled ?? snapshot.isDebateScoreTrackingEnabled
        snapshot.isDebatePlayerTrackingEnabled = config.isDebatePlayerTrackingEnabled ?? snapshot.isDebatePlayerTrackingEnabled
        snapshot.isDebatePlayerFoulsEnabled = config.isDebatePlayerFoulsEnabled ?? snapshot.isDebatePlayerFoulsEnabled
        snapshot.isDebatePlayerCardsEnabled = config.isDebatePlayerCardsEnabled ?? snapshot.isDebatePlayerCardsEnabled
        snapshot.isDebatePrepTimeEnabled = config.isDebatePrepTimeEnabled ?? snapshot.isDebatePrepTimeEnabled
        if snapshot.isDebatePrepTimeEnabled == false {
            snapshot.debatePrepHomeSeconds = 0
            snapshot.debatePrepGuestSeconds = 0
        }
        if config.sport == .debate {
            snapshot.isPlayerTrackingEnabled = snapshot.isDebatePlayerTrackingEnabled
        }
        // Use the same saved-game loading path as the app. Timers and transport
        // behavior after launch are still driven through the actual UI.
        store.applyGameSnapshot(snapshot)
    }
}
#endif
