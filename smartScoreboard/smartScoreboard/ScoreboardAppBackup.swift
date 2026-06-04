import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let scoreboardBackup = UTType(exportedAs: "com.ironmaple.smartscoreboard.backup", conformingTo: .json)
}

struct ScoreboardBackupFile: Codable, Sendable {
    var filename: String
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
    var logSessions: [ScoreboardBackupFile]

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

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "Unsupported backup schema version \(version)."
        case .invalidFilename(let filename):
            return "Backup contains an invalid filename: \(filename)."
        case .invalidPersistedState:
            return "Backup contains invalid persisted app state."
        }
    }
}
