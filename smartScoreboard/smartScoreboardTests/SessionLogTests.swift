import Foundation
import Testing

extension ScoreboardTests {
    @Test("Joined log history stays in memory through flush, is discarded on leave, and becomes durable only on host transfer")
    func joinedSessionLogIsolation() throws {
        let manager = ScoreboardLogManager.shared
        let original = try #require(manager.currentSessionSnapshot())
        defer {
            manager.discardTransientSessionLogs()
            try? manager.adoptAuthoritativeSession(original)
        }
        let before = try manager.backupFiles()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = ScoreboardLogEntry(id: UUID(), timestamp: date,
            operation: ScoreboardLogOperation(kind: .scoreAdjustment, summary: "Remote score"),
            context: store.currentLogContext(), outcome: .applied)
        let remote = ScoreboardLogSession(startedAt: date, lastUpdatedAt: date, entries: [entry])
        let batch = ScoreboardSessionLogBatch(fileVersion: remote.fileVersion, sessionID: remote.sessionID,
            startedAt: remote.startedAt, lastUpdatedAt: remote.lastUpdatedAt, startIndex: 0,
            totalEntryCount: remote.entries.count, entries: remote.entries)
        let cursor = try manager.mergeReplicatedLogBatch(batch, persist: false)
        #expect(cursor.sessionID == remote.sessionID && cursor.nextIndex == 1)
        #expect(try manager.mergeReplicatedLogBatch(batch, persist: false) == cursor)
        #expect(manager.currentSessionSnapshot()?.sessionID == original.sessionID)
        #expect(manager.currentSessionSnapshot()?.entries.map(\.id) == original.entries.map(\.id))
        #expect(try manager.listSessions().allSatisfy { $0.session.sessionID != remote.sessionID })
        let after = try manager.backupFiles() // Also forces all pending writes to flush.
        #expect(Dictionary(uniqueKeysWithValues: before.map { ($0.filename, $0.data) }) ==
                Dictionary(uniqueKeysWithValues: after.map { ($0.filename, $0.data) }))
        manager.discardTransientSessionLogs()
        #expect(manager.receivedLogCursor(for: remote.sessionID) == nil)
        #expect(manager.currentReceivedLogCursor == nil)

        // Even a remote ID colliding with a personal log must stay isolated.
        var colliding = batch
        colliding.sessionID = original.sessionID
        _ = try manager.mergeReplicatedLogBatch(colliding, persist: false)
        #expect(manager.currentSessionSnapshot()?.entries.map(\.id) == original.entries.map(\.id))
        manager.discardTransientSessionLogs()

