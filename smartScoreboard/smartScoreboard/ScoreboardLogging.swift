import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let scoreboardLogSessionsDidChange = Notification.Name("scoreboardLogSessionsDidChange")
}

extension UTType {
    static let scoreboardLogSession = UTType(exportedAs: "com.ironmaple.smartscoreboard.log-session", conformingTo: .json)
}

enum ScoreboardLogOutcome: String, Codable, CaseIterable, Sendable {
    case applied
    case ignored
    case failed

    var title: String { rawValue.capitalized }
}

enum ScoreboardLogOperationKind: String, Codable, CaseIterable, Sendable {
    case scoreAdjustment
    case scoresReset
    case clockToggle
    case clockExpired
    case clockAdjustment
    case clockReset
    case periodAdjustment
    case shotClockAssignment
    case shotClockToggle
    case shotClockExpired
    case shotClockAdjustment
    case shotClockReset
    case possessionChange
    case sideSwap
    case substitutionsAdjustment
    case playerFoulAdjustment
    case playerFoulReset
    case playerFoulResetAll
    case playerCardSet
    case playerCardReset
    case playerCardResetAll
    case teamFoulAdjustment
    case teamFoulReset
    case teamFoulResetAll
    case lineupToggle
    case playerOverlayToggle
    case fileCreate
    case fileImport
    case fileLoad
    case fileExport
    case fileDelete

    var title: String {
        switch self {
        case .scoreAdjustment:
            return "Score Change"
        case .scoresReset:
            return "Zero Scores"
        case .clockToggle:
            return "Game Clock Toggle"
        case .clockExpired:
            return "Game Clock Expired"
        case .clockAdjustment:
            return "Game Clock Adjust"
        case .clockReset:
            return "Game Clock Reset"
        case .periodAdjustment:
            return "Period Change"
        case .shotClockAssignment:
            return "Shot Clock Preset"
        case .shotClockToggle:
            return "Shot Clock Toggle"
        case .shotClockExpired:
            return "Shot Clock Expired"
        case .shotClockAdjustment:
            return "Shot Clock Adjust"
        case .shotClockReset:
            return "Shot Clock Reset"
        case .possessionChange:
            return "Possession Change"
        case .sideSwap:
            return "Swap Sides"
        case .substitutionsAdjustment:
            return "Substitution Swap"
        case .playerFoulAdjustment:
            return "Player Foul Change"
        case .playerFoulReset:
            return "Player Foul Reset"
        case .playerFoulResetAll:
            return "Player Fouls Reset"
        case .playerCardSet:
            return "Player Card"
        case .playerCardReset:
            return "Player Cards Reset"
        case .playerCardResetAll:
            return "All Cards Reset"
        case .teamFoulAdjustment:
            return "Team Foul Change"
        case .teamFoulReset:
            return "Team Fouls Reset"
        case .teamFoulResetAll:
            return "All Team Fouls Reset"
        case .lineupToggle:
            return "Lineup Toggle"
        case .playerOverlayToggle:
            return "Overlay Toggle"
        case .fileCreate:
            return "Game File Create"
        case .fileImport:
            return "Game File Import"
        case .fileLoad:
            return "Game File Load"
        case .fileExport:
            return "Game File Export"
        case .fileDelete:
            return "Game File Delete"
        }
    }
}

struct ScoreboardLogOperation: Codable, Sendable {
    var kind: ScoreboardLogOperationKind
    var summary: String
    var teamSide: TeamSide?
    var playerID: UUID?
    var playerNumber: String?
    var playerName: String?
    var delta: Int?
    var value: Int?
    var fileName: String?
    var notes: String?
}

struct ScoreboardLogContext: Codable, Sendable {
    var gameFileName: String?
    var gameFilePath: String?
    var sport: SportType
    var period: Int
    var isClockRunning: Bool
    var gameClockSeconds: Int
    var supportsShotClock: Bool
    var isShotClockRunning: Bool?
    var shotClockMilliseconds: Int?
    var homeTeamName: String
    var guestTeamName: String
    var homeScore: Int
    var guestScore: Int
}

