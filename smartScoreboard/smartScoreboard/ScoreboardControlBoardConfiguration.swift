import Foundation

nonisolated enum ScoreboardControlBoardModule: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case matchTimer, shotClock, scores, roster, teamFouls, substitutions, pauses, penalties, prepTime

    var id: String { rawValue }
    var hasTeamControls: Bool { self != .matchTimer }
    var title: String {
        switch self {
        case .matchTimer: "Match & Timer Controls"
        case .shotClock: "Shot / Serve Timer"
        case .scores: "Scoring"
        case .roster: "Roster Management"
        case .teamFouls: "Team Fouls"
        case .substitutions: "Substitutions"
        case .pauses: "Pauses"
        case .penalties: "Penalty Timers"
        case .prepTime: "Prep Time"
        }
    }
}

nonisolated enum ScoreboardControlBoardMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case full, timer, shotClock, roster, scoring, penalties, custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .full: "Full Control Board"
        case .timer: "Timer Controller"
        case .shotClock: "Shot / Serve Controller"
        case .roster: "Roster Station"
        case .scoring: "Scoring Station"
        case .penalties: "Penalty Station"
        case .custom: "Custom Station"
        }
    }

    var modules: [ScoreboardControlBoardModule] {
        switch self {
        case .full, .custom: ScoreboardControlBoardModule.allCases
        case .timer: [.matchTimer, .prepTime]
        case .shotClock: [.shotClock]
        case .roster: [.roster]
        case .scoring: [.scores, .teamFouls]
        case .penalties: [.penalties]
        }
    }
}

nonisolated enum ScoreboardControlBoardTeams: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case both, home, guest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: "Both Teams"
        case .home: "Home Team"
        case .guest: "Guest Team"
        }
    }
    var sides: [TeamSide] {
        switch self {
        case .both: [.home, .guest]
        case .home: [.home]
        case .guest: [.guest]
        }
    }
}

nonisolated struct ScoreboardControlBoardCapabilities: Sendable {
    var availableModules: Set<ScoreboardControlBoardModule>

    init(rules: SportRules, showsPrepTime: Bool = false) {
        // Match navigation and official pauses are useful even without a clock
        // or team pause allowances. The other modules follow the sport's rules.
        availableModules = [.matchTimer, .pauses]
        if rules.supportsShotClock { availableModules.insert(.shotClock) }
        if rules.supportsScore { availableModules.insert(.scores) }
        if rules.supportsPlayerTracking { availableModules.insert(.roster) }
        if rules.supportsTeamFouls { availableModules.insert(.teamFouls) }
        if rules.showsSubstitutionTracking { availableModules.insert(.substitutions) }
        if rules.supportsHockeyPenalties { availableModules.insert(.penalties) }
        if showsPrepTime { availableModules.insert(.prepTime) }
    }

    var availableModes: [ScoreboardControlBoardMode] {
        ScoreboardControlBoardMode.allCases.filter { mode in
            mode == .full || mode == .custom || mode.modules.first.map(availableModules.contains) == true
        }
    }
}

