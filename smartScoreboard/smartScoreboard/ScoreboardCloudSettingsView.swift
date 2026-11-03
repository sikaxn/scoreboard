import SwiftUI

struct ScoreboardCloudSettingsView: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @Environment(\.openURL) private var openURL
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var removesDevice: ScoreboardCloudRegisteredDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            serviceSection
            accountSection
            if !cloud.isRemoteRegistration {
                hostSection
                ScoreboardCloudFailoverSettings()
                ScoreboardDevicePairingSection()
                permissionsSection
                if cloud.isLinked { devicesSection }
            } else {
                Text("This device is registered for remote display and control. Choose a host in Remote Display / Control Mode.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private var serviceSection: some View {
        ScoreboardCloudSection("Cloud Service") {
            ScoreboardCloudSettingsRow("Cloud Service") {
                servicePicker
                    .disabled(cloud.isLinked || cloud.isLinking)
                    .accessibilityIdentifier("cloud.serviceMode")
            }
            ScoreboardCloudSettingsDivider()
            ScoreboardCloudSettingsRow("Service URL") {
                if cloud.serviceMode == .publicCloud {
                    Text(verbatim: ScoreboardCloudEndpoint.publicServiceURL)
                } else {
                    TextField("https://your-scoreboard-server.com", text: $cloud.selfHostedURL)
                        .autocorrectionDisabled()
                        .scoreboardCloudSettingsField()
                        .disabled(cloud.isLinked || cloud.isLinking)
                        .accessibilityIdentifier("cloud.selfHostedURL")
                }
            }
            ScoreboardCloudSettingsDivider()
            ScoreboardCloudSettingsRow("Status") {
                Text(cloud.status)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cloud.status")
            }
        }
    }

    @ViewBuilder
    private var servicePicker: some View {
        let picker = Picker("Cloud Service", selection: $cloud.serviceMode) {
            Text("Public Cloud (Experimental)").tag(ScoreboardCloudServiceMode.publicCloud)
            Text("Self-hosted").tag(ScoreboardCloudServiceMode.selfHosted)
        }.labelsHidden()
        #if os(iOS)
        if horizontalSizeClass == .compact { picker.pickerStyle(.menu) }
        else { picker.pickerStyle(.segmented) }
        #else
        picker.pickerStyle(.segmented)
        #endif
    }

    private var accountSection: some View {
        ScoreboardCloudSection("Account") {
            if cloud.isLinked {
                if let account = cloud.account {
                    ScoreboardCloudSettingsRow("Account") { Text(verbatim: account.name) }
                    ScoreboardCloudSettingsDivider()
                    ScoreboardCloudSettingsRow("Access") {
                        Text(verbatim: ScoreboardLocalization.string(cloud.isRemoteRegistration ? "Remote Device" : account.role.capitalized))
                    }
                    ScoreboardCloudSettingsDivider()
                }
                if !cloud.hasAccountRegistration {
                    Text("This device uses an older session link. Sign out and sign in once to register it to your account.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    ScoreboardCloudSettingsDivider()
                }
                ScoreboardCloudSettingsRow("This Device") {
                    Button("Sign Out This Device", role: .destructive) { cloud.disconnect() }
                }
            } else if let code = cloud.linkCode {
                ScoreboardCloudSettingsRow("Pairing Code") { Text(code).font(.title.monospaced()) }
                ScoreboardCloudSettingsDivider()
                if let url = cloud.verificationURL {
                    ScoreboardCloudSettingsRow("Sign In with Browser") {
                        VStack(alignment: .leading, spacing: 14) {
                            ScoreboardPairingQRCode(value: url.absoluteString)
                            #if !os(tvOS)
                            Link("Open Sign-in Page", destination: url)
                            #endif
                        }
                    }
                    ScoreboardCloudSettingsDivider()
                }
                Text("Sign in on the webpage and authorize this host. You only need to register this device once.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                ScoreboardCloudSettingsDivider()
                ScoreboardCloudSettingsRow("Account") {
                    Button("Cancel Linking") { cloud.cancelLink() }
                }
            } else {
                ScoreboardCloudSettingsRow("Account") {
                    Button("Sign In with Browser") { cloud.beginLink() }
                        .disabled(cloud.isLinking).accessibilityIdentifier("cloud.link")
                }
            }
        }
    }

    private var hostSection: some View {
        ScoreboardCloudSection("This Host", footer: "This device has its own persistent host session. Disabling and enabling publishing keeps the same session ID.") {
            ScoreboardCloudSettingsRow("Host Name") {
                TextField("Host Name", text: $cloud.hostName)
                    .autocorrectionDisabled().scoreboardCloudSettingsField()
            }
            ScoreboardCloudSettingsDivider()
            Toggle("Enable Cloud Hosting", isOn: $cloud.hostingEnabled)
                .padding(.vertical, 10)
                .disabled(!cloud.isLinked).accessibilityIdentifier("cloud.hostingEnabled")
            if cloud.isHost, let session = cloud.session {
                ScoreboardCloudSettingsDivider()
                ScoreboardCloudSettingsRow("Session") { Text(verbatim: session.name) }
                ScoreboardCloudSettingsDivider()
                ScoreboardCloudSettingsRow("Session ID") { Text(session.id).monospaced() }
            }
            ScoreboardCloudSettingsDivider()
            ScoreboardCloudSettingsRow("Cloud Session") {
                Button("Save Host Name / Reconnect") { cloud.reconnect() }.disabled(!cloud.isLinked)
            }
        }
    }

    @ViewBuilder
    private var permissionsSection: some View {
        if let session = cloud.session, cloud.isHost {
            let members = session.members.filter { $0.role != "host" }
            ScoreboardCloudSection("Cloud Control Permissions") {
                ForEach(members) { member in
                    if member.id != members.first?.id { ScoreboardCloudSettingsDivider() }
                    ScoreboardCloudSettingsRow(member.name,
                        detail: [member.requestedControl ? "Requesting control" : member.role.capitalized,
                                 member.connected == false ? "Disconnected" : member.connectionStatus?.scoped(to: session.hostLocalID).summary]
                            .compactMap { $0 }.joined(separator: " · "), verbatim: true) {
                        Button(member.role == "controller" ? "Revoke Control" : "Allow Control") {
                            Task { await cloud.setCloudPermission(memberID: member.id, allowed: member.role != "controller") }
                        }
                    }
                }
            }
        }
    }

    private var devicesSection: some View {
        ScoreboardCloudSection("Registered Devices") {
            ScoreboardCloudSettingsRow("Registered Devices") {
                Button("Refresh Devices") { Task { await cloud.refreshDevices() } }
            }
            ForEach(cloud.registeredDevices) { device in
                ScoreboardCloudSettingsDivider()
                ScoreboardCloudSettingsRow(device.name, detail: device.access == "owner" ? "Owner" : "Remote", verbatim: true) {
                    Button("Remove", role: .destructive) { removesDevice = device }
                }
            }
        }
    }
}

struct ScoreboardCloudFailoverSettings: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    var body: some View {
        ScoreboardCloudSection("Cloud Failover", footer: "When cloud hosting is enabled, automatically register authenticated nearby/LAN devices to this account. Existing local control permissions carry over for this host. Remote devices can then choose Prefer LAN + Nearby or Prefer Cloud.") {
            Toggle("Cloud Failover", isOn: $cloud.cloudFailoverEnabled)
                .padding(.vertical, 10)
                .accessibilityIdentifier("cloud.failover")
            if cloud.cloudFailoverEnabled && (!cloud.isLinked || !cloud.hostingEnabled) {
                ScoreboardCloudSettingsDivider()
                Text("Sign in and enable Cloud Hosting on the Cloud settings page to prepare failover.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
            }
        }
    }
}
