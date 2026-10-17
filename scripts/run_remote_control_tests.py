#!/usr/bin/env python3
"""Compile and exercise the actual scoreboard control core without a full app build.

Presentation-only confirmation types are extracted from ContentView; file storage
is redirected in a temporary copy. Production preferences and game files are not
loaded. Live HTTP checks run only when both API ports are available.
"""
from pathlib import Path
import os
import re
import socket
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "smartScoreboard" / "smartScoreboard"
CORE_FILES = [
    "ScoreboardStore", "ScoreboardControl", "ScoreboardWebAPI",
    "SportType", "DebateModels", "ScoreboardTheme", "BuzzerPlayer", "ScoreboardKeyboardShortcuts",
    "ScoreboardCompanion", "ScoreboardLogging", "ScoreboardGameDocument", "ScoreboardLocalization",
    "ScoreboardRosterCSV", "ScoreboardAppBackup", "ScoreboardRemoteClockProjection",
    "ScoreboardSession", "ScoreboardSessionTransport",
    "ScoreboardRTCTransport",
]


def port_is_free(port):
    with socket.socket() as probe:
        probe.settimeout(0.1)
        return probe.connect_ex(("127.0.0.1", port)) != 0


def main():
    env = os.environ.copy()
    developer = Path("/Applications/Xcode.app/Contents/Developer")
    if developer.is_dir():
        env.setdefault("DEVELOPER_DIR", str(developer))
    sdk = subprocess.check_output(
        ["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=env, text=True
    ).strip()
    framework_path = env.get("SCOREBOARD_TEST_FRAMEWORK_PATH")
    if not framework_path:
        frameworks = list((Path.home() / "Library/Developer/Xcode/DerivedData").glob(
            "*/Build/Products/Debug/LiveKitWebRTC.framework"))
        if frameworks:
            framework_path = str(max(frameworks, key=lambda path: path.stat().st_mtime).parent)
        else:
            packages = Path(tempfile.gettempdir()) / "scoreboard-control-test-packages"
            subprocess.run([
                "xcodebuild", "-resolvePackageDependencies", "-project",
                str(ROOT / "smartScoreboard/smartScoreboard.xcodeproj"),
                "-scheme", "smartScoreboard", "-derivedDataPath", str(packages),
            ], env=env, check=True, stdout=subprocess.DEVNULL)
            framework_path = str(packages / "SourcePackages/artifacts/webrtc-xcframework/LiveKitWebRTC/LiveKitWebRTC.xcframework/macos-arm64_x86_64")
    with tempfile.TemporaryDirectory(prefix="scoreboard-control-tests-") as directory:
        temp = Path(directory)
        storage = (SOURCE / "ScoreboardFileStorage.swift").read_text()
        original = "baseDirectory.appendingPathComponent(fallbackDirectoryName, isDirectory: true)"
        assert original in storage, "Storage implementation changed; update test isolation."
        storage = storage.replace(
            original,
            f'URL(fileURLWithPath: "{temp}/storage").appendingPathComponent(fallbackDirectoryName, isDirectory: true)',
        )
        (temp / "storage.swift").write_text(storage)
        session = (SOURCE / "ScoreboardSession.swift").read_text()
        recovery_path = 'return base.appendingPathComponent("smartScoreboard/Session/authority.json")'
        assert recovery_path in session, "Session recovery storage changed; update test isolation."
        session = session.replace(
            recovery_path,
            f'return URL(fileURLWithPath: "{temp}/session/authority.json")',
        )
        (temp / "session.swift").write_text(session)
        view = (SOURCE / "ContentView.swift").read_text()
        start = view.index("enum GameConfirmationAction:")
        end = view.index("\n}", start) + 2
        (temp / "confirmations.swift").write_text("import Foundation\n" + view[start:end])
        # Exercise the actual settings navigation/commit methods. Only file I/O
        # and the surrounding SwiftUI state storage are replaced by a fixture.
        def view_member(signature):
            start = view.index("    private " + signature)
            brace = view.index("{", start)
            depth, end = 1, brace + 1
            while depth:
                depth += (view[end] == "{") - (view[end] == "}")
                end += 1
            member = view[start:end].replace("    private ", "    ", 1)
            return member.replace("DispatchQueue.main.async {", "DispatchQueue.main.async { [self] in")

        state_names = {
            "homeTeamDraft", "guestTeamDraft", "eventNameDraft", "gameFileNameDraft",
            "selectedSoundSettingsSport", "selectedCompanionSettingsSport", "showsSetup",
            "isLoadingSetupDrafts", "isCommittingSetupEdits", "hasPendingSetupEdits",
            "isInitialSetupStateLoaded", "isApplyingSetupSportDefaults",
        }
        states = []
        for line in view.splitlines():
            match = re.match(r"    @State private var (\w+)", line)
            if match and (match[1] in state_names or match[1].startswith("setup")):
                states.append(line.replace("@State private ", "", 1))
        members = [view_member(signature) for signature in [
            "var isSetupDraftUpdateSuppressed:", "var setupRules:",
            "var resolvedSetupCustomSportConfig:", "var resolvedSetupCustomDebatePreset:",
            "var setupDebatePreset:", "var setupDebateOpeningSegmentSeconds:",
            "func resetSetupDraftsToDefaults(", "func openSettingsFromLiveBoard(",
            "func openSetupGame(", "func handleSetupDraftChanged(",
            "func applySetupClockDefaultsAndCommit(", "func loadSetupDraftsFromStore(",
            "func normalizeSetupCustomDebatePreset(", "func commitSetupEdits(",
            "func currentSetupWorkingSnapshot(", "func markSetupClockBaselinesCurrent(",
            "func storedSetupOptionsChanged(",
            "func requestGameConfirmation(", "func performConfirmedGameAction(",
        ]]
        fixture = """import SwiftUI
import AppKit
private enum SetupTestPane { case game }
private struct SetupTestGameFile { var displayName: String }
@MainActor final class ScoreboardSetupNavigationFixture {
    let store: ScoreboardStore
    var pendingGameConfirmation: GameConfirmationAction?
    var focusedSettingsTextFieldID: String?
    private var selectedSettingsPane = SetupTestPane.game
    private var selectedStoredGameFile: SetupTestGameFile?
    var ensureFileCalls = 0
    var autosaveRefreshes: [Bool] = []
    init(store: ScoreboardStore) { self.store = store }
    func ensureWorkingGameFileExists() { ensureFileCalls += 1 }
    func autosaveSelectedGameFile(refreshSelection: Bool = false) { autosaveRefreshes.append(refreshSelection) }
    func showPublicBoardWindow() {}
    func resolvedGameFilenameDraft(_ home: String, _ guest: String, includeExtension: Bool) -> String { "Game" }
""" + "\n".join(states + members) + "\n}\n"
        (temp / "setup-navigation.swift").write_text(fixture)
        # Exercise the real receiver/command logic with an in-memory wire. Only
        # the transport send is replaced; no app test hooks are shipped.
        remote = (SOURCE / "ScoreboardRemoteDisplay.swift").read_text()
        wire = "connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed(completion))"
        assert wire in remote, "Remote transport changed; update the test wire."
        remote = remote.replace(wire, "_ = context; ScoreboardControlTestTransport.packets.append(data); completion(nil)", 1)
        remote += (ROOT / "scripts" / "remote_control_receiver_fixture.swift").read_text()
        (temp / "remote.swift").write_text(remote)
        # Keep private host access in the temporary store's own source file.
        store = (SOURCE / "ScoreboardStore.swift").read_text()
        store += """
@MainActor
extension ScoreboardStore {
    func withControlTestFollowingSessionHost(_ action: () -> Void) {
        let previousDescriptor = sessionDescriptor
        let previousRole = sessionRecoveryRole
        let previousConnection = sessionIsConnected
        defer {
            sessionDescriptor = previousDescriptor
            sessionRecoveryRole = previousRole
            sessionIsConnected = previousConnection
        }
        sessionDescriptor = ScoreboardSessionDescriptor(sessionID: UUID(), epoch: 1,
            ownerDeviceID: localSessionDeviceID, ownerHostID: "test-owner", ownerName: "Owner",
            hostDeviceID: "test-delegated-host", hostName: "Host", hostAddresses: [])
        sessionRecoveryRole = .follower
        sessionIsConnected = false
        action()
    }
    // Hold playback as if another sound is active, then inspect the real event
    // queue without playing audio or contacting a Companion server.
    func captureControlTestEventActions(_ action: () -> Void)
        -> [(event: ScoreboardSoundEvent, effect: ScoreboardSoundEffect, location: String?)] {
        clearQueuedEventActions()
        activeEventPlaybackID = UUID()
        action()
        let actions = queuedEventActions.map { ($0.triggerEvent, $0.effect, $0.companionLocation?.rawValue) }
        clearQueuedEventActions()
        return actions
    }
    func advanceControlTestTimers(by elapsed: TimeInterval) {
        tick(elapsed: elapsed)
        lastTimerFireDate = Date()
    }
    func refreshControlTestTrustedDisplay(_ peer: ScoreboardRemoteDisplayTrustedPeer) {
        remoteDisplayHostService.refreshControlTestTrustedDisplay(peer)
    }
}
"""
        (temp / "store.swift").write_text(store)
        binary = temp / "scoreboard-control-tests"
        command = [
            "xcrun", "swiftc", "-sdk", sdk, "-parse-as-library", "-swift-version", "5",
            "-default-isolation", "MainActor", "-o", str(binary),
            "-F", framework_path, "-framework", "LiveKitWebRTC",
            "-Xlinker", "-rpath", "-Xlinker", framework_path,
        ]
        command.extend(str(SOURCE / (name + ".swift")) for name in CORE_FILES
                       if name not in {"ScoreboardStore", "ScoreboardSession"})
        command.extend([
            str(temp / "storage.swift"), str(temp / "session.swift"), str(temp / "confirmations.swift"),
            str(temp / "remote.swift"), str(temp / "store.swift"),
            str(temp / "setup-navigation.swift"),
            str(ROOT / "scripts" / "remote_control_tests.swift"),
            str(ROOT / "scripts" / "setup_navigation_tests.swift"),
            str(ROOT / "scripts" / "pause_timer_tests.swift"),
            str(ROOT / "scripts" / "session_log_tests.swift"),
            str(ROOT / "scripts" / "session_authority_tests.swift"),
        ])
        subprocess.run(command, env=env, check=True)
        free = port_is_free(5516) and port_is_free(5517)
        if not free:
            print("Skipping live HTTP checks: an API port is already occupied.", flush=True)
        subprocess.run(
            [str(binary)], env=dict(env, SCOREBOARD_TEST_HTTP="1" if free else "0",
                                   SCOREBOARD_TEST_STORAGE_ROOT=str(temp)), check=True
        )


if __name__ == "__main__":
    main()
