import Foundation
import Testing

extension ScoreboardTests {
    @Test("Station presets follow each sport's capabilities", arguments: SportType.allCases)
    func controlBoardModesFollowSport(sport: SportType) {
        store.setSelectedSport(sport)
        let capabilities = ScoreboardControlBoardCapabilities(rules: store.currentRules, showsPrepTime: store.showsDebatePrepTime)
        #expect(capabilities.availableModes.contains(.full))
        #expect(capabilities.availableModes.contains(.timer))
        #expect(capabilities.availableModes.contains(.custom))
        for mode in capabilities.availableModes {
            var config = ScoreboardControlBoardConfiguration()
            config.mode = mode
            #expect(config.showsCenterSummary, "Every mode starts with its clock/score box enabled")
            #expect(config.effectiveMode(for: capabilities) == mode)
            #expect(!config.visibleModules(for: capabilities).isEmpty)
            #expect(Set(config.visibleModules(for: capabilities)).isSubset(of: capabilities.availableModules))
        }
        switch sport {
        case .basketball, .volleyball:
            #expect(capabilities.availableModes.contains(.shotClock))
            #expect(capabilities.availableModes.contains(.roster))
            #expect(!capabilities.availableModes.contains(.penalties))
        case .soccer:
            #expect(!capabilities.availableModes.contains(.shotClock))
            #expect(capabilities.availableModes.contains(.roster))
        case .hockey:
            #expect(capabilities.availableModes.contains(.penalties))
            #expect(!capabilities.availableModes.contains(.shotClock))
        case .simple, .chess:
            #expect(!capabilities.availableModes.contains(.shotClock))
            #expect(!capabilities.availableModes.contains(.roster))
        case .debate, .custom: break
        }
    }

    @Test("Dedicated stations expose only their controls and shortcuts")
    func dedicatedControlBoardStations() {
        let capabilities = ScoreboardControlBoardCapabilities(rules: store.currentRules)
        var config = ScoreboardControlBoardConfiguration()
        config.mode = .shotClock
        #expect(config.visibleModules(for: capabilities) == [.shotClock])
        #expect(config.allows(.secondaryTimerPrimary, capabilities: capabilities))
        #expect(config.allows(.homeSecondaryAlternate, capabilities: capabilities))
        #expect(!config.allows(.togglePrimaryTimer, capabilities: capabilities))
        #expect(!config.allows(.homeScorePrimary, capabilities: capabilities))
        #expect(!config.allows(.zeroScores, capabilities: capabilities))
        config.mode = .roster
        #expect(config.visibleModules(for: capabilities) == [.roster])
        #expect(config.allows(.togglePlayersPage, capabilities: capabilities))
        #expect(config.allows(.resetAllPlayerFouls, capabilities: capabilities))
        #expect(!config.allows(.resetPrimaryTimer, capabilities: capabilities))
        config.mode = .timer
        #expect(config.allows(.togglePrimaryTimer, capabilities: capabilities))
        #expect(!config.allows(.zeroScores, capabilities: capabilities))
        config.mode = .scoring
        #expect(config.allows(.guestScorePrimary, capabilities: capabilities))
        #expect(!config.allows(.resetSecondaryTimer, capabilities: capabilities))
    }

    @Test("Custom station order, selected teams, and temporarily unavailable modules persist")
    func customControlBoardLayout() {
        var config = ScoreboardControlBoardConfiguration()
        config.mode = .custom
        config.moduleOrder = [.penalties, .scores, .shotClock]
        config.enabledModules = [.penalties, .scores, .shotClock]
        config.teams = .home
        let basketball = ScoreboardControlBoardCapabilities(rules: SportType.basketball.rules(customConfig: nil))
        let hockey = ScoreboardControlBoardCapabilities(rules: SportType.hockey.rules(customConfig: nil))
        #expect(config.visibleModules(for: basketball) == [.scores, .shotClock])
        config.move(.shotClock, by: -1, available: basketball.availableModules)
        #expect(config.visibleModules(for: basketball) == [.shotClock, .scores])
        #expect(config.visibleModules(for: hockey) == [.penalties, .scores])
        #expect(config.teams.sides == [.home])
        #expect(config.allows(.homeScorePrimary, capabilities: basketball))
        #expect(!config.allows(.guestScorePrimary, capabilities: basketball))
        #expect(!config.allows(.zeroScores, capabilities: basketball))
        let order = config.moduleOrder
        config.move(.shotClock, by: -1, available: basketball.availableModules)
        #expect(config.moduleOrder == order, "Moving the first available row up is a no-op")
        config.teams = .guest
        #expect(config.teams.sides == [.guest])
        #expect(!config.allows(.homeSecondaryPrimary, capabilities: basketball))
        #expect(config.allows(.guestSecondaryPrimary, capabilities: basketball))
        config.enabledModules.insert(.matchTimer)
        #expect(config.allows(.homeClockPlusSecond, capabilities: basketball), "Shared match controls are independent of the team panels")
    }

