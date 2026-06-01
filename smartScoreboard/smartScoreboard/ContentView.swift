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
    @State private var setupPeriod = ScoreboardStore.shared.period
    @State private var setupClockSeconds = ScoreboardStore.shared.defaultClockSeconds
    @State private var setupShotClockSeconds = ScoreboardStore.shared.defaultShotClockSeconds
    @State private var gameFileNameDraft = ""
    @State private var showsSetup = !ScoreboardStore.shared.didCompleteSetup
    @State private var selectedSettingsPane: SettingsPane = .game
    @State private var storedGameFiles: [StoredGameFile] = []
    @State private var selectedStoredGameFileID: String?
    @State private var showsGameImporter = false
    @State private var showsGameExporter = false
    @State private var exportDocument = ScoreboardGameDocument(snapshot: .empty)
    @State private var exportFilename = "Scoreboard Game.scoreboardgame"
    @State private var fileOperationErrorMessage: String?

    private var themePalette: ThemePalette { store.theme.palette }
    private var settingsPalette: SettingsPalette { themePalette.settingsPalette(for: store.theme, colorScheme: colorScheme) }
    private var homeTint: Color { themePalette.homeAccent }
    private var guestTint: Color { themePalette.guestAccent }

    var body: some View {
        GeometryReader { proxy in
            let layout = InterfaceLayout(size: proxy.size)

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
        .onReceive(store.$homeTeamName) { homeTeamDraft = $0 }
        .onReceive(store.$guestTeamName) { guestTeamDraft = $0 }
        .onReceive(store.$homeScore) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$guestScore) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$period) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$gameClockSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$defaultClockSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$shotClockMilliseconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$defaultShotClockSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$activeShotClockPresetSeconds) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$possessionDirection) { _ in autosaveSelectedGameFile() }
        .onReceive(store.$areSidesSwapped) { _ in autosaveSelectedGameFile() }
        .onAppear {
            initializeWorkingGameFile()
            updateIdleTimer(for: scenePhase)
        }
        .onChange(of: scenePhase) { _, newPhase in
            updateIdleTimer(for: newPhase)

            if newPhase != .active {
                autosaveSelectedGameFile(refreshSelection: true)
            }
        }
        .onChange(of: homeTeamDraft) { _, _ in commitSetupEdits() }
        .onChange(of: guestTeamDraft) { _, _ in commitSetupEdits() }
        .onChange(of: setupPeriod) { _, _ in commitSetupEdits() }
        .onChange(of: setupClockSeconds) { _, _ in commitSetupEdits() }
        .onChange(of: setupShotClockSeconds) { _, _ in commitSetupEdits() }
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
        .alert("File Error", isPresented: Binding(
            get: { fileOperationErrorMessage != nil },
            set: { if !$0 { fileOperationErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fileOperationErrorMessage ?? "")
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
        case .theme:
            settingsThemePane()
        case .files:
            settingsFilesPane()
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
                settingsStepperValueRow(
                    title: "Starting Period",
                    value: "\(setupPeriod)",
                    decrement: { setupPeriod = max(1, setupPeriod - 1) },
                    increment: { setupPeriod = min(9, setupPeriod + 1) }
                )
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
                    options: [
                        ("8:00", 8 * 60),
                        ("10:00", 10 * 60),
                        ("12:00", 12 * 60)
                    ],
                    selection: $setupClockSeconds
                )
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
                settingsSummaryValueRow(title: "Period", value: "\(setupPeriod)")
                settingsDivider()
                settingsSummaryValueRow(title: "Opening Clock", value: formatClock(setupClockSeconds))
                settingsDivider()
                settingsSummaryValueRow(title: "Shot Clock", value: ScoreboardStore.formatShotClock(setupShotClockSeconds))
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
            let previewHeight = layout.dashboardPreviewHeight(in: contentHeight)

            VStack(spacing: layout.sectionSpacing) {
                dashboardHeader(layout: layout)
                    .frame(height: layout.dashboardHeaderHeight)

                if layout.dashboardUsesSingleColumn || layout.dashboardStacksPreview {
                    VStack(spacing: layout.sectionSpacing) {
                        previewPane(layout: layout, height: previewHeight)
                            .frame(height: previewHeight)

                        controlPane(layout: layout)
                            .frame(height: max(contentHeight - previewHeight - layout.sectionSpacing, 0))
                    }
                } else {
                    HStack(spacing: layout.sectionSpacing) {
                        previewPane(layout: layout, height: contentHeight)
                            .frame(maxWidth: .infinity)

                        controlPane(layout: layout)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: contentHeight)
                }
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
        VStack(alignment: .leading, spacing: layout.headerTitleSpacing) {
            Text("Smart Scoreboard")
                .font(.system(size: layout.headerTitleSize, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.6)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            Text("Responsive control board")
                .font(layout.headerSubtitleFont)
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardSecondaryText)
        }
    }

    private func headerStatusBadge(layout: InterfaceLayout) -> some View {
        Label(displayStatusTitle, systemImage: displayStatusSystemImage)
            .font(layout.headerBadgeFont)
            .lineLimit(1)
            .foregroundStyle(publicBoardState.isPresented ? themePalette.dashboardStatusLive : themePalette.dashboardStatusIdle)
            .padding(.horizontal, layout.headerBadgeHorizontalPadding)
            .padding(.vertical, layout.headerBadgeVerticalPadding)
            .background(themePalette.dashboardCardBackground, in: Capsule())
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

    private func previewPane(layout: InterfaceLayout, height: CGFloat) -> some View {
        let widgetHeight = layout.shotClockWidgetHeight(in: height)
        let previewHeight = max(height - widgetHeight - layout.sectionSpacing, 0)

        return VStack(spacing: layout.sectionSpacing) {
            previewPanel(title: "Live Preview", caption: "Public scoreboard output", layout: layout) {
                ScoreboardFaceView(
                    theme: store.theme,
                    backgroundStyle: .clear,
                    homeTeamName: store.homeTeamName,
                    guestTeamName: store.guestTeamName,
                    homeScore: store.homeScore,
                    guestScore: store.guestScore,
                    period: store.period,
                    formattedClock: store.formattedClock,
                    formattedShotClock: store.formattedShotClock,
                    possessionDirection: store.possessionDirection,
                    areSidesSwapped: store.areSidesSwapped,
                    isClockRunning: store.isClockRunning,
                    compact: layout.previewUsesCompactBoard
                )
            }
            .frame(height: previewHeight)

            shotClockWidget(layout: layout)
                .frame(height: widgetHeight)
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
        GeometryReader { proxy in
            let teamSectionHeight = layout.teamSectionHeight(in: proxy.size.height)

            VStack(spacing: layout.sectionSpacing) {
                if layout.teamPanelsUseVerticalFlow {
                    VStack(spacing: 16) {
                        teamControlsGroup(layout: layout)
                    }
                    .frame(height: teamSectionHeight)
                } else {
                    HStack(spacing: 16) {
                        teamControlsGroup(layout: layout)
                    }
                    .frame(height: teamSectionHeight)
                }

                gameControls(layout: layout)
                    .frame(height: max(proxy.size.height - teamSectionHeight - layout.sectionSpacing, 0))
            }
        }
    }

    @ViewBuilder
    private func teamControlsGroup(layout: InterfaceLayout) -> some View {
        if store.areSidesSwapped {
            teamControls(
                title: "Guest",
                teamName: store.guestTeamName,
                score: store.guestScore,
                isHome: false,
                tint: guestTint,
                layout: layout
            )

            teamControls(
                title: "Home",
                teamName: store.homeTeamName,
                score: store.homeScore,
                isHome: true,
                tint: homeTint,
                layout: layout
            )
        } else {
            teamControls(
                title: "Home",
                teamName: store.homeTeamName,
                score: store.homeScore,
                isHome: true,
                tint: homeTint,
                layout: layout
            )

            teamControls(
                title: "Guest",
                teamName: store.guestTeamName,
                score: store.guestScore,
                isHome: false,
                tint: guestTint,
                layout: layout
            )
        }
    }

    private func teamControls(
        title: String,
        teamName: String,
        score: Int,
        isHome: Bool,
        tint: Color,
        layout: InterfaceLayout
    ) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardPrimaryText)

            Text(displayTeamName(teamName))
                .font(.system(size: layout.teamFieldFontSize, weight: .heavy, design: .rounded))
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(themePalette.dashboardPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(themePalette.dashboardCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(themePalette.dashboardCardBorder)
                )

            Text("\(score)")
                .font(.system(size: layout.scoreValueSize, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.4)
                .foregroundStyle(themePalette.dashboardPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            buttonGrid(
                columns: layout.teamButtonColumns,
                buttons: [
                    ActionDescriptor(title: "+1", tint: tint, foreground: .white) { store.adjustScore(isHome: isHome, by: 1) },
                    ActionDescriptor(title: "+2", tint: tint, foreground: .white) { store.adjustScore(isHome: isHome, by: 2) },
                    ActionDescriptor(title: "+3", tint: tint, foreground: .white) { store.adjustScore(isHome: isHome, by: 3) },
                    ActionDescriptor(title: "-1", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) { store.adjustScore(isHome: isHome, by: -1) }
                ],
                dense: layout.denseControls
            )

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
        }
        .controlCardStyle(
            backgroundColor: themePalette.dashboardCardBackground,
            borderColor: themePalette.dashboardCardBorder,
            padding: layout.controlCardPadding,
            cornerRadius: layout.controlCardCornerRadius
        )
    }

    private func gameControls(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
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

            buttonGrid(
                columns: 3,
                buttons: [
                    ActionDescriptor(title: "Prev Period", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.adjustPeriod(by: -1)
                    },
                    ActionDescriptor(title: "Swap Sides", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText) {
                        store.swapSides()
                    },
                    ActionDescriptor(title: "Next Period", tint: themePalette.dashboardWarningButton, foreground: themePalette.dashboardWarningButtonText) {
                        store.adjustPeriod(by: 1)
                    }
                ],
                dense: layout.denseControls,
                compactVerticalPadding: layout.advancedButtonVerticalPadding
            )

            buttonGrid(
                columns: 2,
                buttons: [
                    ActionDescriptor(title: "Reset 12:00", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, isEnabled: !store.isGameClockInterlockActive) {
                        store.resetClock(to: 12 * 60)
                    },
                    ActionDescriptor(title: "Zero Scores", tint: themePalette.dashboardNeutralButton, foreground: themePalette.dashboardNeutralButtonText, isEnabled: !store.isGameClockInterlockActive) {
                        store.resetScores()
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
        HStack(alignment: .top, spacing: 16) {
            gameMetricBlock(title: "Game Clock", value: store.formattedClock, valueSize: layout.metricValueSize - 2, monospaced: true)

            Spacer(minLength: 0)

            gameMetricBlock(title: "Period", value: "\(store.period)", valueSize: layout.metricValueSize - 10)
        }
    }

    private func gameMetricBlock(title: String, value: String, valueSize: CGFloat, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(themePalette.dashboardSubtleText)

            Text(value)
                .font(.system(size: valueSize, weight: .black, design: .rounded))
                .monospacedDigitIfNeeded(monospaced)
                .singleLineFitted(minScale: 0.35)
                .foregroundStyle(themePalette.dashboardPrimaryText)
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

    private func formatClock(_ seconds: Int) -> String {
        ScoreboardStore.formatGameClock(seconds)
    }

    private func resetSetupDraftsToDefaults() {
        homeTeamDraft = ""
        guestTeamDraft = ""
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
            homeTeamName: homeTeamDraft,
            guestTeamName: guestTeamDraft,
            homeScore: 0,
            guestScore: 0,
            period: setupPeriod,
            gameClockSeconds: setupClockSeconds,
            defaultClockSeconds: setupClockSeconds,
            shotClockMilliseconds: setupShotClockSeconds * 1_000,
            defaultShotClockSeconds: setupShotClockSeconds,
            activeShotClockPresetSeconds: setupShotClockSeconds,
            possessionDirection: .none,
            areSidesSwapped: false
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
        } catch {
            fileOperationErrorMessage = error.localizedDescription
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
        } catch {
            fileOperationErrorMessage = error.localizedDescription
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
        } catch {
            fileOperationErrorMessage = error.localizedDescription
        }
    }

    private func deleteSelectedStoredGame() {
        do {
            guard let selectedURL = selectedStoredGameFile?.url else {
                return
            }

            try FileManager.default.removeItem(at: selectedURL)
            refreshStoredGameFiles()
        } catch {
            fileOperationErrorMessage = error.localizedDescription
        }
    }

    private func loadStoredGameFile(_ gameFile: StoredGameFile) {
        do {
            let snapshot = try loadGameSnapshot(from: gameFile.url)
            selectedStoredGameFileID = gameFile.id
            store.applyGameSnapshot(snapshot)
            loadSetupDraftsFromStore()
            gameFileNameDraft = gameFile.displayName
        } catch {
            fileOperationErrorMessage = error.localizedDescription
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
            fileOperationErrorMessage = error.localizedDescription
        }
    }

    private func handleGameExport(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            fileOperationErrorMessage = error.localizedDescription
        }
    }

    private func suggestedGameFilename(_ home: String, _ guest: String) -> String {
        let resolvedHome = displayTeamName(home)
        let resolvedGuest = displayTeamName(guest)
        return "\(resolvedHome) vs \(resolvedGuest).scoreboardgame"
    }

    private func loadSetupDraftsFromStore() {
        homeTeamDraft = store.homeTeamName
        guestTeamDraft = store.guestTeamName
        setupPeriod = store.period
        setupClockSeconds = store.gameClockSeconds
        setupShotClockSeconds = store.activeShotClockPresetSeconds
        gameFileNameDraft = selectedStoredGameFile?.displayName ?? resolvedGameFilenameDraft(store.homeTeamName, store.guestTeamName, includeExtension: false)
    }

    private func displayTeamName(_ name: String) -> String {
        name.isEmpty ? "TBD" : name
    }

    private var selectedStoredGameFile: StoredGameFile? {
        guard let selectedStoredGameFileID else {
            return nil
        }

        return storedGameFiles.first { $0.id == selectedStoredGameFileID }
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
            fileOperationErrorMessage = error.localizedDescription
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
                fileOperationErrorMessage = error.localizedDescription
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
            fileVersion: 2,
            homeTeamName: homeTeamDraft,
            guestTeamName: guestTeamDraft,
            homeScore: currentSnapshot.homeScore,
            guestScore: currentSnapshot.guestScore,
            period: setupPeriod,
            gameClockSeconds: setupClockSeconds,
            defaultClockSeconds: setupClockSeconds,
            shotClockMilliseconds: setupShotClockSeconds * 1_000,
            defaultShotClockSeconds: setupShotClockSeconds,
            activeShotClockPresetSeconds: setupShotClockSeconds,
            possessionDirection: .none,
            areSidesSwapped: currentSnapshot.areSidesSwapped
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
            fileOperationErrorMessage = error.localizedDescription
        }
    }

    private func migrateLegacyPresetsToStoredGameFilesIfNeeded() {
        guard !store.setupPresets.isEmpty else {
            return
        }

        do {
            for preset in store.setupPresets {
                let snapshot = ScoreboardGameSnapshot(
                    homeTeamName: preset.homeTeamName,
                    guestTeamName: preset.guestTeamName,
                    homeScore: 0,
                    guestScore: 0,
                    period: preset.period,
                    gameClockSeconds: preset.clockSeconds,
                    defaultClockSeconds: preset.clockSeconds,
                    shotClockMilliseconds: preset.shotClockSeconds * 1_000,
                    defaultShotClockSeconds: preset.shotClockSeconds,
                    activeShotClockPresetSeconds: preset.shotClockSeconds,
                    possessionDirection: preset.possessionDirection,
                    areSidesSwapped: false
                )

                let baseFilename = preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? suggestedGameFilename(preset.homeTeamName, preset.guestTeamName)
                    : "\(preset.name).scoreboardgame"
                let url = try uniqueStoredGameFileURL(preferredFilename: baseFilename)
                try writeGameSnapshot(snapshot, to: url)
            }

            store.setupPresets.removeAll()
        } catch {
            fileOperationErrorMessage = error.localizedDescription
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

        return "P\(snapshot.period) • \(formatGameClock(snapshot.defaultClockSeconds)) • SC \(formatShotClock(snapshot.defaultShotClockSeconds))"
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

private enum SettingsPane: String, CaseIterable, Identifiable {
    case game
    case theme
    case files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .game:
            return "Game Setup"
        case .theme:
            return "Theme"
        case .files:
            return "Library"
        }
    }

    var subtitle: String {
        switch self {
        case .game:
            return "Edit teams, period, and clock defaults before opening the live control board."
        case .theme:
            return "Choose the look for both the operator controls and public scoreboard."
        case .files:
            return "Manage local game files for both reusable setups and live games."
        }
    }

    var systemImage: String {
        switch self {
        case .game:
            return "slider.horizontal.3"
        case .theme:
            return "paintpalette"
        case .files:
            return "books.vertical"
        }
    }
}

private enum ButtonStyleVariant: Equatable {
    case compact
    case large
}

private struct InterfaceLayout {
    let size: CGSize

    private var width: CGFloat { size.width }
    private var height: CGFloat { size.height }

    var isCompactWidth: Bool { width < 840 }
    var isShortHeight: Bool { height < 760 }
    var isPortraitish: Bool { height > width * 1.05 }
    var denseControls: Bool { isShortHeight || isPortraitish || width < 980 }

    var outerPadding: CGFloat { isCompactWidth ? 16 : 24 }
    var cardPadding: CGFloat { isCompactWidth ? 18 : 28 }
    var sectionSpacing: CGFloat { isCompactWidth ? 14 : 18 }
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
    var headerBlockSpacing: CGFloat { denseControls ? 8 : 12 }
    var headerInlineSpacing: CGFloat { denseControls ? 12 : 14 }
    var headerHorizontalPadding: CGFloat { denseControls ? 14 : 18 }
    var headerVerticalPadding: CGFloat { denseControls ? 10 : 12 }
    var headerBadgeHorizontalPadding: CGFloat { denseControls ? 10 : 12 }
    var headerBadgeVerticalPadding: CGFloat { denseControls ? 6 : 8 }
    var headerActionVerticalPadding: CGFloat { denseControls ? 8 : 10 }
    var controlCardPadding: CGFloat { denseControls ? 14 : 18 }
    var controlCardCornerRadius: CGFloat { denseControls ? 24 : 28 }

    var setupUsesVerticalFlow: Bool { width < 1260 || height < 860 }
    var setupControlCardsStacked: Bool { width < 760 }
    var setupFormWidth: CGFloat { min(max(contentMaxWidth * 0.38, 420), 540) }
    var setupPreviewHeight: CGFloat { max(280, min(height * 0.52, 520)) }
    var setupActionColumns: Int { isCompactWidth ? 1 : 2 }
    var secondaryButtonColumns: Int { width < 620 ? 1 : 2 }

    var dashboardUsesSingleColumn: Bool { width < 560 }
    var dashboardStacksPreview: Bool { !dashboardUsesSingleColumn && isPortraitish }
    var dashboardHeaderHeight: CGFloat {
        if isPortraitish { return 118 }
        return denseControls || headerUsesVerticalFlow ? 96 : 76
    }
    func dashboardPreviewHeight(in contentHeight: CGFloat) -> CGFloat {
        if dashboardUsesSingleColumn {
            return min(max(contentHeight * 0.28, 180), 240)
        }
        if dashboardStacksPreview {
            return min(max(contentHeight * 0.26, 200), 300)
        }
        return contentHeight
    }
    func shotClockWidgetHeight(in totalHeight: CGFloat) -> CGFloat {
        let minimumBoardHeight: CGFloat = dashboardUsesSingleColumn ? 180 : dashboardStacksPreview ? 210 : 250
        let baseHeight = min(
            max(totalHeight * (dashboardUsesSingleColumn ? 0.34 : dashboardStacksPreview ? 0.30 : 0.26), 188),
            dashboardUsesSingleColumn ? 236 : 212
        )
        let availableHeight = max(totalHeight - minimumBoardHeight - sectionSpacing, 0)
        return min(baseHeight, availableHeight)
    }

    var headerUsesVerticalFlow: Bool { isPortraitish || width < 920 }
    var headerActionColumns: Int {
        if width < 520 { return 1 }
        if isPortraitish { return 3 }
        if width < 1320 { return 2 }
        return 3
    }
    var headerActionWidth: CGFloat { width < 1320 ? 320 : 420 }

    var teamPanelsUseVerticalFlow: Bool { width < 620 && !isPortraitish }
    var teamButtonColumns: Int { width < 520 ? 1 : 2 }
    func teamSectionHeight(in totalHeight: CGFloat) -> CGFloat {
        if teamPanelsUseVerticalFlow {
            return min(max(totalHeight * 0.58, 280), totalHeight - 120)
        }
        if isPortraitish {
            return min(max(totalHeight * 0.42, 210), 300)
        }
        return min(max(totalHeight * 0.45, 220), 320)
    }
    var gameMetricsUseVerticalFlow: Bool { width < 540 }
    var gamePrimaryButtonColumns: Int {
        if width < 520 { return 1 }
        if dashboardStacksPreview { return 3 }
        return 3
    }
    var gameSecondaryButtonColumns: Int {
        if dashboardUsesSingleColumn { return width < 420 ? 1 : 2 }
        if dashboardStacksPreview { return width < 620 ? 2 : 5 }
        if width < 1000 { return 3 }
        if width < 1320 { return 4 }
        return 5
    }
    var advancedButtonVerticalPadding: CGFloat { denseControls ? 8 : 11 }
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
