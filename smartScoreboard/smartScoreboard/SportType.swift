import Foundation

enum MainClockMode: String, Codable, CaseIterable, Identifiable {
    case countdown
    case countUp
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countdown:
            return "Countdown"
        case .countUp:
            return "Count Up"
        case .disabled:
            return "Disabled"
        }
    }
}

enum GameClockMode: String, Codable {
    case countdown
    case countUp
}

enum ChessClockPreset: String, Codable, CaseIterable, Identifiable {
    case bullet
    case blitz
    case rapid
    case classical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bullet:
            return "Bullet"
        case .blitz:
            return "Blitz"
        case .rapid:
            return "Rapid"
        case .classical:
            return "Classical"
        }
    }

    var seconds: Int {
        switch self {
        case .bullet:
            return 60
        case .blitz:
            return 5 * 60
        case .rapid:
            return 10 * 60
        case .classical:
            return 30 * 60
        }
    }
}

enum CustomScoreStepPreset: String, Codable, CaseIterable, Identifiable {
    case one
    case oneTwo
    case oneTwoThree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .one:
            return "+1"
        case .oneTwo:
            return "+1 +2"
        case .oneTwoThree:
            return "+1 +2 +3"
        }
    }

    var values: [Int] {
        switch self {
        case .one:
            return [1]
        case .oneTwo:
            return [1, 2]
        case .oneTwoThree:
            return [1, 2, 3]
        }
    }
}

struct CustomSportConfig: Codable, Equatable, Sendable {
    var title: String
    var isPeriodEnabled: Bool
    var periodTitle: String
    var periodShortTitle: String
    var usesChessClocks: Bool
    var mainClockMode: MainClockMode
    var defaultClockSeconds: Int
    var isScoreEnabled: Bool
    var scoreStepPreset: CustomScoreStepPreset
    var isShotClockEnabled: Bool
    var defaultShotClockSeconds: Int
    var isPossessionEnabled: Bool
    var isPlayerTrackingEnabled: Bool
    var usesCenterPlayerStrip: Bool
    var isPlayerFoulsEnabled: Bool
    var isSubstitutionTrackingEnabled: Bool
    var defaultSubstitutionLimit: Int
    var isTeamFoulsEnabled: Bool
    var isPlayerCardsEnabled: Bool
    var defaultRosterSize: Int
    var defaultDisplayLineupSize: Int

    init(
        title: String,
        isPeriodEnabled: Bool,
        periodTitle: String,
        periodShortTitle: String,
        usesChessClocks: Bool,
        mainClockMode: MainClockMode,
        defaultClockSeconds: Int,
        isScoreEnabled: Bool,
        scoreStepPreset: CustomScoreStepPreset,
        isShotClockEnabled: Bool,
        defaultShotClockSeconds: Int,
        isPossessionEnabled: Bool,
        isPlayerTrackingEnabled: Bool,
        usesCenterPlayerStrip: Bool,
        isPlayerFoulsEnabled: Bool,
        isSubstitutionTrackingEnabled: Bool,
        defaultSubstitutionLimit: Int,
        isTeamFoulsEnabled: Bool,
        isPlayerCardsEnabled: Bool,
        defaultRosterSize: Int,
        defaultDisplayLineupSize: Int
    ) {
        self.title = title
        self.isPeriodEnabled = isPeriodEnabled
        self.periodTitle = periodTitle
        self.periodShortTitle = periodShortTitle
        self.usesChessClocks = usesChessClocks
        self.mainClockMode = mainClockMode
        self.defaultClockSeconds = defaultClockSeconds
        self.isScoreEnabled = isScoreEnabled
        self.scoreStepPreset = scoreStepPreset
        self.isShotClockEnabled = isShotClockEnabled
        self.defaultShotClockSeconds = defaultShotClockSeconds
        self.isPossessionEnabled = isPossessionEnabled
        self.isPlayerTrackingEnabled = isPlayerTrackingEnabled
        self.usesCenterPlayerStrip = usesCenterPlayerStrip
        self.isPlayerFoulsEnabled = isPlayerFoulsEnabled
        self.isSubstitutionTrackingEnabled = isSubstitutionTrackingEnabled
        self.defaultSubstitutionLimit = defaultSubstitutionLimit
        self.isTeamFoulsEnabled = isTeamFoulsEnabled
        self.isPlayerCardsEnabled = isPlayerCardsEnabled
        self.defaultRosterSize = defaultRosterSize
        self.defaultDisplayLineupSize = defaultDisplayLineupSize
    }

