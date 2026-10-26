import Foundation

@MainActor
final class SetupNavigationFixture: ScoreboardSetupEditing {
    let store: ScoreboardStore
    var pendingGameConfirmation: GameConfirmationAction?
    var focusedSettingsTextFieldID: String?
    var selectedSetupGameDisplayName: String?
    var ensureFileCalls = 0
    var autosaveRefreshes: [Bool] = []
    init(store: ScoreboardStore) { self.store = store }
    func selectGameSettingsPane() {}
    func requestSetupGameConfirmation(_ action: GameConfirmationAction) { pendingGameConfirmation = action }
    func ensureWorkingGameFileExists() { ensureFileCalls += 1 }
    func autosaveSelectedGameFile(refreshSelection: Bool) { autosaveRefreshes.append(refreshSelection) }
    func showPublicBoardWindow() {}
    func resolvedGameFilenameDraft(_ home: String, _ guest: String, includeExtension: Bool) -> String { "Game" }
    var homeTeamDraft = ""
    var guestTeamDraft = ""
    var eventNameDraft = ""
    var setupSport: SportType = .simple
    var setupPeriod = 1
    var setupClockSeconds = 10 * 60
    var setupUsesGameClock = true
    var setupShotClockSeconds = 24
    var setupVolleyballMatchFormat: VolleyballMatchFormat = .bestOf5
    var setupGuestClockSeconds = ChessClockPreset.rapid.seconds
    var setupClockSecondsBaseline = 10 * 60
    var setupShotClockSecondsBaseline = 24
    var setupGuestClockSecondsBaseline = ChessClockPreset.rapid.seconds
    var setupChessPreset: ChessClockPreset = .rapid
    var setupCustomSportConfig: CustomSportConfig = .default
    var setupDebatePresetID = DebatePreset.publicForum.id
    var setupDebateHomeSideLabel = DebatePreset.publicForum.homeSideLabel
    var setupDebateGuestSideLabel = DebatePreset.publicForum.guestSideLabel
    var setupDebateScoreTrackingEnabled = DebatePreset.publicForum.defaultScoreTrackingEnabled
    var setupDebatePlayerTrackingEnabled = DebatePreset.publicForum.defaultPlayerTrackingEnabled
    var setupDebatePlayerFoulsEnabled = DebatePreset.publicForum.defaultPlayerFoulsEnabled
    var setupDebatePlayerCardsEnabled = DebatePreset.publicForum.defaultPlayerCardsEnabled
    var setupDebatePrepTimeEnabled = DebatePreset.publicForum.isPrepTimeEnabled
    var setupCustomDebatePreset = DebatePreset.customDefault
    var setupStoreOptionsBaseline: ScoreboardGameSnapshot?
    var selectedSoundSettingsSport: SportType = .simple
    var selectedCompanionSettingsSport: SportType = .simple
    var gameFileNameDraft = ""
    var showsSetup = !ScoreboardStore.shared.didCompleteSetup
    var isApplyingSetupSportDefaults = false
    var isLoadingSetupDrafts = false
    var hasPendingSetupEdits = false
    var isCommittingSetupEdits = false
    var isInitialSetupStateLoaded = false
}
