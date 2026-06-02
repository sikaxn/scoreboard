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
    var periodTitle: String
    var periodShortTitle: String
    var mainClockMode: MainClockMode
    var defaultClockSeconds: Int
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

    static let `default` = CustomSportConfig(
        title: "Custom Sport",
        periodTitle: "Period",
        periodShortTitle: "P",
        mainClockMode: .countdown,
        defaultClockSeconds: 10 * 60,
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
    case basketball
    case volleyball
    case soccer
    case hockey
    case chess
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
                showsSubstitutionTracking: false,
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
                defaultSubstitutionLimit: config.isSubstitutionTrackingEnabled ? config.defaultSubstitutionLimit : 0,
                mainClockMode: config.mainClockMode,
                supportsScore: true,
                supportsPeriod: true,
                supportsShotClock: config.isShotClockEnabled,
                supportsPossession: config.isPossessionEnabled,
                supportsFouls: config.isPlayerFoulsEnabled,
                supportsTeamFouls: config.isTeamFoulsEnabled,
                supportsPlayerTracking: config.isPlayerTrackingEnabled,
                usesCenterPlayerStrip: config.usesCenterPlayerStrip,
                supportsCards: config.isPlayerCardsEnabled,
                showsSubstitutionTracking: config.isSubstitutionTrackingEnabled,
                supportsHockeyPenalties: false,
                usesChessClocks: false
            )
        }
    }
}