        _ = try manager.mergeReplicatedLogBatch(batch, persist: false)
        var stale = remote; stale.entries = []
        #expect(throws: (any Error).self) { try manager.adoptAuthoritativeSession(stale) }
        try manager.adoptAuthoritativeSession(remote)
        manager.flushPendingWrites()
        #expect(try manager.listSessions().contains { $0.session.sessionID == remote.sessionID })
    }

    @Test("Session log paging, replication, and promotion")
    func sessionLogReplication() throws {
        let manager = ScoreboardLogManager.shared
        let original = try #require(manager.currentSessionSnapshot())
        defer { try? manager.adoptAuthoritativeSession(original) }
        func expectError(_ message: String, _ operation: () throws -> Void) {
            #expect(throws: (any Error).self, Comment(rawValue: message)) { try operation() }
        }
        let context = ScoreboardStore.shared.currentLogContext()
        let date = Date(timeIntervalSince1970: 1_700_000_000.375)
        let entries = (0..<70).map { index in
            ScoreboardLogEntry(id: UUID(), timestamp: date.addingTimeInterval(Double(index)),
                operation: ScoreboardLogOperation(kind: .scoreAdjustment, summary: "Score \(index)"),
                context: context, outcome: .applied)
        }
        let seed = ScoreboardLogSession(startedAt: date, lastUpdatedAt: date.addingTimeInterval(70), entries: entries)
        try manager.adoptAuthoritativeSession(seed, gameDisplayName: "Owner Game")
        #expect(manager.currentSessionSnapshot()?.sessionID == seed.sessionID, "handoff keeps log session identity")
        #expect(manager.currentSessionSnapshot()?.entries.map(\.id) == entries.map(\.id), "handoff preserves entries")
        let first = try #require(try manager.sessionLogBatch(after: nil))
        #expect(first.entries.count == 32 && first.startIndex == 0 && first.hasMore, "log page entry cap")
        let firstBytes = try JSONEncoder().encode(first).count
        #expect(firstBytes <= 32_768, "log page byte cap")
        let second = try #require(try manager.sessionLogBatch(after: first.nextCursor))
        let third = try #require(try manager.sessionLogBatch(after: second.nextCursor))
        #expect(second.startIndex == 32 && second.entries.count == 32, "log cursor continues exact prefix")
        #expect(third.startIndex == 64 && third.entries.count == 6 && !third.hasMore, "last page announces completion")
        let finished = try manager.sessionLogBatch(after: third.nextCursor)
        #expect(finished == nil, "acknowledged history sends no further log pages")
        let foreign = ScoreboardSessionLogCursor(sessionID: UUID(), nextIndex: 70, lastEntryID: entries.last!.id)
        let foreignPage = try manager.sessionLogBatch(after: foreign)
        #expect(foreignPage?.startIndex == 0, "new session restarts old cursor")
        let stale = ScoreboardSessionLogCursor(sessionID: seed.sessionID, nextIndex: 32, lastEntryID: UUID())
        let restarted = try manager.sessionLogBatch(after: stale)
        #expect(restarted?.startIndex == 0, "restored checkpoint detects stale cursor")
        expectError("metadata must fit byte cap") { _ = try manager.sessionLogBatch(after: nil, maxBytes: 10) }

        // A different ID represents the same pages arriving at another device.
        let replicaID = UUID()
        func replica(_ page: ScoreboardSessionLogBatch) -> ScoreboardSessionLogBatch {
            var result = page; result.sessionID = replicaID; return result
        }
        let gapCursor = try manager.mergeReplicatedLogBatch(replica(second))
        #expect(gapCursor.nextIndex == 0, "out-of-order pages ask for the missing prefix")
        let firstCursor = try manager.mergeReplicatedLogBatch(replica(first))
        #expect(firstCursor.nextIndex == 32, "first log page acknowledged")
        let duplicateCursor = try manager.mergeReplicatedLogBatch(replica(first))
        #expect(duplicateCursor == firstCursor, "retransmitted log page is idempotent")
        var overlap = replica(first)
        overlap.startIndex = 10
        overlap.entries = Array(entries[10..<42])
        let overlapCursor = try manager.mergeReplicatedLogBatch(overlap)
        #expect(overlapCursor.nextIndex == 42, "overlapping log page adds only the new suffix")
        _ = try manager.mergeReplicatedLogBatch(replica(second))
        let lastCursor = try manager.mergeReplicatedLogBatch(replica(third))
        #expect(lastCursor.nextIndex == 70 && lastCursor.lastEntryID == entries.last!.id, "complete replicated cursor")
        let oldPageCursor = try manager.mergeReplicatedLogBatch(replica(first))
        #expect(oldPageCursor == lastCursor, "late duplicate never moves cursor backwards")
        #expect(manager.currentReceivedLogCursor == lastCursor, "current replica cursor is exposed")
        #expect(manager.currentSessionSnapshot()?.sessionID == seed.sessionID, "replication does not replace unrelated local log")
        let replicaRow = try #require(try manager.listSessions().first { $0.session.sessionID == replicaID })
        #expect(replicaRow.session.entries.map(\.id) == entries.map(\.id), "replicated logs visible in existing log browser")
        #expect(!FileManager.default.fileExists(atPath: replicaRow.url.path), "network merge performs no inline disk write")
        let cached = try manager.loadSession(from: replicaRow.url)
        #expect(cached.entries.count == 70, "log export can read pending replica from memory")

        var conflicting = replica(first)
        conflicting.entries[0].id = UUID()
        expectError("conflicting prefix must be rejected") { _ = try manager.mergeReplicatedLogBatch(conflicting) }
        #expect(manager.receivedLogCursor(for: replicaID) == lastCursor, "invalid page leaves replica unchanged")
        var invalid = replica(first)
        invalid.startIndex = -1
        expectError("negative page cursor must be rejected") { _ = try manager.mergeReplicatedLogBatch(invalid) }
        invalid = replica(first)
        invalid.entries.append(entries[32])
        expectError("oversized entry page must be rejected") { _ = try manager.mergeReplicatedLogBatch(invalid) }

        var nextSession = first
        nextSession.sessionID = UUID()
        nextSession.entries = []
        nextSession.totalEntryCount = 0
        let emptyCursor = try manager.mergeReplicatedLogBatch(nextSession)
        #expect(emptyCursor.nextIndex == 0 && emptyCursor.lastEntryID == nil, "empty replacement session is explicit")
        #expect(manager.receivedLogCursor(for: replicaID) == lastCursor, "session switch preserves prior replicated history")
        manager.flushPendingWrites()
        let persisted = try JSONDecoder.withLogDates.decode(ScoreboardLogSession.self, from: Data(contentsOf: replicaRow.url))
        #expect(persisted.entries.map(\.id) == entries.map(\.id), "throttled replica flush persists complete history")

        var promoted = seed
        promoted.sessionID = replicaID
        try manager.adoptAuthoritativeSession(promoted, gameDisplayName: "Owner Game")
        manager.record(operation: ScoreboardLogOperation(kind: .scoreAdjustment, summary: "After promotion"),
                       context: context, outcome: .applied)
        let continued = try #require(manager.currentSessionSnapshot())
        #expect(continued.sessionID == replicaID && continued.entries.count == 71, "promoted replica continues same log")
        #expect(continued.entries.last?.context.gameFileName == "Owner Game", "host logs owner game display name")
        #expect(continued.entries.last?.context.gameFilePath == nil, "host logs do not fabricate owner-local filesystem path")
        expectError("old checkpoint must not truncate acknowledged history") { try manager.adoptAuthoritativeSession(promoted) }
        manager.startSession()
        let savedPromotion = try manager.loadSession(from: replicaRow.url)
        #expect(savedPromotion.entries.count == 71, "starting another session preserves pending promoted tail")

        var bulky = seed
        bulky.sessionID = UUID()
        bulky.entries = Array(entries.prefix(10)).map { entry in
            var copy = entry; copy.operation.notes = String(repeating: "x", count: 6_000); return copy
        }
        try manager.adoptAuthoritativeSession(bulky)
        let bounded = try #require(try manager.sessionLogBatch(after: nil))
        #expect(bounded.entries.count > 0 && bounded.entries.count < 10, "large log entries obey byte budget")
        let boundedBytes = try JSONEncoder().encode(bounded).count
        #expect(boundedBytes <= 32_768, "encoded large-entry batch stays bounded")
    }
}

private extension JSONDecoder {
    static var withLogDates: JSONDecoder {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder
    }
}
