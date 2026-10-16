import SwiftUI

struct RemoteSessionHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Example: a basketball game with three public screens")
                        .font(.title2.bold())
                    Text("This is one possible setup. Remote Display & Control works with every supported sport and different numbers of screens and control boards. In this basketball example, one screen sits behind each basket and a master screen sits at midcourt. The owner starts the match, then chooses a reliable paired device as the host. Every screen and control board follows that host.")
                        .foregroundStyle(.secondary)

                    Image(ScoreboardLocalization.usesSimplifiedChinese ? "RemoteSessionCourtChinese" : "RemoteSessionCourt")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Basketball court diagram: left basket, master, and right basket screens, the owner tablet, and a separate control board all connect to the Ethernet Apple TV host. Web API and Companion run on the host.")

                    helpCard("Owner", icon: "ipad", tint: .blue,
                        text: "The owner sets up the game and starts pairing. It keeps the match file and integration settings, grants control to each paired device, and chooses the session host. It can go offline after assigning a host; the host and other control boards keep the game running.")
                    helpCard("Host", icon: "server.rack", tint: .indigo,
                        text: "Exactly one paired device runs scores, clocks, sounds, logs, Web API, and Bitfocus Companion. An Ethernet-connected Apple TV or Mac is a useful choice. The host keeps an isolated working copy until the owner saves the match or another host accepts the handoff.")
                    helpCard("Control board", icon: "hand.tap", tint: .teal,
                        text: "An approved iPhone, iPad, or Mac uses the normal control board, including players and display controls. It can also show a remote display. Apple TV can display and host, but has no control board.")
                    helpCard("Remote displays", icon: "display.2", tint: .orange,
                        text: "The basket screens and master screen show the same live match. They reconnect to the selected host after a handoff; each screen can keep its own display direction and layout.")

                    Text("How devices connect")
                        .font(.title2.bold())
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)],
                              alignment: .leading, spacing: 14) {
                        networkCard("LAN Only", icon: "network", path: "Device → Wi-Fi or Ethernet network → Host",
                            detail: "Use when all devices share the same local network. An Ethernet host can serve wireless screens and control boards on that LAN.")
                        networkCard("Nearby / peer-to-peer", icon: "dot.radiowaves.left.and.right", path: "Device ↔ nearby Host",
                            detail: "Allows Apple's direct nearby Wi-Fi path as well as the LAN. It can work without a separate router, but range and interference still matter.")
                    }

                    helpCard("Web API and Companion", icon: "point.3.connected.trianglepath.dotted", tint: .purple,
                        text: "Both come from the host, at the host IP shown in Integration settings. Browser clients should use that IP. Companion commands fire once from the host, even if several control boards are connected.")
                    helpCard("Safe to Disconnect", icon: "checkmark.shield", tint: .green,
                        text: "This appears on the owner's control board and connected display when every timer is stopped and the owner has confirmed that the latest match file and log were saved. If it says sync pending, keep the host open or reconnect the owner. Leaving a host while unsynced offers an explicit delete choice. Apple TV can lose its local working copy after Scoreboard closes, so reconnect the owner and wait for Safe to Disconnect before leaving the app.")
                    helpCard("If the host is gone", icon: "arrow.uturn.backward.circle", tint: .red,
                        text: "On the owner's Remote Display & Control settings, Recover Here starts hosting from the last match copy the owner saved. Changes made after that copy may be lost, and all timers restart paused. If the old host returns, discard its local match before reconnecting it. A delegated host can discard its isolated match and log from its pairing screen.")
                    helpCard("Local Network permission", icon: "wifi", tint: .cyan,
                        text: "On iPhone, iPad, or Apple TV, the system may ask for Local Network access when Remote Display starts. Allow it for pairing and discovery. If pairing stays empty after denying it, enable Scoreboard's Local Network permission in the device's Settings, then return to the app.")

                    Text("Quick setup: enable Remote Display / Control pairing on the owner, allow Local Network access on each device, enter each device's pairing code, grant control per device, then choose Make Session Host. Watch the connection and sync status before powering anything down.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

