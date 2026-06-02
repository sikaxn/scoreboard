import Foundation

enum GameClockMode: String, Codable {
    case countdown
    case countUp
}

enum SportType: String, Codable, CaseIterable, Identifiable {
    case basketball
    case volleyball
    case soccer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basketball:
            return "Basketball"
        case .volleyball:
            return "Volleyball"
        case .soccer:
            return "Soccer"
        }
    }

    var periodTitle: String {
        switch self {
        case .basketball:
            return "Period"
        case .volleyball:
            return "Set"
        case .soccer:
            return "Half"
        }
    }

    var periodShortTitle: String {
        switch self {
        case .basketball:
            return "P"
        case .volleyball:
            return "S"
        case .soccer:
            return "H"
        }
    }

    var scoreStepOptions: [Int] {
        switch self {
        case .basketball:
            return [1, 2, 3]
        case .volleyball, .soccer:
            return [1]
        }
    }

    var defaultClockSeconds: Int {
        switch self {
        case .basketball:
            return 12 * 60
        case .volleyball:
            return 0
        case .soccer:
            return 45 * 60
        }
    }

    var defaultShotClockSeconds: Int {
        switch self {
        case .basketball:
            return 24
        case .volleyball, .soccer:
            return 0
        }
    }

    var defaultRosterSize: Int {
        switch self {
        case .basketball:
            return 12
        case .volleyball:
            return 12
        case .soccer:
            return 11
        }
    }

    var defaultDisplayLineupSize: Int {
        switch self {
        case .basketball:
            return 5
        case .volleyball:
            return 6
        case .soccer:
            return 11
        }
    }

    var defaultSubstitutionLimit: Int {
        switch self {
        case .basketball:
            return 0
        case .volleyball:
            return 6
        case .soccer:
            return 5
        }
    }

    var clockMode: GameClockMode {
        switch self {
        case .basketball, .soccer:
            return .countdown
        case .volleyball:
            return .countUp
        }
    }

    var supportsShotClock: Bool { self == .basketball }
    var supportsPossession: Bool { self == .basketball }
    var supportsFouls: Bool { self == .basketball }
    var supportsTeamFouls: Bool { self == .volleyball }
    var supportsPlayerTracking: Bool { true }
    var supportsCards: Bool { self == .soccer || self == .volleyball }
    var showsSubstitutionTracking: Bool { self != .basketball }
}
