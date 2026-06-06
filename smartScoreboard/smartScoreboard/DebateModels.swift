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
    var speakingSide: TeamSide?
    var startingSide: TeamSide?
    var allowsSideSwitching: Bool
    var autoPauseAtEnd: Bool
    var startsPaused: Bool

    init(
        id: String,
        title: String,
        timerMode: DebateTimerMode,
        durationSeconds: Int,
        speakingSide: TeamSide? = nil,
        startingSide: TeamSide?,
        allowsSideSwitching: Bool,
        autoPauseAtEnd: Bool,
        startsPaused: Bool
    ) {
        self.id = id
        self.title = title
        self.timerMode = timerMode
        self.durationSeconds = durationSeconds
        self.speakingSide = speakingSide ?? Self.inferredSpeakingSide(id: id, title: title)
        self.startingSide = startingSide
        self.allowsSideSwitching = allowsSideSwitching
        self.autoPauseAtEnd = autoPauseAtEnd
        self.startsPaused = startsPaused
    }

    private static func inferredSpeakingSide(id: String, title: String) -> TeamSide? {
        let normalizedID = id.lowercased()
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedID.contains("-aff-") || normalizedID.contains("-aff") || normalizedTitle.hasPrefix("aff ") || normalizedTitle.hasPrefix("aff-") {
            return .home
        }

        if normalizedID.contains("-neg-") || normalizedID.contains("-neg") || normalizedTitle.hasPrefix("neg ") || normalizedTitle.hasPrefix("neg-") {
            return .guest
        }

        return nil
    }
}

struct DebatePreset: Identifiable, Codable, Equatable, Sendable {
    static let customID = "custom-debate"

    var id: String
    var title: String
    var homeSideLabel: String
    var guestSideLabel: String
    var segments: [DebateSegment]
    var prepSecondsPerSide: Int
    var isPrepTimeEnabled: Bool
    var defaultScoreTrackingEnabled: Bool
    var defaultPlayerTrackingEnabled: Bool
    var defaultPlayerFoulsEnabled: Bool
    var defaultPlayerCardsEnabled: Bool

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
        isPrepTimeEnabled: true,
        defaultScoreTrackingEnabled: false,
        defaultPlayerTrackingEnabled: false,
        defaultPlayerFoulsEnabled: false,
        defaultPlayerCardsEnabled: false
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
        isPrepTimeEnabled: true,
        defaultScoreTrackingEnabled: false,
        defaultPlayerTrackingEnabled: false,
        defaultPlayerFoulsEnabled: false,
        defaultPlayerCardsEnabled: false
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
        isPrepTimeEnabled: true,
        defaultScoreTrackingEnabled: false,
        defaultPlayerTrackingEnabled: false,
        defaultPlayerFoulsEnabled: false,
        defaultPlayerCardsEnabled: false
    )

    static let customDefault = DebatePreset(
        id: customID,
        title: "Custom Debate",
        homeSideLabel: "Aff",
        guestSideLabel: "Neg",
        segments: [
            DebateSegment(
                id: "custom-segment-1",
                title: "Constructive",
                timerMode: .masterClock,
                durationSeconds: 4 * 60,
                startingSide: nil,
                allowsSideSwitching: false,
                autoPauseAtEnd: true,
                startsPaused: true
            )
        ],
        prepSecondsPerSide: 2 * 60,
        isPrepTimeEnabled: true,
        defaultScoreTrackingEnabled: false,
        defaultPlayerTrackingEnabled: false,
        defaultPlayerFoulsEnabled: false,
        defaultPlayerCardsEnabled: false
    )

    static let builtInPresets: [DebatePreset] = [
        .publicForum,
        .lincolnDouglas,
        .policy
    ]

    static let allPresets: [DebatePreset] = builtInPresets
    static let selectablePresetIDs: [String] = builtInPresets.map(\.id) + [customID]

    static func preset(id: String) -> DebatePreset {
        builtInPresets.first(where: { $0.id == id }) ?? .publicForum
    }
}

extension DebatePreset {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case homeSideLabel
        case guestSideLabel
        case segments
        case prepSecondsPerSide
        case isPrepTimeEnabled
        case defaultScoreTrackingEnabled
        case defaultPlayerTrackingEnabled
        case defaultPlayerFoulsEnabled
        case defaultPlayerCardsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        homeSideLabel = try container.decode(String.self, forKey: .homeSideLabel)
        guestSideLabel = try container.decode(String.self, forKey: .guestSideLabel)
        segments = try container.decode([DebateSegment].self, forKey: .segments)
        prepSecondsPerSide = try container.decode(Int.self, forKey: .prepSecondsPerSide)
        isPrepTimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPrepTimeEnabled) ?? true
        defaultScoreTrackingEnabled = try container.decode(Bool.self, forKey: .defaultScoreTrackingEnabled)
        defaultPlayerTrackingEnabled = try container.decode(Bool.self, forKey: .defaultPlayerTrackingEnabled)
        defaultPlayerFoulsEnabled = try container.decodeIfPresent(Bool.self, forKey: .defaultPlayerFoulsEnabled) ?? false
        defaultPlayerCardsEnabled = try container.decodeIfPresent(Bool.self, forKey: .defaultPlayerCardsEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(homeSideLabel, forKey: .homeSideLabel)
        try container.encode(guestSideLabel, forKey: .guestSideLabel)
        try container.encode(segments, forKey: .segments)
        try container.encode(prepSecondsPerSide, forKey: .prepSecondsPerSide)
        try container.encode(isPrepTimeEnabled, forKey: .isPrepTimeEnabled)
        try container.encode(defaultScoreTrackingEnabled, forKey: .defaultScoreTrackingEnabled)
        try container.encode(defaultPlayerTrackingEnabled, forKey: .defaultPlayerTrackingEnabled)
        try container.encode(defaultPlayerFoulsEnabled, forKey: .defaultPlayerFoulsEnabled)
        try container.encode(defaultPlayerCardsEnabled, forKey: .defaultPlayerCardsEnabled)
    }
}

enum DebateActiveTimer: String, Codable, Sendable {
    case segment
    case prepHome
    case prepGuest
}
