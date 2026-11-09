import SwiftUI
#if !os(tvOS)
import UniformTypeIdentifiers

/// The app starts here. Choosing a document is separate from operating it.
struct ScoreboardMatchLibraryView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    private var compactHeader: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }
    @ObservedObject private var navigation = ScoreboardAppNavigation.shared
    @ObservedObject private var library = ScoreboardStore.shared.matchLibrary
    @ObservedObject private var cloud = ScoreboardCloudClient.shared
    @State private var showsAppMenu = false
    @State private var imports = false
    @State private var searches = false
    @State private var query = ""
    @State private var error: String?
    @State private var renamed: ScoreboardLibraryEntry?
    @State private var rename = ""
    @State private var actionsEntryID: String?
    @State private var deleting: ScoreboardLibraryEntry?
    @State private var confirmsKiosk = false
    @FocusState private var searchFocused: Bool
    private var palette: SettingsPalette { store.theme.palette.settingsPalette(for: store.theme, colorScheme: colorScheme) }
    private var entries: [ScoreboardLibraryEntry] {
        library.entries.filter { query.isEmpty || "\($0.title) \($0.home) \($0.guest)".localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header.padding(.horizontal, compactHeader ? 20 : 32).padding(.top, 24)
                ScoreboardHomeStatusView().padding(.horizontal, compactHeader ? 20 : 32).padding(.vertical, 16)
                HStack(spacing: 4) {
                    ForEach(ScoreboardHomeTab.allCases) { tab in
                        Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { navigation.homeTab = tab } } label: {
                            VStack(spacing: 12) {
                                HStack(spacing: 9) {
                                    Image(systemName: tab.symbol).font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(.white).frame(width: 36, height: 36)
                                        .background(tab == .open ? Color.blue : tab == .new ? Color.orange : Color.teal,
                                            in: RoundedRectangle(cornerRadius: 10))
                                        .accessibilityHidden(true)
                                    Text(LocalizedStringKey(compactHeader ? tab.rawValue.capitalized : tab.title)).font(.headline)
                                }.frame(maxWidth: .infinity).padding(.top, 10)
                                Capsule().fill(navigation.homeTab == tab ? palette.accent : .clear).frame(height: 3)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .foregroundStyle(navigation.homeTab == tab ? palette.accent : palette.secondaryText)
                            .accessibilityAddTraits(navigation.homeTab == tab ? .isSelected : [])
                            .accessibilityIdentifier(tab == .open ? "home.tab.open" : tab == .new ? "home.new" : "home.connect")
                    }
                }.padding(.horizontal, compactHeader ? 16 : 32)
                Divider()
                Group {
                    switch navigation.homeTab {
                    case .new:
                        ScoreboardNewScoreboardView(embedded: true, cancel: { navigation.homeTab = .open }) { name, sport in
                            try library.newMatch(keepLocalDevices: false)
                            store.setSelectedSport(sport)
                            if !name.isEmpty, let entry = library.workingMatch { try library.rename(entry, to: name) }
                            try library.save(); navigation.openBoard(setup: true)
                        }
                    case .connect:
                        ScoreboardJoinMatchView(initialInvitation: navigation.invitation, nearbyInvitation: navigation.nearbyInvitation, embedded: true)
                    case .open:
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                if let current = library.workingMatch {
                                    HStack(spacing: 18) {
                                        Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.blue)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(current.title).font(.headline)
                                            Text("\(store.homeTeamName)  \(store.homeScore) – \(store.guestScore)  \(store.guestTeamName)")
                                                .font(.callout).foregroundStyle(palette.secondaryText)
                                        }
                                        Spacer()
                                        Button("Continue") { navigation.openBoard() }.buttonStyle(.borderedProminent).accessibilityIdentifier("home.continue")
                                    }.padding(22).background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 18))
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Open Scoreboard").font(.title2.bold())
                                        Spacer()
                                        Button("Open File…", systemImage: "folder") { imports = true }.accessibilityIdentifier("home.open")
                                    }
                                    if searches || !library.entries.isEmpty {
                                        TextField("Search scoreboards", text: $query).textFieldStyle(.roundedBorder).focused($searchFocused)
                                    }
                                    if entries.isEmpty {
                                        ContentUnavailableView(query.isEmpty ? "No Scoreboards Yet" : "No Matching Scoreboards", systemImage: "folder",
                                            description: Text("Create a scoreboard or import a .scoreboardgame file."))
                                    }
                                    ForEach(entries) { entry in
                                        HStack(spacing: 16) {
                                            Image(systemName: "doc.text").font(.title2).foregroundStyle(palette.accent)
                                            Button { resume(entry) } label: {
                                                VStack(alignment: .leading, spacing: 5) {
                                                    Text(entry.title).font(.headline).foregroundStyle(palette.primaryText)
                                                    Text(entry.loadError ?? "\(entry.home)  \(entry.homeScore) – \(entry.guestScore)  \(entry.guest)")
                                                        .font(.callout).foregroundStyle(entry.loadError == nil ? palette.secondaryText : .orange)
                                                    Text(entry.modifiedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(palette.secondaryText)
                                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                            }.buttonStyle(.plain).disabled(entry.loadError != nil)
                                            Button { actionsEntryID = entry.id } label: { Image(systemName: "ellipsis").padding(12) }
                                                .accessibilityLabel("Scoreboard Actions").accessibilityIdentifier("library.actions")
                                                .popover(isPresented: Binding(get: { actionsEntryID == entry.id }, set: { if !$0 { actionsEntryID = nil } })) {
                                                    fileActions(entry)
                                                }
                                        }.padding(18).background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                                ScoreboardMatchSaveStatus(library: library)
                            }.padding(compactHeader ? 20 : 32).frame(maxWidth: 1100).frame(maxWidth: .infinity)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(palette.detailBackground).foregroundStyle(palette.primaryText)
            .fileImporter(isPresented: $imports, allowedContentTypes: [.scoreboardGame]) { result in
                perform {
                    let url = try result.get(), access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let local = library.entries.first(where: { $0.url.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() }) {
                        try library.resume(local); navigation.openBoard()
                    } else {
                        let previous = Set(library.entries.map(\.id))
                        try library.importCopy(url)
                        if let imported = library.entries.first(where: { !previous.contains($0.id) }) {
                            try library.resume(imported); navigation.openBoard()
                        }
                    }
                }
            }
            .alert("Unable to Open Scoreboard", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
            .alert("Rename Scoreboard", isPresented: Binding(get: { renamed != nil }, set: { if !$0 { renamed = nil } })) {
                TextField("Name", text: $rename)
                Button("Rename") { if let entry = renamed { perform { try library.rename(entry, to: rename) } }; renamed = nil }
                Button("Cancel", role: .cancel) { renamed = nil }
            }
            .confirmationDialog("Delete Scoreboard?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete File", role: .destructive) { if let entry = deleting { perform { try library.delete(entry) } }; deleting = nil }
            }
            .confirmationDialog("Switch to Kiosk Mode?", isPresented: $confirmsKiosk, titleVisibility: .visible) {
                Button("Use Kiosk Mode") { perform { try store.setDeviceMode(.kiosk) } }
            } message: { Text("Your files stay on this device. Kiosk mode joins scoreboards as a display or controller and clears received match data when disconnected.") }
            .onAppear { perform { try library.refresh() }; store.isShowingFileHome = true }
        }
    }
    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 16) {
                ScoreboardLogoView(size: compactHeader ? 44 : 64)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart Scoreboard").font(compactHeader ? .title2.bold() : .largeTitle.bold()).lineLimit(2)
                    Text("Your scoreboards, ready to play.").font(compactHeader ? .callout : .title3).foregroundStyle(palette.secondaryText)
                }.layoutPriority(1)
            }
            Spacer(minLength: 0)
            Button { showsAppMenu = true } label: { Image(systemName: "gearshape").font(.title2).padding(12) }
                .accessibilityLabel("Settings and Mode").accessibilityIdentifier("home.settings")
                .popover(isPresented: $showsAppMenu, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 18) {
                        Button("App Settings", systemImage: "gearshape") { showsAppMenu = false; navigation.openSettings("general") }
                        Button("LAN & Cloud", systemImage: "network") { showsAppMenu = false; navigation.openSettings("cloud") }
                        Divider()
                        Button("Switch to Kiosk Mode", systemImage: "display") { showsAppMenu = false; confirmsKiosk = true }
                    }.buttonStyle(.plain).padding(24)
                        #if os(iOS)
                        .presentationCompactAdaptation(.popover)
                        #endif
                }
        }
    }
    private func fileActions(_ entry: ScoreboardLibraryEntry) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Button("Open") { actionsEntryID = nil; resume(entry) }.disabled(entry.loadError != nil)
            Button("New Scoreboard from Setup") { actionsEntryID = nil; perform { try library.newMatch(from: entry, keepLocalDevices: false); navigation.openBoard(setup: true) } }.disabled(entry.loadError != nil)
            ShareLink("Export File", item: entry.url)
            Button("Rename") { actionsEntryID = nil; renamed = entry; rename = entry.title }
            Button("Duplicate") { actionsEntryID = nil; perform { try library.duplicate(entry) } }.disabled(entry.loadError != nil)
            Button("Delete", role: .destructive) { actionsEntryID = nil; deleting = entry }.disabled(entry.matchID == library.workingMatchID)
        }.buttonStyle(.plain).padding(24)
            #if os(iOS)
            .presentationCompactAdaptation(.popover)
            #endif
    }
    private func resume(_ entry: ScoreboardLibraryEntry) { perform { try library.resume(entry); navigation.openBoard() } }
    private func perform(_ work: () throws -> Void) { do { try work() } catch { self.error = error.localizedDescription } }
}
#endif
