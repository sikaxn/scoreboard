import SwiftUI

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
    @State private var showsGuide = false
    var body: some View {
        ScoreboardCloudSection("Connection Preferences", footer: "Nearby and LAN work without internet. Cloud preferences require cloud access on the host and this device.") {
            Picker("Preferred Connection", selection: Binding(get: { store.remoteDisplayNetworkMode }, set: store.setRemoteDisplayNetworkMode)) {
                ForEach(ScoreboardRemoteDisplayNetworkMode.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.menu).padding(.vertical, 12)
            Text(store.remoteDisplayNetworkMode.detail).font(.callout).foregroundStyle(.secondary).padding(.bottom, 12)
            Button("Connection Guide", systemImage: "questionmark.circle") { showsGuide = true }.padding(.bottom, 12)
        }.sheet(isPresented: $showsGuide) { RemoteSessionHelpView() }
    }
}
