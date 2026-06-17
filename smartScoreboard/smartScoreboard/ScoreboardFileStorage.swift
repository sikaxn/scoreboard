import Foundation

struct ScoreboardFileMigrationProgress: Sendable, Equatable {
    var completedFiles: Int
    var totalFiles: Int
    var currentFilename: String?
}

struct ScoreboardFileMigrationResult: Sendable, Equatable {
    var migratedFiles: Int
    var failedFiles: Int
    var totalFiles: Int
}

enum ScoreboardFileStorage {
    static let filesAppContainerName = "Scoreboard"
    static let gameLibraryDirectoryName = "Library"
    static let logsDirectoryName = "Logs"
    static let customWebPageDirectoryName = "CustomWebPage"

    private static let legacyStoredGamesDirectoryName = "StoredGames"
    private static let legacyLogsDirectoryName = "ScoreboardLogs"

    static func storedGamesDirectory(create: Bool = true) throws -> URL {
        try localFilesDirectory(
            visibleDirectoryName: gameLibraryDirectoryName,
            fallbackDirectoryName: legacyStoredGamesDirectoryName,
            create: create
        )
    }

    static func logsDirectory(create: Bool = true) throws -> URL {
        try localFilesDirectory(
            visibleDirectoryName: logsDirectoryName,
            fallbackDirectoryName: legacyLogsDirectoryName,
            create: create
        )
    }

    static func migrateLegacyFilesToUserVisibleStorage(
        progress: (@MainActor @Sendable (ScoreboardFileMigrationProgress) -> Void)? = nil
    ) async throws -> ScoreboardFileMigrationResult {
        #if os(iOS)
        return try await Task.detached(priority: .utility) {
            try await migrateLegacyFilesToUserVisibleStorageSynchronously(progress: progress)
        }.value
        #else
        return ScoreboardFileMigrationResult(migratedFiles: 0, failedFiles: 0, totalFiles: 0)
        #endif
    }

