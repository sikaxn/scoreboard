import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS) || os(macOS)
import TipKit
#endif

@main
struct SmartScoreboardApp: App {
    // Apple TV also owns a runtime when selected as the session host.
    @StateObject private var store = ScoreboardStore.shared
    #if os(macOS)
    @NSApplicationDelegateAdaptor(ScoreboardAppTerminationDelegate.self) private var terminationDelegate
    #endif
    #if !os(tvOS)
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
                .environmentObject(store)
                .reportsSceneActivityForSleepPolicy()
                .reportsExternalDisplaysForSleepPolicy()
        }
        #elseif os(macOS)
        Window("Control Board", id: "control-board") {
            MacControlBoardRootView()
                .environmentObject(store)
                .environmentObject(publicBoardState)
                .onAppear {
                    ScoreboardEasterEggIcon.applyPersistedSystemIcon()
                }
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
                    }, networkMode: store.remoteDisplayNetworkMode, setNetworkMode: {
                        store.setRemoteDisplayNetworkMode($0)
                    })
                } else {
                    ContentView()
                        .environmentObject(store)
                        .environmentObject(publicBoardState)
                }
            }
            #if os(iOS)
            .modifier(ExternalScoreboardSceneAccessory())
            #endif
            .onAppear {
                ScoreboardEasterEggIcon.applyPersistedSystemIcon()
            }
            .reportsSceneActivityForSleepPolicy()
            .reportsExternalDisplaysForSleepPolicy()
            .reportsScoreboardSleepPolicy(store: store, publicBoardState: publicBoardState)
        }
        #endif
    }
}

#if os(macOS)
@MainActor
private final class ScoreboardAppTerminationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let store = ScoreboardStore.shared
        guard store.isDelegatedSessionHost else { return .terminateNow }
        if store.isSessionSafeToDisconnect {
            store.handoffHostedMatchForQuit { success in
                Task { @MainActor in sender.reply(toApplicationShouldTerminate: success) }
            }
            return .terminateLater
        }

        let alert = NSAlert()
        alert.messageText = ScoreboardLocalization.string("This hosted match has not synced to its owner")
        alert.informativeText = ScoreboardLocalization.string("Keep Scoreboard open, reconnect the owner, and wait for Safe to Disconnect. Deleting the local match now can lose unsynced scores and logs.")
        alert.addButton(withTitle: ScoreboardLocalization.string("Keep Hosting and Sync"))
        alert.addButton(withTitle: ScoreboardLocalization.string("Delete Local Match and Quit"))
        return alert.runModal() == .alertSecondButtonReturn && store.deleteHostedMatchAndExitRemoteMode()
            ? .terminateNow : .terminateCancel
    }
}
#endif

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
                },
                networkMode: store.remoteDisplayNetworkMode,
                setNetworkMode: {
                    store.setRemoteDisplayNetworkMode($0)
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
    @ObservedObject private var receiver = ScoreboardRemoteDisplayReceiver.shared

    private var followsRemoteScoreboard: Bool {
        store.isRemoteDisplayViewerModeEnabled || store.isFollowingSessionHost
    }

    var body: some View {
        Group {
            if followsRemoteScoreboard {
                RemoteScoreboardView(
                    networkMode: store.remoteDisplayNetworkMode,
                    setNetworkMode: {
                        store.setRemoteDisplayNetworkMode($0)
                    },
                    showsPairingControls: false,
                    usesExternalDisplayDirection: true
                )
            } else {
                ExternalScoreboardView(configuresPublicWindow: false)
                    .environmentObject(store)
                    .environmentObject(publicBoardState)
            }
        }
        .background {
            PublicBoardWindowConfigurator(
                backgroundMode: followsRemoteScoreboard
                    ? (receiver.state?.display?.backgroundMode ?? .blurred).resolvedForRendering
                    : store.externalDisplayBackgroundMode.resolvedForRendering,
                displayViewMode: followsRemoteScoreboard
                    ? (receiver.state?.display?.viewMode ?? .scoreboard)
                    : store.publicDisplayViewMode,
                fullscreenRequestID: publicBoardState.fullscreenRequestID
            )
        }
    }
}
#endif
