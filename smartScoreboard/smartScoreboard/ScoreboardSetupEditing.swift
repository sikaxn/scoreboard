import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Setup editing shared by the SwiftUI view and test fixtures. UI presentation
/// and file operations stay with the view; draft and commit behavior lives here.
@MainActor
protocol ScoreboardSetupEditing {
    var store: ScoreboardStore { get }
    var focusedSettingsTextFieldID: String? { get nonmutating set }
    var selectedSetupGameDisplayName: String? { get }
    var homeTeamDraft: String { get nonmutating set }
    var guestTeamDraft: String { get nonmutating set }
    var eventNameDraft: String { get nonmutating set }
    var setupSport: SportType { get nonmutating set }
    var setupPeriod: Int { get nonmutating set }
    var setupClockSeconds: Int { get nonmutating set }
    var setupUsesGameClock: Bool { get nonmutating set }
    var setupShotClockSeconds: Int { get nonmutating set }
    var setupVolleyballMatchFormat: VolleyballMatchFormat { get nonmutating set }
    var setupGuestClockSeconds: Int { get nonmutating set }
    var setupClockSecondsBaseline: Int { get nonmutating set }
    var setupShotClockSecondsBaseline: Int { get nonmutating set }
    var setupGuestClockSecondsBaseline: Int { get nonmutating set }
    var setupChessPreset: ChessClockPreset { get nonmutating set }
    var setupCustomSportConfig: CustomSportConfig { get nonmutating set }
    var setupDebatePresetID: String { get nonmutating set }
    var setupDebateHomeSideLabel: String { get nonmutating set }
    var setupDebateGuestSideLabel: String { get nonmutating set }
    var setupDebateScoreTrackingEnabled: Bool { get nonmutating set }
    var setupDebatePlayerTrackingEnabled: Bool { get nonmutating set }
    var setupDebatePlayerFoulsEnabled: Bool { get nonmutating set }
    var setupDebatePlayerCardsEnabled: Bool { get nonmutating set }
    var setupDebatePrepTimeEnabled: Bool { get nonmutating set }
    var setupCustomDebatePreset: DebatePreset { get nonmutating set }
    var setupStoreOptionsBaseline: ScoreboardGameSnapshot? { get nonmutating set }
    var selectedSoundSettingsSport: SportType { get nonmutating set }
    var selectedCompanionSettingsSport: SportType { get nonmutating set }
    var gameFileNameDraft: String { get nonmutating set }
    var showsSetup: Bool { get nonmutating set }
    var isApplyingSetupSportDefaults: Bool { get nonmutating set }
    var isLoadingSetupDrafts: Bool { get nonmutating set }
    var hasPendingSetupEdits: Bool { get nonmutating set }
    var isCommittingSetupEdits: Bool { get nonmutating set }
    var isInitialSetupStateLoaded: Bool { get nonmutating set }
    func selectGameSettingsPane()
    func requestSetupGameConfirmation(_ action: GameConfirmationAction)
    func ensureWorkingGameFileExists()
    func autosaveSelectedGameFile(refreshSelection: Bool)
    #if os(macOS)
    func showPublicBoardWindow()
    #endif
    func resolvedGameFilenameDraft(_ home: String, _ guest: String, includeExtension: Bool) -> String
}

extension ScoreboardSetupEditing {
    var isSetupDraftUpdateSuppressed: Bool {
        !showsSetup || isLoadingSetupDrafts || isCommittingSetupEdits || isApplyingSetupSportDefaults
    }

    var setupRules: SportRules { setupSport.rules(customConfig: setupCustomSportConfig) }

    var resolvedSetupCustomSportConfig: CustomSportConfig {
        var config = setupCustomSportConfig
        config.defaultClockSeconds = setupClockSeconds
        config.defaultShotClockSeconds = setupShotClockSeconds
        if !config.isScoreEnabled || !config.isPeriodEnabled {
            config.isPeriodWinTrackingEnabled = false
        }
        if !config.isShotClockEnabled {
            config.shotClockMode = .shot
            config.isPossessionEnabled = false
        }
        return config
    }

