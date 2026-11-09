import SwiftUI

private struct ScoreboardCloudConsentOverlay: ViewModifier {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    func body(content: Content) -> some View {
        content.disabled(cloud.cloudConsent != nil).accessibilityHidden(cloud.cloudConsent != nil).overlay {
            if cloud.cloudConsent != nil {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.55).ignoresSafeArea()
                        ScoreboardCloudConsentView()
                            .disabled(false).accessibilityHidden(false)
                            .padding(28)
                            .frame(width: min(geometry.size.width - 32, 980), height: min(geometry.size.height - 32, 850))
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                    }.frame(width: geometry.size.width, height: geometry.size.height)
                }
                .accessibilityAddTraits(.isModal)
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }
}

struct ScoreboardCloudConsentView: View {
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @State private var agrees = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch cloud.cloudConsent {
            case .disclosure:
                Label("Your data will be sent to the cloud", systemImage: "cloud").font(.title2.bold())
                Text("When you host or join through the cloud, account/device information and shared match data—including scores, player details, logos and backgrounds—pass through this service.")
                Text(verbatim: cloud.serviceURL).font(.callout).foregroundStyle(.secondary)
                Text("Continue to fetch and review this service's agreement. Cloud connections begin after you accept it.")
                Spacer(minLength: 0)
                HStack {
                    Button("Cancel", role: .cancel) { cloud.cancelCloudAgreement() }.buttonStyle(.bordered)
                    Spacer()
                    Button("Continue") { cloud.continueCloudDisclosure() }.buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("cloud.consent.continue")
                }
            case .loading:
                ProgressView("Loading cloud agreement…").frame(maxWidth: .infinity, maxHeight: .infinity)
                Button("Cancel", role: .cancel) { cloud.cancelCloudAgreement() }.buttonStyle(.bordered)
            case .agreement(let document):
                Text(document.title).font(.title2.bold())
                Text("Version \(document.version)").font(.headline)
                Text(verbatim: cloud.serviceURL).font(.caption).foregroundStyle(.secondary)
                if document.placeholder {
                    Text("Placeholder policy supplied by the service operator. Some legal details remain to be completed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(document.content.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, block in
                            Text(.init(block)).frame(maxWidth: .infinity, alignment: .leading)
                                #if os(tvOS)
                                .focusable()
                                #else
                                .textSelection(.enabled)
                                #endif
                        }
                    }.padding(16)
                }.background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("cloud.consent.document")
                Toggle("I have read and accept this version of the cloud agreement.", isOn: $agrees)
                    .scoreboardCloudSettingsToggleStyle().accessibilityIdentifier("cloud.consent.agrees")
                if cloud.status.hasPrefix("Unable to record") { Text(cloud.status).font(.caption).foregroundStyle(.orange) }
                HStack {
                    Button("Decline", role: .cancel) { cloud.cancelCloudAgreement() }.buttonStyle(.bordered)
                        .disabled(cloud.acceptingCloudAgreement)
                    Spacer()
                    Button(cloud.acceptingCloudAgreement ? "Saving…" : "Accept and Enable Cloud") {
                        Task { await cloud.acceptCloudAgreement() }
                    }.buttonStyle(.borderedProminent).disabled(!agrees || cloud.acceptingCloudAgreement)
                        .accessibilityIdentifier("cloud.consent.accept")
                }
            case .failed(let message):
                Label("Cloud agreement unavailable", systemImage: "cloud.slash").font(.title2.bold())
                Text(message)
                Text("Local scoreboards and nearby pairing remain available.").foregroundStyle(.secondary)
                Spacer(minLength: 0)
                HStack {
                    Button("Keep Cloud Off", role: .cancel) { cloud.cancelCloudAgreement() }.buttonStyle(.bordered)
                    Spacer()
                    Button("Try Again") { cloud.retryCloudAgreement() }.buttonStyle(.borderedProminent)
                }
            case nil: EmptyView()
            }
        }
        .padding(4)
        .onChange(of: cloud.cloudConsent) { _, _ in agrees = false }
        #if os(tvOS)
        .onExitCommand { if !cloud.acceptingCloudAgreement { cloud.cancelCloudAgreement() } }
        #endif
    }
}

extension View {
    func scoreboardCloudConsentPresentation() -> some View { modifier(ScoreboardCloudConsentOverlay()) }
}
