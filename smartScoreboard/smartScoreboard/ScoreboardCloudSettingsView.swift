import SwiftUI

struct ScoreboardCloudSettingsView: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @Environment(\.openURL) private var openURL
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            serviceSection
            accountSection
            if cloud.isRemoteRegistration {
                Text("You are a guest in this match. No account or permanent device registration is required.")
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
    }

    private var serviceSection: some View {
        ScoreboardCloudSection("Cloud Service") {
            ScoreboardCloudSettingsRow("Enable Cloud") { Toggle("Enable Cloud", isOn: $cloud.cloudEnabled).labelsHidden().scoreboardCloudSettingsToggleStyle() }
            ScoreboardCloudSettingsDivider()
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
                    if cloud.hasOwnerAccount {
                        ScoreboardCloudSettingsRow("Cloud Relay") { Text(account.relay?.description ?? "No active cloud relay entitlement") }
                        ScoreboardCloudSettingsDivider()
                        ScoreboardCloudSettingsRow("Account Access") {
                            Button("Refresh Account Access") { Task { await cloud.refreshAccountAccess() } }
                        }
                        ScoreboardCloudSettingsDivider()
                    }
                    ScoreboardCloudSettingsRow("Access") {
                        Text(verbatim: ScoreboardLocalization.string(cloud.isRemoteRegistration ? "Remote Device" : account.role.capitalized))
                    }
                    ScoreboardCloudSettingsDivider()
                }
                if cloud.hasMatchPublishingGrant && !cloud.hasOwnerAccount {
                    Text("This device can publish one match with permission from its owner. It has no access to the owner's account or other matches.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 10)
                    ScoreboardCloudSettingsDivider()
                } else if !cloud.hasAccountRegistration {
                    Text("This device uses an older session link. Sign out and sign in once to register it to your account.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    ScoreboardCloudSettingsDivider()
                }
                ScoreboardCloudSettingsRow("This Device") {
                    Button(cloud.hasOwnerAccount ? "Sign Out This Device" : "Forget Match Access", role: .destructive) { cloud.disconnect() }
                }
            } else if let code = cloud.linkCode {
                ScoreboardCloudSettingsRow("Sign-in Code") { Text(code).font(.title.monospaced()) }
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

}

struct ScoreboardCloudFailoverSettings: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    var body: some View {
        ScoreboardCloudSection("Cloud Failover", footer: "Prepare match-scoped cloud access for trusted LAN and nearby devices. Local control permissions carry over for this match. Guests do not sign in or gain access to other matches. Remote devices can choose Prefer LAN + Nearby or Prefer Cloud.") {
            Toggle("Cloud Failover", isOn: $cloud.cloudFailoverEnabled)
                .padding(.vertical, 10)
                .accessibilityIdentifier("cloud.failover")
            if cloud.cloudFailoverEnabled && (!cloud.isLinked || !cloud.hostingEnabled) {
                ScoreboardCloudSettingsDivider()
                Text("The owner must sign in and share this match online to prepare failover.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
            }
        }
    }
}
