import SwiftUI
#if os(iOS) || os(macOS)
import TipKit
#endif

@main
struct SmartScoreboardApp: App {
    #if !os(tvOS)
    @StateObject private var store = ScoreboardStore.shared
    @StateObject private var publicBoardState = PublicBoardState.shared
    #endif

    init() {
        #if os(iOS)
        ScoreboardBackgroundCoordinator.shared.register()
        #endif

        #if os(iOS) || os(macOS)
        do {
            try Tips.configure()
        } catch {
            print("Error initializing TipKit \(error.localizedDescription)")
        }
        #endif
    }

    var body: some Scene {
        #if os(tvOS)
        WindowGroup {
            RemoteScoreboardView()
                .reportsSceneActivityForSleepPolicy()
                .reportsExternalDisplaysForSleepPolicy()
        }
        #elseif os(macOS)
        Window("Control Board", id: "control-board") {
            MacControlBoardRootView()
                .environmentObject(store)
                .environmentObject(publicBoardState)
                .reportsSceneActivityForSleepPolicy()
                .reportsExternalDisplaysForSleepPolicy()
                .reportsScoreboardSleepPolicy(store: store, publicBoardState: publicBoardState)
        }
        .defaultSize(width: 1280, height: 820)

        Window("Public Scoreboard", id: "public-scoreboard") {
            MacPublicScoreboardRootView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(store)
                .environmentObject(publicBoardState)
                .onAppear {
                    publicBoardState.isPresented = true
                }
                .onDisappear {
                    publicBoardState.isPresented = false
                }
        }
        .defaultSize(width: 960, height: 540)
        .windowStyle(.hiddenTitleBar)
        #else
        WindowGroup {
            Group {
                if store.isRemoteDisplayViewerModeEnabled {
                    RemoteScoreboardView(exitRemoteDisplayMode: {
                        store.setRemoteDisplayViewerModeEnabled(false)
                    })
                } else {
                    ContentView()
                        .environmentObject(store)
                        .environmentObject(publicBoardState)
                }
            }
            .reportsSceneActivityForSleepPolicy()
            .reportsExternalDisplaysForSleepPolicy()
            .reportsScoreboardSleepPolicy(store: store, publicBoardState: publicBoardState)
        }
        #endif
    }
}

#if os(macOS)
private struct MacControlBoardRootView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.isRemoteDisplayViewerModeEnabled {
            RemoteScoreboardView(
                exitRemoteDisplayMode: {
                    store.setRemoteDisplayViewerModeEnabled(false)
                },
                openScoreboardWindow: {
                    publicBoardState.requestFullscreen()
                    openWindow(id: "public-scoreboard")
                }
            )
        } else {
            ContentView()
                .environmentObject(store)
                .environmentObject(publicBoardState)
        }
    }
}

private struct MacPublicScoreboardRootView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState

    var body: some View {
        if store.isRemoteDisplayViewerModeEnabled {
            RemoteScoreboardView(showsPairingControls: false, usesExternalDisplayDirection: true)
        } else {
            ExternalScoreboardView()
                .environmentObject(store)
                .environmentObject(publicBoardState)
        }
    }
}
#endif