    private static func localFilesDirectory(
        visibleDirectoryName: String,
        fallbackDirectoryName: String,
        create: Bool
    ) throws -> URL {
        let fileManager = FileManager.default

        #if os(iOS)
        let baseDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = baseDirectory.appendingPathComponent(visibleDirectoryName, isDirectory: true)
        #else
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = baseDirectory.appendingPathComponent(fallbackDirectoryName, isDirectory: true)
        #endif

        if create {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        return directoryURL
    }

    #if os(iOS)
    private struct LegacyMigrationSpec {
        var legacyDirectoryName: String
        var visibleDirectoryName: String
    }

    private struct LegacyMigrationItem {
        var sourceURL: URL
        var destinationDirectory: URL
    }

    private static func migrateLegacyFilesToUserVisibleStorageSynchronously(
        progress: (@MainActor @Sendable (ScoreboardFileMigrationProgress) -> Void)?
    ) async throws -> ScoreboardFileMigrationResult {
        let specs = [
            LegacyMigrationSpec(
                legacyDirectoryName: legacyStoredGamesDirectoryName,
                visibleDirectoryName: gameLibraryDirectoryName
            ),
            LegacyMigrationSpec(
                legacyDirectoryName: legacyLogsDirectoryName,
                visibleDirectoryName: logsDirectoryName
            )
        ]

        let fileManager = FileManager.default
        let legacyBaseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let visibleBaseDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        var items: [LegacyMigrationItem] = []
        var legacyDirectoriesToClean: [URL] = []

        for spec in specs {
            let legacyDirectory = legacyBaseDirectory.appendingPathComponent(spec.legacyDirectoryName, isDirectory: true)
            let visibleDirectory = visibleBaseDirectory.appendingPathComponent(spec.visibleDirectoryName, isDirectory: true)

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: legacyDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            try appendRecursiveMigrationItems(
                from: legacyDirectory,
                to: visibleDirectory,
                items: &items
            )
            legacyDirectoriesToClean.append(legacyDirectory)
        }

        #if ENABLE_CUSTOM_USER_PAGE
        let legacyCustomWebPageDirectory = legacyBaseDirectory.appendingPathComponent(customWebPageDirectoryName, isDirectory: true)
        let visibleCustomWebPageDirectory = visibleBaseDirectory.appendingPathComponent(customWebPageDirectoryName, isDirectory: true)
        var isCustomWebPageDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: legacyCustomWebPageDirectory.path, isDirectory: &isCustomWebPageDirectory),
           isCustomWebPageDirectory.boolValue {
            try appendRecursiveMigrationItems(
                from: legacyCustomWebPageDirectory,
                to: visibleCustomWebPageDirectory,
                items: &items
            )
            legacyDirectoriesToClean.append(legacyCustomWebPageDirectory)
        }
        #endif

        guard !items.isEmpty else {
            try removeLegacyDirectoriesIfPossible(legacyDirectoriesToClean)
            return ScoreboardFileMigrationResult(migratedFiles: 0, failedFiles: 0, totalFiles: 0)
        }

        await progress?(ScoreboardFileMigrationProgress(completedFiles: 0, totalFiles: items.count, currentFilename: nil))

        var migratedFiles = 0
        var failedFiles = 0
        for item in items {
            await progress?(ScoreboardFileMigrationProgress(
                completedFiles: migratedFiles + failedFiles,
                totalFiles: items.count,
                currentFilename: item.sourceURL.lastPathComponent
            ))

            do {
                let destinationURL = uniqueDestinationURL(for: item.sourceURL.lastPathComponent, in: item.destinationDirectory)
                try fileManager.moveItem(at: item.sourceURL, to: destinationURL)
                migratedFiles += 1
            } catch {
                failedFiles += 1
                NSLog("Scoreboard failed to migrate file %@: %@", item.sourceURL.path, String(describing: error))
            }

            await progress?(ScoreboardFileMigrationProgress(completedFiles: migratedFiles + failedFiles, totalFiles: items.count, currentFilename: nil))
        }

        if failedFiles == 0 {
            try removeLegacyDirectoriesIfPossible(legacyDirectoriesToClean)
        }

        return ScoreboardFileMigrationResult(migratedFiles: migratedFiles, failedFiles: failedFiles, totalFiles: items.count)
    }

    private static func removeLegacyDirectoriesIfPossible(_ directories: [URL]) throws {
        let fileManager = FileManager.default
        for directory in directories where fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    private static func appendRecursiveMigrationItems(
        from legacyDirectory: URL,
        to visibleDirectory: URL,
        items: inout [LegacyMigrationItem]
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: visibleDirectory, withIntermediateDirectories: true, attributes: nil)

        guard let enumerator = fileManager.enumerator(
            at: legacyDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return
        }

        for case let sourceURL as URL in enumerator {
            let values = try sourceURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory != true else {
                continue
            }

            let parentDirectory = sourceURL.deletingLastPathComponent()
            let legacyPathPrefix = legacyDirectory.path + "/"
            let trimmedRelativeParentPath = parentDirectory.path.hasPrefix(legacyPathPrefix)
                ? String(parentDirectory.path.dropFirst(legacyPathPrefix.count))
                : ""
            let destinationDirectory = trimmedRelativeParentPath.isEmpty
                ? visibleDirectory
                : visibleDirectory.appendingPathComponent(trimmedRelativeParentPath, isDirectory: true)
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
            items.append(LegacyMigrationItem(sourceURL: sourceURL, destinationDirectory: destinationDirectory))
        }
    }

    private static func uniqueDestinationURL(for filename: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        let filenameNSString = filename as NSString
        let baseName = filenameNSString.deletingPathExtension
        let pathExtension = filenameNSString.pathExtension
        var candidateURL = directory.appendingPathComponent(baseName).appendingPathExtension(pathExtension)
        var suffix = 2

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = directory.appendingPathComponent("\(baseName) \(suffix)").appendingPathExtension(pathExtension)
            suffix += 1
        }

        return candidateURL
    }
    #endif
}
