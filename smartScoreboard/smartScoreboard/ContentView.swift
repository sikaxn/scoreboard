import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @State private var homeTeamDraft = ScoreboardStore.shared.homeTeamName
    @State private var guestTeamDraft = ScoreboardStore.shared.guestTeamName
    @State private var setupSport = ScoreboardStore.shared.selectedSport
    @State private var setupPeriod = ScoreboardStore.shared.period
    @State private var setupClockSeconds = ScoreboardStore.shared.defaultClockSeconds
    @State private var setupUsesGameClock = ScoreboardStore.shared.isGameClockEnabled
    @State private var setupShotClockSeconds = ScoreboardStore.shared.defaultShotClockSeconds
    @State private var gameFileNameDraft = ""
    @State private var showsSetup = !ScoreboardStore.shared.didCompleteSetup
    @State private var selectedSettingsPane: SettingsPane = .game
    @State private var storedGameFiles: [StoredGameFile] = []
    @State private var selectedStoredGameFileID: String?
    @State private var storedLogSessions: [StoredLogSession] = []
    @State private var selectedStoredLogSessionID: String?
    @State private var showsGameImporter = false
    @State private var showsGameExporter = false
    @State private var showsLogExporter = false
    @State private var exportDocument = ScoreboardGameDocument(snapshot: .empty)
    @State private var exportFilename = "Scoreboard Game.scoreboardgame"
    @State private var logExportDocument = ScoreboardLogExportDocument()
    @State private var logExportFilename = "Scoreboard Log.json"
    @State private var logExportContentType: UTType = .scoreboardLogSession
    @State private var fileOperationError: FileOperationAlert?
    @State private var dashboardPage: DashboardPage = .main
    @State private var pendingGameConfirmation: GameConfirmationAction?
    @State private var pendingLogDeletion: StoredLogSession?

    private var themePalette: ThemePalette { store.theme.palette }
    private var settingsPalette: SettingsPalette { themePalette.settingsPalette(for: store.theme, colorScheme: colorScheme) }
    private var homeTint: Color { themePalette.homeAccent }
    private var guestTint: Color { themePalette.guestAccent }
    private let logManager = ScoreboardLogManager.shared

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
        .onReceive(store.$homeScore) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestScore) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$period) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$selectedSport) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$gameClockSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$defaultClockSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$shotClockMilliseconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$defaultShotClockSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$activeShotClockPresetSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$possessionDirection) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$areSidesSwapped) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isPlayerTrackingEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isPlayerOverlayPaused) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$rosterSizePerTeam) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$displayLineupSize) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$playerFoulHighlightColor) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isGameClockRedEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$gameClockRedThresholdSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$isShotClockRedEnabled) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$shotClockRedThresholdSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeSubstitutionsAllowed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestSubstitutionsAllowed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeSubstitutionsUsed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestSubstitutionsUsed) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeTeamFouls) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestTeamFouls) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$homeRoster) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestRoster) { _ in autosaveSelectedGameFile() }
    }

    private var lifecycleConfiguredRootView: some View {
        synchronizedRootView
        .onAppear(perform: handleRootAppear)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: homeTeamDraft) { _, _ in commitSetupEdits() }
        .onChange(of: guestTeamDraft) { _, _ in commitSetupEdits() }
        .onChange(of: setupSport) { _, newValue in
            applySetupSportDraft(newValue)
        }
        .onChange(of: setupPeriod) { _, _ in commitSetupEdits() }
        .onChange(of: setupClockSeconds) { _, _ in commitSetupEdits() }
        .onChange(of: setupUsesGameClock) { _, _ in commitSetupEdits() }
        .onChange(of: setupShotClockSeconds) { _, _ in commitSetupEdits() }
        .onChange(of: selectedStoredGameFileID) { _, _ in
            syncCurrentLogGameFile()
        }
        .onChange(of: store.isPlayerTrackingEnabled) { _, isEnabled in
            handlePlayerTrackingEnabledChange(isEnabled)
        }
    }

    private var filePresentationConfiguredRootView: some View {
        lifecycleConfiguredRootView
        .fileImporter(
            isPresented: $showsGameImporter,
            allowedContentTypes: [.scoreboardGame],
            allowsMultipleSelection: false
        ) { result in
            importGameIntoLibrary(result)
        }
        .fileExporter(
            isPresented: $showsGameExporter,
            document: exportDocument,
            contentType: .scoreboardGame,
            defaultFilename: exportFilename
        ) { result in
            handleGameExport(result)
        }
        .fileExporter(
            isPresented: $showsLogExporter,
            document: logExportDocument,
            contentType: logExportContentType,
            defaultFilename: logExportFilename
        ) { result in
            handleLogExport(result)
        }
    }

    private var alertConfiguredRootView: some View {
        filePresentationConfiguredRootView
        .alert(item: $fileOperationError) { error in
            Alert(
                title: Text("File Error"),
                message: Text(error.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
        .alert(item: $pendingGameConfirmation) { action in
            Alert(
                title: Text(action.title(periodTitle: store.periodTitle, resetClockTitle: formatClock(store.defaultClockSeconds))),
                message: Text(action.message(periodTitle: store.periodTitle)),
                primaryButton: .destructive(Text(action.confirmButtonTitle(periodTitle: store.periodTitle))) {
                    performConfirmedGameAction(action)
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $pendingLogDeletion) { session in
            Alert(
                title: Text("Delete Log Session"),
                message: Text(logDeletionMessage(for: session)),
                primaryButton: .destructive(Text("Delete")) {
                    deleteLogSession(session)
                },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .scoreboardLogSessionsDidChange)) { _ in
            refreshStoredLogSessions()
        }
        #if os(macOS)
        .background(ControlBoardWindowConfigurator())
        #endif
    }

    private func setupScreen(layout: InterfaceLayout) -> some View {
        HStack(spacing: 0) {
            settingsSidebar(layout: layout)
                .frame(width: max(220, min(layout.size.width * 0.24, 280)))

            settingsDetailPane(layout: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(settingsPalette.shellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(settingsPalette.divider)
        )
        .padding(layout.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func settingsSidebar(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Settings")
                    .font(.system(size: layout.heroTitleSize - 4, weight: .black, design: .rounded))
                    .foregroundStyle(settingsPalette.primaryText)

                Text(setupDescription)
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
            }

            VStack(spacing: 8) {
                ForEach(SettingsPane.allCases) { pane in
                    settingsSidebarButton(pane)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                #if os(macOS)
                Button {
                    openSetupGame()
                } label: {
                    Text(publicBoardState.isPresented ? "Reopen Scoreboard" : "Open Scoreboard")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(settingsPalette.accentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(settingsPalette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                #endif

                Button {
                    store.playTestBuzzer()
                } label: {
                    Text("Sound Test")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(settingsPalette.accentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(settingsPalette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!store.isSoundEnabled)
                .opacity(store.isSoundEnabled ? 1 : 0.42)

                if store.didCompleteSetup {
                    Button {
                        loadSetupDraftsFromStore()
                        showsSetup = false
                    } label: {
                        Text("Back to Live Board")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(settingsPalette.secondaryButtonText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(settingsPalette.secondaryButtonBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(settingsPalette.sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(settingsPalette.divider)
                .frame(width: 1)
        }
    }

    private func settingsSidebarButton(_ pane: SettingsPane) -> some View {
        Button {
            selectedSettingsPane = pane
        } label: {
            HStack(spacing: 12) {
                Image(systemName: pane.systemImage)
                    .font(.headline.weight(.semibold))
                    .frame(width: 22)

                Text(pane.title)
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
        .buttonStyle(.plain)
    }

    private func settingsDetailPane(layout: InterfaceLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedSettingsPane.title)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(settingsPalette.primaryText)

                        Text(selectedSettingsPane.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(settingsPalette.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                settingsPaneContent(layout: layout)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(settingsPalette.detailBackground)
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
        case .theme:
            settingsThemePane()
        case .files:
            settingsFilesPane()
        case .logs:
            settingsLogsPane()
        }
    }

    private func settingsGamePane(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Teams") {
                settingsTextEntryRow(title: "Home Team", text: $homeTeamDraft, teamSide: true)
                settingsDivider()
                settingsTextEntryRow(title: "Guest Team", text: $guestTeamDraft, teamSide: false)
            }

            settingsSection(title: "Game") {
                settingsPickerRow(
                    title: "Sport",
                    selection: $setupSport,
                    options: SportType.allCases
                ) { option in
                    option.title
                }
                settingsDivider()
                settingsStepperValueRow(
                    title: "Starting \(setupSport.periodTitle)",
                    value: "\(setupPeriod)",
                    decrement: { setupPeriod = max(1, setupPeriod - 1) },
                    increment: { setupPeriod = min(9, setupPeriod + 1) }
                )

                if setupSport == .volleyball {
                    settingsDivider()
                    settingsToggleRow(title: "Enable Match Timer", isOn: $setupUsesGameClock)
                }

                if setupSport != .volleyball || setupUsesGameClock {
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
                        options: clockPresetOptions(for: setupSport),
                        selection: $setupClockSeconds
                    )
                }

                if setupSport.supportsShotClock {
                    settingsDivider()
                    settingsStepperValueRow(
                        title: "Shot Clock",
                        value: ScoreboardStore.formatShotClock(setupShotClockSeconds),
                        decrement: { setupShotClockSeconds = max(0, setupShotClockSeconds - 1) },
                        increment: { setupShotClockSeconds = min(ScoreboardStore.maxShotClockSeconds, setupShotClockSeconds + 1) }
                    )
                    settingsDivider()
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

            settingsSection(title: "Substitutions", footer: "Set how many player swaps each team can use during the match.") {
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

    private func settingsThemePane() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Scoreboard Theme", footer: "Themes update the setup screen, live control board, preview, and external scoreboard together.") {
                ForEach(Array(ScoreboardTheme.allCases.enumerated()), id: \.element.id) { index, theme in
                    themeSelectionRow(theme)

                    if index < ScoreboardTheme.allCases.count - 1 {
                        settingsDivider()
                    }
                }
            }

            settingsSection(title: "External Display Background", footer: "Controls only the public/external display. The preview stays unchanged.") {
                ForEach(Array(ExternalDisplayBackgroundMode.allCases.enumerated()), id: \.element.id) { index, mode in
                    externalBackgroundModeRow(mode)

                    if index < ExternalDisplayBackgroundMode.allCases.count - 1 {
                        settingsDivider()
                    }
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

            if store.selectedSport.supportsPlayerTracking {
                settingsSection(title: "Home Roster", footer: "Edit player number, display name, and active lineup status for the home team.") {
                    settingsRosterEditor(side: .home, layout: layout)
                }

                settingsSection(title: "Guest Roster", footer: "Edit player number, display name, and active lineup status for the guest team.") {
                    settingsRosterEditor(side: .guest, layout: layout)
                }
            } else {
                settingsSection(title: "Tracking Unavailable", footer: "The current sport uses score, clock, and substitution controls only.") {
                    settingsSummaryValueRow(title: "Sport", value: store.selectedSport.title)
                }
            }
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
            }

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
                    settingsDivider()
                    settingsToggleRow(title: "Turn Shot Clock Red", isOn: Binding(
                        get: { store.isShotClockRedEnabled },
                        set: { store.isShotClockRedEnabled = $0 }
                    ))
                    settingsDivider()
                    settingsStepperValueRow(
                        title: "Shot Clock Red At",
                        value: "\(store.shotClockRedThresholdSeconds)s",
                        decrement: { store.shotClockRedThresholdSeconds = max(0, store.shotClockRedThresholdSeconds - 1) },
                        increment: { store.shotClockRedThresholdSeconds = min(ScoreboardStore.maxShotClockSeconds, store.shotClockRedThresholdSeconds + 1) }
                    )
                }
            }
        }
    }

    private func settingsFilesPane() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Game Files", footer: "Use game files for both reusable setups and live games. Save the current setup as a new file, then load, import, export, or delete from the same library.") {
                settingsTextEntryRow(title: "New Game File", text: $gameFileNameDraft, placeholder: "Weekend League")
                settingsDivider()
                settingsButtonRow(title: "Save Current Setup", buttonTitle: "Save as New File", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                    createStoredGameFromDraft()
                }

                settingsDivider()
                settingsLibraryToolbar
                settingsDivider()
                settingsGameFileList
            }

            settingsSection(title: "Current Game") {
                settingsSummaryValueRow(title: "Working File", value: selectedStoredGameFile?.displayName ?? "Auto-created")
                settingsDivider()
                settingsSummaryValueRow(title: "Home Team", value: displayTeamName(homeTeamDraft))
                settingsDivider()
                settingsSummaryValueRow(title: "Guest Team", value: displayTeamName(guestTeamDraft))
                settingsDivider()
                settingsSummaryValueRow(title: "Sport", value: setupSport.title)
                settingsDivider()
                settingsSummaryValueRow(title: setupSport.periodTitle, value: "\(setupPeriod)")
                settingsDivider()
                settingsSummaryValueRow(title: "Opening Clock", value: setupSport == .volleyball && !setupUsesGameClock ? "Disabled" : formatClock(setupClockSeconds))
                if setupSport.supportsShotClock {
                    settingsDivider()
                    settingsSummaryValueRow(title: "Shot Clock", value: ScoreboardStore.formatShotClock(setupShotClockSeconds))
                }
                settingsDivider()
                settingsSummaryValueRow(title: "Player Tracking", value: store.isPlayerTrackingEnabled ? "Enabled" : "Disabled")
                settingsDivider()
                settingsSummaryValueRow(title: "Roster Size", value: "\(store.rosterSizePerTeam)")
                settingsDivider()
                settingsSummaryValueRow(title: "Home Subs", value: "\(store.homeSubstitutionsUsed)/\(store.homeSubstitutionsAllowed)")
                settingsDivider()
                settingsSummaryValueRow(title: "Guest Subs", value: "\(store.guestSubstitutionsUsed)/\(store.guestSubstitutionsAllowed)")
            }
        }
    }

    private func settingsLogsPane() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Log Sessions", footer: "Each app launch writes to its own audit session. Export or delete the selected session below.") {
                settingsLogToolbar
                settingsDivider()
                settingsLogSessionList
            }

            settingsSection(title: "Playback") {
                if let selectedStoredLogSession {
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
                } else {
                    Text("Select a log session to inspect exported actions and captured game context.")
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private var settingsLibraryToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                settingsIconButton("Import", systemImage: "square.and.arrow.down.on.square", tint: settingsPalette.accent, foreground: settingsPalette.accentText) {
                    showsGameImporter = true
                }

                settingsIconButton(
                    "Export",
                    systemImage: "square.and.arrow.up",
                    tint: settingsPalette.accent,
                    foreground: settingsPalette.accentText,
                    isEnabled: selectedStoredGameFile != nil
                ) {
                    exportSelectedStoredGame()
                }

                settingsIconButton(
                    "Delete",
                    systemImage: "trash",
                    tint: themePalette.destructiveTint,
                    foreground: .white,
                    isEnabled: selectedStoredGameFile != nil
                ) {
                    deleteSelectedStoredGame()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var settingsGameFileList: some View {
        Group {
            if storedGameFiles.isEmpty {
                Text("No local game files yet. Create one from the current draft or import an existing file.")
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(storedGameFiles.enumerated()), id: \.element.id) { index, gameFile in
                        settingsGameFileRow(gameFile)

                        if index < storedGameFiles.count - 1 {
                            settingsDivider()
                        }
                    }
                }
            }
        }
    }

    private var settingsLogToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                settingsIconButton(
                    "Export JSON",
                    systemImage: "doc.badge.arrow.up",
                    tint: settingsPalette.accent,
                    foreground: settingsPalette.accentText,
                    isEnabled: selectedStoredLogSession != nil
                ) {
                    prepareLogExport(as: .scoreboardLogSession)
                }

                settingsIconButton(
                    "Export CSV",
                    systemImage: "tablecells.badge.ellipsis",
                    tint: settingsPalette.accent,
                    foreground: settingsPalette.accentText,
                    isEnabled: selectedStoredLogSession != nil
                ) {
                    prepareLogExport(as: .commaSeparatedText)
                }

                settingsIconButton(
                    "Delete",
                    systemImage: "trash",
                    tint: themePalette.destructiveTint,
                    foreground: .white,
                    isEnabled: selectedStoredLogSession != nil
                ) {
                    pendingLogDeletion = selectedStoredLogSession
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var settingsLogSessionList: some View {
        Group {
            if storedLogSessions.isEmpty {
                Text("No log sessions yet. Start operating the scoreboard to create the first per-run log.")
                    .font(.subheadline)
                    .foregroundStyle(settingsPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(storedLogSessions.enumerated()), id: \.element.id) { index, session in
                        settingsLogSessionRow(session)

                        if index < storedLogSessions.count - 1 {
                            settingsDivider()
                        }
                    }
                }
            }
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
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
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(settingsPalette.secondaryText)
            }
        }
    }

    private func settingsTextEntryRow(
        title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        teamSide: Bool? = nil
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.body)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            TextField(placeholder ?? title, text: text)
                .scoreboardUppercaseEntry()
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: 280)
                .onSubmit {
                    guard let teamSide else {
                        return
                    }

                    synchronizeDraftTeamName(text.wrappedValue, isHome: teamSide)
                }
                .onChange(of: text.wrappedValue) { _, newValue in
                    guard let teamSide else {
                        return
                    }

                    synchronizeDraftTeamName(newValue, isHome: teamSide)
                }
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
            Text(title)
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
            Text(title)
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
            Text(title)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Picker(title, selection: selection) {
                ForEach(options, id: \.1) { option in
                    Text(option.0).tag(option.1)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
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
            Text(title)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 10)
    }

    private func settingsRosterEditor(side: TeamSide, layout: InterfaceLayout) -> some View {
        VStack(spacing: 0) {
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

                if store.supportsCards {
                    Text(player.cardStatus.title.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(cardStatusColor(player.cardStatus))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(settingsPalette.fieldBackground, in: Capsule())
                } else if store.supportsFouls {
                    Text("F \(player.foulCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(settingsPalette.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(settingsPalette.fieldBackground, in: Capsule())
                }
            }

            HStack(spacing: 12) {
                TextField(
                    "No.",
                    text: Binding(
                        get: { player.number },
                        set: { store.updateTrackedPlayerNumber($0, for: side, playerID: player.id) }
                    )
                )
                .multilineTextAlignment(.center)
                .foregroundStyle(settingsPalette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(settingsPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(width: 84)

                TextField(
                    "Player Name",
                    text: Binding(
                        get: { player.name },
                        set: { store.updateTrackedPlayerName($0, for: side, playerID: player.id) }
                    )
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
                    smallSettingsActionButton("Clear", tint: settingsPalette.fieldBackground, foreground: settingsPalette.primaryText) {
                        store.setCardStatus(.none, for: side, playerID: player.id)
                    }
                    smallSettingsActionButton("Yellow", tint: .yellow.opacity(0.85), foreground: .black) {
                        store.setCardStatus(.yellow, for: side, playerID: player.id)
                    }
                    smallSettingsActionButton("Red", tint: .red.opacity(0.9), foreground: .white) {
                        store.setCardStatus(.red, for: side, playerID: player.id)
                    }
                }
            } else if store.supportsFouls {
                HStack(spacing: 10) {
                    smallSettingsActionButton("F -", tint: settingsPalette.fieldBackground, foreground: settingsPalette.primaryText) {
                        store.adjustFoulCount(for: side, playerID: player.id, by: -1)
                    }
                    smallSettingsActionButton("F +", tint: side == .home ? homeTint : guestTint, foreground: .white) {
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
            Text(title)
                .foregroundStyle(settingsPalette.primaryText)

            Spacer(minLength: 0)

            Button(action: action) {
                Text(buttonTitle)
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
            Label(title, systemImage: systemImage)
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
            Text(title)
                .foregroundStyle(settingsPalette.primaryText)
            Spacer(minLength: 0)
            Text(value)
                .foregroundStyle(settingsPalette.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private func smallSettingsActionButton(
        _ title: String,
        tint: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(tint, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func settingsGameFileRow(_ gameFile: StoredGameFile) -> some View {
        Button {
            loadStoredGameFile(gameFile)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(gameFile.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)

                    Text(gameFile.matchupLine)
                        .font(.subheadline)
                        .foregroundStyle(settingsPalette.secondaryText)

                    Text(gameFile.stateLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(settingsPalette.secondaryText)

                    Text(gameFile.detailLine)
                        .font(.caption)
                        .foregroundStyle(settingsPalette.secondaryText.opacity(0.8))
                }

                Spacer(minLength: 0)

                if selectedStoredGameFileID == gameFile.id {
                    Text("Selected")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(settingsPalette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(settingsPalette.accent.opacity(0.12), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(settingsPalette.secondaryText)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsLogSessionRow(_ session: StoredLogSession) -> some View {
        Button {
            selectedStoredLogSessionID = session.id
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)

                    Text(session.summaryLine)
                        .font(.caption)
                        .foregroundStyle(settingsPalette.secondaryText)

                    Text(session.sportsLine)
                        .font(.caption)
                        .foregroundStyle(settingsPalette.secondaryText)

                    Text(session.gameFilesLine)
                        .font(.caption)
                        .foregroundStyle(settingsPalette.secondaryText)
                }

                Spacer(minLength: 0)

                if selectedStoredLogSessionID == session.id {
                    Text("Selected")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(settingsPalette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(settingsPalette.accent.opacity(0.12), in: Capsule())
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsLogPlaybackList(_ session: StoredLogSession) -> some View {
        VStack(spacing: 10) {
            ForEach(session.session.entries) { entry in
                settingsLogEntryRow(entry)
            }
        }
        .padding(.vertical, 12)
    }

    private func settingsLogEntryRow(_ entry: ScoreboardLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.operation.kind.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(settingsPalette.primaryText)

                Spacer(minLength: 0)

                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(settingsPalette.secondaryText)
            }

            Text(entry.operation.summary)
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

            Text("Outcome: \(entry.outcome.title)")
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

                        Text(theme.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(settingsPalette.primaryText)
                    }

                    Text(theme.subtitle)
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
            store.externalDisplayBackgroundMode = mode
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)

                    Text(mode.subtitle)
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
        if mode == .blurred {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [palette.homeAccent.opacity(0.65), palette.guestAccent.opacity(0.45), palette.externalDisplayBackground], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(settingsPalette.cardBorder, lineWidth: 1)
                )
        } else if mode == .clear {
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
        } else if mode == .clearUnderBoard {
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
            let contentHeight = max(availableHeight - layout.dashboardHeaderHeight - layout.sectionSpacing, 0)

            VStack(spacing: layout.sectionSpacing) {
                dashboardHeader(layout: layout)
                    .frame(height: layout.dashboardHeaderHeight)

                controlPane(layout: layout)
                    .frame(height: contentHeight)
            }
            .padding(layout.outerPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func dashboardHeader(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.headerBlockSpacing) {
            if layout.headerUsesVerticalFlow {
                VStack(alignment: .leading, spacing: layout.headerBlockSpacing) {
                    headerTitleBlock(layout: layout)
                    headerStatusBadge(layout: layout)
                    headerActionButtons(layout: layout)
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
    }

    private func headerTitleBlock(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedStoredGameFile?.displayName ?? "New Game")
                .font(.system(size: layout.headerTitleSize, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.6)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            Text(store.selectedSport.title)
                .font(layout.headerSubtitleFont.weight(.semibold))
                .singleLineFitted(minScale: 0.8)
                .foregroundStyle(themePalette.dashboardMutedText)
        }
    }

    private func headerStatusBadge(layout: InterfaceLayout) -> some View {
        HStack(spacing: 10) {
            Label(displayStatusTitle, systemImage: displayStatusSystemImage)
                .font(layout.headerBadgeFont)
                .lineLimit(1)
                .foregroundStyle(publicBoardState.isPresented ? themePalette.dashboardStatusLive : themePalette.dashboardStatusIdle)
                .padding(.horizontal, layout.headerBadgeHorizontalPadding)
                .padding(.vertical, layout.headerBadgeVerticalPadding)
                .background(themePalette.dashboardCardBackground, in: Capsule())

            Button {
                dashboardPage = .preview
            } label: {
                Label("Show Preview", systemImage: "display")
                    .font(layout.headerBadgeFont)
                    .foregroundStyle(themePalette.dashboardNeutralButtonText)
                    .padding(.horizontal, layout.headerBadgeHorizontalPadding)
                    .padding(.vertical, layout.headerBadgeVerticalPadding)
                    .background(themePalette.dashboardNeutralButton, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func headerActionButtons(layout: InterfaceLayout) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, layout.headerActionColumns)),
            spacing: 10
        ) {
            #if os(macOS)
            actionButton(
                publicBoardState.isPresented ? "Reopen Scoreboard" : "Open Scoreboard",
                tint: themePalette.dashboardNeutralButton,
                foreground: themePalette.dashboardNeutralButtonText,
                verticalPadding: layout.headerActionVerticalPadding
            ) {
                showPublicBoardWindow()
            }
            #endif

            actionButton(
                store.isSoundEnabled ? "Sound On" : "Sound Off",
                tint: store.isSoundEnabled ? themePalette.dashboardSuccessButton : themePalette.dashboardNeutralButton,
                foreground: store.isSoundEnabled ? themePalette.dashboardSuccessButtonText : themePalette.dashboardNeutralButtonText,
                verticalPadding: layout.headerActionVerticalPadding
            ) {
                store.toggleSoundEnabled()
            }

            Button {
                loadSetupDraftsFromStore()
                selectedSettingsPane = .game
                showsSetup = true
            } label: {
                Label("Setting", systemImage: "gearshape")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(themePalette.dashboardNeutralButtonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.headerActionVerticalPadding)
                    .background(themePalette.dashboardNeutralButton, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func shotClockWidget(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Shot Clock")
                    .font(.title3.weight(.bold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Spacer(minLength: 0)

                Text("Possession: \(store.possessionDirection.displayName)")
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
                columns: max(1, layout.shotClockButtonColumns - 2),
                buttons: [
                    ActionDescriptor(title: "Shot Reset", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.resetActiveShotClock()
                    },
                    ActionDescriptor(title: "Shot -1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustShotClock(by: -1)
                    },
                    ActionDescriptor(title: "Shot +1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustShotClock(by: 1)
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
    }

    private func controlPane(layout: InterfaceLayout) -> some View {
        if store.isPlayerTrackingEnabled {
            return AnyView(trackedControlPane(layout: layout))
        }

        return AnyView(mainControlPane(layout: layout))
    }

    private func trackedControlPane(layout: InterfaceLayout) -> some View {
        ZStack {
            switch dashboardPage {
            case .main:
                mainControlPane(layout: layout)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            case .players:
                playerTrackingScreen(layout: layout)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
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
                    title: "Display Preview",
                    caption: "Preview the external scoreboard without requiring an attached display. This preview may not match the connected external display exactly.",
                    actionTitle: "Back to Game",
                    actionSystemImage: "chevron.left",
                    action: { dashboardPage = .main },
                    layout: layout
                )
                .transition(.move(edge: .top).combined(with: .opacity))

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
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Text(caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themePalette.dashboardMutedText)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage ?? "arrow.right")
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

    @ViewBuilder
    private func topControlRow(layout: InterfaceLayout) -> some View {
        let leftIsHome = !store.areSidesSwapped

        if layout.topControlUsesVerticalFlow {
            VStack(spacing: layout.sectionSpacing) {
                centeredStatusWidget(layout: layout)

                teamControls(
                    title: leftIsHome ? "Home" : "Guest",
                    isHome: leftIsHome,
                    tint: leftIsHome ? homeTint : guestTint,
                    layout: layout
                )

                teamControls(
                    title: leftIsHome ? "Guest" : "Home",
                    isHome: !leftIsHome,
                    tint: leftIsHome ? guestTint : homeTint,
                    layout: layout
                )
            }
        } else {
            HStack(spacing: 16) {
                teamControls(
                    title: leftIsHome ? "Home" : "Guest",
                    isHome: leftIsHome,
                    tint: leftIsHome ? homeTint : guestTint,
                    layout: layout
                )
                .frame(maxWidth: .infinity)

                centeredStatusWidget(layout: layout)
                    .frame(maxWidth: layout.centerStatusWidth)

                teamControls(
                    title: leftIsHome ? "Guest" : "Home",
                    isHome: !leftIsHome,
                    tint: leftIsHome ? guestTint : homeTint,
                    layout: layout
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func centeredStatusWidget(layout: InterfaceLayout) -> some View {
        let leftName = store.areSidesSwapped ? store.guestTeamName : store.homeTeamName
        let leftScore = store.areSidesSwapped ? store.guestScore : store.homeScore
        let leftTint = store.areSidesSwapped ? guestTint : homeTint
        let rightName = store.areSidesSwapped ? store.homeTeamName : store.guestTeamName
        let rightScore = store.areSidesSwapped ? store.homeScore : store.guestScore
        let rightTint = store.areSidesSwapped ? homeTint : guestTint

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Game State")
                    .font(.title3.weight(.bold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Spacer(minLength: 0)

                Text(store.showsGameClock ? (store.isClockRunning ? "Running" : "Stopped") : "Timer Off")
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

            if store.showsGameClock {
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
                    gameMetricCard(title: "Shot", value: store.formattedShotClock, monospaced: true, layout: layout)
                }
                gameMetricCard(title: store.periodTitle, value: "\(store.period)", layout: layout)
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
            }
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
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
        }
        .frame(maxWidth: .infinity)
    }

    private func gameMetricCard(
        title: String,
        value: String,
        monospaced: Bool = false,
        layout: InterfaceLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardSubtleText)

            Text(value)
                .font(.system(size: layout.centerMetricValueSize, weight: .black, design: .rounded))
                .monospacedDigitIfNeeded(monospaced)
                .singleLineFitted(minScale: 0.4)
                .foregroundStyle(themePalette.dashboardPrimaryText)
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

    private func teamControls(
        title: String,
        isHome: Bool,
        tint: Color,
        layout: InterfaceLayout
    ) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            buttonGrid(
                columns: max(1, min(2, store.selectedSport.scoreStepOptions.count + 1)),
                buttons: scoreButtons(forHomeTeam: isHome, tint: tint),
                dense: layout.denseControls
            )

            if store.supportsShotClock {
                buttonGrid(
                    columns: 2,
                    buttons: [
                        ActionDescriptor(
                            title: "Shot 24",
                            tint: (store.possessionDirection == (isHome ? .home : .guest) && store.activeShotClockPresetSeconds == 24) ? tint : themePalette.dashboardNeutralButton,
                            foreground: .white
                        ) {
                            store.assignShotClock(to: 24, forHomeTeam: isHome)
                        },
                        ActionDescriptor(
                            title: "Shot 14",
                            tint: (store.possessionDirection == (isHome ? .home : .guest) && store.activeShotClockPresetSeconds == 14) ? tint.opacity(0.82) : themePalette.dashboardNeutralButton,
                            foreground: .white
                        ) {
                            store.assignShotClock(to: 14, forHomeTeam: isHome)
                        }
                    ],
                    dense: layout.denseControls,
                    compactVerticalPadding: layout.advancedButtonVerticalPadding
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if store.showsSubstitutionTracking {
                substitutionControlRow(side: isHome ? .home : .guest, tint: tint, layout: layout)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if store.supportsTeamFouls {
                teamFoulControlRow(side: isHome ? .home : .guest, tint: tint, layout: layout)
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
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.showsSubstitutionTracking)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.supportsTeamFouls)
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
    }

    private func quickResetButtons() -> [ActionDescriptor] {
        var buttons: [ActionDescriptor] = []

        if store.supportsFouls {
            buttons.append(
                ActionDescriptor(title: "Reset All Player Fouls", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText) {
                    store.resetAllPlayerFouls()
                }
            )
        }

        if store.supportsTeamFouls {
            buttons.append(
                ActionDescriptor(title: "Reset All Team Fouls", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText) {
                    store.resetAllTeamFouls()
                }
            )
        }

        if store.supportsCards {
            buttons.append(
                ActionDescriptor(title: "Reset All Cards", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText) {
                    store.resetAllPlayerCards()
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
                Text("\(side.title) Roster")
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
        let sideTitle = side.title

        if store.supportsFouls {
            buttons.append(
                ActionDescriptor(title: "Reset \(sideTitle) Player Fouls", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                    store.resetFouls(for: side)
                }
            )
        }

        if store.supportsTeamFouls {
            buttons.append(
                ActionDescriptor(title: "Reset \(sideTitle) Team Fouls", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                    store.resetTeamFouls(for: side)
                }
            )
        }

        if store.supportsCards {
            buttons.append(
                ActionDescriptor(title: "Reset \(sideTitle) Cards", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                    store.resetCards(for: side)
                }
            )
        }

        return buttons
    }

    private func playerControlRow(_ player: TrackedPlayer, side: TeamSide, layout: InterfaceLayout) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(player.number.isEmpty ? "--" : player.number) \(player.name.isEmpty ? "PLAYER" : player.name)")
                    .font(.subheadline.weight(.bold))
                    .singleLineFitted(minScale: 0.65)
                    .foregroundStyle(themePalette.dashboardPrimaryText)

                Text(player.isInActiveLineup ? "Active Lineup" : "Bench")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(player.isInActiveLineup ? themePalette.dashboardStatusLive : themePalette.dashboardMutedText)
            }

            Spacer(minLength: 0)

            if store.supportsCards {
                Text(player.cardStatus.title.uppercased())
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(cardStatusColor(player.cardStatus))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(themePalette.dashboardCardBackground.opacity(0.72), in: Capsule())

                smallActionButton("Clr", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, verticalPadding: layout.advancedButtonVerticalPadding) {
                    store.setCardStatus(.none, for: side, playerID: player.id)
                }
                .frame(width: 46)

                smallActionButton("Y", tint: .yellow.opacity(0.88), foreground: .black, verticalPadding: layout.advancedButtonVerticalPadding) {
                    store.setCardStatus(.yellow, for: side, playerID: player.id)
                }
                .frame(width: 40)

                smallActionButton("R", tint: .red.opacity(0.9), foreground: .white, verticalPadding: layout.advancedButtonVerticalPadding) {
                    store.setCardStatus(.red, for: side, playerID: player.id)
                }
                .frame(width: 40)
            } else if store.supportsFouls {
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

                smallActionButton("+", tint: side == .home ? homeTint : guestTint, foreground: .white, verticalPadding: layout.advancedButtonVerticalPadding) {
                    store.adjustFoulCount(for: side, playerID: player.id, by: 1)
                }
                .frame(width: 40)
            }

            smallActionButton(
                player.isInActiveLineup ? "Bench" : "Show",
                tint: player.isInActiveLineup ? themePalette.dashboardNeutralButton : (side == .home ? homeTint.opacity(0.86) : guestTint.opacity(0.86)),
                foreground: player.isInActiveLineup ? themePalette.dashboardNeutralButtonText : .white,
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
        VStack(alignment: .leading, spacing: 16) {
            if store.showsGameClock {
                gameSummaryRow(layout: layout)

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
            }

            buttonGrid(
                columns: 3,
                buttons: [
                    ActionDescriptor(title: "Prev Period", tint: themePalette.destructiveTint, foreground: .white) {
                        pendingGameConfirmation = .previousPeriod
                    },
                    ActionDescriptor(title: "Swap Sides", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.swapSides()
                    },
                    ActionDescriptor(title: "Next \(store.periodTitle)", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText) {
                        store.adjustPeriod(by: 1)
                    }
                ],
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )

            buttonGrid(
                columns: store.showsGameClock ? 2 : 1,
                buttons: store.showsGameClock ? [
                    ActionDescriptor(title: "Reset \(formatClock(store.defaultClockSeconds))", tint: themePalette.destructiveTint, foreground: .white, isEnabled: !store.isGameClockInterlockActive) {
                        pendingGameConfirmation = .resetClock
                    },
                    ActionDescriptor(title: "Zero Scores", tint: themePalette.destructiveTint, foreground: .white, isEnabled: !store.isGameClockInterlockActive) {
                        pendingGameConfirmation = .zeroScores
                    }
                ] : [
                    ActionDescriptor(title: "Zero Scores", tint: themePalette.destructiveTint, foreground: .white, isEnabled: !store.isGameClockInterlockActive) {
                        pendingGameConfirmation = .zeroScores
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
    }

    private func gameSummaryRow(layout: InterfaceLayout) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Game Clock")
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            Spacer(minLength: 0)

            Text(store.isClockRunning ? "Running" : "Stopped")
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(store.isClockRunning ? themePalette.dashboardStatusLive : themePalette.dashboardMutedText)
        }
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
            Text(title)
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
            Text(title)
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
        case .basketball:
            return [("8:00", 8 * 60), ("10:00", 10 * 60), ("12:00", 12 * 60)]
        case .volleyball:
            return [("00:00", 0), ("15:00", 15 * 60), ("25:00", 25 * 60)]
        case .soccer:
            return [("40:00", 40 * 60), ("45:00", 45 * 60), ("50:00", 50 * 60)]
        }
    }

    private func scoreButtons(forHomeTeam isHome: Bool, tint: Color) -> [ActionDescriptor] {
        let sportButtons = store.selectedSport.scoreStepOptions.map { value in
            ActionDescriptor(title: "+\(value)", tint: tint, foreground: .white) {
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
        VStack(alignment: .leading, spacing: 10) {
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
                        foreground: .white,
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

    private func handleRootAppear() {
        initializeWorkingGameFile()
        refreshStoredLogSessions()
        syncCurrentLogGameFile()
        updateIdleTimer(for: scenePhase)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        updateIdleTimer(for: newPhase)

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
            } else {
                LinearGradient(
                    colors: themePalette.appDashboardBackground,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            if showsSetup {
                setupScreen(layout: layout)
            } else {
                dashboard(layout: layout)
            }
        }
    }

    private func teamFoulControlRow(side: TeamSide, tint: Color, layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    ActionDescriptor(title: "Foul +", tint: tint, foreground: .white) {
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

    private func resetSetupDraftsToDefaults() {
        homeTeamDraft = ""
        guestTeamDraft = ""
        setupSport = .basketball
        setupPeriod = 1
        setupClockSeconds = 12 * 60
        setupShotClockSeconds = 24
        gameFileNameDraft = ""
    }

    private func createNewGame() {
        resetSetupDraftsToDefaults()
        selectedStoredGameFileID = nil
        gameFileNameDraft = ""
        selectedSettingsPane = .game
        showsSetup = true
    }

    private func swapSetupSides() {
        swap(&homeTeamDraft, &guestTeamDraft)
    }

    private func openSetupGame() {
        commitSetupEdits(forceRefresh: true)
        #if os(macOS)
        showPublicBoardWindow()
        #endif
        showsSetup = false
    }

    private func makeDraftSnapshot() -> ScoreboardGameSnapshot {
        ScoreboardGameSnapshot(
            fileVersion: 5,
            sport: setupSport,
            homeTeamName: homeTeamDraft,
            guestTeamName: guestTeamDraft,
            homeScore: 0,
            guestScore: 0,
            period: setupPeriod,
            gameClockSeconds: setupClockSeconds,
            defaultClockSeconds: setupClockSeconds,
            isGameClockEnabled: setupSport == .volleyball ? setupUsesGameClock : true,
            shotClockMilliseconds: setupShotClockSeconds * 1_000,
            defaultShotClockSeconds: setupShotClockSeconds,
            activeShotClockPresetSeconds: setupShotClockSeconds,
            possessionDirection: .none,
            areSidesSwapped: false,
            isPlayerTrackingEnabled: store.isPlayerTrackingEnabled,
            isPlayerOverlayPaused: store.isPlayerOverlayPaused,
            rosterSizePerTeam: store.rosterSizePerTeam,
            displayLineupSize: store.displayLineupSize,
            playerFoulHighlightColor: store.playerFoulHighlightColor,
            isGameClockRedEnabled: store.isGameClockRedEnabled,
            gameClockRedThresholdSeconds: store.gameClockRedThresholdSeconds,
            isShotClockRedEnabled: store.isShotClockRedEnabled,
            shotClockRedThresholdSeconds: store.shotClockRedThresholdSeconds,
            homeSubstitutionsAllowed: store.homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: store.guestSubstitutionsAllowed,
            homeSubstitutionsUsed: store.homeSubstitutionsUsed,
            guestSubstitutionsUsed: store.guestSubstitutionsUsed,
            homeTeamFouls: store.homeTeamFouls,
            guestTeamFouls: store.guestTeamFouls,
            homeRoster: store.homeRoster,
            guestRoster: store.guestRoster
        )
    }

    private func prepareDraftExport() {
        exportDocument = ScoreboardGameDocument(snapshot: makeDraftSnapshot())
        exportFilename = suggestedGameFilename(homeTeamDraft, guestTeamDraft)
        showsGameExporter = true
    }

    private func prepareLiveGameExport() {
        exportDocument = ScoreboardGameDocument(snapshot: store.currentGameSnapshot())
        exportFilename = suggestedGameFilename(store.homeTeamName, store.guestTeamName)
        showsGameExporter = true
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

            let data = try Data(contentsOf: sourceURL)
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

    private func exportSelectedStoredGame() {
        do {
            guard let selectedURL = selectedStoredGameFile?.url else {
                return
            }

            let snapshot = try loadGameSnapshot(from: selectedURL)
            exportDocument = ScoreboardGameDocument(snapshot: snapshot)
            exportFilename = selectedURL.lastPathComponent
            showsGameExporter = true
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

    private func deleteSelectedStoredGame() {
        do {
            guard let selectedURL = selectedStoredGameFile?.url else {
                return
            }

            try FileManager.default.removeItem(at: selectedURL)
            refreshStoredGameFiles()
            recordFileLog(
                kind: .fileDelete,
                summary: "Delete game file",
                outcome: .applied,
                fileURL: selectedURL
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
                        snapshot: try? loadGameSnapshot(from: url)
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
                selectedStoredGameFileID = nil
            }
        } catch {
            storedGameFiles = []
            selectedStoredGameFileID = nil
            presentFileOperationError(error)
        }
    }

    private func handleGameExport(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            presentFileOperationError(error)
        }
    }

    private func handleLogExport(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            presentFileOperationError(error)
        }
    }

    private func refreshStoredLogSessions() {
        do {
            storedLogSessions = try logManager.listSessions()

            if let selectedStoredLogSessionID, storedLogSessions.contains(where: { $0.id == selectedStoredLogSessionID }) {
                self.selectedStoredLogSessionID = selectedStoredLogSessionID
            } else {
                selectedStoredLogSessionID = storedLogSessions.first?.id
            }
        } catch {
            storedLogSessions = []
            selectedStoredLogSessionID = nil
            presentFileOperationError(error)
        }
    }

    private func prepareLogExport(as contentType: UTType) {
        do {
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
                fileExtension = "json"
            }

            logExportDocument = ScoreboardLogExportDocument(data: data)
            logExportContentType = contentType
            let timestamp = session.startedAt.ISO8601Format()
                .replacingOccurrences(of: ":", with: "-")
            logExportFilename = "Scoreboard Log \(timestamp).\(fileExtension)"
            showsLogExporter = true
        } catch {
            presentFileOperationError(error)
        }
    }

    private func deleteLogSession(_ session: StoredLogSession) {
        do {
            try logManager.deleteSession(at: session.url)
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
                summary: summary,
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

    private func loadSetupDraftsFromStore() {
        homeTeamDraft = store.homeTeamName
        guestTeamDraft = store.guestTeamName
        setupSport = store.selectedSport
        setupPeriod = store.period
        setupClockSeconds = store.defaultClockSeconds
        setupUsesGameClock = store.isGameClockEnabled
        setupShotClockSeconds = store.activeShotClockPresetSeconds
        gameFileNameDraft = selectedStoredGameFile?.displayName ?? resolvedGameFilenameDraft(store.homeTeamName, store.guestTeamName, includeExtension: false)
    }

    private func displayTeamName(_ name: String) -> String {
        name.isEmpty ? "TBD" : name
    }

    private func logEntryContextLine(_ entry: ScoreboardLogEntry) -> String {
        var segments: [String] = []
        segments.append(entry.context.sport.title)
        segments.append("\(entry.context.sport.periodTitle) \(entry.context.period)")
        segments.append("Clock \(entry.context.isClockRunning ? "Running" : "Stopped") \(ScoreboardStore.formatGameClock(entry.context.gameClockSeconds))")

        if entry.context.supportsShotClock, let milliseconds = entry.context.shotClockMilliseconds {
            let shotState = entry.context.isShotClockRunning == true ? "Running" : "Stopped"
            segments.append("Shot \(shotState) \(ScoreboardStore.formatShotClock(milliseconds: milliseconds))")
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
            segments.append(side.title)
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

        return "File: \(fileName)"
    }

    private func logDeletionMessage(for session: StoredLogSession) -> String {
        "Delete the log session from \(session.startedAt.formatted(date: .abbreviated, time: .shortened))?"
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

    private var selectedStoredLogSession: StoredLogSession? {
        guard let selectedStoredLogSessionID else {
            return nil
        }

        return storedLogSessions.first { $0.id == selectedStoredLogSessionID }
    }

    private func applySetupSportDraft(_ sport: SportType) {
        let previousSport = store.selectedSport
        store.setSelectedSport(sport, applyDefaults: previousSport != sport)
        setupPeriod = 1
        setupClockSeconds = sport.defaultClockSeconds
        if sport != .volleyball {
            setupUsesGameClock = true
        }
        setupShotClockSeconds = sport.defaultShotClockSeconds
        commitSetupEdits()
    }

    private func storedGameFilesDirectory() throws -> URL {
        let fileManager = FileManager.default
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = baseDirectory.appendingPathComponent("StoredGames", isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        return directoryURL
    }

    private func uniqueStoredGameFileURL(preferredFilename: String) throws -> URL {
        let directoryURL = try storedGameFilesDirectory()
        let fileManager = FileManager.default
        let sanitizedBaseName = sanitizeGameFilename(preferredFilename)
        let baseName = (sanitizedBaseName as NSString).deletingPathExtension
        let pathExtension = ((sanitizedBaseName as NSString).pathExtension.isEmpty ? "scoreboardgame" : (sanitizedBaseName as NSString).pathExtension)

        var candidateURL = directoryURL.appendingPathComponent(baseName).appendingPathExtension(pathExtension)
        var suffix = 2

        while fileManager.fileExists(atPath: candidateURL.path) {
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
                let snapshot = currentSetupWorkingSnapshot()
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

    private func commitSetupEdits(forceRefresh: Bool = false) {
        ensureWorkingGameFileExists()
        let snapshot = currentSetupWorkingSnapshot()
        store.applyGameSnapshot(snapshot)
        autosaveSelectedGameFile(refreshSelection: forceRefresh)
    }

    private func currentSetupWorkingSnapshot() -> ScoreboardGameSnapshot {
        let currentSnapshot = store.currentGameSnapshot()

        return ScoreboardGameSnapshot(
            fileVersion: 5,
            sport: setupSport,
            homeTeamName: homeTeamDraft,
            guestTeamName: guestTeamDraft,
            homeScore: currentSnapshot.homeScore,
            guestScore: currentSnapshot.guestScore,
            period: setupPeriod,
            gameClockSeconds: setupClockSeconds,
            defaultClockSeconds: setupClockSeconds,
            isGameClockEnabled: setupSport == .volleyball ? setupUsesGameClock : true,
            shotClockMilliseconds: setupSport.supportsShotClock ? setupShotClockSeconds * 1_000 : 0,
            defaultShotClockSeconds: setupSport.supportsShotClock ? setupShotClockSeconds : 0,
            activeShotClockPresetSeconds: setupSport.supportsShotClock ? setupShotClockSeconds : 0,
            possessionDirection: setupSport.supportsPossession ? .none : .none,
            areSidesSwapped: currentSnapshot.areSidesSwapped,
            isPlayerTrackingEnabled: currentSnapshot.isPlayerTrackingEnabled,
            isPlayerOverlayPaused: currentSnapshot.isPlayerOverlayPaused,
            rosterSizePerTeam: currentSnapshot.rosterSizePerTeam,
            displayLineupSize: currentSnapshot.displayLineupSize,
            playerFoulHighlightColor: currentSnapshot.playerFoulHighlightColor,
            isGameClockRedEnabled: currentSnapshot.isGameClockRedEnabled,
            gameClockRedThresholdSeconds: currentSnapshot.gameClockRedThresholdSeconds,
            isShotClockRedEnabled: currentSnapshot.isShotClockRedEnabled,
            shotClockRedThresholdSeconds: currentSnapshot.shotClockRedThresholdSeconds,
            homeSubstitutionsAllowed: currentSnapshot.homeSubstitutionsAllowed,
            guestSubstitutionsAllowed: currentSnapshot.guestSubstitutionsAllowed,
            homeSubstitutionsUsed: currentSnapshot.homeSubstitutionsUsed,
            guestSubstitutionsUsed: currentSnapshot.guestSubstitutionsUsed,
            homeTeamFouls: currentSnapshot.homeTeamFouls,
            guestTeamFouls: currentSnapshot.guestTeamFouls,
            homeRoster: currentSnapshot.homeRoster,
            guestRoster: currentSnapshot.guestRoster
        )
    }

    private func autosaveSelectedGameFile(refreshSelection: Bool = false) {
        guard let selectedURL = selectedStoredGameFile?.url else {
            return
        }

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

    private func migrateLegacyPresetsToStoredGameFilesIfNeeded() {
        guard !store.setupPresets.isEmpty else {
            return
        }

        do {
            for preset in store.setupPresets {
                let snapshot = ScoreboardGameSnapshot(
                    fileVersion: 5,
                    sport: preset.sport,
                    homeTeamName: preset.homeTeamName,
                    guestTeamName: preset.guestTeamName,
                    homeScore: 0,
                    guestScore: 0,
                    period: preset.period,
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
                    playerFoulHighlightColor: store.playerFoulHighlightColor,
                    isGameClockRedEnabled: store.isGameClockRedEnabled,
                    gameClockRedThresholdSeconds: store.gameClockRedThresholdSeconds,
                    isShotClockRedEnabled: store.isShotClockRedEnabled,
                    shotClockRedThresholdSeconds: store.shotClockRedThresholdSeconds,
                    homeSubstitutionsAllowed: preset.sport.defaultSubstitutionLimit,
                    guestSubstitutionsAllowed: preset.sport.defaultSubstitutionLimit,
                    homeSubstitutionsUsed: 0,
                    guestSubstitutionsUsed: 0,
                    homeTeamFouls: 0,
                    guestTeamFouls: 0,
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
                    Text(title)
                        .font(.title3.weight(.bold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(themePalette.dashboardPrimaryText)

                    Text(caption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(themePalette.dashboardMutedText)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(themePalette.dashboardPrimaryText)

                    Spacer(minLength: 0)

                    Text(caption)
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
        ScoreboardFaceView(
            theme: store.theme,
            backgroundStyle: currentPreviewBoardBackgroundStyle,
            sport: store.selectedSport,
            homeTeamName: store.homeTeamName,
            guestTeamName: store.guestTeamName,
            homeScore: store.homeScore,
            guestScore: store.guestScore,
            period: store.period,
            formattedClock: store.formattedClock,
            showsGameClock: store.showsGameClock,
            formattedShotClock: store.formattedShotClock,
            possessionDirection: store.possessionDirection,
            areSidesSwapped: store.areSidesSwapped,
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
            homeTeamFouls: store.homeTeamFouls,
            guestTeamFouls: store.guestTeamFouls,
            homePlayers: store.displayedHomePlayers,
            guestPlayers: store.displayedGuestPlayers,
            compact: layout.previewUsesCompactBoard
        )
    }

    private var currentPreviewModeTitle: String {
        switch store.externalDisplayBackgroundMode {
        case .blurred:
            return "Blurred Background"
        case .clear:
            return "Clear Background"
        case .clearUnderBoard:
            return "Transparent Board"
        case .none:
            return "No Background"
        }
    }

    private var currentPreviewBoardBackgroundStyle: ScoreboardFaceView.BackgroundStyle {
        switch store.externalDisplayBackgroundMode {
        case .blurred:
            return .blurred
        case .clear:
            return .clear
        case .clearUnderBoard:
            return .transparent
        case .none:
            return .clear
        }
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
        return publicBoardState.isPresented ? "Public Board Open" : "Public Board Closed"
        #else
        return publicBoardState.isPresented ? "External Display Live" : "External Display Ready"
        #endif
    }

    private var displayStatusSystemImage: String {
        #if os(macOS)
        return publicBoardState.isPresented ? "rectangle.on.rectangle" : "rectangle"
        #else
        return publicBoardState.isPresented ? "display.2" : "cable.connector"
        #endif
    }

    private func updateIdleTimer(for phase: ScenePhase) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = phase == .active
        #endif
    }

    private func performConfirmedGameAction(_ action: GameConfirmationAction) {
        switch action {
        case .previousPeriod:
            store.adjustPeriod(by: -1)
        case .resetClock:
            store.resetClock(to: store.defaultClockSeconds)
        case .zeroScores:
            store.resetScores()
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

private struct StoredGameFile: Identifiable {
    let url: URL
    let modifiedAt: Date
    let snapshot: ScoreboardGameSnapshot?

    var id: String { url.path }
    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var matchupLine: String {
        guard let snapshot else {
            return "Game file"
        }

        let home = snapshot.homeTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TBD" : snapshot.homeTeamName
        let guest = snapshot.guestTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TBD" : snapshot.guestTeamName
        return "\(home) vs \(guest)"
    }
    var stateLine: String {
        guard let snapshot else {
            return "Preview unavailable"
        }

        let sport = snapshot.sport ?? .basketball
        let periodLine = "\(sport.periodShortTitle)\(snapshot.period)"
        let clockLine = formatGameClock(snapshot.defaultClockSeconds)

        if sport.supportsShotClock {
            return "\(sport.title) • \(periodLine) • \(clockLine) • SC \(formatShotClock(snapshot.defaultShotClockSeconds))"
        }

        return "\(sport.title) • \(periodLine) • \(clockLine)"
    }
    var detailLine: String { "Modified \(modifiedAt.formatted(date: .abbreviated, time: .shortened))" }

    private func formatGameClock(_ totalSeconds: Int) -> String {
        let boundedSeconds = max(0, min(59 * 60 + 59, totalSeconds))
        let minutes = boundedSeconds / 60
        let seconds = boundedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatShotClock(_ totalSeconds: Int) -> String {
        let boundedSeconds = max(0, min(99, totalSeconds))
        return String(format: "%.1f", Double(boundedSeconds))
    }
}

private struct FileOperationAlert: Identifiable {
    let id = UUID()
    let message: String
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case game
    case players
    case display
    case theme
    case files
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .game:
            return "Game Setup"
        case .players:
            return "Players"
        case .display:
            return "Display"
        case .theme:
            return "Theme"
        case .files:
            return "Library"
        case .logs:
            return "Logs"
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
        case .theme:
            return "Choose the look for both the operator controls and public scoreboard."
        case .files:
            return "Manage local game files for both reusable setups and live games."
        case .logs:
            return "Review per-run audit sessions with export and delete tools."
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
        case .theme:
            return "paintpalette"
        case .files:
            return "books.vertical"
        case .logs:
            return "list.bullet.rectangle.portrait"
        }
    }
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

private enum GameConfirmationAction: String, Identifiable {
    case previousPeriod
    case resetClock
    case zeroScores

    var id: String { rawValue }

    func title(periodTitle: String, resetClockTitle: String) -> String {
        switch self {
        case .previousPeriod:
            return "Confirm Previous \(periodTitle)"
        case .resetClock:
            return "Confirm Clock Reset"
        case .zeroScores:
            return "Confirm Zero Scores"
        }
    }

    func message(periodTitle: String) -> String {
        switch self {
        case .previousPeriod:
            return "Move back one \(periodTitle.lowercased())?"
        case .resetClock:
            return "Reset the game clock to its configured starting time?"
        case .zeroScores:
            return "Set both team scores back to zero?"
        }
    }

    func confirmButtonTitle(periodTitle: String) -> String {
        switch self {
        case .previousPeriod:
            return "Previous \(periodTitle)"
        case .resetClock:
            return "Reset Clock"
        case .zeroScores:
            return "Zero Scores"
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
    var headerTitleSpacing: CGFloat { denseControls ? 4 : 5 }
    var headerBlockSpacing: CGFloat { denseControls ? 8 : isTabletSized ? 7 : 12 }
    var headerInlineSpacing: CGFloat { denseControls ? 12 : isTabletSized ? 10 : 14 }
    var headerHorizontalPadding: CGFloat { denseControls ? 14 : isTabletSized ? 12 : 18 }
    var headerVerticalPadding: CGFloat { denseControls ? 10 : isTabletSized ? 8 : 12 }
    var headerBadgeHorizontalPadding: CGFloat { denseControls ? 10 : isTabletSized ? 9 : 12 }
    var headerBadgeVerticalPadding: CGFloat { denseControls ? 6 : isTabletSized ? 5 : 8 }
    var headerActionVerticalPadding: CGFloat { denseControls ? 8 : isTabletSized ? 7 : 10 }
    var controlCardPadding: CGFloat { denseControls ? 14 : isTabletSized ? 12 : 18 }
    var controlCardCornerRadius: CGFloat { denseControls ? 24 : 28 }

    var setupUsesVerticalFlow: Bool { width < 1260 || height < 860 }
    var setupControlCardsStacked: Bool { width < 760 }
    var setupFormWidth: CGFloat { min(max(contentMaxWidth * 0.38, 420), 540) }
    var setupPreviewHeight: CGFloat { max(280, min(height * 0.52, 520)) }
    var setupActionColumns: Int { isCompactWidth ? 1 : 2 }
    var secondaryButtonColumns: Int { width < 620 ? 1 : 2 }

    var dashboardHeaderHeight: CGFloat {
        if isPortraitish { return 118 }
        if isTabletSized { return denseControls || headerUsesVerticalFlow ? 84 : 68 }
        return denseControls || headerUsesVerticalFlow ? 96 : 76
    }

    var headerUsesVerticalFlow: Bool { isPortraitish || width < 920 }
    var headerActionColumns: Int {
        if width < 520 { return 1 }
        if isPortraitish { return 3 }
        if width < 1320 { return 2 }
        return 3
    }
    var headerActionWidth: CGFloat { width < 1320 ? 320 : 420 }

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
    func monospacedDigitIfNeeded(_ enabled: Bool) -> some View {
        if enabled {
            monospacedDigit()
        } else {
            self
        }
    }
}

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
