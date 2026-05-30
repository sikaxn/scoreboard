import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var externalDisplayState: ExternalDisplayState
    @Environment(\.openWindow) private var openWindow

    @State private var homeTeamDraft = ""
    @State private var guestTeamDraft = ""
    @State private var setupPeriod = 1
    @State private var setupClockSeconds = 12 * 60
    @State private var showsSetup = true
    @State private var didOpenMacScoreboardWindow = false

    var body: some View {
        GeometryReader { proxy in
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
                    setupScreen(size: proxy.size)
                } else {
                    dashboard(size: proxy.size)
                }
            }
        }
        .onReceive(store.$homeTeamName) { homeTeamDraft = $0 }
        .onReceive(store.$guestTeamName) { guestTeamDraft = $0 }
        .onAppear {
            #if os(macOS)
            guard !didOpenMacScoreboardWindow else {
                return
            }

            didOpenMacScoreboardWindow = true
            openWindow(id: "public-scoreboard")
            #endif
        }
    }

    private func setupScreen(size: CGSize) -> some View {
        let cardWidth = min(size.width - 48, 1380.0)
        let cardHeight = min(size.height - 48, 820.0)
        let panelSpacing = max(18, min(size.width * 0.015, 26))
        let leftPanelWidth = min(max(cardWidth * 0.38, 420), 520)

        return HStack {
            Spacer(minLength: 0)

            HStack(spacing: panelSpacing) {
                VStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Game Setup")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(setupDescription)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.76))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 18) {
                        setupField(title: "Home Team", text: $homeTeamDraft, tint: Color(red: 0.97, green: 0.38, blue: 0.28))
                        setupField(title: "Guest Team", text: $guestTeamDraft, tint: Color(red: 0.22, green: 0.68, blue: 0.95))
                    }

                    HStack(spacing: 18) {
                        setupStepperCard(
                            title: "Starting Period",
                            value: "\(setupPeriod)",
                            decrement: { setupPeriod = max(1, setupPeriod - 1) },
                            increment: { setupPeriod = min(9, setupPeriod + 1) }
                        )

                        setupClockCard
                    }
                    .frame(height: 220)

                    Spacer(minLength: 0)

                    HStack(spacing: 14) {
                        actionButton("Use Defaults", tint: .white.opacity(0.14)) {
                            homeTeamDraft = ""
                            guestTeamDraft = ""
                            setupPeriod = 1
                            setupClockSeconds = 12 * 60
                        }

                        actionButton("Open Scoreboard", tint: Color.orange) {
                            store.applySetup(
                                homeName: homeTeamDraft,
                                guestName: guestTeamDraft,
                                period: setupPeriod,
                                clockSeconds: setupClockSeconds
                            )
                            showsSetup = false
                        }
                    }
                }
                .frame(width: leftPanelWidth)
                .frame(maxHeight: .infinity, alignment: .top)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Preview")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    ScoreboardFaceView(
                        homeTeamName: homeTeamDraft,
                        guestTeamName: guestTeamDraft,
                        homeScore: 0,
                        guestScore: 0,
                        period: setupPeriod,
                        formattedClock: formatClock(setupClockSeconds),
                        isClockRunning: false,
                        compact: false
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.08))
                )
            }
            .padding(28)
            .frame(width: cardWidth, height: cardHeight)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(.white.opacity(0.1))
            )

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private var setupClockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Opening Clock")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(formatClock(setupClockSeconds))
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                setupClockPreset("8:00", seconds: 8 * 60)
                setupClockPreset("10:00", seconds: 10 * 60)
                setupClockPreset("12:00", seconds: 12 * 60)
            }

            HStack(spacing: 10) {
                smallActionButton("-1 Min", tint: .white.opacity(0.14)) {
                    setupClockSeconds = max(0, setupClockSeconds - 60)
                }

                smallActionButton("+1 Min", tint: .white.opacity(0.14)) {
                    setupClockSeconds = min((59 * 60) + 59, setupClockSeconds + 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private func setupClockPreset(_ title: String, seconds: Int) -> some View {
        smallActionButton(title, tint: setupClockSeconds == seconds ? Color.orange : .white.opacity(0.14)) {
            setupClockSeconds = seconds
        }
    }

    private func setupStepperCard(
        title: String,
        value: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(value)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                smallActionButton("Prev", tint: .white.opacity(0.14), action: decrement)
                smallActionButton("Next", tint: Color.orange, action: increment)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private func setupField(title: String, text: Binding<String>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            TextField(title, text: text)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dashboard(size: CGSize) -> some View {
        let padding = max(18, min(size.width * 0.02, 28))
        let headerHeight = max(78, min(size.height * 0.13, 110))

        return VStack(spacing: 16) {
            dashboardHeader
                .frame(height: headerHeight)

            HStack(spacing: 16) {
                previewPane
                    .frame(maxWidth: .infinity)

                controlPane
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dashboardHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Smart Scoreboard")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Landscape control board")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Label(
                displayStatusTitle,
                systemImage: displayStatusSystemImage
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(externalDisplayState.isConnected ? Color.green : Color.orange)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: Capsule())

            #if os(macOS)
            smallActionButton("Show Board", tint: .white.opacity(0.14)) {
                openWindow(id: "public-scoreboard")
            }
            #endif

            smallActionButton("Setup", tint: .white.opacity(0.14)) {
                showsSetup = true
            }

            smallActionButton("New Game", tint: Color.red) {
                store.newGame()
            }
        }
        .padding(.horizontal, 20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Live Preview")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            ScoreboardFaceView(
                homeTeamName: store.homeTeamName,
                guestTeamName: store.guestTeamName,
                homeScore: store.homeScore,
                guestScore: store.guestScore,
                period: store.period,
                formattedClock: store.formattedClock,
                isClockRunning: store.isClockRunning,
                compact: false
            )
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private var controlPane: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                teamControls(
                    title: "Home",
                    teamName: $homeTeamDraft,
                    score: store.homeScore,
                    isHome: true,
                    tint: Color(red: 0.97, green: 0.38, blue: 0.28)
                )

                teamControls(
                    title: "Guest",
                    teamName: $guestTeamDraft,
                    score: store.guestScore,
                    isHome: false,
                    tint: Color(red: 0.22, green: 0.68, blue: 0.95)
                )
            }
            .frame(maxHeight: .infinity)

            gameControls
                .frame(maxHeight: .infinity)
        }
    }

    private func teamControls(
        title: String,
        teamName: Binding<String>,
        score: Int,
        isHome: Bool,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            TextField("Team Name", text: teamName)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onSubmit {
                    store.updateTeamName(teamName.wrappedValue, isHome: isHome)
                }
                .onChange(of: teamName.wrappedValue) { _, newValue in
                    store.updateTeamName(newValue, isHome: isHome)
                }

            Text("\(score)")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                smallActionButton("+1", tint: tint) { store.adjustScore(isHome: isHome, by: 1) }
                smallActionButton("+2", tint: tint) { store.adjustScore(isHome: isHome, by: 2) }
                smallActionButton("+3", tint: tint) { store.adjustScore(isHome: isHome, by: 3) }
                smallActionButton("-1", tint: .white.opacity(0.14)) { store.adjustScore(isHome: isHome, by: -1) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private var gameControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Game Clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))

                    Text(store.formattedClock)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Period")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))

                    Text("\(store.period)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 10) {
                smallActionButton(store.isClockRunning ? "Pause" : "Start", tint: Color.green) {
                    store.toggleClock()
                }
                smallActionButton("Reset 12:00", tint: .white.opacity(0.14)) {
                    store.resetClock()
                }
                smallActionButton("Reset Clock", tint: .white.opacity(0.14)) {
                    store.resetClock(to: setupClockSeconds)
                }
            }

            HStack(spacing: 10) {
                smallActionButton("-1 Min", tint: .white.opacity(0.14)) { store.adjustClock(by: -60) }
                smallActionButton("+1 Min", tint: .white.opacity(0.14)) { store.adjustClock(by: 60) }
                smallActionButton("-1 Sec", tint: .white.opacity(0.14)) { store.adjustClock(by: -1) }
                smallActionButton("+1 Sec", tint: .white.opacity(0.14)) { store.adjustClock(by: 1) }
            }

            HStack(spacing: 10) {
                smallActionButton("Prev Period", tint: .white.opacity(0.14)) { store.adjustPeriod(by: -1) }
                smallActionButton("Next Period", tint: Color.orange) { store.adjustPeriod(by: 1) }
                smallActionButton("Zero Scores", tint: .white.opacity(0.14)) {
                    store.homeScore = 0
                    store.guestScore = 0
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private func actionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func smallActionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formatClock(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private var setupDescription: String {
        #if os(macOS)
        "Set the teams and opening game state, then move into the control board. A second native macOS scoreboard window opens separately for presentation."
        #else
        "Set the teams and opening game state, then move into the control board. The app stays landscape and all scoreboard controls fit on-screen."
        #endif
    }

    private var displayStatusTitle: String {
        #if os(macOS)
        externalDisplayState.isConnected ? "Scoreboard Window Open" : "Scoreboard Window Closed"
        #else
        externalDisplayState.isConnected ? "External Display Live" : "Second Display Ready"
        #endif
    }

    private var displayStatusSystemImage: String {
        #if os(macOS)
        externalDisplayState.isConnected ? "macwindow.on.rectangle" : "macwindow"
        #else
        externalDisplayState.isConnected ? "display.2" : "cable.connector"
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(ScoreboardStore.shared)
        .environmentObject(ExternalDisplayState.shared)
}
