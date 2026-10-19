import SwiftUI

struct PreferencesAppearancePage: View {
    @ObservedObject var preferences: PreferencesStore
    @Environment(\.colorScheme) private var colorScheme

    private var isLight: Bool {
        switch preferences.appAppearance {
        case .light: return true
        case .dark: return false
        case .system: return colorScheme == .light
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PreferencesChrome.pageSpacing) {
            PreferencesChrome.sectionCard {
                PreferencesChrome.sectionHeader(L10n.generalOptionsMenuBarIcon)
                MenuBarIconStylePicker(selection: $preferences.menuBarIconStyle, appearance: preferences.appAppearance)
                PreferencesChrome.caption(L10n.generalOptionsMenuBarIconCaption)
            }

            PreferencesChrome.sectionCard {
                PreferencesChrome.sectionHeader(L10n.generalOptionsAppearance)
                AppearanceThemePicker(selection: $preferences.appAppearance)
            }

            PreferencesChrome.sectionCard {
                PreferencesChrome.sectionHeader(L10n.appearanceIndicatorsHeader)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)], spacing: 10) {
                    indicatorCard(
                        .hud, title: L10n.generalOptionsHUD, caption: L10n.generalOptionsHUDCaption,
                        isOn: $preferences.hudEnabled, requiresFeatures: true
                    )
                    indicatorCard(
                        .floating, title: L10n.generalOptionsFloating, caption: L10n.generalOptionsFloatingCaption,
                        isOn: $preferences.hudFloating, requiresFeatures: true
                    )
                    indicatorCard(
                        .dock, title: L10n.generalOptionsDock, caption: L10n.generalOptionsDockCaption,
                        isOn: $preferences.showInDock, requiresFeatures: false
                    )
                }
            }
        }
    }

    /// Whole card toggles the setting; selected cards get the accent border like the other pickers.
    private func indicatorCard(
        _ kind: IndicatorPreview.Kind,
        title: String,
        caption: String,
        isOn: Binding<Bool>,
        requiresFeatures: Bool
    ) -> some View {
        let on = isOn.wrappedValue
        let locked = requiresFeatures && !preferences.featuresEnabled
        return Button { isOn.wrappedValue.toggle() } label: {
            VStack(alignment: .leading, spacing: 8) {
                IndicatorPreview(kind: kind, enabled: on, light: isLight)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(on ? Color.accentColor : Color.secondary)
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? Color.accentColor.opacity(0.12) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(on ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: on ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.45 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
