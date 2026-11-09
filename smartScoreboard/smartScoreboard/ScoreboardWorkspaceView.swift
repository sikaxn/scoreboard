import SwiftUI

/// Shared in-app brand asset; the neighboring title supplies its accessible name.
struct ScoreboardLogoView: View {
    var size: CGFloat = 64
    var body: some View {
        Image("ScoreboardIcon").resizable().scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ScoreboardWorkspaceView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @ObservedObject private var navigation = ScoreboardAppNavigation.shared
    @AppStorage(ScoreboardDeviceMode.preferenceKey, store: ScoreboardPreferences.current) private var mode = "app"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var startupError: String?

    private var kiosk: Bool { ScoreboardDeviceMode.current == .kiosk }
    var body: some View {
        ZStack {
            workspace
                .opacity(navigation.destination == .settings ? 0 : 1)
                .allowsHitTesting(navigation.destination != .settings)
                .accessibilityHidden(navigation.destination == .settings)
            #if !os(tvOS)
            if navigation.destination == .settings {
                ContentView(startsInSettings: true, initialSettingsSection: navigation.settingsSection, softwareSettings: true)
                    .id("app-settings").transition(.opacity)
            }
            #endif
        }
        .id(mode)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: navigation.destination == .settings)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: mode)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: navigation.boardOpen)
        .scoreboardNearbyJoinNotifications()
        .task(id: mode) {
            guard !kiosk else {
                if !store.isDelegatedSessionHost { store.setRemoteDisplayHostEnabled(false) }
                return
            }
            do {
                _ = try await ScoreboardFileStorage.migrateLegacyFilesToUserVisibleStorage()
                try store.matchLibrary.start()
                if !navigation.boardOpen && !store.matchWorkspace.presentsSharedMatch { try store.prepareForFileHome() }
            } catch { startupError = error.localizedDescription }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { store.matchLibrary.saveAfterChange() }
        }
        .background { ScoreboardExternalPresentationMonitor() }
        .onChange(of: store.isJoinedMatchActive) { _, joined in
            store.isShowingFileHome = !joined && !navigation.boardOpen
            if joined { navigation.destination = nil }
        }
        #if !os(tvOS)
        .sheet(item: Binding(get: { navigation.destination == .settings ? nil : navigation.destination }, set: {
            if navigation.destination != .settings { navigation.destination = $0 }
        }), onDismiss: navigation.didDismiss) { destination in
            Group {
                switch destination {
                case .join:
                    ScoreboardJoinMatchView(initialInvitation: navigation.invitation, nearbyInvitation: navigation.nearbyInvitation)
                case .sharing:
                    ScoreboardConnectionSheet()
                case .settings, .library: EmptyView()
                }
            }
            .environmentObject(store).environmentObject(PublicBoardState.shared)
            .scoreboardNearbyJoinNotifications()
            .defaultAppStorage(ScoreboardPreferences.current)
            .frame(minWidth: 320, idealWidth: 1000, minHeight: 550)
        }
        #endif
        .alert("Unable to Open Scoreboard", isPresented: Binding(get: { startupError != nil || navigation.fileImportError != nil },
            set: { if !$0 { startupError = nil; navigation.fileImportError = nil } })) {
                Button("OK") { startupError = nil; navigation.fileImportError = nil }
        } message: { Text(startupError ?? navigation.fileImportError ?? "") }
    }
    @ViewBuilder private var workspace: some View {
        if kiosk || store.matchWorkspace.presentsSharedMatch {
            remoteView.transition(.opacity)
        } else {
            #if !os(tvOS)
            if navigation.boardOpen {
                ContentView(startsInSettings: navigation.startsInSetup, returnHome: navigation.goHome).transition(.opacity)
            } else {
                ScoreboardMatchLibraryView().transition(.opacity)
            }
            #endif
        }
    }
    @ViewBuilder private var remoteView: some View {
        #if os(macOS)
        RemoteScoreboardView(exitRemoteDisplayMode: leave,
            openScoreboardWindow: { PublicBoardState.shared.requestFullscreen(); openWindow(id: "public-scoreboard") },
            networkMode: store.remoteDisplayNetworkMode, setNetworkMode: { store.setRemoteDisplayNetworkMode($0) })
        #else
        RemoteScoreboardView(exitRemoteDisplayMode: leave,
            networkMode: store.remoteDisplayNetworkMode, setNetworkMode: { store.setRemoteDisplayNetworkMode($0) })
        #endif
    }
    private func leave() {
        store.leaveJoinedMatch()
        if !store.isRemoteDisplayViewerModeEnabled { navigation.goHome() }
    }
}

