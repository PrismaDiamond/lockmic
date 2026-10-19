import SwiftUI

/// Tile-based picker that previews each menu bar icon style (mic on / muted) on a mock menu bar.
struct MenuBarIconStylePicker: View {
    @Binding var selection: MenuBarIconStyle
    var appearance: AppAppearance = .system
    @Environment(\.colorScheme) private var colorScheme

    private var isLight: Bool {
        switch appearance {
        case .light: return true
        case .dark: return false
        case .system: return colorScheme == .light
        }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            ForEach(MenuBarIconStyle.allCases) { style in
                tile(style)
            }
        }
    }

    private func tile(_ style: MenuBarIconStyle) -> some View {
        let selected = selection == style
        return Button { selection = style } label: {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    preview(style, symbol: "mic.fill", state: .unmuted)
                    preview(style, symbol: "mic.slash.fill", state: .muted)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: isLight ? 0.93 : 0.16)))
                Text(title(style))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
            }
            .padding(6)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(title(style))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func preview(_ style: MenuBarIconStyle, symbol: String, state: MicState) -> some View {
        let image = MenuBarIconRenderer.image(
            symbol: symbol, style: style, state: state, recording: false, description: ""
        )
        // Template glyphs take the mock menu bar's foreground color.
        let tinted = image.isTemplate
        return Image(nsImage: image)
            .renderingMode(tinted ? .template : .original)
            .foregroundStyle(isLight ? Color.black : Color.white)
    }

    private func title(_ style: MenuBarIconStyle) -> String {
        switch style {
        case .monochrome: return L10n.generalOptionsMenuBarIconMonochrome
        case .redWhenLive: return L10n.generalOptionsMenuBarIconRed
        case .redBox: return L10n.generalOptionsMenuBarIconRedBox
        case .textBadge: return L10n.generalOptionsMenuBarIconText
        case .redAndGreen: return L10n.generalOptionsMenuBarIconRedGreen
        }
    }
}
