import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let scoreboardGame = UTType(exportedAs: "com.ironmaple.smartscoreboard.game", conformingTo: .json)
}

struct ScoreboardGameSnapshot: Sendable {
    var fileVersion = 2
    var homeTeamName: String
    var guestTeamName: String
    var homeScore: Int
    var guestScore: Int
    var period: Int
    var gameClockSeconds: Int
    var defaultClockSeconds: Int
    var shotClockMilliseconds: Int
    var defaultShotClockSeconds: Int
    var possessionDirection: PossessionDirection
    var areSidesSwapped: Bool

    static let empty = ScoreboardGameSnapshot(
        homeTeamName: "",
        guestTeamName: "",
        homeScore: 0,
        guestScore: 0,
        period: 1,
        gameClockSeconds: 12 * 60,
        defaultClockSeconds: 12 * 60,
        shotClockMilliseconds: 24_000,
        defaultShotClockSeconds: 24,
        possessionDirection: .none,
        areSidesSwapped: false
    )
}

extension ScoreboardGameSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case fileVersion
        case homeTeamName
        case guestTeamName
        case homeScore
        case guestScore
        case period
        case gameClockSeconds
        case defaultClockSeconds
        case shotClockMilliseconds
        case defaultShotClockSeconds
        case possessionDirection
        case areSidesSwapped
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileVersion = try container.decodeIfPresent(Int.self, forKey: .fileVersion) ?? 1
        homeTeamName = try container.decode(String.self, forKey: .homeTeamName)
        guestTeamName = try container.decode(String.self, forKey: .guestTeamName)
        homeScore = try container.decode(Int.self, forKey: .homeScore)
        guestScore = try container.decode(Int.self, forKey: .guestScore)
        period = try container.decode(Int.self, forKey: .period)
        gameClockSeconds = try container.decode(Int.self, forKey: .gameClockSeconds)
        defaultClockSeconds = try container.decode(Int.self, forKey: .defaultClockSeconds)
        shotClockMilliseconds = try container.decode(Int.self, forKey: .shotClockMilliseconds)
        defaultShotClockSeconds = try container.decode(Int.self, forKey: .defaultShotClockSeconds)
        possessionDirection = try container.decodeIfPresent(PossessionDirection.self, forKey: .possessionDirection) ?? .none
        areSidesSwapped = try container.decodeIfPresent(Bool.self, forKey: .areSidesSwapped) ?? false
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileVersion, forKey: .fileVersion)
        try container.encode(homeTeamName, forKey: .homeTeamName)
        try container.encode(guestTeamName, forKey: .guestTeamName)
        try container.encode(homeScore, forKey: .homeScore)
        try container.encode(guestScore, forKey: .guestScore)
        try container.encode(period, forKey: .period)
        try container.encode(gameClockSeconds, forKey: .gameClockSeconds)
        try container.encode(defaultClockSeconds, forKey: .defaultClockSeconds)
        try container.encode(shotClockMilliseconds, forKey: .shotClockMilliseconds)
        try container.encode(defaultShotClockSeconds, forKey: .defaultShotClockSeconds)
        try container.encode(possessionDirection, forKey: .possessionDirection)
        try container.encode(areSidesSwapped, forKey: .areSidesSwapped)
    }
}

struct ScoreboardGameDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.scoreboardGame] }

    var snapshot: ScoreboardGameSnapshot

    init(snapshot: ScoreboardGameSnapshot) {
        self.snapshot = snapshot
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        snapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(snapshot)
        return .init(regularFileWithContents: data)
    }
}
