import Foundation
import Combine

nonisolated enum ScoreboardDeviceMode: String, CaseIterable, Identifiable {
    case app, kiosk
    static let preferenceKey = "scoreboard.deviceMode.v2"
    var id: String { rawValue }
    var title: String { self == .app ? "App Mode" : "Kiosk Mode" }
    var canCreateScoreboards: Bool { self == .app }
    var canHost: Bool { self == .app }
    @MainActor static var current: Self {
        #if os(tvOS)
        .kiosk
        #else
        Self(rawValue: ScoreboardPreferences.current.string(forKey: preferenceKey) ?? "app") ?? .app
        #endif
    }
}

nonisolated enum ScoreboardMatchWorkspace: Equatable {
    case personal
    case joining
    case participant(displayOnly: Bool)
    case venueHost

    var presentsSharedMatch: Bool {
        switch self {
        case .personal, .joining: false
        case .participant, .venueHost: true
        }
    }
}

nonisolated struct ScoreboardMatchRecord: Codable, Equatable, Sendable {
    var matchID: UUID
    var runtimeID = UUID()
    var cloudEnabled = false
    var serviceURL: String? = nil
    var cloudSessionID: String? = nil
    var filePath: String? = nil
    var lastHostDeviceID: String? = nil
    var authorityEpoch: UInt64? = nil
    var logSessionID: UUID? = nil
    var logSessionIDs: [UUID]? = nil
}

@MainActor enum ScoreboardMatchIndex {
    private static let key = "scoreboard.matchIndex.v1"
    static func record(for id: UUID) -> ScoreboardMatchRecord {
        records()[id.uuidString] ?? ScoreboardMatchRecord(matchID: id)
    }
    private static func records() -> [String: ScoreboardMatchRecord] {
        guard let data = ScoreboardPreferences.current.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: ScoreboardMatchRecord].self, from: data)) ?? [:]
    }
    static func save(_ record: ScoreboardMatchRecord) {
        var values = records()
        guard values[record.matchID.uuidString] != record else { return }
        values[record.matchID.uuidString] = record
        if let data = try? JSONEncoder().encode(values) { ScoreboardPreferences.current.set(data, forKey: key) }
    }
    static func remove(_ id: UUID) {
        var values = records(); values.removeValue(forKey: id.uuidString)
        if let data = try? JSONEncoder().encode(values) { ScoreboardPreferences.current.set(data, forKey: key) }
    }
}

extension ScoreboardGameSnapshot {
    nonisolated func asNewMatch(ownerDeviceID: String) -> Self {
        var copy = self
        copy.fileVersion = 13; copy.matchID = UUID(); copy.ownerDeviceID = ownerDeviceID
        return copy
    }
}

nonisolated struct ScoreboardLibraryEntry: Identifiable, Sendable {
    var id: String { url.path }
    var url: URL
    var modifiedAt: Date
    var matchID: UUID?
    var title: String { url.deletingPathExtension().lastPathComponent }
    var home: String
    var guest: String
    var homeScore: Int
    var guestScore: Int
    var sport: SportType?
    var loadError: String? = nil
}

