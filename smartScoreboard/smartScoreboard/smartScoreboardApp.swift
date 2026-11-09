import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS) || os(macOS)
import TipKit
#endif

@main
struct SmartScoreboardApp: App {
    // App mode owns documents; kiosk mode only participates in another host's match.
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
            #if DEBUG
            if !ScoreboardUITestLaunch.isEnabled {
                try Tips.configure()
            }
            #else
            try Tips.configure()
            #endif
        } catch {
            print("Error initializing TipKit \(error.localizedDescription)")
        }
        #endif
    }

    var body: some Scene {
        #if os(tvOS)
        WindowGroup {
            ScoreboardWorkspaceView()
                .defaultAppStorage(ScoreboardPreferences.current)
                .environmentObject(store)
                .reportsSceneActivityForSleepPolicy()
                .reportsExternalDisplaysForSleepPolicy()
        }
        #elseif os(macOS)
        Window("Control Board", id: "control-board") {
            ScoreboardWorkspaceView()
                .modifier(ScoreboardInvitationLinkHandler())
                .defaultAppStorage(ScoreboardPreferences.current)
                .scoreboardUITestAnimationPolicy()
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
                .defaultAppStorage(ScoreboardPreferences.current)
                .scoreboardUITestAnimationPolicy()
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
            ScoreboardWorkspaceView()
                .environmentObject(store)
                .environmentObject(publicBoardState)
            .defaultAppStorage(ScoreboardPreferences.current)
            .scoreboardUITestAnimationPolicy()
            #if os(iOS)
            .modifier(ExternalScoreboardSceneAccessory())
            #endif
            .onAppear {
                ScoreboardEasterEggIcon.applyPersistedSystemIcon()
            }
            .reportsSceneActivityForSleepPolicy()
            .reportsExternalDisplaysForSleepPolicy()
            .reportsScoreboardSleepPolicy(store: store, publicBoardState: publicBoardState)
            .modifier(ScoreboardInvitationLinkHandler())
        }
        #endif
    }
}

#if os(macOS)
@MainActor
private final class ScoreboardAppTerminationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let store = ScoreboardStore.shared
        do { try store.matchLibrary.save() }
        catch {
            let alert = NSAlert()
            alert.messageText = ScoreboardLocalization.string("Match could not be saved")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: ScoreboardLocalization.string("Keep Open"))
            alert.runModal()
            return .terminateCancel
        }
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
private struct MacPublicScoreboardRootView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState
    @ObservedObject private var receiver = ScoreboardRemoteDisplayReceiver.shared

    private var followsRemoteScoreboard: Bool {
        store.usesRemoteScoreboardPresentation
    }

    var body: some View {
        Group {
            if store.isShowingFileHome {
                ScoreboardWaitingDisplayView()
            } else if followsRemoteScoreboard {
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

private extension View {
    func scoreboardUITestAnimationPolicy() -> some View {
        transaction { transaction in
            #if DEBUG
            if ScoreboardUITestLaunch.isEnabled {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            #endif
        }
    }
}