/// Local presentation preferences, deliberately separate from match snapshots,
/// host settings, control permissions, and timer operations.
nonisolated struct ScoreboardControlBoardConfiguration: Codable, Equatable, Sendable {
    var mode: ScoreboardControlBoardMode = .full
    var teams: ScoreboardControlBoardTeams = .both
    var showsCenterSummary = true
    var moduleOrder: [ScoreboardControlBoardModule] = ScoreboardControlBoardModule.allCases
    var enabledModules: Set<ScoreboardControlBoardModule> = Set(ScoreboardControlBoardModule.allCases)

    init() {}

    func effectiveMode(for capabilities: ScoreboardControlBoardCapabilities) -> ScoreboardControlBoardMode {
        capabilities.availableModes.contains(mode) ? mode : .full
    }

    func orderedModules(available: Set<ScoreboardControlBoardModule>) -> [ScoreboardControlBoardModule] {
        var seen = Set<ScoreboardControlBoardModule>()
        return (moduleOrder + ScoreboardControlBoardModule.allCases).filter {
            available.contains($0) && seen.insert($0).inserted
        }
    }

    func visibleModules(for capabilities: ScoreboardControlBoardCapabilities) -> [ScoreboardControlBoardModule] {
        let effective = effectiveMode(for: capabilities)
        if effective == .custom {
            return orderedModules(available: capabilities.availableModules).filter(enabledModules.contains)
        }
        return effective.modules.filter(capabilities.availableModules.contains)
    }

    @MainActor func allows(_ action: ScoreboardKeyboardShortcutAction, capabilities: ScoreboardControlBoardCapabilities) -> Bool {
        if effectiveMode(for: capabilities) == .full { return true }
        let name = action.rawValue.lowercased()
        let module: ScoreboardControlBoardModule
        switch action {
        case .resetSecondaryTimer: module = .shotClock
        case .zeroScores: module = .scores
        case .resetHomePrep, .resetGuestPrep, .toggleHomePrep, .toggleGuestPrep,
             .homePrepMinusFifteen, .homePrepPlusFifteen, .guestPrepMinusFifteen, .guestPrepPlusFifteen:
            module = .prepTime
        case .resetAllPlayerFouls, .resetAllCards: module = .roster
        case .resetAllTeamFouls: module = .teamFouls
        default:
            switch action.group {
            case .scoring: module = .scores
            case .primaryTimer, .periodAndSides, .chessAndDebate, .resetActions: module = .matchTimer
            case .secondaryTimer: module = .shotClock
            case .playerView: module = .roster
            case .hockeyPenalties: module = .penalties
            case .teamTools:
                if name.contains("substitution") { module = .substitutions }
                else if name.contains("pause") { module = .pauses }
                else { module = .teamFouls }
            }
        }
        if module.hasTeamControls {
            if teams == .home && name.contains("guest") { return false }
            if teams == .guest && name.contains("home") { return false }
            if teams != .both && (name.hasPrefix("resetall") || action == .zeroScores) { return false }
        }
        return visibleModules(for: capabilities).contains(module)
    }

    mutating func move(_ module: ScoreboardControlBoardModule, by offset: Int,
                       available: Set<ScoreboardControlBoardModule>) {
        let visible = orderedModules(available: available)
        guard let index = visible.firstIndex(of: module), visible.indices.contains(index + offset) else { return }
        moduleOrder = orderedModules(available: Set(ScoreboardControlBoardModule.allCases))
        guard let source = moduleOrder.firstIndex(of: module),
              let destination = moduleOrder.firstIndex(of: visible[index + offset]) else { return }
        moduleOrder.swapAt(source, destination)
    }

    private enum CodingKeys: String, CodingKey { case mode, teams, showsCenterSummary, moduleOrder, enabledModules }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = (try? values.decode(String.self, forKey: .mode)).flatMap(ScoreboardControlBoardMode.init(rawValue:)) ?? .full
        teams = (try? values.decode(String.self, forKey: .teams)).flatMap(ScoreboardControlBoardTeams.init(rawValue:)) ?? .both
        showsCenterSummary = (try? values.decode(Bool.self, forKey: .showsCenterSummary)) ?? true
        let order = (try? values.decode([String].self, forKey: .moduleOrder)) ?? []
        var seen = Set<ScoreboardControlBoardModule>()
        moduleOrder = (order.compactMap(ScoreboardControlBoardModule.init(rawValue:)) + ScoreboardControlBoardModule.allCases)
            .filter { seen.insert($0).inserted }
        if let enabled = try? values.decode([String].self, forKey: .enabledModules) {
            enabledModules = Set(enabled.compactMap(ScoreboardControlBoardModule.init(rawValue:)))
        } else {
            enabledModules = Set(ScoreboardControlBoardModule.allCases)
        }
    }
}

/// Uses the available control pane, including the smaller pane in Merged View.
/// Height and orientation do not force otherwise usable columns into a stack.
nonisolated struct ScoreboardControlBoardLayout: Equatable, Sendable {
    let usesCenterColumn: Bool
    let teamColumnCount: Int
    let sharedControlColumnCount: Int
    let canPlaceSummaryBesideControls: Bool

    init(width: Double, teamCount: Int, showsSummary: Bool, includesRoster: Bool) {
        let width = max(0, width)
        usesCenterColumn = showsSummary && teamCount == 2 && width >= (includesRoster ? 1_140 : 1_000)
        teamColumnCount = teamCount == 0 ? 0 : min(teamCount, width >= 600 ? 2 : 1)
        sharedControlColumnCount = width >= 960 ? 3 : width >= 600 ? 2 : 1
        canPlaceSummaryBesideControls = showsSummary && width >= 680
    }
}

nonisolated struct ScoreboardControlBoardPreferences: Codable, Equatable, Sendable {
    static let storageKey = "scoreboard.controlBoardConfigurations.v1"
    var sports: [String: ScoreboardControlBoardConfiguration] = [:]

    init(data: Data = Data()) {
        self = (try? JSONDecoder().decode(Self.self, from: data)) ?? Self(sports: [:])
    }

    private init(sports: [String: ScoreboardControlBoardConfiguration]) { self.sports = sports }

    func configuration(for sport: SportType) -> ScoreboardControlBoardConfiguration {
        sports[sport.rawValue] ?? ScoreboardControlBoardConfiguration()
    }

    mutating func set(_ configuration: ScoreboardControlBoardConfiguration, for sport: SportType) {
        sports[sport.rawValue] = configuration
    }

    var data: Data { (try? JSONEncoder().encode(self)) ?? Data() }
}