    var resolvedSetupCustomDebatePreset: DebatePreset {
        var preset = setupCustomDebatePreset
        preset.id = DebatePreset.customID
        preset.homeSideLabel = setupDebateHomeSideLabel
        preset.guestSideLabel = setupDebateGuestSideLabel
        preset.defaultScoreTrackingEnabled = setupDebateScoreTrackingEnabled
        preset.defaultPlayerTrackingEnabled = setupDebatePlayerTrackingEnabled
        preset.defaultPlayerFoulsEnabled = setupDebatePlayerTrackingEnabled && setupDebatePlayerFoulsEnabled
        preset.defaultPlayerCardsEnabled = setupDebatePlayerTrackingEnabled && setupDebatePlayerCardsEnabled
        preset.isPrepTimeEnabled = setupDebatePrepTimeEnabled
        if !preset.isPrepTimeEnabled {
            preset.prepSecondsPerSide = 0
        }
        if preset.segments.isEmpty {
            preset.segments = DebatePreset.customDefault.segments
        }
        return preset
    }

    var setupDebatePreset: DebatePreset {
        setupDebatePresetID == DebatePreset.customID ? resolvedSetupCustomDebatePreset : DebatePreset.preset(id: setupDebatePresetID)
    }

    var setupDebateOpeningSegmentSeconds: Int {
        max(0, setupDebatePreset.segments.first?.durationSeconds ?? 0)
    }

    func resetSetupDraftsToDefaults() {
        homeTeamDraft = ""
        guestTeamDraft = ""
        eventNameDraft = ""
        setupSport = .simple
        setupPeriod = 1
        setupClockSeconds = 10 * 60
        setupShotClockSeconds = 24
        setupGuestClockSeconds = ChessClockPreset.rapid.seconds
        setupChessPreset = .rapid
        setupCustomSportConfig = .default
        setupCustomDebatePreset = .customDefault
        setupDebatePresetID = DebatePreset.publicForum.id
        setupDebateHomeSideLabel = DebatePreset.publicForum.homeSideLabel
        setupDebateGuestSideLabel = DebatePreset.publicForum.guestSideLabel
        setupDebateScoreTrackingEnabled = DebatePreset.publicForum.defaultScoreTrackingEnabled
        setupDebatePlayerTrackingEnabled = DebatePreset.publicForum.defaultPlayerTrackingEnabled
        setupDebatePlayerFoulsEnabled = DebatePreset.publicForum.defaultPlayerFoulsEnabled
        setupDebatePlayerCardsEnabled = DebatePreset.publicForum.defaultPlayerCardsEnabled
        setupDebatePrepTimeEnabled = DebatePreset.publicForum.isPrepTimeEnabled
        gameFileNameDraft = ""
        markSetupClockBaselinesCurrent()
        hasPendingSetupEdits = true
    }

    func openSettingsFromLiveBoard(confirmedRunningTimers: Bool = false) {
        guard !store.isRemoteControlProxy else { return }
        if store.isAnyTimerRunning, !confirmedRunningTimers {
            requestSetupGameConfirmation(.openSettings)
            return
        }
        isLoadingSetupDrafts = true
        isInitialSetupStateLoaded = false
        loadSetupDraftsFromStore(keepsLoadingFlag: true)
        normalizeSetupCustomDebatePreset()
        selectGameSettingsPane()
        withAnimation(.easeInOut(duration: 0.24)) {
            showsSetup = true
        }
        DispatchQueue.main.async { [self] in
            DispatchQueue.main.async { [self] in
                isInitialSetupStateLoaded = true
                isLoadingSetupDrafts = false
            }
        }
    }

    func openSetupGame() {
        if focusedSettingsTextFieldID != nil {
            focusedSettingsTextFieldID = nil
            DispatchQueue.main.async { [self] in
                openSetupGame()
            }
            return
        }

        #if os(macOS)
        let shouldOpenPublicBoard = !store.didCompleteSetup && NSScreen.screens.count > 1
        #endif
        commitSetupEdits(forceRefresh: true)
        #if os(macOS)
        if shouldOpenPublicBoard {
            showPublicBoardWindow()
        }
        #endif
        withAnimation(.easeInOut(duration: 0.24)) {
            showsSetup = false
        }
    }

