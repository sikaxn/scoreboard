import SwiftUI

struct RemoteSessionHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Start with a scoreboard file").font(.title2.bold())
                    Text("In App Mode, use Home to create a scoreboard, open an existing file, or connect to another host. Your local files work without an account or internet.")
                        .foregroundStyle(.secondary)
                    helpCard("App Mode", icon: "doc.text", tint: .blue,
                        text: "The device that opens the scoreboard file runs the game. Game Settings saves teams, rules, clocks, rosters and presentation in that file. App Settings contains preferences for this device.")
                    helpCard("Kiosk Mode", icon: "display", tint: .orange,
                        text: "Join an existing scoreboard as a display or an approved controller. Kiosks cannot create files or host. Received game data is cleared when disconnected. Apple TV always uses Kiosk Mode.")
                    helpCard("Nearby pairing", icon: "dot.radiowaves.left.and.right", tint: .teal,
                        text: "On the host, open Connect Devices and allow nearby connections. On the joining device, select the discovered scoreboard and enter the host’s pairing PIN or ask the host to confirm. The host can also select a kiosk and enter the device PIN shown on its pairing screen.")
                    helpCard("Cloud code and password", icon: "cloud", tint: .indigo,
                        text: "Only the owner signs in. The host enables online sharing and sets a match password. Other devices join with the session code and password. The code stays fixed for that session. Controllers require approval; public viewing links are read-only.")
                    Text("Connection preferences").font(.title2.bold())
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], alignment: .leading, spacing: 14) {
                        networkCard("LAN Only", icon: "network", path: "Device → Local network → Host",
                            detail: "Use Wi-Fi or Ethernet on the same network. Internet and accounts are not required.")
                        networkCard("LAN + Nearby", icon: "wifi", path: "Device ↔ Nearby host",
                            detail: "Also allows Apple’s nearby peer-to-peer Wi-Fi connection.")
                        networkCard("Cloud preferences", icon: "cloud", path: "Device → Cloud service → Host",
                            detail: "Prefer Cloud or Prefer LAN + Nearby can use a cloud path for the same match. The publishing host and devices using cloud need internet; local devices can stay offline.")
                    }
                    helpCard("Web API and Companion", icon: "point.3.connected.trianglepath.dotted", tint: .purple,
                        text: "These integrations run on the host. Configure them in App Settings. Remote control changes the game on that host; it does not create a separate local game on a kiosk.")
                    helpCard("Local Network permission", icon: "wifi", tint: .cyan,
                        text: "Allow Local Network access for nearby discovery and pairing. If discovery is empty after denying it, enable Smart Scoreboard’s Local Network permission in system Settings.")
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Remote Display & Control Guide")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func helpCard(_ title: String, icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 5) {
                Text(ScoreboardLocalization.string(title)).font(.headline)
                Text(ScoreboardLocalization.string(text)).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func networkCard(_ title: String, icon: String, path: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(ScoreboardLocalization.string(title), systemImage: icon).font(.headline)
            Text(ScoreboardLocalization.string(path)).font(.subheadline.bold()).foregroundStyle(.teal)
            Text(ScoreboardLocalization.string(detail)).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

