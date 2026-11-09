import SwiftUI
import Combine

nonisolated enum ScoreboardMatchDestination: String, Identifiable {
    case library, join, sharing, settings
    var id: String { rawValue }
}
nonisolated enum ScoreboardHomeTab: String, CaseIterable, Identifiable {
    case open, new, connect
    var id: String { rawValue }
    var title: String { switch self { case .open: "Open Scoreboard"; case .new: "New Scoreboard"; case .connect: "Connect to Scoreboard" } }
    var symbol: String { switch self { case .open: "folder"; case .new: "plus"; case .connect: "person.2" } }
}

/// Home owns file navigation. A received scoreboard never becomes a local document.
@MainActor final class ScoreboardAppNavigation: ObservableObject {
    static let shared = ScoreboardAppNavigation()
    @Published var destination: ScoreboardMatchDestination?
    @Published var boardOpen = false
    @Published var startsInSetup = false
    @Published var homeTab: ScoreboardHomeTab = .open
    @Published var fileImportError: String?
    var settingsSection = "general"
    var invitation: ScoreboardMatchInvitation?
    var nearbyInvitation: ScoreboardNearbyInvitation?

    func open(_ destination: ScoreboardMatchDestination) {
        if destination == .library { goHome(); return }
        if destination == .join, ScoreboardDeviceMode.current == .app {
            goHome()
            guard !boardOpen else { return }
            homeTab = .connect
            return
        }
        self.destination = destination
    }
    func openBoard(setup: Bool = false) {
        startsInSetup = setup; boardOpen = true
        let store = ScoreboardStore.shared
        store.resumeOpenMatchConnections()
        ScoreboardNearbyMatchService.shared.update(owner: store)
        destination = nil
    }
    func goHome() {
        do { try ScoreboardStore.shared.prepareForFileHome() }
        catch { fileImportError = error.localizedDescription; return }
        boardOpen = false; homeTab = .open; ScoreboardStore.shared.isShowingFileHome = true
        destination = nil
    }
    func openSettings(_ section: String) { settingsSection = section; destination = .settings }
    func openInvitation(_ url: URL) {
        if url.isFileURL, url.pathExtension.lowercased() == "scoreboardgame" {
            guard ScoreboardDeviceMode.current.canCreateScoreboards else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let library = ScoreboardStore.shared.matchLibrary
                try library.start(); try library.importCopy(url)
                goHome()
            } catch { fileImportError = error.localizedDescription }
            return
        }
        invitation = ScoreboardMatchInvitation.parse(url.absoluteString)
        nearbyInvitation = ScoreboardNearbyInvitation.parse(url.absoluteString)
        if invitation != nil || nearbyInvitation != nil { open(.join) }
    }
    func didDismiss() { invitation = nil; nearbyInvitation = nil }
}

struct ScoreboardInvitationLinkHandler: ViewModifier {
    func body(content: Content) -> some View {
        content.onOpenURL { ScoreboardAppNavigation.shared.openInvitation($0) }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { ScoreboardAppNavigation.shared.openInvitation(url) }
            }
    }
}

struct ScoreboardMatchSaveStatus: View {
    @ObservedObject var library: ScoreboardMatchRepository
    var body: some View {
        if let error = library.saveError {
            VStack(alignment: .leading, spacing: 8) {
                Label("Scoreboard could not be saved", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(error).font(.callout)
                Button("Retry Save") { library.saveAfterChange() }
            }
        } else if library.lastSavedAt != nil {
            Label("Saved on this device", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
        }
    }
}