nonisolated enum ScoreboardMatchFiles {
    static func load(_ url: URL, ownerDeviceID: String) throws -> ScoreboardGameSnapshot {
        var snapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: url))
        if snapshot.matchID == nil || (snapshot.ownerDeviceID != nil && snapshot.ownerDeviceID != ownerDeviceID) {
            // Opening/migrating is explicit. Merely listing the Library never rewrites a file.
            let backup = url.appendingPathExtension("identity-backup")
            if !FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.copyItem(at: url, to: backup) }
            snapshot = snapshot.asNewMatch(ownerDeviceID: ownerDeviceID)
            try write(snapshot, to: url)
        }
        return snapshot
    }
    static func write(_ snapshot: ScoreboardGameSnapshot, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }
    static func destination(named name: String) throws -> URL {
        let safe = name.components(separatedBy: CharacterSet(charactersIn: "/\\:\n\r")).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = safe.isEmpty ? "Untitled Match" : String(safe.prefix(100))
        let folder = try ScoreboardFileStorage.storedGamesDirectory()
        var candidate = folder.appendingPathComponent(base).appendingPathExtension("scoreboardgame")
        var count = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(count)").appendingPathExtension("scoreboardgame"); count += 1
        }
        return candidate
    }
    static func entries(ownerDeviceID: String) throws -> [ScoreboardLibraryEntry] {
        let folder = try ScoreboardFileStorage.storedGamesDirectory()
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
            .filter { $0.pathExtension.lowercased() == "scoreboardgame" }.compactMap { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                do {
                    let snapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: url))
                    return ScoreboardLibraryEntry(url: url, modifiedAt: modified, matchID: snapshot.matchID,
                        home: snapshot.homeTeamName, guest: snapshot.guestTeamName,
                        homeScore: snapshot.homeScore, guestScore: snapshot.guestScore, sport: snapshot.sport)
                } catch {
                    return ScoreboardLibraryEntry(url: url, modifiedAt: modified, matchID: nil,
                        home: "", guest: "", homeScore: 0, guestScore: 0, sport: nil, loadError: error.localizedDescription)
                }
            }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}

/// The personal Library is independent of view lifetime and received guest state.
@MainActor final class ScoreboardMatchRepository: ObservableObject {
    @Published private(set) var entries: [ScoreboardLibraryEntry] = []
    @Published private(set) var saveError: String?
    @Published private(set) var lastSavedAt: Date?
    @Published private(set) var workingMatchID: UUID?
    var workingMatch: ScoreboardLibraryEntry? { entries.first { $0.matchID == workingMatchID && workingMatchID != nil } }
    private weak var store: ScoreboardStore?
    private var changes: AnyCancellable?
    private(set) var isStarted = false
    private var isSwitching = false
    private var hasOpenDocument = false

    init(store: ScoreboardStore) { self.store = store }

