import SwiftUI

struct ScoreboardLocalConnectionsToggle: View {
    @EnvironmentObject private var store: ScoreboardStore
    @State private var error: String?
    var body: some View {
        ScoreboardCloudSection("LAN & Nearby", footer: "Allow pairing and connections on your local network or nearby Wi-Fi, including local Web API and Companion. Cloud access is controlled separately below. Turn both off for a completely local scoreboard.") {
            Toggle("Enable LAN & Nearby", isOn: Binding(get: { store.localConnectionsEnabled }, set: { enabled in
                do { try store.setLocalConnectionsEnabled(enabled) }
                catch { self.error = error.localizedDescription }
            }))
                .scoreboardCloudSettingsToggleStyle().padding(.vertical, 12)
                .accessibilityIdentifier("connections.localEnabled")
            if !store.localConnectionsEnabled {
                Text("LAN and nearby connections are off. Cloud can still be used independently.").foregroundStyle(.secondary).padding(.bottom, 12)
            }
        }
        .alert("Unable to Change LAN & Nearby", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct ScoreboardSoftwareGeneralSettingsView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @State private var requestedMode: ScoreboardDeviceMode?
    @State private var error: String?
    var body: some View {
        ScoreboardCloudSection("Device Mode", footer: "App Mode creates and opens local scoreboard files. Kiosk Mode joins an existing scoreboard as a display or controller and clears received data when disconnected.") {
            Text(ScoreboardDeviceMode.current.title).font(.headline).padding(.vertical, 12)
            #if os(tvOS)
            Text("Apple TV runs in Kiosk Mode.").foregroundStyle(.secondary)
            #else
            Button(ScoreboardDeviceMode.current == .app ? "Switch to Kiosk Mode" : "Switch to App Mode") {
                requestedMode = ScoreboardDeviceMode.current == .app ? .kiosk : .app
            }.buttonStyle(.bordered).padding(.vertical, 12)
            #endif
        }
        .confirmationDialog("Change Device Mode?", isPresented: Binding(get: { requestedMode != nil }, set: { if !$0 { requestedMode = nil } }), titleVisibility: .visible) {
            Button("Switch Mode") {
                if let mode = requestedMode {
                    do { try store.setDeviceMode(mode); ScoreboardAppNavigation.shared.goHome() }
                    catch { self.error = error.localizedDescription }
                }
                requestedMode = nil
            }
        }
        .alert("Unable to Change Mode", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct ScoreboardConnectionPreferencesView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @State private var showsGuide = false
    var body: some View {
        ScoreboardCloudSection("Preferred Route", footer: "Available routes follow the LAN/nearby and cloud switches. LAN and nearby do not need internet.") {
            if store.availableConnectionModes.isEmpty {
                Label("Local Only", systemImage: "internaldrive").padding(.vertical, 12)
            } else if store.availableConnectionModes.count == 1 {
                Text(store.remoteDisplayNetworkMode.title).padding(.vertical, 12).accessibilityIdentifier("connections.preference")
            } else {
            Picker("Preferred Connection", selection: Binding(get: { store.remoteDisplayNetworkMode }, set: store.setRemoteDisplayNetworkMode)) {
                ForEach(store.availableConnectionModes) { Text($0.title).tag($0) }
            }.pickerStyle(.menu).padding(.vertical, 12).accessibilityIdentifier("connections.preference")
            }
            if !store.availableConnectionModes.isEmpty {
                Text(store.remoteDisplayNetworkMode.detail).font(.callout).foregroundStyle(.secondary).padding(.bottom, 12)
            }
            Button("Connection Guide", systemImage: "questionmark.circle") { showsGuide = true }.padding(.bottom, 12)
        }.sheet(isPresented: $showsGuide) { RemoteSessionHelpView() }
    }
}