    static let `default` = CustomSportConfig(
        title: "Custom Sport",
        isPeriodEnabled: true,
        periodTitle: "Period",
        periodShortTitle: "P",
        usesChessClocks: false,
        mainClockMode: .countdown,
        defaultClockSeconds: 10 * 60,
        isScoreEnabled: true,
        scoreStepPreset: .oneTwoThree,
        isShotClockEnabled: false,
        defaultShotClockSeconds: 24,
        isPossessionEnabled: false,
        isPlayerTrackingEnabled: false,
        usesCenterPlayerStrip: false,
        isPlayerFoulsEnabled: false,
        isSubstitutionTrackingEnabled: false,
        defaultSubstitutionLimit: 0,
        isTeamFoulsEnabled: false,
        isPlayerCardsEnabled: false,
        defaultRosterSize: 12,
        defaultDisplayLineupSize: 5
    )

    private enum CodingKeys: String, CodingKey {
        case title
        case isPeriodEnabled
        case periodTitle
        case periodShortTitle
        case usesChessClocks
        case mainClockMode
        case defaultClockSeconds
        case isScoreEnabled
        case scoreStepPreset
        case isShotClockEnabled
        case defaultShotClockSeconds
        case isPossessionEnabled
        case isPlayerTrackingEnabled
        case usesCenterPlayerStrip
        case isPlayerFoulsEnabled
        case isSubstitutionTrackingEnabled
        case defaultSubstitutionLimit
        case isTeamFoulsEnabled
        case isPlayerCardsEnabled
        case defaultRosterSize
        case defaultDisplayLineupSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? Self.default.title
        isPeriodEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPeriodEnabled) ?? Self.default.isPeriodEnabled
        periodTitle = try container.decodeIfPresent(String.self, forKey: .periodTitle) ?? Self.default.periodTitle
        periodShortTitle = try container.decodeIfPresent(String.self, forKey: .periodShortTitle) ?? Self.default.periodShortTitle
        usesChessClocks = try container.decodeIfPresent(Bool.self, forKey: .usesChessClocks) ?? Self.default.usesChessClocks
        mainClockMode = try container.decodeIfPresent(MainClockMode.self, forKey: .mainClockMode) ?? Self.default.mainClockMode
        defaultClockSeconds = try container.decodeIfPresent(Int.self, forKey: .defaultClockSeconds) ?? Self.default.defaultClockSeconds
        isScoreEnabled = try container.decodeIfPresent(Bool.self, forKey: .isScoreEnabled) ?? Self.default.isScoreEnabled
        scoreStepPreset = try container.decodeIfPresent(CustomScoreStepPreset.self, forKey: .scoreStepPreset) ?? Self.default.scoreStepPreset
        isShotClockEnabled = try container.decodeIfPresent(Bool.self, forKey: .isShotClockEnabled) ?? Self.default.isShotClockEnabled
        defaultShotClockSeconds = try container.decodeIfPresent(Int.self, forKey: .defaultShotClockSeconds) ?? Self.default.defaultShotClockSeconds
        isPossessionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPossessionEnabled) ?? Self.default.isPossessionEnabled
        isPlayerTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPlayerTrackingEnabled) ?? Self.default.isPlayerTrackingEnabled
        usesCenterPlayerStrip = try container.decodeIfPresent(Bool.self, forKey: .usesCenterPlayerStrip) ?? Self.default.usesCenterPlayerStrip
        isPlayerFoulsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPlayerFoulsEnabled) ?? Self.default.isPlayerFoulsEnabled
        isSubstitutionTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSubstitutionTrackingEnabled) ?? Self.default.isSubstitutionTrackingEnabled
        defaultSubstitutionLimit = try container.decodeIfPresent(Int.self, forKey: .defaultSubstitutionLimit) ?? Self.default.defaultSubstitutionLimit
        isTeamFoulsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTeamFoulsEnabled) ?? Self.default.isTeamFoulsEnabled
        isPlayerCardsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPlayerCardsEnabled) ?? Self.default.isPlayerCardsEnabled
        defaultRosterSize = try container.decodeIfPresent(Int.self, forKey: .defaultRosterSize) ?? Self.default.defaultRosterSize
        defaultDisplayLineupSize = try container.decodeIfPresent(Int.self, forKey: .defaultDisplayLineupSize) ?? Self.default.defaultDisplayLineupSize
    }
}

struct SportRules: Sendable {
    let sport: SportType
    let title: String
    let periodTitle: String
    let periodShortTitle: String
    let scoreStepOptions: [Int]
    let defaultClockSeconds: Int
    let defaultShotClockSeconds: Int
    let defaultRosterSize: Int
    let defaultDisplayLineupSize: Int
    let defaultSubstitutionLimit: Int
    let mainClockMode: MainClockMode
    let supportsScore: Bool
    let supportsPeriod: Bool
    let supportsShotClock: Bool
    let supportsPossession: Bool
    let supportsFouls: Bool
    let supportsTeamFouls: Bool
    let supportsPlayerTracking: Bool
    let usesCenterPlayerStrip: Bool
    let supportsCards: Bool
    let showsSubstitutionTracking: Bool
    let supportsHockeyPenalties: Bool
    let usesChessClocks: Bool
}

