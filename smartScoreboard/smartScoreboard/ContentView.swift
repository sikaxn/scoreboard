import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS) || os(macOS)
import TipKit
#endif
#if os(iOS)
import PhotosUI
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

#if !os(tvOS)

private func localizedAppString(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func localizedAppFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedAppString(key), locale: Locale.current, arguments: arguments)
}

private func localizedAppText(_ key: String) -> Text {
    Text(localizedAppString(key))
}

private let automaticDiskWriteThrottleInterval: TimeInterval = 5

private struct PendingGameFileAutosave {
    var url: URL
    var refreshSelection: Bool
}

struct ContentView: View {
    private static let tipHistoryResetGenerationKey = "scoreboardTipHistoryResetGeneration"

    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @FocusState private var focusedSettingsTextFieldID: String?

    @State private var homeTeamDraft = ""
    @State private var guestTeamDraft = ""
    @State private var eventNameDraft = ""
    @State private var setupSport: SportType = .simple
    @State private var setupPeriod = 1
    @State private var setupClockSeconds = 10 * 60
    @State private var setupUsesGameClock = true
    @State private var setupShotClockSeconds = 24
    @State private var setupVolleyballMatchFormat: VolleyballMatchFormat = .bestOf5
    @State private var setupGuestClockSeconds = ChessClockPreset.rapid.seconds
    @State private var setupClockSecondsBaseline = 10 * 60
    @State private var setupShotClockSecondsBaseline = 24
    @State private var setupGuestClockSecondsBaseline = ChessClockPreset.rapid.seconds
    @State private var setupChessPreset: ChessClockPreset = .rapid
    @State private var setupCustomSportConfig: CustomSportConfig = .default
    @State private var setupDebatePresetID = DebatePreset.publicForum.id
    @State private var setupDebateHomeSideLabel = DebatePreset.publicForum.homeSideLabel
    @State private var setupDebateGuestSideLabel = DebatePreset.publicForum.guestSideLabel
    @State private var setupDebateScoreTrackingEnabled = DebatePreset.publicForum.defaultScoreTrackingEnabled
    @State private var setupDebatePlayerTrackingEnabled = DebatePreset.publicForum.defaultPlayerTrackingEnabled
    @State private var setupDebatePlayerFoulsEnabled = DebatePreset.publicForum.defaultPlayerFoulsEnabled
    @State private var setupDebatePlayerCardsEnabled = DebatePreset.publicForum.defaultPlayerCardsEnabled
    @State private var setupDebatePrepTimeEnabled = DebatePreset.publicForum.isPrepTimeEnabled
    @State private var setupCustomDebatePreset = DebatePreset.customDefault
    @State private var selectedSoundSettingsSport: SportType = .simple
    @State private var selectedIntegrationDetail: IntegrationSettingsDetail = .remoteDisplay
    @State private var remoteDisplayPairingCodes: [String: String] = [:]
    @State private var selectedCompanionSettingsSport: SportType = .simple
    @State private var gameFileNameDraft = ""
    @State private var showsSetup = !ScoreboardStore.shared.didCompleteSetup
    @State private var showsGettingStarted = false
    @State private var showsBunnyEasterEgg = false
    @State private var isGettingStartedAutoPresentation = false
    @AppStorage(ScoreboardEasterEggIcon.userDefaultsKey) private var isBunnyIconEnabled = false
    @State private var tipHistoryResetGeneration = UserDefaults.standard.integer(forKey: Self.tipHistoryResetGenerationKey)
    @State private var selectedSettingsPane: SettingsPane = .game
    @State private var isSettingsSidebarCollapsed = false
    @State private var storedGameFiles: [StoredGameFile] = []
    @State private var selectedStoredGameFileID: String?
    @State private var renameGameFileNameDraft = ""
    @State private var selectedGameFileIDs: Set<String> = []
    @State private var isSelectingGameFiles = false
    @State private var storedLogSessions: [StoredLogSession] = []
    @State private var selectedStoredLogSessionID: String?
    @State private var selectedLogSessionIDs: Set<String> = []
    @State private var isSelectingLogSessions = false
    @State private var showsGameImporter = false
    @State private var showsBackupImporter = false
    @State private var showsRosterCSVImporter = false
    @State private var exportSharePayload: ExportSharePayload?
    @State private var fileOperationError: FileOperationAlert?
    @State private var pendingRemoteDisplayTakeover: PendingRemoteDisplayTakeover?
    @State private var dashboardPage: DashboardPage = .main
    @State private var isDashboardHeaderHidden = false
    @State private var showsLocalScoreboard = false
    @State private var showsLocalScoreboardReturnHint = false
    @State private var localScoreboardReturnHintDismissTask: Task<Void, Never>?
    @State private var dashboardTipGroup: TipGroup?
    @State private var dashboardTipGroupSignature = ""
    @State private var pendingGameConfirmation: GameConfirmationAction?
    @State private var pendingBackupRestore: PendingBackupRestore?
    @State private var pendingLogDeletion: StoredLogSession?
    @State private var isFactoryDefaultConfirmationPresented = false
    @State private var pendingPenaltySelection: PendingPenaltySelection?
    @State private var logPlaybackOrder: LogPlaybackOrder = .topToBottom
    @State private var isLoadingSetupDrafts = false
    @State private var isCommittingSetupEdits = false
    @State private var isInitialSetupStateLoaded = false
    @State private var didStartRootInitialization = false
    @State private var fileMigrationProgress: ScoreboardFileMigrationProgress?
    @State private var isExternalBackgroundImageEditorVisible = false
    @State private var isDebateDesignerVisible = false
    @State private var pendingExternalBackgroundModeAfterImageImport: ExternalDisplayBackgroundMode?
    @State private var pendingGameFileAutosaves: [String: PendingGameFileAutosave] = [:]
    @State private var lastGameFileAutosaveDate: Date?
    @State private var pendingGameFileAutosaveWorkItem: DispatchWorkItem?
    #if os(iOS)
    @State private var showsExternalBackgroundPhotoPicker = false
    @State private var showsHomeLogoPhotoPicker = false
    @State private var showsGuestLogoPhotoPicker = false
    @State private var showsEventLogoPhotoPicker = false
    @State private var selectedExternalBackgroundPhotoItem: PhotosPickerItem?
    @State private var selectedHomeLogoPhotoItem: PhotosPickerItem?
    @State private var selectedGuestLogoPhotoItem: PhotosPickerItem?
    @State private var selectedEventLogoPhotoItem: PhotosPickerItem?
    @State private var settingsKeyboardHeight: CGFloat = 0
    #endif

    private var themePalette: ThemePalette { store.theme.palette }
    private var settingsPalette: SettingsPalette { themePalette.settingsPalette(for: store.theme, colorScheme: colorScheme) }
    private var settingsKeyboardAvoidanceInset: CGFloat {
        #if os(iOS)
        settingsKeyboardHeight > 0 ? min(88, max(24, settingsKeyboardHeight * 0.18)) : 0
        #else
        0
        #endif
    }
    private var isIPhoneInterface: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
    private var homeTint: Color { themePalette.homeAccent }
    private var guestTint: Color { themePalette.guestAccent }
    private var homeTintText: Color { themePalette.homeAccentText }
    private var guestTintText: Color { themePalette.guestAccentText }
    private var destructiveText: Color { themePalette.destructiveText }
    private var appDisplayName: String {
        "Smart Scoreboard"
    }
    private var currentAppIconAssetName: String {
        ScoreboardEasterEggIcon.assetName(isBunnyEnabled: isBunnyIconEnabled)
    }
    private var appVersionLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let version, let build {
            return localizedAppFormat("Version %@ (%@)", version, build)
        }
        if let version {
            return localizedAppFormat("Version %@", version)
        }
        return localizedAppString("Version unavailable")
    }
    private var setupRules: SportRules { setupSport.rules(customConfig: setupCustomSportConfig) }
    private var setupPeriodUpperBound: Int {
        setupSport == .volleyball ? setupVolleyballMatchFormat.maximumSets : 9
    }
    private var setupUsesServeTimer: Bool {
        setupSport == .volleyball ||
            (setupSport == .custom && setupCustomSportConfig.isShotClockEnabled && setupCustomSportConfig.shotClockMode == .serve)
    }
    private var isSetupDraftUpdateSuppressed: Bool { !showsSetup || isLoadingSetupDrafts || isCommittingSetupEdits }
    private var resolvedSetupCustomSportConfig: CustomSportConfig {
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
    private var resolvedSetupCustomDebatePreset: DebatePreset {
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
    private var setupDebatePreset: DebatePreset {
        setupDebatePresetID == DebatePreset.customID ? resolvedSetupCustomDebatePreset : DebatePreset.preset(id: setupDebatePresetID)
    }
    private var usesDedicatedDualClockLayout: Bool { store.selectedSport == .chess }
    private var isResetInterlockActive: Bool { store.isResetInterlockActive }
    private var isGameClockResetInterlockActive: Bool { store.isGameClockInterlockActive }
    private let logManager = ScoreboardLogManager.shared
    #if os(iOS)
    private var iOSGameImportContentTypes: [UTType] { [.scoreboardGame, .json, .data] }
    private var iOSBackupImportContentTypes: [UTType] { [.scoreboardBackup, .json, .data] }
    private var iOSRosterCSVImportContentTypes: [UTType] { [.commaSeparatedText, .plainText, .data] }
    #endif
    #if os(macOS)
    private var macOSGameImportContentTypes: [UTType] { [.scoreboardGame, .json] }
    private var macOSBackupImportContentTypes: [UTType] { [.scoreboardBackup, .json] }
    private var macOSRosterCSVImportContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    private var macOSImageImportContentTypes: [UTType] { [.image] }
    #endif

    var body: some View {
        alertConfiguredRootView
    }

    private var rootView: some View {
        GeometryReader { proxy in
            let layout = InterfaceLayout(size: proxy.size)
            contentRoot(layout: layout)
        }
    }

    private var synchronizedRootView: some View {
        rootView
        .onReceive(store.$homeTeamName) { homeTeamDraft = $0 }
        .onReceive(store.$guestTeamName) { guestTeamDraft = $0 }
        .onReceive(store.$eventName) { eventNameDraft = $0 }
        .onReceive(store.$homeScore) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestScore) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$period) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$selectedSport) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$gameClockAutosaveRevision) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$defaultClockSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$shotClockAutosaveRevision) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$defaultShotClockSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$customSportConfig) {
            guard !isSetupDraftUpdateSuppressed else { return }
            setupCustomSportConfig = $0
        }
        .onReceive(store.$customDebatePreset) {
            autosaveSelectedGameFile()
            guard !isSetupDraftUpdateSuppressed else { return }
            setupCustomDebatePreset = $0
        }
        .onReceive(store.$activeChessClockSide) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$chessClockPreset) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homePenaltyTimers) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestPenaltyTimers) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$selectedDebatePresetID) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$debateHomeSideLabel) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$debateGuestSideLabel) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$debateCurrentSegmentIndex) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$debatePrepHomeSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$debatePrepGuestSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$debateActiveTimer) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isDebatePrepClockRunning) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isDebateScoreTrackingEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isDebatePlayerTrackingEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isDebatePlayerFoulsEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isDebatePlayerCardsEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isPlayerTrackingEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isPlayerOverlayPaused) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$rosterSizePerTeam) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$displayLineupSize) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerLineupOverflowMode) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerLineupOverflowLogoOverride) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerLineupOverflowNoLogoOverride) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerLineupFadePageSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerLineupScrollSpeed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerLineupScrollDirection) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerViewRosterScope) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerFoulHighlightColor) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isGameClockRedEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$gameClockRedThresholdSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isShotClockRedEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$shotClockRedThresholdSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeSubstitutionsAllowed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestSubstitutionsAllowed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeSubstitutionsUsed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestSubstitutionsUsed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homePausesAllowed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestPausesAllowed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homePausesUsed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestPausesUsed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeTeamFouls) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestTeamFouls) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isDebatePrepTimeEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeRoster) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestRoster) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$externalDisplayBackgroundMode) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$externalDisplayBackgroundImage) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$externalDisplayAnimatedLogoStyle) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$externalDisplayAnimatedLogoBackgroundColor) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$externalDisplayAnimatedLogoSpeed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$externalDisplayAnimatedLogoSize) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$externalDisplayAnimatedLogoOpacity) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$showsExternalDisplayDateTime) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$externalDisplayDateTimeFormat) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$showsExternalDisplayDateTimeSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$showsTeamLogos) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeTeamLogoImage) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestTeamLogoImage) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$showsEventLogo) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$eventLogoImage) { _ in autosaveSelectedGameFile() }
    }

    private var basicSetupDraftConfiguredRootView: some View {
        synchronizedRootView
        .onChange(of: homeTeamDraft) { _, _ in handleSetupDraftChanged() }
        .onChange(of: guestTeamDraft) { _, _ in handleSetupDraftChanged() }
        .onChange(of: eventNameDraft) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupSport) { _, newValue in
            guard !isSetupDraftUpdateSuppressed else { return }
            applySetupSportDefaults(newValue)
            handleSetupDraftChanged()
        }
        .onChange(of: setupPeriod) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupClockSeconds) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupUsesGameClock) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupShotClockSeconds) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupVolleyballMatchFormat) { _, _ in
            setupPeriod = min(setupPeriod, setupPeriodUpperBound)
            handleSetupDraftChanged()
        }
        .onChange(of: setupGuestClockSeconds) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupChessPreset) { _, _ in
            guard !isSetupDraftUpdateSuppressed else { return }
            setupClockSeconds = setupChessPreset.seconds
            setupGuestClockSeconds = setupChessPreset.seconds
            handleSetupDraftChanged()
        }
    }

    private var setupDraftConfiguredRootView: some View {
        basicSetupDraftConfiguredRootView
        .onChange(of: setupDebatePresetID) { _, _ in
            guard !isSetupDraftUpdateSuppressed else { return }
            let preset = setupDebatePresetID == DebatePreset.customID ? setupCustomDebatePreset : DebatePreset.preset(id: setupDebatePresetID)
            setupDebateHomeSideLabel = preset.homeSideLabel
            setupDebateGuestSideLabel = preset.guestSideLabel
            setupDebateScoreTrackingEnabled = preset.defaultScoreTrackingEnabled
            setupDebatePlayerTrackingEnabled = preset.defaultPlayerTrackingEnabled
            setupDebatePlayerFoulsEnabled = preset.defaultPlayerFoulsEnabled
            setupDebatePlayerCardsEnabled = preset.defaultPlayerCardsEnabled
            setupDebatePrepTimeEnabled = preset.isPrepTimeEnabled
            if let firstSegment = preset.segments.first {
                setupClockSeconds = firstSegment.durationSeconds
                setupGuestClockSeconds = firstSegment.durationSeconds
            }
            handleSetupDraftChanged()
        }
        .onChange(of: setupDebateHomeSideLabel) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupDebateGuestSideLabel) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupDebateScoreTrackingEnabled) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupDebatePlayerTrackingEnabled) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupDebatePlayerFoulsEnabled) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupDebatePlayerCardsEnabled) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupDebatePrepTimeEnabled) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupCustomDebatePreset) { _, _ in handleSetupDraftChanged() }
        .onChange(of: setupCustomSportConfig) { _, _ in handleSetupDraftChanged() }
        .onChange(of: selectedStoredGameFileID) { _, _ in
            syncCurrentLogGameFile()
            renameGameFileNameDraft = selectedStoredGameFile?.displayName ?? ""
        }
        .onChange(of: store.isPlayerTrackingEnabled) { _, isEnabled in
            handlePlayerTrackingEnabledChange(isEnabled)
        }
        .onChange(of: setupSport) { _, _ in
            let supportsPlayers = setupSport == .debate ? setupDebatePlayerTrackingEnabled : setupRules.supportsPlayerTracking
            if setupSport != .debate {
                isDebateDesignerVisible = false
            }
            guard selectedSettingsPane == .players, !supportsPlayers else {
                return
            }
            selectedSettingsPane = .game
        }
        .onChange(of: setupCustomSportConfig) { _, _ in
            let supportsPlayers = setupSport == .debate ? setupDebatePlayerTrackingEnabled : setupRules.supportsPlayerTracking
            guard selectedSettingsPane == .players, !supportsPlayers else {
                return
            }
            selectedSettingsPane = .game
        }
        .onChange(of: setupDebatePlayerTrackingEnabled) { _, isEnabled in
            guard selectedSettingsPane == .players, !isEnabled else {
                return
            }
            selectedSettingsPane = .game
        }
    }

    private var integrationEditorSportConfiguredRootView: some View {
        setupDraftConfiguredRootView
        .onChange(of: selectedSettingsPane) { _, pane in
            if pane == .sound {
                selectedSoundSettingsSport = setupSport
            } else if pane == .integration, selectedIntegrationDetail == .bitfocusCompanion {
                selectedCompanionSettingsSport = setupSport
            }
            if pane != .theme {
                isExternalBackgroundImageEditorVisible = false
            }
            if pane != .game {
                isDebateDesignerVisible = false
            }
        }
        .onChange(of: selectedIntegrationDetail) { _, detail in
            guard selectedSettingsPane == .integration, detail == .bitfocusCompanion else {
                return
            }
            selectedCompanionSettingsSport = setupSport
        }
    }

    private var lifecycleConfiguredRootView: some View {
        integrationEditorSportConfiguredRootView
        .onAppear(perform: handleRootAppear)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    #if os(iOS)
    private func updateSettingsKeyboardHeight(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let screenHeight = UIScreen.main.bounds.height
        let overlap = max(0, screenHeight - endFrame.minY)
        let resolvedHeight = overlap < 80 ? 0 : overlap
        withAnimation(.easeOut(duration: 0.22)) {
            settingsKeyboardHeight = resolvedHeight
        }
    }
    #endif

    #if os(iOS)
    private var filePresentationConfiguredRootView: some View {
        lifecycleConfiguredRootView
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateSettingsKeyboardHeight(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) {
                settingsKeyboardHeight = 0
            }
        }
        .sheet(isPresented: $showsGameImporter) {
            ScoreboardDocumentPicker(
                isPresented: $showsGameImporter,
                contentTypes: iOSGameImportContentTypes,
                allowsMultipleSelection: false,
                onCompletion: importGameIntoLibrary
            )
        }
        .sheet(isPresented: $showsBackupImporter) {
            ScoreboardDocumentPicker(
                isPresented: $showsBackupImporter,
                contentTypes: iOSBackupImportContentTypes,
                allowsMultipleSelection: false,
                onCompletion: importBackupForRestore
            )
        }
        .sheet(isPresented: $showsRosterCSVImporter) {
            ScoreboardDocumentPicker(
                isPresented: $showsRosterCSVImporter,
                contentTypes: iOSRosterCSVImportContentTypes,
                allowsMultipleSelection: false,
                onCompletion: importRosterCSV
            )
        }
        .photosPicker(
            isPresented: $showsExternalBackgroundPhotoPicker,
            selection: $selectedExternalBackgroundPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .photosPicker(
            isPresented: $showsHomeLogoPhotoPicker,
            selection: $selectedHomeLogoPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .photosPicker(
            isPresented: $showsGuestLogoPhotoPicker,
            selection: $selectedGuestLogoPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .photosPicker(
            isPresented: $showsEventLogoPhotoPicker,
            selection: $selectedEventLogoPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedExternalBackgroundPhotoItem) { _, item in
            guard let item else { return }
            Task {
                await importExternalBackgroundPhoto(item)
                await MainActor.run {
                    selectedExternalBackgroundPhotoItem = nil
                }
            }
        }
        .onChange(of: selectedHomeLogoPhotoItem) { _, item in
            guard let item else { return }
            Task {
                await importTeamLogoPhoto(item, for: .home)
                await MainActor.run {
                    selectedHomeLogoPhotoItem = nil
                }
            }
        }
        .onChange(of: selectedGuestLogoPhotoItem) { _, item in
            guard let item else { return }
            Task {
                await importTeamLogoPhoto(item, for: .guest)
                await MainActor.run {
                    selectedGuestLogoPhotoItem = nil
                }
            }
        }
        .onChange(of: selectedEventLogoPhotoItem) { _, item in
            guard let item else { return }
            Task {
                await importEventLogoPhoto(item)
                await MainActor.run {
                    selectedEventLogoPhotoItem = nil
                }
            }
        }
        .scoreboardShareExporter(payload: $exportSharePayload)
        .statusBar(hidden: showsLocalScoreboard)
    }
    #else
    private var filePresentationConfiguredRootView: some View {
        lifecycleConfiguredRootView
            .scoreboardShareExporter(payload: $exportSharePayload)
    }
    #endif

    private var alertConfiguredRootView: some View {
        filePresentationConfiguredRootView
        .alert(item: activeAlertBinding) { alert in
            switch alert {
            case .fileOperation(let error):
                return Alert(
                    title: Text("File Error"),
                    message: Text(error.message),
                    dismissButton: .cancel(Text("OK")) {
                        fileOperationError = nil
                    }
                )
            case .gameConfirmation(let action):
                return Alert(
                    title: Text(gameConfirmationTitle(for: action)),
                    message: Text(gameConfirmationMessage(for: action)),
                    primaryButton: .destructive(Text(gameConfirmationButtonTitle(for: action))) {
                        pendingGameConfirmation = nil
                        performConfirmedGameAction(action)
                    },
                    secondaryButton: .cancel {
                        pendingGameConfirmation = nil
                    }
                )
            case .backupRestore(let backupRestore):
                return Alert(
                    title: Text("Restore Full Backup"),
                    message: Text(backupRestoreMessage(for: backupRestore)),
                    primaryButton: .destructive(Text("Restore")) {
                        pendingBackupRestore = nil
                        restoreFullBackup(backupRestore.backup)
                    },
                    secondaryButton: .cancel {
                        pendingBackupRestore = nil
                    }
                )
            case .remoteDisplayTakeover(let takeover):
                return Alert(
                    title: Text("Replace Remote Display Operator?"),
                    message: Text(remoteDisplayTakeoverMessage(for: takeover)),
                    primaryButton: .destructive(Text("Replace")) {
                        pendingRemoteDisplayTakeover = nil
                        performRemoteDisplayTakeover(takeover)
                    },
                    secondaryButton: .cancel {
                        pendingRemoteDisplayTakeover = nil
                    }
                )
            case .logDeletion(let session):
                return Alert(
                    title: Text("Delete Log Session"),
                    message: Text(logDeletionMessage(for: session)),
                    primaryButton: .destructive(Text("Delete")) {
                        pendingLogDeletion = nil
                        deleteLogSession(session)
                    },
                    secondaryButton: .cancel {
                        pendingLogDeletion = nil
                    }
                )
            case .factoryDefault:
                return Alert(
                    title: Text("Factory Default App"),
                    message: Text("This will delete all local game files, log sessions, custom webpages, roster edits, settings, integrations, and current game state."),
                    primaryButton: .destructive(Text("Factory Default")) {
                        isFactoryDefaultConfirmationPresented = false
                        performFactoryDefaultReset()
                    },
                    secondaryButton: .cancel {
                        isFactoryDefaultConfirmationPresented = false
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scoreboardLogSessionsDidChange)) { _ in
            refreshStoredLogSessions()
        }
        .sheet(isPresented: $showsGettingStarted, onDismiss: handleGettingStartedDismissed) {
            gettingStartedSheet
        }
        .sheet(isPresented: $showsBunnyEasterEgg) {
            bunnyEasterEggSheet
        }
        .sheet(item: $pendingPenaltySelection) { selection in
            penaltyPlayerSelectionSheet(selection)
        }
        #if os(macOS)
        .background(ControlBoardWindowConfigurator())
        #endif
    }

    private func setupScreen(layout: InterfaceLayout) -> some View {
        if !isInitialSetupStateLoaded {
            return AnyView(setupLoadingScreen(layout: layout))
        }

        return AnyView(settingsSetupScreen(layout: layout))
    }

    private func setupLoadingScreen(layout: InterfaceLayout) -> some View {
        VStack(spacing: 16) {
            if let fileMigrationProgress, fileMigrationProgress.totalFiles > 0 {
                ProgressView(
                    value: Double(fileMigrationProgress.completedFiles),
                    total: Double(fileMigrationProgress.totalFiles)
                )
                .controlSize(.large)
                .frame(maxWidth: min(360, layout.contentMaxWidth))
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            Text(fileMigrationProgress == nil ? "Loading scoreboard setup" : "Moving files into Files")
                .font(.headline.weight(.semibold))
                .foregroundStyle(settingsPalette.primaryText)

            if let fileMigrationProgress {
                Text(fileMigrationDetailText(fileMigrationProgress))
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settingsPalette.shellBackground)
        .padding(layout.outerPadding)
    }

    private func fileMigrationOverlay(_ progress: ScoreboardFileMigrationProgress, layout: InterfaceLayout) -> some View {
        VStack(spacing: 14) {
            if progress.totalFiles > 0 {
                ProgressView(value: Double(progress.completedFiles), total: Double(progress.totalFiles))
                    .frame(maxWidth: 320)
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            Text("Moving files into Files")
                .font(.headline.weight(.semibold))
                .foregroundStyle(settingsPalette.primaryText)

            Text(fileMigrationDetailText(progress))
                .font(.subheadline)
                .foregroundStyle(settingsPalette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: min(420, layout.contentMaxWidth))
        .background(settingsPalette.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(settingsPalette.cardBorder)
        )
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 14)
        .padding(layout.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
        }
    }

    private func fileMigrationDetailText(_ progress: ScoreboardFileMigrationProgress) -> String {
        guard progress.totalFiles > 0 else {
            return localizedAppString("Preparing local files for the Files app.")
        }

        if let currentFilename = progress.currentFilename {
            return localizedAppFormat(
                "Moving %@ (%lld of %lld)",
                currentFilename,
                min(progress.completedFiles + 1, progress.totalFiles),
                progress.totalFiles
            )
        }

        return localizedAppFormat("Moved %lld of %lld files.", progress.completedFiles, progress.totalFiles)
    }

    private func settingsSetupScreen(layout: InterfaceLayout) -> some View {
        let usesCompactNavigation = layout.settingsUsesCompactNavigation || isSettingsSidebarCollapsed
        let shellCornerRadius = layout.settingsShellCornerRadius
        let shellContent: AnyView

        if usesCompactNavigation {
            shellContent = AnyView(
                VStack(spacing: 0) {
                    settingsCompactNavigationBar(layout: layout, showsSidebarToggle: !layout.settingsUsesCompactNavigation)

                    settingsDetailPane(layout: layout)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            )
        } else {
            shellContent = AnyView(
                HStack(spacing: 0) {
                    settingsSidebar(layout: layout)
                        .frame(width: layout.settingsSidebarWidth)

                    settingsDetailPane(layout: layout)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            )
        }

        return shellContent
        .background(settingsPalette.shellBackground)
        .clipShape(RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                .strokeBorder(settingsPalette.divider)
        )
        .padding(layout.settingsOuterPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func settingsSidebar(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.system(size: layout.heroTitleSize - 4, weight: .black, design: .rounded))
                            .foregroundStyle(settingsPalette.primaryText)

                        Text(localizedAppString(setupDescription))
                            .font(.subheadline)
                            .foregroundStyle(settingsPalette.secondaryText)
                    }

                    VStack(spacing: 8) {
                        ForEach(SettingsPane.allCases) { pane in
                            settingsSidebarButton(pane)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(spacing: 10) {
                Button {
                    openSetupGame()
                } label: {
                    localizedAppText(store.didCompleteSetup ? "Back to Live Board" : "Go to Control Board")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(settingsPalette.secondaryButtonText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(settingsPalette.secondaryButtonBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSettingsSidebarCollapsed = true
                    }
                } label: {
                    Label(localizedAppString("Hide Sidebar"), systemImage: "sidebar.leading")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(settingsPalette.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedAppString("Hide Settings Sidebar"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(settingsPalette.sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(settingsPalette.divider)
                .frame(width: 1)
        }
    }

    private func settingsCompactNavigationBar(layout: InterfaceLayout, showsSidebarToggle: Bool) -> some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(SettingsPane.allCases) { pane in
                    Button {
                        selectSettingsPane(pane)
                    } label: {
                        Label(localizedAppString(pane.title), systemImage: pane.systemImage)
                    }
                    .disabled(!isSettingsPaneEnabled(pane))
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedSettingsPane.systemImage)
                        .font(.headline.weight(.semibold))
                        .frame(width: 22)

                    localizedAppText(selectedSettingsPane.title)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .layoutPriority(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.black))
                }
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizedAppString("Settings Section"))

            if showsSidebarToggle {
                settingsCompactNavigationIconButton("Show Sidebar", systemImage: "sidebar.leading") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSettingsSidebarCollapsed = false
                    }
                }
            }

            settingsCompactNavigationIconButton(
                store.didCompleteSetup ? "Back to Live Board" : "Go to Control Board",
                systemImage: store.didCompleteSetup ? "play.rectangle.fill" : "play.fill"
            ) {
                openSetupGame()
            }
        }
        .padding(.horizontal, layout.settingsCompactNavigationHorizontalPadding)
        .padding(.vertical, layout.settingsCompactNavigationVerticalPadding)
        .background(settingsPalette.sidebarBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(settingsPalette.divider)
                .frame(height: 1)
        }
    }

    private func settingsCompactNavigationIconButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(settingsPalette.primaryText)
                .frame(width: 44, height: 44)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
    }

    private func settingsSidebarButton(_ pane: SettingsPane) -> some View {
        let isEnabled = isSettingsPaneEnabled(pane)
        return Button {
            selectSettingsPane(pane)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: pane.systemImage)
                    .font(.headline.weight(.semibold))
                    .frame(width: 22)

                localizedAppText(pane.title)
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)
            }
            .foregroundStyle(selectedSettingsPane == pane ? settingsPalette.accentText : settingsPalette.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                (selectedSettingsPane == pane ? settingsPalette.accent : Color.clear),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .opacity(isEnabled ? 1 : 0.38)
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }

    private func selectSettingsPane(_ pane: SettingsPane) {
        guard isSettingsPaneEnabled(pane) else { return }
        focusedSettingsTextFieldID = nil
        selectedSettingsPane = pane
    }

    private func settingsDetailPane(layout: InterfaceLayout) -> some View {
        Group {
            if selectedSettingsPane == .files {
                settingsLibraryDetailPane(layout: layout)
            } else if selectedSettingsPane == .logs, !layout.settingsUsesCompactNavigation {
                settingsFixedManagerDetailPane(layout: layout)
            } else {
                settingsScrollableDetailPane(layout: layout)
            }
        }
        .background(settingsPalette.detailBackground)
    }

    private func settingsLibraryDetailPane(layout: InterfaceLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.settingsDetailSpacing) {
                settingsPaneHeader(layout: layout)
                settingsPaneIntroTip
                settingsFilesPane(layout: layout, fillsAvailableHeight: false)
            }
            .padding(layout.settingsDetailPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .id(selectedSettingsPane.id)
        .scoreboardSettingsKeyboardAwareScroll(bottomInset: settingsKeyboardAvoidanceInset)
    }

    private func settingsFixedManagerDetailPane(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.settingsDetailSpacing) {
            settingsPaneHeader(layout: layout)
            settingsPaneIntroTip
            settingsPaneContent(layout: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(layout.settingsDetailPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func settingsScrollableDetailPane(layout: InterfaceLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.settingsDetailSpacing) {
                settingsPaneHeader(layout: layout)
                settingsPaneIntroTip
                settingsPaneContent(layout: layout)
            }
            .padding(layout.settingsDetailPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .id(selectedSettingsPane.id)
        .scoreboardSettingsKeyboardAwareScroll(bottomInset: settingsKeyboardAvoidanceInset)
    }

    private func settingsPaneHeader(layout: InterfaceLayout) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                localizedAppText(selectedSettingsPane.title)
                    .font(.system(size: layout.settingsHeaderTitleSize, weight: .black, design: .rounded))
                    .foregroundStyle(settingsPalette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                localizedAppText(selectedSettingsPane.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .lineLimit(layout.settingsUsesCompactNavigation ? 3 : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var settingsPaneIntroTip: some View {
        if store.areTipsEnabled, let introduction = settingsPaneIntroduction(for: selectedSettingsPane) {
            settingsPageTip(introduction, title: selectedSettingsPane.title, systemImage: selectedSettingsPane.systemImage)
        }
    }

    private func settingsPaneIntroduction(for pane: SettingsPane) -> String? {
        switch pane {
        case .game:
            return "Use Game Setup to choose the sport, name the event, set both sides, and define the starting rules that the live control board will use. Changes here are the defaults for the next run of the current game, so set clocks, periods, tracking, and sport-specific options before operators begin."
        case .players:
            return "Use Players to prepare roster details and decide which player data should appear during the game. This page controls roster size, active lineup state, fouls, cards, overlay pause behavior, and CSV roster import or export when the selected sport supports player tracking."
        case .display:
            return "Use Display to shape the public scoreboard presentation without changing the live game state. These options control lineup overflow, team and event logos, foul highlighting, and clock warning colors shown on external, public, and remote displays."
        case .sound:
            return "Use Sound to decide whether the app can play audio and which tones fire for each sport event. Sound settings are global to the app, while sport event assignments let different game types use different start, stop, warning, and expiration cues."
        case .theme:
            return "Use Theme to set the visual style shared by setup, live controls, previews, and public scoreboard outputs. This page also controls display direction, public-display background treatment, and optional date or time overlays."
        case .files:
            #if os(iOS)
            return "Use Library to preserve reusable game setups, recover live state, and move data between devices. Game files also appear in the Files app under Scoreboard > Library."
            #else
            return "Use Library to preserve reusable game setups, recover live state, and move data between devices. Game files keep operator-facing setup and scoreboard state, while full backups can include settings, game files, current game state, and logs."
            #endif
        case .logs:
            #if os(iOS)
            return "Use Logs to review the sequence of actions captured during a scoreboard run. Log sessions also appear in the Files app under Scoreboard > Logs."
            #else
            return "Use Logs to review the sequence of actions captured during a scoreboard run. Sessions can be inspected for audit or replay context, exported for review, or removed when they are no longer needed."
            #endif
        case .integration:
            return "Use Integration to connect Scoreboard with trusted production tools on the local network. Remote Display, Web API, and Bitfocus Companion are configured independently, so enabling one integration does not turn another one off."
        case .about:
            return nil
        }
    }

    private var settingsSportSetupGuidance: (message: String, systemImage: String) {
        switch setupSport {
        case .simple:
            return (
                "For Simple, choose the opening countdown and side names for a compact score-and-clock board. Use it when operators only need score, optional clock state, quick side swaps, and reset controls without sport-specific player or penalty tools.",
                "timer"
            )
        case .basketball:
            return (
                "For Basketball, confirm the starting period, opening game clock, and shot-clock default before going live. The control board will expose score buttons, period controls, possession, shot-clock presets, and player tools based on this setup.",
                "timer.circle"
            )
        case .volleyball:
            return (
                "For Volleyball, choose best-of-3 or best-of-5, confirm the starting period, and keep the serve timer at 8 seconds for indoor rules. The live board records period winners, serving side, substitutions, cards, score, and optional match timing.",
                "person.3"
            )
        case .soccer:
            return (
                "For Soccer, set halves, the match clock, team names, substitution allowances, and player tracking before kickoff. The live board uses those choices for score, cards, lineups, swaps, and the public player display.",
                "flag.checkered"
            )
        case .hockey:
            return (
                "For Hockey, confirm the period and clock setup before puck drop. The live board adds side-specific penalty timers, so team names, period timing, and player details should be ready before penalties are tracked.",
                "clock"
            )
        case .chess:
            return (
                "For Chess, choose the clock preset and confirm both starting clocks. The control board runs one active side clock at a time, so correct clock lengths and side names are the key setup choices before starting the match.",
                "timer"
            )
        case .debate:
            return (
                "For Debate, start by choosing a preset or Custom Debate, then verify side labels, segment order, prep time, scoring, and player tracking before opening the live board. The control board advances through these segments in order, so this setup page is where the round flow should be checked.",
                "quote.bubble"
            )
        case .custom:
            return (
                "For Custom, build the sport from modules: score behavior, clock mode, period labels, secondary timer, possession, player tracking, substitutions, penalty timers, and team counters. Turn on only the pieces operators need, then set the starting clock and period values before going live.",
                "slider.horizontal.3"
            )
        }
    }

    @ViewBuilder
    private var settingsSportSetupGuidanceTip: some View {
        if store.areTipsEnabled {
            let guidance = settingsSportSetupGuidance
            settingsPageTip(guidance.message, title: "\(setupSport.title) Setup", systemImage: guidance.systemImage)
        }
    }

    private func settingsPageTip(_ message: String, title: String = "Page Overview", systemImage: String = "lightbulb") -> some View {
        settingsGuidanceRow(title: title, message: message, systemImage: systemImage)
    }

    @ViewBuilder
    private func settingsOptionTip(_ message: String, systemImage: String = "lightbulb") -> some View {
        if store.areTipsEnabled {
            let title = settingsOptionTipTitle(for: message)
            let resolvedSystemImage = settingsOptionTipSystemImage(for: message, fallback: systemImage)
            settingsGuidanceRow(title: title, message: message, systemImage: resolvedSystemImage)
        }
    }

    private func settingsGuidanceRow(title: String, message: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(settingsPalette.accent)
                .frame(width: 30, height: 30)
                .background(settingsPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                localizedAppText(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(settingsPalette.primaryText)

                Text(localizedAppString(message))
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(settingsPalette.cardBorder, lineWidth: 1)
        )
    }

    private func settingsOptionTipTitle(for message: String) -> String {
        let lowercasedMessage = message.lowercased()

        if lowercasedMessage.hasPrefix("pick the sport") { return "Choose Sport" }
        if lowercasedMessage.hasPrefix("name the event") { return "Event Name" }
        if lowercasedMessage.hasPrefix("set the two side names") { return "Team Names" }
        if lowercasedMessage.hasPrefix("review the starting game state") { return "Starting State" }
        if lowercasedMessage.hasPrefix("set substitution allowances") { return "Substitution Limits" }
        if lowercasedMessage.hasPrefix("set pause allowances") { return "Pause Limits" }
        if lowercasedMessage.hasPrefix("use general to define the custom sport") { return "Custom General" }
        if lowercasedMessage.hasPrefix("use clock") { return "Clock Setup" }
        if lowercasedMessage.hasPrefix("use period") { return "Period Setup" }
        if lowercasedMessage.hasPrefix("use shot clock") { return "Shot Clock Setup" }
        if lowercasedMessage.hasPrefix("use possession") { return "Possession Setup" }
        if lowercasedMessage.hasPrefix("use player settings when the custom sport") { return "Custom Player Tools" }
        if lowercasedMessage.hasPrefix("use team settings") { return "Team Counters" }
        if lowercasedMessage.hasPrefix("use general to choose the debate") { return "Debate Format" }
        if lowercasedMessage.hasPrefix("use segments") { return "Debate Segments" }
        if lowercasedMessage.hasPrefix("use player settings for debate") { return "Debate Speakers" }
        if lowercasedMessage.hasPrefix("use prep") { return "Prep Clocks" }
        if lowercasedMessage.contains("no timer segments") || lowercasedMessage.hasPrefix("no timer segments") { return "No Timer Segments" }
        if lowercasedMessage.contains("dual clock segments") || lowercasedMessage.hasPrefix("dual clock segments") { return "Dual Clock Segments" }
        if lowercasedMessage.hasPrefix("use templates") { return "Debate Templates" }
        if lowercasedMessage.hasPrefix("use format") { return "Custom Format" }
        if lowercasedMessage.hasPrefix("use segment blocks") { return "Segment Blocks" }
        if lowercasedMessage.hasPrefix("display direction") { return "Display Direction" }
        if lowercasedMessage.hasPrefix("keep this limitation") { return "iPad Web API" }
        if lowercasedMessage.hasPrefix("use web api") { return "Web API Output" }
        if lowercasedMessage.hasPrefix("review security") { return "Network Security" }
        if lowercasedMessage.hasPrefix("choose which integration") { return "Integration Selector" }
        if lowercasedMessage.hasPrefix("use remote display mode") { return "Remote Display Mode" }
        if lowercasedMessage.hasPrefix("use this device") { return "Remote Display Mode" }
        if lowercasedMessage.hasPrefix("use remote display") { return "Remote Display Mode" }
        if lowercasedMessage.hasPrefix("turn on operator broadcast") { return "Operator Broadcast" }
        if lowercasedMessage.hasPrefix("use displays") { return "Display Pairing" }
        if lowercasedMessage.hasPrefix("each saved or connected remote display") { return "Remote Direction" }
        if lowercasedMessage.hasPrefix("use bitfocus companion settings") { return "Companion Settings" }
        if lowercasedMessage.hasPrefix("use companion") { return "Companion Automation" }
        if lowercasedMessage.hasPrefix("choose the sport whose companion") { return "Sport Assignments" }
        if lowercasedMessage.hasPrefix("use event commands") { return "Event Commands" }
        if lowercasedMessage.hasPrefix("local network permission") { return "Local Network" }

        return "Setup Guidance"
    }

    private func settingsOptionTipSystemImage(for message: String, fallback: String) -> String {
        let lowercasedMessage = message.lowercased()

        if lowercasedMessage.hasPrefix("review the starting game state") {
            return "checklist"
        }
        if lowercasedMessage.hasPrefix("use segment blocks") {
            return "square.grid.2x2"
        }
        if lowercasedMessage.hasPrefix("display direction") || lowercasedMessage.hasPrefix("each saved or connected remote display") {
            return "arrow.left.and.right"
        }
        if lowercasedMessage.contains("no timer segments") || lowercasedMessage.hasPrefix("no timer segments") {
            return "pause.circle"
        }
        if lowercasedMessage.contains("dual clock segments") || lowercasedMessage.hasPrefix("dual clock segments") {
            return "person.2"
        }

        return fallback
    }

    @ViewBuilder
    private func scoreboardInlineTip(_ tip: (any Tip)?) -> some View {
        if store.areTipsEnabled {
            TipView(tip)
        }
    }

    private func scoreboardTipID(prefix: String, message: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in message.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return "\(prefix).\(tipHistoryResetGeneration).\(String(hash, radix: 16))"
    }

    private var arePopoverTipsEnabled: Bool {
        store.areTipsEnabled && !showsGettingStarted
    }

    private func isSettingsPaneEnabled(_ pane: SettingsPane) -> Bool {
        switch pane {
        case .players:
            return setupSport == .debate ? setupDebatePlayerTrackingEnabled : setupRules.supportsPlayerTracking
        default:
            return true
        }
    }

    @ViewBuilder
    private func settingsPaneContent(layout: InterfaceLayout) -> some View {
        switch selectedSettingsPane {
        case .game:
            settingsGamePane(layout: layout)
        case .players:
            settingsPlayersPane(layout: layout)
        case .display:
            settingsDisplayPane()
        case .sound:
            settingsSoundPane(layout: layout)
        case .theme:
            settingsThemePane()
        case .files:
            settingsFilesPane(layout: layout)
        case .logs:
            settingsLogsPane(layout: layout)
        case .integration:
            settingsIntegrationPane(layout: layout)
        case .about:
            settingsAboutPane()
        }
    }

    private func settingsGamePane(layout: InterfaceLayout) -> AnyView {
        if isDebateDesignerVisible {
            if debateDesignerRequiresLandscape(layout: layout) {
                return AnyView(debateDesignerLandscapeRequiredPage(layout: layout))
            }
            return AnyView(debateDesignerPage(layout: layout))
        }

        return AnyView(settingsGameOverviewPane(layout: layout))
    }

    private func settingsGameOverviewPane(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsGameIdentitySections(layout: layout)
            settingsSportSetupGuidanceTip
            settingsGameRulesSections(layout: layout)
            settingsSubstitutionTrackingSection()
            settingsPauseTrackingSection()
        }
    }

    @ViewBuilder
    private func settingsGameIdentitySections(layout: InterfaceLayout) -> some View {
        settingsSection(title: "Sport", footer: "Choose the scoreboard mode before editing teams, clocks, and tracking rules.") {
            settingsOptionTip("Pick the sport or custom ruleset first because this choice decides which score buttons, timers, periods, player tools, and display controls appear across the rest of setup and the live board.", systemImage: "slider.horizontal.3")
            sportSelectionGrid(layout: layout)
        }

        settingsSection(title: "Event") {
            settingsOptionTip("Name the event when the public board should show tournament, venue, round, or broadcast context. Leave it blank for a cleaner scoreboard that focuses only on the teams and live state.", systemImage: "textformat")
            settingsPlainTextEntryRow(title: "Event Name", text: $eventNameDraft)
        }

        settingsSection(title: "Teams") {
            settingsOptionTip("Set the two side names exactly as operators and viewers should see them. These names drive the setup screen, live controls, saved game files, public scoreboard, logs, and connected displays.", systemImage: "person.2")
            settingsTextEntryRow(title: "Home Team", text: $homeTeamDraft, teamSide: true)
            settingsDivider()
            settingsTextEntryRow(title: "Guest Team", text: $guestTeamDraft, teamSide: false)
        }
    }

    @ViewBuilder
    private func settingsGameRulesSections(layout: InterfaceLayout) -> some View {
        if setupSport == .custom {
            customSportSettingsSections()
        } else if setupSport == .debate {
            debateSettingsSections(layout: layout)
        } else {
            builtInSportGameSettingsSection()
        }
    }

    private func builtInSportGameSettingsSection() -> some View {
        settingsSection(title: "Game") {
            settingsOptionTip("Review the starting game state for the selected sport before opening the control board. Only options that matter to this sport appear here, such as period, clock presets, chess clocks, match timer, or shot clock.", systemImage: "slider.horizontal.3")
            builtInSportGameSettingsRows()
        }
    }

    @ViewBuilder
    private func builtInSportGameSettingsRows() -> some View {
        if setupRules.supportsPeriod {
            settingsStepperValueRow(
                title: "Starting \(setupRules.periodTitle)",
                value: "\(setupPeriod)",
                decrement: { setupPeriod = max(1, setupPeriod - 1) },
                increment: { setupPeriod = min(setupPeriodUpperBound, setupPeriod + 1) }
            )
        }

        if setupSport == .volleyball {
            settingsDivider()
            settingsSegmentRow(
                title: "Match Format",
                options: [
                    (VolleyballMatchFormat.bestOf5.title, VolleyballMatchFormat.bestOf5.maximumSets),
                    (VolleyballMatchFormat.bestOf3.title, VolleyballMatchFormat.bestOf3.maximumSets)
                ],
                selection: Binding(
                    get: { setupVolleyballMatchFormat.maximumSets },
                    set: { setupVolleyballMatchFormat = $0 == VolleyballMatchFormat.bestOf3.maximumSets ? .bestOf3 : .bestOf5 }
                )
            )
            settingsDivider()
            settingsToggleRow(title: "Enable Match Timer", isOn: $setupUsesGameClock)
        }

        if setupRules.usesChessClocks {
            chessClockSetupRows()
        } else if setupRules.mainClockMode != .disabled && (setupSport != .volleyball || setupUsesGameClock) {
            sharedClockSetupRows()
        }

        if setupRules.supportsShotClock {
            shotClockSetupRows()
        }
    }

    @ViewBuilder
    private func chessClockSetupRows() -> some View {
        if setupSport == .chess {
            settingsDivider()
            settingsSegmentRow(
                title: "Preset",
                options: ChessClockPreset.allCases.map { ($0.title, $0.seconds) },
                selection: Binding(
                    get: { setupChessPreset.seconds },
                    set: { value in
                        if let preset = ChessClockPreset.allCases.first(where: { $0.seconds == value }) {
                            setupChessPreset = preset
                        }
                    }
                )
            )
        }

        settingsDivider()
        settingsStepperValueRow(
            title: "Home Clock",
            value: formatClock(setupClockSeconds),
            decrement: { setupClockSeconds = max(0, setupClockSeconds - 60) },
            increment: { setupClockSeconds = min(ScoreboardStore.maxGameClockSeconds, setupClockSeconds + 60) }
        )
        settingsDivider()
        settingsStepperValueRow(
            title: "Guest Clock",
            value: formatClock(setupGuestClockSeconds),
            decrement: { setupGuestClockSeconds = max(0, setupGuestClockSeconds - 60) },
            increment: { setupGuestClockSeconds = min(ScoreboardStore.maxGameClockSeconds, setupGuestClockSeconds + 60) }
        )
    }

    @ViewBuilder
    private func sharedClockSetupRows() -> some View {
        settingsDivider()
        settingsStepperValueRow(
            title: "Opening Clock",
            value: formatClock(setupClockSeconds),
            decrement: { setupClockSeconds = max(0, setupClockSeconds - 60) },
            increment: { setupClockSeconds = min(ScoreboardStore.maxGameClockSeconds, setupClockSeconds + 60) }
        )
        settingsDivider()
        if setupSport == .simple {
            settingsPresetButtonGrid(
                title: "Clock Preset",
                options: clockPresetOptions(for: setupSport),
                selection: $setupClockSeconds
            )
        } else {
            settingsSegmentRow(
                title: "Clock Preset",
                options: clockPresetOptions(for: setupSport),
                selection: $setupClockSeconds
            )
        }
    }

    @ViewBuilder
    private func shotClockSetupRows() -> some View {
        settingsDivider()
        settingsStepperValueRow(
            title: setupUsesServeTimer ? "Serve Timer" : "Shot Clock",
            value: ScoreboardStore.formatShotClock(setupShotClockSeconds),
            decrement: { setupShotClockSeconds = max(0, setupShotClockSeconds - 1) },
            increment: { setupShotClockSeconds = min(ScoreboardStore.maxShotClockSeconds, setupShotClockSeconds + 1) }
        )
        settingsDivider()
        if setupUsesServeTimer {
            settingsSegmentRow(
                title: "Serve Preset",
                options: [
                    ("8", 8)
                ],
                selection: $setupShotClockSeconds
            )
        } else {
            settingsSegmentRow(
                title: "Shot Preset",
                options: [
                    ("24", 24),
                    ("14", 14)
                ],
                selection: $setupShotClockSeconds
            )
        }
    }

    @ViewBuilder
    private func settingsSubstitutionTrackingSection() -> some View {
        if setupRules.showsSubstitutionTracking && setupSport != .chess && setupSport != .debate && (setupSport != .custom || setupCustomSportConfig.isSubstitutionTrackingEnabled) {
            settingsSection(title: "Substitutions", footer: "Set how many player swaps each team can use during the match.") {
                settingsOptionTip("Set substitution allowances before the match so the live board can count remaining swaps for each side. These limits are saved with the current game setup and can differ for home and guest.", systemImage: "arrow.left.arrow.right")
                settingsStepperValueRow(
                    title: "Home Allowed",
                    value: "\(store.homeSubstitutionsAllowed)",
                    decrement: { store.setSubstitutionsAllowed(for: .home, to: store.homeSubstitutionsAllowed - 1) },
                    increment: { store.setSubstitutionsAllowed(for: .home, to: store.homeSubstitutionsAllowed + 1) }
                )
                settingsDivider()
                settingsStepperValueRow(
                    title: "Guest Allowed",
                    value: "\(store.guestSubstitutionsAllowed)",
                    decrement: { store.setSubstitutionsAllowed(for: .guest, to: store.guestSubstitutionsAllowed - 1) },
                    increment: { store.setSubstitutionsAllowed(for: .guest, to: store.guestSubstitutionsAllowed + 1) }
                )
            }
        }
    }

    @ViewBuilder
    private func settingsPauseTrackingSection() -> some View {
        if setupRules.showsPauseTracking && setupSport != .chess && setupSport != .debate && (setupSport != .custom || setupCustomSportConfig.isPauseTrackingEnabled) {
            settingsSection(title: "Pauses", footer: "Set how many team pauses each side can use during the match.") {
                settingsOptionTip("Set pause allowances before the match so the live board can count remaining pauses for each side. These limits are saved with the current game setup and can differ for home and guest.", systemImage: "pause.circle")
                settingsStepperValueRow(
                    title: "Home Allowed",
                    value: "\(store.homePausesAllowed)",
                    decrement: { store.setPausesAllowed(for: .home, to: store.homePausesAllowed - 1) },
                    increment: { store.setPausesAllowed(for: .home, to: store.homePausesAllowed + 1) }
                )
                settingsDivider()
                settingsStepperValueRow(
                    title: "Guest Allowed",
                    value: "\(store.guestPausesAllowed)",
                    decrement: { store.setPausesAllowed(for: .guest, to: store.guestPausesAllowed - 1) },
                    increment: { store.setPausesAllowed(for: .guest, to: store.guestPausesAllowed + 1) }
                )
            }
        }
    }

    @ViewBuilder
    private func customSportSettingsSections() -> some View {
        settingsSection(title: "General", footer: "Core custom sport identity and scoring behavior.") {
            settingsOptionTip("Use General to define the custom sport name and whether the scoreboard should track points at all. When score tracking is enabled, choose the button layout that best matches how operators usually add points.", systemImage: "tag")
            settingsTextEntryRow(title: "Custom Title", text: Binding(
                get: { setupCustomSportConfig.title },
                set: { setupCustomSportConfig.title = $0 }
            ))
            settingsDivider()
            settingsToggleRow(title: "Score Tracking", isOn: Binding(
                get: { setupCustomSportConfig.isScoreEnabled },
                set: {
                    setupCustomSportConfig.isScoreEnabled = $0
                    if !$0 {
                        setupCustomSportConfig.isPeriodWinTrackingEnabled = false
                    }
                }
            ))
            if setupCustomSportConfig.isScoreEnabled {
                settingsDivider()
                settingsPickerRow(
                    title: "Score Buttons",
                    selection: Binding(
                        get: { setupCustomSportConfig.scoreStepPreset },
                        set: { setupCustomSportConfig.scoreStepPreset = $0 }
                    ),
                    options: CustomScoreStepPreset.allCases
                ) { $0.title }
            }
        }

        settingsSection(title: "Clock", footer: "Choose between a shared game clock and chess-style side clocks.") {
            settingsOptionTip("Use Clock to decide whether the custom sport has one shared timer, no main timer, count-up or count-down behavior, or separate side clocks. The opening values here become the live board reset targets.", systemImage: "timer")
            settingsToggleRow(title: "Chess Style Clocks", isOn: Binding(
                get: { setupCustomSportConfig.usesChessClocks },
                set: { setupCustomSportConfig.usesChessClocks = $0 }
            ))
            if setupCustomSportConfig.usesChessClocks {
                settingsDivider()
                settingsStepperValueRow(
                    title: "Home Clock",
                    value: formatClock(setupClockSeconds),
                    decrement: { setupClockSeconds = max(0, setupClockSeconds - 60) },
                    increment: { setupClockSeconds = min(ScoreboardStore.maxGameClockSeconds, setupClockSeconds + 60) }
                )
                settingsDivider()
                settingsStepperValueRow(
                    title: "Guest Clock",
                    value: formatClock(setupGuestClockSeconds),
                    decrement: { setupGuestClockSeconds = max(0, setupGuestClockSeconds - 60) },
                    increment: { setupGuestClockSeconds = min(ScoreboardStore.maxGameClockSeconds, setupGuestClockSeconds + 60) }
                )
            } else {
                settingsDivider()
                settingsPickerRow(
                    title: "Clock Mode",
                    selection: Binding(
                        get: { setupCustomSportConfig.mainClockMode },
                        set: { setupCustomSportConfig.mainClockMode = $0 }
                    ),
                    options: MainClockMode.allCases
                ) { $0.title }
                if setupCustomSportConfig.mainClockMode != .disabled {
                    settingsDivider()
                    settingsStepperValueRow(
                        title: "Opening Clock",
                        value: formatClock(setupClockSeconds),
                        decrement: { setupClockSeconds = max(0, setupClockSeconds - 60) },
                        increment: { setupClockSeconds = min(ScoreboardStore.maxGameClockSeconds, setupClockSeconds + 60) }
                    )
                    settingsDivider()
                    settingsSegmentRow(
                        title: "Clock Preset",
                        options: clockPresetOptions(for: .custom),
                        selection: $setupClockSeconds
                    )
                }
            }
        }

        settingsSection(title: "Period", footer: "Enable period tracking and define the labels shown on the board.") {
            settingsOptionTip("Use Period when the custom sport has halves, innings, rounds, segments, or another phase label. The full and short labels are used by the public board, live controls, and logs.", systemImage: "number")
            settingsToggleRow(title: "Period Tracking", isOn: Binding(
                get: { setupCustomSportConfig.isPeriodEnabled },
                set: {
                    setupCustomSportConfig.isPeriodEnabled = $0
                    if !$0 {
                        setupCustomSportConfig.isPeriodWinTrackingEnabled = false
                    }
                }
            ))
            if setupCustomSportConfig.isPeriodEnabled {
                settingsDivider()
                settingsStepperValueRow(
                    title: "Starting Period",
                    value: "\(setupPeriod)",
                    decrement: { setupPeriod = max(1, setupPeriod - 1) },
                    increment: { setupPeriod = min(9, setupPeriod + 1) }
                )
                settingsDivider()
                settingsTextEntryRow(title: "Period Label", text: Binding(
                    get: { setupCustomSportConfig.periodTitle },
                    set: { setupCustomSportConfig.periodTitle = $0 }
                ))
                settingsDivider()
                settingsTextEntryRow(title: "Short Label", text: Binding(
                    get: { setupCustomSportConfig.periodShortTitle },
                    set: { setupCustomSportConfig.periodShortTitle = $0 }
                ))
                if setupCustomSportConfig.isScoreEnabled {
                    settingsDivider()
                    settingsToggleRow(title: "Track Period Wins", isOn: Binding(
                        get: { setupCustomSportConfig.isPeriodWinTrackingEnabled },
                        set: { setupCustomSportConfig.isPeriodWinTrackingEnabled = $0 }
                    ))
                }
            }
        }

        settingsSection(title: "Secondary Timer", footer: "Enable a separate shot or serve timer and configure how it resets.") {
            settingsOptionTip("Use Secondary Timer when the sport needs a possession-style timer beside the main game clock. Shot Clock gives operators preset reset buttons; Serve Timer gives each side a Serve Here action that resets and starts the timer.", systemImage: "timer.circle")
            settingsToggleRow(title: "Secondary Timer", isOn: Binding(
                get: { setupCustomSportConfig.isShotClockEnabled },
                set: {
                    setupCustomSportConfig.isShotClockEnabled = $0
                    if !$0 {
                        setupCustomSportConfig.shotClockMode = .shot
                        setupCustomSportConfig.isPossessionEnabled = false
                    }
                }
            ))
            if setupCustomSportConfig.isShotClockEnabled {
                settingsDivider()
                settingsPickerRow(
                    title: "Timer Type",
                    selection: Binding(
                        get: { setupCustomSportConfig.shotClockMode },
                        set: { setupCustomSportConfig.shotClockMode = $0 }
                    ),
                    options: CustomShotClockMode.allCases
                ) { $0.title }
                settingsDivider()
                settingsStepperValueRow(
                    title: setupCustomSportConfig.shotClockMode == .serve ? "Serve Default" : "Shot Default",
                    value: ScoreboardStore.formatShotClock(setupShotClockSeconds),
                    decrement: { setupShotClockSeconds = max(0, setupShotClockSeconds - 1) },
                    increment: { setupShotClockSeconds = min(ScoreboardStore.maxShotClockSeconds, setupShotClockSeconds + 1) }
                )
                settingsDivider()
                if setupCustomSportConfig.shotClockMode == .serve {
                    settingsSegmentRow(
                        title: "Serve Preset",
                        options: [
                            ("8", 8)
                        ],
                        selection: $setupShotClockSeconds
                    )
                } else {
                    settingsSegmentRow(
                        title: "Shot Preset",
                        options: [
                            ("24", 24),
                            ("14", 14)
                        ],
                        selection: $setupShotClockSeconds
                    )
                }
            }
        }

        settingsSection(title: "Possession", footer: setupCustomSportConfig.isShotClockEnabled ? "Show the center possession arrow alongside the secondary timer." : "Enable Secondary Timer first to use the possession arrow.") {
            settingsOptionTip("Use Possession to show which side currently controls play. It is available for custom sports that use the Shot Clock timer type; Serve Timer uses serving side instead.", systemImage: "arrow.left.and.right")
            settingsToggleRow(title: "Possession Arrow", isOn: Binding(
                get: { setupCustomSportConfig.isPossessionEnabled },
                set: { setupCustomSportConfig.isPossessionEnabled = $0 }
            ))
            .disabled(!setupCustomSportConfig.isShotClockEnabled || setupCustomSportConfig.shotClockMode == .serve)
            .opacity(setupCustomSportConfig.isShotClockEnabled && setupCustomSportConfig.shotClockMode != .serve ? 1 : 0.42)
        }

        settingsSection(title: "Player", footer: "Enable player tracking, lineup style, and player-specific state.") {
            settingsOptionTip("Use Player settings when the custom sport needs rosters, active lineups, player fouls, cards, or a soccer-style center player strip. Turning tracking on also enables the Players settings page.", systemImage: "person.3")
            settingsToggleRow(title: "Player Tracking", isOn: Binding(
                get: { setupCustomSportConfig.isPlayerTrackingEnabled },
                set: { setupCustomSportConfig.isPlayerTrackingEnabled = $0 }
            ))
            if setupCustomSportConfig.isPlayerTrackingEnabled {
                settingsDivider()
                settingsToggleRow(title: "Soccer Style Player Display", isOn: Binding(
                    get: { setupCustomSportConfig.usesCenterPlayerStrip },
                    set: { setupCustomSportConfig.usesCenterPlayerStrip = $0 }
                ))
                settingsDivider()
                settingsToggleRow(title: "Player Fouls", isOn: Binding(
                    get: { setupCustomSportConfig.isPlayerFoulsEnabled },
                    set: { setupCustomSportConfig.isPlayerFoulsEnabled = $0 }
                ))
                settingsDivider()
                settingsToggleRow(title: "Player Cards", isOn: Binding(
                    get: { setupCustomSportConfig.isPlayerCardsEnabled },
                    set: { setupCustomSportConfig.isPlayerCardsEnabled = $0 }
                ))
            }
        }

        settingsSection(title: "Team", footer: "Turn on team-level tracking controls for the live board and display.") {
            settingsOptionTip("Use Team settings for counters and timers that belong to a side rather than an individual player. Substitutions, pauses, team fouls, and penalty timers add live controls, public display state, and log entries for both sides.", systemImage: "person.2")
            settingsToggleRow(title: "Substitutions", isOn: Binding(
                get: { setupCustomSportConfig.isSubstitutionTrackingEnabled },
                set: { setupCustomSportConfig.isSubstitutionTrackingEnabled = $0 }
            ))
            settingsDivider()
            settingsToggleRow(title: "Pauses", isOn: Binding(
                get: { setupCustomSportConfig.isPauseTrackingEnabled },
                set: { isEnabled in
                    setupCustomSportConfig.isPauseTrackingEnabled = isEnabled
                    if isEnabled, store.homePausesAllowed == 0, store.guestPausesAllowed == 0 {
                        store.setPausesAllowed(for: .home, to: setupCustomSportConfig.defaultPauseLimit)
                        store.setPausesAllowed(for: .guest, to: setupCustomSportConfig.defaultPauseLimit)
                    }
                }
            ))
            settingsDivider()
            settingsToggleRow(title: "Team Fouls", isOn: Binding(
                get: { setupCustomSportConfig.isTeamFoulsEnabled },
                set: { setupCustomSportConfig.isTeamFoulsEnabled = $0 }
            ))
            settingsDivider()
            settingsToggleRow(title: "Penalty Timers", isOn: Binding(
                get: { setupCustomSportConfig.isPenaltyTimerEnabled },
                set: { setupCustomSportConfig.isPenaltyTimerEnabled = $0 }
            ))
        }
    }

    @ViewBuilder
    private func debateSettingsSections(layout: InterfaceLayout) -> some View {
        settingsSection(title: "General", footer: "Choose the debate format, round title, side labels, and whether score is tracked.") {
            settingsOptionTip("Use General to choose the debate format, label each side, and decide whether the round has score tracking. Presets fill in standard flows, while Custom Debate lets you design a format for this event.", systemImage: "quote.bubble")
            settingsPickerRow(
                title: "Preset",
                selection: $setupDebatePresetID,
                options: DebatePreset.selectablePresetIDs
            ) { presetID in
                presetID == DebatePreset.customID ? "Custom Debate" : DebatePreset.preset(id: presetID).title
            }
            if setupDebatePresetID == DebatePreset.customID {
                settingsDivider()
                debateDesignerLauncherRow(layout: layout)
                settingsDivider()
                settingsTextEntryRow(
                    title: "Format Title",
                    text: Binding(
                        get: { setupCustomDebatePreset.title },
                        set: { setupCustomDebatePreset.title = $0 }
                    )
                )
            }
            settingsDivider()
            settingsTextEntryRow(title: "First Side", text: $setupDebateHomeSideLabel)
            settingsDivider()
            settingsTextEntryRow(title: "Second Side", text: $setupDebateGuestSideLabel)
            settingsDivider()
            settingsToggleRow(title: "Enable Score Tracking", isOn: $setupDebateScoreTrackingEnabled)
        }

        settingsSection(title: "Segments", footer: setupDebatePresetID == DebatePreset.customID ? "Preview the full custom debate flow. Use Open Designer under Preset to edit these blocks." : "Preview the full debate timer flow for the selected preset.") {
            settingsOptionTip("Use Segments to confirm the speaking order, timing mode, active side, and duration before the round starts. This preview is the sequence operators will advance through on the live debate board.", systemImage: "list.number")
            debateSegmentPreviewModeTips(preset: setupDebatePreset)
            debateSegmentPreviewList(preset: setupDebatePreset)
        }

        settingsSection(title: "Player", footer: "Enable player tracking and choose whether debate players carry fouls or cards.") {
            settingsOptionTip("Use Player settings for debate when speakers need roster entries, active lineup visibility, fouls, or cards. These options control whether the Players page and player overlay tools appear for debate rounds.", systemImage: "person.3")
            settingsToggleRow(title: "Enable Player Tracking", isOn: $setupDebatePlayerTrackingEnabled)
            if setupDebatePlayerTrackingEnabled {
                settingsDivider()
                settingsToggleRow(title: "Player Fouls", isOn: $setupDebatePlayerFoulsEnabled)
                settingsDivider()
                settingsToggleRow(title: "Player Cards", isOn: $setupDebatePlayerCardsEnabled)
            }
        }

        settingsSection(title: "Prep", footer: setupDebatePrepTimeEnabled ? "Prep time is tracked per side and shown on the live board and display." : "Turn prep time on to expose per-side prep clocks.") {
            settingsOptionTip("Use Prep to give each side its own preparation clock. Prep time appears beside the segment timer on the live board so operators can pause the speech flow and run side-specific prep.", systemImage: "hourglass")
            settingsToggleRow(title: "Enable Prep Time", isOn: $setupDebatePrepTimeEnabled)
            if setupDebatePrepTimeEnabled {
                settingsDivider()
                if setupDebatePresetID == DebatePreset.customID {
                    settingsStepperValueRow(
                        title: "Prep Time",
                        value: formatClock(setupCustomDebatePreset.prepSecondsPerSide),
                        decrement: {
                            setupCustomDebatePreset.prepSecondsPerSide = max(0, setupCustomDebatePreset.prepSecondsPerSide - 15)
                        },
                        increment: {
                            setupCustomDebatePreset.prepSecondsPerSide = min(ScoreboardStore.maxGameClockSeconds, setupCustomDebatePreset.prepSecondsPerSide + 15)
                        }
                    )
                } else {
                    settingsSummaryValueRow(title: "Prep Time", value: formatClock(setupDebatePreset.prepSecondsPerSide))
                }
            }
        }
    }

    private func debateDesignerLauncherRow(layout: InterfaceLayout) -> some View {
        let requiresLandscape = debateDesignerRequiresLandscape(layout: layout)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "square.grid.2x2")
                    .font(.title3.weight(.black))
                    .foregroundStyle(settingsPalette.accent)
                    .frame(width: 42, height: 42)
                    .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    localizedAppText("Debate Designer")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)

                    Text(localizedAppFormat("%lld blocks · %@ speech time", setupCustomDebatePreset.segments.count, formatClock(debateTotalDurationSeconds(setupCustomDebatePreset))))
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                settingsCompactIconButton(
                    "Open Designer",
                    systemImage: "arrow.right",
                    tint: settingsPalette.accent,
                    foreground: settingsPalette.accentText,
                    isEnabled: !requiresLandscape
                ) {
                    openDebateDesigner()
                }
            }

            if requiresLandscape {
                Text("Rotate iPhone to landscape to use Debate Designer.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(settingsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }

    private func debateDesignerRequiresLandscape(layout: InterfaceLayout) -> Bool {
        isIPhoneInterface && layout.size.height >= layout.size.width
    }

    private func debateSegmentPreviewList(preset: DebatePreset) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(preset.segments.enumerated()), id: \.offset) { index, segment in
                debateSegmentPreviewRow(segment: segment, index: index)
                if index < preset.segments.count - 1 {
                    settingsDivider()
                }
            }
        }
    }

    @ViewBuilder
    private func debateSegmentPreviewModeTips(preset: DebatePreset) -> some View {
        if preset.segments.contains(where: { $0.timerMode == .none }) {
            settingsOptionTip("This debate format includes No Timer segments. Those blocks appear in the live round sequence as checkpoints or transitions, but they do not run a speech clock.", systemImage: "pause.circle")
        }

        if preset.segments.contains(where: { $0.timerMode == .dualClock }) {
            settingsOptionTip("This debate format includes Dual Clock segments. Those blocks run separate side clocks, starting from the configured side and optionally allowing operators to switch active sides during the segment.", systemImage: "person.2")
        }
    }

    private func debateSegmentPreviewRow(segment: DebateSegment, index: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(localizedAppFormat("%lld. %@", index + 1, localizedAppString(segment.title)))
                .font(.body.weight(.semibold))
                .foregroundStyle(settingsPalette.primaryText)
                .lineLimit(2)

            Spacer(minLength: 8)

            Text(debateSegmentPreviewDetail(segment))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(settingsPalette.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
    }

    private func debateSegmentPreviewDetail(_ segment: DebateSegment) -> String {
        let timerTitle = debateTimerModeTitle(segment.timerMode)
        let speakerTitle = segment.speakingSide.map(debateSpeakingSideTitle)
        guard segment.timerMode != .none else {
            return [timerTitle, speakerTitle].compactMap { $0 }.joined(separator: " · ")
        }

        return [timerTitle, formatClock(segment.durationSeconds), speakerTitle].compactMap { $0 }.joined(separator: " · ")
    }

    private func debateDesignerPage(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            debateDesignerHeader()
            debateDesignerTemplatesSection(layout: layout)
            debateDesignerFormatSection()
            debateDesignerSegmentsSection()
        }
    }

    private func debateDesignerLandscapeRequiredPage(layout _: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            debateDesignerHeader()

            settingsSection(title: "Landscape Required", footer: "Debate Designer remains available on iPhone after rotating to landscape.") {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "iphone.landscape")
                        .font(.title2.weight(.black))
                        .foregroundStyle(settingsPalette.accent)
                        .frame(width: 44, height: 44)
                        .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        localizedAppText("Rotate iPhone")
                            .font(.body.weight(.bold))
                            .foregroundStyle(settingsPalette.primaryText)

                        localizedAppText("Debate Designer needs the wider landscape layout for segment editing, timers, side controls, and action buttons.")
                            .font(.subheadline)
                            .foregroundStyle(settingsPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func debateDesignerHeader() -> some View {
        HStack(alignment: .center, spacing: 12) {
            settingsCompactIconButton("Back", systemImage: "chevron.left", tint: settingsPalette.fieldBackground, foreground: settingsPalette.primaryText) {
                isDebateDesignerVisible = false
            }

            VStack(alignment: .leading, spacing: 4) {
                localizedAppText("Debate Designer")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(settingsPalette.primaryText)

                Text(localizedAppFormat("%lld blocks · %@ speech time", setupCustomDebatePreset.segments.count, formatClock(debateTotalDurationSeconds(setupCustomDebatePreset))))
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    private func debateDesignerTemplatesSection(layout: InterfaceLayout) -> some View {
        settingsSection(title: "Templates", footer: "Start from Public Forum, Lincoln-Douglas, or Policy. Applying a template creates an editable Custom Debate flow.") {
            settingsOptionTip("Use Templates as starting points for a custom debate format. Applying a template replaces the current custom block list with an editable copy, so choose the closest flow before fine-tuning labels and timings.", systemImage: "doc.on.doc")
            debateDesignerTemplateGrid(layout: layout)
        }
    }

    private func debateDesignerFormatSection() -> some View {
        settingsSection(title: "Format", footer: "These labels and tracking options are saved with the custom debate format.") {
            settingsOptionTip("Use Format to name the custom debate, label the two sides, and decide which live-board tools are available. These choices define the behavior of the custom preset before individual segment blocks run.", systemImage: "text.badge.checkmark")
            debateDesignerFormatRows()
        }
    }

    @ViewBuilder
    private func debateDesignerFormatRows() -> some View {
        settingsTextEntryRow(
            title: "Format Title",
            text: Binding(
                get: { setupCustomDebatePreset.title },
                set: { setupCustomDebatePreset.title = $0 }
            )
        )
        settingsDivider()
        settingsTextEntryRow(title: "First Side", text: $setupDebateHomeSideLabel)
        settingsDivider()
        settingsTextEntryRow(title: "Second Side", text: $setupDebateGuestSideLabel)
        settingsDivider()
        settingsToggleRow(title: "Enable Score Tracking", isOn: $setupDebateScoreTrackingEnabled)
        settingsDivider()
        settingsToggleRow(title: "Enable Player Tracking", isOn: $setupDebatePlayerTrackingEnabled)
        if setupDebatePlayerTrackingEnabled {
            settingsDivider()
            settingsToggleRow(title: "Player Fouls", isOn: $setupDebatePlayerFoulsEnabled)
            settingsDivider()
            settingsToggleRow(title: "Player Cards", isOn: $setupDebatePlayerCardsEnabled)
        }
        settingsDivider()
        settingsToggleRow(title: "Enable Prep Time", isOn: $setupDebatePrepTimeEnabled)
        if setupDebatePrepTimeEnabled {
            settingsDivider()
            settingsStepperValueRow(
                title: "Prep Time",
                value: formatClock(setupCustomDebatePreset.prepSecondsPerSide),
                decrement: {
                    setupCustomDebatePreset.prepSecondsPerSide = max(0, setupCustomDebatePreset.prepSecondsPerSide - 15)
                },
                increment: {
                    setupCustomDebatePreset.prepSecondsPerSide = min(ScoreboardStore.maxGameClockSeconds, setupCustomDebatePreset.prepSecondsPerSide + 15)
                }
            )
        }
    }

    private func debateDesignerSegmentsSection() -> some View {
        settingsSection(title: "Segment Blocks", footer: "Each block becomes one step in the live debate timer. Add speeches, crossfires, prep breaks, or side-clock segments in the order they should run.") {
            settingsOptionTip("Use Segment Blocks to build the exact round flow operators will follow. Each block can have no timer, a shared master clock, or a dual side clock, and the order here becomes the live segment order.", systemImage: "square.grid.2x2")
            debateDesignerSegmentBlocks()
        }
    }

    private func debateDesignerSegmentBlocks() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    localizedAppText("Round Flow")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(settingsPalette.primaryText)

                    Text(localizedAppFormat("%lld blocks", setupCustomDebatePreset.segments.count))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(settingsPalette.secondaryText)
                }

                Spacer(minLength: 0)

                settingsCompactIconButton("Add Segment", systemImage: "plus", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                    addCustomDebateSegment()
                }
            }

            ForEach(Array(setupCustomDebatePreset.segments.indices), id: \.self) { index in
                customDebateSegmentEditor(segment: setupCustomDebatePreset.segments[index], index: index)
            }
        }
        .padding(.vertical, 10)
    }

    private var debateDesignerTemplates: [DebatePreset] {
        [simpleDemoDebateTemplate] + DebatePreset.builtInPresets
    }

    private var simpleDemoDebateTemplate: DebatePreset {
        DebatePreset(
            id: "simple-demo",
            title: "Simple Demo",
            homeSideLabel: "Aff",
            guestSideLabel: "Neg",
            segments: [
                DebateSegment(
                    id: "demo-no-timer",
                    title: "No Timer Block",
                    timerMode: .none,
                    durationSeconds: 0,
                    startingSide: nil,
                    allowsSideSwitching: false,
                    autoPauseAtEnd: true,
                    startsPaused: true
                ),
                DebateSegment(
                    id: "demo-aff-speech",
                    title: "Aff Speech",
                    timerMode: .masterClock,
                    durationSeconds: 60,
                    startingSide: nil,
                    allowsSideSwitching: false,
                    autoPauseAtEnd: true,
                    startsPaused: true
                ),
                DebateSegment(
                    id: "demo-neg-speech",
                    title: "Neg Speech",
                    timerMode: .masterClock,
                    durationSeconds: 60,
                    startingSide: nil,
                    allowsSideSwitching: false,
                    autoPauseAtEnd: true,
                    startsPaused: false
                ),
                DebateSegment(
                    id: "demo-aff-led-dual",
                    title: "Aff-Led Side Clock",
                    timerMode: .dualClock,
                    durationSeconds: 90,
                    startingSide: .home,
                    allowsSideSwitching: true,
                    autoPauseAtEnd: true,
                    startsPaused: true
                ),
                DebateSegment(
                    id: "demo-neg-led-dual",
                    title: "Neg-Led Side Clock",
                    timerMode: .dualClock,
                    durationSeconds: 90,
                    startingSide: .guest,
                    allowsSideSwitching: true,
                    autoPauseAtEnd: false,
                    startsPaused: true
                ),
                DebateSegment(
                    id: "demo-final",
                    title: "Final Speech",
                    timerMode: .masterClock,
                    durationSeconds: 45,
                    startingSide: nil,
                    allowsSideSwitching: false,
                    autoPauseAtEnd: true,
                    startsPaused: true
                )
            ],
            prepSecondsPerSide: 30,
            isPrepTimeEnabled: true,
            defaultScoreTrackingEnabled: true,
            defaultPlayerTrackingEnabled: true,
            defaultPlayerFoulsEnabled: true,
            defaultPlayerCardsEnabled: true
        )
    }

    private func debateDesignerTemplateGrid(layout: InterfaceLayout) -> some View {
        let columnCount = layout.size.width < 880 ? 1 : layout.size.width < 1240 ? 2 : 3
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(debateDesignerTemplates) { template in
                debateDesignerTemplateButton(template)
            }
        }
        .padding(.vertical, 10)
    }

    private func debateDesignerTemplateButton(_ template: DebatePreset) -> some View {
        Button {
            applyDebateDesignerTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "doc.on.doc")
                        .font(.headline.weight(.black))
                        .foregroundStyle(settingsPalette.accent)
                        .frame(width: 34, height: 34)
                        .background(settingsPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        localizedAppText(template.title)
                            .font(.headline.weight(.black))
                            .foregroundStyle(settingsPalette.primaryText)
                            .lineLimit(2)

                        Text(localizedAppFormat("%lld blocks · %@", template.segments.count, formatClock(debateTotalDurationSeconds(template))))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(settingsPalette.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    debateTemplatePill(template.homeSideLabel)
                    debateTemplatePill(template.guestSideLabel)
                    debateTemplatePill(template.isPrepTimeEnabled ? localizedAppFormat("%@ prep", formatClock(template.prepSecondsPerSide)) : "No prep")
                }

                Text(debateTemplateFeatureLine(template))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(settingsPalette.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(template.segments.prefix(4).map { localizedAppString($0.title) }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
            .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(settingsPalette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scoreboardPopoverTip(ScoreboardTips.about, isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func debateTemplatePill(_ title: String) -> some View {
        Text(localizedAppString(title))
            .font(.caption.weight(.bold))
            .foregroundStyle(settingsPalette.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(settingsPalette.cardBackground, in: Capsule())
    }

    private func debateTemplateFeatureLine(_ template: DebatePreset) -> String {
        var features: [String] = []
        let timerModes = Set(template.segments.map(\.timerMode))

        if timerModes.contains(.masterClock) {
            features.append(localizedAppString("Master"))
        }
        if timerModes.contains(.dualClock) {
            features.append(localizedAppString("Dual side"))
        }
        if timerModes.contains(.none) {
            features.append(localizedAppString("No timer"))
        }
        if template.defaultScoreTrackingEnabled {
            features.append(localizedAppString("Score"))
        }
        if template.defaultPlayerTrackingEnabled {
            features.append(localizedAppString("Players"))
        }
        if template.defaultPlayerFoulsEnabled {
            features.append(localizedAppString("Fouls"))
        }
        if template.defaultPlayerCardsEnabled {
            features.append(localizedAppString("Cards"))
        }
        if template.segments.contains(where: { $0.allowsSideSwitching }) {
            features.append(localizedAppString("Side switch"))
        }

        return features.joined(separator: " · ")
    }

    private func sportSelectionGrid(layout: InterfaceLayout) -> some View {
        sportSelectionGrid(layout: layout, selection: $setupSport)
    }

    private func sportSelectionGrid(layout: InterfaceLayout, selection: Binding<SportType>) -> some View {
        let columnCount = layout.size.width < 760 ? 2 : layout.size.width < 1120 ? 3 : 4
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SportType.allCases) { sport in
                sportSelectionButton(sport, selection: selection)
            }
        }
    }

    private func sportSelectionButton(_ sport: SportType, selection: Binding<SportType>) -> some View {
        let isSelected = selection.wrappedValue == sport
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                selection.wrappedValue = sport
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: sportSelectionSystemImage(for: sport))
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(isSelected ? settingsPalette.accentText : settingsPalette.accent)
                        .frame(width: 34, height: 34)
                        .background(
                            (isSelected ? settingsPalette.accent.opacity(0.18) : settingsPalette.fieldBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(settingsPalette.accentText)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                localizedAppText(sport.title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(isSelected ? settingsPalette.accentText : settingsPalette.primaryText)
                    .singleLineFitted(minScale: 0.72)

                localizedAppText(sportSelectionSubtitle(for: sport))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? settingsPalette.accentText.opacity(0.82) : settingsPalette.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(
                isSelected ? settingsPalette.accent : settingsPalette.fieldBackground,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? settingsPalette.accentText.opacity(0.32) : settingsPalette.cardBorder, lineWidth: isSelected ? 1.4 : 1)
            )
            .shadow(color: isSelected ? settingsPalette.accent.opacity(0.22) : .clear, radius: 14, y: 8)
            .scaleEffect(isSelected ? 1.015 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func compactSportSelectionGrid(layout: InterfaceLayout, selection: Binding<SportType>) -> some View {
        let columnCount = layout.size.width < 560 ? 2 : layout.size.width < 980 ? 3 : 4
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SportType.allCases) { sport in
                compactSportSelectionButton(sport, selection: selection)
            }
        }
        .padding(.vertical, 10)
    }

    private func compactSportSelectionButton(_ sport: SportType, selection: Binding<SportType>) -> some View {
        let isSelected = selection.wrappedValue == sport

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selection.wrappedValue = sport
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: sportSelectionSystemImage(for: sport))
                        .font(.headline.weight(.semibold))
                        .frame(width: 22)

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.black))
                            .transition(.opacity)
                    }
                }

                localizedAppText(sport.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(isSelected ? settingsPalette.accentText : settingsPalette.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
            .background(
                isSelected ? settingsPalette.accent : settingsPalette.fieldBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? settingsPalette.accentText.opacity(0.28) : settingsPalette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sportSelectionSystemImage(for sport: SportType) -> String {
        switch sport {
        case .simple:
            return "timer"
        case .basketball:
            return "basketball.fill"
        case .volleyball:
            return "volleyball.fill"
        case .soccer:
            return "soccerball"
        case .hockey:
            return "figure.hockey"
        case .chess:
            return "checkerboard.rectangle"
        case .debate:
            return "quote.bubble.fill"
        case .custom:
            return "slider.horizontal.3"
        }
    }

    private func sportSelectionSubtitle(for sport: SportType) -> String {
        switch sport {
        case .simple:
            return "Score and countdown"
        case .basketball:
            return "Score, clock, shot clock"
        case .volleyball:
            return "Periods, swaps, cards"
        case .soccer:
            return "Halves and lineup cards"
        case .hockey:
            return "Periods and penalties"
        case .chess:
            return "Two player clocks"
        case .debate:
            return "Segments and prep"
        case .custom:
            return "Build your own rules"
        }
    }

    @ViewBuilder
    private func settingsThemePane() -> some View {
        if isExternalBackgroundImageEditorVisible {
            externalBackgroundImageEditorPage()
        } else {
            VStack(alignment: .leading, spacing: 22) {
                #if os(iOS)
                settingsSection(title: "Live Activity", footer: "Shows a Live Activity and Dynamic Island status while a primary game timer is running.") {
                    settingsToggleRow(title: "Show Activity When Timer Is Running", isOn: Binding(
                        get: { store.showsLiveActivityWhenTimerRunning },
                        set: { store.showsLiveActivityWhenTimerRunning = $0 }
                    ))
                }
                #endif

                settingsSection(title: "Scoreboard Theme", footer: "Themes update the setup screen, live control board, preview, and external scoreboard together.") {
                    ForEach(Array(ScoreboardTheme.allCases.enumerated()), id: \.element.id) { index, theme in
                        themeSelectionRow(theme)

                        if index < ScoreboardTheme.allCases.count - 1 {
                            settingsDivider()
                        }
                    }
                }

                settingsSection(title: "Display Direction", footer: "Choose the base left/right orientation for each screen. Swap Sides still flips the live layout during the game. To change Remote Display direction, go to Integration > Remote Display.") {
                    settingsOptionTip("Display Direction is the base left/right orientation for the screen you are setting up. A control board, projector, TV, or paired Remote Display may face the court, field, stage, or players from different sides, so Home Left on one screen may need to be Guest Left on another. Swap Sides is still a live-game control: it flips the current matchup on top of each screen's base direction, including Remote Displays that have their own direction set in Integration.", systemImage: "arrow.left.and.right")
                    settingsDivider()

                    settingsPickerRow(
                        title: "Control Board",
                        selection: Binding(
                            get: { store.controlBoardDisplayDirection },
                            set: { store.setControlBoardDisplayDirection($0) }
                        ),
                        options: ScoreboardDisplayDirection.allCases
                    ) { direction in
                        direction.title
                    }

                    settingsDivider()

                    settingsPickerRow(
                        title: "External Display",
                        selection: Binding(
                            get: { store.externalDisplayDirection },
                            set: { store.externalDisplayDirection = $0 }
                        ),
                        options: ScoreboardDisplayDirection.allCases
                    ) { direction in
                        direction.title
                    }
                }

                settingsSection(title: "External Display Background", footer: "Controls only the public/external display. The preview stays unchanged.") {
                    let backgroundModes = ExternalDisplayBackgroundMode.selectableThemeModes
                    ForEach(Array(backgroundModes.enumerated()), id: \.element.id) { index, mode in
                        externalBackgroundModeRow(mode)

                        if index < backgroundModes.count - 1 {
                            settingsDivider()
                        }
                    }
                    settingsDivider()
                    externalBackgroundImageControls()
                    if store.externalDisplayBackgroundMode == .animatedLogo && ExternalDisplayBackgroundMode.isAnimatedLogoBackgroundEnabled {
                        settingsDivider()
                        animatedLogoBackgroundControls()
                    }
                }

                settingsSection(title: "Display Date & Time", footer: "Shows the current device date/time on public and remote displays without resizing the scoreboard.") {
                    settingsToggleRow(title: "Show Date/Time", isOn: Binding(
                        get: { store.showsExternalDisplayDateTime },
                        set: { store.showsExternalDisplayDateTime = $0 }
                    ))
                    settingsDivider()
                    settingsPickerRow(
                        title: "Time Format",
                        selection: Binding(
                            get: { store.externalDisplayDateTimeFormat },
                            set: { store.externalDisplayDateTimeFormat = $0 }
                        ),
                        options: ExternalDisplayDateTimeFormat.allCases
                    ) { option in
                        option.title
                    }
                    .disabled(!store.showsExternalDisplayDateTime)
                    .opacity(store.showsExternalDisplayDateTime ? 1 : 0.42)
                    settingsDivider()
                    settingsToggleRow(title: "Show Seconds", isOn: Binding(
                        get: { store.showsExternalDisplayDateTimeSeconds },
                        set: { store.showsExternalDisplayDateTimeSeconds = $0 }
                    ))
                    .disabled(!store.showsExternalDisplayDateTime)
                    .opacity(store.showsExternalDisplayDateTime ? 1 : 0.42)
                }
            }
        }
    }

    private func settingsPlayersPane(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Tracking") {
                settingsToggleRow(title: "Enable Player/Foul Tracking", isOn: Binding(
                    get: { store.isPlayerTrackingEnabled },
                    set: { store.setPlayerTrackingEnabled($0) }
                ))
                if store.isDebateMode && store.isDebatePlayerTrackingEnabled {
                    settingsDivider()
                    settingsToggleRow(title: "Player Fouls", isOn: Binding(
                        get: { store.isDebatePlayerFoulsEnabled },
                        set: { store.setDebatePlayerFoulsEnabled($0) }
                    ))
                    settingsDivider()
                    settingsToggleRow(title: "Player Cards", isOn: Binding(
                        get: { store.isDebatePlayerCardsEnabled },
                        set: { store.setDebatePlayerCardsEnabled($0) }
                    ))
                }
                settingsDivider()
                settingsToggleRow(title: "Pause Public Player Overlay", isOn: Binding(
                    get: { store.isPlayerOverlayPaused },
                    set: { if store.isPlayerOverlayPaused != $0 { store.togglePlayerOverlayPaused() } }
                ))
                settingsDivider()
                settingsStepperValueRow(
                    title: "Roster Size",
                    value: "\(store.rosterSizePerTeam)",
                    decrement: { store.setRosterSizePerTeam(store.rosterSizePerTeam - 1) },
                    increment: { store.setRosterSizePerTeam(store.rosterSizePerTeam + 1) }
                )
            }

            if store.supportsPlayerTracking {
                settingsRosterCSVSection()
                settingsRosterSections(layout: layout)
            } else {
                settingsSection(title: "Tracking Unavailable", footer: "The current sport uses score, clock, and substitution controls only.") {
                    settingsSummaryValueRow(title: "Sport", value: localizedAppString(store.selectedSport.title))
                }
            }
        }
    }

    private func settingsRosterCSVSection() -> some View {
        settingsSection(title: "Roster CSV", footer: "Import or export both team rosters in one comma-separated file.") {
            HStack(spacing: 16) {
                localizedAppText("Roster File")
                    .foregroundStyle(settingsPalette.primaryText)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    #if os(macOS)
                    Menu {
                        Button {
                            exportRosterCSV(destination: .file)
                        } label: {
                            Label("Save to File", systemImage: "folder")
                        }

                        Button {
                            exportRosterCSV(destination: .share)
                        } label: {
                            Label("System Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(settingsPalette.accentText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(settingsPalette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    #else
                    settingsIconButton("Export", systemImage: "square.and.arrow.up", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                        exportRosterCSV(destination: .share)
                    }
                    #endif

                    settingsIconButton("Import", systemImage: "square.and.arrow.down", tint: settingsPalette.fieldBackground, foreground: settingsPalette.primaryText) {
                        beginRosterCSVImport()
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func settingsRosterSections(layout: InterfaceLayout) -> some View {
        settingsTwoColumnLayout(layout: layout, usesBalancedColumns: true) {
            settingsRosterSection(side: .home, layout: layout, footer: "Edit player number, display name, and active lineup status for the first side.")
        } right: {
            settingsRosterSection(side: .guest, layout: layout, footer: "Edit player number, display name, and active lineup status for the second side.")
        }
    }

    private func settingsRosterSection(side: TeamSide, layout: InterfaceLayout, footer: String) -> some View {
        settingsSection(title: localizedAppFormat("%@ Roster", store.sideRoleLabel(for: side)), footer: footer) {
            settingsRosterEditor(side: side, layout: layout)
        }
    }

    private func settingsDisplayPane() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Lineup") {
                settingsStepperValueRow(
                    title: "Player Lineup Size",
                    value: "\(store.displayLineupSize)",
                    decrement: { store.setDisplayLineupSize(store.displayLineupSize - 1) },
                    increment: { store.setDisplayLineupSize(store.displayLineupSize + 1) }
                )
                settingsDivider()
                settingsPickerRow(
                    title: "Overflow Behavior",
                    selection: Binding(
                        get: { store.playerLineupOverflowMode },
                        set: { store.playerLineupOverflowMode = $0 }
                    ),
                    options: PlayerLineupOverflowMode.allCases
                ) { option in
                    option.title
                }
                settingsDivider()
                settingsPickerRow(
                    title: "When Logos Shown",
                    selection: Binding(
                        get: { store.playerLineupOverflowLogoOverride },
                        set: { store.playerLineupOverflowLogoOverride = $0 }
                    ),
                    options: playerOverflowOverrideOptions
                ) { option in
                    playerOverflowOverrideTitle(option)
                }
                settingsDivider()
                settingsPickerRow(
                    title: "When Logos Hidden",
                    selection: Binding(
                        get: { store.playerLineupOverflowNoLogoOverride },
                        set: { store.playerLineupOverflowNoLogoOverride = $0 }
                    ),
                    options: playerOverflowOverrideOptions
                ) { option in
                    playerOverflowOverrideTitle(option)
                }
                settingsDivider()
                settingsStepperValueRow(
                    title: "Fade Page Time",
                    value: "\(store.playerLineupFadePageSeconds)s",
                    decrement: { store.setPlayerLineupFadePageSeconds(store.playerLineupFadePageSeconds - 1) },
                    increment: { store.setPlayerLineupFadePageSeconds(store.playerLineupFadePageSeconds + 1) }
                )
                settingsDivider()
                settingsStepperValueRow(
                    title: "Scroll Speed",
                    value: "\(store.playerLineupScrollSpeed) px/s",
                    decrement: { store.setPlayerLineupScrollSpeed(store.playerLineupScrollSpeed - 2) },
                    increment: { store.setPlayerLineupScrollSpeed(store.playerLineupScrollSpeed + 2) }
                )
                settingsDivider()
                settingsPickerRow(
                    title: "Scroll Mode",
                    selection: Binding(
                        get: { store.playerLineupScrollDirection },
                        set: { store.playerLineupScrollDirection = $0 }
                    ),
                    options: PlayerLineupScrollDirection.allCases
                ) { option in
                    option.title
                }
            }

            settingsTeamLogoSection()
            settingsEventLogoSection()

            if store.supportsFouls {
                settingsSection(title: "Foul Highlight") {
                    settingsPickerRow(
                        title: "Foul Highlight Color",
                        selection: Binding(
                            get: { store.playerFoulHighlightColor },
                            set: { store.playerFoulHighlightColor = $0 }
                        ),
                        options: PlayerFoulHighlightColor.allCases
                    ) { option in
                        option.title
                    }
                }
            }

            settingsSection(title: "Clock Alerts", footer: "These affect the public scoreboard display only.") {
                settingsToggleRow(title: "Turn Game Clock Red", isOn: Binding(
                    get: { store.isGameClockRedEnabled },
                    set: { store.isGameClockRedEnabled = $0 }
                ))
                settingsDivider()
                settingsStepperValueRow(
                    title: "Game Clock Red At",
                    value: "\(store.gameClockRedThresholdSeconds)s",
                    decrement: { store.gameClockRedThresholdSeconds = max(0, store.gameClockRedThresholdSeconds - 5) },
                    increment: { store.gameClockRedThresholdSeconds = min(ScoreboardStore.maxGameClockSeconds, store.gameClockRedThresholdSeconds + 5) }
                )

                if store.supportsShotClock {
                    let timerTitle = store.selectedSport == .volleyball ? "Serve Timer" : "Shot Clock"
                    settingsDivider()
                    settingsToggleRow(title: "Turn \(timerTitle) Red", isOn: Binding(
                        get: { store.isShotClockRedEnabled },
                        set: { store.isShotClockRedEnabled = $0 }
                    ))
                    settingsDivider()
                    settingsStepperValueRow(
                        title: "\(timerTitle) Red At",
                        value: "\(store.shotClockRedThresholdSeconds)s",
                        decrement: { store.shotClockRedThresholdSeconds = max(0, store.shotClockRedThresholdSeconds - 1) },
                        increment: { store.shotClockRedThresholdSeconds = min(ScoreboardStore.maxShotClockSeconds, store.shotClockRedThresholdSeconds + 1) }
                    )
                }
            }
        }
    }

    private var playerOverflowOverrideOptions: [PlayerLineupOverflowMode?] {
        [nil] + PlayerLineupOverflowMode.allCases.map { Optional($0) }
    }

    private func playerOverflowOverrideTitle(_ mode: PlayerLineupOverflowMode?) -> String {
        mode?.title ?? localizedAppString("Use Overflow Behavior")
    }

    private func settingsTeamLogoSection() -> some View {
        settingsSection(title: "Team Logos", footer: "Controls logos on public, external, and remote displays. Hiding logos keeps the selected images.") {
            settingsToggleRow(title: "Show Team Logos", isOn: Binding(
                get: { store.showsTeamLogos },
                set: { store.showsTeamLogos = $0 }
            ))
            settingsDivider()
            teamLogoSettingsRow(for: .home)
            settingsDivider()
            teamLogoSettingsRow(for: .guest)
        }
    }

    private func settingsEventLogoSection() -> some View {
        settingsSection(title: "Event Logo", footer: "Shown in the scoreboard center box and Event Logo display mode on public, external, and remote displays.") {
            settingsToggleRow(title: "Show Event Logo", isOn: Binding(
                get: { store.showsEventLogo },
                set: { store.showsEventLogo = $0 }
            ))
            settingsDivider()
            eventLogoSettingsRow()
        }
    }

    private func settingsSoundPane(layout: InterfaceLayout) -> some View {
        let events = store.assignableSoundEvents(for: selectedSoundSettingsSport)

        return settingsTwoColumnLayout(layout: layout) {
            VStack(alignment: .leading, spacing: 22) {
                settingsSoundGlobalSection()
                settingsSoundSportSection(layout: layout)
                settingsSoundLibrarySection()
                settingsSoundResetSection()
            }
        } right: {
            settingsSoundEventsSection(events)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            store.prepareTestSoundEffects()
        }
    }

    private func settingsSoundGlobalSection() -> some View {
        settingsSection(title: "Global Sound", footer: "Sound is global app state and is not saved in game files.") {
            settingsToggleRow(title: "Sound", isOn: Binding(
                get: { store.isSoundEnabled },
                set: { store.setSoundEnabled($0) }
            ))
            settingsDivider()
            settingsSummaryValueRow(title: "Live Board", value: localizedAppString(store.isSoundEnabled ? "Sound On" : "Sound Off"))
        }
    }

    private func settingsSoundSportSection(layout: InterfaceLayout) -> some View {
        settingsSection(title: "Configure Sport", footer: "Choose which sport's sound assignments to edit. The live board keeps using the currently configured game sport.") {
            compactSportSelectionGrid(layout: layout, selection: $selectedSoundSettingsSport)
        }
    }

    private func settingsSoundEventsSection(_ events: [ScoreboardSoundEvent]) -> some View {
        settingsSection(title: "Event Sounds", footer: "Assign one available sound to each supported event for the selected sport.") {
            if events.isEmpty {
                settingsSummaryValueRow(title: selectedSoundSettingsSport.title, value: localizedAppString("No configurable sound events"))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        settingsSoundAssignmentRow(event, sport: selectedSoundSettingsSport)

                        if index < events.count - 1 {
                            settingsDivider()
                        }
                    }
                }
            }
        }
    }

    private func settingsSoundLibrarySection() -> some View {
        settingsSection(title: "Available Sounds", footer: "Preview each sound before assigning it to a timer.") {
            LazyVStack(spacing: 0) {
                ForEach(Array(ScoreboardSoundEffect.allCases.enumerated()), id: \.element.id) { index, effect in
                    settingsSoundLibraryRow(effect)

                    if index < ScoreboardSoundEffect.allCases.count - 1 {
                        settingsDivider()
                    }
                }
            }
        }
    }

    private func settingsSoundResetSection() -> some View {
        settingsSection(title: "Reset", footer: "Restores Sound On and every event assignment to the default sound setup across all sports and modes.") {
            settingsButtonRow(title: "Sound Defaults", buttonTitle: "Reset", tint: themePalette.destructiveTint, foreground: destructiveText) {
                requestGameConfirmation(.resetSoundSettings)
            }
        }
    }

    private func settingsSoundAssignmentRow(_ event: ScoreboardSoundEvent, sport: SportType) -> some View {
        let selectedEffect = store.selectedSoundEffect(for: event, sport: sport)
        let isTesting = store.isTestingSoundEffect(selectedEffect)
        let canTest = store.canTestSoundEffect(selectedEffect)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: event.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(settingsPalette.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    localizedAppText(event.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)

                    localizedAppText(event.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                }

                Spacer(minLength: 0)

                Picker("Sound", selection: Binding(
                    get: { store.selectedSoundEffect(for: event, sport: sport) },
                    set: { store.setSoundEffect($0, for: event, sport: sport) }
                )) {
                    ForEach(ScoreboardSoundEffect.allCases) { effect in
                        localizedAppText(effect.title).tag(effect)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 210)

                Button {
                    store.playTestSound(event, sport: sport)
                } label: {
                    Label(isTesting ? "Stop" : "Test", systemImage: isTesting ? "stop.fill" : "play.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(canTest ? settingsPalette.accentText : settingsPalette.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            canTest ? settingsPalette.accent : settingsPalette.fieldBackground,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canTest)
                .opacity(canTest ? 1 : 0.42)
            }

            localizedAppText(selectedEffect.subtitle)
                .font(.footnote)
                .foregroundStyle(settingsPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }

    private func settingsSoundLibraryRow(_ effect: ScoreboardSoundEffect) -> some View {
        let isTesting = store.isTestingSoundEffect(effect)
        let canTest = store.canTestSoundEffect(effect)

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                localizedAppText(effect.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(settingsPalette.primaryText)

                localizedAppText(effect.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
            }

            Spacer(minLength: 0)

            Button {
                store.playTestEffect(effect)
            } label: {
                Label(isTesting ? "Stop" : "Test", systemImage: isTesting ? "stop.fill" : "play.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(canTest ? settingsPalette.accentText : settingsPalette.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        canTest ? settingsPalette.accent : settingsPalette.fieldBackground,
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canTest)
            .opacity(canTest ? 1 : 0.42)
        }
        .padding(.vertical, 12)
    }

    private func settingsFilesPane(layout: InterfaceLayout, fillsAvailableHeight: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsBackupSection(layout: layout)

            settingsTwoColumnLayout(
                layout: layout,
                primaryColumnWidth: layout.settingsFileManagerPrimaryColumnWidth,
                fillsHeight: fillsAvailableHeight
            ) {
                settingsFileManagerPanel(title: "Game Files", fillsHeight: fillsAvailableHeight) {
                    settingsGameFileManagerToolbar
                } content: {
                    settingsGameFileManagerList(minHeight: layout.settingsFileManagerListMinimumHeight)
                }
            } right: {
                settingsFileManagerPanel(title: "Details", fillsHeight: fillsAvailableHeight) {
                    settingsSelectedGameFileToolbar
                } content: {
                    settingsGameFileDetailPane
                }
            }
        }
    }

    private func settingsBackupSection(layout: InterfaceLayout) -> some View {
        settingsSection(title: "App Backup", footer: "Back up or restore app settings, current game state, stored game files, and log sessions. Remote Display pairings are excluded; pair displays again after restoring on another device.") {
            HStack(spacing: 16) {
                localizedAppText("Full App Backup")
                    .foregroundStyle(settingsPalette.primaryText)

                Spacer(minLength: 0)

                settingsBackupActions(layout: layout)
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func settingsBackupActions(layout: InterfaceLayout) -> some View {
        HStack(spacing: layout.settingsUsesCompactNavigation ? 8 : 10) {
            if layout.settingsUsesCompactNavigation {
                settingsToolbarIconButton("Backup", systemImage: "externaldrive", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                    prepareFullBackup(destination: .share)
                }

                settingsToolbarIconButton("Restore", systemImage: "arrow.clockwise", tint: themePalette.destructiveTint, foreground: destructiveText) {
                    beginBackupRestore()
                }
            } else {
                #if os(macOS)
                Menu {
                    Button {
                        prepareFullBackup(destination: .file)
                    } label: {
                        Label("Save to File", systemImage: "folder")
                    }

                    Button {
                        prepareFullBackup(destination: .share)
                    } label: {
                        Label("System Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("Backup", systemImage: "externaldrive")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(settingsPalette.accentText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(settingsPalette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                #else
                settingsIconButton("Backup", systemImage: "externaldrive", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                    prepareFullBackup(destination: .share)
                }
                #endif

                settingsIconButton("Restore", systemImage: "arrow.clockwise", tint: themePalette.destructiveTint, foreground: destructiveText) {
                    beginBackupRestore()
                }
            }
        }
    }

    private func settingsLogsPane(layout: InterfaceLayout) -> some View {
        let fillsManagerHeight = !layout.settingsTwoColumnUsesVerticalFlow

        return VStack(alignment: .leading, spacing: 18) {
            settingsTwoColumnLayout(
                layout: layout,
                primaryColumnWidth: layout.settingsFileManagerPrimaryColumnWidth,
                fillsHeight: fillsManagerHeight
            ) {
                settingsFileManagerPanel(title: "Sessions", fillsHeight: fillsManagerHeight) {
                    settingsLogSessionManagerToolbar
                } content: {
                    settingsLogSessionManagerList()
                }
            } right: {
                settingsFileManagerPanel(title: "Playback", fillsHeight: fillsManagerHeight) {
                    settingsLogPlaybackToolbar
                } content: {
                    settingsLogPlaybackDetailPane
                }
            }
            .frame(maxHeight: fillsManagerHeight ? .infinity : nil)
        }
    }

    private func settingsIntegrationPane(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsLocalNetworkPermissionSection()
            settingsIntegrationConfigurationSection()

            switch selectedIntegrationDetail {
            case .webAPI:
                settingsWebAPIPane()
            case .remoteDisplay:
                settingsRemoteDisplayPane(layout: layout)
            case .bitfocusCompanion:
                settingsBitfocusCompanionPane(layout: layout)
            }
        }
    }

    #if os(iOS)
    private func settingsIPadLifecycleSection() -> some View {
        settingsSection(title: "iPad App Lifecycle") {
            settingsOptionTip("Keep this limitation in mind when using Web API from iPad during a production session. iPadOS can suspend local network services after app switches, so the most reliable setup keeps Scoreboard open while external tools are connected.", systemImage: "ipad")
            Text("If you close Scoreboard or switch to another app, iPadOS may pause local web connections even if you did not force quit. Keep Scoreboard open during production use. When you return to the app, the Web API restarts automatically if it is still enabled.")
                .font(.body)
                .foregroundStyle(settingsPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
        }
    }
    #endif

    private func settingsWebAPIPane() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            #if os(iOS)
            settingsIPadLifecycleSection()
            #endif

            settingsSection(title: "Web API", footer: "Publishes live scoreboard state over HTTP 5516 and WebSocket 5517 for trusted local production tools.") {
                settingsOptionTip("Use Web API when local overlays, browser sources, custom dashboards, or production scripts need to read live scoreboard state. The API is read-only for game operations and publishes current state over HTTP and WebSocket ports.", systemImage: "network")
                settingsToggleRow(title: "Enable HTTP 5516 and WebSocket 5517", isOn: Binding(
                    get: { store.isWebAPIEnabled },
                    set: { store.setWebAPIEnabled($0) }
                ))
                settingsDivider()
                settingsWebAPIUpdateModeRow()
                settingsDivider()
                settingsSummaryValueRow(title: "Status", value: localizedWebAPIStatusTitle(store.webAPIStatus))
                settingsDivider()
                Text(localizedWebAPIStatusDetail(store.webAPIStatus))
                    .font(.subheadline)
                    .foregroundStyle(store.webAPIStatus.isError ? themePalette.destructiveTint : settingsPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                settingsDivider()
                settingsWebAPIIntegrationURLRow()
                settingsDivider()
                settingsButtonRow(
                    title: "Demo and Docs",
                    buttonTitle: "Open",
                    tint: settingsPalette.accent,
                    foreground: settingsPalette.accentText,
                    isEnabled: store.isWebAPIEnabled
                ) {
                    openWebAPIDemo()
                }
            }

            #if ENABLE_CUSTOM_USER_PAGE
            settingsSection(title: "Custom User Page", footer: "Files are stored locally on this device and served read-only at /user while the Web API is running. Edit the files in Files or Finder, and add index.html at the root or inside a folder.") {
                settingsOptionTip(customWebPageFilesTip, systemImage: "curlybraces.square")
                settingsSummaryValueRow(title: "User Page URL", value: webAPICustomUserPageURL)
                settingsSummaryValueRow(title: "Files Location", value: customWebPageFilesLocationDescription)
                #if os(macOS)
                settingsDivider()
                settingsButtonRow(
                    title: "Files",
                    buttonTitle: "Open in Finder",
                    tint: settingsPalette.accent,
                    foreground: settingsPalette.accentText
                ) {
                    openCustomWebPageFolderInFinder()
                }
                #endif
            }
            #endif

            settingsSection(title: "Security") {
                settingsOptionTip("Review Security before enabling network integrations on shared or unfamiliar networks. The Web API is intended for trusted local production devices and does not expose controls for changing scores, clocks, rosters, files, or settings.", systemImage: "lock.shield")
                Text("This API publishes scoreboard state to the trusted local network only. Connected devices can read live game data, but the service rejects score, clock, roster, file, and settings changes.")
                    .font(.body)
                    .foregroundStyle(settingsPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
        }
    }

    private func settingsIntegrationConfigurationSection() -> some View {
        settingsSection(
            title: "Configure Integration",
            footer: "Selecting an icon only changes which settings are shown; it does not turn other integrations off. Web API, Remote Display, and Bitfocus Companion are separate integrations."
        ) {
            settingsOptionTip("Choose which integration settings to edit. This selector is only navigation: Web API, Remote Display, and Bitfocus Companion each keep their own enabled state, connection details, and assignments.", systemImage: "arrow.left.arrow.right")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(IntegrationSettingsDetail.allCases) { detail in
                    settingsIntegrationConfigurationButton(detail)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func settingsIntegrationConfigurationButton(_ detail: IntegrationSettingsDetail) -> some View {
        let isSelected = selectedIntegrationDetail == detail

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                selectedIntegrationDetail = detail
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: detail.systemImage)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(isSelected ? settingsPalette.accentText : settingsPalette.accent)
                        .frame(width: 34, height: 34)
                        .background(
                            (isSelected ? settingsPalette.accent.opacity(0.18) : settingsPalette.fieldBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(settingsPalette.accentText)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                localizedAppText(detail.title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(isSelected ? settingsPalette.accentText : settingsPalette.primaryText)
                    .singleLineFitted(minScale: 0.72)

                localizedAppText(detail.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? settingsPalette.accentText.opacity(0.82) : settingsPalette.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                localizedAppText(detail.introduction)
                    .font(.caption)
                    .foregroundStyle(isSelected ? settingsPalette.accentText.opacity(0.78) : settingsPalette.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 174, alignment: .topLeading)
            .background(
                isSelected ? settingsPalette.accent : settingsPalette.fieldBackground,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? settingsPalette.accentText.opacity(0.32) : settingsPalette.cardBorder, lineWidth: isSelected ? 1.4 : 1)
            )
            .shadow(color: isSelected ? settingsPalette.accent.opacity(0.22) : .clear, radius: 14, y: 8)
            .scaleEffect(isSelected ? 1.015 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func settingsRemoteDisplayPane(layout _: InterfaceLayout) -> some View {
        let displayRows = remoteDisplaySettingsRows

        return VStack(alignment: .leading, spacing: 22) {
            settingsRemoteDisplayThisDeviceSection()
            settingsRemoteDisplayAboutSection()
            settingsRemoteDisplayBroadcastSection()
            settingsRemoteDisplayDisplaysSection(displayRows)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func settingsRemoteDisplayThisDeviceSection() -> some View {
        #if !os(tvOS)
        settingsSection(title: "Remote Display Mode", footer: remoteDisplayViewerModeFooter) {
            settingsOptionTip(remoteDisplayViewerModeTip, systemImage: "rectangle.on.rectangle")
            settingsButtonRow(
                title: "Enter Remote Display Mode",
                buttonTitle: "Enter",
                tint: settingsPalette.accent,
                foreground: settingsPalette.accentText
            ) {
                store.setRemoteDisplayViewerModeEnabled(true)
            }

            if isIPhoneInterface {
                settingsDivider()
                Text("iPhone can enter Remote Display Mode. In portrait, keep this screen available for the pairing code; if an external display is connected, it will show the remote scoreboard output.")
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                Text("Some scoreboard content, including player lists and longer text, may not display fully on the iPhone screen because of the limited space. For the best viewing experience, connect an external display.")
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
            }

            #if os(macOS)
            settingsDivider()
            settingsButtonRow(
                title: "Scoreboard Window",
                buttonTitle: "Open",
                tint: settingsPalette.accent,
                foreground: settingsPalette.accentText
            ) {
                store.setRemoteDisplayViewerModeEnabled(true)
                showPublicBoardWindow()
            }
            #endif
        }
        #endif
    }

    private var remoteDisplayViewerModeFooter: String {
        if isIPhoneInterface {
            return "Remote Display Mode replaces the operator interface. On iPhone, portrait can show the pairing code while a connected external display shows the scoreboard."
        }
        return "Remote Display Mode replaces the operator interface on this device until you exit from the Remote Display configuration screen."
    }

    private var remoteDisplayViewerModeTip: String {
        if isIPhoneInterface {
            return "Use Remote Display Mode on iPhone when the phone should show the pairing code or drive a connected external display. For the phone screen itself, landscape still gives the scoreboard more room."
        }
        return "Use Remote Display Mode when the current iPad or Mac should stop acting as an operator board and become a public remote display. On Mac you can also open a separate scoreboard window while keeping the operator controls available."
    }

    private func settingsRemoteDisplayAboutSection() -> some View {
        settingsSection(title: "About Remote Display") {
            settingsOptionTip("Use Remote Display for Apple TV, iPad, or Mac displays that should mirror the public scoreboard without browser URLs or a Web API client. Pairing happens nearby and the operator device remains the source of live updates.", systemImage: "tv.and.mediabox")
            Text("Remote Display uses nearby device pairing to send the public scoreboard to Apple TV, iPad, or Mac without IP addresses or the Web API. The operator device stays in control and paired displays receive live scoreboard, theme, and sound settings.")
                .font(.body)
                .foregroundStyle(settingsPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
        }
    }

    private func settingsRemoteDisplayBroadcastSection() -> some View {
        settingsSection(title: "Operator Broadcast", footer: "Turn this on from the operator device. Nearby displays in Remote Display Mode appear by device name.") {
            settingsOptionTip("Turn on Operator Broadcast from the device that will run the game. Nearby Remote Display devices can then pair, reconnect if saved, receive live scoreboard state, and stay in sync with theme and sound settings.", systemImage: "dot.radiowaves.left.and.right")
            settingsToggleRow(title: "Enable Remote Display Pairing", isOn: Binding(
                get: { store.isRemoteDisplayHostEnabled },
                set: { store.setRemoteDisplayHostEnabled($0) }
            ))
            settingsDivider()
            settingsRemoteDisplayNetworkModeRow()
            settingsDivider()
            settingsSummaryValueRow(title: "Status", value: localizedRemoteDisplayHostStatusTitle(store.remoteDisplayHostStatus))
            settingsDivider()
            settingsSummaryValueRow(title: "Connected Displays", value: remoteDisplayConnectedDisplayCountLabel)
            settingsDivider()
            Text(remoteDisplayHostStatusDetail)
                .font(.subheadline)
                .foregroundStyle(store.remoteDisplayHostStatus.isError ? themePalette.destructiveTint : settingsPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
        }
    }

    private func settingsRemoteDisplayNetworkModeRow() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    localizedAppText("Connection")
                        .foregroundStyle(settingsPalette.primaryText)

                    Spacer(minLength: 0)

                    remoteDisplayNetworkModePicker
                        .frame(maxWidth: 360)
                }

                VStack(alignment: .leading, spacing: 10) {
                    localizedAppText("Connection")
                        .foregroundStyle(settingsPalette.primaryText)

                    remoteDisplayNetworkModePicker
                        .frame(maxWidth: .infinity)
                }
            }

            localizedAppText(store.remoteDisplayNetworkMode.detail)
                .font(.subheadline)
                .foregroundStyle(settingsPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    private var remoteDisplayNetworkModePicker: some View {
        Picker("Connection", selection: Binding(
            get: { store.remoteDisplayNetworkMode },
            set: { store.setRemoteDisplayNetworkMode($0) }
        )) {
            ForEach(ScoreboardRemoteDisplayNetworkMode.allCases) { mode in
                localizedAppText(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private func settingsRemoteDisplayDisplaysSection(_ displayRows: [RemoteDisplaySettingsRow]) -> some View {
        settingsSection(title: "Displays", footer: "Connected, saved, and nearby displays appear together. Saved displays can connect without another code; new displays need the 4-digit code shown on that display.") {
            settingsOptionTip("Use Displays to see which remote screens are available, saved, connected, or waiting for a pairing code. Pair new screens from their four-digit code and reuse saved displays for faster setup at the next event.", systemImage: "display.2")
            settingsOptionTip("Each saved or connected Remote Display can use its own direction because screens may be mounted on opposite sides of the court, field, room, or player area. Set the direction here for that physical display, then use Swap Sides during the game only when the teams or sides need to flip live across every output.", systemImage: "arrow.left.and.right")
            if !store.isRemoteDisplayHostEnabled {
                settingsDivider()
                settingsSummaryValueRow(title: "Displays", value: localizedAppString("Enable Remote Display Pairing first"))
            } else if displayRows.isEmpty {
                settingsDivider()
                settingsSummaryValueRow(title: "Displays", value: localizedAppString("No displays found or saved"))
            } else {
                settingsDivider()
                ForEach(Array(displayRows.enumerated()), id: \.element.id) { index, row in
                    settingsRemoteDisplayRow(row)
                    if index < displayRows.count - 1 {
                        settingsDivider()
                    }
                }
            }
        }
    }

    private var remoteDisplayConnectedDisplayCountLabel: String {
        let count = store.remoteDisplayConnectedDisplays.count
        if count == 0 {
            return localizedAppString("None")
        }
        return localizedAppFormat("%d connected", count)
    }

    private var remoteDisplayHostStatusDetail: String {
        if store.isRemoteDisplayViewerModeEnabled {
            return localizedAppString("Pairing is paused while this device is in Remote Display Mode.")
        }
        return localizedRemoteDisplayHostStatusDetail(store.remoteDisplayHostStatus)
    }

    private func localizedRemoteDisplayHostStatusTitle(_ status: ScoreboardRemoteDisplayHostStatus) -> String {
        switch status {
        case .off:
            return localizedAppString("Off")
        case .browsing:
            return localizedAppString("Ready")
        case .failed:
            return localizedAppString("Failed")
        }
    }

    private func localizedRemoteDisplayHostStatusDetail(_ status: ScoreboardRemoteDisplayHostStatus) -> String {
        switch status {
        case .off:
            return localizedAppString("Remote Display pairing is off.")
        case .browsing(let displayCount, let pairedCount):
            if displayCount == 1 {
                return localizedAppFormat("Found %d display, %d connected.", displayCount, pairedCount)
            }
            return localizedAppFormat("Found %d displays, %d connected.", displayCount, pairedCount)
        case .failed(let message):
            return message
        }
    }

    private var remoteDisplaySettingsRows: [RemoteDisplaySettingsRow] {
        var rowsByID: [String: RemoteDisplaySettingsRow] = [:]

        for trusted in store.remoteDisplayTrustedDisplays {
            rowsByID[trusted.id] = RemoteDisplaySettingsRow(
                id: trusted.id,
                name: trusted.name,
                deviceType: trusted.deviceType ?? .unknown,
                source: nil,
                connection: nil,
                trusted: trusted,
                isTrusted: true,
                isMuted: store.isRemoteDisplayMuted(displayID: trusted.id)
            )
        }

        for source in store.remoteDisplaySources {
            let trusted = store.remoteDisplayTrustedDisplays.first { $0.id == source.id }
            let isTrusted = store.isTrustedRemoteDisplay(source)
            let existing = rowsByID[source.id]
            rowsByID[source.id] = RemoteDisplaySettingsRow(
                id: source.id,
                name: source.name,
                deviceType: source.deviceType,
                source: source,
                connection: existing?.connection,
                trusted: trusted,
                isTrusted: isTrusted,
                isMuted: store.isRemoteDisplayMuted(displayID: source.id)
            )
        }

        for connection in store.remoteDisplayConnectedDisplays {
            let trusted = store.remoteDisplayTrustedDisplays.first { $0.id == connection.id }
            let existing = rowsByID[connection.id]
            rowsByID[connection.id] = RemoteDisplaySettingsRow(
                id: connection.id,
                name: connection.name,
                deviceType: connection.deviceType,
                source: existing?.source,
                connection: connection,
                trusted: trusted,
                isTrusted: trusted != nil || existing?.isTrusted == true,
                isMuted: connection.isMuted || store.isRemoteDisplayMuted(displayID: connection.id)
            )
        }

        return rowsByID.values.sorted { lhs, rhs in
            if lhs.sortRank != rhs.sortRank {
                return lhs.sortRank < rhs.sortRank
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func requestPairRemoteDisplay(_ source: ScoreboardRemoteDisplaySource, pairingCode: String) {
        if source.needsTakeoverConfirmation(currentOperatorID: store.remoteDisplayHostID) {
            pendingRemoteDisplayTakeover = PendingRemoteDisplayTakeover(
                source: source,
                action: .pair(code: pairingCode)
            )
            return
        }

        store.pairRemoteDisplay(source, pairingCode: pairingCode)
    }

    private func requestConnectTrustedRemoteDisplay(_ source: ScoreboardRemoteDisplaySource) {
        if source.needsTakeoverConfirmation(currentOperatorID: store.remoteDisplayHostID) {
            pendingRemoteDisplayTakeover = PendingRemoteDisplayTakeover(
                source: source,
                action: .connectTrusted
            )
            return
        }

        store.connectTrustedRemoteDisplay(source)
    }

    private func performRemoteDisplayTakeover(_ takeover: PendingRemoteDisplayTakeover) {
        switch takeover.action {
        case .pair(let code):
            store.pairRemoteDisplay(
                takeover.source,
                pairingCode: code,
                takeoverConfirmed: true
            )
        case .connectTrusted:
            store.connectTrustedRemoteDisplay(
                takeover.source,
                takeoverConfirmed: true
            )
        }
    }

    private func remoteDisplayTakeoverMessage(for takeover: PendingRemoteDisplayTakeover) -> String {
        let source = takeover.source
        let operatorName = source.activeOperatorName
            ?? source.lastActiveOperatorName
            ?? localizedAppString("another operator device")
        if source.receiverState == .runningPairing {
            return localizedAppFormat(
                "%@ is currently showing the pair screen while connected to %@. Replacing it will move the live Remote Display session to this operator device.",
                source.name,
                operatorName
            )
        }
        return localizedAppFormat(
            "%@ was previously connected to %@. Replacing it will allow this operator device to run that Remote Display.",
            source.name,
            operatorName
        )
    }

    private func settingsRemoteDisplayRow(_ row: RemoteDisplaySettingsRow) -> some View {
        let versionWarning = row.isOffline ? nil : remoteDisplayVersionWarningText(row.appVersion)
        let isInUseByOtherBoard = row.source?.isInUseByOtherOperator(currentOperatorID: store.remoteDisplayHostID) == true
        let enteredCode = row.source.map { remoteDisplayPairingCodes[$0.id] ?? "" } ?? ""
        let allowsSourceAction = row.source?.allowsNewPairing ?? false
        let canConnect = row.source != nil
            && row.isTrusted
            && !row.isConnected
            && !isInUseByOtherBoard
            && allowsSourceAction
        let canPair = row.source != nil
            && !row.isTrusted
            && !row.isConnected
            && !isInUseByOtherBoard
            && allowsSourceAction
            && enteredCode.count == ScoreboardRemoteDisplayHostService.pairingCodeLength
        let canTestSound = row.isConnected && !row.isMuted

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: row.deviceType.systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(remoteDisplayRowIconColor(row, isInUseByOtherBoard: isInUseByOtherBoard, hasVersionWarning: versionWarning != nil))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(row.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(settingsPalette.primaryText)
                            .lineLimit(1)

                        Text(localizedAppString(row.deviceType.title))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(settingsPalette.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(settingsPalette.fieldBackground, in: Capsule())
                    }

                    Text(remoteDisplayRowStatusText(row, isInUseByOtherBoard: isInUseByOtherBoard))
                        .font(.subheadline)
                        .foregroundStyle(isInUseByOtherBoard ? themePalette.destructiveTint : settingsPalette.secondaryText)

                    if let versionWarning {
                        Text(versionWarning)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.orange)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                if let connection = row.connection {
                    remoteDisplayConnectionQualityBadge(connection.quality)
                } else if row.isTrusted {
                    remoteDisplayStatusBadge(remoteDisplayRowBadgeTitle(row, isInUseByOtherBoard: isInUseByOtherBoard))
                }

                if row.isTrusted || row.isConnected {
                    remoteDisplayIconActionButton(
                        row.isMuted ? "Unmute" : "Mute",
                        systemImage: row.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        tint: row.isMuted ? settingsPalette.accent : settingsPalette.fieldBackground,
                        foreground: row.isMuted ? settingsPalette.accentText : settingsPalette.primaryText
                    ) {
                        store.setRemoteDisplayMuted(displayID: row.id, isMuted: !row.isMuted)
                    }
                }

                if row.isConnected {
                    remoteDisplayIconActionButton(
                        "Test",
                        systemImage: "play.fill",
                        tint: canTestSound ? settingsPalette.accent : settingsPalette.fieldBackground,
                        foreground: canTestSound ? settingsPalette.accentText : settingsPalette.secondaryText,
                        isEnabled: canTestSound
                    ) {
                        store.sendRemoteDisplaySoundTest(displayID: row.id)
                    }

                    remoteDisplayIconActionButton(
                        "Disconnect",
                        systemImage: "xmark.circle",
                        tint: themePalette.destructiveTint.opacity(0.12),
                        foreground: themePalette.destructiveTint
                    ) {
                        store.disconnectRemoteDisplay(displayID: row.id)
                    }
                } else if row.isTrusted, let source = row.source {
                    remoteDisplayTextActionButton(
                        "Connect",
                        systemImage: "link",
                        tint: settingsPalette.accent,
                        foreground: settingsPalette.accentText,
                        isEnabled: canConnect
                    ) {
                        requestConnectTrustedRemoteDisplay(source)
                    }
                } else if let source = row.source {
                    TextField(
                        localizedAppString("Code"),
                        text: remoteDisplayPairingCodeBinding(for: source)
                    )
                    .font(.title3.weight(.black).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .scoreboardNumberEntry()
                    .foregroundStyle(settingsPalette.primaryText)
                    .textFieldStyle(.plain)
                    .frame(width: 88)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(settingsPalette.cardBorder, lineWidth: 1)
                    )
                    .onSubmit {
                        guard canPair else { return }
                        requestPairRemoteDisplay(source, pairingCode: enteredCode)
                    }
                    .disabled(isInUseByOtherBoard)

                    remoteDisplayTextActionButton(
                        "Pair",
                        systemImage: "key.fill",
                        tint: settingsPalette.accent,
                        foreground: settingsPalette.accentText,
                        isEnabled: canPair
                    ) {
                        requestPairRemoteDisplay(source, pairingCode: enteredCode)
                    }
                }

                if row.isTrusted {
                    remoteDisplayIconActionButton(
                        "Remove",
                        systemImage: "trash",
                        tint: themePalette.destructiveTint.opacity(0.12),
                        foreground: themePalette.destructiveTint
                    ) {
                        store.removeRemoteDisplayPairing(displayID: row.id)
                    }
                }
            }

            if row.isTrusted || row.isConnected {
                remoteDisplayDirectionControls(row)
                    .padding(.leading, 46)
            }
        }
        .padding(.vertical, 12)
    }

    private func remoteDisplayDirectionControls(_ row: RemoteDisplaySettingsRow) -> some View {
        HStack(spacing: 10) {
            remoteDisplayDirectionPicker(
                title: "Remote Display",
                selection: Binding(
                    get: { store.remoteDisplayDirection(displayID: row.id) },
                    set: { store.setRemoteDisplayDirection(displayID: row.id, direction: $0) }
                )
            )

            if row.deviceType == .mac || row.deviceType == .ipad {
                remoteDisplayDirectionPicker(
                    title: "External Display",
                    selection: Binding(
                        get: { store.remoteDisplayExternalDirection(displayID: row.id) },
                        set: { store.setRemoteDisplayExternalDirection(displayID: row.id, direction: $0) }
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func remoteDisplayDirectionPicker(
        title: String,
        selection: Binding<ScoreboardDisplayDirection>
    ) -> some View {
        HStack(spacing: 8) {
            Text(localizedAppString(title))
                .font(.caption.weight(.bold))
                .foregroundStyle(settingsPalette.secondaryText)

            Picker(localizedAppString(title), selection: selection) {
                ForEach(ScoreboardDisplayDirection.allCases) { direction in
                    Text(localizedAppString(direction.title)).tag(direction)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settingsPalette.cardBorder.opacity(0.7), lineWidth: 1)
        )
    }

    private func remoteDisplayIconActionButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        foreground: Color,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(settingsPalette.cardBorder.opacity(0.7), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func remoteDisplayTextActionButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        foreground: Color,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(localizedAppString(title), systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.58)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func remoteDisplayRowIconColor(
        _ row: RemoteDisplaySettingsRow,
        isInUseByOtherBoard: Bool,
        hasVersionWarning: Bool
    ) -> Color {
        if hasVersionWarning {
            return .orange
        }
        if isInUseByOtherBoard {
            return themePalette.destructiveTint
        }
        if let quality = row.connection?.quality {
            return remoteDisplayConnectionQualityColor(quality)
        }
        if row.source != nil {
            return settingsPalette.accent
        }
        return settingsPalette.secondaryText
    }

    private func remoteDisplayRowStatusText(
        _ row: RemoteDisplaySettingsRow,
        isInUseByOtherBoard: Bool
    ) -> String {
        if let connection = row.connection {
            let soundState = row.isMuted ? localizedAppString("Muted") : localizedAppString("Sound on")
            return "\(remoteDisplayConnectionDetail(connection)) · \(soundState)"
        }
        if isInUseByOtherBoard, let source = row.source {
            return localizedAppFormat("In use by %@", source.activeOperatorName ?? localizedAppString("another operator device"))
        }
        if let source = row.source, source.needsTakeoverConfirmation(currentOperatorID: store.remoteDisplayHostID) {
            let operatorName = source.activeOperatorName
                ?? source.lastActiveOperatorName
                ?? localizedAppString("another operator device")
            switch source.receiverState {
            case .runningPairing:
                return localizedAppFormat("Pair screen is open. Replacing %@ requires confirmation.", operatorName)
            case .awaitingReconnect, .disconnecting:
                return localizedAppFormat("Waiting for %@ to reconnect. Replacing it requires confirmation.", operatorName)
            case .waitingPaired:
                return localizedAppFormat("Previously paired with %@. Replacing it requires confirmation.", operatorName)
            case .waitingUnpaired, .running:
                break
            }
        }
        if let source = row.source, source.lastActiveOperatorID == store.remoteDisplayHostID, !row.isConnected {
            return localizedAppString("Saved. This operator device can reconnect automatically.")
        }
        if row.isTrusted, row.source != nil {
            return localizedAppString("Saved. Use Connect without a code.")
        }
        if row.isTrusted {
            return localizedAppString("Offline. Saved display can reconnect when it is in Remote Display Mode.")
        }
        return row.source?.detail ?? localizedAppString("Waiting for Remote Display")
    }

    private func remoteDisplayRowBadgeTitle(
        _ row: RemoteDisplaySettingsRow,
        isInUseByOtherBoard: Bool
    ) -> String {
        if row.isOffline {
            return "Offline"
        }
        if isInUseByOtherBoard {
            return "In Use"
        }
        guard let source = row.source else {
            return "Ready"
        }
        switch source.receiverState {
        case .waitingUnpaired:
            return "Ready"
        case .waitingPaired:
            return "Saved"
        case .running:
            return "In Use"
        case .runningPairing:
            return "Pairing"
        case .awaitingReconnect:
            return "Reconnect"
        case .disconnecting:
            return "Disconnecting"
        }
    }

    private func remoteDisplayConnectionQualityBadge(_ quality: ScoreboardRemoteDisplayConnectionQuality) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(remoteDisplayConnectionQualityColor(quality))
                .frame(width: 8, height: 8)
            Text(remoteDisplayConnectionQualityLabel(quality))
                .font(.caption.weight(.bold))
                .foregroundStyle(settingsPalette.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(settingsPalette.fieldBackground, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private func remoteDisplayStatusBadge(_ title: String) -> some View {
        Text(localizedAppString(title))
            .font(.caption.weight(.bold))
            .foregroundStyle(settingsPalette.primaryText)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(settingsPalette.fieldBackground, in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }

    private func remoteDisplayPairingCodeBinding(for source: ScoreboardRemoteDisplaySource) -> Binding<String> {
        Binding(
            get: { remoteDisplayPairingCodes[source.id] ?? "" },
            set: { value in
                remoteDisplayPairingCodes[source.id] = String(value.filter(\.isNumber).prefix(ScoreboardRemoteDisplayHostService.pairingCodeLength))
            }
        )
    }

    private func remoteDisplayVersionWarningText(_ version: ScoreboardRemoteDisplayAppVersion?) -> String? {
        guard let version else {
            return localizedAppFormat(
                "Version unknown on display, operator device %@",
                ScoreboardRemoteDisplayAppVersion.current.displayText
            )
        }
        guard version.isMismatch() else {
            return nil
        }
        return localizedAppFormat(
            "Version mismatch: display %@, operator device %@",
            version.displayText,
            ScoreboardRemoteDisplayAppVersion.current.displayText
        )
    }

    private func remoteDisplayConnectionDetail(_ connection: ScoreboardRemoteDisplayConnection) -> String {
        if let latencyMilliseconds = connection.latencyMilliseconds {
            if let age = connection.lastHandshakeAgeSeconds, age >= 1 {
                return localizedAppFormat("Ping %d ms · last reply %d s ago", latencyMilliseconds, age)
            }
            return localizedAppFormat("Ping %d ms", latencyMilliseconds)
        }
        if let age = connection.lastHandshakeAgeSeconds {
            return localizedAppFormat("Waiting for ping reply · last reply %d s ago", age)
        }
        return localizedAppString("Pinging")
    }

    private func remoteDisplayConnectionQualityColor(_ quality: ScoreboardRemoteDisplayConnectionQuality) -> Color {
        switch quality {
        case .connecting:
            return settingsPalette.secondaryText
        case .live:
            return .green
        case .poor:
            return .orange
        case .unresponsive:
            return themePalette.destructiveTint
        }
    }

    private func remoteDisplayConnectionQualityLabel(_ quality: ScoreboardRemoteDisplayConnectionQuality) -> String {
        switch quality {
        case .connecting:
            return localizedAppString("Connecting")
        case .live:
            return localizedAppString("Good")
        case .poor:
            return localizedAppString("Poor")
        case .unresponsive:
            return localizedAppString("No Reply")
        }
    }

    private func settingsBitfocusCompanionPane(layout: InterfaceLayout) -> some View {
        let events = store.assignableSoundEvents(for: selectedCompanionSettingsSport)

        return VStack(alignment: .leading, spacing: 22) {
            settingsCompanionAboutSection()

            settingsTwoColumnLayout(layout: layout) {
                VStack(alignment: .leading, spacing: 22) {
                    settingsCompanionConnectionSection()
                    settingsCompanionSportSection(layout: layout)
                }
            } right: {
                settingsCompanionEventsSection(events)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private func settingsCompanionConnectionSection() -> some View {
        settingsSection(title: "Bitfocus Companion", footer: "Show Companion controls the live-board button. Turning it off also disables Companion, while keeping every option and event assignment saved.") {
            settingsOptionTip("Use Bitfocus Companion settings to send PRESS commands to a Companion instance on the local network. Show Companion controls whether operators see the live-board toggle, while Enable Companion controls whether event commands are sent.", systemImage: "square.grid.3x3")
            settingsToggleRow(title: "Show Companion", isOn: Binding(
                get: { store.isCompanionVisible },
                set: { store.setCompanionVisible($0) }
            ))
            settingsDivider()
            settingsToggleRow(title: "Enable Companion", isOn: Binding(
                get: { store.isCompanionEnabled },
                set: { store.setCompanionEnabled($0) }
            ))
            .disabled(!store.isCompanionVisible)
            .opacity(store.isCompanionVisible ? 1 : 0.42)
            settingsDivider()
            settingsPlainTextEntryRow(
                title: "Companion IP",
                text: Binding(
                    get: { store.companionHost },
                    set: { store.setCompanionHost($0) }
                ),
                placeholder: "192.168.1.50"
            )
            settingsDivider()
            settingsPickerRow(
                title: "Mode",
                selection: Binding(
                    get: { store.companionMode },
                    set: { store.setCompanionMode($0) }
                ),
                options: ScoreboardCompanionMode.allCases,
                label: { $0.title }
            )
            settingsDivider()
            settingsCompanionPortRow()
            settingsDivider()
            settingsSummaryValueRow(title: "Status", value: companionStatusTitle)
            settingsDivider()
            Text(companionStatusDetail)
                .font(.subheadline)
                .foregroundStyle(companionStatusIsError ? themePalette.destructiveTint : settingsPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
        }
    }

    private func settingsCompanionAboutSection() -> some View {
        settingsSection(title: "About Companion") {
            settingsOptionTip("Use Companion when scoreboard events should trigger production automation, such as switching scenes, firing graphics, or controlling external gear. Scoreboard sends button press commands to Companion; Companion handles the downstream actions.", systemImage: "bolt.horizontal")
            Text("Bitfocus Companion is a separate automation tool for triggering actions on production gear and software. SmartScoreboard can send Companion PRESS commands from scoreboard events.")
                .font(.body)
                .foregroundStyle(settingsPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            settingsDivider()
            settingsLinkRow(
                title: "Bitfocus Companion",
                subtitle: "bitfocus.io/companion",
                systemImage: "square.grid.3x3",
                urlString: "https://bitfocus.io/companion"
            )
        }
    }

    private func settingsCompanionSportSection(layout: InterfaceLayout) -> some View {
        settingsSection(title: "Configure Sport", footer: "Choose which sport's automation assignments to edit. The live board keeps using the currently configured game sport.") {
            settingsOptionTip("Choose the sport whose Companion assignments you want to edit. Assignments are stored per sport, so basketball, soccer, debate, and custom games can each trigger different Companion buttons.", systemImage: "slider.horizontal.3")
            compactSportSelectionGrid(layout: layout, selection: $selectedCompanionSettingsSport)
        }
    }

    private func settingsCompanionEventsSection(_ events: [ScoreboardSoundEvent]) -> some View {
        settingsSection(title: "Event Commands", footer: "Assign a Companion location to each supported event for the selected sport. Empty assignments do not send commands.") {
            settingsOptionTip("Use Event Commands to map scoreboard moments to Companion page, row, and column locations. Empty assignments are ignored, so you can automate only the events that matter for the selected sport.", systemImage: "square.grid.3x3")
            if events.isEmpty {
                settingsSummaryValueRow(title: selectedCompanionSettingsSport.title, value: localizedAppString("No configurable sound events"))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        settingsCompanionAssignmentRow(event, sport: selectedCompanionSettingsSport)

                        if index < events.count - 1 {
                            settingsDivider()
                        }
                    }
                }
            }
        }
    }

    private func settingsLocalNetworkPermissionSection() -> some View {
        settingsSection(title: "Local Network Permission", footer: localNetworkPermissionFooter) {
            settingsOptionTip("Local Network permission is required before this device can discover nearby displays, host the Web API, or send commands to Companion on your production network. Open system settings here if the OS has blocked access.", systemImage: "wifi")
            settingsButtonRow(
                title: "System Settings",
                buttonTitle: "Open",
                tint: settingsPalette.accent,
                foreground: settingsPalette.accentText
            ) {
                openLocalNetworkSettings()
            }
        }
    }

    private var companionStatusTitle: String {
        if !store.isCompanionVisible {
            return localizedAppString("Hidden")
        }
        if !store.isCompanionEnabled {
            return localizedAppString("Off")
        }
        if store.companionHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localizedAppString("Missing Host")
        }
        if store.companionLastError != nil {
            return localizedAppString("Last Error")
        }
        return localizedAppString("Ready")
    }

    private var companionStatusDetail: String {
        if !store.isCompanionVisible {
            return localizedAppString("Companion is hidden from the live board and disabled. Settings and event assignments remain saved.")
        }
        if !store.isCompanionEnabled {
            return localizedAppString("Companion is disabled. Settings and event assignments remain saved.")
        }
        if store.companionHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localizedAppString("Enter the Companion IP address or host before event triggers can send commands.")
        }
        if let error = store.companionLastError {
            return error
        }
        return localizedAppFormat("Ready to send %@ commands to %@:%d.", store.companionMode.title, store.companionHost, Int(store.companionPort))
    }

    private var companionStatusIsError: Bool {
        store.isCompanionEnabled && (store.companionHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.companionLastError != nil)
    }

    private func settingsCompanionPortRow() -> some View {
        return HStack(spacing: 16) {
            localizedAppText("Port")
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            DeferredSettingsTextField(
                placeholder: "Port",
                text: Binding(
                    get: { store.companionPortText() },
                    set: { store.setCompanionPortText($0) }
                ),
                focusID: "companion-port",
                focusedField: $focusedSettingsTextFieldID
            )
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .scoreboardNumberEntry()
                .monospacedDigit()
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: 140)
        }
        .padding(.vertical, 10)
    }

    private func settingsCompanionAssignmentRow(_ event: ScoreboardSoundEvent, sport: SportType) -> some View {
        let locationText = store.companionLocationText(for: event, sport: sport)
        let trimmedLocationText = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = ScoreboardCompanionLocation(rawValue: locationText)
        let validationMessage = location == nil ? ScoreboardCompanionLocation.validationMessage(for: locationText) : nil
        let normalizedLocation = location?.rawValue
        let hasAssignment = !trimmedLocationText.isEmpty
        let canTest = store.isCompanionVisible &&
            store.isCompanionEnabled &&
            !store.companionHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            location != nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: event.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(settingsPalette.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    localizedAppText(event.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)

                    localizedAppText(event.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                DeferredSettingsTextField(
                    placeholder: "1:0:2",
                    text: Binding(
                        get: { store.companionLocationDisplayText(for: event, sport: sport) },
                        set: { store.setCompanionLocationDisplayText($0, for: event, sport: sport) }
                    ),
                    focusID: "companion-location-\(sport.rawValue)-\(event.rawValue)",
                    focusedField: $focusedSettingsTextFieldID
                )
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .scoreboardNumberEntry()
                .monospacedDigit()
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(width: 128)

                Button {
                    store.testCompanionCommand(for: event, sport: sport)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(canTest ? settingsPalette.accentText : settingsPalette.secondaryText)
                        .frame(width: 40, height: 40)
                        .background(
                            canTest ? settingsPalette.accent : settingsPalette.fieldBackground,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canTest)
                .opacity(canTest ? 1 : 0.42)
                .accessibilityLabel(localizedAppString("Test Companion command"))
                .help(localizedAppString("Test Companion command"))
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(themePalette.destructiveTint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let normalizedLocation {
                Text(localizedAppFormat("Sends LOCATION %@ PRESS.", normalizedLocation))
                    .font(.footnote)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !hasAssignment {
                localizedAppText("No Companion command assigned.")
                    .font(.footnote)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
    }

    private func settingsWebAPIUpdateModeRow() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                localizedAppText("Update Mode")
                    .foregroundStyle(settingsPalette.primaryText)

                Spacer(minLength: 0)

                Picker("Update Mode", selection: Binding(
                    get: { store.webAPIUpdateMode },
                    set: { store.setWebAPIUpdateMode($0) }
                )) {
                    ForEach(ScoreboardWebAPIUpdateMode.allCases) { mode in
                        localizedAppText(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }

            localizedAppText(store.webAPIUpdateMode.detail)
                .font(.subheadline)
                .foregroundStyle(settingsPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    private func localizedWebAPIStatusTitle(_ status: ScoreboardWebAPIStatus) -> String {
        localizedAppString(status.title)
    }

    private func localizedWebAPIStatusDetail(_ status: ScoreboardWebAPIStatus) -> String {
        switch status {
        case .running(let httpPort, let webSocketPort, let clientCount):
            return localizedAppFormat("HTTP %@, WebSocket %@, %@ connected WS clients.", "\(httpPort)", "\(webSocketPort)", "\(clientCount)")
        case .portUnavailable(let message), .failed(let message):
            return localizedAppString(message)
        case .off, .starting, .suspended, .permissionDenied:
            return localizedAppString(status.detail)
        }
    }

    private func settingsWebAPIIntegrationURLRow() -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            localizedAppText("Integration URL")
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Text(webAPIIntegrationURL)
                .font(.footnote.monospaced())
                .foregroundStyle(settingsPalette.secondaryText)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 10)
    }

    private var webAPIIntegrationURL: String {
        if let address = store.webAPILocalAddresses.first {
            return "http://\(address):\(ScoreboardWebAPIService.httpPort)/"
        }
        return "http://127.0.0.1:\(ScoreboardWebAPIService.httpPort)/"
    }

    #if ENABLE_CUSTOM_USER_PAGE
    private var webAPICustomUserPageURL: String {
        if let address = store.webAPILocalAddresses.first {
            return "http://\(address):\(ScoreboardWebAPIService.httpPort)/user"
        }
        return "http://127.0.0.1:\(ScoreboardWebAPIService.httpPort)/user"
    }

    private var customWebPageFilesLocationDescription: String {
        #if os(iOS)
        let filesApp = localizedAppString("Files")
        let localRoot = localizedAppString(UIDevice.current.userInterfaceIdiom == .pad ? "On My iPad" : "On My iPhone")
        return "\(filesApp) > \(localRoot) > \(ScoreboardFileStorage.filesAppContainerName) > \(ScoreboardCustomWebPage.userVisibleDirectoryName)"
        #elseif os(macOS)
        if let rootDirectory = try? ScoreboardCustomWebPage.rootDirectoryURL(create: false) {
            return rootDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        }
        return "Application Support > \(ScoreboardCustomWebPage.userVisibleDirectoryName)"
        #else
        return ScoreboardCustomWebPage.userVisibleDirectoryName
        #endif
    }

    private var customWebPageFilesTip: String {
        #if os(iOS)
        return "Open the Files app and go to the Scoreboard folder to edit index.html and assets for this page. The Web API only serves these files; it does not allow remote uploads, deletes, or edits."
        #elseif os(macOS)
        return "Open Finder and edit index.html and assets in the folder below. The Web API only serves these files; it does not allow remote uploads, deletes, or edits."
        #else
        return "Edit index.html and assets in the folder below. The Web API only serves these files; it does not allow remote uploads, deletes, or edits."
        #endif
    }

    #if os(macOS)
    private func openCustomWebPageFolderInFinder() {
        do {
            let rootDirectory = try ScoreboardCustomWebPage.rootDirectoryURL()
            NSWorkspace.shared.open(rootDirectory)
        } catch {
            presentFileOperationError(error)
        }
    }
    #endif
    #endif

    private var localNetworkPermissionFooter: String {
        #if os(iOS)
        return "Open Settings and enable Local Network for Scoreboard."
        #elseif os(macOS)
        return "Open System Settings, then enable Scoreboard under Privacy & Security > Local Network."
        #else
        return "Enable local network access for Scoreboard in system settings."
        #endif
    }

    private func openWebAPIDemo() {
        guard let url = URL(string: "http://127.0.0.1:\(ScoreboardWebAPIService.httpPort)/") else {
            return
        }
        openURL(url)
    }

    private func openLocalNetworkSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func settingsAboutPane() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Application") {
                HStack(alignment: .center, spacing: 18) {
                    Image(currentAppIconAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(settingsPalette.cardBorder)
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            handleApplicationNameTapped()
                        } label: {
                            Text(appDisplayName)
                                .font(.title3.weight(.black))
                                .foregroundStyle(settingsPalette.primaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(localizedAppString(isBunnyIconEnabled ? "Restore the original app icon" : "Unlock a hidden app icon"))
                        .help(localizedAppString(isBunnyIconEnabled ? "Restore the original app icon" : "Unlock a hidden app icon"))

                        Text(appVersionLine)
                            .font(.subheadline)
                            .foregroundStyle(settingsPalette.secondaryText)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)

                if isBunnyIconEnabled {
                    settingsDivider()
                    settingsButtonRow(
                        title: "App Icon",
                        buttonTitle: "Restore Original",
                        tint: settingsPalette.accent,
                        foreground: settingsPalette.accentText
                    ) {
                        restoreOriginalAppIcon()
                    }
                }
            }

            settingsSection(title: "Help", footer: "Tips guide you through setup and key controls around the app. Turn them off here, or reset them to show dismissed tips again.") {
                settingsToggleRow(
                    title: "Tips",
                    isOn: Binding(
                        get: { store.areTipsEnabled },
                        set: { store.areTipsEnabled = $0 }
                    )
                )
                settingsDivider()
                settingsToggleRow(
                    title: "Show Getting Started on Startup",
                    isOn: Binding(
                        get: { store.showGettingStartedOnStartup },
                        set: { store.setGettingStartedStartupEnabled($0) }
                    )
                )
                settingsDivider()
                settingsButtonRow(
                    title: "Getting Started",
                    buttonTitle: "Show",
                    tint: settingsPalette.accent,
                    foreground: settingsPalette.accentText
                ) {
                    presentGettingStarted(auto: false)
                }
                settingsDivider()
                settingsButtonRow(
                    title: "Tip History",
                    buttonTitle: "Reset Tips",
                    tint: settingsPalette.accent,
                    foreground: settingsPalette.accentText
                ) {
                    resetScoreboardTips()
                }
            }

            settingsSection(title: "Factory Default", footer: "Deletes local app data and returns Scoreboard to its first-launch defaults.") {
                settingsButtonRow(
                    title: "Reset App",
                    buttonTitle: "Factory Default",
                    tint: themePalette.destructiveTint,
                    foreground: destructiveText
                ) {
                    isFactoryDefaultConfirmationPresented = true
                }
            }

            settingsSection(title: "License", footer: "See LICENSE.md in the repository for the full GNU General Public License text.") {
                settingsSummaryValueRow(title: "License", value: "GNU General Public License v3.0")
                settingsDivider()
                Text("This software is free software released under the GNU General Public License version 3. You may redistribute and modify it under those terms.")
                    .font(.body)
                    .foregroundStyle(settingsPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                settingsDivider()
                Text("Distributed without warranty.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(settingsPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }

            settingsSection(title: "Third-Party Licenses") {
                Text("The Web API demo pages use bundled first-party HTML, CSS, and JavaScript only. No third-party web libraries are included for these integrations.")
                    .font(.body)
                    .foregroundStyle(settingsPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }

            settingsSection(title: "Trademarks") {
                Text("Bitfocus Companion is a trademark of its respective owner. SmartScoreboard is not affiliated with or endorsed by Bitfocus.")
                    .font(.body)
                    .foregroundStyle(settingsPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }

            settingsSection(title: "Links") {
                settingsLinkRow(
                    title: "Source Code",
                    subtitle: "github.com/sikaxn/scoreboard",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    urlString: "https://github.com/sikaxn/scoreboard"
                )
                settingsDivider()
                settingsLinkRow(
                    title: "Privacy Policy",
                    subtitle: "studenttechsupport.com/privacy",
                    systemImage: "hand.raised",
                    urlString: "https://studenttechsupport.com/privacy"
                )
                settingsDivider()
                settingsLinkRow(
                    title: "Email",
                    subtitle: "smartscoreboard@studenttechsupport.com",
                    systemImage: "envelope",
                    urlString: "mailto:smartscoreboard@studenttechsupport.com"
                )
                settingsDivider()
                settingsLinkRow(
                    title: "Bug Reports",
                    subtitle: "Open a GitHub issue",
                    systemImage: "exclamationmark.bubble",
                    urlString: "https://github.com/sikaxn/scoreboard/issues/new"
                )
            }

            settingsSection(title: "Bug Reports") {
                Text("To report a bug, open a GitHub issue in the scoreboard repository and include the sport, device, OS version, and steps to reproduce.")
                    .font(.body)
                    .foregroundStyle(settingsPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }

            settingsSection(title: "Privacy") {
                Text("This app does not collect any data and does not phone any third-party server.")
                    .font(.body)
                    .foregroundStyle(settingsPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
        }
    }

    private var bunnyEasterEggSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    Image(currentAppIconAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(settingsPalette.cardBorder)
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Hey, you found the bunny")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(settingsPalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("The hidden app icon is now active on this device.")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(settingsPalette.secondaryText)
                    }
                }

                VStack(spacing: 0) {
                    bunnyEasterEggFeatureRow(
                        title: "Bunny Icon",
                        detail: "About and welcome now use the hidden icon.",
                        systemImage: "app"
                    )
                    settingsDivider()
                    #if os(macOS)
                    bunnyEasterEggFeatureRow(
                        title: "In-App Only",
                        detail: "On Mac, the hidden icon appears inside the app.",
                        systemImage: "desktopcomputer"
                    )
                    #else
                    bunnyEasterEggFeatureRow(
                        title: "Home Screen",
                        detail: "iPhone and iPad may ask before changing the Home Screen icon.",
                        systemImage: "iphone"
                    )
                    #endif
                    settingsDivider()
                    bunnyEasterEggFeatureRow(
                        title: "Change It Back",
                        detail: "Tap Smart Scoreboard again in About, or use Restore Original.",
                        systemImage: "arrow.uturn.backward"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(settingsPalette.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(settingsPalette.cardBorder)
                )

                HStack(spacing: 12) {
                    Button {
                        restoreOriginalAppIcon()
                    } label: {
                        Label("Restore Original", systemImage: "arrow.uturn.backward")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(settingsPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(settingsPalette.fieldBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)

                    Button {
                        showsBunnyEasterEgg = false
                    } label: {
                        Label("Keep Bunny", systemImage: "checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(settingsPalette.accentText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(settingsPalette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(settingsPalette.shellBackground)
        #if os(iOS)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
        #endif
        #if os(macOS)
        .frame(minWidth: 620, idealWidth: 700, maxWidth: 760, minHeight: 420, idealHeight: 430, maxHeight: 470)
        #endif
    }

    private func bunnyEasterEggFeatureRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(settingsPalette.accentText)
                .frame(width: 34, height: 34)
                .background(settingsPalette.accent, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                localizedAppText(title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(settingsPalette.primaryText)

                localizedAppText(detail)
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 9)
    }

    private var gettingStartedSheet: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 620

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center, spacing: 16) {
                        Image(currentAppIconAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(settingsPalette.cardBorder)
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Welcome to Smart Scoreboard")
                                .font(.system(size: isCompact ? 28 : 34, weight: .black, design: .rounded))
                                .foregroundStyle(settingsPalette.primaryText)

                            Text("Set up the game, open the public board, then run the live controls from one operator screen.")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(settingsPalette.secondaryText)
                        }
                    }

                    VStack(spacing: 0) {
                        gettingStartedFeatureRow(
                            title: "Start in Game Setup",
                            detail: "Choose the sport, teams, clock defaults, display options, files, and integrations before opening the live board.",
                            systemImage: "slider.horizontal.3"
                        )
                        settingsDivider()
                        gettingStartedFeatureRow(
                            title: "Show the Public Board",
                            detail: "On Mac, open the public scoreboard window. On iPad, connect an external display or pair a Remote Display.",
                            systemImage: "display.2"
                        )
                        settingsDivider()
                        gettingStartedFeatureRow(
                            title: "Run the Game",
                            detail: "Use the live board for score, clock, shot clock, players, fouls, substitutions, sound, and companion controls.",
                            systemImage: "trophy"
                        )
                        settingsDivider()
                        gettingStartedFeatureRow(
                            title: "Tips Guide You Through the App",
                            detail: "Contextual tips appear near key controls while you set up and run the scoreboard. You can turn them off or reset them any time in Settings > About.",
                            systemImage: "lightbulb"
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(settingsPalette.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(settingsPalette.cardBorder)
                    )

                    HStack(spacing: 12) {
                        gettingStartedExperiencedButton
                            .frame(maxWidth: .infinity)
                        gettingStartedPrimaryButton
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(28)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(settingsPalette.shellBackground)
        }
        #if os(macOS)
        .frame(minWidth: 620, minHeight: 620)
        #endif
    }

    private func gettingStartedFeatureRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(settingsPalette.accentText)
                .frame(width: 42, height: 42)
                .background(settingsPalette.accent, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                localizedAppText(title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(settingsPalette.primaryText)

                localizedAppText(detail)
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }

    private var gettingStartedPrimaryButton: some View {
        Button {
            closeGettingStarted()
        } label: {
            Label("Get Started", systemImage: "checkmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(settingsPalette.accentText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(settingsPalette.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var gettingStartedExperiencedButton: some View {
        Button {
            skipGettingStartedAndDisableTips()
        } label: {
            Label("Skip Welcome and Turn Off Tips", systemImage: "xmark.circle")
                .font(.headline.weight(.bold))
                .foregroundStyle(settingsPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(settingsPalette.fieldBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func settingsLinkRow(
        title: String,
        subtitle: String,
        systemImage: String,
        urlString: String
    ) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(settingsPalette.accent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        localizedAppText(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(settingsPalette.primaryText)

                        localizedAppText(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(settingsPalette.secondaryText)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(settingsPalette.secondaryText)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func settingsFileManagerPanel<Toolbar: View, Content: View>(
        title: String,
        fillsHeight: Bool = true,
        @ViewBuilder toolbar: () -> Toolbar,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                localizedAppText(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(settingsPalette.secondaryText)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                ScrollView(.horizontal, showsIndicators: false) {
                    toolbar()
                }
                .frame(maxWidth: 220, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            settingsDivider()

            content()
                .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        }
        .background(settingsPalette.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(settingsPalette.cardBorder)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func settingsToolbarIconButton(
        _ title: String,
        systemImage: String,
        tint: Color? = nil,
        foreground: Color? = nil,
        isEnabled: Bool = true,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isEnabled ? (foreground ?? settingsPalette.primaryText) : settingsPalette.secondaryText)
                .frame(width: 34, height: 34)
                .background(tint ?? settingsPalette.fieldBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
    }

    private func settingsToolbarIconMenu<Content: View>(
        _ title: String,
        systemImage: String,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isEnabled ? settingsPalette.primaryText : settingsPalette.secondaryText)
                .frame(width: 34, height: 34)
                .background(settingsPalette.fieldBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
    }

    private var settingsGameFileManagerToolbar: some View {
        HStack(spacing: 8) {
            settingsToolbarIconButton("Duplicate Current Setup", systemImage: "doc.on.doc", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                createStoredGameFromDraft()
            }

            settingsToolbarIconButton("Import", systemImage: "square.and.arrow.down") {
                beginGameImport()
            }

            settingsToolbarIconButton(isSelectingGameFiles ? "Done" : "Select", systemImage: isSelectingGameFiles ? "checkmark.circle.fill" : "checkmark.circle") {
                toggleGameFileSelectionMode()
            }

            if isSelectingGameFiles {
                settingsToolbarIconButton("Select All", systemImage: "checkmark.circle.fill", isEnabled: !storedGameFiles.isEmpty) {
                    selectedGameFileIDs = Set(storedGameFiles.map(\.id))
                }

                settingsToolbarIconButton(
                    "Delete Selected",
                    systemImage: "trash",
                    tint: themePalette.destructiveTint,
                    foreground: destructiveText,
                    isEnabled: !selectedGameFileIDs.isEmpty,
                    role: .destructive
                ) {
                    deleteSelectedStoredGames()
                }
            }
        }
    }

    private var settingsSelectedGameFileToolbar: some View {
        HStack(spacing: 8) {
            settingsToolbarIconButton("Open", systemImage: "folder", isEnabled: selectedStoredGameFile != nil) {
                openSelectedStoredGame()
            }

            settingsToolbarIconButton("Rename", systemImage: "checkmark", tint: settingsPalette.accent, foreground: settingsPalette.accentText, isEnabled: canRenameSelectedGameFile) {
                renameSelectedStoredGame()
            }

            #if os(macOS)
            settingsToolbarIconMenu("Export", systemImage: "square.and.arrow.up", isEnabled: selectedStoredGameFile != nil) {
                Button {
                    exportSelectedStoredGame(destination: .file)
                } label: {
                    Label("Save to File", systemImage: "folder")
                }

                Button {
                    exportSelectedStoredGame(destination: .share)
                } label: {
                    Label("System Share", systemImage: "square.and.arrow.up")
                }
            }
            #else
            settingsToolbarIconButton("Export", systemImage: "square.and.arrow.up", isEnabled: selectedStoredGameFile != nil) {
                exportSelectedStoredGame(destination: .share)
            }
            #endif

            settingsToolbarIconButton(
                "Delete",
                systemImage: "trash",
                tint: themePalette.destructiveTint,
                foreground: destructiveText,
                isEnabled: selectedStoredGameFile != nil,
                role: .destructive
            ) {
                deleteSelectedStoredGame()
            }
        }
    }

    private func settingsGameFileManagerList(minHeight: CGFloat = 360) -> some View {
        Group {
            if storedGameFiles.isEmpty {
                settingsEmptyFileManagerMessage("No local game files yet. Create one from the current setup or import an existing file.")
            } else {
                List {
                    ForEach(storedGameFiles) { gameFile in
                        settingsGameFileManagerRow(gameFile)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                            .listRowSeparator(.hidden)
                            .listRowBackground(gameFileRowBackground(gameFile))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteStoredGame(gameFile)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    loadStoredGameFile(gameFile)
                                } label: {
                                    Label("Open", systemImage: "folder")
                                }

                                Button {
                                    selectedStoredGameFileID = gameFile.id
                                    renameGameFileNameDraft = gameFile.displayName
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                #if os(macOS)
                                Menu {
                                    Button {
                                        selectedStoredGameFileID = gameFile.id
                                        exportSelectedStoredGame(destination: .file)
                                    } label: {
                                        Label("Save to File", systemImage: "folder")
                                    }

                                    Button {
                                        selectedStoredGameFileID = gameFile.id
                                        exportSelectedStoredGame(destination: .share)
                                    } label: {
                                        Label("System Share", systemImage: "square.and.arrow.up")
                                    }
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                #else
                                Button {
                                    selectedStoredGameFileID = gameFile.id
                                    exportSelectedStoredGame(destination: .share)
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                #endif

                                Button(role: .destructive) {
                                    deleteStoredGame(gameFile)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .frame(minHeight: minHeight)
    }

    private func settingsGameFileManagerRow(_ gameFile: StoredGameFile) -> some View {
        Button {
            handleGameFileRowTap(gameFile)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: gameFileLeadingSystemImage(gameFile))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(gameFileLeadingTint(gameFile))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(gameFile.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)
                        .lineLimit(1)

                    Text(gameFile.matchupLine)
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                        .lineLimit(1)

                    Text(gameFile.detailLine)
                        .font(.caption)
                        .foregroundStyle(settingsPalette.secondaryText.opacity(0.82))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if !isSelectingGameFiles, selectedStoredGameFileID == gameFile.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(settingsPalette.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var settingsGameFileDetailPane: some View {
        SettingsGameFileDetailPane(
            selectedFile: selectedStoredGameFile,
            workingRows: settingsCurrentGameSummaryDetailRows,
            renameDraft: $renameGameFileNameDraft,
            canRename: canRenameSelectedGameFile,
            palette: settingsPalette,
            keyboardBottomInset: settingsKeyboardAvoidanceInset,
            onRename: renameSelectedStoredGame
        )
    }

    private var settingsCurrentGameSummaryDetailRows: [SettingsDetailRow] {
        var rows: [SettingsDetailRow] = [
            SettingsDetailRow(id: "workingFile", title: "Working File", value: selectedStoredGameFile?.displayName ?? localizedAppString("Auto-created")),
            SettingsDetailRow(id: "event", title: "Event", value: eventNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedAppString("Not Set") : eventNameDraft),
            SettingsDetailRow(id: "homeTeam", title: "Home Team", value: displayTeamName(homeTeamDraft)),
            SettingsDetailRow(id: "guestTeam", title: "Guest Team", value: displayTeamName(guestTeamDraft)),
            SettingsDetailRow(id: "sport", title: "Sport", value: localizedAppString(setupSport.title))
        ]

        if setupRules.supportsPeriod {
            rows.append(SettingsDetailRow(id: "period", title: setupRules.periodTitle, value: "\(setupPeriod)"))
        }
        if setupSport == .volleyball {
            rows.append(SettingsDetailRow(id: "matchFormat", title: "Match Format", value: setupVolleyballMatchFormat.title))
        }
        if setupSport == .custom, setupCustomSportConfig.isScoreEnabled, setupCustomSportConfig.isPeriodEnabled {
            rows.append(SettingsDetailRow(
                id: "periodWins",
                title: "Period Wins",
                value: localizedAppString(setupCustomSportConfig.isPeriodWinTrackingEnabled ? "Enabled" : "Disabled")
            ))
        }
        if setupSport == .custom {
            rows.append(SettingsDetailRow(
                id: "penaltyTimers",
                title: "Penalty Timers",
                value: localizedAppString(setupCustomSportConfig.isPenaltyTimerEnabled ? "Enabled" : "Disabled")
            ))
        }

        let clockValue = (setupSport == .volleyball || setupSport == .custom) && !setupUsesGameClock
            ? localizedAppString("Disabled")
            : formatClock(setupClockSeconds)
        rows.append(SettingsDetailRow(
            id: "clock",
            title: setupRules.usesChessClocks ? "Home Clock" : "Opening Clock",
            value: clockValue
        ))

        if setupRules.usesChessClocks {
            rows.append(SettingsDetailRow(id: "guestClock", title: "Guest Clock", value: formatClock(setupGuestClockSeconds)))
        }

        if setupRules.supportsShotClock {
            rows.append(SettingsDetailRow(id: "shotClock", title: setupUsesServeTimer ? "Serve Timer" : "Shot Clock", value: ScoreboardStore.formatShotClock(setupShotClockSeconds)))
        }

        rows.append(SettingsDetailRow(id: "playerTracking", title: "Player Tracking", value: localizedAppString(store.isPlayerTrackingEnabled ? "Enabled" : "Disabled")))
        rows.append(SettingsDetailRow(id: "rosterSize", title: "Roster Size", value: "\(store.rosterSizePerTeam)"))
        return rows
    }

    private var settingsLogSessionManagerToolbar: some View {
        HStack(spacing: 8) {
            settingsToolbarIconButton(isSelectingLogSessions ? "Done" : "Select", systemImage: isSelectingLogSessions ? "checkmark.circle.fill" : "checkmark.circle") {
                toggleLogSessionSelectionMode()
            }

            if isSelectingLogSessions {
                settingsToolbarIconButton("Select All", systemImage: "checkmark.circle.fill", isEnabled: !storedLogSessions.isEmpty) {
                    selectedLogSessionIDs = Set(storedLogSessions.map(\.id))
                }

                settingsToolbarIconButton(
                    "Delete Selected",
                    systemImage: "trash",
                    tint: themePalette.destructiveTint,
                    foreground: destructiveText,
                    isEnabled: !selectedLogSessionIDs.isEmpty,
                    role: .destructive
                ) {
                    deleteSelectedLogSessions()
                }
            }
        }
    }

    private var settingsLogPlaybackToolbar: some View {
        HStack(spacing: 8) {
            settingsToolbarIconMenu("Export", systemImage: "square.and.arrow.up", isEnabled: selectedStoredLogSession != nil) {
                #if os(macOS)
                Menu {
                    Button {
                        prepareLogExport(as: .json, destination: .file)
                    } label: {
                        Label("Save to File", systemImage: "folder")
                    }

                    Button {
                        prepareLogExport(as: .json, destination: .share)
                    } label: {
                        Label("System Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("JSON", systemImage: "doc")
                }

                Menu {
                    Button {
                        prepareLogExport(as: .commaSeparatedText, destination: .file)
                    } label: {
                        Label("Save to File", systemImage: "folder")
                    }

                    Button {
                        prepareLogExport(as: .commaSeparatedText, destination: .share)
                    } label: {
                        Label("System Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("CSV", systemImage: "tablecells")
                }
                #else
                Button {
                    prepareLogExport(as: .json, destination: .share)
                } label: {
                    Label("JSON", systemImage: "doc")
                }

                Button {
                    prepareLogExport(as: .commaSeparatedText, destination: .share)
                } label: {
                    Label("CSV", systemImage: "tablecells")
                }
                #endif
            }

            settingsToolbarIconButton(
                "Delete",
                systemImage: "trash",
                tint: themePalette.destructiveTint,
                foreground: destructiveText,
                isEnabled: selectedStoredLogSession != nil,
                role: .destructive
            ) {
                if let selectedStoredLogSession {
                    pendingLogDeletion = selectedStoredLogSession
                }
            }
        }
    }

    private func settingsLogSessionManagerList(minHeight: CGFloat = 360) -> some View {
        Group {
            if storedLogSessions.isEmpty {
                settingsEmptyFileManagerMessage("No log sessions yet. Start operating the scoreboard to create the first per-run log.")
            } else {
                List {
                    ForEach(storedLogSessions) { session in
                        settingsLogSessionManagerRow(session)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                            .listRowSeparator(.hidden)
                            .listRowBackground(logSessionRowBackground(session))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    pendingLogDeletion = session
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    selectedStoredLogSessionID = session.id
                                } label: {
                                    Label("Open", systemImage: "folder")
                                }

                                #if os(macOS)
                                Menu {
                                    Button {
                                        selectedStoredLogSessionID = session.id
                                        prepareLogExport(as: .json, destination: .file)
                                    } label: {
                                        Label("Save to File", systemImage: "folder")
                                    }

                                    Button {
                                        selectedStoredLogSessionID = session.id
                                        prepareLogExport(as: .json, destination: .share)
                                    } label: {
                                        Label("System Share", systemImage: "square.and.arrow.up")
                                    }
                                } label: {
                                    Label("Export JSON", systemImage: "doc")
                                }

                                Menu {
                                    Button {
                                        selectedStoredLogSessionID = session.id
                                        prepareLogExport(as: .commaSeparatedText, destination: .file)
                                    } label: {
                                        Label("Save to File", systemImage: "folder")
                                    }

                                    Button {
                                        selectedStoredLogSessionID = session.id
                                        prepareLogExport(as: .commaSeparatedText, destination: .share)
                                    } label: {
                                        Label("System Share", systemImage: "square.and.arrow.up")
                                    }
                                } label: {
                                    Label("Export CSV", systemImage: "tablecells")
                                }
                                #else
                                Button {
                                    selectedStoredLogSessionID = session.id
                                    prepareLogExport(as: .json, destination: .share)
                                } label: {
                                    Label("Export JSON", systemImage: "doc")
                                }

                                Button {
                                    selectedStoredLogSessionID = session.id
                                    prepareLogExport(as: .commaSeparatedText, destination: .share)
                                } label: {
                                    Label("Export CSV", systemImage: "tablecells")
                                }
                                #endif

                                Button(role: .destructive) {
                                    pendingLogDeletion = session
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .frame(minHeight: minHeight)
    }

    private func settingsLogSessionManagerRow(_ session: StoredLogSession) -> some View {
        Button {
            handleLogSessionRowTap(session)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: logSessionLeadingSystemImage(session))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(logSessionLeadingTint(session))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)
                        .lineLimit(1)

                    Text(session.summaryLine)
                        .font(.caption)
                        .foregroundStyle(settingsPalette.secondaryText)
                        .lineLimit(1)

                    Text(session.gameFilesLine)
                        .font(.caption)
                        .foregroundStyle(settingsPalette.secondaryText.opacity(0.82))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if !isSelectingLogSessions, selectedStoredLogSessionID == session.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(settingsPalette.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var settingsLogPlaybackDetailPane: some View {
        Group {
            if let selectedStoredLogSession {
                ScrollView {
                    VStack(spacing: 0) {
                        settingsLogPlaybackControls
                        settingsDivider()
                        settingsSummaryValueRow(title: "Session Start", value: selectedStoredLogSession.startedAt.formatted(date: .abbreviated, time: .shortened))
                        settingsDivider()
                        settingsSummaryValueRow(title: "Last Update", value: selectedStoredLogSession.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))
                        settingsDivider()
                        settingsSummaryValueRow(title: "Event Count", value: "\(selectedStoredLogSession.eventCount)")
                        settingsDivider()
                        settingsSummaryValueRow(title: "Sports", value: selectedStoredLogSession.sportsLine)
                        settingsDivider()
                        settingsSummaryValueRow(title: "Game Files", value: selectedStoredLogSession.gameFilesLine)
                        settingsDivider()
                        settingsLogPlaybackList(selectedStoredLogSession)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
            } else {
                settingsEmptyFileManagerMessage("Select a log session to inspect exported actions and captured game context.")
            }
        }
    }

    private func settingsEmptyFileManagerMessage(_ message: String) -> some View {
        localizedAppText(message)
            .font(.subheadline)
            .foregroundStyle(settingsPalette.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(18)
    }

    private var settingsLogPlaybackControls: some View {
        return HStack(spacing: 16) {
            Text("View")
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Picker("Log View", selection: $logPlaybackOrder) {
                ForEach(LogPlaybackOrder.allCases) { order in
                    localizedAppText(order.title).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func settingsTwoColumnLayout<Left: View, Right: View>(
        layout: InterfaceLayout,
        primaryColumnWidth: CGFloat? = nil,
        usesBalancedColumns: Bool = false,
        fillsHeight: Bool = false,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) -> some View {
        if layout.settingsTwoColumnUsesVerticalFlow {
            VStack(alignment: .leading, spacing: 22) {
                left()
                right()
            }
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        } else {
            let resolvedPrimaryColumnWidth = primaryColumnWidth ?? layout.settingsPrimaryColumnWidth
            HStack(alignment: .top, spacing: 22) {
                left()
                    .frame(width: usesBalancedColumns ? nil : resolvedPrimaryColumnWidth, alignment: .topLeading)
                    .frame(maxWidth: usesBalancedColumns ? .infinity : nil, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)

                right()
                    .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            localizedAppText(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(settingsPalette.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(settingsPalette.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(settingsPalette.cardBorder)
            )

            if let footer, !footer.isEmpty {
                localizedAppText(footer)
                    .font(.footnote)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func settingsTextEntryRow(
        title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        teamSide: Bool? = nil,
        focusID: String? = nil
    ) -> some View {
        let committedText = Binding(
            get: { text.wrappedValue },
            set: { newValue in
                if let teamSide {
                    synchronizeDraftTeamName(newValue, isHome: teamSide)
                } else {
                    text.wrappedValue = newValue
                }
            }
        )

        return HStack(spacing: 16) {
            localizedAppText(title)
                .font(.body)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            DeferredSettingsTextField(
                placeholder: localizedAppString(placeholder ?? title),
                text: committedText,
                focusID: focusID ?? "settings-text-entry-\(title)-\(placeholder ?? "")",
                focusedField: $focusedSettingsTextFieldID
            )
                .scoreboardUppercaseEntry()
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: 280)
        }
        .padding(.vertical, 10)
    }

    private func settingsPlainTextEntryRow(
        title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        focusID: String? = nil
    ) -> some View {
        HStack(spacing: 16) {
            localizedAppText(title)
                .font(.body)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            DeferredSettingsTextField(
                placeholder: localizedAppString(placeholder ?? title),
                text: text,
                focusID: focusID ?? "settings-plain-text-entry-\(title)-\(placeholder ?? "")",
                focusedField: $focusedSettingsTextFieldID
            )
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .scoreboardPlainTextEntry()
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: 280)
        }
        .padding(.vertical, 10)
    }

    private func settingsStepperValueRow(
        title: String,
        value: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            localizedAppText(title)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(settingsPalette.secondaryText)

            Stepper("", onIncrement: increment, onDecrement: decrement)
                .labelsHidden()
        }
        .padding(.vertical, 10)
    }

    private func settingsToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            localizedAppText(title)
                .foregroundStyle(settingsPalette.primaryText)
        }
        .toggleStyle(.switch)
        .padding(.vertical, 10)
    }

    private func settingsSegmentRow(
        title: String,
        options: [(String, Int)],
        selection: Binding<Int>
    ) -> some View {
        HStack(spacing: 16) {
            localizedAppText(title)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Picker(localizedAppString(title), selection: selection) {
                ForEach(options, id: \.1) { option in
                    localizedAppText(option.0).tag(option.1)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
        .padding(.vertical, 10)
    }

    private func settingsPresetButtonGrid(
        title: String,
        options: [(String, Int)],
        selection: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                localizedAppText(title)
                    .foregroundStyle(settingsPalette.primaryText)

                Spacer(minLength: 0)

                Text(formatClock(selection.wrappedValue))
                    .font(.subheadline.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(settingsPalette.secondaryText)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(options, id: \.1) { option in
                    let isSelected = selection.wrappedValue == option.1
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            selection.wrappedValue = option.1
                        }
                    } label: {
                        localizedAppText(option.0)
                            .font(.subheadline.weight(.black))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? settingsPalette.accentText : settingsPalette.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                isSelected ? settingsPalette.accent : settingsPalette.fieldBackground,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func settingsPickerRow<Option: Hashable>(
        title: String,
        selection: Binding<Option>,
        options: [Option],
        label: @escaping (Option) -> String
    ) -> some View {
        HStack(spacing: 16) {
            localizedAppText(title)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Picker(localizedAppString(title), selection: selection) {
                ForEach(options, id: \.self) { option in
                    localizedAppText(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 10)
    }

    private func openDebateDesigner() {
        if setupSport != .debate {
            setupSport = .debate
        }
        if setupDebatePresetID == DebatePreset.customID {
            normalizeSetupCustomDebatePreset()
        } else {
            applyDebateDesignerTemplate(setupDebatePreset)
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            isDebateDesignerVisible = true
        }
    }

    private func applyDebateDesignerTemplate(_ template: DebatePreset) {
        var customPreset = template
        customPreset.id = DebatePreset.customID
        setupCustomDebatePreset = customPreset
        setupDebatePresetID = DebatePreset.customID
        setupDebateHomeSideLabel = customPreset.homeSideLabel
        setupDebateGuestSideLabel = customPreset.guestSideLabel
        setupDebateScoreTrackingEnabled = customPreset.defaultScoreTrackingEnabled
        setupDebatePlayerTrackingEnabled = customPreset.defaultPlayerTrackingEnabled
        setupDebatePlayerFoulsEnabled = customPreset.defaultPlayerFoulsEnabled
        setupDebatePlayerCardsEnabled = customPreset.defaultPlayerCardsEnabled
        setupDebatePrepTimeEnabled = customPreset.isPrepTimeEnabled
        if let firstSegment = customPreset.segments.first {
            setupClockSeconds = firstSegment.durationSeconds
            setupGuestClockSeconds = firstSegment.durationSeconds
        }
    }

    private var setupDebateOpeningSegmentSeconds: Int {
        max(0, setupDebatePreset.segments.first?.durationSeconds ?? 0)
    }

    private func debateTotalDurationSeconds(_ preset: DebatePreset) -> Int {
        preset.segments.reduce(0) { $0 + max(0, $1.durationSeconds) }
    }

    private func debateTimerModeTitle(_ mode: DebateTimerMode) -> String {
        switch mode {
        case .masterClock:
            return "Master"
        case .dualClock:
            return "Dual"
        case .none:
            return "None"
        }
    }

    @ViewBuilder
    private func debateTimerModeSetupGuidance(_ mode: DebateTimerMode) -> some View {
        switch mode {
        case .none:
            settingsOptionTip("No Timer segments are checkpoints in the round flow, such as judge instructions, disclosure, prep reminders, or transitions. They do not run a countdown on the live board, so operators will only move to the previous or next segment unless prep time or score/player tools are enabled.", systemImage: "pause.circle")
        case .dualClock:
            settingsOptionTip("Dual Clock segments give each side its own countdown for cross-examination, flex prep, or side-controlled speaking time. Set the starting side and decide whether operators can switch the active side during the segment before saving the custom debate format.", systemImage: "person.2")
        case .masterClock:
            EmptyView()
        }
    }

    private func debateSpeakingSideTitle(_ side: TeamSide?) -> String {
        guard let side else {
            return "Not Set"
        }

        return debateSpeakingSideTitle(side)
    }

    private func debateSpeakingSideTitle(_ side: TeamSide) -> String {
        side == .home ? setupDebateHomeSideLabel : setupDebateGuestSideLabel
    }

    private func debateSpeakingSideSystemImage(_ side: TeamSide) -> String {
        side == .home ? "arrow.left.circle.fill" : "arrow.right.circle.fill"
    }

    @ViewBuilder
    private func customDebateSegmentEditor(segment: DebateSegment, index: Int) -> some View {
        let segmentID = segment.id
        let currentSegment = customDebateSegment(segmentID) ?? segment
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)")
                    .font(.headline.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(settingsPalette.accentText)
                    .frame(width: 38, height: 38)
                    .background(settingsPalette.accent, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    DeferredSettingsTextField(
                        placeholder: localizedAppString("Segment Title"),
                        text: Binding(
                            get: { customDebateSegment(segmentID)?.title ?? segment.title },
                            set: { newValue in
                                updateCustomDebateSegment(segmentID) { $0.title = newValue }
                            }
                        ),
                        focusID: "debate-segment-title-\(segmentID)",
                        focusedField: $focusedSettingsTextFieldID
                    )
                    .font(.headline.weight(.black))
                    .autocorrectionDisabled()
                    .scoreboardPlainTextEntry()
                    .foregroundStyle(settingsPalette.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(settingsPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 8) {
                        debateSegmentMetaPill(formatClock(currentSegment.durationSeconds), systemImage: "timer")
                        debateSegmentMetaPill(debateTimerModeTitle(currentSegment.timerMode), systemImage: currentSegment.timerMode == .dualClock ? "person.2" : "clock")
                        if let speakingSide = currentSegment.speakingSide {
                            debateSegmentMetaPill(debateSpeakingSideTitle(speakingSide), systemImage: debateSpeakingSideSystemImage(speakingSide))
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if index > 0 {
                        settingsCompactIconButton("Up", systemImage: "chevron.up", tint: settingsPalette.cardBackground, foreground: settingsPalette.primaryText) {
                            moveCustomDebateSegment(from: index, to: index - 1)
                        }
                    }

                    if index < setupCustomDebatePreset.segments.count - 1 {
                        settingsCompactIconButton("Down", systemImage: "chevron.down", tint: settingsPalette.cardBackground, foreground: settingsPalette.primaryText) {
                            moveCustomDebateSegment(from: index, to: index + 1)
                        }
                    }

                    if setupCustomDebatePreset.segments.count > 1 {
                        settingsCompactIconButton("Delete", systemImage: "trash", tint: themePalette.destructiveTint, foreground: destructiveText) {
                            removeCustomDebateSegment(segment.id)
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                settingsPickerRow(
                    title: "Timer",
                    selection: Binding(
                        get: { customDebateSegment(segmentID)?.timerMode ?? segment.timerMode },
                        set: { newValue in
                            updateCustomDebateSegment(segmentID) {
                                $0.timerMode = newValue
                                if newValue != .dualClock {
                                    $0.startingSide = nil
                                    $0.allowsSideSwitching = false
                                } else if $0.startingSide == nil {
                                    $0.startingSide = .home
                                }
                            }
                        }
                    ),
                    options: DebateTimerMode.allCases
                ) { mode in
                    debateTimerModeTitle(mode)
                }

                if currentSegment.timerMode == .none || currentSegment.timerMode == .dualClock {
                    settingsDivider()
                    debateTimerModeSetupGuidance(currentSegment.timerMode)
                }

                settingsDivider()

                settingsPickerRow(
                    title: "Speaking Side",
                    selection: Binding<TeamSide?>(
                        get: { customDebateSegment(segmentID)?.speakingSide ?? segment.speakingSide },
                        set: { newValue in
                            updateCustomDebateSegment(segmentID) { $0.speakingSide = newValue }
                        }
                    ),
                    options: [TeamSide?.none, .some(.home), .some(.guest)]
                ) { side in
                    debateSpeakingSideTitle(side)
                }

                settingsDivider()

                settingsStepperValueRow(
                    title: "Duration",
                    value: formatClock(currentSegment.durationSeconds),
                    decrement: {
                        updateCustomDebateSegment(segmentID) { $0.durationSeconds = max(0, $0.durationSeconds - 15) }
                    },
                    increment: {
                        updateCustomDebateSegment(segmentID) { $0.durationSeconds = min(ScoreboardStore.maxDebateSegmentSeconds, $0.durationSeconds + 15) }
                    }
                )

                settingsDivider()

                settingsToggleRow(
                    title: "Start Paused",
                    isOn: Binding(
                        get: { customDebateSegment(segmentID)?.startsPaused ?? segment.startsPaused },
                        set: { newValue in
                            updateCustomDebateSegment(segmentID) { $0.startsPaused = newValue }
                        }
                    )
                )

                settingsDivider()

                settingsToggleRow(
                    title: "Auto Pause At End",
                    isOn: Binding(
                        get: { customDebateSegment(segmentID)?.autoPauseAtEnd ?? segment.autoPauseAtEnd },
                        set: { newValue in
                            updateCustomDebateSegment(segmentID) { $0.autoPauseAtEnd = newValue }
                        }
                    )
                )

                if currentSegment.timerMode == .dualClock {
                    settingsDivider()

                    settingsPickerRow(
                        title: "Starting Side",
                        selection: Binding(
                            get: { customDebateSegment(segmentID)?.startingSide ?? segment.startingSide ?? .home },
                            set: { newValue in
                                updateCustomDebateSegment(segmentID) { $0.startingSide = newValue }
                            }
                        ),
                        options: [TeamSide.home, TeamSide.guest]
                    ) { side in
                        side == .home ? setupDebateHomeSideLabel : setupDebateGuestSideLabel
                    }

                    settingsDivider()

                    settingsToggleRow(
                        title: "Allow Side Switching",
                        isOn: Binding(
                            get: { customDebateSegment(segmentID)?.allowsSideSwitching ?? segment.allowsSideSwitching },
                            set: { newValue in
                                updateCustomDebateSegment(segmentID) { $0.allowsSideSwitching = newValue }
                            }
                        )
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(settingsPalette.cardBorder, lineWidth: 1)
        )
    }

    private func debateSegmentMetaPill(_ title: String, systemImage: String) -> some View {
        Label(localizedAppString(title), systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(settingsPalette.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(settingsPalette.cardBackground, in: Capsule())
    }

    private func addCustomDebateSegment() {
        var preset = setupCustomDebatePreset
        preset.segments.append(
            DebateSegment(
                id: UUID().uuidString,
                title: "New Segment",
                timerMode: .masterClock,
                durationSeconds: 3 * 60,
                startingSide: nil,
                allowsSideSwitching: false,
                autoPauseAtEnd: true,
                startsPaused: true
            )
        )
        setupCustomDebatePreset = preset
    }

    private func removeCustomDebateSegment(_ id: String) {
        var preset = setupCustomDebatePreset
        preset.segments.removeAll { $0.id == id }
        if preset.segments.isEmpty {
            preset.segments = DebatePreset.customDefault.segments
        }
        setupCustomDebatePreset = preset
    }

    private func moveCustomDebateSegment(from sourceIndex: Int, to targetIndex: Int) {
        guard setupCustomDebatePreset.segments.indices.contains(sourceIndex),
              setupCustomDebatePreset.segments.indices.contains(targetIndex) else {
            return
        }

        var preset = setupCustomDebatePreset
        let segment = preset.segments.remove(at: sourceIndex)
        preset.segments.insert(segment, at: targetIndex)
        setupCustomDebatePreset = preset
    }

    private func updateCustomDebateSegment(_ id: String, mutate: (inout DebateSegment) -> Void) {
        guard let index = setupCustomDebatePreset.segments.firstIndex(where: { $0.id == id }) else {
            return
        }

        var preset = setupCustomDebatePreset
        mutate(&preset.segments[index])
        setupCustomDebatePreset = preset
    }

    private func customDebateSegment(_ id: String) -> DebateSegment? {
        setupCustomDebatePreset.segments.first { $0.id == id }
    }

    private func settingsRosterEditor(side: TeamSide, layout: InterfaceLayout) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(store.trackedPlayers(for: side).enumerated()), id: \.element.id) { index, player in
                settingsTrackedPlayerRow(player, side: side, layout: layout)

                if index < store.trackedPlayers(for: side).count - 1 {
                    settingsDivider()
                }
            }
        }
    }

    private func settingsTrackedPlayerRow(_ player: TrackedPlayer, side: TeamSide, layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("#\(player.number.isEmpty ? "--" : player.number)")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(settingsPalette.primaryText)

                Spacer(minLength: 0)

                if store.supportsCards || store.supportsFouls {
                    HStack(spacing: 8) {
                        if store.supportsCards {
                            Text(localizedAppString(player.cardStatus.title).uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(cardStatusColor(player.cardStatus))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(settingsPalette.fieldBackground, in: Capsule())
                        }
                        if store.supportsFouls {
                            Text("F \(player.foulCount)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(settingsPalette.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(settingsPalette.fieldBackground, in: Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                DeferredSettingsTextField(
                    placeholder: "No.",
                    text: Binding(
                        get: { player.number },
                        set: { store.updateTrackedPlayerNumber($0, for: side, playerID: player.id) }
                    ),
                    focusID: "player-number-\(side.rawValue)-\(player.id.uuidString)",
                    focusedField: $focusedSettingsTextFieldID
                )
                .multilineTextAlignment(.center)
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(width: 84)

                DeferredSettingsTextField(
                    placeholder: "Player Name",
                    text: Binding(
                        get: { player.name },
                        set: { store.updateTrackedPlayerName($0, for: side, playerID: player.id) }
                    ),
                    focusID: "player-name-\(side.rawValue)-\(player.id.uuidString)",
                    focusedField: $focusedSettingsTextFieldID
                )
                .scoreboardUppercaseEntry()
                .autocorrectionDisabled()
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Toggle(isOn: Binding(
                get: { player.isInActiveLineup },
                set: { store.setPlayerActiveLineup($0, for: side, playerID: player.id) }
            )) {
                Text("Show In Active Lineup")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(settingsPalette.secondaryText)
            }
            .toggleStyle(.switch)

            if store.supportsCards {
                HStack(spacing: 10) {
                    smallSettingsActionButton("Yellow", tint: player.cardStatus == .yellow ? .yellow.opacity(0.85) : .yellow.opacity(0.42), foreground: .black) {
                        store.setCardStatus(toggledCardStatus(.yellow, current: player.cardStatus), for: side, playerID: player.id)
                    }
                    smallSettingsActionButton("Red", tint: player.cardStatus == .red ? .red.opacity(0.9) : .red.opacity(0.42), foreground: .white) {
                        store.setCardStatus(toggledCardStatus(.red, current: player.cardStatus), for: side, playerID: player.id)
                    }
                }
            }

            if store.supportsFouls {
                HStack(spacing: 10) {
                    smallSettingsActionButton("F -", tint: settingsPalette.fieldBackground, foreground: settingsPalette.primaryText) {
                        store.adjustFoulCount(for: side, playerID: player.id, by: -1)
                    }
                    smallSettingsActionButton("F +", tint: side == .home ? homeTint : guestTint, foreground: teamAccentText(for: side)) {
                        store.adjustFoulCount(for: side, playerID: player.id, by: 1)
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func settingsButtonRow(
        title: String,
        buttonTitle: String,
        tint: Color,
        foreground: Color = .white,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            localizedAppText(title)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Button(action: action) {
                localizedAppText(buttonTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(foreground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(tint, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.42)
        }
        .padding(.vertical, 10)
    }

    private func settingsIconButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        foreground: Color = .white,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(localizedAppString(title), systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }

    private func settingsSummaryValueRow(title: String, value: String) -> some View {
        HStack(spacing: 16) {
            localizedAppText(title)
                .foregroundStyle(settingsPalette.primaryText)
            Spacer(minLength: 0)
            Text(localizedAppString(value))
                .foregroundStyle(settingsPalette.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private func smallSettingsActionButton(
        _ title: String,
        tint: Color,
        foreground: Color,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            localizedAppText(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(tint, in: Capsule())
        }
        .opacity(isEnabled ? 1 : 0.42)
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }

    private func settingsLogPlaybackList(_ session: StoredLogSession) -> some View {
        VStack(spacing: 10) {
            ForEach(orderedLogEntries(for: session)) { entry in
                settingsLogEntryRow(entry)
            }
        }
        .padding(.vertical, 12)
    }

    private func settingsLogEntryRow(_ entry: ScoreboardLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                localizedAppText(entry.operation.kind.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(settingsPalette.primaryText)

                Spacer(minLength: 0)

                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(settingsPalette.secondaryText)
            }

            Text(localizedAppString(entry.operation.summary))
                .font(.subheadline)
                .foregroundStyle(settingsPalette.primaryText)

            Text(logEntryContextLine(entry))
                .font(.caption)
                .foregroundStyle(settingsPalette.secondaryText)

            if let playerLine = logEntryPlayerLine(entry) {
                Text(playerLine)
                    .font(.caption)
                    .foregroundStyle(settingsPalette.secondaryText)
            }

            if let fileLine = logEntryFileLine(entry) {
                Text(fileLine)
                    .font(.caption)
                    .foregroundStyle(settingsPalette.secondaryText)
            }

            Text(localizedAppFormat("Outcome: %@", entry.outcome.title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.outcome == .applied ? settingsPalette.accent : settingsPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func themeSelectionRow(_ theme: ScoreboardTheme) -> some View {
        let palette = theme.palette
        let isSelected = store.theme == theme

        return Button {
            store.theme = theme
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: theme.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(settingsPalette.accent)

                        localizedAppText(theme.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(settingsPalette.primaryText)
                    }

                    localizedAppText(theme.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                }

                Spacer(minLength: 0)

                themePalettePreview(for: palette)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? settingsPalette.accent : settingsPalette.secondaryText)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func externalBackgroundModeRow(_ mode: ExternalDisplayBackgroundMode) -> some View {
        let isSelected = store.externalDisplayBackgroundMode == mode

        return Button {
            if mode.usesSelectedBackgroundPhoto, store.externalDisplayBackgroundImage == nil {
                pendingExternalBackgroundModeAfterImageImport = mode
                beginExternalBackgroundImageImport()
                #if os(iOS)
                showsExternalBackgroundPhotoPicker = true
                #endif
            } else {
                store.externalDisplayBackgroundMode = mode
                if mode.usesSelectedBackgroundPhoto {
                    isExternalBackgroundImageEditorVisible = true
                }
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    localizedAppText(mode.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)

                    localizedAppText(mode.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    externalBackgroundPreview(mode)
                        .frame(width: 52, height: 28)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? settingsPalette.accent : settingsPalette.secondaryText)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func externalBackgroundImageControls() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                externalBackgroundImagePreview()
                    .frame(width: 96, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    localizedAppText("Background Photo")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)

                    Text(externalBackgroundImageDetail)
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    #if os(iOS)
                    settingsCompactIconButton("Choose", systemImage: "photo", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                        chooseExternalBackgroundImage()
                    }
                    #else
                    settingsCompactIconButton("Choose", systemImage: "photo", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                        chooseExternalBackgroundImage()
                    }
                    #endif

                    if store.externalDisplayBackgroundImage != nil {
                        settingsCompactIconButton(
                            "Edit",
                            systemImage: "slider.horizontal.3",
                            tint: settingsPalette.fieldBackground,
                            foreground: settingsPalette.primaryText
                        ) {
                            showExternalBackgroundImageEditor()
                        }

                        settingsCompactIconButton("Remove", systemImage: "trash", tint: themePalette.destructiveTint, foreground: destructiveText) {
                            removeExternalBackgroundImage()
                        }
                    }
                }
                .zIndex(2)
            }
        }
        .padding(.vertical, 12)
    }

    private func chooseExternalBackgroundImage() {
        pendingExternalBackgroundModeAfterImageImport = store.externalDisplayBackgroundMode.usesSelectedBackgroundPhoto ? store.externalDisplayBackgroundMode : nil
        beginExternalBackgroundImageImport()
        #if os(iOS)
        showsExternalBackgroundPhotoPicker = true
        #endif
    }

    private func showExternalBackgroundImageEditor() {
        guard store.externalDisplayBackgroundImage != nil else {
            isExternalBackgroundImageEditorVisible = false
            return
        }

        isExternalBackgroundImageEditorVisible = true
    }

    private func removeExternalBackgroundImage() {
        pendingExternalBackgroundModeAfterImageImport = nil
        store.clearExternalDisplayBackgroundImage()
        isExternalBackgroundImageEditorVisible = false
        autosaveSelectedGameFile(refreshSelection: true)
    }

    private func animatedLogoBackgroundControls() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsPickerRow(
                title: "Animation Style",
                selection: Binding(
                    get: { store.externalDisplayAnimatedLogoStyle },
                    set: { store.externalDisplayAnimatedLogoStyle = $0 }
                ),
                options: ExternalDisplayAnimatedLogoStyle.allCases
            ) { option in
                option.title
            }

            localizedAppText(store.externalDisplayAnimatedLogoStyle.subtitle)
                .font(.footnote)
                .foregroundStyle(settingsPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            settingsDivider()
            settingsPickerRow(
                title: "Background Color",
                selection: Binding(
                    get: { store.externalDisplayAnimatedLogoBackgroundColor },
                    set: { store.externalDisplayAnimatedLogoBackgroundColor = $0 }
                ),
                options: ExternalDisplayAnimatedLogoBackgroundColor.allCases
            ) { option in
                option.title
            }

            settingsDivider()
            settingsStepperValueRow(
                title: "Animation Speed",
                value: "\(store.externalDisplayAnimatedLogoSpeed) px/s",
                decrement: { store.setExternalDisplayAnimatedLogoSpeed(store.externalDisplayAnimatedLogoSpeed - 6) },
                increment: { store.setExternalDisplayAnimatedLogoSpeed(store.externalDisplayAnimatedLogoSpeed + 6) }
            )
            settingsDivider()
            settingsStepperValueRow(
                title: "Logo Size",
                value: "\(store.externalDisplayAnimatedLogoSize) px",
                decrement: { store.setExternalDisplayAnimatedLogoSize(store.externalDisplayAnimatedLogoSize - 8) },
                increment: { store.setExternalDisplayAnimatedLogoSize(store.externalDisplayAnimatedLogoSize + 8) }
            )
            settingsDivider()
            animatedLogoOpacitySlider()
        }
        .padding(.vertical, 4)
    }

    private func animatedLogoOpacitySlider() -> some View {
        HStack(spacing: 12) {
            localizedAppText("Logo Opacity")
                .foregroundStyle(settingsPalette.primaryText)

            Slider(
                value: Binding(
                    get: { store.externalDisplayAnimatedLogoOpacity },
                    set: { store.setExternalDisplayAnimatedLogoOpacity($0) }
                ),
                in: ScoreboardStore.minAnimatedLogoOpacity...ScoreboardStore.maxAnimatedLogoOpacity
            )
            .frame(maxWidth: 220)

            Text("\(Int((store.externalDisplayAnimatedLogoOpacity * 100).rounded()))%")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(settingsPalette.secondaryText)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }

    private var externalBackgroundImageDetail: String {
        guard let image = store.externalDisplayBackgroundImage else {
            return localizedAppString("Choose a photo to enable Photo or Animated Logo mode.")
        }

        return "\(image.displayName) · \(image.pixelWidth)x\(image.pixelHeight) · \(ByteCountFormatter.string(fromByteCount: Int64(image.byteCount), countStyle: .file))"
    }

    @ViewBuilder
    private func externalBackgroundImagePreview() -> some View {
        if let image = store.externalDisplayBackgroundImage {
            ExternalDisplayBackgroundImageView(image: image)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(settingsPalette.fieldBackground)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(settingsPalette.secondaryText)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        }
    }

    private func externalBackgroundImageEditorPage() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 12) {
                settingsCompactIconButton("Back", systemImage: "chevron.left", tint: settingsPalette.fieldBackground, foreground: settingsPalette.primaryText) {
                    isExternalBackgroundImageEditorVisible = false
                }

                VStack(alignment: .leading, spacing: 4) {
                    localizedAppText("Background Photo")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(settingsPalette.primaryText)

                    Text(externalBackgroundImageDetail)
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if store.externalDisplayBackgroundImage == nil {
                settingsSection(title: "Background Photo", footer: "Choose a photo before editing placement.") {
                    HStack(spacing: 14) {
                        externalBackgroundImagePreview()
                            .frame(width: 96, height: 54)

                        localizedAppText("No background photo selected")
                            .foregroundStyle(settingsPalette.secondaryText)

                        Spacer(minLength: 0)

                        settingsCompactIconButton("Choose", systemImage: "photo", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                            chooseExternalBackgroundImage()
                        }
                    }
                    .padding(.vertical, 12)
                }
            } else {
                settingsSection(title: "Edit Background", footer: "Adjust the selected photo placement on the public display.") {
                    externalBackgroundImageEditor()
                }
            }
        }
    }

    private func externalBackgroundImageEditor() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image = store.externalDisplayBackgroundImage {
                ExternalDisplayBackgroundImageView(image: image)
                    .aspectRatio(ScoreboardFaceView.preferredAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(settingsPalette.cardBorder, lineWidth: 1)
                    )
            }

            externalBackgroundPlacementSlider(
                title: "Scale",
                value: Binding(
                    get: { store.externalDisplayBackgroundImage?.scale ?? 1 },
                    set: {
                        store.updateExternalDisplayBackgroundPlacement(
                            scale: $0,
                            offsetX: store.externalDisplayBackgroundImage?.offsetX ?? 0,
                            offsetY: store.externalDisplayBackgroundImage?.offsetY ?? 0
                        )
                    }
                ),
                range: ExternalDisplayBackgroundImage.minScale...ExternalDisplayBackgroundImage.maxScale
            )

            externalBackgroundPlacementSlider(
                title: "Horizontal",
                value: Binding(
                    get: { store.externalDisplayBackgroundImage?.offsetX ?? 0 },
                    set: {
                        store.updateExternalDisplayBackgroundPlacement(
                            scale: store.externalDisplayBackgroundImage?.scale ?? 1,
                            offsetX: $0,
                            offsetY: store.externalDisplayBackgroundImage?.offsetY ?? 0
                        )
                    }
                ),
                range: ExternalDisplayBackgroundImage.minOffset...ExternalDisplayBackgroundImage.maxOffset
            )

            externalBackgroundPlacementSlider(
                title: "Vertical",
                value: Binding(
                    get: { store.externalDisplayBackgroundImage?.offsetY ?? 0 },
                    set: {
                        store.updateExternalDisplayBackgroundPlacement(
                            scale: store.externalDisplayBackgroundImage?.scale ?? 1,
                            offsetX: store.externalDisplayBackgroundImage?.offsetX ?? 0,
                            offsetY: $0
                        )
                    }
                ),
                range: ExternalDisplayBackgroundImage.minOffset...ExternalDisplayBackgroundImage.maxOffset
            )

            settingsCompactIconButton("Center", systemImage: "scope", tint: settingsPalette.fieldBackground, foreground: settingsPalette.primaryText) {
                store.updateExternalDisplayBackgroundPlacement(scale: 1, offsetX: 0, offsetY: 0)
            }
            .frame(maxWidth: 150, alignment: .leading)
        }
        .padding(12)
        .background(settingsPalette.fieldBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .zIndex(0)
    }

    private func externalBackgroundPlacementSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            localizedAppText(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(settingsPalette.secondaryText)
                .frame(width: 76, alignment: .leading)

            Slider(value: value, in: range)

            Text(String(format: "%.2f", value.wrappedValue))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(settingsPalette.secondaryText)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func teamLogoSettingsRow(for side: TeamSide) -> some View {
        let logo = store.teamLogoImage(for: side)
        let title = side == .home ? "Home Logo" : "Guest Logo"

        return HStack(alignment: .center, spacing: 14) {
            teamLogoSettingsPreview(for: side)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                localizedAppText(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(settingsPalette.primaryText)

                Text(logo.map { "\($0.displayName) · \($0.pixelWidth)x\($0.pixelHeight)" } ?? localizedAppString("Optional team image for public and remote displays."))
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                #if os(iOS)
                if side == .home {
                    settingsCompactIconButton("Choose", systemImage: "photo.badge.plus", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                        showsHomeLogoPhotoPicker = true
                    }
                } else {
                    settingsCompactIconButton("Choose", systemImage: "photo.badge.plus", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                        showsGuestLogoPhotoPicker = true
                    }
                }
                #else
                settingsCompactIconButton("Choose", systemImage: "photo.badge.plus", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                    beginTeamLogoImageImport(for: side)
                }
                #endif

                if logo != nil {
                    settingsCompactIconButton("Remove", systemImage: "trash", tint: themePalette.destructiveTint, foreground: destructiveText) {
                        store.clearTeamLogoImage(for: side)
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func eventLogoSettingsRow() -> some View {
        let logo = store.eventLogoImage

        return HStack(alignment: .center, spacing: 14) {
            eventLogoSettingsPreview()
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                localizedAppText("Event Logo")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(settingsPalette.primaryText)

                Text(logo.map { "\($0.displayName) · \($0.pixelWidth)x\($0.pixelHeight)" } ?? localizedAppString("Optional event image for Event Logo display mode."))
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                #if os(iOS)
                settingsCompactIconButton("Choose", systemImage: "photo.badge.plus", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                    showsEventLogoPhotoPicker = true
                }
                #else
                settingsCompactIconButton("Choose", systemImage: "photo.badge.plus", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                    beginEventLogoImageImport()
                }
                #endif

                if logo != nil {
                    settingsCompactIconButton("Remove", systemImage: "trash", tint: themePalette.destructiveTint, foreground: destructiveText) {
                        store.clearEventLogoImage()
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func teamLogoSettingsPreview(for side: TeamSide) -> some View {
        if let logo = store.teamLogoImage(for: side) {
            TeamLogoImageView(data: logo.data, cornerRadius: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(settingsPalette.fieldBackground)
                .overlay(
                    Image(systemName: side == .home ? "h.circle" : "g.circle")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(side == .home ? homeTint : guestTint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func eventLogoSettingsPreview() -> some View {
        if let logo = store.eventLogoImage {
            TeamLogoImageView(data: logo.data, cornerRadius: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(settingsPalette.fieldBackground)
                .overlay(
                    Image(systemName: "seal")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(settingsPalette.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        }
    }

    private func settingsCompactIconButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        foreground: Color,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsCompactIconLabel(title, systemImage: systemImage, tint: tint, foreground: foreground)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
    }

    private func settingsCompactIconLabel(_ title: String, systemImage: String, tint: Color, foreground: Color) -> some View {
        Label(localizedAppString(title), systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(tint, in: Capsule())
    }

    private func themeSwatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(settingsPalette.cardBorder, lineWidth: 1))
    }

    private func themePalettePreview(for palette: ThemePalette) -> some View {
        ZStack {
            externalBackgroundPreview(store.externalDisplayBackgroundMode, palette: palette)

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.boardPanelBackground)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.boardClockPanelBackground)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.boardPanelBackground)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            HStack(spacing: 10) {
                themeSwatch(palette.homeAccent)
                themeSwatch(palette.guestAccent)
                themeSwatch(palette.settingsAccent)
            }
            .padding(.top, 30)
        }
        .frame(width: 88, height: 52)
    }

    @ViewBuilder
    private func externalBackgroundPreview(_ mode: ExternalDisplayBackgroundMode) -> some View {
        externalBackgroundPreview(mode, palette: themePalette)
    }

    @ViewBuilder
    private func externalBackgroundPreview(_ mode: ExternalDisplayBackgroundMode, palette: ThemePalette) -> some View {
        let renderedMode = mode.resolvedForRendering

        if renderedMode == .blurred {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [palette.homeAccent.opacity(0.65), palette.guestAccent.opacity(0.45), palette.externalDisplayBackground], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        } else if renderedMode == .clear {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.homeAccent, palette.guestAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        } else if renderedMode == .clearUnderBoard {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.homeAccent, palette.guestAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        } else if renderedMode == .smartScoreboard {
            SmartScoreboardBackgroundView()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        } else if renderedMode == .image {
            if let image = store.externalDisplayBackgroundImage {
                ExternalDisplayBackgroundImageView(image: image)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(settingsPalette.cardBorder, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(settingsPalette.fieldBackground)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(settingsPalette.secondaryText)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(settingsPalette.cardBorder, lineWidth: 1)
                    )
            }
        } else if renderedMode == .animatedLogo {
            ExternalDisplayAnimatedLogoBackgroundView(
                data: store.externalDisplayBackgroundImage?.data,
                style: store.externalDisplayAnimatedLogoStyle,
                backgroundColor: store.externalDisplayAnimatedLogoBackgroundColor,
                speed: store.externalDisplayAnimatedLogoSpeed,
                logoSize: store.externalDisplayAnimatedLogoSize,
                logoOpacity: store.externalDisplayAnimatedLogoOpacity,
                palette: palette,
                animates: false
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(settingsPalette.cardBorder, lineWidth: 1)
            )
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        }
    }

    private func settingsDivider() -> some View {
        Divider()
            .overlay(settingsPalette.divider)
    }

    private func synchronizeDraftTeamName(_ value: String, isHome: Bool) {
        let normalizedValue = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if isHome {
            if homeTeamDraft != normalizedValue {
                homeTeamDraft = normalizedValue
            }
        } else if guestTeamDraft != normalizedValue {
            guestTeamDraft = normalizedValue
        }
    }

    private func dashboard(layout: InterfaceLayout) -> some View {
        dashboardContent(layout: layout)
    }

    private func dashboardContent(layout: InterfaceLayout) -> some View {
        GeometryReader { proxy in
            let availableHeight = max(proxy.size.height - (layout.outerPadding * 2), 0)
            let expandedHeaderHeight = dashboardHeaderReservedHeight(layout: layout)
            let headerHeight = isDashboardHeaderHidden ? CGFloat(0) : expandedHeaderHeight
            let headerSpacing = isDashboardHeaderHidden ? CGFloat(0) : layout.sectionSpacing
            let contentHeight = max(availableHeight - headerHeight - headerSpacing, 0)

            ZStack(alignment: .topTrailing) {
                VStack(spacing: headerSpacing) {
                    if !isDashboardHeaderHidden {
                        dashboardHeader(layout: layout)
                            .frame(height: expandedHeaderHeight)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    controlPane(layout: layout)
                        .frame(height: contentHeight)
                }
                .padding(layout.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if isDashboardHeaderHidden {
                    showDashboardHeaderButton(layout: layout)
                        .padding(layout.outerPadding)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .onAppear {
                refreshDashboardTipGroup()
            }
            .onChange(of: dashboardTourSignature) { _, _ in
                refreshDashboardTipGroup()
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isDashboardHeaderHidden)
        }
    }

    private func dashboardHeaderReservedHeight(layout: InterfaceLayout) -> CGFloat {
        var reservedHeight = layout.dashboardHeaderHeight

        #if os(iOS)
        if layout.headerUsesVerticalFlow {
            reservedHeight += 12

            if store.isCompanionVisible {
                reservedHeight += layout.headerActionRowStride
            }
        }
        #endif

        return reservedHeight
    }

    private func dashboardHeader(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.headerBlockSpacing) {
            if layout.headerUsesVerticalFlow {
                VStack(alignment: .leading, spacing: layout.headerBlockSpacing) {
                    headerTitleBlock(layout: layout)
                    verticalHeaderControls(layout: layout)
                }
            } else {
                HStack(spacing: layout.headerInlineSpacing) {
                    headerTitleBlock(layout: layout)
                    Spacer(minLength: 0)
                    headerStatusBadge(layout: layout)
                    headerActionButtons(layout: layout)
                        .frame(maxWidth: layout.headerActionWidth)
                }
            }
        }
        .padding(.horizontal, layout.headerHorizontalPadding)
        .padding(.vertical, layout.headerVerticalPadding)
        .background(themePalette.dashboardCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder)
        )
        .overlay(alignment: .topTrailing) {
            if isIPhoneInterface && !layout.headerUsesVerticalFlow {
                hideDashboardHeaderButton(layout: layout)
                    .padding(.top, layout.headerVerticalPadding)
                    .padding(.trailing, layout.headerHorizontalPadding)
            }
        }
        .scoreboardPopoverTip(dashboardHeaderTip(layout: layout), isEnabled: arePopoverTipsEnabled, arrowEdge: .bottom)
    }

    private func dashboardHeaderTip(layout: InterfaceLayout) -> (any Tip)? {
        if shouldShowIPhonePortraitLandscapeTip(layout: layout) {
            return ScoreboardTips.iPhoneLandscape
        }
        return dashboardCurrentTourTip(matching: ScoreboardTips.liveBoard)
    }

    private func shouldShowIPhonePortraitLandscapeTip(layout: InterfaceLayout) -> Bool {
        isIPhoneInterface && layout.size.height > layout.size.width && dashboardPage == .main
    }

    private func headerTitleBlock(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedStoredGameFile?.displayName ?? localizedAppString("New Game"))
                .font(.system(size: layout.headerTitleSize, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.6)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            localizedAppText(store.selectedSport.title)
                .font(layout.headerSubtitleFont.weight(.semibold))
                .singleLineFitted(minScale: 0.8)
                .foregroundStyle(themePalette.dashboardMutedText)
        }
    }

    @ViewBuilder
    private func verticalHeaderControls(layout: InterfaceLayout) -> some View {
        #if os(iOS)
        if isIPhoneInterface {
            iPhoneHeaderControls(layout: layout)
        } else {
            headerStatusBadge(layout: layout)
            headerActionButtons(layout: layout)
        }
        #else
        headerStatusBadge(layout: layout)
        headerActionButtons(layout: layout)
        #endif
    }

    @ViewBuilder
    private func headerStatusBadge(layout: InterfaceLayout) -> some View {
        #if os(iOS)
        if layout.headerUsesVerticalFlow {
            localDisplayStatusGroup(layout: layout)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            localDisplayStatusGroup(layout: layout)
        }
        #else
        publicBoardStatusGroup(layout: layout)
        #endif
    }

    private func externalDisplayHeaderStatusBadge(layout: InterfaceLayout) -> some View {
        HStack(spacing: 8) {
            Image(systemName: displayStatusSystemImage)
                .imageScale(.medium)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                localizedAppText(displayStatusTitle)
                    .font(layout.headerBadgeFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let remoteDisplayHeaderStatusTitle {
                    Text(remoteDisplayHeaderStatusTitle)
                        .font(layout.headerBadgeDetailFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .foregroundStyle(publicBoardState.isPresented ? themePalette.dashboardStatusLive : themePalette.dashboardStatusIdle)
        .padding(.horizontal, layout.headerBadgeHorizontalPadding)
        .padding(.vertical, layout.headerBadgeVerticalPadding)
        .background(themePalette.dashboardCardBackground, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    #if os(iOS)
    private func iPhoneHeaderControls(layout: InterfaceLayout) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                externalDisplayHeaderStatusBadge(layout: layout)
                iPhoneHeaderButtonCluster(layout: layout)
            }

            VStack(alignment: .trailing, spacing: 8) {
                externalDisplayHeaderStatusBadge(layout: layout)
                iPhoneHeaderButtonCluster(layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func iPhoneHeaderButtonCluster(layout: InterfaceLayout) -> some View {
        iPhoneHeaderIconButtonRow(layout: layout)
    }

    private func iPhoneHeaderIconButtonRow(layout: InterfaceLayout) -> some View {
        HStack(spacing: 8) {
            localScoreboardHeaderButton(layout: layout)
            displayControlHeaderButton(layout: layout)
            soundHeaderButton(layout: layout)
            themeHeaderMenu(layout: layout)
            if store.isCompanionVisible {
                companionHeaderButton(layout: layout)
            }
            settingsHeaderButton(layout: layout)
            hideDashboardHeaderButton(layout: layout)
        }
    }

    @ViewBuilder
    private func localDisplayStatusGroup(layout: InterfaceLayout) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                externalDisplayHeaderStatusBadge(layout: layout)
                localScoreboardHeaderButton(layout: layout)
            }

            VStack(alignment: .trailing, spacing: 8) {
                externalDisplayHeaderStatusBadge(layout: layout)
                localScoreboardHeaderButton(layout: layout)
            }
        }
    }

    private func localScoreboardHeaderButton(layout: InterfaceLayout) -> some View {
        Button {
            enterLocalScoreboardMode()
        } label: {
            localScoreboardHeaderButtonLabel(layout: layout)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString("Local Display"))
        .accessibilityHint(localizedAppString("Show Scoreboard on This Device"))
        .help(localizedAppString("Show Scoreboard on This Device"))
    }

    @ViewBuilder
    private func localScoreboardHeaderButtonLabel(layout: InterfaceLayout) -> some View {
        if isIPhoneInterface {
            headerIconButtonLabel(
                systemImage: "platter.2.filled.ipad",
                tint: themePalette.dashboardNeutralButton,
                foreground: themePalette.dashboardNeutralButtonText,
                layout: layout
            )
        } else {
            Label(localizedAppString("Local Display"), systemImage: "platter.2.filled.ipad")
                .font(layout.headerBadgeFont)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(themePalette.dashboardNeutralButtonText)
                .frame(height: layout.headerIconButtonSize)
                .padding(.horizontal, layout.headerBadgeHorizontalPadding)
                .background(themePalette.dashboardNeutralButton, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    #endif

    #if os(macOS)
    @ViewBuilder
    private func publicBoardStatusGroup(layout: InterfaceLayout) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                externalDisplayHeaderStatusBadge(layout: layout)
                publicBoardHeaderButton(layout: layout)
            }

            VStack(alignment: .trailing, spacing: 8) {
                externalDisplayHeaderStatusBadge(layout: layout)
                publicBoardHeaderButton(layout: layout)
            }
        }
    }
    #endif

    @ViewBuilder
    private func headerActionButtons(layout: InterfaceLayout) -> some View {
        #if os(macOS)
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            displayControlHeaderButton(layout: layout)
            soundHeaderButton(layout: layout)
            themeHeaderMenu(layout: layout)
            if store.isCompanionVisible {
                companionHeaderButton(layout: layout)
            }
            settingsHeaderButton(layout: layout)
            hideDashboardHeaderButton(layout: layout)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        #else
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                displayControlHeaderButton(layout: layout)
                soundHeaderButton(layout: layout)
                themeHeaderMenu(layout: layout)
                if store.isCompanionVisible {
                    companionHeaderButton(layout: layout)
                }
                settingsHeaderButton(layout: layout)

                if !isIPhoneInterface {
                    hideDashboardHeaderButton(layout: layout)
                }
            }

            VStack(alignment: .trailing, spacing: 8) {
                if store.isCompanionVisible {
                    companionHeaderButton(layout: layout)
                }

                HStack(spacing: 10) {
                    displayControlHeaderButton(layout: layout)
                    soundHeaderButton(layout: layout)
                    themeHeaderMenu(layout: layout)
                    settingsHeaderButton(layout: layout)

                    if !isIPhoneInterface {
                        hideDashboardHeaderButton(layout: layout)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        #endif
    }

    #if os(macOS)
    private func publicBoardHeaderButton(layout: InterfaceLayout) -> some View {
        let title = publicBoardState.isPresented ? "Reopen Scoreboard" : "Open Scoreboard"
        return Button {
            showPublicBoardWindow()
        } label: {
            Label(localizedAppString(title), systemImage: "display")
                .font(layout.headerBadgeFont)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(themePalette.dashboardNeutralButtonText)
                .frame(height: layout.headerIconButtonSize)
                .padding(.horizontal, layout.headerBadgeHorizontalPadding)
                .background(themePalette.dashboardNeutralButton, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
    }
    #endif

    private func displayControlHeaderButton(layout: InterfaceLayout) -> some View {
        Button {
            dashboardPage = .preview
        } label: {
            headerIconButtonLabel(
                systemImage: "appletvremote.gen4",
                tint: themePalette.dashboardNeutralButton,
                foreground: themePalette.dashboardNeutralButtonText,
                layout: layout
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString("Display Control"))
        .help(localizedAppString("Display Control"))
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.displayPreview), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func soundHeaderButton(layout: InterfaceLayout) -> some View {
        let title = store.isSoundEnabled ? "Sound On" : "Sound Off"
        return Button {
            store.toggleSoundEnabled()
        } label: {
            headerIconButtonLabel(
                systemImage: store.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                tint: store.isSoundEnabled ? themePalette.dashboardSuccessButton : themePalette.dashboardNeutralButton,
                foreground: store.isSoundEnabled ? themePalette.dashboardSuccessButtonText : themePalette.dashboardNeutralButtonText,
                layout: layout
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
    }

    private func themeHeaderMenu(layout: InterfaceLayout) -> some View {
        Menu {
            ForEach(ScoreboardTheme.allCases) { theme in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        store.theme = theme
                    }
                } label: {
                    Label(localizedAppString(theme.title), systemImage: store.theme == theme ? "checkmark.circle.fill" : theme.systemImage)
                }
            }
        } label: {
            headerIconButtonLabel(
                systemImage: store.theme.systemImage,
                tint: themePalette.dashboardNeutralButton,
                foreground: themePalette.dashboardNeutralButtonText,
                layout: layout
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString("Theme"))
        .help(localizedAppString(store.theme.title))
    }

    private func companionHeaderButton(layout: InterfaceLayout) -> some View {
        let title = store.isCompanionEnabled ? "Companion On" : "Companion Off"
        return Button {
            store.toggleCompanionEnabled()
        } label: {
            headerIconButtonLabel(
                systemImage: IntegrationSettingsDetail.bitfocusCompanion.systemImage,
                tint: store.isCompanionEnabled ? themePalette.dashboardSuccessButton : themePalette.dashboardNeutralButton,
                foreground: store.isCompanionEnabled ? themePalette.dashboardSuccessButtonText : themePalette.dashboardNeutralButtonText,
                layout: layout
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString(title))
        .help(localizedAppString(title))
    }

    private func settingsHeaderButton(layout: InterfaceLayout) -> some View {
        Button {
            openSettingsFromLiveBoard()
        } label: {
            headerIconButtonLabel(
                systemImage: "gearshape",
                tint: themePalette.dashboardNeutralButton,
                foreground: themePalette.dashboardNeutralButtonText,
                layout: layout
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString("Settings"))
        .help(localizedAppString("Settings"))
    }

    private func headerIconButtonLabel(systemImage: String, tint: Color, foreground: Color, layout: InterfaceLayout) -> some View {
        Image(systemName: systemImage)
            .font(layout.headerToggleIconFont)
            .foregroundStyle(foreground)
            .frame(width: layout.headerIconButtonSize, height: layout.headerIconButtonSize)
            .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func hideDashboardHeaderButton(layout: InterfaceLayout) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                isDashboardHeaderHidden = true
            }
        } label: {
            Image(systemName: "chevron.up")
                .font(layout.headerToggleIconFont)
                .foregroundStyle(themePalette.dashboardNeutralButtonText)
                .frame(width: layout.headerToggleButtonSize, height: layout.headerToggleButtonSize)
                .background(themePalette.dashboardNeutralButton, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString("Hide Top Bar"))
    }

    private func showDashboardHeaderButton(layout: InterfaceLayout) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                isDashboardHeaderHidden = false
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(layout.headerToggleIconFont)
                .foregroundStyle(themePalette.dashboardNeutralButtonText)
                .frame(width: layout.headerToggleButtonSize, height: layout.headerToggleButtonSize)
                .background(themePalette.dashboardNeutralButton, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedAppString("Show Top Bar"))
    }

    private func shotClockWidget(layout: InterfaceLayout) -> some View {
        let usesServeTimer = store.usesServeTimer
        let timerAction = usesServeTimer ? "Serve" : "Shot"
        let timerButtons: [ActionDescriptor] = usesServeTimer ? [
            ActionDescriptor(
                title: store.isShotClockRunning ? "\(timerAction) Pause" : "Start \(timerAction)",
                tint: store.isShotClockRunning ? themePalette.dashboardWarningButton : themePalette.dashboardSuccessButton,
                foreground: store.isShotClockRunning ? themePalette.dashboardWarningButtonText : themePalette.dashboardSuccessButtonText
            ) {
                store.toggleShotClock()
            },
            ActionDescriptor(title: "\(timerAction) Reset", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                store.resetActiveShotClock()
            },
            ActionDescriptor(title: "\(timerAction) -1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                store.adjustShotClock(by: -1)
            },
            ActionDescriptor(title: "\(timerAction) +1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                store.adjustShotClock(by: 1)
            }
        ] : [
            ActionDescriptor(
                title: store.isShotClockRunning ? "Shot Pause" : "Shot Reset",
                tint: store.isShotClockRunning ? themePalette.dashboardWarningButton : themePalette.dashboardNeutralButton,
                foreground: store.isShotClockRunning ? themePalette.dashboardWarningButtonText : themePalette.dashboardNeutralButtonText
            ) {
                if store.isShotClockRunning {
                    store.toggleShotClock()
                } else {
                    store.resetActiveShotClock()
                }
            },
            ActionDescriptor(title: "Shot -1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                store.adjustShotClock(by: -1)
            },
            ActionDescriptor(title: "Shot +1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                store.adjustShotClock(by: 1)
            }
        ]

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(store.secondaryTimerTitle)
                    .font(.title3.weight(.bold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Spacer(minLength: 0)

                Text("\(store.secondaryTimerOwnerTitle): \(store.possessionDirection.displayName)")
                    .font(.subheadline.weight(.semibold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardMutedText)
                    .opacity(store.supportsPossession ? 1 : 0)
            }

            Text(store.formattedShotClock)
                .font(.system(size: layout.metricValueSize + 8, weight: .black, design: .rounded))
                .monospacedDigit()
                .singleLineFitted(minScale: 0.4)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            buttonGrid(
                columns: usesServeTimer ? max(2, layout.shotClockButtonColumns - 1) : max(1, layout.shotClockButtonColumns - 2),
                buttons: timerButtons,
                style: .compact,
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.shotClockControls), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func controlPane(layout: InterfaceLayout) -> some View {
        ZStack {
            switch dashboardPage {
            case .main:
                mainControlPane(layout: layout)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            case .players:
                if store.isPlayerTrackingEnabled {
                    playerTrackingScreen(layout: layout)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    mainControlPane(layout: layout)
                        .transition(.opacity)
                }
            case .preview:
                previewDashboardScreen(layout: layout)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: dashboardPage)
    }

    private func mainControlPane(layout: InterfaceLayout) -> some View {
        Group {
            if layout.requiresDashboardScroll {
                ScrollView(.vertical, showsIndicators: false) {
                    dashboardControlStack(layout: layout)
                        .padding(.bottom, layout.sectionSpacing)
                }
            } else {
                GeometryReader { proxy in
                    let topSectionHeight = layout.controlTopSectionHeight(in: proxy.size.height)

                    VStack(spacing: layout.sectionSpacing) {
                        topControlRow(layout: layout)
                            .frame(height: topSectionHeight)

                        bottomControlRow(layout: layout)
                            .frame(height: max(proxy.size.height - topSectionHeight - layout.sectionSpacing, 0))
                    }
                }
            }
        }
    }

    private func playerTrackingScreen(layout: InterfaceLayout) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                playerTrackingIntroCard(layout: layout)
                    .transition(.move(edge: .top).combined(with: .opacity))

                dashboardInlineTip(
                    "Use the player list to manage rosters during live operation. Quick actions handle full-game reset tasks, while each side roster lets you adjust player fouls, cards, active lineup status, and public overlay visibility without leaving the control board.",
                    systemImage: "person.3",
                    layout: layout
                )

                dashboardInlineTip(
                    "Reset actions stay protected while timers are running. Pause the live clocks before clearing fouls, cards, or team counters so player state is not changed accidentally during active play.",
                    systemImage: "lock.shield",
                    layout: layout
                )

                playerTrackingPanel(layout: layout)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .padding(.bottom, layout.sectionSpacing)
        }
    }

    private func previewDashboardScreen(layout: InterfaceLayout) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                pageIntroCard(
                    title: "Display Control",
                    caption: "Choose the public display mode and preview the external scoreboard without requiring an attached display. This preview may not match the connected external display exactly.",
                    actionTitle: "Back to Game",
                    actionSystemImage: "chevron.left",
                    action: { dashboardPage = .main },
                    layout: layout
                )
                .transition(.move(edge: .top).combined(with: .opacity))

                dashboardInlineTip(
                    "Use Display Control to switch what viewers see while keeping the operator controls private. Mode changes apply to the public scoreboard window, external displays, and paired Remote Display devices, while the preview below gives a quick confidence check before or during a game.",
                    systemImage: "display",
                    layout: layout
                )

                displayPresetPanel(layout: layout)
                    .transition(.move(edge: .top).combined(with: .opacity))

                dashboardInlineTip(
                    "The preview renders from the current game state, theme, display direction, background, logos, and player settings. Treat it as an operator check of the selected public mode, not as a pixel-perfect guarantee for every connected screen.",
                    systemImage: "eye",
                    layout: layout
                )

                if isIPhoneInterface {
                    dashboardInlineTip(
                        "On iPhone, this preview may not look correct because the screen is small. For the best viewing experience and the most accurate public display check, connect an external display.",
                        systemImage: "iphone.and.arrow.forward",
                        layout: layout
                    )
                }

                previewPanel(
                    title: "External Scoreboard",
                    caption: currentPreviewModeTitle,
                    layout: layout
                ) {
                    currentPreviewBoard(layout: layout)
                }
                .frame(minHeight: max(320, layout.size.height * 0.58))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .padding(.bottom, layout.sectionSpacing)
        }
    }

    private func dashboardParagraphTip(
        _ message: String,
        systemImage: String,
        placement: String
    ) -> ScoreboardTips.ParagraphTip {
        ScoreboardTips.ParagraphTip(
            id: scoreboardTipID(prefix: "dashboard.\(placement)", message: message),
            titleText: dashboardTourTipTitle(for: message),
            messageText: message,
            systemImage: systemImage
        )
    }

    private func dashboardTourTipTitle(for message: String) -> String {
        let lowercasedMessage = message.lowercased()

        if lowercasedMessage.hasPrefix("use the player list") { return "Player List" }
        if lowercasedMessage.hasPrefix("reset actions stay protected") { return "Protected Resets" }
        if lowercasedMessage.hasPrefix("use display control") { return "Display Control" }
        if lowercasedMessage.hasPrefix("select the display mode") { return "Display Mode" }
        if lowercasedMessage.hasPrefix("the preview renders") { return "Public Preview" }
        if lowercasedMessage.hasPrefix("this debate segment has no timer") { return "No Timer Segment" }
        if lowercasedMessage.hasPrefix("this debate segment uses two side clocks") { return "Dual Clock Segment" }
        if lowercasedMessage.hasPrefix("debate controls") { return "Debate Controls" }
        if lowercasedMessage.hasPrefix("custom dual-clock controls") { return "Custom Dual Clocks" }
        if lowercasedMessage.hasPrefix("chess controls") { return "Chess Controls" }
        if lowercasedMessage.hasPrefix("simple controls") { return "Simple Controls" }
        if lowercasedMessage.hasPrefix("basketball controls") { return "Basketball Controls" }
        if lowercasedMessage.hasPrefix("volleyball controls") { return "Volleyball Controls" }
        if lowercasedMessage.hasPrefix("soccer controls") { return "Soccer Controls" }
        if lowercasedMessage.hasPrefix("hockey controls") { return "Hockey Controls" }
        if lowercasedMessage.hasPrefix("custom controls") { return "Custom Controls" }

        return "Live Board"
    }

    private var liveBoardSportGuidanceTourTip: ScoreboardTips.ParagraphTip {
        let guidance = liveBoardSportGuidance
        return dashboardParagraphTip(
            guidance.message,
            systemImage: guidance.systemImage,
            placement: "panel"
        )
    }

    private var liveDebateSegmentModeTourTip: ScoreboardTips.ParagraphTip? {
        switch store.currentDebateSegment?.timerMode {
        case .some(.none):
            return dashboardParagraphTip(
                "This debate segment has no timer. Use it as a live checklist step for instructions, transitions, prep reminders, or judge/admin pauses, then move to the previous or next segment when the round flow is ready to continue.",
                systemImage: "pause.circle",
                placement: "panel"
            )
        case .some(.dualClock):
            return dashboardParagraphTip(
                "This debate segment uses two side clocks. Start the active side, switch turns when control changes, and use the active-side jog buttons carefully because time adjustments apply to the currently selected side clock.",
                systemImage: "person.2",
                placement: "panel"
            )
        case .some(.masterClock), nil:
            return nil
        }
    }

    private var dashboardTourTips: [any Tip] {
        var tips: [any Tip] = [
            ScoreboardTips.liveBoard,
            ScoreboardTips.displayPreview,
            liveBoardSportGuidanceTourTip
        ]

        if let debateSegmentTip = liveDebateSegmentModeTourTip {
            tips.append(debateSegmentTip)
        }
        if !usesDedicatedDualClockLayout {
            tips.append(ScoreboardTips.gameState)
        }
        tips.append(ScoreboardTips.scoreControls)
        tips.append(ScoreboardTips.matchControls)
        if store.supportsShotClock {
            tips.append(ScoreboardTips.shotClockControls)
        }
        if !usesDedicatedDualClockLayout, store.isPlayerTrackingEnabled {
            tips.append(ScoreboardTips.playerShortcut)
        }

        return tips
    }

    private var dashboardTourSignature: String {
        dashboardTourTips.map(\.id).joined(separator: "|")
    }

    private func refreshDashboardTipGroup() {
        let signature = dashboardTourSignature
        guard signature != dashboardTipGroupSignature else { return }

        let tips = dashboardTourTips
        dashboardTipGroupSignature = signature
        dashboardTipGroup = TipGroup(.ordered) {
            for tip in tips {
                tip
            }
        }
    }

    private func dashboardCurrentTourTip(matching tip: any Tip) -> (any Tip)? {
        guard dashboardPage == .main, let currentTip = dashboardTipGroup?.currentTip, currentTip.id == tip.id else {
            return nil
        }
        return currentTip
    }

    @ViewBuilder
    private func dashboardOrderedTip(_ tip: any Tip) -> some View {
        if store.areTipsEnabled, let currentTip = dashboardCurrentTourTip(matching: tip) {
            scoreboardInlineTip(currentTip)
        }
    }

    @ViewBuilder
    private func dashboardInlineTip(
        _ message: String,
        systemImage: String = "lightbulb",
        layout _: InterfaceLayout
    ) -> some View {
        let tip = dashboardParagraphTip(message, systemImage: systemImage, placement: "inline")
        if dashboardPage == .main {
            dashboardOrderedTip(tip)
        } else {
            scoreboardInlineTip(tip)
        }
    }

    private func displayPresetPanel(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                localizedAppText("Display")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Spacer(minLength: 0)

                Text(localizedAppString(store.publicDisplayViewMode.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themePalette.dashboardMutedText)
            }

            dashboardPanelTip(
                "Select the display mode that should be sent to viewers. Scoreboard mode shows the full game face, while player, logo, and alternate display modes focus the public screen on the selected production element.",
                systemImage: "rectangle.on.rectangle",
                layout: layout
            )

            LazyVGrid(columns: displayPresetGridColumns(layout: layout), spacing: displayPresetGridSpacing(layout: layout)) {
                ForEach(displayPresetModes) { mode in
                    displayPresetButton(mode, layout: layout)
                }
            }
        }
        .padding(.horizontal, layout.controlCardPadding)
        .padding(.vertical, layout.controlCardPadding)
        .background(themePalette.dashboardCardBackground, in: RoundedRectangle(cornerRadius: layout.controlCardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.controlCardCornerRadius, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder)
        )
    }

    private var displayPresetModes: [ScoreboardDisplayViewMode] {
        [
            .blackScreen,
            .backgroundOnly,
            .eventLogo,
            .teamView,
            .playerView,
            .scoreboard
        ]
    }

    private func displayPresetGridColumns(layout: InterfaceLayout) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: displayPresetGridSpacing(layout: layout)), count: 3)
    }

    private func displayPresetGridSpacing(layout: InterfaceLayout) -> CGFloat {
        layout.isCompactWidth ? 8 : 10
    }

    @ViewBuilder
    private func dashboardPanelTip(
        _ message: String,
        systemImage: String = "lightbulb",
        layout _: InterfaceLayout
    ) -> some View {
        let tip = dashboardParagraphTip(message, systemImage: systemImage, placement: "panel")
        if dashboardPage == .main {
            dashboardOrderedTip(tip)
        } else {
            scoreboardInlineTip(tip)
        }
    }

    private var liveBoardSportGuidance: (message: String, systemImage: String) {
        if store.isDebateMode {
            return (
                "Debate controls follow the segment flow chosen in Game Setup. Use this panel to start or return to the active segment timer, move between segments, switch active sides for dual-clock blocks, and reset only after timers are paused.",
                "quote.bubble"
            )
        }

        if store.usesChessClocks {
            if store.selectedSport == .custom {
                return (
                    "Custom dual-clock controls use the side clocks configured in Game Setup. Start the active clock, switch turns, adjust side clocks, or reset both clocks here after pausing live play.",
                    "timer"
                )
            }

            return (
                "Chess controls use the preset and side clocks configured in Game Setup. Start the active clock, switch turns, adjust side clocks, or reset both player clocks here after pausing the match.",
                "timer"
            )
        }

        switch store.selectedSport {
        case .simple:
            return (
                "Simple controls use the setup clock and team names for a compact score-and-timer workflow. Run or jog the clock here, swap sides if needed, and use reset actions only when live play is paused.",
                "timer"
            )
        case .basketball:
            return (
                "Basketball controls combine score, game clock, period, possession, and shot-clock presets from setup. Use this panel to run the main clock, move periods, swap sides, and reset only after play is paused.",
                "timer.circle"
            )
        case .volleyball:
            return (
                "Volleyball controls reflect the match timer, period format, serve timer, substitutions, and player-card choices from setup. Use the period-win actions to record winners, reset the rally score, and advance the match.",
                "person.3"
            )
        case .soccer:
            return (
                "Soccer controls use the half, clock, lineup, card, and substitution choices from setup. Run the match clock here, manage sides and resets, and use Players for lineups, cards, fouls, and overlay changes.",
                "flag.checkered"
            )
        case .hockey:
            return (
                "Hockey controls use the period and clock setup, while side panels handle penalty timers. Use this panel for the main clock, period changes, side swaps, and resets after live play is paused.",
                "clock"
            )
        case .custom:
            return (
                "Custom controls reflect the modules enabled in Game Setup. If clock, period, secondary timer, substitutions, penalty timers, fouls, cards, or player tools are missing, return to Settings and turn on that custom option before going live.",
                "slider.horizontal.3"
            )
        case .chess, .debate:
            return (
                "Game controls reflect the sport-specific setup chosen in Settings. Confirm clocks, sides, periods, and tracking options before using this panel during live play.",
                "lightbulb"
            )
        }
    }

    @ViewBuilder
    private func liveBoardSportGuidanceTip(layout: InterfaceLayout) -> some View {
        let guidance = liveBoardSportGuidance
        dashboardPanelTip(guidance.message, systemImage: guidance.systemImage, layout: layout)
    }

    @ViewBuilder
    private func liveDebateSegmentModeTip(layout: InterfaceLayout) -> some View {
        switch store.currentDebateSegment?.timerMode {
        case .some(.none):
            dashboardPanelTip(
                "This debate segment has no timer. Use it as a live checklist step for instructions, transitions, prep reminders, or judge/admin pauses, then move to the previous or next segment when the round flow is ready to continue.",
                systemImage: "pause.circle",
                layout: layout
            )
        case .some(.dualClock):
            dashboardPanelTip(
                "This debate segment uses two side clocks. Start the active side, switch turns when control changes, and use the active-side jog buttons carefully because time adjustments apply to the currently selected side clock.",
                systemImage: "person.2",
                layout: layout
            )
        case .some(.masterClock), nil:
            EmptyView()
        }
    }

    private func displayPresetButton(_ mode: ScoreboardDisplayViewMode, layout: InterfaceLayout) -> some View {
        let isSelected = store.publicDisplayViewMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                store.publicDisplayViewMode = mode
            }
        } label: {
            Label(localizedAppString(mode.title), systemImage: isSelected ? "checkmark.circle.fill" : mode.systemImage)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(isSelected ? themePalette.dashboardSuccessButtonText : themePalette.dashboardNeutralButtonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.denseControls ? 12 : 14)
                .background(
                    isSelected ? themePalette.dashboardSuccessButton : themePalette.dashboardNeutralButton,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private func dashboardControlStack(layout: InterfaceLayout) -> some View {
        VStack(spacing: layout.sectionSpacing) {
            topControlRow(layout: layout)
            bottomControlRow(layout: layout)
        }
    }

    private func pageIntroCard(
        title: String,
        caption: String,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        action: (() -> Void)? = nil,
        layout: InterfaceLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                localizedAppText(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                localizedAppText(caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themePalette.dashboardMutedText)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(localizedAppString(actionTitle), systemImage: actionSystemImage ?? "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(themePalette.dashboardNeutralButtonText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(themePalette.dashboardNeutralButton, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, layout.controlCardPadding)
        .padding(.vertical, layout.controlCardPadding)
        .background(themePalette.dashboardCardBackground, in: RoundedRectangle(cornerRadius: layout.controlCardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.controlCardCornerRadius, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: store.isPlayerOverlayPaused)
    }

    private func playerTrackingIntroCard(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Player Tracking")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Text("Roster, cards, fouls, and active-lineup controls.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themePalette.dashboardMutedText)
            }

            HStack(spacing: 10) {
                Button {
                    dashboardPage = .main
                } label: {
                    Label("Back to Game", systemImage: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(themePalette.dashboardNeutralButtonText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(themePalette.dashboardNeutralButton, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    store.togglePlayerOverlayPaused()
                } label: {
                    Label(store.isPlayerOverlayPaused ? "Resume Overlay" : "Pause Overlay", systemImage: store.isPlayerOverlayPaused ? "play.fill" : "pause.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(store.isPlayerOverlayPaused ? themePalette.dashboardSuccessButtonText : themePalette.dashboardNeutralButtonText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background((store.isPlayerOverlayPaused ? themePalette.dashboardSuccessButton : themePalette.dashboardNeutralButton), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, layout.controlCardPadding)
        .padding(.vertical, layout.controlCardPadding)
        .background(themePalette.dashboardCardBackground, in: RoundedRectangle(cornerRadius: layout.controlCardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.controlCardCornerRadius, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder)
        )
    }

    @ViewBuilder
    private func bottomControlRow(layout: InterfaceLayout) -> some View {
        if !store.supportsShotClock {
            gameControls(layout: layout)
        } else if layout.controlBottomUsesVerticalFlow {
            VStack(spacing: layout.sectionSpacing) {
                gameControls(layout: layout)
                shotClockWidget(layout: layout)
            }
        } else {
            HStack(spacing: 16) {
                gameControls(layout: layout)
                    .frame(maxWidth: .infinity)

                shotClockWidget(layout: layout)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func topControlRow(layout: InterfaceLayout) -> some View {
        let leftIsHome = store.resolvedControlBoardDisplayDirection.leftSide == .home
        let leftTitle = store.sideRoleLabel(for: leftIsHome ? .home : .guest)
        let rightTitle = store.sideRoleLabel(for: leftIsHome ? .guest : .home)

        if usesDedicatedDualClockLayout {
            if layout.topControlUsesVerticalFlow {
                return AnyView(VStack(spacing: layout.sectionSpacing) {
                    teamControls(
                        title: leftTitle,
                        isHome: leftIsHome,
                        tint: leftIsHome ? homeTint : guestTint,
                        layout: layout
                    )

                    teamControls(
                        title: rightTitle,
                        isHome: !leftIsHome,
                        tint: leftIsHome ? guestTint : homeTint,
                        layout: layout
                    )
                })
            } else {
                return AnyView(HStack(spacing: 16) {
                    teamControls(
                        title: leftTitle,
                        isHome: leftIsHome,
                        tint: leftIsHome ? homeTint : guestTint,
                        layout: layout
                    )
                    .frame(maxWidth: .infinity)

                    teamControls(
                        title: rightTitle,
                        isHome: !leftIsHome,
                        tint: leftIsHome ? guestTint : homeTint,
                        layout: layout
                    )
                    .frame(maxWidth: .infinity)
                })
            }
        }

        if layout.topControlUsesVerticalFlow {
            return AnyView(VStack(spacing: layout.sectionSpacing) {
                centeredStatusWidget(layout: layout)

                teamControls(
                    title: leftTitle,
                    isHome: leftIsHome,
                    tint: leftIsHome ? homeTint : guestTint,
                    layout: layout
                )

                teamControls(
                    title: rightTitle,
                    isHome: !leftIsHome,
                    tint: leftIsHome ? guestTint : homeTint,
                    layout: layout
                )
            })
        } else {
            return AnyView(HStack(spacing: 16) {
                teamControls(
                    title: leftTitle,
                    isHome: leftIsHome,
                    tint: leftIsHome ? homeTint : guestTint,
                    layout: layout
                )
                .frame(maxWidth: .infinity)

                centeredStatusWidget(layout: layout)
                .frame(maxWidth: layout.centerStatusWidth)

                teamControls(
                    title: rightTitle,
                    isHome: !leftIsHome,
                    tint: leftIsHome ? guestTint : homeTint,
                    layout: layout
                )
                .frame(maxWidth: .infinity)
            })
        }
    }

    private func centeredStatusWidget(layout: InterfaceLayout) -> some View {
        if usesDedicatedDualClockLayout {
            return AnyView(chessStatusWidget(layout: layout))
        }

        if store.isDebateMode {
            return AnyView(debateStatusWidget(layout: layout))
        }

        let leftSide = store.resolvedControlBoardDisplayDirection.leftSide
        let rightSide = store.resolvedControlBoardDisplayDirection.rightSide
        let leftName = leftSide == .home ? store.homeTeamName : store.guestTeamName
        let leftScore = leftSide == .home ? store.homeScore : store.guestScore
        let leftTint = leftSide == .home ? homeTint : guestTint
        let rightName = rightSide == .home ? store.homeTeamName : store.guestTeamName
        let rightScore = rightSide == .home ? store.homeScore : store.guestScore
        let rightTint = rightSide == .home ? homeTint : guestTint

        return AnyView(VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Game State")
                    .font(.title3.weight(.bold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Spacer(minLength: 0)

                localizedAppText(store.showsGameClock ? (store.isClockRunning ? "Running" : "Stopped") : "Timer Off")
                    .font(.subheadline.weight(.semibold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(store.showsGameClock && store.isClockRunning ? themePalette.dashboardStatusLive : themePalette.dashboardMutedText)
            }

            HStack(spacing: 12) {
                gameStateScoreColumn(
                    title: displayTeamName(leftName),
                    score: leftScore,
                    tint: leftTint,
                    layout: layout
                )

                Text("-")
                    .font(.system(size: layout.centerScoreSize - 10, weight: .black, design: .rounded))
                    .foregroundStyle(themePalette.dashboardMutedText)

                gameStateScoreColumn(
                    title: displayTeamName(rightName),
                    score: rightScore,
                    tint: rightTint,
                    layout: layout
                )
            }
            .frame(maxWidth: .infinity)

            if store.usesChessClocks {
                compactDualClockRow(layout: layout)
            } else if store.showsGameClock {
                Text(store.formattedClock)
                    .font(.system(size: layout.centerScoreSize + 6, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .singleLineFitted(minScale: 0.4)
                    .foregroundStyle(themePalette.dashboardPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.84), value: store.formattedClock)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: layout.centerMetricColumns),
                spacing: 10
            ) {
                if store.supportsShotClock {
                    gameMetricCard(title: store.secondaryTimerActionTitle, value: store.formattedShotClock, monospaced: true, animatesValue: false, layout: layout)
                }
                if store.supportsPeriod {
                    gameMetricCard(title: store.periodTitle, value: "\(store.period)", layout: layout)
                }
                if store.supportsPeriodWinTracking {
                    gameMetricCard(title: "Periods", value: "\(store.homePeriodWins)-\(store.guestPeriodWins)", layout: layout)
                }
            }

            if store.isPlayerTrackingEnabled {
                Button {
                    dashboardPage = .players
                } label: {
                    Label("Open Players", systemImage: "person.3")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(themePalette.dashboardNeutralButtonText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(themePalette.dashboardNeutralButton, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.playerShortcut), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
            }
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.gameState), isEnabled: arePopoverTipsEnabled, arrowEdge: .top))
    }

    private func compactDualClockRow(layout: InterfaceLayout) -> some View {
        HStack(spacing: 10) {
            compactDualClockBadge(
                title: displayTeamName(store.homeTeamName),
                value: store.formattedHomeChessClock,
                tint: homeTint,
                isActive: store.activeChessClockSide == .home,
                layout: layout
            )

            compactDualClockBadge(
                title: displayTeamName(store.guestTeamName),
                value: store.formattedGuestChessClock,
                tint: guestTint,
                isActive: store.activeChessClockSide == .guest,
                layout: layout
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func compactDualClockBadge(
        title: String,
        value: String,
        tint: Color,
        isActive: Bool,
        layout: InterfaceLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(themePalette.dashboardSubtleText)

            HStack(spacing: 8) {
                Circle()
                    .fill(isActive ? tint : themePalette.dashboardMutedText.opacity(0.35))
                    .frame(width: 10, height: 10)

                Text(value)
                    .font(.system(size: layout.centerMetricValueSize + 2, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .singleLineFitted(minScale: 0.55)
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(themePalette.dashboardCardBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder.opacity(0.75))
        )
    }

    private func chessStatusWidget(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizedAppFormat("%@ Clocks", localizedAppString(store.selectedSport.title)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Spacer(minLength: 0)

                localizedAppText(store.isClockRunning ? "Running" : "Paused")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.isClockRunning ? themePalette.dashboardStatusLive : themePalette.dashboardMutedText)
            }

            HStack(spacing: 12) {
                chessClockColumn(
                    title: displayTeamName(store.homeTeamName),
                    value: store.formattedHomeChessClock,
                    tint: homeTint,
                    isActive: store.activeChessClockSide == .home,
                    layout: layout
                )

                chessClockColumn(
                    title: displayTeamName(store.guestTeamName),
                    value: store.formattedGuestChessClock,
                    tint: guestTint,
                    isActive: store.activeChessClockSide == .guest,
                    layout: layout
                )
            }
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.gameState), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func chessClockColumn(title: String, value: String, tint: Color, isActive: Bool, layout: InterfaceLayout) -> some View {
        VStack(spacing: 10) {
            localizedAppText(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(themePalette.dashboardSubtleText)

            Text(value)
                .font(.system(size: layout.centerScoreSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)

            localizedAppText(isActive ? "ACTIVE" : "WAITING")
                .font(.caption.weight(.black))
                .foregroundStyle(isActive ? tint : themePalette.dashboardMutedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func gameStateScoreColumn(
        title: String,
        score: Int,
        tint: Color,
        layout: InterfaceLayout
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(themePalette.dashboardSubtleText)

            Text("\(score)")
                .font(.system(size: layout.centerScoreSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .singleLineFitted(minScale: 0.4)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: score)
        }
        .frame(maxWidth: .infinity)
    }

    private func gameMetricCard(
        title: String,
        value: String,
        monospaced: Bool = false,
        animatesValue: Bool = true,
        layout: InterfaceLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardSubtleText)

            gameMetricValueText(value, monospaced: monospaced, animatesValue: animatesValue, layout: layout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(themePalette.dashboardCardBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder.opacity(0.75))
        )
    }

    @ViewBuilder
    private func gameMetricValueText(
        _ value: String,
        monospaced: Bool,
        animatesValue: Bool,
        layout: InterfaceLayout
    ) -> some View {
        let text = Text(value)
            .font(.system(size: layout.centerMetricValueSize, weight: .black, design: .rounded))
            .monospacedDigitIfNeeded(monospaced)
            .singleLineFitted(minScale: 0.4)
            .foregroundStyle(themePalette.dashboardPrimaryText)

        if animatesValue {
            text
                .contentTransition(.numericText())
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: value)
        } else {
            text
        }
    }

    private func teamControls(
        title: String,
        isHome: Bool,
        tint: Color,
        layout: InterfaceLayout
    ) -> some View {
        let side: TeamSide = isHome ? .home : .guest
        let tintText = teamAccentText(for: side)

        if usesDedicatedDualClockLayout {
            return AnyView(chessTeamControls(side: side, tint: tint, layout: layout))
        }

        return AnyView(VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            if store.usesChessClocks && !store.isDebateMode {
                smallActionButton(
                    "Turn Here",
                    tint: store.activeChessClockSide == side ? tint.opacity(0.78) : tint,
                    foreground: tintText,
                    verticalPadding: layout.advancedButtonVerticalPadding
                ) {
                    store.setActiveChessClockSide(side)
                }
            }

            if store.isDebateMode, store.currentDebateSegment?.timerMode == .dualClock {
                smallActionButton(
                    store.activeChessClockSide == side && store.isClockRunning ? "Pause Here" : "Turn Here",
                    tint: store.activeChessClockSide == side ? tint.opacity(0.78) : tint,
                    foreground: tintText,
                    verticalPadding: layout.advancedButtonVerticalPadding
                ) {
                    handleDebateTurnHere(for: side)
                }
            }

            if store.showsDebatePrepTime {
                debatePrepInlinePanel(side: isHome ? .home : .guest, tint: tint, layout: layout)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if store.supportsScore {
                buttonGrid(
                    columns: max(1, min(2, scoreButtons(forHomeTeam: isHome, tint: tint).count)),
                    buttons: scoreButtons(forHomeTeam: isHome, tint: tint),
                    dense: layout.denseControls
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if store.supportsShotClock {
                if store.usesServeTimer {
                    let possessionSide: PossessionDirection = side == .home ? .home : .guest
                    let isSelectedSide = store.possessionDirection == possessionSide
                    buttonGrid(
                        columns: 1,
                        buttons: [
                            ActionDescriptor(
                                title: "Serve Here",
                                tint: isSelectedSide ? tint : themePalette.dashboardNeutralButton,
                                foreground: isSelectedSide ? tintText : themePalette.dashboardNeutralButtonText
                            ) {
                                store.setServeTimerSide(side)
                            }
                        ],
                        dense: layout.denseControls,
                        compactVerticalPadding: layout.advancedButtonVerticalPadding
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    let possessionSide: PossessionDirection = side == .home ? .home : .guest
                    let isSelectedSide = store.possessionDirection == possessionSide
                    buttonGrid(
                        columns: 2,
                        buttons: [
                            ActionDescriptor(
                                title: "Shot 24",
                                tint: (isSelectedSide && store.activeShotClockPresetSeconds == 24) ? tint : themePalette.dashboardNeutralButton,
                                foreground: (isSelectedSide && store.activeShotClockPresetSeconds == 24) ? tintText : themePalette.dashboardNeutralButtonText
                            ) {
                                store.assignShotClock(to: 24, forHomeTeam: isHome)
                            },
                            ActionDescriptor(
                                title: "Shot 14",
                                tint: (isSelectedSide && store.activeShotClockPresetSeconds == 14) ? tint.opacity(0.82) : themePalette.dashboardNeutralButton,
                                foreground: (isSelectedSide && store.activeShotClockPresetSeconds == 14) ? tintText : themePalette.dashboardNeutralButtonText
                            ) {
                                store.assignShotClock(to: 14, forHomeTeam: isHome)
                            }
                        ],
                        dense: layout.denseControls,
                        compactVerticalPadding: layout.advancedButtonVerticalPadding
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            if store.showsSubstitutionTracking {
                substitutionControlRow(side: isHome ? .home : .guest, tint: tint, layout: layout)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if store.showsPauseTracking {
                pauseControlRow(side: isHome ? .home : .guest, tint: tint, layout: layout)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if store.supportsTeamFouls {
                teamFoulControlRow(side: isHome ? .home : .guest, tint: tint, layout: layout)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if store.supportsHockeyPenalties {
                hockeyPenaltyPanel(side: isHome ? .home : .guest, tint: tint, layout: layout)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.supportsShotClock)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.supportsScore)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.showsSubstitutionTracking)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.showsPauseTracking)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.supportsTeamFouls)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.supportsHockeyPenalties)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.showsDebatePrepTime)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.debateActiveTimer)
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.scoreControls), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
        )
    }

    private func chessTeamControls(side: TeamSide, tint: Color, layout: InterfaceLayout) -> some View {
        let isHome = side == .home
        let clockText = isHome ? store.formattedHomeChessClock : store.formattedGuestChessClock
        let tintText = teamAccentText(for: side)
        return VStack(alignment: .leading, spacing: 12) {
            localizedAppText(side.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(themePalette.dashboardPrimaryText)

            Text(clockText)
                .font(.system(size: layout.centerMetricValueSize + 6, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)

            localizedAppText(store.activeChessClockSide == side ? "Active Clock" : "Waiting")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(store.activeChessClockSide == side ? tint : themePalette.dashboardMutedText)

            smallActionButton(
                "Turn Here",
                tint: store.activeChessClockSide == side ? tint.opacity(0.78) : tint,
                foreground: tintText,
                verticalPadding: layout.advancedButtonVerticalPadding
            ) {
                store.setActiveChessClockSide(side)
            }

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "-1 Min", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustChessClock(for: side, by: -60)
                    },
                    ActionDescriptor(title: "+1 Min", tint: tint, foreground: tintText) {
                        store.adjustChessClock(for: side, by: 60)
                    }
                ],
                dense: layout.denseControls
            )

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "-1 Sec", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustChessClock(for: side, by: -1)
                    },
                    ActionDescriptor(title: "+1 Sec", tint: tint.opacity(0.9), foreground: tintText) {
                        store.adjustChessClock(for: side, by: 1)
                    }
                ],
                dense: layout.denseControls
            )
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.scoreControls), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func playerTrackingPanel(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Quick Actions")
                    .font(.title3.weight(.bold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Spacer(minLength: 0)

                Text(resetSummaryText)
                    .font(.subheadline.weight(.semibold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardMutedText)
            }

            buttonGrid(
                columns: min(layout.playerActionButtonColumns, 3),
                buttons: quickResetButtons(),
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )

            if layout.playerPanelsUseVerticalFlow {
                VStack(spacing: layout.sectionSpacing) {
                    playerTeamPanel(side: .home, layout: layout)
                    playerTeamPanel(side: .guest, layout: layout)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    playerTeamPanel(side: .home, layout: layout)
                    playerTeamPanel(side: .guest, layout: layout)
                }
            }
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.resetInterlock), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func quickResetButtons() -> [ActionDescriptor] {
        var buttons: [ActionDescriptor] = []

        if store.supportsFouls {
            buttons.append(
                ActionDescriptor(title: "Reset All Player Fouls", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText, isEnabled: !isResetInterlockActive) {
                    pendingGameConfirmation = .resetAllPlayerFouls
                }
            )
        }

        if store.supportsTeamFouls {
            buttons.append(
                ActionDescriptor(title: "Reset All Team Fouls", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText, isEnabled: !isResetInterlockActive) {
                    pendingGameConfirmation = .resetAllTeamFouls
                }
            )
        }

        if store.supportsCards {
            buttons.append(
                ActionDescriptor(title: "Reset All Cards", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText, isEnabled: !isResetInterlockActive) {
                    pendingGameConfirmation = .resetAllCards
                }
            )
        }

        if buttons.isEmpty {
            buttons.append(
                ActionDescriptor(title: "No Reset Actions", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, isEnabled: false) {}
            )
        }

        return buttons
    }

    private var resetSummaryText: String {
        var parts: [String] = []
        if store.supportsFouls { parts.append("Player Fouls") }
        if store.supportsTeamFouls { parts.append("Team Fouls") }
        if store.supportsCards { parts.append("Cards") }
        return parts.isEmpty ? "No reset actions" : parts.joined(separator: " • ")
    }

    private func playerTeamPanel(side: TeamSide, layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(store.sideRoleLabel(for: side)) Roster")
                    .font(.headline.weight(.bold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Spacer(minLength: 0)

                Text("Showing \(store.trackedPlayers(for: side).filter(\.isInActiveLineup).count)/\(min(store.displayLineupSize, store.rosterSizePerTeam))")
                    .font(.caption.weight(.semibold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardMutedText)
            }

            playerTeamToolbar(side: side, layout: layout)

            VStack(spacing: 10) {
                ForEach(store.trackedPlayers(for: side)) { player in
                    playerControlRow(player, side: side, layout: layout)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func playerTeamToolbar(side: TeamSide, layout: InterfaceLayout) -> some View {
        let buttons = teamToolbarButtons(for: side)

        if !buttons.isEmpty {
            buttonGrid(
                columns: min(max(1, buttons.count), 3),
                buttons: buttons,
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func teamToolbarButtons(for side: TeamSide) -> [ActionDescriptor] {
        var buttons: [ActionDescriptor] = []
        let sideTitle = store.sideRoleLabel(for: side)

        if store.supportsFouls {
            buttons.append(
                ActionDescriptor(title: localizedAppFormat("Reset %@ Player Fouls", sideTitle), tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, isEnabled: !isResetInterlockActive) {
                    pendingGameConfirmation = .resetSidePlayerFouls(side)
                }
            )
        }

        if store.supportsTeamFouls {
            buttons.append(
                ActionDescriptor(title: localizedAppFormat("Reset %@ Team Fouls", sideTitle), tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, isEnabled: !isResetInterlockActive) {
                    pendingGameConfirmation = .resetSideTeamFouls(side)
                }
            )
        }

        if store.supportsCards {
            buttons.append(
                ActionDescriptor(title: localizedAppFormat("Reset %@ Cards", sideTitle), tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, isEnabled: !isResetInterlockActive) {
                    pendingGameConfirmation = .resetSideCards(side)
                }
            )
        }

        return buttons
    }

    private func playerControlRow(_ player: TrackedPlayer, side: TeamSide, layout: InterfaceLayout) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(player.number.isEmpty ? "--" : player.number) \(player.name.isEmpty ? localizedAppString("PLAYER") : player.name)")
                    .font(.subheadline.weight(.bold))
                    .singleLineFitted(minScale: 0.65)
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                localizedAppText(player.isInActiveLineup ? "Active Lineup" : "Bench")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(player.isInActiveLineup ? themePalette.dashboardStatusLive : themePalette.dashboardMutedText)
            }

            Spacer(minLength: 0)

            if store.supportsCards {
                Text(localizedAppString(player.cardStatus.title).uppercased())
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(cardStatusColor(player.cardStatus))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(themePalette.dashboardCardBackground.opacity(0.72), in: Capsule())

                smallActionButton("Y", tint: player.cardStatus == .yellow ? .yellow.opacity(0.88) : .yellow.opacity(0.42), foreground: .black, verticalPadding: layout.advancedButtonVerticalPadding) {
                    store.setCardStatus(toggledCardStatus(.yellow, current: player.cardStatus), for: side, playerID: player.id)
                }
                .frame(width: 40)

                smallActionButton("R", tint: player.cardStatus == .red ? .red.opacity(0.9) : .red.opacity(0.42), foreground: .white, verticalPadding: layout.advancedButtonVerticalPadding) {
                    store.setCardStatus(toggledCardStatus(.red, current: player.cardStatus), for: side, playerID: player.id)
                }
                .frame(width: 40)
            }

            if store.supportsFouls {
                Text("F \(player.foulCount)")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(themePalette.dashboardPrimaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(themePalette.dashboardCardBackground.opacity(0.72), in: Capsule())

                smallActionButton("-", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, verticalPadding: layout.advancedButtonVerticalPadding) {
                    store.adjustFoulCount(for: side, playerID: player.id, by: -1)
                }
                .frame(width: 40)

                smallActionButton("+", tint: side == .home ? homeTint : guestTint, foreground: teamAccentText(for: side), verticalPadding: layout.advancedButtonVerticalPadding) {
                    store.adjustFoulCount(for: side, playerID: player.id, by: 1)
                }
                .frame(width: 40)
            }

            smallActionButton(
                player.isInActiveLineup ? "Bench" : "Show",
                tint: player.isInActiveLineup ? themePalette.dashboardNeutralButton : (side == .home ? homeTint.opacity(0.86) : guestTint.opacity(0.86)),
                foreground: player.isInActiveLineup ? themePalette.dashboardNeutralButtonText : teamAccentText(for: side),
                verticalPadding: layout.advancedButtonVerticalPadding
            ) {
                store.setPlayerActiveLineup(!player.isInActiveLineup, for: side, playerID: player.id)
            }
            .frame(width: 78)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(themePalette.dashboardCardBackground.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder.opacity(0.7))
        )
    }

    private func gameControls(layout: InterfaceLayout) -> some View {
        if store.isDebateMode {
            return AnyView(debateGameControls(layout: layout))
        }

        if store.usesChessClocks {
            return AnyView(chessGameControls(layout: layout))
        }

        return AnyView(VStack(alignment: .leading, spacing: 16) {
            if store.showsGameClock {
                gameSummaryRow(layout: layout)

                liveBoardSportGuidanceTip(layout: layout)

                actionButton(
                    store.isClockRunning ? "Pause Game Clock" : "Start Game Clock",
                    tint: themePalette.dashboardSuccessButton,
                    foreground: themePalette.dashboardSuccessButtonText,
                    titleFont: .title3.weight(.black),
                    verticalPadding: layout.denseControls ? 16 : 20
                ) {
                    store.toggleClock()
                }

                buttonGrid(
                    columns: 4,
                    buttons: [
                        ActionDescriptor(title: "-1 Min", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                            store.adjustClock(by: -60)
                        },
                        ActionDescriptor(title: "+1 Min", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                            store.adjustClock(by: 60)
                        },
                        ActionDescriptor(title: "-1 Sec", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                            store.adjustClock(by: -1)
                        },
                        ActionDescriptor(title: "+1 Sec", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                            store.adjustClock(by: 1)
                        }
                    ],
                    dense: layout.denseControls,
                    compactVerticalPadding: layout.advancedButtonVerticalPadding
                )
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Match Controls")
                        .font(.title3.weight(.bold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(themePalette.dashboardPrimaryText)

                    Spacer(minLength: 0)

                    Text("Timer Disabled")
                        .font(.subheadline.weight(.semibold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(themePalette.dashboardMutedText)
                }

                liveBoardSportGuidanceTip(layout: layout)
            }

            buttonGrid(
                columns: matchNavigationButtons.count,
                buttons: matchNavigationButtons,
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )

            if store.supportsPeriodWinTracking {
                VStack(alignment: .leading, spacing: 10) {
                    Text(periodWinStatusText)
                        .font(.subheadline.weight(.semibold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(themePalette.dashboardMutedText)

                    buttonGrid(
                        columns: store.volleyballSetResults.isEmpty ? 2 : 3,
                        buttons: [
                            ActionDescriptor(title: "Home Wins Period", tint: homeTint, foreground: homeTintText, isEnabled: store.periodWinMatchWinner == nil) {
                                requestGameConfirmation(.awardVolleyballSet(.home))
                            },
                            ActionDescriptor(title: "Guest Wins Period", tint: guestTint, foreground: guestTintText, isEnabled: store.periodWinMatchWinner == nil) {
                                requestGameConfirmation(.awardVolleyballSet(.guest))
                            }
                        ] + (store.volleyballSetResults.isEmpty ? [] : [
                            ActionDescriptor(title: "Undo & Return", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, isEnabled: !isResetInterlockActive) {
                                requestGameConfirmation(.undoVolleyballSet)
                            }
                        ]),
                        dense: layout.denseControls,
                        compactVerticalPadding: layout.advancedButtonVerticalPadding
                    )
                }
            }

            buttonGrid(
                columns: store.showsGameClock ? 2 : 1,
                buttons: store.showsGameClock ? [
                    ActionDescriptor(title: localizedAppFormat("Reset %@", formatClock(store.defaultClockSeconds)), tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isGameClockResetInterlockActive) {
                        requestGameConfirmation(.resetClock)
                    },
                    ActionDescriptor(title: "Zero Scores", tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isGameClockResetInterlockActive) {
                        requestGameConfirmation(.zeroScores)
                    }
                ] : [
                    ActionDescriptor(title: "Zero Scores", tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isGameClockResetInterlockActive) {
                        requestGameConfirmation(.zeroScores)
                    }
                ],
                style: .compact,
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.matchControls), isEnabled: arePopoverTipsEnabled, arrowEdge: .top))
    }

    private func chessGameControls(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizedAppFormat("%@ Controls", localizedAppString(store.selectedSport.title)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themePalette.dashboardPrimaryText)
                Spacer(minLength: 0)
                localizedAppText(store.selectedSport == .chess ? store.chessClockPreset.title : "Dual Clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themePalette.dashboardMutedText)
            }

            liveBoardSportGuidanceTip(layout: layout)

            actionButton(
                store.isClockRunning ? "Pause Active Clock" : "Start Active Clock",
                tint: themePalette.dashboardSuccessButton,
                foreground: themePalette.dashboardSuccessButtonText,
                titleFont: .title3.weight(.black),
                verticalPadding: layout.denseControls ? 16 : 20
            ) {
                store.toggleChessClock()
            }

            actionButton(
                "Switch Turn",
                tint: themePalette.dashboardWarningButton,
                foreground: themePalette.dashboardWarningButtonText,
                verticalPadding: layout.denseControls ? 14 : 18
            ) {
                store.switchChessClock()
            }

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "Swap Side", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.swapSides()
                    },
                    ActionDescriptor(title: "Reset Clocks", tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isResetInterlockActive) {
                        pendingGameConfirmation = .resetChessClocks
                    }
                ],
                dense: layout.denseControls
            )

            if store.supportsPeriod {
                buttonGrid(
                    columns: matchNavigationButtons.count,
                    buttons: matchNavigationButtons,
                    dense: layout.denseControls,
                    compactVerticalPadding: layout.advancedButtonVerticalPadding
                )
            }

            if store.supportsScore {
                buttonGrid(
                    columns: 1,
                    buttons: [
                        ActionDescriptor(title: "Zero Scores", tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isGameClockResetInterlockActive) {
                            requestGameConfirmation(.zeroScores)
                        }
                    ],
                    style: .compact,
                    dense: layout.denseControls,
                    compactVerticalPadding: layout.advancedButtonVerticalPadding
                )
            }
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.matchControls), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func debateStatusWidget(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    localizedAppText(store.currentDebatePreset.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(themePalette.dashboardPrimaryText)

                    debateControlSegmentTitle(idPrefix: "status")
                }

                Spacer(minLength: 0)

                localizedAppText(store.debateActiveTimer == .segment ? (store.isClockRunning ? "Running" : "Paused") : "Prep")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.isClockRunning || store.isDebatePrepClockRunning ? themePalette.dashboardStatusLive : themePalette.dashboardMutedText)
            }

            if store.currentDebateSegment?.timerMode == .dualClock {
                compactDualClockRow(layout: layout)
                    .id("status-dual-\(store.debateCurrentSegmentIndex)")
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if store.showsGameClock {
                Text(store.formattedClock)
                    .font(.system(size: layout.centerScoreSize + 10, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .singleLineFitted(minScale: 0.4)
                    .foregroundStyle(themePalette.dashboardPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentTransition(.numericText())
                    .id("status-master-\(store.debateCurrentSegmentIndex)")
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Text("No Active Segment Clock")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themePalette.dashboardMutedText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .id("status-none-\(store.debateCurrentSegmentIndex)")
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if store.showsDebatePrepTime {
                HStack(spacing: 10) {
                    compactDualClockBadge(
                        title: localizedAppFormat("%@ Prep", store.sideRoleLabel(for: .home)),
                        value: store.formattedDebatePrepHomeClock,
                        tint: homeTint,
                        isActive: store.debateActiveTimer == .prepHome,
                        layout: layout
                    )

                    compactDualClockBadge(
                        title: localizedAppFormat("%@ Prep", store.sideRoleLabel(for: .guest)),
                        value: store.formattedDebatePrepGuestClock,
                        tint: guestTint,
                        isActive: store.debateActiveTimer == .prepGuest,
                        layout: layout
                    )
                }
            }

            if store.supportsScore {
                HStack(spacing: 12) {
                    gameStateScoreColumn(
                        title: store.sideRoleLabel(for: .home),
                        score: store.homeScore,
                        tint: homeTint,
                        layout: layout
                    )

                    Text("-")
                        .font(.system(size: layout.centerScoreSize - 10, weight: .black, design: .rounded))
                        .foregroundStyle(themePalette.dashboardMutedText)

                    gameStateScoreColumn(
                        title: store.sideRoleLabel(for: .guest),
                        score: store.guestScore,
                        tint: guestTint,
                        layout: layout
                    )
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if store.isPlayerTrackingEnabled {
                Button {
                    dashboardPage = .players
                } label: {
                    Label("Open Players", systemImage: "person.3")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(themePalette.dashboardNeutralButtonText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(themePalette.dashboardNeutralButton, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.playerShortcut), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
            }
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: store.supportsScore)
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: store.showsDebatePrepTime)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: store.debateCurrentSegmentIndex)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: store.debateSpeakingSide)
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.gameState), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func debateGameControls(layout: InterfaceLayout) -> some View {
        let segment = store.currentDebateSegment
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    localizedAppText(store.currentDebatePreset.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(themePalette.dashboardPrimaryText)

                    debateControlSegmentTitle(idPrefix: "controls")
                }

                Spacer(minLength: 0)

                Text("Segment \(store.debateCurrentSegmentIndex + 1)/\(store.currentDebatePreset.segments.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themePalette.dashboardMutedText)
                    .contentTransition(.numericText())
            }

            liveBoardSportGuidanceTip(layout: layout)
            liveDebateSegmentModeTip(layout: layout)

            actionButton(
                store.debateActiveTimer == .segment
                    ? (store.isClockRunning ? "Pause Segment Timer" : "Start Segment Timer")
                    : "Return to Segment Timer",
                tint: themePalette.dashboardSuccessButton,
                foreground: themePalette.dashboardSuccessButtonText,
                titleFont: .title3.weight(.black),
                verticalPadding: layout.denseControls ? 16 : 20
            ) {
                if store.debateActiveTimer == .segment {
                    store.toggleClock()
                } else {
                    store.returnToDebateSegmentTimer()
                }
            }

            if store.debateActiveTimer == .segment, segment?.timerMode != DebateTimerMode.none {
                buttonGrid(
                    columns: 4,
                    buttons: debateSegmentJogButtons(
                        tint: segment?.timerMode == .dualClock ? debateActiveSideTint : themePalette.dashboardNeutralButton,
                        foreground: segment?.timerMode == .dualClock ? debateActiveSideText : themePalette.dashboardNeutralButtonText
                    ),
                    dense: layout.denseControls,
                    compactVerticalPadding: layout.advancedButtonVerticalPadding
                )
            }

            if segment?.timerMode == .dualClock && segment?.allowsSideSwitching == true {
                actionButton(
                    "Switch Active Side",
                    tint: themePalette.dashboardWarningButton,
                    foreground: themePalette.dashboardWarningButtonText,
                    verticalPadding: layout.denseControls ? 14 : 18
                ) {
                    store.switchChessClock()
                }
            }

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "Previous Segment", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            store.advanceDebateSegment(by: -1)
                        }
                    },
                    ActionDescriptor(title: "Next Segment", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            store.advanceDebateSegment(by: 1)
                        }
                    }
                ],
                dense: layout.denseControls
            )

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "Reset Segment", tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isResetInterlockActive) {
                        pendingGameConfirmation = .resetDebateSegment
                    },
                    ActionDescriptor(title: "Reset Round", tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isResetInterlockActive) {
                        pendingGameConfirmation = .resetDebateRound
                    }
                ],
                dense: layout.denseControls
            )

            if store.supportsScore {
                buttonGrid(
                    columns: 1,
                    buttons: [
                        ActionDescriptor(title: "Zero Scores", tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isGameClockResetInterlockActive) {
                            pendingGameConfirmation = .zeroScores
                        }
                    ],
                    style: .compact,
                    dense: layout.denseControls,
                    compactVerticalPadding: layout.advancedButtonVerticalPadding
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: store.supportsScore)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: store.debateCurrentSegmentIndex)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: store.debateSpeakingSide)
        .scoreboardPopoverTip(dashboardCurrentTourTip(matching: ScoreboardTips.matchControls), isEnabled: arePopoverTipsEnabled, arrowEdge: .top)
    }

    private func debateControlSegmentTitle(idPrefix: String) -> some View {
        let indicator = debateControlSpeakingSideIndicator

        return HStack(alignment: .center, spacing: 6) {
            if let indicator, indicator.pointsLeft {
                debateControlSpeakingSideArrow(systemName: indicator.systemName, color: indicator.color)
            }

            localizedAppText(store.debateSegmentTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themePalette.dashboardMutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .layoutPriority(1)

            if let indicator, !indicator.pointsLeft {
                debateControlSpeakingSideArrow(systemName: indicator.systemName, color: indicator.color)
            }
        }
        .id("\(idPrefix)-segment-title-\(store.debateCurrentSegmentIndex)-\(store.debateSegmentTitle)-\(store.debateSpeakingSide?.rawValue ?? "none")")
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var debateControlSpeakingSideIndicator: (systemName: String, color: Color, pointsLeft: Bool)? {
        guard let side = store.debateSpeakingSide else {
            return nil
        }

        let pointsLeft = side == store.resolvedControlBoardDisplayDirection.leftSide
        let color = side == .home ? homeTint : guestTint
        return (pointsLeft ? "arrow.left.circle.fill" : "arrow.right.circle.fill", color, pointsLeft)
    }

    private func debateControlSpeakingSideArrow(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.black))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private var debateActiveSideTint: Color {
        switch store.activeChessClockSide {
        case .home:
            return homeTint
        case .guest:
            return guestTint
        case .none:
            return themePalette.dashboardNeutralButton
        }
    }

    private var debateActiveSideText: Color {
        switch store.activeChessClockSide {
        case .home:
            return homeTintText
        case .guest:
            return guestTintText
        case .none:
            return themePalette.dashboardNeutralButtonText
        }
    }

    private func handleDebateTurnHere(for side: TeamSide) {
        if store.debateActiveTimer != .segment {
            store.returnToDebateSegmentTimer()
        }

        if store.activeChessClockSide == side {
            store.toggleChessClock()
        } else {
            store.setActiveChessClockSide(side)
            if !store.isClockRunning {
                store.toggleChessClock()
            }
        }
    }

    private func debateSegmentJogButtons(tint: Color, foreground: Color) -> [ActionDescriptor] {
        [
            ActionDescriptor(title: "-1 Min", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                adjustDebateSegmentTimer(by: -60)
            },
            ActionDescriptor(title: "+1 Min", tint: tint, foreground: foreground) {
                adjustDebateSegmentTimer(by: 60)
            },
            ActionDescriptor(title: "-1 Sec", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                adjustDebateSegmentTimer(by: -1)
            },
            ActionDescriptor(title: "+1 Sec", tint: tint.opacity(0.9), foreground: foreground) {
                adjustDebateSegmentTimer(by: 1)
            }
        ]
    }

    private func adjustDebateSegmentTimer(by delta: Int) {
        guard store.debateActiveTimer == .segment else {
            return
        }

        switch store.currentDebateSegment?.timerMode {
        case .some(.masterClock):
            store.adjustClock(by: delta)
        case .some(.dualClock):
            if let side = store.activeChessClockSide {
                store.adjustChessClock(for: side, by: delta)
            }
        case .some(.none), nil:
            break
        }
    }

    private func debatePrepInlinePanel(side: TeamSide, tint: Color, layout: InterfaceLayout) -> some View {
        let isHome = side == .home
        let isActive = store.debateActiveTimer == (isHome ? .prepHome : .prepGuest)
        let tintText = teamAccentText(for: side)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Prep Controls")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(themePalette.dashboardPrimaryText)

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(
                        title: isActive && store.isDebatePrepClockRunning ? "Pause Prep" : "Use Prep",
                        tint: isActive ? tint.opacity(0.82) : tint,
                        foreground: tintText
                    ) {
                        store.toggleDebatePrepClock(for: side)
                    },
                    ActionDescriptor(title: "Reset", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, isEnabled: !isResetInterlockActive) {
                        pendingGameConfirmation = .resetDebatePrep(side)
                    },
                    ActionDescriptor(title: "-15s", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustDebatePrepClock(for: side, by: -15)
                    },
                    ActionDescriptor(title: "+15s", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustDebatePrepClock(for: side, by: 15)
                    },
                ],
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(themePalette.dashboardCardBackground.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder.opacity(0.7))
        )
    }

    private func gameSummaryRow(layout: InterfaceLayout) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Game Clock")
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            Spacer(minLength: 0)

            localizedAppText(store.isClockRunning ? "Running" : "Stopped")
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(store.isClockRunning ? themePalette.dashboardStatusLive : themePalette.dashboardMutedText)
        }
    }

    private var periodWinStatusText: String {
        let periodLine: String
        if store.selectedSport == .volleyball {
            periodLine = localizedAppFormat(
                "Periods %d-%d • %@",
                store.homePeriodWins,
                store.guestPeriodWins,
                localizedAppString(store.volleyballMatchFormat.title)
            )
        } else {
            periodLine = localizedAppFormat("Periods %d-%d", store.homePeriodWins, store.guestPeriodWins)
        }

        guard let winner = store.periodWinMatchWinner else {
            return periodLine
        }

        return localizedAppFormat("%@ • %@ wins match", periodLine, store.sideRoleLabel(for: winner))
    }

    private var matchNavigationButtons: [ActionDescriptor] {
        if !store.supportsPeriod || store.supportsPeriodWinTracking {
            return [
                ActionDescriptor(title: "Swap Sides", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                    store.swapSides()
                }
            ]
        }

        return [
            ActionDescriptor(title: "Prev Period", tint: themePalette.destructiveTint, foreground: destructiveText, isEnabled: !isGameClockResetInterlockActive) {
                requestGameConfirmation(.previousPeriod)
            },
            ActionDescriptor(title: "Swap Sides", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                store.swapSides()
            },
            ActionDescriptor(title: localizedAppFormat("Next %@", localizedAppString(store.periodTitle)), tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText) {
                store.adjustPeriod(by: 1)
            }
        ]
    }

    private func buttonGrid(
        columns: Int,
        buttons: [ActionDescriptor],
        style: ButtonStyleVariant = .compact,
        dense: Bool = false,
        compactVerticalPadding: CGFloat? = nil
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, columns)),
            spacing: 10
        ) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                if style == .large {
                    actionButton(
                        button.title,
                        tint: button.tint,
                        foreground: button.foreground,
                        verticalPadding: dense ? 14 : 18,
                        isEnabled: button.isEnabled,
                        action: button.action
                    )
                } else {
                    smallActionButton(
                        button.title,
                        tint: button.tint,
                        foreground: button.foreground,
                        verticalPadding: compactVerticalPadding ?? (dense ? 10 : 14),
                        isEnabled: button.isEnabled,
                        action: button.action
                    )
                }
            }
        }
    }

    private func actionButton(
        _ title: String,
        tint: Color,
        foreground: Color = .white,
        titleFont: Font = .headline.weight(.bold),
        verticalPadding: CGFloat = 18,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            localizedAppText(title)
                .font(titleFont)
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, verticalPadding)
                .background(tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .opacity(isEnabled ? 1 : 0.42)
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }

    private func smallActionButton(
        _ title: String,
        tint: Color,
        foreground: Color = .white,
        verticalPadding: CGFloat = 14,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            localizedAppText(title)
                .font(.headline.weight(.bold))
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, verticalPadding)
                .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .opacity(isEnabled ? 1 : 0.42)
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }

    private func clockPresetOptions(for sport: SportType) -> [(String, Int)] {
        switch sport {
        case .simple:
            return stride(from: 5, through: 60, by: 5).map { minutes in
                ("\(minutes):00", minutes * 60)
            }
        case .basketball:
            return [("8:00", 8 * 60), ("10:00", 10 * 60), ("12:00", 12 * 60)]
        case .volleyball:
            return [("00:00", 0), ("15:00", 15 * 60), ("25:00", 25 * 60)]
        case .soccer:
            return [("40:00", 40 * 60), ("45:00", 45 * 60), ("50:00", 50 * 60)]
        case .hockey:
            return [("15:00", 15 * 60), ("20:00", 20 * 60), ("25:00", 25 * 60)]
        case .chess:
            return ChessClockPreset.allCases.map { ($0.title, $0.seconds) }
        case .debate:
            return [("5:00", 5 * 60), ("7:00", 7 * 60), ("8:00", 8 * 60), ("10:00", 10 * 60)]
        case .custom:
            return [("5:00", 5 * 60), ("10:00", 10 * 60), ("15:00", 15 * 60)]
        }
    }

    private func scoreButtons(forHomeTeam isHome: Bool, tint: Color) -> [ActionDescriptor] {
        let tintText = teamAccentText(isHome: isHome)

        if store.isDebateMode {
            return [
                ActionDescriptor(title: "-1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                    store.adjustScore(isHome: isHome, by: -1)
                },
                ActionDescriptor(title: "+1", tint: tint, foreground: tintText) {
                    store.adjustScore(isHome: isHome, by: 1)
                }
            ]
        }

        let sportButtons = store.currentRules.scoreStepOptions.map { value in
            ActionDescriptor(title: "+\(value)", tint: tint, foreground: tintText) {
                store.adjustScore(isHome: isHome, by: value)
            }
        }

        return sportButtons + [
            ActionDescriptor(title: "-1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                store.adjustScore(isHome: isHome, by: -1)
            }
        ]
    }

    private func substitutionControlRow(side: TeamSide, tint: Color, layout: InterfaceLayout) -> some View {
        let tintText = teamAccentText(for: side)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Subs \(store.substitutionsUsed(for: side))/\(store.substitutionsAllowed(for: side)) Used • \(store.substitutionsRemaining(for: side)) Left")
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardMutedText)

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "Swap -", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustSubstitutionsUsed(for: side, by: -1)
                    },
                    ActionDescriptor(
                        title: "Swap +",
                        tint: tint,
                        foreground: tintText,
                        isEnabled: store.substitutionsUsed(for: side) < store.substitutionsAllowed(for: side)
                    ) {
                        store.adjustSubstitutionsUsed(for: side, by: 1)
                    }
                ],
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )
        }
    }

    private func pauseControlRow(side: TeamSide, tint: Color, layout: InterfaceLayout) -> some View {
        let tintText = teamAccentText(for: side)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Pauses \(store.pausesUsed(for: side))/\(store.pausesAllowed(for: side)) Used • \(store.pausesRemaining(for: side)) Left")
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardMutedText)

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "Pause -", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustPausesUsed(for: side, by: -1)
                    },
                    ActionDescriptor(
                        title: "Pause +",
                        tint: tint,
                        foreground: tintText,
                        isEnabled: store.pausesUsed(for: side) < store.pausesAllowed(for: side)
                    ) {
                        store.adjustPausesUsed(for: side, by: 1)
                    }
                ],
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )
        }
    }

    private func hockeyPenaltyPanel(side: TeamSide, tint: Color, layout: InterfaceLayout) -> some View {
        let timers = side == .home ? store.homePenaltyTimers : store.guestPenaltyTimers
        let tintText = teamAccentText(for: side)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Penalty Bench")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themePalette.dashboardMutedText)

            buttonGrid(
                columns: 3,
                buttons: [
                    ActionDescriptor(title: "Add 2:00", tint: tint, foreground: tintText) { addPenaltyTimer(side: side, seconds: 120) },
                    ActionDescriptor(title: "Add 4:00", tint: tint.opacity(0.9), foreground: tintText) { addPenaltyTimer(side: side, seconds: 240) },
                    ActionDescriptor(title: "Add 5:00", tint: tint.opacity(0.8), foreground: tintText) { addPenaltyTimer(side: side, seconds: 300) }
                ],
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )

            ForEach(timers) { timer in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(timer.playerNumber.isEmpty ? "#" : "#\(timer.playerNumber)") \(timer.playerName.isEmpty ? localizedAppString("PLAYER") : timer.playerName)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(themePalette.dashboardPrimaryText)
                        Spacer(minLength: 0)
                        Text(formatClock(timer.remainingSeconds))
                            .font(.system(size: layout.centerMetricValueSize - 4, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                    }
                    buttonGrid(
                        columns: 4,
                        buttons: [
                            ActionDescriptor(title: timer.isRunning ? "Pause" : "Start", tint: themePalette.dashboardSuccessButton, foreground: themePalette.dashboardSuccessButtonText) {
                                store.togglePenaltyTimer(for: side, timerID: timer.id)
                            },
                            ActionDescriptor(title: "-1s", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                                store.adjustPenaltyTimer(for: side, timerID: timer.id, by: -1)
                            },
                            ActionDescriptor(title: "+1s", tint: tint, foreground: tintText) {
                                store.adjustPenaltyTimer(for: side, timerID: timer.id, by: 1)
                            },
                            ActionDescriptor(title: "Clear", tint: themePalette.destructiveTint, foreground: destructiveText) {
                                pendingGameConfirmation = .clearPenalty(side, timer.id)
                            }
                        ],
                        dense: layout.denseControls,
                        compactVerticalPadding: layout.advancedButtonVerticalPadding
                    )
                }
                .padding(10)
                .background(themePalette.dashboardCardBackground.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func addPenaltyTimer(side: TeamSide, seconds: Int) {
        if store.supportsPlayerTracking {
            pendingPenaltySelection = PendingPenaltySelection(side: side, seconds: seconds)
        } else {
            store.addPenaltyTimer(for: side, seconds: seconds, player: nil, startsRunning: true)
        }
    }

    private func penaltyPlayerSelectionSheet(_ selection: PendingPenaltySelection) -> some View {
        NavigationStack {
            List(store.trackedPlayers(for: selection.side)) { player in
                Button {
                    store.addPenaltyTimer(for: selection.side, seconds: selection.seconds, player: player, startsRunning: true)
                    pendingPenaltySelection = nil
                } label: {
                    HStack(spacing: 12) {
                        Text("#\(player.number.isEmpty ? "--" : player.number)")
                            .font(.headline.weight(.black))
                            .foregroundStyle(selection.side == .home ? homeTint : guestTint)
                            .frame(width: 54, alignment: .leading)

                        Text(player.name.isEmpty ? localizedAppString("PLAYER") : player.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(themePalette.dashboardPrimaryText)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(localizedAppFormat("Select %@ Player", localizedAppString(selection.side.title)))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        pendingPenaltySelection = nil
                    }
                }
            }
        }
    }

    private func handleRootAppear() {
        guard !didStartRootInitialization else {
            return
        }

        didStartRootInitialization = true
        Task {
            await bootstrapRootAfterFileMigration()
        }
    }

    @MainActor
    private func bootstrapRootAfterFileMigration() async {
        await migrateLegacyUserVisibleFilesIfNeeded()
        ensureDefaultCustomWebPageIfNeeded()
        initializeWorkingGameFile()
        isInitialSetupStateLoaded = true
        refreshStoredLogSessions()
        syncCurrentLogGameFile()
        store.refreshWebAPILocalAddresses()
        ScoreboardEasterEggIcon.applyPersistedSystemIcon()
        #if os(iOS)
        store.reconcileRunningTimersWithWallClock()
        store.syncLiveActivityForCurrentState()
        #endif
        updateIdleTimer(for: scenePhase)
        presentGettingStartedIfNeeded()
    }

    @MainActor
    private func migrateLegacyUserVisibleFilesIfNeeded() async {
        #if os(iOS)
        do {
            let result = try await ScoreboardFileStorage.migrateLegacyFilesToUserVisibleStorage { progress in
                withAnimation(.easeInOut(duration: 0.16)) {
                    fileMigrationProgress = progress
                }
            }

            if result.failedFiles > 0 {
                NSLog(
                    "Scoreboard migrated %lld of %lld legacy files to Files-visible storage; %lld failed.",
                    result.migratedFiles,
                    result.totalFiles,
                    result.failedFiles
                )
            }
        } catch {
            presentFileOperationError(error)
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            fileMigrationProgress = nil
        }
        #endif
    }

    private func ensureDefaultCustomWebPageIfNeeded() {
        #if ENABLE_CUSTOM_USER_PAGE
        do {
            try ScoreboardCustomWebPage.ensureDefaultPageIfNeeded()
        } catch {
            NSLog("Scoreboard failed to prepare default custom web page: %@", String(describing: error))
        }
        #endif
    }

    private func presentGettingStartedIfNeeded() {
        guard store.showGettingStartedOnStartup, !store.didAutoShowGettingStarted, !showsGettingStarted else {
            return
        }

        DispatchQueue.main.async {
            guard store.showGettingStartedOnStartup, !store.didAutoShowGettingStarted, !showsGettingStarted else {
                return
            }
            presentGettingStarted(auto: true)
        }
    }

    private func presentGettingStarted(auto: Bool) {
        isGettingStartedAutoPresentation = auto
        showsGettingStarted = true
    }

    private func closeGettingStarted() {
        showsGettingStarted = false
    }

    private func handleApplicationNameTapped() {
        if isBunnyIconEnabled {
            restoreOriginalAppIcon()
        } else {
            setBunnyIconEnabled(true, presentsSheet: true)
        }
    }

    private func restoreOriginalAppIcon() {
        setBunnyIconEnabled(false, presentsSheet: false)
        showsBunnyEasterEgg = false
    }

    private func setBunnyIconEnabled(_ isEnabled: Bool, presentsSheet: Bool) {
        let previousValue = isBunnyIconEnabled
        withAnimation(.easeInOut(duration: 0.18)) {
            isBunnyIconEnabled = isEnabled
        }
        if presentsSheet {
            showsBunnyEasterEgg = true
        }

        ScoreboardEasterEggIcon.applySystemIcon(isBunnyEnabled: isEnabled) { error in
            guard let error else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                isBunnyIconEnabled = previousValue
            }
            fileOperationError = FileOperationAlert(
                message: localizedAppFormat("Could not change app icon: %@", error.localizedDescription)
            )
        }
    }

    private func skipGettingStartedAndDisableTips() {
        isGettingStartedAutoPresentation = false
        store.skipGettingStartedAndDisableTips()
        showsGettingStarted = false
    }

    private func resetScoreboardTips() {
        #if os(iOS) || os(macOS)
        let nextGeneration = tipHistoryResetGeneration + 1
        tipHistoryResetGeneration = nextGeneration
        UserDefaults.standard.set(nextGeneration, forKey: Self.tipHistoryResetGenerationKey)
        store.areTipsEnabled = true

        if #available(iOS 26.0, macOS 26.0, *) {
            Task {
                await ScoreboardTips.resetTipEligibility()
            }
        }
        #endif
    }

    private func handleGettingStartedDismissed() {
        if isGettingStartedAutoPresentation {
            store.markGettingStartedAutoShown()
        }
        isGettingStartedAutoPresentation = false
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        updateIdleTimer(for: newPhase)

        #if os(iOS)
        switch newPhase {
        case .active:
            ScoreboardBackgroundCoordinator.shared.handleAppDidBecomeActive(store: store)
        case .background:
            ScoreboardBackgroundCoordinator.shared.handleAppDidEnterBackground(store: store)
        case .inactive:
            break
        @unknown default:
            break
        }
        #else
        if newPhase == .active {
            store.resumeWebAPIForAppLifecycle()
            store.refreshWebAPILocalAddresses()
        } else {
            store.suspendWebAPIForAppLifecycle()
        }
        #endif

        if newPhase != .active {
            autosaveSelectedGameFile(refreshSelection: true)
        }
    }

    private func handlePlayerTrackingEnabledChange(_ isEnabled: Bool) {
        if !isEnabled {
            dashboardPage = .main
        }
    }

    private func contentRoot(layout: InterfaceLayout) -> some View {
        ZStack {
            if showsSetup {
                LinearGradient(
                    colors: themePalette.appSetupBackground,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .transition(.opacity)
            } else {
                LinearGradient(
                    colors: themePalette.appDashboardBackground,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            if showsSetup {
                setupScreen(layout: layout)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.985)),
                        removal: .opacity.combined(with: .scale(scale: 1.015))
                    ))
            } else {
                dashboard(layout: layout)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.985)),
                        removal: .opacity.combined(with: .scale(scale: 1.015))
                    ))
            }

            if !showsSetup, store.companionFailureNotice != nil || store.remoteDisplayWarningNotice != nil {
                VStack {
                    VStack(spacing: 12) {
                        if let notice = store.companionFailureNotice {
                            companionFailureBanner(notice)
                        }

                        if let notice = store.remoteDisplayWarningNotice {
                            remoteDisplayWarningBanner(notice)
                        }
                    }
                    .padding(.top, layout.outerPadding + 8)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, layout.outerPadding)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let fileMigrationProgress, !showsSetup {
                fileMigrationOverlay(fileMigrationProgress, layout: layout)
                    .transition(.opacity)
                    .zIndex(40)
            }

            #if os(iOS)
            if !showsSetup, showsLocalScoreboard {
                localScoreboardOverlay()
                    .transition(.opacity)
                    .zIndex(20)
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.24), value: showsSetup)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: store.companionFailureNotice?.id)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: store.remoteDisplayWarningNotice?.id)
        #if os(iOS)
        .animation(.easeInOut(duration: 0.18), value: showsLocalScoreboard)
        #endif
    }

    #if os(iOS)
    private func localScoreboardOverlay() -> some View {
        GeometryReader { proxy in
            ZStack {
                if shouldShowLocalScoreboardIPhoneLandscapePrompt(in: proxy.size) {
                    localScoreboardIPhoneLandscapePrompt()
                } else {
                    ExternalScoreboardView()
                        .ignoresSafeArea()
                }

                if showsLocalScoreboardReturnHint {
                    VStack {
                        localScoreboardReturnHint()
                            .padding(.top, localScoreboardReturnHintTopPadding(in: proxy))

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    exitLocalScoreboardMode()
                }
            )
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            AppSleepPrevention.setReason(.localScoreboardVisible, active: true)
        }
        .onDisappear {
            AppSleepPrevention.setReason(.localScoreboardVisible, active: false)
            cancelLocalScoreboardReturnHint()
        }
        .accessibilityLabel(localizedAppString("Local Scoreboard"))
        .accessibilityHint(localizedAppString("Tap anywhere on screen to return to the control board."))
    }

    private func localScoreboardReturnHintTopPadding(in proxy: GeometryProxy) -> CGFloat {
        let basePadding = CGFloat(18)
        let safeTopPadding = proxy.safeAreaInsets.top + basePadding

        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return safeTopPadding
        }

        guard proxy.size.height > proxy.size.width else {
            return safeTopPadding
        }

        return max(safeTopPadding, 78)
    }

    private func localScoreboardReturnHint() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black.opacity(0.84))
                .accessibilityHidden(true)

            Text("Tap anywhere on screen to return to the control board.")
                .font(.callout.weight(.bold))
                .foregroundStyle(.black.opacity(0.86))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .frame(maxWidth: 460)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func localScoreboardIPhoneLandscapePrompt() -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.05),
                    Color(red: 0.04, green: 0.09, blue: 0.08),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "iphone.landscape")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    Text("Turn iPhone to Landscape")
                        .font(.title2.weight(.black))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text("Local Scoreboard is live. Rotate iPhone to show the scoreboard on this screen.")
                        .font(.callout.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaPadding(.horizontal, 18)
        .safeAreaPadding(.vertical, 16)
    }

    private func shouldShowLocalScoreboardIPhoneLandscapePrompt(in size: CGSize) -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone && size.height > size.width
    }

    private func scheduleLocalScoreboardReturnHintDismissal() {
        localScoreboardReturnHintDismissTask?.cancel()
        localScoreboardReturnHintDismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard showsLocalScoreboard else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsLocalScoreboardReturnHint = false
                }
                localScoreboardReturnHintDismissTask = nil
            }
        }
    }

    private func cancelLocalScoreboardReturnHint() {
        localScoreboardReturnHintDismissTask?.cancel()
        localScoreboardReturnHintDismissTask = nil
        showsLocalScoreboardReturnHint = false
    }

    private func showLocalScoreboardReturnHint() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showsLocalScoreboardReturnHint = true
        }
        scheduleLocalScoreboardReturnHintDismissal()
    }

    private func enterLocalScoreboardMode() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showsLocalScoreboard = true
        }
        showLocalScoreboardReturnHint()
    }

    private func exitLocalScoreboardMode() {
        dashboardPage = .main
        cancelLocalScoreboardReturnHint()
        withAnimation(.easeInOut(duration: 0.18)) {
            showsLocalScoreboard = false
        }
    }
    #endif

    private func companionFailureBanner(_ notice: ScoreboardCompanionFailureNotice) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.weight(.black))
                .foregroundStyle(themePalette.destructiveTint)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.94), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(notice.message)
                    .font(.title3.weight(.black))
                    .foregroundStyle(destructiveText)

                Text(notice.detail)
                    .font(.body.weight(.semibold))
                    .lineLimit(3)
                    .foregroundStyle(destructiveText.opacity(0.92))
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 10) {
                Text("FAILED")
                    .font(.caption.weight(.black))
                    .foregroundStyle(themePalette.destructiveTint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.94), in: Capsule())

                Button {
                    store.dismissCompanionFailureNotice()
                } label: {
                    Label("Dismiss", systemImage: "xmark")
                        .font(.subheadline.weight(.black))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(themePalette.destructiveTint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.94), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedAppString("Dismiss Companion failure"))
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: 720, alignment: .leading)
        .background(themePalette.destructiveTint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: themePalette.destructiveTint.opacity(0.42), radius: 24, y: 10)
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 8)
    }

    private func remoteDisplayWarningBanner(_ notice: ScoreboardRemoteDisplayWarningNotice) -> some View {
        let warningTint = themePalette.dashboardWarningButton
        let warningForeground = themePalette.dashboardWarningButtonText

        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.weight(.black))
                .foregroundStyle(.black)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.94), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(notice.message)
                    .font(.title3.weight(.black))
                    .foregroundStyle(warningForeground)

                Text(notice.detail)
                    .font(.body.weight(.semibold))
                    .lineLimit(3)
                    .foregroundStyle(warningForeground.opacity(0.90))
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 10) {
                Text("WARNING")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.94), in: Capsule())

                Button {
                    store.dismissRemoteDisplayWarningNotice()
                } label: {
                    Label("Dismiss", systemImage: "xmark")
                        .font(.subheadline.weight(.black))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.94), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedAppString("Dismiss Remote Display warning"))
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: 720, alignment: .leading)
        .background(warningTint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: warningTint.opacity(0.42), radius: 24, y: 10)
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 8)
    }

    private func teamFoulControlRow(side: TeamSide, tint: Color, layout: InterfaceLayout) -> some View {
        let tintText = teamAccentText(for: side)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Team Fouls \(store.teamFouls(for: side))")
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardMutedText)

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "Foul -", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustTeamFouls(for: side, by: -1)
                    },
                    ActionDescriptor(title: "Foul +", tint: tint, foreground: tintText) {
                        store.adjustTeamFouls(for: side, by: 1)
                    }
                ],
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )
        }
    }

    private func formatClock(_ seconds: Int) -> String {
        ScoreboardStore.formatGameClock(seconds)
    }

    private func teamAccentText(isHome: Bool) -> Color {
        isHome ? homeTintText : guestTintText
    }

    private func teamAccentText(for side: TeamSide) -> Color {
        side == .home ? homeTintText : guestTintText
    }

    private func cardStatusColor(_ status: PlayerCardStatus) -> Color {
        switch status {
        case .none:
            return settingsPalette.secondaryText
        case .yellow:
            return .yellow
        case .red:
            return .red
        }
    }

    private func toggledCardStatus(_ target: PlayerCardStatus, current: PlayerCardStatus) -> PlayerCardStatus {
        current == target ? .none : target
    }

    private func resetSetupDraftsToDefaults() {
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
    }

    private func openSettingsFromLiveBoard() {
        isLoadingSetupDrafts = true
        isInitialSetupStateLoaded = false
        loadSetupDraftsFromStore(keepsLoadingFlag: true)
        normalizeSetupCustomDebatePreset()
        selectedSettingsPane = .game
        withAnimation(.easeInOut(duration: 0.24)) {
            showsSetup = true
        }
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                isInitialSetupStateLoaded = true
                isLoadingSetupDrafts = false
            }
        }
    }

    private func createNewGame() {
        resetSetupDraftsToDefaults()
        selectedStoredGameFileID = nil
        gameFileNameDraft = ""
        selectedSettingsPane = .game
        withAnimation(.easeInOut(duration: 0.24)) {
            showsSetup = true
        }
    }

    private func swapSetupSides() {
        swap(&homeTeamDraft, &guestTeamDraft)
    }

    private func openSetupGame() {
        if focusedSettingsTextFieldID != nil {
            focusedSettingsTextFieldID = nil
            DispatchQueue.main.async {
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

    private func handleSetupDraftChanged() {
        guard !isSetupDraftUpdateSuppressed else {
            return
        }

        commitSetupEdits(animated: true)
    }

    private func makeDraftSnapshot() -> ScoreboardGameSnapshot {
        let draftClockSeconds = setupSport == .debate ? setupDebateOpeningSegmentSeconds : setupClockSeconds
        let draftGuestClockSeconds = setupSport == .debate ? setupDebateOpeningSegmentSeconds : setupGuestClockSeconds
        let tracksPeriodWins = setupSport == .volleyball ||
            (setupSport == .custom && resolvedSetupCustomSportConfig.isPeriodWinTrackingEnabled)

        return ScoreboardGameSnapshot(
            fileVersion: 11,
            sport: setupSport,
            customSportConfig: setupSport == .custom ? resolvedSetupCustomSportConfig : nil,
            customDebatePreset: setupSport == .debate
                ? (setupDebatePresetID == DebatePreset.customID ? resolvedSetupCustomDebatePreset : setupCustomDebatePreset)
                : nil,
            homeTeamName: homeTeamDraft,
            guestTeamName: guestTeamDraft,
            eventName: eventNameDraft,
            homeScore: 0,
            guestScore: 0,
            period: setupPeriod,
            volleyballMatchFormat: setupSport == .volleyball ? setupVolleyballMatchFormat : nil,
            volleyballSetResults: tracksPeriodWins ? [] : nil,
            gameClockSeconds: draftClockSeconds,
            defaultClockSeconds: draftClockSeconds,
            isGameClockEnabled: setupSport == .volleyball || setupSport == .custom ? setupUsesGameClock : true,
            shotClockMilliseconds: setupRules.supportsShotClock ? setupShotClockSeconds * 1_000 : 0,
            defaultShotClockSeconds: setupRules.supportsShotClock ? setupShotClockSeconds : 0,
            activeShotClockPresetSeconds: setupRules.supportsShotClock ? setupShotClockSeconds : 0,
            possessionDirection: .none,
            areSidesSwapped: false,
            isPlayerTrackingEnabled: store.isPlayerTrackingEnabled,
            isPlayerOverlayPaused: store.isPlayerOverlayPaused,
            rosterSizePerTeam: store.rosterSizePerTeam,
            displayLineupSize: store.displayLineupSize,
            playerLineupOverflowMode: store.playerLineupOverflowMode,
            playerLineupOverflowLogoOverride: store.playerLineupOverflowLogoOverride,
            playerLineupOverflowNoLogoOverride: store.playerLineupOverflowNoLogoOverride,
            playerLineupFadePageSeconds: store.playerLineupFadePageSeconds,
            playerLineupScrollSpeed: store.playerLineupScrollSpeed,
            playerLineupScrollDirection: store.playerLineupScrollDirection,
            playerFoulHighlightColor: store.playerFoulHighlightColor,
            isGameClockRedEnabled: store.isGameClockRedEnabled,
            gameClockRedThresholdSeconds: store.gameClockRedThresholdSeconds,
            isShotClockRedEnabled: store.isShotClockRedEnabled,
            shotClockRedThresholdSeconds: store.shotClockRedThresholdSeconds,
            homeSubstitutionsAllowed: setupRules.showsSubstitutionTracking ? store.homeSubstitutionsAllowed : 0,
            guestSubstitutionsAllowed: setupRules.showsSubstitutionTracking ? store.guestSubstitutionsAllowed : 0,
            homeSubstitutionsUsed: setupRules.showsSubstitutionTracking ? store.homeSubstitutionsUsed : 0,
            guestSubstitutionsUsed: setupRules.showsSubstitutionTracking ? store.guestSubstitutionsUsed : 0,
            homePausesAllowed: setupRules.showsPauseTracking ? store.homePausesAllowed : 0,
            guestPausesAllowed: setupRules.showsPauseTracking ? store.guestPausesAllowed : 0,
            homePausesUsed: setupRules.showsPauseTracking ? store.homePausesUsed : 0,
            guestPausesUsed: setupRules.showsPauseTracking ? store.guestPausesUsed : 0,
            homeTeamFouls: store.homeTeamFouls,
            guestTeamFouls: store.guestTeamFouls,
            homeChessClockSeconds: setupRules.usesChessClocks ? draftClockSeconds : nil,
            guestChessClockSeconds: setupRules.usesChessClocks ? draftGuestClockSeconds : nil,
            activeChessClockSide: setupRules.usesChessClocks ? .home : nil,
            chessClockPreset: setupSport == .chess ? setupChessPreset : nil,
            selectedDebatePresetID: setupSport == .debate ? setupDebatePresetID : nil,
            debateHomeSideLabel: setupSport == .debate ? setupDebateHomeSideLabel : nil,
            debateGuestSideLabel: setupSport == .debate ? setupDebateGuestSideLabel : nil,
            debateCurrentSegmentIndex: setupSport == .debate ? 0 : nil,
            debatePrepHomeSeconds: setupSport == .debate && setupDebatePrepTimeEnabled ? setupDebatePreset.prepSecondsPerSide : nil,
            debatePrepGuestSeconds: setupSport == .debate && setupDebatePrepTimeEnabled ? setupDebatePreset.prepSecondsPerSide : nil,
            isDebatePrepTimeEnabled: setupSport == .debate ? setupDebatePrepTimeEnabled : nil,
            debateActiveTimer: setupSport == .debate ? .segment : nil,
            isDebatePrepClockRunning: setupSport == .debate ? false : nil,
            isDebateScoreTrackingEnabled: setupSport == .debate ? setupDebateScoreTrackingEnabled : nil,
            isDebatePlayerTrackingEnabled: setupSport == .debate ? setupDebatePlayerTrackingEnabled : nil,
            isDebatePlayerFoulsEnabled: setupSport == .debate ? setupDebatePlayerTrackingEnabled && setupDebatePlayerFoulsEnabled : nil,
            isDebatePlayerCardsEnabled: setupSport == .debate ? setupDebatePlayerTrackingEnabled && setupDebatePlayerCardsEnabled : nil,
            homePenaltyTimers: [],
            guestPenaltyTimers: [],
            homeRoster: store.homeRoster,
            guestRoster: store.guestRoster,
            externalDisplayBackgroundMode: store.externalDisplayBackgroundMode,
            externalDisplayBackgroundImage: store.currentGameSnapshot().externalDisplayBackgroundImage,
            externalDisplayAnimatedLogoStyle: store.externalDisplayAnimatedLogoStyle,
            externalDisplayAnimatedLogoBackgroundColor: store.externalDisplayAnimatedLogoBackgroundColor,
            externalDisplayAnimatedLogoSpeed: store.externalDisplayAnimatedLogoSpeed,
            externalDisplayAnimatedLogoSize: store.externalDisplayAnimatedLogoSize,
            externalDisplayAnimatedLogoOpacity: store.externalDisplayAnimatedLogoOpacity,
            showsExternalDisplayDateTime: store.showsExternalDisplayDateTime,
            externalDisplayDateTimeFormat: store.externalDisplayDateTimeFormat,
            showsExternalDisplayDateTimeSeconds: store.showsExternalDisplayDateTimeSeconds,
            showsTeamLogos: store.showsTeamLogos,
            showsEventLogo: store.showsEventLogo,
            playerViewRosterScope: .fullRoster,
            homeTeamLogoImage: store.currentGameSnapshot().homeTeamLogoImage,
            guestTeamLogoImage: store.currentGameSnapshot().guestTeamLogoImage,
            eventLogoImage: store.currentGameSnapshot().eventLogoImage
        )
    }

    private func prepareDraftExport() {
        presentGameExport(snapshot: makeDraftSnapshot(), defaultFilename: suggestedGameFilename(homeTeamDraft, guestTeamDraft))
    }

    private func prepareLiveGameExport() {
        presentGameExport(snapshot: store.currentGameSnapshot(), defaultFilename: suggestedGameFilename(store.homeTeamName, store.guestTeamName))
    }

    private func createStoredGameFromDraft() {
        do {
            let snapshot = currentSetupWorkingSnapshot()
            let preferredFilename = resolvedGameFilenameDraft(homeTeamDraft, guestTeamDraft)
            let url = try uniqueStoredGameFileURL(preferredFilename: preferredFilename)
            try writeGameSnapshot(snapshot, to: url)
            refreshStoredGameFiles(selectedURL: url)
            store.applyGameSnapshot(snapshot)
            loadSetupDraftsFromStore()
            gameFileNameDraft = url.deletingPathExtension().lastPathComponent
            recordFileLog(
                kind: .fileCreate,
                summary: "Create game file",
                outcome: .applied,
                fileURL: url
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func importGameIntoLibrary(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else {
                return
            }

            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let data = try readImportedFileData(from: sourceURL)
            let snapshot = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: data)
            let destinationURL = try uniqueStoredGameFileURL(preferredFilename: sourceURL.lastPathComponent)

            try data.write(to: destinationURL, options: .atomic)

            refreshStoredGameFiles(selectedURL: destinationURL)
            store.applyGameSnapshot(snapshot)
            loadSetupDraftsFromStore()
            recordFileLog(
                kind: .fileImport,
                summary: "Import game file",
                outcome: .applied,
                fileURL: destinationURL,
                notes: sourceURL.lastPathComponent
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func exportRosterCSV(destination: ExportDestination = .share) {
        let data = ScoreboardRosterCSV.exportData(homeRoster: store.homeRoster, guestRoster: store.guestRoster)
        presentExport(
            data: data,
            contentType: .commaSeparatedText,
            defaultFilename: "Scoreboard Roster.csv",
            destination: destination
        )
        recordFileLog(
            kind: .fileExport,
            summary: "Export roster CSV",
            outcome: .applied,
            notes: "Player roster CSV"
        )
    }

    private func importRosterCSV(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else {
                return
            }

            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let data = try readImportedFileData(from: sourceURL)
            let importedRoster = try ScoreboardRosterCSV.importData(data)
            store.replaceRosters(
                home: importedRoster.homeRoster,
                guest: importedRoster.guestRoster,
                rosterSize: importedRoster.rosterSize
            )
            autosaveSelectedGameFile(refreshSelection: true)
            recordFileLog(
                kind: .fileImport,
                summary: "Import roster CSV",
                outcome: .applied,
                notes: sourceURL.lastPathComponent
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func prepareFullBackup(destination: ExportDestination = .share) {
        do {
            autosaveSelectedGameFileImmediately(refreshSelection: true)
            logManager.flushPendingWrites()
            let backup = try makeFullBackup()
            let data = try ScoreboardAppBackup.makeEncoder().encode(backup)
            presentExport(
                data: data,
                contentType: .scoreboardBackup,
                defaultFilename: "Scoreboard Backup \(backupTimestamp()).scoreboardbackup",
                destination: destination
            )
            recordFileLog(
                kind: .fileExport,
                summary: "Export app backup",
                outcome: .applied,
                notes: "Full app backup"
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func importBackupForRestore(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else {
                return
            }

            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let data = try readImportedFileData(from: sourceURL)
            let backup = try ScoreboardAppBackup.makeDecoder().decode(ScoreboardAppBackup.self, from: data)
            try validateFullBackup(backup)
            pendingBackupRestore = PendingBackupRestore(backup: backup, sourceFilename: sourceURL.lastPathComponent)
        } catch {
            presentFileOperationError(error)
        }
    }

    private func makeFullBackup() throws -> ScoreboardAppBackup {
        ScoreboardAppBackup(
            schemaVersion: ScoreboardAppBackup.currentSchemaVersion,
            createdAt: Date(),
            appVersion: appVersionLine,
            selectedGameFilename: selectedStoredGameFile?.url.lastPathComponent,
            persistedStateData: try store.exportPersistedStateData(),
            storedGameFiles: try storedGameBackupFiles(),
            logSessions: try logManager.backupFiles()
        )
    }

    private func validateFullBackup(_ backup: ScoreboardAppBackup) throws {
        try backup.validateSchema()
        try store.validatePersistedStateData(backup.persistedStateData)
        try validateStoredGameBackupFiles(backup.storedGameFiles)
        try logManager.validateBackupFiles(backup.logSessions)
    }

    private func restoreFullBackup(_ backup: ScoreboardAppBackup) {
        do {
            try validateFullBackup(backup)
            discardPendingGameFileAutosaves()
            try replaceStoredGameFiles(with: backup.storedGameFiles)
            try logManager.replaceSessions(with: backup.logSessions)
            try store.restorePersistedStateData(backup.persistedStateData)

            selectedGameFileIDs.removeAll()
            selectedLogSessionIDs.removeAll()
            isSelectingGameFiles = false
            isSelectingLogSessions = false

            let selectedURL = try restoredStoredGameURL(named: backup.selectedGameFilename)
            refreshStoredGameFiles(selectedURL: selectedURL)
            refreshStoredLogSessions()
            loadSetupDraftsFromStore()
            syncCurrentLogGameFile()
            showsSetup = true
            selectedSettingsPane = .files
        } catch {
            presentFileOperationError(error)
        }
    }

    private func performFactoryDefaultReset() {
        do {
            try deleteAllStoredGameFiles()
            try logManager.replaceSessions(with: [])
            #if ENABLE_CUSTOM_USER_PAGE
            try ScoreboardCustomWebPage.deleteAll()
            try ScoreboardCustomWebPage.ensureDefaultPageIfNeeded()
            #endif
            store.resetToFactoryDefaults()

            storedGameFiles = []
            selectedStoredGameFileID = nil
            renameGameFileNameDraft = ""
            selectedGameFileIDs.removeAll()
            isSelectingGameFiles = false
            selectedLogSessionIDs.removeAll()
            isSelectingLogSessions = false
            refreshStoredGameFiles()
            refreshStoredLogSessions()
            resetSetupDraftsToDefaults()
            loadSetupDraftsFromStore()
            syncCurrentLogGameFile()
            dashboardPage = .main
            selectedSettingsPane = .game
            showsSetup = true
        } catch {
            presentFileOperationError(error)
        }
    }

    private func beginGameImport() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = macOSGameImportContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK else {
                return
            }

            importGameIntoLibrary(.success(panel.urls))
        }
        #else
        showsGameImporter = true
        #endif
    }

    private func beginBackupRestore() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = macOSBackupImportContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK else {
                return
            }

            importBackupForRestore(.success(panel.urls))
        }
        #else
        showsBackupImporter = true
        #endif
    }

    private func beginRosterCSVImport() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = macOSRosterCSVImportContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK else {
                return
            }

            importRosterCSV(.success(panel.urls))
        }
        #else
        showsRosterCSVImporter = true
        #endif
    }

    private func beginExternalBackgroundImageImport() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = macOSImageImportContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else {
                pendingExternalBackgroundModeAfterImageImport = nil
                return
            }

            importExternalBackgroundImageFile(url)
        }
        #else
        isExternalBackgroundImageEditorVisible = true
        #endif
    }

    private func beginTeamLogoImageImport(for side: TeamSide) {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = macOSImageImportContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else {
                return
            }

            importTeamLogoImageFile(url, for: side)
        }
        #endif
    }

    private func beginEventLogoImageImport() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = macOSImageImportContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else {
                return
            }

            importEventLogoImageFile(url)
        }
        #endif
    }

    #if os(macOS)
    private func importExternalBackgroundImageFile(_ sourceURL: URL) {
        do {
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let data = try readImportedFileData(from: sourceURL)
            applyExternalBackgroundImageData(data, sourceName: sourceURL.lastPathComponent)
        } catch {
            presentFileOperationError(error)
        }
    }

    private func importTeamLogoImageFile(_ sourceURL: URL, for side: TeamSide) {
        do {
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let data = try readImportedFileData(from: sourceURL)
            applyTeamLogoImageData(data, sourceName: sourceURL.lastPathComponent, for: side)
        } catch {
            presentFileOperationError(error)
        }
    }

    private func importEventLogoImageFile(_ sourceURL: URL) {
        do {
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let data = try readImportedFileData(from: sourceURL)
            applyEventLogoImageData(data, sourceName: sourceURL.lastPathComponent)
        } catch {
            presentFileOperationError(error)
        }
    }
    #endif

    #if os(iOS)
    @MainActor
    private func importExternalBackgroundPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ScoreboardDisplayImageError.unreadableImage
            }

            applyExternalBackgroundImageData(data, sourceName: item.itemIdentifier)
        } catch {
            presentFileOperationError(error)
        }
    }

    @MainActor
    private func importTeamLogoPhoto(_ item: PhotosPickerItem, for side: TeamSide) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ScoreboardDisplayImageError.unreadableImage
            }

            applyTeamLogoImageData(data, sourceName: item.itemIdentifier, for: side)
        } catch {
            presentFileOperationError(error)
        }
    }

    @MainActor
    private func importEventLogoPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ScoreboardDisplayImageError.unreadableImage
            }

            applyEventLogoImageData(data, sourceName: item.itemIdentifier)
        } catch {
            presentFileOperationError(error)
        }
    }
    #endif

    private func applyExternalBackgroundImageData(_ data: Data, sourceName: String?) {
        do {
            let image = try ScoreboardDisplayImageProcessor.makeBackgroundImage(from: data, sourceName: sourceName)
            let pendingMode = pendingExternalBackgroundModeAfterImageImport
            store.setExternalDisplayBackgroundImage(image)
            if let pendingMode {
                store.externalDisplayBackgroundMode = pendingMode
            }
            pendingExternalBackgroundModeAfterImageImport = nil
            isExternalBackgroundImageEditorVisible = true
            autosaveSelectedGameFile(refreshSelection: true)
        } catch {
            pendingExternalBackgroundModeAfterImageImport = nil
            presentFileOperationError(error)
        }
    }

    private func applyTeamLogoImageData(_ data: Data, sourceName: String?, for side: TeamSide) {
        do {
            let image = try ScoreboardDisplayImageProcessor.makeTeamLogo(from: data, sourceName: sourceName)
            store.setTeamLogoImage(image, for: side)
            autosaveSelectedGameFile(refreshSelection: true)
        } catch {
            presentFileOperationError(error)
        }
    }

    private func applyEventLogoImageData(_ data: Data, sourceName: String?) {
        do {
            let image = try ScoreboardDisplayImageProcessor.makeEventLogo(from: data, sourceName: sourceName)
            store.setEventLogoImage(image)
            autosaveSelectedGameFile(refreshSelection: true)
        } catch {
            presentFileOperationError(error)
        }
    }

    private func readImportedFileData(from url: URL) throws -> Data {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var coordinatedReadResult: Result<Data, Error>?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            coordinatedReadResult = Result {
                try Data(contentsOf: coordinatedURL)
            }
        }

        if let coordinatedReadResult {
            return try coordinatedReadResult.get()
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw coordinationError ?? error
        }
    }

    private func presentGameExport(
        snapshot: ScoreboardGameSnapshot,
        defaultFilename: String,
        destination: ExportDestination = .share
    ) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            presentExport(data: data, contentType: .scoreboardGame, defaultFilename: defaultFilename, destination: destination)
        } catch {
            presentFileOperationError(error)
        }
    }

    private func presentLogExport(
        data: Data,
        contentType: UTType,
        defaultFilename: String,
        destination: ExportDestination
    ) {
        presentExport(data: data, contentType: contentType, defaultFilename: defaultFilename, destination: destination)
    }

    private func presentExport(
        data: Data,
        contentType: UTType,
        defaultFilename: String,
        destination: ExportDestination
    ) {
        switch destination {
        case .share:
            presentShareExport(data: data, defaultFilename: defaultFilename)
        case .file:
            #if os(macOS)
            presentMacOSSavePanel(data: data, contentType: contentType, defaultFilename: defaultFilename)
            #else
            presentShareExport(data: data, defaultFilename: defaultFilename)
            #endif
        }
    }

    private func presentShareExport(data: Data, defaultFilename: String) {
        do {
            let url = try temporaryExportURL(defaultFilename: defaultFilename)
            try data.write(to: url, options: .atomic)
            exportSharePayload = ExportSharePayload(url: url)
        } catch {
            presentFileOperationError(error)
        }
    }

    #if os(macOS)
    private func presentMacOSSavePanel(data: Data, contentType: UTType, defaultFilename: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultFilename
        panel.begin { response in
            guard response == .OK, let destinationURL = panel.url else {
                return
            }

            do {
                try data.write(to: destinationURL, options: .atomic)
            } catch {
                presentFileOperationError(error)
            }
        }
    }
    #endif

    private func exportSelectedStoredGame(destination: ExportDestination = .share) {
        do {
            guard let selectedURL = selectedStoredGameFile?.url else {
                return
            }

            flushPendingGameFileAutosave(for: selectedURL)
            let snapshot = try loadGameSnapshot(from: selectedURL)
            presentGameExport(snapshot: snapshot, defaultFilename: selectedURL.lastPathComponent, destination: destination)
            recordFileLog(
                kind: .fileExport,
                summary: "Export game file",
                outcome: .applied,
                fileURL: selectedURL
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func openSelectedStoredGame() {
        guard let selectedStoredGameFile else {
            return
        }

        flushPendingGameFileAutosave(for: selectedStoredGameFile.url)
        loadStoredGameFile(selectedStoredGameFile)
    }

    private func deleteSelectedStoredGame() {
        guard let selectedStoredGameFile else {
            return
        }

        deleteStoredGame(selectedStoredGameFile)
    }

    private func deleteStoredGame(_ gameFile: StoredGameFile) {
        do {
            discardPendingGameFileAutosave(for: gameFile.url)
            try FileManager.default.removeItem(at: gameFile.url)
            selectedGameFileIDs.remove(gameFile.id)
            refreshStoredGameFiles()
            recordFileLog(
                kind: .fileDelete,
                summary: "Delete game file",
                outcome: .applied,
                fileURL: gameFile.url
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func deleteSelectedStoredGames() {
        let filesToDelete = storedGameFiles.filter { selectedGameFileIDs.contains($0.id) }
        guard !filesToDelete.isEmpty else {
            return
        }

        do {
            for gameFile in filesToDelete {
                discardPendingGameFileAutosave(for: gameFile.url)
                try FileManager.default.removeItem(at: gameFile.url)
                recordFileLog(
                    kind: .fileDelete,
                    summary: "Delete game file",
                    outcome: .applied,
                    fileURL: gameFile.url
                )
            }

            selectedGameFileIDs.removeAll()
            isSelectingGameFiles = false
            refreshStoredGameFiles()
        } catch {
            presentFileOperationError(error)
        }
    }

    private func renameSelectedStoredGame() {
        do {
            guard let selectedURL = selectedStoredGameFile?.url else {
                return
            }

            flushPendingGameFileAutosave(for: selectedURL)
            let destinationURL = try uniqueStoredGameFileURL(
                preferredFilename: renameGameFileNameDraft,
                excluding: selectedURL
            )

            guard destinationURL.path != selectedURL.path else {
                renameGameFileNameDraft = selectedURL.deletingPathExtension().lastPathComponent
                return
            }

            try FileManager.default.moveItem(at: selectedURL, to: destinationURL)
            refreshStoredGameFiles(selectedURL: destinationURL)
            syncCurrentLogGameFile()
            recordFileLog(
                kind: .fileRename,
                summary: "Rename game file",
                outcome: .applied,
                fileURL: destinationURL,
                notes: selectedURL.lastPathComponent
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func loadStoredGameFile(_ gameFile: StoredGameFile) {
        do {
            let snapshot = try loadGameSnapshot(from: gameFile.url)
            selectedStoredGameFileID = gameFile.id
            store.applyGameSnapshot(snapshot)
            loadSetupDraftsFromStore()
            gameFileNameDraft = gameFile.displayName
            recordFileLog(
                kind: .fileLoad,
                summary: "Load game file",
                outcome: .applied,
                fileURL: gameFile.url
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func refreshStoredGameFiles(selectedURL: URL? = nil) {
        do {
            let directoryURL = try storedGameFilesDirectory()
            let urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            storedGameFiles = try urls
                .filter { $0.pathExtension.lowercased() == "scoreboardgame" }
                .map { url in
                    let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
                    return StoredGameFile(
                        url: url,
                        modifiedAt: values.contentModificationDate ?? .distantPast,
                        summary: try? loadStoredGameFileSummary(from: url)
                    )
                }
                .sorted {
                    if $0.modifiedAt == $1.modifiedAt {
                        return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }

                    return $0.modifiedAt > $1.modifiedAt
                }

            if let selectedURL {
                selectedStoredGameFileID = selectedURL.path
            } else if let selectedStoredGameFileID, storedGameFiles.contains(where: { $0.id == selectedStoredGameFileID }) {
                self.selectedStoredGameFileID = selectedStoredGameFileID
            } else {
                selectedStoredGameFileID = storedGameFiles.first?.id
            }

            renameGameFileNameDraft = selectedStoredGameFile?.displayName ?? ""
            selectedGameFileIDs.formIntersection(Set(storedGameFiles.map(\.id)))
            if storedGameFiles.isEmpty {
                isSelectingGameFiles = false
            }
        } catch {
            storedGameFiles = []
            selectedStoredGameFileID = nil
            renameGameFileNameDraft = ""
            selectedGameFileIDs.removeAll()
            isSelectingGameFiles = false
            presentFileOperationError(error)
        }
    }

    private func refreshStoredLogSessions(selectedURL: URL? = nil) {
        do {
            storedLogSessions = try logManager.listSessions()

            if let selectedURL {
                selectedStoredLogSessionID = selectedURL.path
            } else if let selectedStoredLogSessionID, storedLogSessions.contains(where: { $0.id == selectedStoredLogSessionID }) {
                self.selectedStoredLogSessionID = selectedStoredLogSessionID
            } else {
                selectedStoredLogSessionID = storedLogSessions.first?.id
            }

            selectedLogSessionIDs.formIntersection(Set(storedLogSessions.map(\.id)))
            if storedLogSessions.isEmpty {
                isSelectingLogSessions = false
            }
        } catch {
            storedLogSessions = []
            selectedStoredLogSessionID = nil
            selectedLogSessionIDs.removeAll()
            isSelectingLogSessions = false
            presentFileOperationError(error)
        }
    }

    private func prepareLogExport(as contentType: UTType, destination: ExportDestination = .share) {
        do {
            let selectedURL = selectedStoredLogSession?.url
            logManager.flushPendingWrites()
            refreshStoredLogSessions(selectedURL: selectedURL)

            guard let session = selectedStoredLogSession else {
                return
            }

            let data: Data
            let fileExtension: String

            if contentType == .commaSeparatedText {
                data = logManager.exportCSVData(for: session.session)
                fileExtension = "csv"
            } else {
                data = try logManager.exportJSONData(for: session.session)
                fileExtension = contentType == .scoreboardLogSession ? "scoreboardlog" : "json"
            }

            let timestamp = session.startedAt.ISO8601Format()
                .replacingOccurrences(of: ":", with: "-")
            presentLogExport(
                data: data,
                contentType: contentType,
                defaultFilename: "Scoreboard Log \(timestamp).\(fileExtension)",
                destination: destination
            )
        } catch {
            presentFileOperationError(error)
        }
    }

    private func deleteLogSession(_ session: StoredLogSession) {
        do {
            try logManager.deleteSession(at: session.url)
            selectedLogSessionIDs.remove(session.id)
            refreshStoredLogSessions()
        } catch {
            presentFileOperationError(error)
        }
    }

    private func deleteSelectedLogSessions() {
        let sessionsToDelete = storedLogSessions.filter { selectedLogSessionIDs.contains($0.id) }
        guard !sessionsToDelete.isEmpty else {
            return
        }

        do {
            for session in sessionsToDelete {
                try logManager.deleteSession(at: session.url)
            }

            selectedLogSessionIDs.removeAll()
            isSelectingLogSessions = false
            refreshStoredLogSessions()
        } catch {
            presentFileOperationError(error)
        }
    }

    private func syncCurrentLogGameFile() {
        logManager.setCurrentGameFile(url: selectedStoredGameFile?.url)
    }

    private func recordFileLog(
        kind: ScoreboardLogOperationKind,
        summary: String,
        outcome: ScoreboardLogOutcome,
        fileURL: URL? = nil,
        notes: String? = nil
    ) {
        let resolvedURL = fileURL ?? selectedStoredGameFile?.url
        var context = store.currentLogContext()
        context.gameFileName = resolvedURL?.deletingPathExtension().lastPathComponent
        context.gameFilePath = resolvedURL?.path

        logManager.record(
            operation: ScoreboardLogOperation(
                kind: kind,
                summary: localizedAppString(summary),
                teamSide: nil,
                playerID: nil,
                playerNumber: nil,
                playerName: nil,
                delta: nil,
                value: nil,
                fileName: resolvedURL?.lastPathComponent,
                notes: notes
            ),
            context: context,
            outcome: outcome
        )
    }

    private func suggestedGameFilename(_ home: String, _ guest: String) -> String {
        let resolvedHome = displayTeamName(home)
        let resolvedGuest = displayTeamName(guest)
        return "\(resolvedHome) vs \(resolvedGuest).scoreboardgame"
    }

    private func loadSetupDraftsFromStore(keepsLoadingFlag: Bool = false) {
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
        gameFileNameDraft = selectedStoredGameFile?.displayName ?? resolvedGameFilenameDraft(store.homeTeamName, store.guestTeamName, includeExtension: false)
        markSetupClockBaselinesCurrent()
        if !keepsLoadingFlag {
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    isLoadingSetupDrafts = false
                }
            }
        }
    }

    private func normalizeSetupCustomDebatePreset() {
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

    private func displayTeamName(_ name: String) -> String {
        name.isEmpty ? localizedAppString("TBD") : name
    }

    private func temporaryExportURL(defaultFilename: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("ScoreboardExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let sanitizedFilename = sanitizeExportFilename(defaultFilename)
        let baseName = (sanitizedFilename as NSString).deletingPathExtension
        let pathExtension = (sanitizedFilename as NSString).pathExtension
        let filename = pathExtension.isEmpty ? baseName : "\(baseName).\(pathExtension)"
        var candidateURL = directoryURL.appendingPathComponent(filename)
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidateURL.path) {
            let suffixedFilename = pathExtension.isEmpty ? "\(baseName) \(suffix)" : "\(baseName) \(suffix).\(pathExtension)"
            candidateURL = directoryURL.appendingPathComponent(suffixedFilename)
            suffix += 1
        }

        return candidateURL
    }

    private func sanitizeExportFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Scoreboard Export" : trimmed
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return String(fallback.unicodeScalars.map { invalidCharacters.contains($0) ? "-" : String($0) }.joined())
    }

    private func logEntryContextLine(_ entry: ScoreboardLogEntry) -> String {
        var segments: [String] = []
        segments.append(entry.context.customSportTitle ?? localizedAppString(entry.context.sport.title))
        if let debatePresetTitle = entry.context.debatePresetTitle {
            segments.append(localizedAppString(debatePresetTitle))
        }
        if let debateSegmentTitle = entry.context.debateSegmentTitle {
            segments.append(localizedAppString(debateSegmentTitle))
        }
        if entry.context.homeChessClockSeconds == nil && entry.context.guestChessClockSeconds == nil {
            segments.append(localizedAppFormat("%@ %lld", localizedAppString(entry.context.sport.periodTitle), entry.context.period))
        }
        if entry.context.homeChessClockSeconds != nil || entry.context.guestChessClockSeconds != nil {
            let home = entry.context.homeChessClockSeconds.map(ScoreboardStore.formatGameClock) ?? "--:--"
            let guest = entry.context.guestChessClockSeconds.map(ScoreboardStore.formatGameClock) ?? "--:--"
            let activeSide = entry.context.activeChessClockSide.map { side in
                if side == .home {
                    return entry.context.debateHomeSideLabel ?? side.title
                }
                return entry.context.debateGuestSideLabel ?? side.title
            } ?? localizedAppString("None")
            segments.append(localizedAppFormat("Dual Clock %@ / %@ • %@", home, guest, activeSide))
        } else if entry.context.showsGameClock {
            let clockState = localizedAppString(entry.context.isClockRunning ? "Running" : "Stopped")
            segments.append(localizedAppFormat("Clock %@ %@", clockState, ScoreboardStore.formatGameClock(entry.context.gameClockSeconds)))
        } else {
            segments.append(localizedAppString("Clock Disabled"))
        }

        if entry.context.supportsShotClock, let milliseconds = entry.context.shotClockMilliseconds {
            let shotState = localizedAppString(entry.context.isShotClockRunning == true ? "Running" : "Stopped")
            segments.append(localizedAppFormat("Shot %@ %@", shotState, ScoreboardStore.formatShotClock(milliseconds: milliseconds)))
        }

        if let hockeyPenaltySummary = entry.context.hockeyPenaltySummary, !hockeyPenaltySummary.isEmpty {
            segments.append(hockeyPenaltySummary)
        }

        segments.append("\(displayTeamName(entry.context.homeTeamName)) \(entry.context.homeScore)-\(entry.context.guestScore) \(displayTeamName(entry.context.guestTeamName))")
        return segments.joined(separator: " • ")
    }

    private func logEntryPlayerLine(_ entry: ScoreboardLogEntry) -> String? {
        guard
            entry.operation.playerNumber != nil ||
            !(entry.operation.playerName?.isEmpty ?? true) ||
            entry.operation.teamSide != nil
        else {
            return nil
        }

        var segments: [String] = []

        if let side = entry.operation.teamSide {
            if entry.context.sport == .debate {
                segments.append(side == .home ? (entry.context.debateHomeSideLabel ?? side.title) : (entry.context.debateGuestSideLabel ?? side.title))
            } else {
                segments.append(localizedAppString(side.title))
            }
        }

        if let number = entry.operation.playerNumber, !number.isEmpty {
            segments.append("#\(number)")
        }

        if let name = entry.operation.playerName, !name.isEmpty {
            segments.append(name)
        }

        return segments.joined(separator: " • ")
    }

    private func logEntryFileLine(_ entry: ScoreboardLogEntry) -> String? {
        guard let fileName = entry.operation.fileName ?? entry.context.gameFileName else {
            return nil
        }

        return localizedAppFormat("File: %@", fileName)
    }

    private func logDeletionMessage(for session: StoredLogSession) -> String {
        localizedAppFormat("Delete the log session from %@?", session.startedAt.formatted(date: .abbreviated, time: .shortened))
    }

    private func backupRestoreMessage(for backupRestore: PendingBackupRestore) -> String {
        let gameCount = backupRestore.backup.storedGameFiles.count
        let logCount = backupRestore.backup.logSessions.count
        return localizedAppFormat(
            "Restore %@? This will replace all local app settings, current game state, %lld game files, and %lld log sessions.",
            backupRestore.sourceFilename,
            gameCount,
            logCount
        )
    }

    private func presentFileOperationError(_ error: Error) {
        fileOperationError = FileOperationAlert(message: error.localizedDescription)
    }

    private var selectedStoredGameFile: StoredGameFile? {
        guard let selectedStoredGameFileID else {
            return nil
        }

        return storedGameFiles.first { $0.id == selectedStoredGameFileID }
    }

    private var canRenameSelectedGameFile: Bool {
        guard let selectedStoredGameFile else {
            return false
        }

        let trimmedName = renameGameFileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName != selectedStoredGameFile.displayName
    }

    private func toggleGameFileSelectionMode() {
        isSelectingGameFiles.toggle()
        if !isSelectingGameFiles {
            selectedGameFileIDs.removeAll()
        }
    }

    private func handleGameFileRowTap(_ gameFile: StoredGameFile) {
        if isSelectingGameFiles {
            toggleGameFileSelection(gameFile)
        } else {
            loadStoredGameFile(gameFile)
        }
    }

    private func toggleGameFileSelection(_ gameFile: StoredGameFile) {
        if selectedGameFileIDs.contains(gameFile.id) {
            selectedGameFileIDs.remove(gameFile.id)
        } else {
            selectedGameFileIDs.insert(gameFile.id)
        }
    }

    private func gameFileLeadingSystemImage(_ gameFile: StoredGameFile) -> String {
        if isSelectingGameFiles {
            return selectedGameFileIDs.contains(gameFile.id) ? "checkmark.circle.fill" : "circle"
        }

        return "doc.text"
    }

    private func gameFileLeadingTint(_ gameFile: StoredGameFile) -> Color {
        if isSelectingGameFiles {
            return selectedGameFileIDs.contains(gameFile.id) ? settingsPalette.accent : settingsPalette.secondaryText
        }

        return selectedStoredGameFileID == gameFile.id ? settingsPalette.accent : settingsPalette.secondaryText
    }

    private func gameFileRowBackground(_ gameFile: StoredGameFile) -> some View {
        let isHighlighted = isSelectingGameFiles
            ? selectedGameFileIDs.contains(gameFile.id)
            : selectedStoredGameFileID == gameFile.id

        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isHighlighted ? settingsPalette.accent.opacity(0.12) : Color.clear)
    }

    private var selectedStoredLogSession: StoredLogSession? {
        guard let selectedStoredLogSessionID else {
            return nil
        }

        return storedLogSessions.first { $0.id == selectedStoredLogSessionID }
    }

    private func toggleLogSessionSelectionMode() {
        isSelectingLogSessions.toggle()
        if !isSelectingLogSessions {
            selectedLogSessionIDs.removeAll()
        }
    }

    private func handleLogSessionRowTap(_ session: StoredLogSession) {
        if isSelectingLogSessions {
            toggleLogSessionSelection(session)
        } else {
            selectedStoredLogSessionID = session.id
        }
    }

    private func toggleLogSessionSelection(_ session: StoredLogSession) {
        if selectedLogSessionIDs.contains(session.id) {
            selectedLogSessionIDs.remove(session.id)
        } else {
            selectedLogSessionIDs.insert(session.id)
        }
    }

    private func logSessionLeadingSystemImage(_ session: StoredLogSession) -> String {
        if isSelectingLogSessions {
            return selectedLogSessionIDs.contains(session.id) ? "checkmark.circle.fill" : "circle"
        }

        return "doc.text.magnifyingglass"
    }

    private func logSessionLeadingTint(_ session: StoredLogSession) -> Color {
        if isSelectingLogSessions {
            return selectedLogSessionIDs.contains(session.id) ? settingsPalette.accent : settingsPalette.secondaryText
        }

        return selectedStoredLogSessionID == session.id ? settingsPalette.accent : settingsPalette.secondaryText
    }

    private func logSessionRowBackground(_ session: StoredLogSession) -> some View {
        let isHighlighted = isSelectingLogSessions
            ? selectedLogSessionIDs.contains(session.id)
            : selectedStoredLogSessionID == session.id

        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isHighlighted ? settingsPalette.accent.opacity(0.12) : Color.clear)
    }

    private func orderedLogEntries(for session: StoredLogSession) -> [ScoreboardLogEntry] {
        switch logPlaybackOrder {
        case .topToBottom:
            return session.session.entries
        case .bottomToTop:
            return Array(session.session.entries.reversed())
        }
    }

    private func applySetupSportDefaults(_ sport: SportType) {
        setupPeriod = 1
        setupClockSeconds = setupRules.defaultClockSeconds
        setupGuestClockSeconds = setupRules.usesChessClocks ? setupRules.defaultClockSeconds : setupGuestClockSeconds
        if sport != .volleyball && sport != .custom {
            setupUsesGameClock = true
        }
        if sport == .volleyball {
            setupVolleyballMatchFormat = .bestOf5
        }
        if setupRules.usesChessClocks {
            if sport == .chess {
                setupClockSeconds = setupChessPreset.seconds
                setupGuestClockSeconds = setupChessPreset.seconds
            } else if sport == .debate {
                let firstSegment = setupDebatePreset.segments.first
                setupClockSeconds = firstSegment?.durationSeconds ?? 0
                setupGuestClockSeconds = firstSegment?.durationSeconds ?? 0
            } else {
                setupClockSeconds = setupRules.defaultClockSeconds
                setupGuestClockSeconds = setupRules.defaultClockSeconds
            }
        }
        setupShotClockSeconds = setupRules.defaultShotClockSeconds
    }

    private func storedGameFilesDirectory() throws -> URL {
        try ScoreboardFileStorage.storedGamesDirectory()
    }

    private func uniqueStoredGameFileURL(preferredFilename: String, excluding excludedURL: URL? = nil) throws -> URL {
        let directoryURL = try storedGameFilesDirectory()
        let fileManager = FileManager.default
        let sanitizedBaseName = sanitizeGameFilename(preferredFilename)
        let baseName = (sanitizedBaseName as NSString).deletingPathExtension
        let pathExtension = ((sanitizedBaseName as NSString).pathExtension.isEmpty ? "scoreboardgame" : (sanitizedBaseName as NSString).pathExtension)

        var candidateURL = directoryURL.appendingPathComponent(baseName).appendingPathExtension(pathExtension)
        var suffix = 2

        while fileManager.fileExists(atPath: candidateURL.path) {
            if let excludedURL, candidateURL.standardizedFileURL == excludedURL.standardizedFileURL {
                break
            }

            candidateURL = directoryURL.appendingPathComponent("\(baseName) \(suffix)").appendingPathExtension(pathExtension)
            suffix += 1
        }

        return candidateURL
    }

    private func resolvedGameFilenameDraft(_ home: String, _ guest: String, includeExtension: Bool = true) -> String {
        let trimmed = gameFileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return includeExtension && !trimmed.lowercased().hasSuffix(".scoreboardgame")
                ? "\(trimmed).scoreboardgame"
                : trimmed
        }

        let suggested = suggestedGameFilename(home, guest)
        return includeExtension ? suggested : suggested.replacingOccurrences(of: ".scoreboardgame", with: "")
    }

    private func sanitizeGameFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "New Game.scoreboardgame" : trimmed
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = String(fallback.unicodeScalars.map { invalidCharacters.contains($0) ? "-" : String($0) }.joined())
        return cleaned.hasSuffix(".scoreboardgame") ? cleaned : "\(cleaned).scoreboardgame"
    }

    private func writeGameSnapshot(_ snapshot: ScoreboardGameSnapshot, to url: URL) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    private func loadGameSnapshot(from url: URL) throws -> ScoreboardGameSnapshot {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: data)
    }

    private func loadStoredGameFileSummary(from url: URL) throws -> StoredGameFileSummary {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StoredGameFileSummary.self, from: data)
    }

    private func storedGameBackupFiles() throws -> [ScoreboardBackupFile] {
        let directoryURL = try storedGameFilesDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { $0.pathExtension.lowercased() == "scoreboardgame" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                ScoreboardBackupFile(filename: url.lastPathComponent, data: try Data(contentsOf: url))
            }
    }

    private func validateStoredGameBackupFiles(_ files: [ScoreboardBackupFile]) throws {
        var filenames = Set<String>()
        for file in files {
            let filename = try safeRestoredStoredGameFilename(file.filename)
            guard filenames.insert(filename).inserted else {
                throw ScoreboardBackupError.invalidFilename(file.filename)
            }
            _ = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: file.data)
        }
    }

    private func replaceStoredGameFiles(with files: [ScoreboardBackupFile]) throws {
        try validateStoredGameBackupFiles(files)
        discardPendingGameFileAutosaves()
        try deleteAllStoredGameFiles()

        let directoryURL = try storedGameFilesDirectory()
        for file in files {
            let filename = try safeRestoredStoredGameFilename(file.filename)
            let destinationURL = directoryURL.appendingPathComponent(filename)
            try file.data.write(to: destinationURL, options: .atomic)
        }
    }

    private func restoredStoredGameURL(named filename: String?) throws -> URL? {
        guard let filename else {
            return nil
        }

        let safeFilename = try safeRestoredStoredGameFilename(filename)
        let url = try storedGameFilesDirectory().appendingPathComponent(safeFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func deleteAllStoredGameFiles() throws {
        let directoryURL = try storedGameFilesDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for url in urls where url.pathExtension.lowercased() == "scoreboardgame" {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func safeRestoredStoredGameFilename(_ filename: String) throws -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastPathComponent = URL(fileURLWithPath: trimmed).lastPathComponent
        let invalidCharacters = CharacterSet(charactersIn: "/:\\")
        guard !trimmed.isEmpty,
              trimmed == lastPathComponent,
              !trimmed.unicodeScalars.contains(where: { invalidCharacters.contains($0) }),
              (trimmed as NSString).pathExtension.lowercased() == "scoreboardgame" else {
            throw ScoreboardBackupError.invalidFilename(filename)
        }

        return trimmed
    }

    private func backupTimestamp() -> String {
        Date().ISO8601Format()
            .replacingOccurrences(of: ":", with: "-")
    }

    private func initializeWorkingGameFile() {
        migrateLegacyPresetsToStoredGameFilesIfNeeded()
        refreshStoredGameFiles()

        if let selectedStoredGameFile {
            loadStoredGameFile(selectedStoredGameFile)
            return
        }

        if let firstStoredGameFile = storedGameFiles.first {
            loadStoredGameFile(firstStoredGameFile)
            return
        }

        do {
            let snapshot = store.currentGameSnapshot()
            let url = try uniqueStoredGameFileURL(preferredFilename: suggestedGameFilename(snapshot.homeTeamName, snapshot.guestTeamName))
            try writeGameSnapshot(snapshot, to: url)
            refreshStoredGameFiles(selectedURL: url)
            selectedStoredGameFileID = url.path
            loadSetupDraftsFromStore()
            gameFileNameDraft = url.deletingPathExtension().lastPathComponent
        } catch {
            presentFileOperationError(error)
        }
    }

    private func ensureWorkingGameFileExists() {
        if selectedStoredGameFile != nil {
            return
        }

        if storedGameFiles.isEmpty {
            do {
                let snapshot = showsSetup ? currentSetupWorkingSnapshot() : store.currentGameSnapshot()
                let url = try uniqueStoredGameFileURL(preferredFilename: suggestedGameFilename(snapshot.homeTeamName, snapshot.guestTeamName))
                try writeGameSnapshot(snapshot, to: url)
                refreshStoredGameFiles(selectedURL: url)
                gameFileNameDraft = url.deletingPathExtension().lastPathComponent
            } catch {
                presentFileOperationError(error)
            }
            return
        }

        if let firstStoredGameFile = storedGameFiles.first {
            selectedStoredGameFileID = firstStoredGameFile.id
        }
    }

    private func commitSetupEdits(forceRefresh: Bool = false, animated: Bool = false) {
        guard !isCommittingSetupEdits else {
            return
        }

        isCommittingSetupEdits = true
        defer {
            DispatchQueue.main.async {
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
        autosaveSelectedGameFile(refreshSelection: forceRefresh)
    }

    private func currentSetupWorkingSnapshot() -> ScoreboardGameSnapshot {
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
        let activeChessClockSide = setupRules.usesChessClocks
            ? ((setupSport == .debate ? isSameDebateFormat : isSameSport) ? currentSnapshot.activeChessClockSide : .home)
            : currentSnapshot.activeChessClockSide
        let tracksPeriodWins = setupSport == .volleyball ||
            (setupSport == .custom && resolvedSetupCustomSportConfig.isPeriodWinTrackingEnabled)

        return ScoreboardGameSnapshot(
            fileVersion: 11,
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
            eventLogoImage: currentSnapshot.eventLogoImage
        )
    }

    private func markSetupClockBaselinesCurrent() {
        setupClockSecondsBaseline = setupClockSeconds
        setupShotClockSecondsBaseline = setupShotClockSeconds
        setupGuestClockSecondsBaseline = setupGuestClockSeconds
    }

    private func autosaveSelectedGameFile(refreshSelection: Bool = false) {
        guard let selectedURL = selectedStoredGameFile?.url else {
            return
        }

        let autosave = PendingGameFileAutosave(
            url: selectedURL,
            refreshSelection: refreshSelection
        )
        requestGameFileAutosave(autosave)
    }

    private func autosaveSelectedGameFileImmediately(refreshSelection: Bool = false) {
        guard let selectedURL = selectedStoredGameFile?.url else {
            return
        }

        discardPendingGameFileAutosave(for: selectedURL)

        do {
            let snapshot = store.currentGameSnapshot()
            try writeGameSnapshot(snapshot, to: selectedURL)

            if refreshSelection {
                refreshStoredGameFiles(selectedURL: selectedURL)
            }
        } catch {
            presentFileOperationError(error)
        }
    }

    private func requestGameFileAutosave(_ autosave: PendingGameFileAutosave) {
        let key = autosave.url.standardizedFileURL.path
        if var pendingAutosave = pendingGameFileAutosaves[key] {
            pendingAutosave.refreshSelection = pendingAutosave.refreshSelection || autosave.refreshSelection
            pendingGameFileAutosaves[key] = pendingAutosave
        } else {
            pendingGameFileAutosaves[key] = autosave
        }

        schedulePendingGameFileAutosaves()
    }

    private func schedulePendingGameFileAutosaves() {
        guard !pendingGameFileAutosaves.isEmpty else {
            pendingGameFileAutosaveWorkItem?.cancel()
            pendingGameFileAutosaveWorkItem = nil
            return
        }

        let now = Date()
        if let lastGameFileAutosaveDate {
            let elapsed = now.timeIntervalSince(lastGameFileAutosaveDate)
            if elapsed < automaticDiskWriteThrottleInterval {
                guard pendingGameFileAutosaveWorkItem == nil else {
                    return
                }

                let delay = automaticDiskWriteThrottleInterval - elapsed
                let workItem = DispatchWorkItem {
                    performPendingGameFileAutosaves()
                }
                pendingGameFileAutosaveWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                return
            }
        }

        performPendingGameFileAutosaves()
    }

    private func performPendingGameFileAutosaves() {
        pendingGameFileAutosaveWorkItem?.cancel()
        pendingGameFileAutosaveWorkItem = nil

        let autosaves = Array(pendingGameFileAutosaves.values)
        guard !autosaves.isEmpty else {
            return
        }

        pendingGameFileAutosaves.removeAll()
        lastGameFileAutosaveDate = Date()

        var refreshURL: URL?
        for autosave in autosaves {
            do {
                guard let snapshot = pendingGameFileSnapshot(for: autosave) else {
                    continue
                }
                try writeGameSnapshot(snapshot, to: autosave.url)
                if autosave.refreshSelection {
                    if autosave.url.standardizedFileURL.path == selectedStoredGameFile?.url.standardizedFileURL.path {
                        refreshURL = autosave.url
                    } else if refreshURL == nil {
                        refreshURL = autosave.url
                    }
                }
            } catch {
                presentFileOperationError(error)
            }
        }

        if let refreshURL {
            refreshStoredGameFiles(selectedURL: refreshURL)
        }
    }

    private func pendingGameFileSnapshot(for autosave: PendingGameFileAutosave) -> ScoreboardGameSnapshot? {
        guard autosave.url.standardizedFileURL.path == selectedStoredGameFile?.url.standardizedFileURL.path else {
            return nil
        }
        return store.currentGameSnapshot()
    }

    private func flushPendingGameFileAutosaves() {
        performPendingGameFileAutosaves()
    }

    private func flushPendingGameFileAutosave(for url: URL) {
        let key = url.standardizedFileURL.path
        guard let autosave = pendingGameFileAutosaves.removeValue(forKey: key) else {
            return
        }

        do {
            guard let snapshot = pendingGameFileSnapshot(for: autosave) else {
                schedulePendingGameFileAutosaves()
                return
            }
            try writeGameSnapshot(snapshot, to: autosave.url)
            lastGameFileAutosaveDate = Date()
            if autosave.refreshSelection {
                refreshStoredGameFiles(selectedURL: autosave.url)
            }
        } catch {
            presentFileOperationError(error)
        }

        schedulePendingGameFileAutosaves()
    }

    private func discardPendingGameFileAutosave(for url: URL) {
        pendingGameFileAutosaves.removeValue(forKey: url.standardizedFileURL.path)
        schedulePendingGameFileAutosaves()
    }

    private func discardPendingGameFileAutosaves() {
        pendingGameFileAutosaves.removeAll()
        schedulePendingGameFileAutosaves()
    }

    private func migrateLegacyPresetsToStoredGameFilesIfNeeded() {
        guard !store.setupPresets.isEmpty else {
            return
        }

        do {
            for preset in store.setupPresets {
                let snapshot = ScoreboardGameSnapshot(
                    fileVersion: 11,
                    sport: preset.sport,
                    customSportConfig: preset.customSportConfig,
                    customDebatePreset: preset.sport == .debate ? DebatePreset.customDefault : nil,
                    homeTeamName: preset.homeTeamName,
                    guestTeamName: preset.guestTeamName,
                    eventName: "",
                    homeScore: 0,
                    guestScore: 0,
                    period: preset.period,
                    volleyballMatchFormat: preset.sport == .volleyball ? .bestOf5 : nil,
                    volleyballSetResults: preset.sport == .volleyball ? [] : nil,
                    gameClockSeconds: preset.clockSeconds,
                    defaultClockSeconds: preset.clockSeconds,
                    isGameClockEnabled: true,
                    shotClockMilliseconds: preset.shotClockSeconds * 1_000,
                    defaultShotClockSeconds: preset.shotClockSeconds,
                    activeShotClockPresetSeconds: preset.shotClockSeconds,
                    possessionDirection: preset.possessionDirection,
                    areSidesSwapped: false,
                    isPlayerTrackingEnabled: store.isPlayerTrackingEnabled,
                    isPlayerOverlayPaused: false,
                    rosterSizePerTeam: store.rosterSizePerTeam,
                    displayLineupSize: store.displayLineupSize,
                    playerLineupOverflowMode: store.playerLineupOverflowMode,
                    playerLineupOverflowLogoOverride: store.playerLineupOverflowLogoOverride,
                    playerLineupOverflowNoLogoOverride: store.playerLineupOverflowNoLogoOverride,
                    playerLineupFadePageSeconds: store.playerLineupFadePageSeconds,
                    playerLineupScrollSpeed: store.playerLineupScrollSpeed,
                    playerLineupScrollDirection: store.playerLineupScrollDirection,
                    playerFoulHighlightColor: store.playerFoulHighlightColor,
                    isGameClockRedEnabled: store.isGameClockRedEnabled,
                    gameClockRedThresholdSeconds: store.gameClockRedThresholdSeconds,
                    isShotClockRedEnabled: store.isShotClockRedEnabled,
                    shotClockRedThresholdSeconds: store.shotClockRedThresholdSeconds,
                    homeSubstitutionsAllowed: preset.sport.defaultSubstitutionLimit,
                    guestSubstitutionsAllowed: preset.sport.defaultSubstitutionLimit,
                    homeSubstitutionsUsed: 0,
                    guestSubstitutionsUsed: 0,
                    homePausesAllowed: preset.sport.rules(customConfig: preset.customSportConfig).defaultPauseLimit,
                    guestPausesAllowed: preset.sport.rules(customConfig: preset.customSportConfig).defaultPauseLimit,
                    homePausesUsed: 0,
                    guestPausesUsed: 0,
                    homeTeamFouls: 0,
                    guestTeamFouls: 0,
                    homeChessClockSeconds: preset.sport.rules(customConfig: preset.customSportConfig).usesChessClocks ? preset.clockSeconds : nil,
                    guestChessClockSeconds: preset.sport.rules(customConfig: preset.customSportConfig).usesChessClocks ? preset.clockSeconds : nil,
                    activeChessClockSide: preset.sport.rules(customConfig: preset.customSportConfig).usesChessClocks ? .home : nil,
                    chessClockPreset: preset.sport == .chess ? .rapid : nil,
                    selectedDebatePresetID: preset.sport == .debate ? DebatePreset.publicForum.id : nil,
                    debateHomeSideLabel: preset.sport == .debate ? DebatePreset.publicForum.homeSideLabel : nil,
                    debateGuestSideLabel: preset.sport == .debate ? DebatePreset.publicForum.guestSideLabel : nil,
                    debateCurrentSegmentIndex: preset.sport == .debate ? 0 : nil,
                    debatePrepHomeSeconds: preset.sport == .debate ? DebatePreset.publicForum.prepSecondsPerSide : nil,
                    debatePrepGuestSeconds: preset.sport == .debate ? DebatePreset.publicForum.prepSecondsPerSide : nil,
                    isDebatePrepTimeEnabled: preset.sport == .debate ? DebatePreset.publicForum.isPrepTimeEnabled : nil,
                    debateActiveTimer: preset.sport == .debate ? .segment : nil,
                    isDebatePrepClockRunning: preset.sport == .debate ? false : nil,
                    isDebateScoreTrackingEnabled: preset.sport == .debate ? false : nil,
                    isDebatePlayerTrackingEnabled: preset.sport == .debate ? false : nil,
                    isDebatePlayerFoulsEnabled: preset.sport == .debate ? false : nil,
                    isDebatePlayerCardsEnabled: preset.sport == .debate ? false : nil,
                    homePenaltyTimers: [],
                    guestPenaltyTimers: [],
                    homeRoster: store.homeRoster,
                    guestRoster: store.guestRoster
                )

                let baseFilename = preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? suggestedGameFilename(preset.homeTeamName, preset.guestTeamName)
                    : "\(preset.name).scoreboardgame"
                let url = try uniqueStoredGameFileURL(preferredFilename: baseFilename)
                try writeGameSnapshot(snapshot, to: url)
            }

            store.setupPresets.removeAll()
        } catch {
            presentFileOperationError(error)
        }
    }

    #if os(macOS)
    private func showPublicBoardWindow() {
        publicBoardState.requestFullscreen()
        openWindow(id: "public-scoreboard")
    }
    #endif

    private func previewBoardSurface<Content: View>(
        layout: InterfaceLayout,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let board = content()

        return GeometryReader { proxy in
            let horizontalInset = max(24, min(proxy.size.width * (layout.isCompactWidth ? 0.05 : 0.09), 72))
            let verticalInset = max(8, min(proxy.size.height * 0.025, 16))
            let availableWidth = max(proxy.size.width - (horizontalInset * 2), 0)
            let availableHeight = max(proxy.size.height - (verticalInset * 2), 0)
            let aspectRatio = ScoreboardFaceView.preferredAspectRatio
            let fittedWidth = min(availableWidth, availableHeight * aspectRatio)
            let fittedHeight = min(availableHeight, fittedWidth / aspectRatio)

            board
                .frame(width: fittedWidth, height: fittedHeight)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
        }
    }

    private func previewPanel<Content: View>(
        title: String,
        caption: String,
        layout: InterfaceLayout,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if layout.previewHeaderUsesVerticalFlow {
                VStack(alignment: .leading, spacing: 8) {
                    localizedAppText(title)
                        .font(.title3.weight(.bold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(themePalette.dashboardPrimaryText)

                    localizedAppText(caption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(themePalette.dashboardMutedText)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    localizedAppText(title)
                        .font(.title3.weight(.bold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(themePalette.dashboardPrimaryText)

                    Spacer(minLength: 0)

                    localizedAppText(caption)
                        .font(.subheadline.weight(.semibold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(themePalette.dashboardMutedText)
                }
            }

            previewBoardSurface(layout: layout) {
                content()
            }
        }
        .padding(layout.previewPanelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(themePalette.dashboardCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(themePalette.dashboardCardBorder)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func currentPreviewBoard(layout: InterfaceLayout) -> some View {
        PublicScoreboardDisplayView(
            viewMode: store.publicDisplayViewMode,
            playerViewRosterScope: .fullRoster,
            theme: store.theme,
            backgroundMode: store.externalDisplayBackgroundMode.resolvedForRendering,
            backgroundImage: store.externalDisplayBackgroundImage.map(PublicScoreboardBackgroundImage.init(image:)),
            animatedLogoStyle: store.externalDisplayAnimatedLogoStyle,
            animatedLogoBackgroundColor: store.externalDisplayAnimatedLogoBackgroundColor,
            animatedLogoSpeed: store.externalDisplayAnimatedLogoSpeed,
            animatedLogoSize: store.externalDisplayAnimatedLogoSize,
            animatedLogoOpacity: store.externalDisplayAnimatedLogoOpacity,
            showsDateTime: store.showsExternalDisplayDateTime,
            dateTimeFormat: store.externalDisplayDateTimeFormat,
            showsDateTimeSeconds: store.showsExternalDisplayDateTimeSeconds,
            sport: store.selectedSport,
            rules: store.currentRules,
            showsScore: store.supportsScore,
            homeTeamName: store.homeTeamName,
            guestTeamName: store.guestTeamName,
            eventName: store.eventName,
            homeTeamLogoData: store.showsTeamLogos ? store.homeTeamLogoImage?.data : nil,
            guestTeamLogoData: store.showsTeamLogos ? store.guestTeamLogoImage?.data : nil,
            eventLogoData: store.showsEventLogo ? store.eventLogoImage?.data : nil,
            playerLineupOverflowMode: store.playerLineupOverflowMode,
            playerLineupOverflowLogoOverride: store.playerLineupOverflowLogoOverride,
            playerLineupOverflowNoLogoOverride: store.playerLineupOverflowNoLogoOverride,
            playerLineupFadePageSeconds: store.playerLineupFadePageSeconds,
            playerLineupScrollSpeed: store.playerLineupScrollSpeed,
            playerLineupScrollDirection: store.playerLineupScrollDirection,
            homeScore: store.homeScore,
            guestScore: store.guestScore,
            homeSetsWon: store.homePeriodWins,
            guestSetsWon: store.guestPeriodWins,
            showsPeriodWins: store.supportsPeriodWinTracking,
            usesServeTimer: store.usesServeTimer,
            period: store.period,
            formattedClock: store.formattedClock,
            showsGameClock: store.showsGameClock,
            showsDualClocks: store.usesChessClocks,
            formattedHomeChessClock: store.formattedHomeChessClock,
            formattedGuestChessClock: store.formattedGuestChessClock,
            activeChessClockSide: store.activeChessClockSide,
            debateHomeSideLabel: store.isDebateMode ? store.sideRoleLabel(for: .home) : nil,
            debateGuestSideLabel: store.isDebateMode ? store.sideRoleLabel(for: .guest) : nil,
            debateSegmentTitle: store.isDebateMode ? store.debateSegmentTitle : nil,
            debateSpeakingSide: store.isDebateMode ? store.debateSpeakingSide : nil,
            debateActiveTimer: store.isDebateMode ? store.debateActiveTimer : nil,
            showsDebatePrepTime: store.showsDebatePrepTime,
            formattedDebatePrepHomeClock: store.showsDebatePrepTime ? store.formattedDebatePrepHomeClock : nil,
            formattedDebatePrepGuestClock: store.showsDebatePrepTime ? store.formattedDebatePrepGuestClock : nil,
            formattedShotClock: store.formattedShotClock,
            possessionDirection: store.possessionDirection,
            displayDirection: store.resolvedExternalDisplayDirection,
            isClockRunning: store.isClockRunning,
            isPlayerTrackingEnabled: store.isPlayerTrackingEnabled,
            isPlayerOverlayPaused: store.isPlayerOverlayPaused,
            playerFoulHighlightColor: store.playerFoulHighlightColor,
            isDisplayGameClockAlertActive: store.isDisplayGameClockAlertActive,
            isDisplayShotClockAlertActive: store.isDisplayShotClockAlertActive,
            homeSubstitutionsAllowed: store.homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: store.guestSubstitutionsAllowed,
            homeSubstitutionsUsed: store.homeSubstitutionsUsed,
            guestSubstitutionsUsed: store.guestSubstitutionsUsed,
            homePausesAllowed: store.homePausesAllowed,
            guestPausesAllowed: store.guestPausesAllowed,
            homePausesUsed: store.homePausesUsed,
            guestPausesUsed: store.guestPausesUsed,
            homeTeamFouls: store.homeTeamFouls,
            guestTeamFouls: store.guestTeamFouls,
            homePenaltyTimers: store.homePenaltyTimers,
            guestPenaltyTimers: store.guestPenaltyTimers,
            homeDisplayedPlayers: store.displayedHomePlayers,
            guestDisplayedPlayers: store.displayedGuestPlayers,
            homeRosterPlayers: store.homeRoster.players,
            guestRosterPlayers: store.guestRoster.players,
            animatesAnimatedLogoBackground: false
        )
    }

    private var currentPreviewModeTitle: String {
        let displayModeTitle = store.publicDisplayViewMode.title
        let backgroundTitle: String
        switch store.externalDisplayBackgroundMode.resolvedForRendering {
        case .blurred:
            backgroundTitle = "Blurred Background"
        case .clear:
            backgroundTitle = "Clear Background"
        case .clearUnderBoard:
            backgroundTitle = "Transparent Board"
        case .smartScoreboard:
            backgroundTitle = "Smart Scoreboard Background"
        case .image:
            backgroundTitle = "Photo Background"
        case .animatedLogo:
            backgroundTitle = "Animated Logo Background"
        case .none:
            backgroundTitle = "No Background"
        }
        return "\(displayModeTitle) / \(backgroundTitle)"
    }

    private var setupDescription: String {
        #if os(macOS)
        "Set the teams and opening game state, then move into the control board. The public scoreboard opens as a separate SwiftUI window for presentation."
        #else
        "Set the teams and opening game state, then move into the control board. Connect an external display to show the full-screen public scoreboard."
        #endif
    }

    private var displayStatusTitle: String {
        #if os(macOS)
        return publicBoardState.isPresented ? "Public Scoreboard Open" : "Public Scoreboard Closed"
        #else
        return publicBoardState.isPresented ? "External Display Live" : "External Display Ready"
        #endif
    }

    private var remoteDisplayHeaderStatusTitle: String? {
        guard store.isRemoteDisplayHostEnabled else {
            return nil
        }

        guard remoteDisplayHeaderTotalDisplayCount > 0 else {
            return nil
        }

        return remoteDisplayHeaderCountStatusTitle
    }

    private var remoteDisplayHeaderCountStatusTitle: String {
        localizedAppFormat(
            "Remote Display %d/%d",
            remoteDisplayHeaderConnectedDisplayCount,
            remoteDisplayHeaderTotalDisplayCount
        )
    }

    private var remoteDisplayHeaderConnectedDisplayCount: Int {
        let knownDisplayIDs = remoteDisplayHeaderKnownDisplayIDs
        return store.remoteDisplayConnectedDisplays.filter {
            knownDisplayIDs.contains($0.id)
        }.count
    }

    private var remoteDisplayHeaderTotalDisplayCount: Int {
        remoteDisplayHeaderKnownDisplayIDs.count
    }

    private var remoteDisplayHeaderKnownDisplayIDs: Set<String> {
        let pairedDisplayIDs = Set(store.remoteDisplayTrustedDisplays.map(\.id))
        let connectedDisplayIDs = Set(store.remoteDisplayConnectedDisplays.map(\.id))
        return pairedDisplayIDs.union(connectedDisplayIDs)
    }

    private var displayStatusSystemImage: String {
        #if os(macOS)
        return publicBoardState.isPresented ? "rectangle.on.rectangle" : "rectangle"
        #else
        return publicBoardState.isPresented ? "display.2" : "cable.connector"
        #endif
    }

    private var activeAlertBinding: Binding<ActiveAlert?> {
        Binding(
            get: {
                if let error = fileOperationError {
                    return .fileOperation(error)
                }
                if let action = pendingGameConfirmation {
                    return .gameConfirmation(action)
                }
                if let backupRestore = pendingBackupRestore {
                    return .backupRestore(backupRestore)
                }
                if let takeover = pendingRemoteDisplayTakeover {
                    return .remoteDisplayTakeover(takeover)
                }
                if let session = pendingLogDeletion {
                    return .logDeletion(session)
                }
                if isFactoryDefaultConfirmationPresented {
                    return .factoryDefault
                }
                return nil
            },
            set: { newValue in
                switch newValue {
                case .none:
                    fileOperationError = nil
                    pendingGameConfirmation = nil
                    pendingBackupRestore = nil
                    pendingRemoteDisplayTakeover = nil
                    pendingLogDeletion = nil
                    isFactoryDefaultConfirmationPresented = false
                case .some(.fileOperation(let error)):
                    fileOperationError = error
                    pendingGameConfirmation = nil
                    pendingBackupRestore = nil
                    pendingRemoteDisplayTakeover = nil
                    pendingLogDeletion = nil
                    isFactoryDefaultConfirmationPresented = false
                case .some(.gameConfirmation(let action)):
                    fileOperationError = nil
                    pendingGameConfirmation = action
                    pendingBackupRestore = nil
                    pendingRemoteDisplayTakeover = nil
                    pendingLogDeletion = nil
                    isFactoryDefaultConfirmationPresented = false
                case .some(.backupRestore(let backupRestore)):
                    fileOperationError = nil
                    pendingGameConfirmation = nil
                    pendingBackupRestore = backupRestore
                    pendingRemoteDisplayTakeover = nil
                    pendingLogDeletion = nil
                    isFactoryDefaultConfirmationPresented = false
                case .some(.remoteDisplayTakeover(let takeover)):
                    fileOperationError = nil
                    pendingGameConfirmation = nil
                    pendingBackupRestore = nil
                    pendingRemoteDisplayTakeover = takeover
                    pendingLogDeletion = nil
                    isFactoryDefaultConfirmationPresented = false
                case .some(.logDeletion(let session)):
                    fileOperationError = nil
                    pendingGameConfirmation = nil
                    pendingBackupRestore = nil
                    pendingRemoteDisplayTakeover = nil
                    pendingLogDeletion = session
                    isFactoryDefaultConfirmationPresented = false
                case .some(.factoryDefault):
                    fileOperationError = nil
                    pendingGameConfirmation = nil
                    pendingBackupRestore = nil
                    pendingRemoteDisplayTakeover = nil
                    pendingLogDeletion = nil
                    isFactoryDefaultConfirmationPresented = true
                }
            }
        )
    }

    private func updateIdleTimer(for phase: ScenePhase) {
        #if os(iOS)
        AppSleepPrevention.setSceneActive(phase == .active)
        #endif
    }

    private func gameConfirmationTitle(for action: GameConfirmationAction) -> String {
        switch action {
        case .awardVolleyballSet(let side):
            return localizedAppFormat("Confirm %@ Period Win", store.sideRoleLabel(for: side))
        case .undoVolleyballSet:
            return localizedAppString("Confirm Undo and Return")
        case .previousPeriod:
            return localizedAppFormat("Confirm Previous %@", localizedAppString(store.periodTitle))
        case .resetClock:
            return localizedAppString("Confirm Clock Reset")
        case .resetShotClock:
            return localizedAppFormat("Confirm %@ Reset", store.secondaryTimerTitle)
        case .zeroScores:
            return localizedAppString("Confirm Zero Scores")
        case .resetChessClocks:
            return localizedAppString("Confirm Clock Reset")
        case .resetDebateSegment:
            return localizedAppString("Confirm Segment Reset")
        case .resetDebateRound:
            return localizedAppString("Confirm Round Reset")
        case .resetDebatePrep(let side):
            return localizedAppFormat("Confirm %@ Prep Reset", store.sideRoleLabel(for: side))
        case .resetAllPlayerFouls:
            return localizedAppString("Confirm Player Foul Reset")
        case .resetAllTeamFouls:
            return localizedAppString("Confirm Team Foul Reset")
        case .resetAllCards:
            return localizedAppString("Confirm Card Reset")
        case .resetSidePlayerFouls(let side):
            return localizedAppFormat("Confirm %@ Foul Reset", store.sideRoleLabel(for: side))
        case .resetSideTeamFouls(let side):
            return localizedAppFormat("Confirm %@ Team Foul Reset", store.sideRoleLabel(for: side))
        case .resetSideCards(let side):
            return localizedAppFormat("Confirm %@ Card Reset", store.sideRoleLabel(for: side))
        case .clearPlayerState(let side, _):
            return localizedAppFormat("Confirm %@ Player Clear", store.sideRoleLabel(for: side))
        case .clearPenalty(let side, _):
            return localizedAppFormat("Confirm %@ Penalty Clear", store.sideRoleLabel(for: side))
        case .resetSoundSettings:
            return localizedAppString("Confirm Sound Reset")
        }
    }

    private func gameConfirmationMessage(for action: GameConfirmationAction) -> String {
        switch action {
        case .awardVolleyballSet(let side):
            let isLegalScore = store.selectedSport != .volleyball || store.isLegalVolleyballSetWin(for: side)
            let scoreLine = localizedAppFormat("Current score is %d-%d.", store.homeScore, store.guestScore)
            if isLegalScore {
                return localizedAppFormat("%@ Award Period %d to %@, reset the score to 0-0, and reset the timer?", scoreLine, store.period, store.sideRoleLabel(for: side))
            }
            return localizedAppFormat("%@ This is not a standard period-winning score for Period %d, which is played to %d and must be won by two. Award it anyway?", scoreLine, store.period, store.volleyballCurrentSetTarget)
        case .undoVolleyballSet:
            return localizedAppString("Restore the last recorded period score, remove that period result, and return to that period?")
        case .previousPeriod:
            return localizedAppFormat("Move back one %@?", localizedAppString(store.periodTitle).lowercased())
        case .resetClock:
            return localizedAppFormat("Reset the game clock to %@?", formatClock(store.defaultClockSeconds))
        case .resetShotClock:
            return localizedAppFormat("Reset the %@ to its active preset?", store.secondaryTimerTitle.lowercased())
        case .zeroScores:
            return localizedAppString("Set both team scores back to zero?")
        case .resetChessClocks:
            return localizedAppString("Reset both side clocks to their configured starting time?")
        case .resetDebateSegment:
            return localizedAppString("Reset the current debate segment timer?")
        case .resetDebateRound:
            return localizedAppString("Reset the full debate round, including segment, prep, and player state?")
        case .resetDebatePrep(let side):
            return localizedAppFormat("Reset %@ prep time?", store.sideRoleLabel(for: side))
        case .resetAllPlayerFouls:
            return localizedAppString("Reset all player fouls for both sides?")
        case .resetAllTeamFouls:
            return localizedAppString("Reset all team fouls for both sides?")
        case .resetAllCards:
            return localizedAppString("Clear all player cards for both sides?")
        case .resetSidePlayerFouls(let side):
            return localizedAppFormat("Reset all player fouls for %@?", store.sideRoleLabel(for: side))
        case .resetSideTeamFouls(let side):
            return localizedAppFormat("Reset team fouls for %@?", store.sideRoleLabel(for: side))
        case .resetSideCards(let side):
            return localizedAppFormat("Clear all player cards for %@?", store.sideRoleLabel(for: side))
        case .clearPlayerState(let side, _):
            return localizedAppFormat("Clear this %@ player's card state and foul count?", store.sideRoleLabel(for: side))
        case .clearPenalty(let side, _):
            return localizedAppFormat("Clear this %@ penalty timer?", store.sideRoleLabel(for: side))
        case .resetSoundSettings:
            return localizedAppString("Reset Sound On and all event sound assignments to their defaults across every sport and mode?")
        }
    }

    private func gameConfirmationButtonTitle(for action: GameConfirmationAction) -> String {
        switch action {
        case .awardVolleyballSet:
            return localizedAppString("Award Period")
        case .undoVolleyballSet:
            return localizedAppString("Undo & Return")
        case .previousPeriod:
            return localizedAppFormat("Previous %@", localizedAppString(store.periodTitle))
        case .resetClock:
            return localizedAppString("Reset Clock")
        case .resetShotClock:
            return localizedAppFormat("Reset %@", store.secondaryTimerActionTitle)
        case .zeroScores:
            return localizedAppString("Zero Scores")
        case .resetChessClocks:
            return localizedAppString("Reset Clocks")
        case .resetDebateSegment:
            return localizedAppString("Reset Segment")
        case .resetDebateRound:
            return localizedAppString("Reset Round")
        case .resetDebatePrep:
            return localizedAppString("Reset Prep")
        case .resetAllPlayerFouls, .resetSidePlayerFouls:
            return localizedAppString("Reset Fouls")
        case .resetAllTeamFouls, .resetSideTeamFouls:
            return localizedAppString("Reset Team Fouls")
        case .resetAllCards, .resetSideCards:
            return localizedAppString("Clear Cards")
        case .clearPlayerState:
            return localizedAppString("Clear Player")
        case .clearPenalty:
            return localizedAppString("Clear Penalty")
        case .resetSoundSettings:
            return localizedAppString("Reset Sound")
        }
    }

    private func requestGameConfirmation(_ action: GameConfirmationAction) {
        if pendingGameConfirmation?.id == action.id {
            pendingGameConfirmation = nil
            DispatchQueue.main.async {
                pendingGameConfirmation = action
            }
        } else {
            pendingGameConfirmation = action
        }
    }

    private func performConfirmedGameAction(_ action: GameConfirmationAction) {
        switch action {
        case .awardVolleyballSet(let side):
            store.awardPeriod(to: side)
        case .undoVolleyballSet:
            store.undoLastPeriodWin()
        case .previousPeriod:
            store.adjustPeriod(by: -1)
        case .resetClock:
            store.resetClock(to: store.defaultClockSeconds)
        case .resetShotClock:
            store.resetActiveShotClock()
        case .zeroScores:
            store.resetScores()
        case .resetChessClocks:
            store.resetChessClocks()
        case .resetDebateSegment:
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                store.resetDebateCurrentSegment()
            }
        case .resetDebateRound:
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                store.resetDebateRound()
            }
        case .resetDebatePrep(let side):
            store.resetDebatePrepClock(for: side)
        case .resetAllPlayerFouls:
            store.resetAllPlayerFouls()
        case .resetAllTeamFouls:
            store.resetAllTeamFouls()
        case .resetAllCards:
            store.resetAllPlayerCards()
        case .resetSidePlayerFouls(let side):
            store.resetFouls(for: side)
        case .resetSideTeamFouls(let side):
            store.resetTeamFouls(for: side)
        case .resetSideCards(let side):
            store.resetCards(for: side)
        case .clearPlayerState(let side, let playerID):
            store.setCardStatus(.none, for: side, playerID: playerID)
            if store.supportsFouls {
                store.resetFouls(for: side, playerID: playerID)
            }
        case .clearPenalty(let side, let timerID):
            store.removePenaltyTimer(for: side, timerID: timerID)
        case .resetSoundSettings:
            store.resetSoundSettingsToDefaults()
        }
    }
}

private struct ActionDescriptor {
    let title: String
    let tint: Color
    var foreground: Color = .white
    var isEnabled: Bool = true
    let action: () -> Void
}

private struct PendingPenaltySelection: Identifiable {
    let id = UUID()
    let side: TeamSide
    let seconds: Int
}

private struct SettingsDetailRow: Identifiable {
    let id: String
    let title: String
    let value: String
}

private struct SettingsGameFileDetailPane: View {
    let selectedFile: StoredGameFile?
    let workingRows: [SettingsDetailRow]
    @Binding var renameDraft: String
    let canRename: Bool
    let palette: SettingsPalette
    let keyboardBottomInset: CGFloat
    let onRename: () -> Void
    @State private var isRenameEditorVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let selectedFile {
                    selectedNameRow(selectedFile)
                    if isRenameEditorVisible {
                        divider
                        renameRow
                    }
                    divider
                    detailRows(selectedRows(for: selectedFile))
                    divider
                }

                detailRows(workingRows)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .scoreboardSettingsKeyboardAwareScroll(bottomInset: keyboardBottomInset)
        .onChange(of: selectedFile?.id) { _, _ in
            isRenameEditorVisible = false
        }
    }

    private func selectedNameRow(_ file: StoredGameFile) -> some View {
        HStack(spacing: 12) {
            Text(localizedAppString("Selected Name"))
                .foregroundStyle(palette.primaryText)

            Spacer(minLength: 0)

            Text(file.displayName)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)

            Button {
                isRenameEditorVisible.toggle()
            } label: {
                Text(localizedAppString(isRenameEditorVisible ? "Hide" : "Edit"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(palette.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }

    private var renameRow: some View {
        HStack(spacing: 12) {
            Text("Selected Name")
                .foregroundStyle(palette.primaryText)

            Spacer(minLength: 0)

            TextField("Game File", text: $renameDraft)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .foregroundStyle(palette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(palette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: 280)
                .onSubmit(onRename)

            Button(action: onRename) {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(canRename ? palette.accentText : palette.secondaryText)
                    .frame(width: 38, height: 38)
                    .background(canRename ? palette.accent : palette.fieldBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canRename)
            .opacity(canRename ? 1 : 0.42)
        }
        .padding(.vertical, 10)
    }

    private func selectedRows(for file: StoredGameFile) -> [SettingsDetailRow] {
        [
            SettingsDetailRow(id: "file", title: "File", value: file.url.lastPathComponent),
            SettingsDetailRow(id: "modified", title: "Modified", value: file.modifiedAt.formatted(date: .abbreviated, time: .shortened)),
            SettingsDetailRow(id: "matchup", title: "Matchup", value: file.matchupLine),
            SettingsDetailRow(id: "state", title: "State", value: file.stateLine)
        ]
    }

    private func detailRows(_ rows: [SettingsDetailRow]) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            summaryRow(row)
            if index < rows.count - 1 {
                divider
            }
        }
    }

    private func summaryRow(_ row: SettingsDetailRow) -> some View {
        HStack(spacing: 16) {
            Text(localizedAppString(row.title))
                .foregroundStyle(palette.primaryText)
            Spacer(minLength: 0)
            Text(row.value)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Divider()
            .overlay(palette.divider)
    }
}

private struct StoredGameFile: Identifiable {
    let url: URL
    let modifiedAt: Date
    let summary: StoredGameFileSummary?

    var id: String { url.path }
    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var matchupLine: String {
        summary?.matchupLine ?? localizedAppString("Game file")
    }
    var stateLine: String {
        summary?.stateLine ?? localizedAppString("Preview unavailable")
    }
    var detailLine: String { "Modified \(modifiedAt.formatted(date: .abbreviated, time: .shortened))" }
}

private struct StoredGameFileSummary: Decodable {
    let sport: SportType?
    let customSportConfig: CustomSportConfig?
    let homeTeamName: String
    let guestTeamName: String
    let period: Int
    let defaultClockSeconds: Int
    let defaultShotClockSeconds: Int
    let homeChessClockSeconds: Int?
    let guestChessClockSeconds: Int?

    var matchupLine: String {
        let home = homeTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedAppString("TBD") : homeTeamName
        let guest = guestTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedAppString("TBD") : guestTeamName
        return localizedAppFormat("%@ vs %@", home, guest)
    }

    var stateLine: String {
        let sport = sport ?? .basketball
        let rules = sport.rules(customConfig: customSportConfig)
        let sportTitle = localizedAppString(rules.title)
        let clockLine = Self.formatGameClock(defaultClockSeconds)

        if rules.usesChessClocks {
            let homeClock = Self.formatGameClock(homeChessClockSeconds ?? ChessClockPreset.rapid.seconds)
            let guestClock = Self.formatGameClock(guestChessClockSeconds ?? ChessClockPreset.rapid.seconds)
            return "\(sportTitle) • \(homeClock) / \(guestClock)"
        }

        if rules.supportsShotClock {
            let periodSegment = rules.supportsPeriod ? "\(rules.periodShortTitle)\(period) • " : ""
            return "\(sportTitle) • \(periodSegment)\(clockLine) • SC \(Self.formatShotClock(defaultShotClockSeconds))"
        }

        if rules.supportsPeriod {
            let periodLine = "\(rules.periodShortTitle)\(period)"
            return "\(sportTitle) • \(periodLine) • \(clockLine)"
        }

        return "\(sportTitle) • \(clockLine)"
    }

    private enum CodingKeys: String, CodingKey {
        case sport
        case customSportConfig
        case homeTeamName
        case guestTeamName
        case period
        case defaultClockSeconds
        case defaultShotClockSeconds
        case homeChessClockSeconds
        case guestChessClockSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sport = try container.decodeIfPresent(SportType.self, forKey: .sport)
        customSportConfig = try container.decodeIfPresent(CustomSportConfig.self, forKey: .customSportConfig)
        homeTeamName = try container.decodeIfPresent(String.self, forKey: .homeTeamName) ?? ""
        guestTeamName = try container.decodeIfPresent(String.self, forKey: .guestTeamName) ?? ""
        period = try container.decodeIfPresent(Int.self, forKey: .period) ?? 1
        defaultClockSeconds = try container.decodeIfPresent(Int.self, forKey: .defaultClockSeconds) ?? 10 * 60
        defaultShotClockSeconds = try container.decodeIfPresent(Int.self, forKey: .defaultShotClockSeconds) ?? 0
        homeChessClockSeconds = try container.decodeIfPresent(Int.self, forKey: .homeChessClockSeconds)
        guestChessClockSeconds = try container.decodeIfPresent(Int.self, forKey: .guestChessClockSeconds)
    }

    private static func formatGameClock(_ totalSeconds: Int) -> String {
        let boundedSeconds = max(0, totalSeconds)
        let minutes = boundedSeconds / 60
        let seconds = boundedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func formatShotClock(_ totalSeconds: Int) -> String {
        let boundedSeconds = max(0, min(99, totalSeconds))
        return String(format: "%.1f", Double(boundedSeconds))
    }
}

private struct ExportSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct FileOperationAlert: Identifiable {
    let id = UUID()
    let message: String
}

private struct PendingBackupRestore: Identifiable {
    let id = UUID()
    let backup: ScoreboardAppBackup
    let sourceFilename: String
}

private struct PendingRemoteDisplayTakeover: Identifiable {
    enum Action {
        case pair(code: String)
        case connectTrusted
    }

    let id = UUID()
    let source: ScoreboardRemoteDisplaySource
    let action: Action
}

private struct RemoteDisplaySettingsRow: Identifiable {
    let id: String
    let name: String
    let deviceType: ScoreboardRemoteDisplayDeviceType
    let source: ScoreboardRemoteDisplaySource?
    let connection: ScoreboardRemoteDisplayConnection?
    let trusted: ScoreboardRemoteDisplayTrustedPeer?
    let isTrusted: Bool
    let isMuted: Bool

    var isConnected: Bool {
        connection != nil
    }

    var isOffline: Bool {
        isTrusted && source == nil && connection == nil
    }

    var appVersion: ScoreboardRemoteDisplayAppVersion? {
        connection?.appVersion ?? source?.appVersion
    }

    var sortRank: Int {
        if isConnected {
            return 0
        }
        if source != nil {
            return 1
        }
        if trusted != nil {
            return 2
        }
        return 3
    }
}

private enum ActiveAlert: Identifiable {
    case fileOperation(FileOperationAlert)
    case gameConfirmation(GameConfirmationAction)
    case backupRestore(PendingBackupRestore)
    case remoteDisplayTakeover(PendingRemoteDisplayTakeover)
    case logDeletion(StoredLogSession)
    case factoryDefault

    var id: String {
        switch self {
        case .fileOperation(let error):
            return "file-\(error.id.uuidString)"
        case .gameConfirmation(let action):
            return "game-\(action.id)"
        case .backupRestore(let backupRestore):
            return "backup-\(backupRestore.id.uuidString)"
        case .remoteDisplayTakeover(let takeover):
            return "remoteDisplay-\(takeover.id.uuidString)"
        case .logDeletion(let session):
            return "log-\(session.id)"
        case .factoryDefault:
            return "factoryDefault"
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case game
    case players
    case display
    case sound
    case theme
    case files
    case logs
    case integration
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .game:
            return "Game Setup"
        case .players:
            return "Players"
        case .display:
            return "Display"
        case .sound:
            return "Sound"
        case .theme:
            return "Theme"
        case .files:
            return "Library"
        case .logs:
            return "Logs"
        case .integration:
            return "Integration"
        case .about:
            return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .game:
            return "Edit teams, period, and clock defaults before opening the live control board."
        case .players:
            return "Configure roster size, player identities, active lineup, and foul tracking."
        case .display:
            return "Configure public scoreboard lineup display, foul highlighting, and red alert timing."
        case .sound:
            return "Control global audio and preview sport-specific timer sounds."
        case .theme:
            return "Choose the look for both the operator controls and public scoreboard."
        case .files:
            return "Manage local game files for both reusable setups and live games."
        case .logs:
            return "Review per-run audit sessions with export and delete tools."
        case .integration:
            return "Connect Scoreboard to broadcast tools, overlays, and automation systems."
        case .about:
            return "View app information, icon, version, and license details."
        }
    }

    var systemImage: String {
        switch self {
        case .game:
            return "slider.horizontal.3"
        case .players:
            return "person.3"
        case .display:
            return "tv"
        case .sound:
            return "speaker.wave.2"
        case .theme:
            return "paintpalette"
        case .files:
            return "books.vertical"
        case .logs:
            return "list.bullet.rectangle.portrait"
        case .integration:
            return "network"
        case .about:
            return "info.circle"
        }
    }

    var usesFileManagerLayout: Bool {
        self == .files || self == .logs
    }
}

private enum IntegrationSettingsDetail: Int, CaseIterable, Identifiable {
    case remoteDisplay
    case webAPI
    case bitfocusCompanion

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .webAPI:
            return "Web API"
        case .remoteDisplay:
            return "Remote Display"
        case .bitfocusCompanion:
            return "Bitfocus Companion"
        }
    }

    var subtitle: String {
        switch self {
        case .webAPI:
            return "Read scoreboard state with HTTP and WebSocket."
        case .remoteDisplay:
            return "Pair nearby Apple TV, iPad, or Mac display devices."
        case .bitfocusCompanion:
            return "Trigger Companion commands from scoreboard events."
        }
    }

    var introduction: String {
        switch self {
        case .webAPI:
            return "Use this when local overlays, browser sources, or scripts need a read-only stream of live scoreboard state from the operator device."
        case .remoteDisplay:
            return "Use this when another Apple device should show the public scoreboard while the operator keeps private controls on the main device."
        case .bitfocusCompanion:
            return "Use this when scoreboard moments should press Companion buttons for graphics, scene changes, lighting, or other production automation."
        }
    }

    var systemImage: String {
        switch self {
        case .webAPI:
            return "network"
        case .remoteDisplay:
            return "tv.and.mediabox"
        case .bitfocusCompanion:
            return "square.grid.3x3"
        }
    }
}

private enum LogPlaybackOrder: String, CaseIterable, Identifiable {
    case topToBottom
    case bottomToTop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topToBottom:
            return "Top to Bottom"
        case .bottomToTop:
            return "Bottom to Top"
        }
    }
}

private enum ExportDestination {
    case file
    case share
}

private enum ButtonStyleVariant: Equatable {
    case compact
    case large
}

private enum DashboardPage: Hashable {
    case main
    case players
    case preview
}

private enum GameConfirmationAction: Identifiable {
    case awardVolleyballSet(TeamSide)
    case undoVolleyballSet
    case previousPeriod
    case resetClock
    case resetShotClock
    case zeroScores
    case resetChessClocks
    case resetDebateSegment
    case resetDebateRound
    case resetDebatePrep(TeamSide)
    case resetAllPlayerFouls
    case resetAllTeamFouls
    case resetAllCards
    case resetSidePlayerFouls(TeamSide)
    case resetSideTeamFouls(TeamSide)
    case resetSideCards(TeamSide)
    case clearPlayerState(TeamSide, UUID)
    case clearPenalty(TeamSide, UUID)
    case resetSoundSettings

    var id: String {
        switch self {
        case .awardVolleyballSet(let side):
            return "awardVolleyballSet-\(side.rawValue)"
        case .undoVolleyballSet:
            return "undoVolleyballSet"
        case .previousPeriod:
            return "previousPeriod"
        case .resetClock:
            return "resetClock"
        case .resetShotClock:
            return "resetShotClock"
        case .zeroScores:
            return "zeroScores"
        case .resetChessClocks:
            return "resetChessClocks"
        case .resetDebateSegment:
            return "resetDebateSegment"
        case .resetDebateRound:
            return "resetDebateRound"
        case .resetDebatePrep(let side):
            return "resetDebatePrep-\(side.rawValue)"
        case .resetAllPlayerFouls:
            return "resetAllPlayerFouls"
        case .resetAllTeamFouls:
            return "resetAllTeamFouls"
        case .resetAllCards:
            return "resetAllCards"
        case .resetSidePlayerFouls(let side):
            return "resetSidePlayerFouls-\(side.rawValue)"
        case .resetSideTeamFouls(let side):
            return "resetSideTeamFouls-\(side.rawValue)"
        case .resetSideCards(let side):
            return "resetSideCards-\(side.rawValue)"
        case .clearPlayerState(let side, let playerID):
            return "clearPlayerState-\(side.rawValue)-\(playerID.uuidString)"
        case .clearPenalty(let side, let timerID):
            return "clearPenalty-\(side.rawValue)-\(timerID.uuidString)"
        case .resetSoundSettings:
            return "resetSoundSettings"
        }
    }

}

private struct InterfaceLayout {
    let size: CGSize

    private var width: CGFloat { size.width }
    private var height: CGFloat { size.height }

    var isCompactWidth: Bool { width < 840 }
    var isShortHeight: Bool { height < 760 }
    var isPortraitish: Bool { height > width * 1.05 }
    var isTabletSized: Bool { width >= 768 && width <= 1366 && height >= 700 }
    var denseControls: Bool { isShortHeight || isPortraitish || width < 980 }

    var outerPadding: CGFloat {
        if isCompactWidth { return 16 }
        if isTabletSized { return 14 }
        return 24
    }
    var cardPadding: CGFloat { isCompactWidth ? 18 : 28 }
    var sectionSpacing: CGFloat {
        if isCompactWidth { return 14 }
        if isTabletSized { return 12 }
        return 18
    }
    var cardCornerRadius: CGFloat { isCompactWidth ? 26 : 34 }
    var contentMaxWidth: CGFloat { min(max(width - (outerPadding * 2), 0), 1480) }

    var heroTitleSize: CGFloat { isCompactWidth ? 34 : 40 }
    var fieldFontSize: CGFloat { isCompactWidth ? 24 : 28 }
    var teamFieldFontSize: CGFloat { denseControls ? 18 : isCompactWidth ? 20 : 22 }
    var metricValueSize: CGFloat { denseControls ? 32 : isCompactWidth ? 34 : 40 }
    var scoreValueSize: CGFloat { denseControls ? 34 : isCompactWidth ? 40 : 48 }
    var bodyFont: Font { isCompactWidth ? .subheadline : .headline }
    var headerTitleSize: CGFloat { denseControls ? 22 : 26 }
    var headerSubtitleFont: Font { denseControls ? .caption : .subheadline }
    var headerBadgeFont: Font { denseControls ? .caption.weight(.semibold) : .subheadline.weight(.semibold) }
    var headerBadgeDetailFont: Font { denseControls ? .caption2.weight(.semibold) : .caption.weight(.semibold) }
    var headerTitleSpacing: CGFloat { denseControls ? 4 : 5 }
    var headerBlockSpacing: CGFloat { denseControls ? 8 : isTabletSized ? 7 : 12 }
    var headerInlineSpacing: CGFloat { denseControls ? 12 : isTabletSized ? 10 : 14 }
    var headerHorizontalPadding: CGFloat { denseControls ? 14 : isTabletSized ? 12 : 18 }
    var headerVerticalPadding: CGFloat { denseControls ? 10 : isTabletSized ? 8 : 12 }
    var headerBadgeHorizontalPadding: CGFloat { denseControls ? 10 : isTabletSized ? 9 : 12 }
    var headerBadgeVerticalPadding: CGFloat { denseControls ? 6 : isTabletSized ? 5 : 8 }
    var headerActionVerticalPadding: CGFloat { denseControls ? 8 : isTabletSized ? 7 : 10 }
    var headerActionRowStride: CGFloat { 52 }
    var headerToggleButtonSize: CGFloat { denseControls ? 34 : 38 }
    var headerIconButtonSize: CGFloat { headerToggleButtonSize }
    var headerToggleIconFont: Font { denseControls ? .subheadline.weight(.bold) : .headline.weight(.bold) }
    var controlCardPadding: CGFloat { denseControls ? 14 : isTabletSized ? 12 : 18 }
    var controlCardCornerRadius: CGFloat { denseControls ? 24 : 28 }

    var setupUsesVerticalFlow: Bool { width < 1260 || height < 860 }
    var setupControlCardsStacked: Bool { width < 760 }
    var setupFormWidth: CGFloat { min(max(contentMaxWidth * 0.38, 420), 540) }
    var setupPreviewHeight: CGFloat { max(280, min(height * 0.52, 520)) }
    var setupActionColumns: Int { isCompactWidth ? 1 : 2 }
    var secondaryButtonColumns: Int { width < 620 ? 1 : 2 }

    var dashboardHeaderHeight: CGFloat {
        if isPortraitish { return 142 }
        if isTabletSized { return denseControls || headerUsesVerticalFlow ? 108 : 72 }
        return denseControls || headerUsesVerticalFlow ? 122 : 80
    }

    var headerUsesVerticalFlow: Bool { isPortraitish || width < 920 }
    var headerActionColumns: Int {
        if width < 520 { return 1 }
        if width < 760 { return 2 }
        return 3
    }
    var headerActionWidth: CGFloat {
        #if os(macOS)
        return width < 1320 ? 620 : 720
        #else
        return width < 1320 ? 480 : 560
        #endif
    }

    var requiresDashboardScroll: Bool { isPortraitish || width < 760 || height < 820 }
    var topControlUsesVerticalFlow: Bool { width < 720 }
    var controlBottomUsesVerticalFlow: Bool { width < 980 || isPortraitish }
    var centerStatusWidth: CGFloat { width < 960 ? 280 : width < 1280 ? 320 : 360 }
    var centerScoreSize: CGFloat { denseControls ? 42 : width < 1280 ? 50 : 58 }
    var centerMetricValueSize: CGFloat { denseControls ? 24 : 28 }
    var centerMetricColumns: Int { width < 720 ? 1 : 3 }
    var teamButtonColumns: Int { width < 900 ? 1 : 2 }
    var playerActionButtonColumns: Int { width < 700 ? 2 : 4 }
    var playerPanelsUseVerticalFlow: Bool { width < 1180 }
    func controlTopSectionHeight(in totalHeight: CGFloat) -> CGFloat {
        if topControlUsesVerticalFlow {
            return min(max(totalHeight * 0.58, 360), totalHeight - 140)
        }
        return min(max(totalHeight * (isTabletSized ? 0.45 : 0.48), isTabletSized ? 250 : 280), isTabletSized ? 330 : 360)
    }
    var advancedButtonVerticalPadding: CGFloat { denseControls ? 8 : isTabletSized ? 7 : 11 }
    var shotClockButtonColumns: Int {
        if width < 520 { return 2 }
        if width < 900 { return 3 }
        return 5
    }

    var previewPanelPadding: CGFloat { denseControls ? 16 : isCompactWidth ? 18 : 24 }
    var previewHeaderUsesVerticalFlow: Bool { isCompactWidth }
    var previewUsesCompactBoard: Bool { width < 1280 || height < 780 }
    var settingsUsesCompactNavigation: Bool { width < 700 }
    var settingsOuterPadding: CGFloat {
        if width < 430 { return 8 }
        if width < 700 { return 10 }
        return outerPadding
    }
    var settingsShellCornerRadius: CGFloat { width < 430 ? 20 : 30 }
    var settingsSidebarWidth: CGFloat { max(220, min(width * 0.24, 280)) }
    var settingsCompactNavigationHorizontalPadding: CGFloat { width < 430 ? 10 : 14 }
    var settingsCompactNavigationVerticalPadding: CGFloat { width < 430 ? 8 : 12 }
    var settingsDetailPadding: CGFloat {
        if width < 430 { return 14 }
        if width < 700 { return 18 }
        return 28
    }
    var settingsDetailSpacing: CGFloat { width < 700 ? 18 : 24 }
    var settingsHeaderTitleSize: CGFloat {
        if width < 430 { return 24 }
        if width < 700 { return 26 }
        return 30
    }
    var settingsFileManagerPrimaryColumnWidth: CGFloat {
        if width < 860 { return 240 }
        if width < 1180 { return 300 }
        return 360
    }
    var settingsFileManagerListMinimumHeight: CGFloat {
        isShortHeight ? 260 : 360
    }
    var settingsTwoColumnUsesVerticalFlow: Bool { width < 1180 }
    var settingsPrimaryColumnWidth: CGFloat {
        min(max(contentMaxWidth * 0.34, 340), 460)
    }
}

private extension View {
    func singleLineFitted(minScale: CGFloat = 0.55) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minScale)
    }

    @ViewBuilder
    func scoreboardUppercaseEntry() -> some View {
        #if os(macOS)
        self
        #else
        textInputAutocapitalization(.characters)
        #endif
    }

    @ViewBuilder
    func scoreboardPlainTextEntry() -> some View {
        #if os(macOS)
        self
        #else
        textInputAutocapitalization(.never)
        #endif
    }

    @ViewBuilder
    func scoreboardNumberEntry() -> some View {
        #if os(macOS)
        self
        #else
        keyboardType(.numberPad)
        #endif
    }

    @ViewBuilder
    func scoreboardSettingsKeyboardAwareScroll(bottomInset: CGFloat) -> some View {
        #if os(iOS)
        self
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: bottomInset)
            }
            .scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }

    @ViewBuilder
    func scoreboardSetupListStyle() -> some View {
        #if os(macOS)
        listStyle(.inset)
        #else
        listStyle(.insetGrouped)
        #endif
    }

    func scoreboardTextField(
        font: Font,
        tint: Color,
        cornerRadius: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat
    ) -> some View {
        self
            .font(font)
            .foregroundStyle(.white)
            .tint(.white)
            .autocorrectionDisabled()
            #if os(macOS)
            .textFieldStyle(.plain)
            #endif
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(tint, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            )
    }

    func controlCardStyle(
        backgroundColor: Color,
        borderColor: Color,
        padding: CGFloat = 18,
        cornerRadius: CGFloat = 28
    ) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    func scoreboardShareExporter(payload: Binding<ExportSharePayload?>) -> some View {
        #if os(iOS)
        sheet(item: payload) { payload in
            ScoreboardActivityView(activityItems: [payload.url])
        }
        #elseif os(macOS)
        background(ScoreboardSharingPickerPresenter(payload: payload))
        #else
        self
        #endif
    }

    @ViewBuilder
    func monospacedDigitIfNeeded(_ enabled: Bool) -> some View {
        if enabled {
            monospacedDigit()
        } else {
            self
        }
    }
}

private struct DeferredSettingsTextField: View {
    let placeholder: String
    @Binding var text: String
    let focusID: String
    let focusedField: FocusState<String?>.Binding
    @State private var draft: String

    init(
        placeholder: String,
        text: Binding<String>,
        focusID: String,
        focusedField: FocusState<String?>.Binding
    ) {
        self.placeholder = placeholder
        self._text = text
        self.focusID = focusID
        self.focusedField = focusedField
        self._draft = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        TextField(placeholder, text: $draft)
            .focused(focusedField, equals: focusID)
            .onSubmit(commitDraft)
            .onChange(of: focusedField.wrappedValue) { oldValue, newValue in
                if oldValue == focusID, newValue != focusID {
                    commitDraft()
                } else if newValue == focusID, oldValue != focusID {
                    draft = text
                }
            }
            .onChange(of: text) { _, newValue in
                guard focusedField.wrappedValue != focusID else {
                    return
                }
                draft = newValue
            }
            .onDisappear(perform: commitDraft)
    }

    private func commitDraft() {
        guard text != draft else {
            return
        }
        text = draft
    }
}

#if os(iOS)
private struct ScoreboardDocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let contentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onCompletion: (Result<[URL], Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        uiViewController.allowsMultipleSelection = allowsMultipleSelection
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private var isPresented: Binding<Bool>
        private let onCompletion: (Result<[URL], Error>) -> Void

        init(
            isPresented: Binding<Bool>,
            onCompletion: @escaping (Result<[URL], Error>) -> Void
        ) {
            self.isPresented = isPresented
            self.onCompletion = onCompletion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            isPresented.wrappedValue = false
            onCompletion(.success(urls))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            isPresented.wrappedValue = false
        }
    }
}

private struct ScoreboardActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#if os(macOS)
private struct ScoreboardSharingPickerPresenter: NSViewRepresentable {
    @Binding var payload: ExportSharePayload?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let payload, context.coordinator.presentedID != payload.id else {
            return
        }

        context.coordinator.presentedID = payload.id
        DispatchQueue.main.async {
            let anchorView = nsView.window?.contentView ?? nsView
            let anchorBounds = anchorView.bounds
            let anchorRect = NSRect(
                x: anchorBounds.midX,
                y: anchorBounds.midY,
                width: 1,
                height: 1
            )
            let picker = NSSharingServicePicker(items: [payload.url])
            picker.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .minY)
            self.payload = nil
        }
    }

    final class Coordinator {
        var presentedID: UUID?
    }
}
#endif

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .frame(width: 1480, height: 920)
                .previewDisplayName("Mac Wide")

            ContentView()
                .frame(width: 1024, height: 768)
                .previewDisplayName("iPad Landscape")

            ContentView()
                .frame(width: 744, height: 1133)
                .previewDisplayName("iPad Narrow")

            ContentView()
                .frame(width: 393, height: 852)
                .previewDisplayName("iPhone")
        }
        .environmentObject(ScoreboardStore.shared)
        .environmentObject(PublicBoardState.shared)
    }
}

#if os(macOS)
private struct ControlBoardWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.configureWindowIfNeeded(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configureWindowIfNeeded(for: nsView)
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        private var positionedWindowNumbers = Set<Int>()
        private var delegatedWindowNumbers = Set<Int>()

        func configureWindowIfNeeded(for view: NSView) {
            guard let window = view.window else {
                return
            }

            if delegatedWindowNumbers.insert(window.windowNumber).inserted {
                window.delegate = self
            }

            guard
                positionedWindowNumbers.insert(window.windowNumber).inserted,
                let primaryScreen = NSScreen.screens.first
            else {
                return
            }

            let visibleFrame = primaryScreen.visibleFrame
            let currentSize = window.frame.size
            let fittedSize = CGSize(
                width: min(currentSize.width, visibleFrame.width),
                height: min(currentSize.height, visibleFrame.height)
            )
            let origin = CGPoint(
                x: visibleFrame.midX - (fittedSize.width / 2),
                y: visibleFrame.midY - (fittedSize.height / 2)
            )

            window.setFrame(CGRect(origin: origin, size: fittedSize), display: true)
        }

        func windowWillClose(_ notification: Notification) {
            NSApp.terminate(nil)
        }
    }
}
#endif

#endif