struct ScoreboardLogEntry: Identifiable, Codable, Sendable {
    var id: UUID
    var timestamp: Date
    var operation: ScoreboardLogOperation
    var context: ScoreboardLogContext
    var outcome: ScoreboardLogOutcome
}

struct ScoreboardLogSession: Codable, Sendable {
    var fileVersion: Int
    var sessionID: UUID
    var startedAt: Date
    var lastUpdatedAt: Date
    var entries: [ScoreboardLogEntry]

    init(
        fileVersion: Int = 1,
        sessionID: UUID = UUID(),
        startedAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        entries: [ScoreboardLogEntry] = []
    ) {
        self.fileVersion = fileVersion
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.entries = entries
    }
}

struct StoredLogSession: Identifiable {
    let url: URL
    let modifiedAt: Date
    let session: ScoreboardLogSession

    var id: String { url.path }
    var startedAt: Date { session.startedAt }
    var lastUpdatedAt: Date { session.lastUpdatedAt }
    var eventCount: Int { session.entries.count }

    var displayName: String {
        session.startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var summaryLine: String {
        "\(eventCount) event\(eventCount == 1 ? "" : "s") • Last update \(session.lastUpdatedAt.formatted(date: .omitted, time: .shortened))"
    }

    var sportsLine: String {
        let sports = Set(session.entries.map(\.context.sport.title)).sorted()
        return sports.isEmpty ? "No sports captured" : sports.joined(separator: " • ")
    }

    var gameFilesLine: String {
        let gameFiles = Set(session.entries.compactMap(\.context.gameFileName)).sorted()
        if gameFiles.isEmpty {
            return "No game file captured"
        }

        if gameFiles.count == 1 {
            return gameFiles[0]
        }

        return "\(gameFiles[0]) +\(gameFiles.count - 1) more"
    }
}

struct ScoreboardLogExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.scoreboardLogSession, .json, .commaSeparatedText, .plainText]
    }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
final class ScoreboardLogManager {
    static let shared = ScoreboardLogManager()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var currentSessionURL: URL?
    private var currentSession: ScoreboardLogSession?
    private var currentGameFileURL: URL?

