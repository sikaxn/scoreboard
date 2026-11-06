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
    @State private var showsNew = false
    @State private var showsAppMenu = false
    @State private var imports = false
    @State private var opensImportedFile = false
    @State private var searches = false
    @State private var query = ""
    @State private var name = ""
    @State private var sport: SportType = .simple
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
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
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
                                    Button("Cloud Service", systemImage: "cloud") { showsAppMenu = false; navigation.openSettings("cloud") }
                                    Divider()
                                    Button("Switch to Kiosk Mode", systemImage: "display") { showsAppMenu = false; confirmsKiosk = true }
                                }.buttonStyle(.plain).padding(24)
                                    #if os(iOS)
                                    .presentationCompactAdaptation(.popover)
                                    #endif
                            }
                    }
                    ScoreboardHomeStatusView().scoreboardHomeEntrance(order: 1)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 215), spacing: 16)], spacing: 16) {
                        action("New Scoreboard", detail: "Choose a sport and get started", icon: "plus", color: .orange) { name = ""; showsNew = true }
                            .accessibilityIdentifier("home.new")
                        action("Open Scoreboard", detail: "Choose a scoreboard file", icon: "folder", color: .blue) { opensImportedFile = true; imports = true }
                            .accessibilityIdentifier("home.open")
                        action("Connect to Scoreboard", detail: "Nearby or with a cloud code", icon: "person.2", color: .teal) { navigation.open(.join) }
                            .accessibilityIdentifier("home.connect")
                    }.scoreboardHomeEntrance(order: 2)
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
                            Text("On This Device").font(.title2.bold())
                            Spacer()
                            Button("Import File", systemImage: "square.and.arrow.down") { opensImportedFile = false; imports = true }.accessibilityIdentifier("home.import")
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
                }.padding(32).frame(maxWidth: 1100).frame(maxWidth: .infinity)
                    .scoreboardHomeEntrance()
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: entries.map(\.id))
            }
            .background(palette.detailBackground).foregroundStyle(palette.primaryText)
            .sheet(isPresented: $showsNew) {
                NavigationStack {
                    Form {
                        TextField("Scoreboard name (optional)", text: $name).accessibilityIdentifier("home.newName")
                        Picker("Sport", selection: $sport) { ForEach(SportType.allCases) { Text($0.title).tag($0) } }
                        Text("Saved on this device. You can connect other devices after opening the scoreboard.").font(.callout).foregroundStyle(.secondary)
                    }.navigationTitle("New Scoreboard")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsNew = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Create") { perform {
                                    try library.newMatch(keepLocalDevices: false)
                                    store.setSelectedSport(sport)
                                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        if let entry = library.workingMatch { try library.rename(entry, to: name) }
                                    }
                                    try library.save(); showsNew = false; navigation.openBoard(setup: true)
                                }}.accessibilityIdentifier("home.create")
                            }
                        }
                }.frame(minWidth: 320, idealWidth: 500, minHeight: 320)
            }
            .fileImporter(isPresented: $imports, allowedContentTypes: [.scoreboardGame]) { result in
                perform {
                    let url = try result.get(), access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if opensImportedFile, let local = library.entries.first(where: { $0.url.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() }) {
                        try library.resume(local); navigation.openBoard()
                    } else {
                        let previous = Set(library.entries.map(\.id))
                        try library.importCopy(url)
                        if opensImportedFile, let imported = library.entries.first(where: { !previous.contains($0.id) }) {
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
    private func action(_ title: String, detail: String, icon: String, color: Color, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon).font(.title2.bold()).frame(width: 54, height: 54).foregroundStyle(.white)
                    .background(color, in: RoundedRectangle(cornerRadius: 16))
                Text(title).font(.headline).foregroundStyle(palette.primaryText)
                Text(detail).font(.callout).foregroundStyle(palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading).padding(22)
                .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(ScoreboardHomeButtonStyle())
    }
}
#endif