    func handleSetupDraftChanged() {
        guard !isSetupDraftUpdateSuppressed else {
            return
        }

        hasPendingSetupEdits = true
        commitSetupEdits(animated: true)
    }

    func applySetupClockDefaultsAndCommit(_ updates: () -> Void) {
        isApplyingSetupSportDefaults = true
        updates()
        hasPendingSetupEdits = true
        DispatchQueue.main.async { [self] in
            commitSetupEdits(animated: true)
            DispatchQueue.main.async { [self] in
                isApplyingSetupSportDefaults = false
            }
        }
    }

    func loadSetupDraftsFromStore(keepsLoadingFlag: Bool = false) {
        if !keepsLoadingFlag {
            isLoadingSetupDrafts = true
        }
        homeTeamDraft = store.homeTeamName
        guestTeamDraft = store.guestTeamName
        eventNameDraft = store.eventName
        setupSport = store.selectedSport
        selectedSoundSettingsSport = store.selectedSport
        selectedCompanionSettingsSport = store.selectedSport
        setupPeriod = store.period
        setupClockSeconds = store.defaultClockSeconds
        setupUsesGameClock = store.isGameClockEnabled
        setupShotClockSeconds = store.activeShotClockPresetSeconds
        setupVolleyballMatchFormat = store.volleyballMatchFormat
        setupGuestClockSeconds = store.guestChessClockSeconds
        setupChessPreset = store.chessClockPreset
        setupCustomSportConfig = store.customSportConfig
        setupCustomDebatePreset = store.customDebatePreset
        normalizeSetupCustomDebatePreset()
        setupDebatePresetID = store.selectedDebatePresetID
        setupDebateHomeSideLabel = store.debateHomeSideLabel
        setupDebateGuestSideLabel = store.debateGuestSideLabel
        setupDebateScoreTrackingEnabled = store.isDebateScoreTrackingEnabled
        setupDebatePlayerTrackingEnabled = store.isDebatePlayerTrackingEnabled
        setupDebatePlayerFoulsEnabled = store.isDebatePlayerFoulsEnabled
        setupDebatePlayerCardsEnabled = store.isDebatePlayerCardsEnabled
        setupDebatePrepTimeEnabled = store.isDebatePrepTimeEnabled
        gameFileNameDraft = selectedSetupGameDisplayName ?? resolvedGameFilenameDraft(store.homeTeamName, store.guestTeamName, includeExtension: false)
        markSetupClockBaselinesCurrent()
        hasPendingSetupEdits = false
        setupStoreOptionsBaseline = store.currentGameSnapshot()
        if !keepsLoadingFlag {
            DispatchQueue.main.async { [self] in
                DispatchQueue.main.async { [self] in
                    isLoadingSetupDrafts = false
                }
            }
        }
    }

