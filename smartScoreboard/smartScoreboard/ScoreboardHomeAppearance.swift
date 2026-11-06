import SwiftUI

/// Uses existing connection state; showing Home never starts cloud requests.
struct ScoreboardHomeStatusView: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @EnvironmentObject private var store: ScoreboardStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var stacked = false
    var fontSize: CGFloat? = nil
    private var version: ScoreboardRemoteDisplayAppVersion { .current }
    private var cloudLabel: String {
        if !store.localConnectionsEnabled && !cloud.cloudEnabled { return "Local Only" }
        if !cloud.cloudEnabled { return "Cloud · Off" }
        if cloud.isLinking { return "Cloud · Signing In" }
        if cloud.isLinked && cloud.session?.enabled == false { return "Cloud · Sharing Paused" }
        if cloud.isConnected {
            if cloud.isPublishingLocalHost { return "Cloud · Sharing Online" }
            if !cloud.isHost && cloud.session?.hostOnline == false { return "Cloud · Waiting for Host" }
            return "Cloud · Connected"
        }
        if cloud.isRemoteRegistration && !store.remoteDisplayNetworkMode.allowsCloud { return "Cloud · Standby" }
        if cloud.hasOwnerAccount && !cloud.hostingEnabled { return "Cloud · Signed In" }
        if cloud.isLinked { return cloud.status.hasPrefix("Connecting") ? "Cloud · Connecting" : "Cloud · Disconnected" }
        return ScoreboardDeviceMode.current == .kiosk ? "Cloud · Ready to Join" : "Cloud · Not Signed In"
    }
    private var statusColor: Color {
        if !store.localConnectionsEnabled && !cloud.cloudEnabled { return .secondary }
        if !cloud.cloudEnabled { return .secondary }
        if cloud.isLinking || (cloud.isLinked && cloud.session?.enabled == false) { return .orange }
        if cloud.isConnected { return !cloud.isHost && cloud.session?.hostOnline == false ? .orange : .green }
        if cloud.isRemoteRegistration && !store.remoteDisplayNetworkMode.allowsCloud { return .blue }
        return cloud.isLinked && !(cloud.hasOwnerAccount && !cloud.hostingEnabled) ? .orange : .blue
    }
    private var serviceLabel: String {
        if cloud.serviceMode == .publicCloud { return "Public Cloud (Experimental)" }
        let host = URLComponents(string: cloud.serviceURL)?.host
        return host.map { "Self-hosted · \($0)" } ?? "Self-hosted · Set Server URL"
    }
    var body: some View {
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: 8) { versionLabel; cloudStatus }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 24) { versionLabel; Spacer(minLength: 8); cloudStatus }
                    VStack(alignment: .leading, spacing: 10) { versionLabel; cloudStatus }
                }
            }
        }.font(fontSize.map { .system(size: $0) } ?? .caption)
    }
    private var versionLabel: some View {
        Text("Version \(version.version) · Build \(version.build)")
            .foregroundStyle(.secondary).accessibilityIdentifier("home.version")
    }
    private var cloudStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8).accessibilityHidden(true)
                Text(cloudLabel).contentTransition(.opacity).accessibilityIdentifier("home.cloudStatus")
            }
            Text(serviceLabel).foregroundStyle(.secondary).font(fontSize.map { .system(size: max(12, $0 - 2)) } ?? .caption2)
                .lineLimit(2).accessibilityIdentifier("home.cloudService")
        }.help(cloud.status).accessibilityHint(cloud.status)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: cloudLabel)
    }
}

private struct ScoreboardHomeEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let order: Int
    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.88).delay(Double(order) * 0.045)) {
                    appeared = true
                }
            }
    }
}

struct ScoreboardHomeButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    @State private var hovered = false
    var hoverEffect = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !enabled ? 1 : configuration.isPressed ? 0.975 : hovered ? 1.015 : 1)
            .shadow(color: .black.opacity(hovered && enabled ? 0.09 : 0), radius: 12, y: 5)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: hovered)
            #if !os(tvOS)
            .onHover { if hoverEffect { hovered = $0 } }
            #endif
    }
}

extension View {
    func scoreboardHomeEntrance(order: Int = 0) -> some View { modifier(ScoreboardHomeEntrance(order: order)) }
}
