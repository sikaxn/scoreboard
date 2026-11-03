import SwiftUI

struct ScoreboardCloudSection<Content: View>: View {
    @ObservedObject private var store = ScoreboardStore.shared
    @Environment(\.colorScheme) private var colorScheme
    let title: LocalizedStringKey
    let footer: LocalizedStringKey?
    @ViewBuilder var content: () -> Content

    init(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    private var palette: SettingsPalette { store.theme.palette.settingsPalette(for: store.theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 0) { content() }
                .font(.body)
                .foregroundStyle(palette.primaryText)
                .tint(palette.accent)
                #if !os(tvOS)
                .toggleStyle(.switch)
                #endif
                .buttonStyle(ScoreboardCloudSettingsButtonStyle(
                    palette: palette,
                    destructiveTint: store.theme.palette.destructiveTint,
                    destructiveText: store.theme.palette.destructiveText
                ))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(palette.cardBorder)
                }

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ScoreboardCloudSettingsRow<Content: View>: View {
    @ObservedObject private var store = ScoreboardStore.shared
    @Environment(\.colorScheme) private var colorScheme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    let title: String
    let detail: String?
    let verbatim: Bool
    @ViewBuilder var content: () -> Content

    init(_ title: String, detail: String? = nil, verbatim: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.detail = detail
        self.verbatim = verbatim
        self.content = content
    }

    private var palette: SettingsPalette { store.theme.palette.settingsPalette(for: store.theme, colorScheme: colorScheme) }
    private var stacked: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: verbatim ? title : ScoreboardLocalization.string(title))
                    .foregroundStyle(palette.primaryText)
                if let detail {
                    Text(verbatim: ScoreboardLocalization.string(detail))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            if !stacked { Spacer(minLength: 0) }
            content()
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(stacked ? .leading : .trailing)
                .frame(maxWidth: stacked ? .infinity : 280, alignment: stacked ? .leading : .trailing)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ScoreboardCloudSettingsDivider: View {
    @ObservedObject private var store = ScoreboardStore.shared
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Divider().overlay(store.theme.palette.settingsPalette(for: store.theme, colorScheme: colorScheme).divider)
    }
}

private struct ScoreboardCloudSettingsButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let palette: SettingsPalette
    let destructiveTint: Color
    let destructiveText: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(configuration.role == .destructive ? destructiveText : palette.accentText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(configuration.role == .destructive ? destructiveTint : palette.accent, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.42)
    }
}

private struct ScoreboardCloudSettingsFieldAppearance: ViewModifier {
    @ObservedObject private var store = ScoreboardStore.shared
    @Environment(\.colorScheme) private var colorScheme
    private var palette: SettingsPalette { store.theme.palette.settingsPalette(for: store.theme, colorScheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func scoreboardCloudSettingsField() -> some View { modifier(ScoreboardCloudSettingsFieldAppearance()) }
}
