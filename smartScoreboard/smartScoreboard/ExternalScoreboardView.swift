import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ExternalScoreboardView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState

    var body: some View {
        let palette = store.theme.palette
        let boardBackgroundStyle = resolvedBoardBackgroundStyle()

        GeometryReader { proxy in
            let displaySize = proxy.size
            let boardSize = fittedBoardSize(in: displaySize)
            let usesCompactBoard = boardSize.width < 1320 || boardSize.height < 760

            ZStack {
                externalBackgroundView(using: palette)
                    .ignoresSafeArea()

                ScoreboardFaceView(
                    theme: store.theme,
                    backgroundStyle: boardBackgroundStyle,
                    sport: store.selectedSport,
                    rules: store.currentRules,
                    showsScore: store.supportsScore,
                    homeTeamName: store.homeTeamName,
                    guestTeamName: store.guestTeamName,
                    homeScore: store.homeScore,
                    guestScore: store.guestScore,
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
                    debateActiveTimer: store.isDebateMode ? store.debateActiveTimer : nil,
                    showsDebatePrepTime: store.showsDebatePrepTime,
                    formattedDebatePrepHomeClock: store.showsDebatePrepTime ? store.formattedDebatePrepHomeClock : nil,
                    formattedDebatePrepGuestClock: store.showsDebatePrepTime ? store.formattedDebatePrepGuestClock : nil,
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
                    homePenaltyTimers: store.homePenaltyTimers,
                    guestPenaltyTimers: store.guestPenaltyTimers,
                    homePlayers: store.displayedHomePlayers,
                    guestPlayers: store.displayedGuestPlayers,
                    compact: usesCompactBoard
                )
                .frame(width: boardSize.width, height: boardSize.height)
                .clipped()
                .position(x: displaySize.width / 2, y: displaySize.height / 2)
            }
            .frame(width: displaySize.width, height: displaySize.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(externalBackgroundView(using: palette).ignoresSafeArea())
        #if os(macOS)
        .background(PublicBoardWindowConfigurator(
            backgroundMode: store.externalDisplayBackgroundMode,
            fullscreenRequestID: publicBoardState.fullscreenRequestID
        ))
        #endif
    }

    private func fittedBoardSize(in availableSize: CGSize) -> CGSize {
        let horizontalInset = max(0, min(availableSize.width * 0.025, 32))
        let verticalInset = max(0, min(availableSize.height * 0.025, 26))
        let usableWidth = max(availableSize.width - (horizontalInset * 2), 0)
        let usableHeight = max(availableSize.height - (verticalInset * 2), 0)
        let preferredWidth = min(usableWidth, usableHeight * ScoreboardFaceView.preferredAspectRatio)
        let preferredHeight = min(usableHeight, preferredWidth / ScoreboardFaceView.preferredAspectRatio)
        return CGSize(width: preferredWidth, height: preferredHeight)
    }

    @ViewBuilder
    private func externalBackgroundView(using palette: ThemePalette) -> some View {
        switch store.externalDisplayBackgroundMode {
        case .blurred:
            palette.externalDisplayBackground
        case .clear:
            HStack(spacing: 0) {
                palette.homeAccent
                palette.guestAccent
            }
        case .clearUnderBoard:
            HStack(spacing: 0) {
                palette.homeAccent
                palette.guestAccent
            }
        case .none:
            Color.clear
        }
    }

    private func resolvedBoardBackgroundStyle() -> ScoreboardFaceView.BackgroundStyle {
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
}

#if os(macOS)
private struct PublicBoardWindowConfigurator: NSViewRepresentable {
    let backgroundMode: ExternalDisplayBackgroundMode
    let fullscreenRequestID: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.configureWindowIfNeeded(
                for: view,
                backgroundMode: backgroundMode,
                fullscreenRequestID: fullscreenRequestID
            )
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configureWindowIfNeeded(
                for: nsView,
                backgroundMode: backgroundMode,
                fullscreenRequestID: fullscreenRequestID
            )
        }
    }

    final class Coordinator {
        private var configuredWindowNumbers = Set<Int>()
        private var placedWindowNumbers = Set<Int>()
        private var handledFullscreenRequestIDs = [Int: UUID]()

        func configureWindowIfNeeded(
            for view: NSView,
            backgroundMode: ExternalDisplayBackgroundMode,
            fullscreenRequestID: UUID
        ) {
            guard let window = view.window else {
                return
            }

            if configuredWindowNumbers.insert(window.windowNumber).inserted {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = false
                window.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
            }

            window.isOpaque = backgroundMode != .none
            window.backgroundColor = backgroundMode == .none ? .clear : .black

            if placedWindowNumbers.insert(window.windowNumber).inserted {
                placeWindowOnSecondaryDisplayIfAvailable(window)
            }

            requestFullscreenIfNeeded(window, fullscreenRequestID: fullscreenRequestID)
        }

        private func placeWindowOnSecondaryDisplayIfAvailable(_ window: NSWindow) {
            let screens = NSScreen.screens
            guard screens.count > 1 else {
                return
            }

            let targetScreen = Array(screens.dropFirst()).first ?? screens[1]
            let visibleFrame = targetScreen.visibleFrame
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

        private func requestFullscreenIfNeeded(_ window: NSWindow, fullscreenRequestID: UUID) {
            guard !window.styleMask.contains(.fullScreen) else {
                handledFullscreenRequestIDs[window.windowNumber] = fullscreenRequestID
                return
            }

            guard handledFullscreenRequestIDs[window.windowNumber] != fullscreenRequestID else {
                return
            }

            handledFullscreenRequestIDs[window.windowNumber] = fullscreenRequestID
            DispatchQueue.main.async {
                guard !window.styleMask.contains(.fullScreen) else {
                    return
                }

                window.toggleFullScreen(nil)
            }
        }
    }
}
#endif
