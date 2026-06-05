import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let scoreboardBackup = UTType(exportedAs: "com.ironmaple.smartscoreboard.backup", conformingTo: .json)
}

struct ScoreboardBackupFile: Codable, Sendable {
    var filename: String
    var data: Data
}

struct ScoreboardBackupImageAsset: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case externalDisplayBackground
        case teamLogo
    }

    var kind: Kind
    var id: String
    var data: Data
}

struct ScoreboardAppBackup: Codable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var createdAt: Date
    var appVersion: String
    var selectedGameFilename: String?
    var persistedStateData: Data
    var storedGameFiles: [ScoreboardBackupFile]
    var imageAssets: [ScoreboardBackupImageAsset]
    var logSessions: [ScoreboardBackupFile]

    init(
        schemaVersion: Int,
        createdAt: Date,
        appVersion: String,
        selectedGameFilename: String?,
        persistedStateData: Data,
        storedGameFiles: [ScoreboardBackupFile],
        imageAssets: [ScoreboardBackupImageAsset] = [],
        logSessions: [ScoreboardBackupFile]
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.selectedGameFilename = selectedGameFilename
        self.persistedStateData = persistedStateData
        self.storedGameFiles = storedGameFiles
        self.imageAssets = imageAssets
        self.logSessions = logSessions
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case createdAt
        case appVersion
        case selectedGameFilename
        case persistedStateData
        case storedGameFiles
        case imageAssets
        case logSessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        selectedGameFilename = try container.decodeIfPresent(String.self, forKey: .selectedGameFilename)
        persistedStateData = try container.decode(Data.self, forKey: .persistedStateData)
        storedGameFiles = try container.decode([ScoreboardBackupFile].self, forKey: .storedGameFiles)
        imageAssets = try container.decodeIfPresent([ScoreboardBackupImageAsset].self, forKey: .imageAssets) ?? []
        logSessions = try container.decode([ScoreboardBackupFile].self, forKey: .logSessions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encodeIfPresent(selectedGameFilename, forKey: .selectedGameFilename)
        try container.encode(persistedStateData, forKey: .persistedStateData)
        try container.encode(storedGameFiles, forKey: .storedGameFiles)
        try container.encode(imageAssets, forKey: .imageAssets)
        try container.encode(logSessions, forKey: .logSessions)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func validateSchema() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ScoreboardBackupError.unsupportedSchema(schemaVersion)
        }
    }
}

enum ScoreboardBackupError: LocalizedError {
    case unsupportedSchema(Int)
    case invalidFilename(String)
    case invalidPersistedState
    case invalidImageAsset

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "Unsupported backup schema version \(version)."
        case .invalidFilename(let filename):
            return "Backup contains an invalid filename: \(filename)."
        case .invalidPersistedState:
            return "Backup contains invalid persisted app state."
        case .invalidImageAsset:
            return "Backup contains an invalid image asset."
        }
    }
}