enum SportType: String, Codable, CaseIterable, Identifiable {
    case simple
    case basketball
    case volleyball
    case soccer
    case hockey
    case chess
    case debate
    case custom

    var id: String { rawValue }

    var title: String {
        rules(customConfig: nil).title
    }

    var periodTitle: String { rules(customConfig: nil).periodTitle }
    var periodShortTitle: String { rules(customConfig: nil).periodShortTitle }
    var scoreStepOptions: [Int] { rules(customConfig: nil).scoreStepOptions }
    var defaultClockSeconds: Int { rules(customConfig: nil).defaultClockSeconds }
    var defaultShotClockSeconds: Int { rules(customConfig: nil).defaultShotClockSeconds }
    var defaultRosterSize: Int { rules(customConfig: nil).defaultRosterSize }
    var defaultDisplayLineupSize: Int { rules(customConfig: nil).defaultDisplayLineupSize }
    var defaultSubstitutionLimit: Int { rules(customConfig: nil).defaultSubstitutionLimit }
    var supportsShotClock: Bool { rules(customConfig: nil).supportsShotClock }
    var supportsPossession: Bool { rules(customConfig: nil).supportsPossession }
    var supportsFouls: Bool { rules(customConfig: nil).supportsFouls }
    var supportsTeamFouls: Bool { rules(customConfig: nil).supportsTeamFouls }
    var supportsPlayerTracking: Bool { rules(customConfig: nil).supportsPlayerTracking }
    var usesCenterPlayerStrip: Bool { rules(customConfig: nil).usesCenterPlayerStrip }
    var supportsCards: Bool { rules(customConfig: nil).supportsCards }
    var showsSubstitutionTracking: Bool { rules(customConfig: nil).showsSubstitutionTracking }

