import SwiftUI

struct ScoreboardCloudSettingsView: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @Environment(\.openURL) private var openURL
    @State private var removesDevice: ScoreboardCloudRegisteredDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ScoreboardCloudSection("Cloud Service") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Cloud Service", selection: $cloud.serviceMode) {
                        Text("Public Cloud (Experimental)").tag(ScoreboardCloudServiceMode.publicCloud)
                        Text("Self-hosted").tag(ScoreboardCloudServiceMode.selfHosted)
                    }
                    .disabled(cloud.isLinked || cloud.isLinking)
                    .accessibilityIdentifier("cloud.serviceMode")
                    if cloud.serviceMode == .publicCloud {
                        Text(ScoreboardCloudEndpoint.publicServiceURL).font(.footnote)
                    } else {
                        TextField("https://your-scoreboard-server.com", text: $cloud.selfHostedURL)
                            .autocorrectionDisabled().disabled(cloud.isLinked || cloud.isLinking)
                            .accessibilityIdentifier("cloud.selfHostedURL")
                    }
                    Text(cloud.status).font(.subheadline).accessibilityIdentifier("cloud.status")
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            ScoreboardCloudSection("Account") {
                VStack(alignment: .leading, spacing: 14) {
                    if cloud.isLinked {
                        if let account = cloud.account {
                            LabeledContent("Account", value: account.name)
                            LabeledContent("Access", value: cloud.isRemoteRegistration ? "Remote Device" : account.role.capitalized)
                        }
                        if !cloud.hasAccountRegistration {
                            Text("This device uses an older session link. Sign out and sign in once to register it to your account.").font(.footnote)
                        }
                        Button("Sign Out This Device", role: .destructive) { cloud.disconnect() }
                    } else if let code = cloud.linkCode {
                        Text(code).font(.title.monospaced())
                        if let url = cloud.verificationURL {
                            ScoreboardPairingQRCode(value: url.absoluteString)
                            #if !os(tvOS)
                            Link("Open Sign-in Page", destination: url)
                            #endif
                        }
                        Text("Sign in on the webpage and authorize this host. You only need to register this device once.")
                        Button("Cancel Linking") { cloud.cancelLink() }
                    } else {
                        Button("Sign In with Browser") { cloud.beginLink() }
                            .disabled(cloud.isLinking).accessibilityIdentifier("cloud.link")
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            if !cloud.isRemoteRegistration {
                ScoreboardCloudSection("This Host") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Host Name", text: $cloud.hostName).autocorrectionDisabled()
                        Toggle("Enable Cloud Hosting", isOn: $cloud.hostingEnabled)
                            .disabled(!cloud.isLinked).accessibilityIdentifier("cloud.hostingEnabled")
                        Text("This device has its own persistent host session. Disabling and enabling publishing keeps the same session ID.")
                            .font(.footnote)
                        if cloud.isHost, let session = cloud.session {
                            LabeledContent("Session", value: session.name)
                            LabeledContent("Session ID", value: session.id)
                        }
                        Button("Save Host Name / Reconnect") { cloud.reconnect() }.disabled(!cloud.isLinked)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                ScoreboardCloudFailoverSettings()
                ScoreboardDevicePairingSection()
                if let session = cloud.session, cloud.isHost {
                    ScoreboardCloudSection("Cloud Control Permissions") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(session.members.filter { $0.role != "host" }) { member in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(member.name)
                                        Text(member.requestedControl ? "Requesting control" : member.role.capitalized).font(.caption)
                                    }
                                    Spacer()
                                    Button(member.role == "controller" ? "Revoke Control" : "Allow Control") {
                                        Task { await cloud.setCloudPermission(memberID: member.id, allowed: member.role != "controller") }
                                    }
                                }
                            }
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if cloud.isLinked {
                    ScoreboardCloudSection("Registered Devices") {
                        VStack(alignment: .leading, spacing: 14) {
                            Button("Refresh Devices") { Task { await cloud.refreshDevices() } }
                            ForEach(cloud.registeredDevices) { device in
                                HStack {
                                    Text(device.name); Spacer()
                                    Text(device.access == "owner" ? "Owner" : "Remote").font(.caption)
                                    Button("Remove", role: .destructive) { removesDevice = device }
                                }
                            }
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("This device is registered for remote display and control. Choose a host in Remote Display / Control Mode.")
            }
        }
        .onChange(of: cloud.verificationURL) { _, url in
            #if !os(tvOS)
            if let url, !cloud.isRemotePairing { openURL(url) }
            #endif
        }
        .task(id: cloud.account?.id) { await cloud.refreshDevices() }
        .confirmationDialog("Remove Registered Device?", isPresented: Binding(get: { removesDevice != nil }, set: { if !$0 { removesDevice = nil } }), titleVisibility: .visible) {
            Button("Remove Device", role: .destructive) {
                if let device = removesDevice { Task { await cloud.revokeDevice(device) } }
                removesDevice = nil
            }
            Button("Cancel", role: .cancel) { removesDevice = nil }
        } message: { Text("This device will lose cloud access and must pair again. Local pairing is managed separately.") }
    }
}

struct ScoreboardCloudFailoverSettings: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    var body: some View {
        ScoreboardCloudSection("Cloud Failover") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Cloud Failover", isOn: $cloud.cloudFailoverEnabled)
                    .accessibilityIdentifier("cloud.failover")
                Text("When cloud hosting is enabled, automatically register authenticated nearby/LAN devices to this account. Existing local control permissions carry over for this host. Remote devices can then choose Prefer LAN + Nearby or Prefer Cloud.")
                    .font(.footnote)
                if cloud.cloudFailoverEnabled && (!cloud.isLinked || !cloud.hostingEnabled) {
                    Text("Sign in and enable Cloud Hosting on the Cloud settings page to prepare failover.").font(.footnote)
                }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