    func start() throws {
        guard !isStarted, let store, !store.isRemoteControlProxy, ScoreboardDeviceMode.current.canCreateScoreboards else { return }
        try refresh()
        // Recover the previous working file without loading an arbitrary first row.
        let legacyName = ScoreboardPreferences.current.string(forKey: "scoreboard.workingGameFilename")
        for entry in entries where entry.loadError == nil {
            var snapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: entry.url))
            if snapshot.matchID == nil, entry.url.lastPathComponent == legacyName, !store.isDelegatedSessionHost {
                let backup = entry.url.appendingPathExtension("identity-backup")
                if !FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.copyItem(at: entry.url, to: backup) }
                snapshot.matchID = store.currentMatchID; snapshot.ownerDeviceID = store.localSessionDeviceID
                snapshot.fileVersion = 13
                try ScoreboardMatchFiles.write(snapshot, to: entry.url)
            } else {
                snapshot = try ScoreboardMatchFiles.load(entry.url, ownerDeviceID: store.localSessionDeviceID)
            }
            if let id = snapshot.matchID, let known = ScoreboardMatchIndex.record(for: id).filePath,
               FileManager.default.fileExists(atPath: known),
               URL(fileURLWithPath: known).resolvingSymlinksInPath() != entry.url.resolvingSymlinksInPath() {
                let backup = entry.url.appendingPathExtension("identity-backup")
                if !FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.copyItem(at: entry.url, to: backup) }
                snapshot = snapshot.asNewMatch(ownerDeviceID: store.localSessionDeviceID)
                try ScoreboardMatchFiles.write(snapshot, to: entry.url)
            }
            if let id = snapshot.matchID {
                var record = ScoreboardMatchIndex.record(for: id); record.filePath = entry.url.path
                ScoreboardMatchIndex.save(record)
            }
        }
        hasOpenDocument = store.didCompleteSetup || entries.contains { $0.matchID == store.currentMatchID }
        workingMatchID = hasOpenDocument ? store.currentMatchID : nil
        // Retain a parked personal document when migrating a previous venue-host installation.
        if store.isDelegatedSessionHost { workingMatchID = entries.first(where: { $0.url.lastPathComponent == legacyName })?.matchID }
        isStarted = true
        changes = store.objectWillChange
            .throttle(for: .seconds(5), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveAfterChange() }
        try save()
        try refresh()
        if store.isDelegatedSessionHost { workingMatchID = entries.first(where: { $0.url.lastPathComponent == legacyName })?.matchID }
    }

    func refresh() throws {
        guard let store else { return }
        entries = try ScoreboardMatchFiles.entries(ownerDeviceID: store.localSessionDeviceID)
    }

    func save() throws {
        guard ScoreboardDeviceMode.current.canCreateScoreboards else { return }
        guard isStarted, !isSwitching, let store, !store.isRemoteControlProxy,
              !store.isJoinedMatchActive, !store.isPreparingMatchJoin, !store.isDelegatedSessionHost else { return }
        guard hasOpenDocument || store.didCompleteSetup else { return }
        hasOpenDocument = true
        do {
            var record = store.currentMatchRecord
            let folder = try ScoreboardFileStorage.storedGamesDirectory()
            let existing = record.filePath.map { URL(fileURLWithPath: $0) }
            let url: URL
            if let existing, existing.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == folder.resolvingSymlinksInPath().standardizedFileURL {
                url = existing
            } else {
                url = try ScoreboardMatchFiles.destination(named: store.currentMatchTitle)
            }
            if FileManager.default.fileExists(atPath: url.path) {
                let saved = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: url))
                guard saved.matchID == store.currentMatchID else {
                    throw NSError(domain: "ScoreboardLibrary", code: 409, userInfo: [NSLocalizedDescriptionKey: "This file belongs to another match. Export a copy or choose another file."])
                }
            }
            let snapshot = store.currentGameSnapshot()
            try ScoreboardMatchFiles.write(snapshot, to: url)
            record.filePath = url.path
            if let logID = ScoreboardLogManager.shared.currentSessionSnapshot()?.sessionID {
                var logs = record.logSessionIDs ?? record.logSessionID.map { [$0] } ?? []
                if !logs.contains(logID) { logs.append(logID) }
                record.logSessionID = logID; record.logSessionIDs = logs
            }
            ScoreboardMatchIndex.save(record)
            ScoreboardPreferences.current.set(url.lastPathComponent, forKey: "scoreboard.workingGameFilename")
            ScoreboardLogManager.shared.setCurrentGameFile(url: url)
            saveError = nil; lastSavedAt = Date()
            workingMatchID = store.currentMatchID
            let entry = ScoreboardLibraryEntry(url: url, modifiedAt: lastSavedAt!, matchID: snapshot.matchID,
                home: snapshot.homeTeamName, guest: snapshot.guestTeamName, homeScore: snapshot.homeScore,
                guestScore: snapshot.guestScore, sport: snapshot.sport)
            entries.removeAll { $0.url.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() }
            entries.insert(entry, at: 0)
        } catch { saveError = error.localizedDescription; throw error }
    }

    func saveAfterChange() {
        do { try save() } catch { /* Observable saveError keeps failures visible and retryable. */ }
    }

    func reconcileAfterRestore() throws {
        changes = nil; isStarted = false
        try start()
    }

    func resume(_ entry: ScoreboardLibraryEntry) throws {
        guard let store else { return }
        if entry.matchID == store.currentMatchID { return }
        try store.requireMatchReplacementAllowed()
        try save()
        let snapshot = try ScoreboardMatchFiles.load(entry.url, ownerDeviceID: store.localSessionDeviceID)
        isSwitching = true
        defer { isSwitching = false }
        try store.openLibraryMatch(snapshot, url: entry.url)
        hasOpenDocument = true; workingMatchID = store.currentMatchID
        store.startLocalMatchLog()
        saveError = nil
    }

    func newMatch(from entry: ScoreboardLibraryEntry? = nil, keepLocalDevices: Bool = true) throws {
        guard let store else { return }
        try store.requireNewLocalMatchAllowed()
        try save()
        let setup = try entry.map { try ScoreboardMatchFiles.load($0.url, ownerDeviceID: store.localSessionDeviceID) }
        if !keepLocalDevices { store.disconnectRemoteDisplays() }
        isSwitching = true
        defer { isSwitching = false }
        if let setup { store.applyGameSnapshot(setup.asNewMatch(ownerDeviceID: store.localSessionDeviceID)) }
        store.newGame()
        store.setCurrentGameDisplayName(nil)
        hasOpenDocument = true
        isSwitching = false
        try save(); try refresh()
    }

    func importCopy(_ source: URL) throws {
        guard let store else { return }
        let copy = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: source))
            .asNewMatch(ownerDeviceID: store.localSessionDeviceID)
        let url = try ScoreboardMatchFiles.destination(named: source.deletingPathExtension().lastPathComponent)
        try ScoreboardMatchFiles.write(copy, to: url)
        var record = ScoreboardMatchIndex.record(for: copy.matchID!); record.filePath = url.path
        ScoreboardMatchIndex.save(record); try refresh()
    }

    func duplicate(_ entry: ScoreboardLibraryEntry) throws {
        guard let store else { return }
        if entry.matchID == store.currentMatchID { try save() }
        let copy = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: entry.url))
            .asNewMatch(ownerDeviceID: store.localSessionDeviceID)
        let url = try ScoreboardMatchFiles.destination(named: entry.title + " Copy")
        try ScoreboardMatchFiles.write(copy, to: url)
        var record = ScoreboardMatchIndex.record(for: copy.matchID!); record.filePath = url.path
        ScoreboardMatchIndex.save(record); try refresh()
    }

    func rename(_ entry: ScoreboardLibraryEntry, to name: String) throws {
        guard let store else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != entry.title else { return }
        if entry.matchID == store.currentMatchID { try save() }
        let url = try ScoreboardMatchFiles.destination(named: trimmed)
        try FileManager.default.moveItem(at: entry.url, to: url)
        if let id = entry.matchID {
            var record = ScoreboardMatchIndex.record(for: id); record.filePath = url.path; ScoreboardMatchIndex.save(record)
            if id == store.currentMatchID {
                store.setCurrentGameDisplayName(url.deletingPathExtension().lastPathComponent)
                ScoreboardPreferences.current.set(url.lastPathComponent, forKey: "scoreboard.workingGameFilename")
            }
        }
        try refresh()
    }

    func delete(_ entry: ScoreboardLibraryEntry) throws {
        guard entry.matchID != store?.currentMatchID, entry.matchID != workingMatchID else {
            throw NSError(domain: "ScoreboardLibrary", code: 409, userInfo: [NSLocalizedDescriptionKey: "Open another match before deleting the current match."])
        }
        try FileManager.default.removeItem(at: entry.url)
        if let id = entry.matchID { ScoreboardMatchIndex.remove(id) }
        try refresh()
    }
}

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

nonisolated enum ScoreboardFileStorage {
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
        #if DEBUG && !SCOREBOARD_TESTING
        if ScoreboardUITestLaunch.isEnabled {
            return ScoreboardFileMigrationResult(migratedFiles: 0, failedFiles: 0, totalFiles: 0)
        }
        #endif
        #if os(iOS)
        return try await migrateLegacyFilesToUserVisibleStorageInBackground(progress: progress)
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
        #if DEBUG && !SCOREBOARD_TESTING
        if let root = ScoreboardUITestLaunch.storageRoot {
            let directory = root.appendingPathComponent(visibleDirectoryName, isDirectory: true)
            if create { try fileManager.createDirectory(at: directory, withIntermediateDirectories: true) }
            return directory
        }
        #endif

        #if SCOREBOARD_TESTING
        let directoryURL = ScoreboardTestEnvironment.root.appendingPathComponent(fallbackDirectoryName, isDirectory: true)
        #elseif os(iOS)
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

    // Keep disk migration off the main actor; only progress updates hop to the UI.
    @concurrent private static func migrateLegacyFilesToUserVisibleStorageInBackground(
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