    func rules(customConfig: CustomSportConfig?) -> SportRules {
        switch self {
        case .simple:
            return SportRules(
                sport: self,
                title: "Simple",
                periodTitle: "Period",
                periodShortTitle: "P",
                scoreStepOptions: [1],
                defaultClockSeconds: 10 * 60,
                defaultShotClockSeconds: 0,
                defaultRosterSize: 0,
                defaultDisplayLineupSize: 0,
                defaultSubstitutionLimit: 0,
                mainClockMode: .countdown,
                supportsScore: true,
                supportsPeriod: false,
                supportsShotClock: false,
                supportsPossession: false,
                supportsFouls: false,
                supportsTeamFouls: false,
                supportsPlayerTracking: false,
                usesCenterPlayerStrip: false,
                supportsCards: false,
                showsSubstitutionTracking: false,
                supportsHockeyPenalties: false,
                usesChessClocks: false
            )
        case .basketball:
            return SportRules(
                sport: self,
                title: "Basketball",
                periodTitle: "Period",
                periodShortTitle: "P",
                scoreStepOptions: [1, 2, 3],
                defaultClockSeconds: 12 * 60,
                defaultShotClockSeconds: 24,
                defaultRosterSize: 12,
                defaultDisplayLineupSize: 5,
                defaultSubstitutionLimit: 0,
                mainClockMode: .countdown,
                supportsScore: true,
                supportsPeriod: true,
                supportsShotClock: true,
                supportsPossession: true,
                supportsFouls: true,
                supportsTeamFouls: false,
                supportsPlayerTracking: true,
                usesCenterPlayerStrip: false,
                supportsCards: false,
                showsSubstitutionTracking: true,
                supportsHockeyPenalties: false,
                usesChessClocks: false
            )
        case .volleyball:
            return SportRules(
                sport: self,
                title: "Volleyball",
                periodTitle: "Set",
                periodShortTitle: "S",
                scoreStepOptions: [1],
                defaultClockSeconds: 0,
                defaultShotClockSeconds: 0,
                defaultRosterSize: 12,
                defaultDisplayLineupSize: 6,
                defaultSubstitutionLimit: 6,
                mainClockMode: .countUp,
                supportsScore: true,
                supportsPeriod: true,
                supportsShotClock: false,
                supportsPossession: false,
                supportsFouls: false,
                supportsTeamFouls: true,
                supportsPlayerTracking: true,
                usesCenterPlayerStrip: false,
                supportsCards: true,
                showsSubstitutionTracking: true,
                supportsHockeyPenalties: false,
                usesChessClocks: false
            )
        case .soccer:
            return SportRules(
                sport: self,
                title: "Soccer",
                periodTitle: "Half",
                periodShortTitle: "H",
                scoreStepOptions: [1],
                defaultClockSeconds: 45 * 60,
                defaultShotClockSeconds: 0,
                defaultRosterSize: 11,
                defaultDisplayLineupSize: 11,
                defaultSubstitutionLimit: 5,
                mainClockMode: .countdown,
                supportsScore: true,
                supportsPeriod: true,
                supportsShotClock: false,
                supportsPossession: false,
                supportsFouls: false,
                supportsTeamFouls: false,
                supportsPlayerTracking: true,
                usesCenterPlayerStrip: true,
                supportsCards: true,
                showsSubstitutionTracking: true,
                supportsHockeyPenalties: false,
                usesChessClocks: false
            )
        case .hockey:
            return SportRules(
                sport: self,
                title: "Hockey",
                periodTitle: "Period",
                periodShortTitle: "P",
                scoreStepOptions: [1],
                defaultClockSeconds: 20 * 60,
                defaultShotClockSeconds: 0,
                defaultRosterSize: 20,
                defaultDisplayLineupSize: 6,
                defaultSubstitutionLimit: 0,
                mainClockMode: .countdown,
                supportsScore: true,
                supportsPeriod: true,
                supportsShotClock: false,
                supportsPossession: false,
                supportsFouls: false,
                supportsTeamFouls: false,
                supportsPlayerTracking: true,
                usesCenterPlayerStrip: false,
                supportsCards: false,
                showsSubstitutionTracking: false,
                supportsHockeyPenalties: true,
                usesChessClocks: false
            )
        case .chess:
            return SportRules(
                sport: self,
                title: "Chess",
                periodTitle: "Round",
                periodShortTitle: "R",
                scoreStepOptions: [],
                defaultClockSeconds: ChessClockPreset.rapid.seconds,
                defaultShotClockSeconds: 0,
                defaultRosterSize: 0,
                defaultDisplayLineupSize: 0,
                defaultSubstitutionLimit: 0,
                mainClockMode: .disabled,
                supportsScore: false,
                supportsPeriod: false,
                supportsShotClock: false,
                supportsPossession: false,
                supportsFouls: false,
                supportsTeamFouls: false,
                supportsPlayerTracking: false,
                usesCenterPlayerStrip: false,
                supportsCards: false,
                showsSubstitutionTracking: false,
                supportsHockeyPenalties: false,
                usesChessClocks: true
            )
        case .debate:
            return SportRules(
                sport: self,
                title: "Debate",
                periodTitle: "Round",
                periodShortTitle: "R",
                scoreStepOptions: [],
                defaultClockSeconds: 7 * 60,
                defaultShotClockSeconds: 0,
                defaultRosterSize: 0,
                defaultDisplayLineupSize: 0,
                defaultSubstitutionLimit: 0,
                mainClockMode: .disabled,
                supportsScore: false,
                supportsPeriod: false,
                supportsShotClock: false,
                supportsPossession: false,
                supportsFouls: false,
                supportsTeamFouls: false,
                supportsPlayerTracking: false,
                usesCenterPlayerStrip: false,
                supportsCards: false,
                showsSubstitutionTracking: false,
                supportsHockeyPenalties: false,
                usesChessClocks: true
            )
        case .custom:
            let config = customConfig ?? .default
            return SportRules(
                sport: self,
                title: config.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom Sport" : config.title,
                periodTitle: config.periodTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Period" : config.periodTitle,
                periodShortTitle: config.periodShortTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "P" : config.periodShortTitle,
                scoreStepOptions: config.scoreStepPreset.values,
                defaultClockSeconds: config.defaultClockSeconds,
                defaultShotClockSeconds: config.isShotClockEnabled ? config.defaultShotClockSeconds : 0,
                defaultRosterSize: config.defaultRosterSize,
                defaultDisplayLineupSize: config.defaultDisplayLineupSize,
                defaultSubstitutionLimit: 0,
                mainClockMode: config.usesChessClocks ? .disabled : config.mainClockMode,
                supportsScore: config.isScoreEnabled,
                supportsPeriod: config.isPeriodEnabled,
                supportsShotClock: config.isShotClockEnabled,
                supportsPossession: config.isShotClockEnabled && config.isPossessionEnabled,
                supportsFouls: config.isPlayerFoulsEnabled,
                supportsTeamFouls: config.isTeamFoulsEnabled,
                supportsPlayerTracking: config.isPlayerTrackingEnabled,
                usesCenterPlayerStrip: config.usesCenterPlayerStrip,
                supportsCards: config.isPlayerCardsEnabled,
                showsSubstitutionTracking: config.isSubstitutionTrackingEnabled,
                supportsHockeyPenalties: false,
                usesChessClocks: config.usesChessClocks
            )
        }
    }
}
