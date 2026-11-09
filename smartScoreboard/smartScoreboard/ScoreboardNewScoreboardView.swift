import SwiftUI

#if !os(tvOS)
/// One explicit layout for Mac windows, iPad sheets, and compact screens.
struct ScoreboardNewScoreboardView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var name = ""
    @State private var sport: SportType = .simple
    @State private var error: String?
    let create: (String, SportType) throws -> Void

    private var palette: SettingsPalette { store.theme.palette.settingsPalette(for: store.theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.title2.weight(.semibold)).foregroundStyle(palette.accent)
                            .frame(width: 52, height: 52)
                            .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("New Scoreboard").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                            Text("Choose a sport. Set up teams and game rules next.")
                                .font(.callout).foregroundStyle(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Scoreboard Name").font(.headline)
                        TextField("Scoreboard name (optional)", text: $name)
                            .textFieldStyle(.plain).padding(14)
                            .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(palette.cardBorder) }
                            .accessibilityIdentifier("home.newName")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sport").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                            ForEach(SportType.allCases) { choice in
                                Button { sport = choice } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: symbol(for: choice)).font(.title3).frame(width: 28)
                                        Text(LocalizedStringKey(choice.title)).font(.body.weight(.semibold))
                                        Spacer(minLength: 4)
                                        Image(systemName: sport == choice ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(sport == choice ? palette.accent : palette.secondaryText.opacity(0.4))
                                    }
                                    .foregroundStyle(sport == choice ? palette.accent : palette.primaryText)
                                    .padding(16).frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                                    .background(sport == choice ? palette.accent.opacity(0.1) : palette.cardBackground,
                                                in: RoundedRectangle(cornerRadius: 14))
                                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(sport == choice ? palette.accent : palette.cardBorder, lineWidth: sport == choice ? 2 : 1) }
                                    .contentShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain).accessibilityIdentifier("home.newSport.\(choice.rawValue)")
                                .accessibilityAddTraits(sport == choice ? .isSelected : [])
                            }
                        }
                    }
                    Label("Saved on this device. You can connect other devices after opening the scoreboard.", systemImage: "internaldrive")
                        .font(.callout).foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout).foregroundStyle(store.theme.palette.destructiveTint)
                            .accessibilityIdentifier("home.newError")
                    }
                }.padding(28).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
            Divider()
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("home.cancelNew")
                Button("Create Scoreboard", systemImage: "plus") {
                    do { try create(name.trimmingCharacters(in: .whitespacesAndNewlines), sport) }
                    catch { self.error = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent).foregroundStyle(palette.accentText).keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("home.create")
            }.controlSize(.large).padding(20).background(palette.cardBackground)
        }
        .background(palette.detailBackground).foregroundStyle(palette.primaryText).tint(palette.accent)
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 620, minHeight: 500, idealHeight: 690)
        #else
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        #endif
    }

    private func symbol(for sport: SportType) -> String {
        switch sport {
        case .simple: "rectangle.split.2x1"
        case .basketball: "basketball.fill"
        case .volleyball: "volleyball.fill"
        case .soccer: "soccerball"
        case .hockey: "figure.hockey"
        case .chess: "checkerboard.rectangle"
        case .debate: "bubble.left.and.bubble.right.fill"
        case .custom: "slider.horizontal.3"
        }
    }
}
#endif