    private init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        startSession()
    }

    func startSession() {
        let now = Date()
        let session = ScoreboardLogSession(startedAt: now, lastUpdatedAt: now)
        let filename = sessionFilename(for: session)

        do {
            let directoryURL = try logsDirectory()
            let sessionURL = directoryURL.appendingPathComponent(filename).appendingPathExtension("scoreboardlog")
            currentSession = session
            currentSessionURL = sessionURL
            try persist(session, to: sessionURL)
            notifyChange()
        } catch {
            currentSession = session
            currentSessionURL = nil
            NSLog("ScoreboardLogManager failed to start session: %@", String(describing: error))
        }
    }

    func setCurrentGameFile(url: URL?) {
        currentGameFileURL = url
    }

    func record(
        operation: ScoreboardLogOperation,
        context: ScoreboardLogContext,
        outcome: ScoreboardLogOutcome
    ) {
        guard var session = currentSession else {
            return
        }

        let now = Date()
        let entry = ScoreboardLogEntry(
            id: UUID(),
            timestamp: now,
            operation: operation,
            context: mergedContext(from: context),
            outcome: outcome
        )

        session.entries.append(entry)
        session.lastUpdatedAt = now
        currentSession = session

        do {
            if let currentSessionURL {
                try persist(session, to: currentSessionURL)
            }
            notifyChange()
        } catch {
            NSLog("ScoreboardLogManager failed to persist entry: %@", String(describing: error))
        }
    }

    func listSessions() throws -> [StoredLogSession] {
        let directoryURL = try logsDirectory()
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { $0.pathExtension.lowercased() == "scoreboardlog" }
            .map { url in
                let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
                return StoredLogSession(
                    url: url,
                    modifiedAt: values.contentModificationDate ?? .distantPast,
                    session: try loadSession(from: url)
                )
            }
            .sorted {
                if $0.startedAt == $1.startedAt {
                    return $0.modifiedAt > $1.modifiedAt
                }

                return $0.startedAt > $1.startedAt
            }
    }

    func loadSession(from url: URL) throws -> ScoreboardLogSession {
        let data = try Data(contentsOf: url)
        return try decoder.decode(ScoreboardLogSession.self, from: data)
    }

    func deleteSession(at url: URL) throws {
        try fileManager.removeItem(at: url)

        if currentSessionURL == url {
            currentSession = nil
            currentSessionURL = nil
            startSession()
            return
        }

        notifyChange()
    }

    func exportJSONData(for session: ScoreboardLogSession) throws -> Data {
        try encoder.encode(session)
    }

    func exportCSVData(for session: ScoreboardLogSession) -> Data {
        let header = [
            "timestamp",
            "session_id",
            "game_file",
            "sport",
            "period",
            "game_clock_status",
            "game_clock_remaining",
            "shot_clock_status",
            "shot_clock_remaining",
            "home_team",
            "guest_team",
            "home_score",
            "guest_score",
            "operation_kind",
            "operation_title",
            "summary",
            "team_side",
            "player_number",
            "player_name",
            "delta",
            "value",
            "file_name",
            "outcome",
            "notes"
        ]

        var rows = [header.joined(separator: ",")]

        for entry in session.entries {
            let row = [
                csvField(entry.timestamp.ISO8601Format()),
                csvField(session.sessionID.uuidString),
                csvField(entry.context.gameFileName ?? ""),
                csvField(entry.context.sport.title),
                csvField("\(entry.context.period)"),
                csvField(entry.context.isClockRunning ? "running" : "stopped"),
                csvField(ScoreboardStore.formatGameClock(entry.context.gameClockSeconds)),
                csvField(shotClockStatus(for: entry.context)),
                csvField(shotClockValue(for: entry.context)),
                csvField(entry.context.homeTeamName),
                csvField(entry.context.guestTeamName),
                csvField("\(entry.context.homeScore)"),
                csvField("\(entry.context.guestScore)"),
                csvField(entry.operation.kind.rawValue),
                csvField(entry.operation.kind.title),
                csvField(entry.operation.summary),
                csvField(entry.operation.teamSide?.title ?? ""),
                csvField(entry.operation.playerNumber ?? ""),
                csvField(entry.operation.playerName ?? ""),
                csvField(entry.operation.delta.map(String.init) ?? ""),
                csvField(entry.operation.value.map(String.init) ?? ""),
                csvField(entry.operation.fileName ?? ""),
                csvField(entry.outcome.rawValue),
                csvField(entry.operation.notes ?? "")
            ]

            rows.append(row.joined(separator: ","))
        }

        return Data(rows.joined(separator: "\n").utf8)
    }

    private func logsDirectory() throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = baseDirectory.appendingPathComponent("ScoreboardLogs", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        return directoryURL
    }

    private func persist(_ session: ScoreboardLogSession, to url: URL) throws {
        let data = try encoder.encode(session)
        try data.write(to: url, options: .atomic)
    }

    private func mergedContext(from context: ScoreboardLogContext) -> ScoreboardLogContext {
        var merged = context

        if merged.gameFileName == nil {
            merged.gameFileName = currentGameFileURL?.deletingPathExtension().lastPathComponent
        }

        if merged.gameFilePath == nil {
            merged.gameFilePath = currentGameFileURL?.path
        }

        return merged
    }

    private func sessionFilename(for session: ScoreboardLogSession) -> String {
        let timestamp = session.startedAt.ISO8601Format()
            .replacingOccurrences(of: ":", with: "-")
        return "\(timestamp)-\(session.sessionID.uuidString)"
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .scoreboardLogSessionsDidChange, object: nil)
    }

    private func shotClockStatus(for context: ScoreboardLogContext) -> String {
        guard context.supportsShotClock else {
            return ""
        }

        return (context.isShotClockRunning ?? false) ? "running" : "stopped"
    }

    private func shotClockValue(for context: ScoreboardLogContext) -> String {
        guard context.supportsShotClock, let milliseconds = context.shotClockMilliseconds else {
            return ""
        }

        return ScoreboardStore.formatShotClock(milliseconds: milliseconds)
    }

    private func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