/// Observe rapidly changing receiver state without rebuilding the file/control-board root.
private struct ScoreboardExternalPresentationMonitor: View {
    @ObservedObject private var local = ScoreboardRemoteDisplayReceiver.shared
    @ObservedObject private var cloud = ScoreboardCloudClient.shared.receiver
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onChange(of: local.state != nil) { _, _ in update() }
            .onChange(of: cloud.state != nil) { _, _ in update() }
    }
    private func update() {
        let store = ScoreboardStore.shared
        guard ScoreboardDeviceMode.current == .kiosk || store.isJoinedMatchActive else { return }
        let home = local.state == nil && cloud.state == nil
        if store.isShowingFileHome != home { store.isShowingFileHome = home }
    }
}

/// Used by HDMI/AirPlay and the separate public window while the operator is on Home.
struct ScoreboardWaitingDisplayView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.035, green: 0.055, blue: 0.10)
                VStack(spacing: 24) {
                    ScoreboardLogoView(size: min(96, geometry.size.width * 0.10))
                    Text("Smart Scoreboard").font(.system(size: min(48, geometry.size.width * 0.045), weight: .bold))
                    Text("Start or join a scoreboard on your main device.")
                        .font(.system(size: min(30, geometry.size.width * 0.03)))
                        .foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center)
                }.padding(48).foregroundStyle(.white)
            }
        }.ignoresSafeArea().accessibilityIdentifier("external.waitingForMatch")
    }
}

#if !os(tvOS)
struct ScoreboardConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ScoreboardStore
    @ObservedObject private var router = ScoreboardRemoteConnectionRouter.shared
    var receiver: ScoreboardRemoteDisplayReceiver? = nil
    var returnToRemoteControl: (() -> Void)? = nil
    private var activeReceiver: ScoreboardRemoteDisplayReceiver { receiver ?? router.receiver }
    private var isParticipant: Bool { store.isJoinedMatchActive || store.isRemoteControlProxy || store.isFollowingSessionHost }
    var body: some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            connectionContent.presentationSizing(.page)
        } else {
            connectionContent
        }
        #else
        connectionContent.frame(minWidth: 320, idealWidth: 1100, minHeight: 550, idealHeight: 760)
        #endif
    }
    private var connectionContent: some View {
        NavigationStack {
            GeometryReader { geometry in
            ScrollView {
                if isParticipant {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(activeReceiver.state.map { "\($0.teams.home.name) vs \($0.teams.guest.name)" } ?? "Waiting for scoreboard")
                            .font(.title.bold())
                        ScoreboardConnectionOverviewSection(receiver: activeReceiver)
                        ScoreboardConnectedDevicesSection(receiver: activeReceiver)
                        Text("Scores and timers stay with the host. Leaving returns this device to Home.").foregroundStyle(.secondary)
                        Picker("Connection", selection: Binding(get: { store.remoteDisplayNetworkMode }, set: store.setRemoteDisplayNetworkMode)) {
                            ForEach(store.availableConnectionModes) { Text($0.title).tag($0) }
                        }
                        ScoreboardSessionRecoveryControls()
                        Button("LAN & Cloud Settings") { dismiss(); ScoreboardAppNavigation.shared.openSettings("cloud") }
                            .accessibilityIdentifier("connection.settings")
                        if store.isJoinedMatchActive {
                            Button("Leave Scoreboard", role: .destructive) { store.leaveJoinedMatch(); ScoreboardAppNavigation.shared.goHome(); dismiss() }
                        }
                        if let returnToRemoteControl {
                            Button("Return to Remote Control") { dismiss(); returnToRemoteControl() }
                        }
                    }.padding(24)
                } else { ScoreboardHostConnectionsView(receiver: activeReceiver, wideLayout: geometry.size.width >= 900).padding(24) }
            }.accessibilityIdentifier("connection.status").navigationTitle("Connect Devices")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("connection.done") } }
            }
        }
    }
}
#endif