    func normalizeSetupCustomDebatePreset() {
        setupCustomDebatePreset.id = DebatePreset.customID
        if setupCustomDebatePreset.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setupCustomDebatePreset.title = DebatePreset.customDefault.title
        }
        if setupCustomDebatePreset.homeSideLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setupCustomDebatePreset.homeSideLabel = DebatePreset.customDefault.homeSideLabel
        }
        if setupCustomDebatePreset.guestSideLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setupCustomDebatePreset.guestSideLabel = DebatePreset.customDefault.guestSideLabel
        }
        if setupCustomDebatePreset.segments.isEmpty {
            setupCustomDebatePreset.segments = DebatePreset.customDefault.segments
        }
        if !setupCustomDebatePreset.isPrepTimeEnabled {
            setupCustomDebatePreset.prepSecondsPerSide = 0
        }
    }

    func commitSetupEdits(forceRefresh: Bool = false, animated: Bool = false) {
        guard !isCommittingSetupEdits else {
            return
        }
        // Returning to the board is navigation. Loading a snapshot would stop
        // live timers locally, or send a game replacement to a delegated host.
        let hasStoredSetupEdits = store.isFollowingSessionHost
            && setupStoreOptionsBaseline.map { storedSetupOptionsChanged(since: $0) } == true
        guard hasPendingSetupEdits || hasStoredSetupEdits || !store.didCompleteSetup else {
            if forceRefresh { autosaveSelectedGameFile(refreshSelection: true) }
            return
        }

        isCommittingSetupEdits = true
        defer {
            DispatchQueue.main.async { [self] in
                isCommittingSetupEdits = false
            }
        }

        ensureWorkingGameFileExists()
        let currentSnapshot = store.currentGameSnapshot()
        let shouldPreserveRuntime = currentSnapshot.sport == setupSport
        let clockWasRunning = store.isClockRunning
        let shotClockWasRunning = store.isShotClockRunning
        let debatePrepWasRunning = store.isDebatePrepClockRunning
        let snapshot = currentSetupWorkingSnapshot()
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                store.applyGameSnapshot(snapshot)
            }
        } else {
            store.applyGameSnapshot(snapshot)
        }
        if shouldPreserveRuntime {
            store.restoreRuntimeAfterSetupApply(
                clockWasRunning: clockWasRunning,
                shotClockWasRunning: shotClockWasRunning,
                debatePrepWasRunning: debatePrepWasRunning
            )
        }
        markSetupClockBaselinesCurrent()
        hasPendingSetupEdits = store.isFollowingSessionHost && !store.sessionIsConnected
        setupStoreOptionsBaseline = store.currentGameSnapshot()
        autosaveSelectedGameFile(refreshSelection: forceRefresh)
    }

    func currentSetupWorkingSnapshot() -> ScoreboardGameSnapshot {
        let currentSnapshot = store.currentGameSnapshot()
        let isSameSport = currentSnapshot.sport == setupSport
        let didEditMainClock = !isSameSport || setupClockSeconds != setupClockSecondsBaseline
        let didEditShotClock = !isSameSport || setupShotClockSeconds != setupShotClockSecondsBaseline
        let didEditGuestClock = !isSameSport || setupGuestClockSeconds != setupGuestClockSecondsBaseline
        let resolvedDebatePreset = setupDebatePresetID == DebatePreset.customID ? resolvedSetupCustomDebatePreset : setupCustomDebatePreset
        let isSameDebateFormat = isSameSport
            && setupSport == .debate
            && currentSnapshot.selectedDebatePresetID == setupDebatePresetID
            && (setupDebatePresetID != DebatePreset.customID || currentSnapshot.customDebatePreset == resolvedDebatePreset)
        let debateOpeningClockSeconds = setupDebateOpeningSegmentSeconds
        let setupDefaultClockSeconds = setupSport == .debate ? debateOpeningClockSeconds : setupClockSeconds
        let gameClockSeconds = setupSport == .debate && !isSameDebateFormat
            ? debateOpeningClockSeconds
            : (didEditMainClock ? setupClockSeconds : currentSnapshot.gameClockSeconds)
        let shotClockMilliseconds = didEditShotClock ? setupShotClockSeconds * 1_000 : currentSnapshot.shotClockMilliseconds
        let homeChessClockSeconds = setupRules.usesChessClocks
            ? (setupSport == .debate && !isSameDebateFormat ? debateOpeningClockSeconds : (didEditMainClock ? setupClockSeconds : currentSnapshot.homeChessClockSeconds))
            : currentSnapshot.homeChessClockSeconds
        let guestChessClockSeconds = setupRules.usesChessClocks
            ? (setupSport == .debate && !isSameDebateFormat ? debateOpeningClockSeconds : (didEditGuestClock ? setupGuestClockSeconds : currentSnapshot.guestChessClockSeconds))
            : currentSnapshot.guestChessClockSeconds
        let activeChessClockSide: TeamSide?
        if setupSport == .debate, !isSameDebateFormat {
            // A new/edited debate flow starts on the side configured by its
            // opening segment. Unrelated edits keep the current live turn.
            let openingSegment = setupDebatePreset.segments.first
            activeChessClockSide = openingSegment?.timerMode == .dualClock
                ? (openingSegment?.startingSide ?? .home) : nil
        } else if setupRules.usesChessClocks, !isSameSport {
            activeChessClockSide = .home
        } else {
            activeChessClockSide = currentSnapshot.activeChessClockSide
        }
        let tracksPeriodWins = setupSport == .volleyball ||
            (setupSport == .custom && resolvedSetupCustomSportConfig.isPeriodWinTrackingEnabled)

        return ScoreboardGameSnapshot(
            fileVersion: 12,
            sport: setupSport,
            customSportConfig: setupSport == .custom ? resolvedSetupCustomSportConfig : nil,
            customDebatePreset: setupSport == .debate
                ? resolvedDebatePreset
                : currentSnapshot.customDebatePreset,
            homeTeamName: homeTeamDraft,
            guestTeamName: guestTeamDraft,
            eventName: eventNameDraft,
            homeScore: currentSnapshot.homeScore,
            guestScore: currentSnapshot.guestScore,
            period: setupPeriod,
            volleyballMatchFormat: setupSport == .volleyball ? setupVolleyballMatchFormat : nil,
            volleyballSetResults: tracksPeriodWins ? currentSnapshot.volleyballSetResults : nil,
            gameClockSeconds: gameClockSeconds,
            defaultClockSeconds: setupDefaultClockSeconds,
            isGameClockEnabled: setupSport == .volleyball || setupSport == .custom ? setupUsesGameClock : true,
            shotClockMilliseconds: setupRules.supportsShotClock ? shotClockMilliseconds : 0,
            defaultShotClockSeconds: setupRules.supportsShotClock ? setupShotClockSeconds : 0,
            activeShotClockPresetSeconds: setupRules.supportsShotClock ? setupShotClockSeconds : 0,
            possessionDirection: setupRules.supportsPossession ? .none : .none,
            areSidesSwapped: currentSnapshot.areSidesSwapped,
            isPlayerTrackingEnabled: setupSport == .debate ? setupDebatePlayerTrackingEnabled : currentSnapshot.isPlayerTrackingEnabled,
            isPlayerOverlayPaused: currentSnapshot.isPlayerOverlayPaused,
            rosterSizePerTeam: currentSnapshot.rosterSizePerTeam,
            displayLineupSize: currentSnapshot.displayLineupSize,
            playerLineupOverflowMode: currentSnapshot.playerLineupOverflowMode,
            playerLineupOverflowLogoOverride: currentSnapshot.playerLineupOverflowLogoOverride,
            playerLineupOverflowNoLogoOverride: currentSnapshot.playerLineupOverflowNoLogoOverride,
            playerLineupFadePageSeconds: currentSnapshot.playerLineupFadePageSeconds,
            playerLineupScrollSpeed: currentSnapshot.playerLineupScrollSpeed,
            playerLineupScrollDirection: currentSnapshot.playerLineupScrollDirection,
            playerFoulHighlightColor: currentSnapshot.playerFoulHighlightColor,
            isGameClockRedEnabled: currentSnapshot.isGameClockRedEnabled,
            gameClockRedThresholdSeconds: currentSnapshot.gameClockRedThresholdSeconds,
            isShotClockRedEnabled: currentSnapshot.isShotClockRedEnabled,
            shotClockRedThresholdSeconds: currentSnapshot.shotClockRedThresholdSeconds,
            homeSubstitutionsAllowed: setupRules.showsSubstitutionTracking ? currentSnapshot.homeSubstitutionsAllowed : 0,
            guestSubstitutionsAllowed: setupRules.showsSubstitutionTracking ? currentSnapshot.guestSubstitutionsAllowed : 0,
            homeSubstitutionsUsed: setupRules.showsSubstitutionTracking ? currentSnapshot.homeSubstitutionsUsed : 0,
            guestSubstitutionsUsed: setupRules.showsSubstitutionTracking ? currentSnapshot.guestSubstitutionsUsed : 0,
            homePausesAllowed: setupRules.showsPauseTracking ? currentSnapshot.homePausesAllowed : 0,
            guestPausesAllowed: setupRules.showsPauseTracking ? currentSnapshot.guestPausesAllowed : 0,
            homePausesUsed: setupRules.showsPauseTracking ? currentSnapshot.homePausesUsed : 0,
            guestPausesUsed: setupRules.showsPauseTracking ? currentSnapshot.guestPausesUsed : 0,
            homeTeamFouls: currentSnapshot.homeTeamFouls,
            guestTeamFouls: currentSnapshot.guestTeamFouls,
            homeChessClockSeconds: homeChessClockSeconds,
            guestChessClockSeconds: guestChessClockSeconds,
            activeChessClockSide: activeChessClockSide,
            chessClockPreset: setupSport == .chess ? setupChessPreset : currentSnapshot.chessClockPreset,
            selectedDebatePresetID: setupSport == .debate ? setupDebatePresetID : currentSnapshot.selectedDebatePresetID,
            debateHomeSideLabel: setupSport == .debate ? setupDebateHomeSideLabel : currentSnapshot.debateHomeSideLabel,
            debateGuestSideLabel: setupSport == .debate ? setupDebateGuestSideLabel : currentSnapshot.debateGuestSideLabel,
            debateCurrentSegmentIndex: isSameDebateFormat ? currentSnapshot.debateCurrentSegmentIndex : (setupSport == .debate ? 0 : currentSnapshot.debateCurrentSegmentIndex),
            debatePrepHomeSeconds: isSameDebateFormat ? currentSnapshot.debatePrepHomeSeconds : (setupSport == .debate && setupDebatePrepTimeEnabled ? setupDebatePreset.prepSecondsPerSide : currentSnapshot.debatePrepHomeSeconds),
            debatePrepGuestSeconds: isSameDebateFormat ? currentSnapshot.debatePrepGuestSeconds : (setupSport == .debate && setupDebatePrepTimeEnabled ? setupDebatePreset.prepSecondsPerSide : currentSnapshot.debatePrepGuestSeconds),
            isDebatePrepTimeEnabled: setupSport == .debate ? setupDebatePrepTimeEnabled : currentSnapshot.isDebatePrepTimeEnabled,
            debateActiveTimer: isSameDebateFormat ? currentSnapshot.debateActiveTimer : (setupSport == .debate ? .segment : currentSnapshot.debateActiveTimer),
            isDebatePrepClockRunning: isSameDebateFormat ? currentSnapshot.isDebatePrepClockRunning : (setupSport == .debate ? false : currentSnapshot.isDebatePrepClockRunning),
            isDebateScoreTrackingEnabled: setupSport == .debate ? setupDebateScoreTrackingEnabled : currentSnapshot.isDebateScoreTrackingEnabled,
            isDebatePlayerTrackingEnabled: setupSport == .debate ? setupDebatePlayerTrackingEnabled : currentSnapshot.isDebatePlayerTrackingEnabled,
            isDebatePlayerFoulsEnabled: setupSport == .debate ? setupDebatePlayerTrackingEnabled && setupDebatePlayerFoulsEnabled : currentSnapshot.isDebatePlayerFoulsEnabled,
            isDebatePlayerCardsEnabled: setupSport == .debate ? setupDebatePlayerTrackingEnabled && setupDebatePlayerCardsEnabled : currentSnapshot.isDebatePlayerCardsEnabled,
            homePenaltyTimers: setupRules.supportsHockeyPenalties ? currentSnapshot.homePenaltyTimers : [],
            guestPenaltyTimers: setupRules.supportsHockeyPenalties ? currentSnapshot.guestPenaltyTimers : [],
            homeRoster: currentSnapshot.homeRoster,
            guestRoster: currentSnapshot.guestRoster,
            externalDisplayBackgroundMode: currentSnapshot.externalDisplayBackgroundMode,
            externalDisplayBackgroundImage: currentSnapshot.externalDisplayBackgroundImage,
            externalDisplayAnimatedLogoStyle: currentSnapshot.externalDisplayAnimatedLogoStyle,
            externalDisplayAnimatedLogoBackgroundColor: currentSnapshot.externalDisplayAnimatedLogoBackgroundColor,
            externalDisplayAnimatedLogoSpeed: currentSnapshot.externalDisplayAnimatedLogoSpeed,
            externalDisplayAnimatedLogoSize: currentSnapshot.externalDisplayAnimatedLogoSize,
            externalDisplayAnimatedLogoOpacity: currentSnapshot.externalDisplayAnimatedLogoOpacity,
            showsExternalDisplayDateTime: currentSnapshot.showsExternalDisplayDateTime,
            externalDisplayDateTimeFormat: currentSnapshot.externalDisplayDateTimeFormat,
            showsExternalDisplayDateTimeSeconds: currentSnapshot.showsExternalDisplayDateTimeSeconds,
            showsTeamLogos: currentSnapshot.showsTeamLogos,
            showsEventLogo: currentSnapshot.showsEventLogo,
            playerViewRosterScope: .fullRoster,
            homeTeamLogoImage: currentSnapshot.homeTeamLogoImage,
            guestTeamLogoImage: currentSnapshot.guestTeamLogoImage,
            eventLogoImage: currentSnapshot.eventLogoImage,
            pauseDurationSeconds: currentSnapshot.pauseDurationSeconds,
            pauseTimer: currentSnapshot.pauseTimer,
            isTeamPauseIndefinite: setupRules.showsPauseTracking && (currentSnapshot.isTeamPauseIndefinite ?? false)
        )
    }

    func markSetupClockBaselinesCurrent() {
        setupClockSecondsBaseline = setupClockSeconds
        setupShotClockSecondsBaseline = setupShotClockSeconds
        setupGuestClockSecondsBaseline = setupGuestClockSeconds
    }

    func storedSetupOptionsChanged(since baseline: ScoreboardGameSnapshot) -> Bool {
        // These settings write directly to the owner's store. Forward actual
        // edits to its host, excluding live clocks, scores, rosters, and counts.
        let current = store.currentGameSnapshot()
        return current.isPlayerTrackingEnabled != baseline.isPlayerTrackingEnabled
            || current.rosterSizePerTeam != baseline.rosterSizePerTeam
            || current.displayLineupSize != baseline.displayLineupSize
            || current.playerLineupOverflowMode != baseline.playerLineupOverflowMode
            || current.playerLineupOverflowLogoOverride != baseline.playerLineupOverflowLogoOverride
            || current.playerLineupOverflowNoLogoOverride != baseline.playerLineupOverflowNoLogoOverride
            || current.playerLineupFadePageSeconds != baseline.playerLineupFadePageSeconds
            || current.playerLineupScrollSpeed != baseline.playerLineupScrollSpeed
            || current.playerLineupScrollDirection != baseline.playerLineupScrollDirection
            || current.playerFoulHighlightColor != baseline.playerFoulHighlightColor
            || current.isGameClockRedEnabled != baseline.isGameClockRedEnabled
            || current.gameClockRedThresholdSeconds != baseline.gameClockRedThresholdSeconds
            || current.isShotClockRedEnabled != baseline.isShotClockRedEnabled
            || current.shotClockRedThresholdSeconds != baseline.shotClockRedThresholdSeconds
            || current.homeSubstitutionsAllowed != baseline.homeSubstitutionsAllowed
            || current.guestSubstitutionsAllowed != baseline.guestSubstitutionsAllowed
            || current.homePausesAllowed != baseline.homePausesAllowed
            || current.guestPausesAllowed != baseline.guestPausesAllowed
            || current.pauseDurationSeconds != baseline.pauseDurationSeconds
            || current.isTeamPauseIndefinite != baseline.isTeamPauseIndefinite
    }
}
