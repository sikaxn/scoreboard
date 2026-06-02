import Foundation

enum DebateTimerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case masterClock
    case dualClock
    case none

    var id: String { rawValue }
}

struct DebateSegment: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var title: String
    var timerMode: DebateTimerMode
    var durationSeconds: Int
    var startingSide: TeamSide?
    var allowsSideSwitching: Bool
    var autoPauseAtEnd: Bool
    var startsPaused: Bool
}

struct DebatePreset: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var title: String
    var homeSideLabel: String
    var guestSideLabel: String
    var segments: [DebateSegment]
    var prepSecondsPerSide: Int
    var defaultScoreTrackingEnabled: Bool
    var defaultPlayerTrackingEnabled: Bool

    static let publicForum = DebatePreset(
        id: "public-forum",
        title: "Public Forum",
        homeSideLabel: "Aff",
        guestSideLabel: "Neg",
        segments: [
            DebateSegment(id: "pf-aff-constructive", title: "Aff Constructive", timerMode: .masterClock, durationSeconds: 4 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-neg-constructive", title: "Neg Constructive", timerMode: .masterClock, durationSeconds: 4 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-crossfire-1", title: "Crossfire", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-aff-rebuttal", title: "Aff Rebuttal", timerMode: .masterClock, durationSeconds: 4 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-neg-rebuttal", title: "Neg Rebuttal", timerMode: .masterClock, durationSeconds: 4 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-aff-summary", title: "Aff Summary", timerMode: .masterClock, durationSeconds: 2 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-neg-summary", title: "Neg Summary", timerMode: .masterClock, durationSeconds: 2 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-grand-crossfire", title: "Grand Crossfire", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-aff-final-focus", title: "Aff Final Focus", timerMode: .masterClock, durationSeconds: 2 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pf-neg-final-focus", title: "Neg Final Focus", timerMode: .masterClock, durationSeconds: 2 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true)
        ],
        prepSecondsPerSide: 2 * 60,
        defaultScoreTrackingEnabled: false,
        defaultPlayerTrackingEnabled: false
    )

    static let lincolnDouglas = DebatePreset(
        id: "lincoln-douglas",
        title: "Lincoln-Douglas",
        homeSideLabel: "Aff",
        guestSideLabel: "Neg",
        segments: [
            DebateSegment(id: "ld-aff-ac", title: "Aff Constructive", timerMode: .masterClock, durationSeconds: 6 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "ld-neg-cx-1", title: "Neg Cross-Ex", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "ld-neg-nc", title: "Neg Constructive", timerMode: .masterClock, durationSeconds: 7 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "ld-aff-cx-1", title: "Aff Cross-Ex", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "ld-aff-1r", title: "Aff Rebuttal", timerMode: .masterClock, durationSeconds: 4 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "ld-neg-1r", title: "Neg Rebuttal", timerMode: .masterClock, durationSeconds: 6 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "ld-aff-2r", title: "Aff Rebuttal 2", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true)
        ],
        prepSecondsPerSide: 3 * 60,
        defaultScoreTrackingEnabled: false,
        defaultPlayerTrackingEnabled: false
    )

    static let policy = DebatePreset(
        id: "policy",
        title: "Policy",
        homeSideLabel: "Aff",
        guestSideLabel: "Neg",
        segments: [
            DebateSegment(id: "pol-aff-1ac", title: "1AC", timerMode: .masterClock, durationSeconds: 8 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-neg-cx-1", title: "Cross-Ex", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-neg-1nc", title: "1NC", timerMode: .masterClock, durationSeconds: 8 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-aff-cx-1", title: "Cross-Ex", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-aff-2ac", title: "2AC", timerMode: .masterClock, durationSeconds: 8 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-neg-cx-2", title: "Cross-Ex", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-neg-block-1", title: "2NC", timerMode: .masterClock, durationSeconds: 8 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-aff-cx-2", title: "Cross-Ex", timerMode: .masterClock, durationSeconds: 3 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-neg-block-2", title: "1NR", timerMode: .masterClock, durationSeconds: 5 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-aff-1ar", title: "1AR", timerMode: .masterClock, durationSeconds: 5 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-neg-2nr", title: "2NR", timerMode: .masterClock, durationSeconds: 5 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true),
            DebateSegment(id: "pol-aff-2ar", title: "2AR", timerMode: .masterClock, durationSeconds: 5 * 60, startingSide: nil, allowsSideSwitching: false, autoPauseAtEnd: true, startsPaused: true)
        ],
        prepSecondsPerSide: 5 * 60,
        defaultScoreTrackingEnabled: false,
        defaultPlayerTrackingEnabled: false
    )

    static let allPresets: [DebatePreset] = [
        .publicForum,
        .lincolnDouglas,
        .policy
    ]

    static func preset(id: String) -> DebatePreset {
        allPresets.first(where: { $0.id == id }) ?? .publicForum
    }
}

enum DebateActiveTimer: String, Codable, Sendable {
    case segment
    case prepHome
    case prepGuest
}
