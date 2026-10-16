import Foundation

@MainActor
func runSessionAuthorityTests() throws -> Int {
    var checks = 0
    func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message)
        checks += 1
    }
    let owner = ScoreboardSessionDescriptor(sessionID: UUID(), epoch: 1,
        ownerDeviceID: "owner-ipad", ownerHostID: "owner-pairing-identity", ownerName: "Owner iPad",
        hostDeviceID: "owner-ipad", hostName: "Owner iPad", hostAddresses: ["192.0.2.1"])
    expect(owner.accepts(owner), "same authority is accepted idempotently")
    var delegated = owner
    delegated.epoch = 2
    delegated.hostDeviceID = "ethernet-tv"
    delegated.hostName = "Apple TV"
    delegated.hostAddresses = ["192.0.2.2"]
    expect(owner.accepts(delegated), "higher authority epoch can move host")
    expect(!delegated.accepts(owner), "previous host epoch cannot regain authority")
    var conflict = delegated
    conflict.hostDeviceID = "other-mac"
    expect(!delegated.accepts(conflict), "same epoch cannot name two hosts")
    conflict = delegated; conflict.sessionID = UUID()
    expect(!delegated.accepts(conflict), "different session cannot replace authority")
    conflict = delegated; conflict.ownerDeviceID = "other-owner"
    expect(!delegated.accepts(conflict), "handoff cannot change owner device")
    conflict = delegated; conflict.ownerHostID = "other-pairing-identity"
    expect(!delegated.accepts(conflict), "handoff cannot change owner pairing identity")
    var addressRefresh = delegated
    addressRefresh.hostAddresses = ["192.0.2.3"]
    addressRefresh.hostWebAPIStatus = "Running"
    addressRefresh.hostCompanionEnabled = true
    expect(delegated.accepts(addressRefresh), "same host may refresh addresses and service status")
    var returned = delegated
    returned.epoch = 3
    returned.hostDeviceID = owner.ownerDeviceID
    returned.hostName = owner.ownerName
    expect(delegated.accepts(returned), "owner can become host again only at a later epoch")
    var maximum = delegated
    maximum.epoch = UInt64.max
    expect(delegated.accepts(maximum) && !maximum.accepts(delegated), "epoch comparisons do not wrap")

    let root = ProcessInfo.processInfo.environment["SCOREBOARD_TEST_STORAGE_ROOT"]!
    let recoveryURL = ScoreboardSessionRecovery.url
    expect(recoveryURL.standardizedFileURL.path.hasPrefix(URL(fileURLWithPath: root).standardizedFileURL.path + "/"),
           "authority recovery uses isolated temporary storage")
    let testURL = recoveryURL.deletingLastPathComponent().appendingPathComponent("recovery-test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: testURL) }
    let absent = try ScoreboardSessionRecovery.load(from: testURL)
    expect(absent == nil, "missing recovery is an explicit absent record")
    let store = ScoreboardStore.shared
    let checkpoint = ScoreboardSessionCheckpoint(descriptor: delegated, settings: try store.exportPersistedStateData(),
        game: store.currentGameSnapshot(), runtime: store.currentWebAPIState().runtime,
        gameName: "Owner Game", ownerGameFilename: "Owner Game.scoreboardgame", mainDisplayMode: .scoreboard,
        pairings: ScoreboardSessionPairingConfiguration(ownerHostID: owner.ownerHostID,
            peers: [], mutedDisplayIDs: [], displayDirectionsByID: [:], customDisplayIDsByID: [:]),
        allowedControllers: ["owner-ipad", "control-mac"], webControlEnabled: true,
        webControlKey: "0123456789ABCDEF", log: ScoreboardLogManager.shared.currentSessionSnapshot()!,
        capturedAt: Date().timeIntervalSince1970, gameElapsed: 0.7, shotElapsed: 0.03,
        penaltyElapsed: 0.2, prepElapsed: 0.8)
    let transferID = UUID()
    let hostedDirectory = ScoreboardHostedMatchStorage.directory(for: delegated.sessionID)
    defer { try? ScoreboardHostedMatchStorage.remove(sessionID: delegated.sessionID) }
    try ScoreboardHostedMatchStorage.save(checkpoint)
    expect(FileManager.default.fileExists(atPath: ScoreboardHostedMatchStorage.gameURL(for: delegated.sessionID).path),
           "delegated game file is isolated from owner documents")
    expect(FileManager.default.fileExists(atPath: ScoreboardHostedMatchStorage.logURL(for: delegated.sessionID).path),
           "delegated log is isolated with the game file")
    expect(hostedDirectory.path.hasPrefix(recoveryURL.deletingLastPathComponent().path),
           "hosted match stays under temporary session storage")
    let hostedCopy = try ScoreboardHostedMatchStorage.load(sessionID: delegated.sessionID)
    expect(hostedCopy?.game == checkpoint.game && hostedCopy?.ownerGameFilename == checkpoint.ownerGameFilename,
           "isolated working copy preserves the match and its owner filename")
    var clean = ScoreboardSessionCleanState(ownerConnected: true, anyTimerRunning: false,
        transferring: false, revision: 4, persistedRevision: 4, acknowledgedRevision: 4,
        logCount: 12, acknowledgedLogCount: 12)
    expect(clean.isSafeToDisconnect, "all stopped timers and durable owner acknowledgement permit disconnect")
    clean.anyTimerRunning = true
    expect(!clean.isSafeToDisconnect, "a running timer prevents clean disconnect")
    clean.anyTimerRunning = false; clean.ownerConnected = false
    expect(!clean.isSafeToDisconnect, "an offline owner cannot confirm the latest saved match")
    clean.ownerConnected = true; clean.acknowledgedRevision = 3
    expect(!clean.isSafeToDisconnect, "an older file acknowledgement is not clean")
    clean.acknowledgedRevision = 4; clean.acknowledgedLogCount = 11
    expect(!clean.isSafeToDisconnect, "an unsynced log tail is not clean")
    clean.acknowledgedLogCount = 12; clean.transferring = true
    expect(!clean.isSafeToDisconnect, "an in-progress handoff is not clean")
    for role in [ScoreboardSessionRecovery.Role.host, .follower, .prepared, .fenced] {
        let recovery = ScoreboardSessionRecovery(role: role, descriptor: delegated,
            checkpoint: checkpoint, transferID: transferID)
        try recovery.save(to: testURL)
        let restored = try ScoreboardSessionRecovery.load(from: testURL)!
        expect(restored.role == role && restored.descriptor == delegated, "recovery preserves \(role) authority")
        expect(restored.transferID == transferID && restored.checkpoint?.game == checkpoint.game,
               "recovery preserves \(role) checkpoint and transfer identity")
        expect(restored.checkpoint?.gameElapsed == 0.7 && restored.checkpoint?.prepElapsed == 0.8,
               "recovery preserves \(role) timer fractions")
    }
    // A corrupt/future authority record must throw. Treating it as absent would
    // allow a fenced device to silently restart local game logic.
    for corrupt in [Data("{".utf8), Data("null".utf8), Data("{}".utf8),
                    Data("{\"role\":\"unknown\"}".utf8)] {
        try corrupt.write(to: testURL, options: .atomic)
        var failedClosed = false
        do { _ = try ScoreboardSessionRecovery.load(from: testURL) }
        catch { failedClosed = true }
        expect(failedClosed, "corrupted authority recovery fails closed")
    }
    let valid = ScoreboardSessionRecovery(role: .fenced, descriptor: delegated,
        checkpoint: checkpoint, transferID: transferID)
    try valid.save(to: testURL)
    let repaired = try ScoreboardSessionRecovery.load(from: testURL)
    expect(repaired?.role == .fenced && repaired?.descriptor.epoch == 2, "atomic rewrite preserves fencing after corrupt file")
    for sport in SportType.allCases {
        store.setSelectedSport(sport)
        var sportCheckpoint = checkpoint
        sportCheckpoint.game = store.currentGameSnapshot()
        let packet = ScoreboardSessionMessage(kind: .prepare, descriptor: delegated,
            targetID: delegated.hostDeviceID, checkpoint: sportCheckpoint)
        let decoded = try JSONDecoder().decode(ScoreboardSessionMessage.self, from: JSONEncoder().encode(packet))
        expect(decoded.checkpoint?.game.sport == sport, "handoff checkpoint supports \(sport.rawValue)")
    }
    try ScoreboardHostedMatchStorage.remove(sessionID: delegated.sessionID)
    expect(!FileManager.default.fileExists(atPath: hostedDirectory.path),
           "unhosting removes the isolated game, checkpoint, and log together")
    return checks
}
