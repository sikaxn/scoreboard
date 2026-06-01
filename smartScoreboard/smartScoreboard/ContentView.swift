import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState
    @Environment(\.openWindow) private var openWindow

    @State private var homeTeamDraft = ScoreboardStore.shared.homeTeamName
    @State private var guestTeamDraft = ScoreboardStore.shared.guestTeamName
    @State private var setupPeriod = ScoreboardStore.shared.period
    @State private var setupClockSeconds = ScoreboardStore.shared.defaultClockSeconds
    @State private var presetNameDraft = ""
    @State private var showsSetup = !ScoreboardStore.shared.didCompleteSetup
    @State private var didOpenMacScoreboardWindow = false

    var body: some View {
        GeometryReader { proxy in
            let layout = InterfaceLayout(size: proxy.size)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.14),
                        Color(red: 0.16, green: 0.08, blue: 0.08),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if showsSetup {
                    setupScreen(layout: layout)
                } else {
                    dashboard(layout: layout)
                }
            }
        }
        .onReceive(store.$homeTeamName) { homeTeamDraft = $0 }
        .onReceive(store.$guestTeamName) { guestTeamDraft = $0 }
        .onAppear {
            loadSetupDraftsFromStore()

            #if os(macOS)
            guard !didOpenMacScoreboardWindow else {
                return
            }

            didOpenMacScoreboardWindow = true
            showPublicBoardWindow()
            #endif
        }
    }

    private func setupScreen(layout: InterfaceLayout) -> some View {
        ScrollView(showsIndicators: false) {
            HStack {
                Spacer(minLength: 0)

                Group {
                    if layout.setupUsesVerticalFlow {
                        VStack(spacing: layout.sectionSpacing) {
                            setupFormPanel(layout: layout)
                            setupPreviewPanel(layout: layout)
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.sectionSpacing) {
                            setupFormPanel(layout: layout)
                                .frame(width: layout.setupFormWidth)

                            setupPreviewPanel(layout: layout)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(layout.cardPadding)
                .frame(maxWidth: layout.contentMaxWidth)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: layout.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cardCornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.1))
                )

                Spacer(minLength: 0)
            }
            .padding(layout.outerPadding)
        }
    }

    private func setupFormPanel(layout: InterfaceLayout) -> some View {
        VStack(spacing: layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Game Setup")
                    .font(.system(size: layout.heroTitleSize, weight: .black, design: .rounded))
                    .singleLineFitted(minScale: 0.6)
                    .foregroundStyle(.white)

                Text(setupDescription)
                    .font(layout.bodyFont)
                    .foregroundStyle(.white.opacity(0.76))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 18) {
                setupField(
                    title: "Home Team",
                    text: $homeTeamDraft,
                    tint: Color(red: 0.97, green: 0.38, blue: 0.28),
                    layout: layout
                )

                setupField(
                    title: "Guest Team",
                    text: $guestTeamDraft,
                    tint: Color(red: 0.22, green: 0.68, blue: 0.95),
                    layout: layout
                )

                presetManagerCard(layout: layout)
            }

            Group {
                if layout.setupControlCardsStacked {
                    VStack(spacing: 16) {
                        setupStepperCard(
                            title: "Starting Period",
                            value: "\(setupPeriod)",
                            layout: layout,
                            decrement: { setupPeriod = max(1, setupPeriod - 1) },
                            increment: { setupPeriod = min(9, setupPeriod + 1) }
                        )

                        setupClockCard(layout: layout)
                    }
                } else {
                    HStack(spacing: 16) {
                        setupStepperCard(
                            title: "Starting Period",
                            value: "\(setupPeriod)",
                            layout: layout,
                            decrement: { setupPeriod = max(1, setupPeriod - 1) },
                            increment: { setupPeriod = min(9, setupPeriod + 1) }
                        )

                        setupClockCard(layout: layout)
                    }
                }
            }

            buttonGrid(
                columns: layout.setupActionColumns,
                buttons: [
                    ActionDescriptor(title: "Use Defaults", tint: .white.opacity(0.14)) {
                        homeTeamDraft = ""
                        guestTeamDraft = ""
                        setupPeriod = 1
                        setupClockSeconds = 12 * 60
                        presetNameDraft = ""
                    },
                    ActionDescriptor(title: "Open Scoreboard", tint: .orange) {
                        store.applySetup(
                            homeName: homeTeamDraft,
                            guestName: guestTeamDraft,
                            period: setupPeriod,
                            clockSeconds: setupClockSeconds
                        )
                        #if os(macOS)
                        showPublicBoardWindow()
                        #endif
                        showsSetup = false
                    }
                ],
                style: .large
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func setupPreviewPanel(layout: InterfaceLayout) -> some View {
        previewPanel(title: "Preview", caption: "Opening board layout", layout: layout) {
            ScoreboardFaceView(
                homeTeamName: homeTeamDraft,
                guestTeamName: guestTeamDraft,
                homeScore: 0,
                guestScore: 0,
                period: setupPeriod,
                formattedClock: formatClock(setupClockSeconds),
                isClockRunning: false,
                compact: layout.previewUsesCompactBoard
            )
        }
        .frame(minHeight: layout.setupPreviewHeight)
    }

    private func setupClockCard(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Opening Clock")
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(.white)

            Text(formatClock(setupClockSeconds))
                .font(.system(size: layout.metricValueSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .singleLineFitted(minScale: 0.35)
                .foregroundStyle(.white)

            buttonGrid(
                columns: layout.presetButtonColumns,
                buttons: [
                    ActionDescriptor(title: "8:00", tint: setupClockSeconds == 8 * 60 ? .orange : .white.opacity(0.14)) {
                        setupClockSeconds = 8 * 60
                    },
                    ActionDescriptor(title: "10:00", tint: setupClockSeconds == 10 * 60 ? .orange : .white.opacity(0.14)) {
                        setupClockSeconds = 10 * 60
                    },
                    ActionDescriptor(title: "12:00", tint: setupClockSeconds == 12 * 60 ? .orange : .white.opacity(0.14)) {
                        setupClockSeconds = 12 * 60
                    }
                ]
            )

            buttonGrid(
                columns: layout.secondaryButtonColumns,
                buttons: [
                    ActionDescriptor(title: "-1 Min", tint: .white.opacity(0.14)) {
                        setupClockSeconds = max(0, setupClockSeconds - 60)
                    },
                    ActionDescriptor(title: "+1 Min", tint: .white.opacity(0.14)) {
                        setupClockSeconds = min((59 * 60) + 59, setupClockSeconds + 60)
                    }
                ]
            )
        }
        .controlCardStyle()
    }

    private func setupStepperCard(
        title: String,
        value: String,
        layout: InterfaceLayout,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(.white)

            Text(value)
                .font(.system(size: layout.metricValueSize + 4, weight: .heavy, design: .rounded))
                .singleLineFitted(minScale: 0.5)
                .foregroundStyle(.white)

            buttonGrid(
                columns: layout.secondaryButtonColumns,
                buttons: [
                    ActionDescriptor(title: "Prev", tint: .white.opacity(0.14), action: decrement),
                    ActionDescriptor(title: "Next", tint: .orange, action: increment)
                ]
            )
        }
        .controlCardStyle()
    }

    private func setupField(title: String, text: Binding<String>, tint: Color, layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(.white)

            TextField(title, text: text)
                .scoreboardTextField(
                    font: .system(size: layout.fieldFontSize, weight: .heavy, design: .rounded),
                    tint: tint.opacity(0.18),
                    cornerRadius: 22,
                    horizontalPadding: 18,
                    verticalPadding: 18
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presetManagerCard(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Preset List")
                    .font(.title3.weight(.bold))
                    .singleLineFitted(minScale: 0.7)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Text("\(store.setupPresets.count) saved")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Group {
                if layout.isCompactWidth {
                    VStack(spacing: 10) {
                        TextField("Preset Name", text: $presetNameDraft)
                            .scoreboardTextField(
                                font: .system(size: 18, weight: .bold, design: .rounded),
                                tint: .white.opacity(0.08),
                                cornerRadius: 18,
                                horizontalPadding: 14,
                                verticalPadding: 12
                            )

                        buttonGrid(
                            columns: 1,
                            buttons: [
                                ActionDescriptor(title: "Save Preset", tint: .orange) {
                                    savePreset()
                                }
                            ]
                        )
                    }
                } else {
                    HStack(spacing: 10) {
                        TextField("Preset Name", text: $presetNameDraft)
                            .scoreboardTextField(
                                font: .system(size: 18, weight: .bold, design: .rounded),
                                tint: .white.opacity(0.08),
                                cornerRadius: 18,
                                horizontalPadding: 14,
                                verticalPadding: 12
                            )

                        Button {
                            savePreset()
                        } label: {
                            Text("Save")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.orange, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if store.setupPresets.isEmpty {
                Text("Save a preset to reuse team names and opening clock settings.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.setupPresets) { preset in
                            presetRow(preset, layout: layout)
                        }
                    }
                }
                .frame(maxHeight: layout.presetListHeight)
            }
        }
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private func presetRow(_ preset: SetupPreset, layout: InterfaceLayout) -> some View {
        Group {
            if layout.isCompactWidth {
                VStack(alignment: .leading, spacing: 12) {
                    presetSummary(preset)

                    buttonGrid(
                        columns: 2,
                        buttons: [
                            ActionDescriptor(title: "Load", tint: .white.opacity(0.14)) {
                                applyPreset(preset)
                            },
                            ActionDescriptor(title: "Delete", tint: .red.opacity(0.82)) {
                                store.deletePreset(preset)
                            }
                        ]
                    )
                }
            } else {
                HStack(spacing: 14) {
                    presetSummary(preset)

                    Spacer(minLength: 0)

                    Button {
                        applyPreset(preset)
                    } label: {
                        Text("Load")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.deletePreset(preset)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.82), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func presetSummary(_ preset: SetupPreset) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(preset.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("\(displayTeamName(preset.homeTeamName)) vs \(displayTeamName(preset.guestTeamName))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            Text("P\(preset.period) • \(formatClock(preset.clockSeconds))")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dashboard(layout: InterfaceLayout) -> some View {
        Group {
            if layout.dashboardNeedsScroll {
                ScrollView(showsIndicators: false) {
                    dashboardContent(layout: layout)
                }
            } else {
                dashboardContent(layout: layout)
            }
        }
    }

    private func dashboardContent(layout: InterfaceLayout) -> some View {
        VStack(spacing: layout.sectionSpacing) {
            dashboardHeader(layout: layout)

            if layout.dashboardUsesSingleColumn {
                VStack(spacing: layout.sectionSpacing) {
                    previewPane(layout: layout)
                        .frame(minHeight: layout.dashboardPreviewHeight)

                    controlPane(layout: layout)
                }
            } else if layout.dashboardStacksPreview {
                VStack(spacing: layout.sectionSpacing) {
                    previewPane(layout: layout)
                        .frame(minHeight: layout.dashboardPreviewHeight)

                    controlPane(layout: layout)
                }
            } else {
                HStack(spacing: layout.sectionSpacing) {
                    previewPane(layout: layout)
                        .frame(maxWidth: .infinity)

                    controlPane(layout: layout)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(layout.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func dashboardHeader(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if layout.headerUsesVerticalFlow {
                VStack(alignment: .leading, spacing: 16) {
                    headerTitleBlock
                    headerStatusBadge
                    headerActionButtons(layout: layout)
                }
            } else {
                HStack(spacing: 16) {
                    headerTitleBlock
                    Spacer(minLength: 0)
                    headerStatusBadge
                    headerActionButtons(layout: layout)
                        .frame(maxWidth: layout.headerActionWidth)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private var headerTitleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Smart Scoreboard")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.6)
                .foregroundStyle(.white)

            Text("Responsive control board")
                .font(.headline)
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var headerStatusBadge: some View {
        Label(displayStatusTitle, systemImage: displayStatusSystemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(publicBoardState.isPresented ? Color.green : Color.orange)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: Capsule())
    }

    private func headerActionButtons(layout: InterfaceLayout) -> some View {
        var buttons: [ActionDescriptor] = []

        #if os(macOS)
        buttons.append(
            ActionDescriptor(title: "Show Board", tint: .white.opacity(0.14)) {
                showPublicBoardWindow()
            }
        )
        #endif

        buttons.append(
            ActionDescriptor(title: "Setup", tint: .white.opacity(0.14)) {
                loadSetupDraftsFromStore()
                showsSetup = true
            }
        )

        buttons.append(
            ActionDescriptor(title: "New Game", tint: .red) {
                store.newGame()
            }
        )

        return buttonGrid(columns: layout.headerActionColumns, buttons: buttons)
    }

    private func previewPane(layout: InterfaceLayout) -> some View {
        previewPanel(title: "Live Preview", caption: "Public scoreboard output", layout: layout) {
            ScoreboardFaceView(
                homeTeamName: store.homeTeamName,
                guestTeamName: store.guestTeamName,
                homeScore: store.homeScore,
                guestScore: store.guestScore,
                period: store.period,
                formattedClock: store.formattedClock,
                isClockRunning: store.isClockRunning,
                compact: layout.previewUsesCompactBoard
            )
        }
    }

    private func controlPane(layout: InterfaceLayout) -> some View {
        VStack(spacing: layout.sectionSpacing) {
            if layout.teamPanelsUseVerticalFlow {
                VStack(spacing: 16) {
                    teamControls(
                        title: "Home",
                        teamName: $homeTeamDraft,
                        score: store.homeScore,
                        isHome: true,
                        tint: Color(red: 0.97, green: 0.38, blue: 0.28),
                        layout: layout
                    )

                    teamControls(
                        title: "Guest",
                        teamName: $guestTeamDraft,
                        score: store.guestScore,
                        isHome: false,
                        tint: Color(red: 0.22, green: 0.68, blue: 0.95),
                        layout: layout
                    )
                }
            } else {
                HStack(spacing: 16) {
                    teamControls(
                        title: "Home",
                        teamName: $homeTeamDraft,
                        score: store.homeScore,
                        isHome: true,
                        tint: Color(red: 0.97, green: 0.38, blue: 0.28),
                        layout: layout
                    )

                    teamControls(
                        title: "Guest",
                        teamName: $guestTeamDraft,
                        score: store.guestScore,
                        isHome: false,
                        tint: Color(red: 0.22, green: 0.68, blue: 0.95),
                        layout: layout
                    )
                }
            }

            gameControls(layout: layout)
        }
    }

    private func teamControls(
        title: String,
        teamName: Binding<String>,
        score: Int,
        isHome: Bool,
        tint: Color,
        layout: InterfaceLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(.white)

            TextField("Team Name", text: teamName)
                .scoreboardTextField(
                    font: .system(size: layout.teamFieldFontSize, weight: .heavy, design: .rounded),
                    tint: .white.opacity(0.08),
                    cornerRadius: 16,
                    horizontalPadding: 14,
                    verticalPadding: 12
                )
                .onSubmit {
                    store.updateTeamName(teamName.wrappedValue, isHome: isHome)
                }
                .onChange(of: teamName.wrappedValue) { _, newValue in
                    store.updateTeamName(newValue, isHome: isHome)
                }

            Text("\(score)")
                .font(.system(size: layout.scoreValueSize, weight: .black, design: .rounded))
                .singleLineFitted(minScale: 0.4)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            buttonGrid(
                columns: layout.teamButtonColumns,
                buttons: [
                    ActionDescriptor(title: "+1", tint: tint) { store.adjustScore(isHome: isHome, by: 1) },
                    ActionDescriptor(title: "+2", tint: tint) { store.adjustScore(isHome: isHome, by: 2) },
                    ActionDescriptor(title: "+3", tint: tint) { store.adjustScore(isHome: isHome, by: 3) },
                    ActionDescriptor(title: "-1", tint: .white.opacity(0.14)) { store.adjustScore(isHome: isHome, by: -1) }
                ]
            )
        }
        .controlCardStyle()
    }

    private func gameControls(layout: InterfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if layout.gameMetricsUseVerticalFlow {
                VStack(alignment: .leading, spacing: 12) {
                    gameMetricBlock(title: "Game Clock", value: store.formattedClock, valueSize: layout.metricValueSize + 2, monospaced: true)
                    gameMetricBlock(title: "Period", value: "\(store.period)", valueSize: layout.metricValueSize - 4)
                }
            } else {
                HStack(alignment: .top) {
                    gameMetricBlock(title: "Game Clock", value: store.formattedClock, valueSize: layout.metricValueSize + 2, monospaced: true)
                    Spacer(minLength: 0)
                    gameMetricBlock(title: "Period", value: "\(store.period)", valueSize: layout.metricValueSize - 4)
                }
            }

            buttonGrid(
                columns: layout.gameButtonColumns,
                buttons: [
                    ActionDescriptor(title: store.isClockRunning ? "Pause" : "Start", tint: .green) {
                        store.toggleClock()
                    },
                    ActionDescriptor(title: "Reset 12:00", tint: .white.opacity(0.14)) {
                        store.resetClock(to: 12 * 60)
                    },
                    ActionDescriptor(title: "Reset Clock", tint: .white.opacity(0.14)) {
                        store.resetClock()
                    },
                    ActionDescriptor(title: "-1 Min", tint: .white.opacity(0.14)) {
                        store.adjustClock(by: -60)
                    },
                    ActionDescriptor(title: "+1 Min", tint: .white.opacity(0.14)) {
                        store.adjustClock(by: 60)
                    },
                    ActionDescriptor(title: "-1 Sec", tint: .white.opacity(0.14)) {
                        store.adjustClock(by: -1)
                    },
                    ActionDescriptor(title: "+1 Sec", tint: .white.opacity(0.14)) {
                        store.adjustClock(by: 1)
                    },
                    ActionDescriptor(title: "Prev Period", tint: .white.opacity(0.14)) {
                        store.adjustPeriod(by: -1)
                    },
                    ActionDescriptor(title: "Next Period", tint: .orange) {
                        store.adjustPeriod(by: 1)
                    },
                    ActionDescriptor(title: "Zero Scores", tint: .white.opacity(0.14)) {
                        store.homeScore = 0
                        store.guestScore = 0
                    }
                ]
            )
        }
        .controlCardStyle()
    }

    private func gameMetricBlock(title: String, value: String, valueSize: CGFloat, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .singleLineFitted(minScale: 0.7)
                .foregroundStyle(.white.opacity(0.68))

            Text(value)
                .font(.system(size: valueSize, weight: .black, design: .rounded))
                .monospacedDigitIfNeeded(monospaced)
                .singleLineFitted(minScale: 0.35)
                .foregroundStyle(.white)
        }
    }

    private func buttonGrid(
        columns: Int,
        buttons: [ActionDescriptor],
        style: ButtonStyleVariant = .compact
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, columns)),
            spacing: 10
        ) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                if style == .large {
                    actionButton(button.title, tint: button.tint, action: button.action)
                } else {
                    smallActionButton(button.title, tint: button.tint, action: button.action)
                }
            }
        }
    }

    private func actionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func smallActionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .singleLineFitted(minScale: 0.55)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func formatClock(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func savePreset() {
        store.savePreset(
            named: presetNameDraft,
            homeName: homeTeamDraft,
            guestName: guestTeamDraft,
            period: setupPeriod,
            clockSeconds: setupClockSeconds
        )
        presetNameDraft = presetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadSetupDraftsFromStore() {
        homeTeamDraft = store.homeTeamName
        guestTeamDraft = store.guestTeamName
        setupPeriod = store.period
        setupClockSeconds = store.defaultClockSeconds
    }

    private func applyPreset(_ preset: SetupPreset) {
        presetNameDraft = preset.name
        homeTeamDraft = preset.homeTeamName
        guestTeamDraft = preset.guestTeamName
        setupPeriod = preset.period
        setupClockSeconds = preset.clockSeconds
    }

    private func displayTeamName(_ name: String) -> String {
        name.isEmpty ? "TBD" : name
    }

    #if os(macOS)
    private func showPublicBoardWindow() {
        guard !publicBoardState.isPresented else {
            return
        }

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
            let verticalInset = max(18, min(proxy.size.height * 0.05, 34))
            let availableWidth = max(proxy.size.width - (horizontalInset * 2), 0)
            let availableHeight = max(proxy.size.height - (verticalInset * 2), 0)
            let aspectRatio = ScoreboardFaceView.preferredAspectRatio
            let fittedWidth = min(availableWidth, availableHeight * aspectRatio)
            let fittedHeight = min(availableHeight, fittedWidth / aspectRatio)

            board
                .frame(width: fittedWidth, height: fittedHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
                        .foregroundStyle(.white)

                    Text(caption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.56))
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    Text(caption)
                        .font(.subheadline.weight(.semibold))
                        .singleLineFitted(minScale: 0.7)
                        .foregroundStyle(.white.opacity(0.56))
                }
            }

            previewBoardSurface(layout: layout) {
                content()
            }
        }
        .padding(layout.previewPanelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
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
}

private struct ActionDescriptor {
    let title: String
    let tint: Color
    let action: () -> Void
}

private enum ButtonStyleVariant: Equatable {
    case compact
    case large
}

private struct InterfaceLayout {
    let size: CGSize

    private var width: CGFloat { size.width }
    private var height: CGFloat { size.height }

    var isCompactWidth: Bool { width < 900 }
    var isShortHeight: Bool { height < 760 }

    var outerPadding: CGFloat { isCompactWidth ? 16 : 24 }
    var cardPadding: CGFloat { isCompactWidth ? 18 : 28 }
    var sectionSpacing: CGFloat { isCompactWidth ? 14 : 18 }
    var cardCornerRadius: CGFloat { isCompactWidth ? 26 : 34 }
    var contentMaxWidth: CGFloat { min(max(width - (outerPadding * 2), 0), 1480) }

    var heroTitleSize: CGFloat { isCompactWidth ? 34 : 40 }
    var fieldFontSize: CGFloat { isCompactWidth ? 24 : 28 }
    var teamFieldFontSize: CGFloat { isCompactWidth ? 20 : 22 }
    var metricValueSize: CGFloat { isCompactWidth ? 34 : 40 }
    var scoreValueSize: CGFloat { isCompactWidth ? 40 : 48 }
    var bodyFont: Font { isCompactWidth ? .subheadline : .headline }

    var setupUsesVerticalFlow: Bool { width < 1260 || height < 860 }
    var setupControlCardsStacked: Bool { width < 760 }
    var setupFormWidth: CGFloat { min(max(contentMaxWidth * 0.38, 420), 540) }
    var setupPreviewHeight: CGFloat { max(280, min(height * 0.52, 520)) }
    var setupActionColumns: Int { isCompactWidth ? 1 : 2 }
    var presetButtonColumns: Int { width < 700 ? 1 : 3 }
    var secondaryButtonColumns: Int { width < 620 ? 1 : 2 }
    var presetListHeight: CGFloat { isCompactWidth ? 240 : 180 }

    var dashboardUsesSingleColumn: Bool { width < 960 }
    var dashboardStacksPreview: Bool { !dashboardUsesSingleColumn && (width < 1380 || height < 820) }
    var dashboardNeedsScroll: Bool { dashboardUsesSingleColumn || isShortHeight }
    var dashboardPreviewHeight: CGFloat { max(260, min(height * 0.48, 420)) }

    var headerUsesVerticalFlow: Bool { width < 1180 || height < 760 }
    var headerActionColumns: Int { isCompactWidth ? 1 : width < 1320 ? 2 : 3 }
    var headerActionWidth: CGFloat { width < 1320 ? 320 : 420 }

    var teamPanelsUseVerticalFlow: Bool { width < 760 }
    var teamButtonColumns: Int { width < 620 ? 1 : 2 }
    var gameMetricsUseVerticalFlow: Bool { width < 760 }
    var gameButtonColumns: Int {
        if width < 560 { return 1 }
        if width < 900 { return 2 }
        if width < 1240 { return 3 }
        return 4
    }

    var previewPanelPadding: CGFloat { isCompactWidth ? 18 : 24 }
    var previewHeaderUsesVerticalFlow: Bool { isCompactWidth }
    var previewUsesCompactBoard: Bool { width < 1200 || height < 760 }
}

private extension View {
    func singleLineFitted(minScale: CGFloat = 0.55) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minScale)
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

    func controlCardStyle() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            )
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
