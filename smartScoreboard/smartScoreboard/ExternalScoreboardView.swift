import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ExternalScoreboardView: View {
    @EnvironmentObject private var store: ScoreboardStore

    var body: some View {
        GeometryReader { proxy in
            let displaySize = proxy.size
            let boardSize = fittedBoardSize(in: displaySize)
            let usesCompactBoard = boardSize.width < 1320 || boardSize.height < 760

            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScoreboardFaceView(
                    homeTeamName: store.homeTeamName,
                    guestTeamName: store.guestTeamName,
                    homeScore: store.homeScore,
                    guestScore: store.guestScore,
                    period: store.period,
                    formattedClock: store.formattedClock,
                    isClockRunning: store.isClockRunning,
                    compact: usesCompactBoard
                )
                .frame(width: boardSize.width, height: boardSize.height)
                .clipped()
                .position(x: displaySize.width / 2, y: displaySize.height / 2)
            }
            .frame(width: displaySize.width, height: displaySize.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        #if os(macOS)
        .background(PublicBoardWindowConfigurator())
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
}

#if os(macOS)
private struct PublicBoardWindowConfigurator: NSViewRepresentable {
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

    final class Coordinator {
        private var configuredWindowNumbers = Set<Int>()
        private var fullscreenRequestedWindowNumbers = Set<Int>()

        func configureWindowIfNeeded(for view: NSView) {
            guard let window = view.window else {
                return
            }

            if configuredWindowNumbers.insert(window.windowNumber).inserted {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = false
                window.backgroundColor = .black
                window.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            }

            guard fullscreenRequestedWindowNumbers.insert(window.windowNumber).inserted else {
                return
            }

            if let screen = window.screen {
                window.setFrame(screen.frame, display: true)
            }

            guard !window.styleMask.contains(.fullScreen) else {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard window.isVisible, !window.styleMask.contains(.fullScreen) else {
                    return
                }

                window.toggleFullScreen(nil)
            }
        }
    }
}
#endif
