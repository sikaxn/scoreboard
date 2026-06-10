#if os(iOS)
import ActivityKit
import Foundation

struct ScoreboardLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var statusText: String
        var sportTitle: String
        var homeTeamName: String
        var guestTeamName: String
        var scoreText: String?
        var periodText: String?
        var primaryTimer: ScoreboardLiveActivityTimer
        var secondaryTimer: ScoreboardLiveActivityTimer?
        var staleDate: Date?
    }

    var activityName: String
}

struct ScoreboardLiveActivityTimer: Codable, Hashable, Sendable {
    var title: String
    var valueText: String
    var mode: ScoreboardLiveActivityTimerMode
    var rangeStartDate: Date?
    var rangeEndDate: Date?
    var isActive: Bool
    var side: ScoreboardLiveActivitySide?

    var dateRange: ClosedRange<Date>? {
        guard let rangeStartDate, let rangeEndDate, rangeStartDate <= rangeEndDate else {
            return nil
        }
        return rangeStartDate...rangeEndDate
    }
}

enum ScoreboardLiveActivityTimerMode: String, Codable, Hashable, Sendable {
    case staticValue
    case countdown
    case countUp
}

enum ScoreboardLiveActivitySide: String, Codable, Hashable, Sendable {
    case home
    case guest
}
#endif