    @Test("Station keyboard execution preserves the match and drives the dedicated shot clock")
    func controlBoardStationKeyboardExecution() {
        var config = ScoreboardControlBoardConfiguration()
        config.mode = .shotClock
        var keyboard = ScoreboardKeyboardShortcutExecutionContext(
            store: store, isResetInterlockActive: false, isGameClockResetInterlockActive: false,
            requestGameConfirmation: { _ in Issue.record("A hidden reset must not reach confirmation") },
            adjustDebateSegmentTimer: { _ in }, handleDebateTurnHere: { _ in },
            addPenaltyTimer: { _, _ in }, togglePlayersPage: {}, controlBoardConfiguration: config)
        store.toggleClock()
        keyboard.perform(.togglePrimaryTimer)
        keyboard.perform(.homeScorePrimary)
        keyboard.perform(.zeroScores)
        #expect(store.isClockRunning && store.homeScore == 0)
        keyboard.perform(.secondaryTimerPrimary)
        #expect(store.isShotClockRunning, "The station primary key starts its shot clock")
        store.advanceControlTestTimers(by: 1.25)
        keyboard.perform(.secondaryTimerPrimary)
        #expect(!store.isShotClockRunning && store.isClockRunning)
        #expect(store.shotClockMilliseconds < 24_000)

        config.mode = .scoring
        config.teams = .guest
        keyboard.controlBoardConfiguration = config
        keyboard.perform(.homeScorePrimary)
        keyboard.perform(.guestScorePrimary)
        #expect(store.homeScore == 0 && store.guestScore == 1)
        keyboard.perform(.secondaryTimerPrimary)
        #expect(!store.isShotClockRunning)

        config.mode = .full
        keyboard.controlBoardConfiguration = config
        keyboard.perform(.secondaryTimerPrimary)
        #expect(!store.isShotClockRunning && store.shotClockMilliseconds == 24_000,
                "The full board retains its existing reset behavior")
    }

    @Test("Empty and unsupported stations remain recoverable without revealing unexpected controls")
    func emptyAndUnsupportedControlBoardModes() {
        let basketball = ScoreboardControlBoardCapabilities(rules: SportType.basketball.rules(customConfig: nil))
        let soccer = ScoreboardControlBoardCapabilities(rules: SportType.soccer.rules(customConfig: nil))
        var config = ScoreboardControlBoardConfiguration()
        config.mode = .custom
        config.enabledModules = []
        #expect(config.visibleModules(for: basketball).isEmpty)
        for action in ScoreboardKeyboardShortcutAction.allCases {
            #expect(!config.allows(action, capabilities: basketball))
        }
        config.mode = .shotClock
        #expect(config.effectiveMode(for: soccer) == .full)
        #expect(config.mode == .shotClock, "A temporary capability change keeps the saved choice")
        #expect(config.effectiveMode(for: basketball) == .shotClock)
    }

    @Test("Device-local profiles round-trip independently per sport and tolerate future data")
    func controlBoardPreferencePersistence() throws {
        var preferences = ScoreboardControlBoardPreferences()
        var basketball = ScoreboardControlBoardConfiguration()
        basketball.mode = .shotClock
        basketball.teams = .guest
        basketball.showsCenterSummary = false
        preferences.set(basketball, for: .basketball)
        var hockey = ScoreboardControlBoardConfiguration()
        hockey.mode = .custom
        hockey.enabledModules = [.penalties, .pauses]
        hockey.moduleOrder = [.pauses, .penalties]
        preferences.set(hockey, for: .hockey)
        ScoreboardPreferences.current.set(preferences.data, forKey: ScoreboardControlBoardPreferences.storageKey)
        let data = try #require(ScoreboardPreferences.current.data(forKey: ScoreboardControlBoardPreferences.storageKey))
        let restored = ScoreboardControlBoardPreferences(data: data)
        #expect(restored.configuration(for: .basketball) == basketball)
        #expect(restored.configuration(for: .hockey).visibleModules(for:
            ScoreboardControlBoardCapabilities(rules: SportType.hockey.rules(customConfig: nil))) == [.pauses, .penalties])
        #expect(restored.configuration(for: .soccer).mode == .full)
        #expect(ScoreboardControlBoardPreferences(data: Data("invalid".utf8)).configuration(for: .basketball).mode == .full)
        let future = Data(#"{"mode":"future","teams":"future","moduleOrder":["scores","scores","future"],"enabledModules":["scores","future"]}"#.utf8)
        let decoded = try JSONDecoder().decode(ScoreboardControlBoardConfiguration.self, from: future)
        #expect(decoded.mode == .full && decoded.teams == .both)
        #expect(decoded.showsCenterSummary, "Existing profiles gain the default summary")
        #expect(decoded.enabledModules == [.scores])
        #expect(Set(decoded.moduleOrder).count == decoded.moduleOrder.count)
        let oldDisplay = try JSONDecoder().decode(ScoreboardControlBoardConfiguration.self,
            from: Data(#"{"mode":"display","enabledModules":["scores","display"]}"#.utf8))
        #expect(oldDisplay.mode == .full && oldDisplay.enabledModules == [.scores])
        store.resetToFactoryDefaults()
        #expect(ScoreboardPreferences.current.data(forKey: ScoreboardControlBoardPreferences.storageKey) == nil)
    }

    @Test("Station layouts retain team columns and use the actual pane width")
    func controlBoardColumnLayouts() {
        let wide = ScoreboardControlBoardLayout(width: 1_280, teamCount: 2, showsSummary: true, includesRoster: true)
        #expect(wide.usesCenterColumn && wide.teamColumnCount == 2)
        let merged = ScoreboardControlBoardLayout(width: 800, teamCount: 2, showsSummary: true, includesRoster: true)
        #expect(!merged.usesCenterColumn && merged.teamColumnCount == 2)
        #expect(merged.canPlaceSummaryBesideControls && merged.sharedControlColumnCount == 2)
        let phone = ScoreboardControlBoardLayout(width: 390, teamCount: 2, showsSummary: true, includesRoster: true)
        #expect(!phone.usesCenterColumn && phone.teamColumnCount == 1 && phone.sharedControlColumnCount == 1)
        let hidden = ScoreboardControlBoardLayout(width: 1_280, teamCount: 2, showsSummary: false, includesRoster: true)
        #expect(!hidden.usesCenterColumn && hidden.teamColumnCount == 2 && !hidden.canPlaceSummaryBesideControls)
        let oneTeam = ScoreboardControlBoardLayout(width: 1_280, teamCount: 1, showsSummary: true, includesRoster: true)
        #expect(!oneTeam.usesCenterColumn && oneTeam.teamColumnCount == 1)
        let empty = ScoreboardControlBoardLayout(width: 0, teamCount: 0, showsSummary: true, includesRoster: false)
        #expect(!empty.usesCenterColumn && empty.teamColumnCount == 0 && empty.sharedControlColumnCount == 1)
    }

    @Test("Debate and custom sport modules follow enabled features")
    func specializedStationCapabilities() {
        store.setSelectedSport(.debate)
        store.setDebatePlayerTrackingEnabled(true)
        store.setDebateScoreTrackingEnabled(true)
        store.setDebatePrepTimeEnabled(true)
        var capabilities = ScoreboardControlBoardCapabilities(rules: store.currentRules, showsPrepTime: store.showsDebatePrepTime)
        #expect(capabilities.availableModules.isSuperset(of: [.roster, .scores, .prepTime]))
        store.setDebatePlayerTrackingEnabled(false)
        store.setDebateScoreTrackingEnabled(false)
        capabilities = ScoreboardControlBoardCapabilities(rules: store.currentRules)
        #expect(!capabilities.availableModes.contains(.roster))
        #expect(!capabilities.availableModes.contains(.scoring))
        var custom = CustomSportConfig.default
        custom.isShotClockEnabled = false
        custom.isPenaltyTimerEnabled = true
        custom.isPlayerTrackingEnabled = false
        custom.isScoreEnabled = false
        custom.isTeamFoulsEnabled = true
        capabilities = ScoreboardControlBoardCapabilities(rules: SportType.custom.rules(customConfig: custom))
        #expect(capabilities.availableModes.contains(.penalties))
        #expect(!capabilities.availableModes.contains(.shotClock))
        #expect(!capabilities.availableModes.contains(.roster))
        #expect(!capabilities.availableModes.contains(.scoring))
        #expect(capabilities.availableModules.contains(.teamFouls), "A custom station can still expose team fouls without scoring")
    }
}
