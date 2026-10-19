import SwiftUI

/// Tile-based theme picker with a mini window preview for System / Light / Dark.
struct AppearanceThemePicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            ForEach(AppAppearance.allCases) { option in
                tile(option)
            }
        }
    }

    private func tile(_ option: AppAppearance) -> some View {
        let selected = selection == option
        return Button { selection = option } label: {
            VStack(spacing: 6) {
                preview(option)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                Text(title(option))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
            }
            .padding(6)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.12) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title(option))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func preview(_ option: AppAppearance) -> some View {
        switch option {
        case .light: miniWindow(light: true)
        case .dark: miniWindow(light: false)
        case .system:
            HStack(spacing: 0) {
                miniWindow(light: true).frame(maxWidth: .infinity).clipped()
                miniWindow(light: false).frame(maxWidth: .infinity).clipped()
            }
        }
    }

    /// Simplified window: title bar with traffic lights, sidebar and content lines.
    private func miniWindow(light: Bool) -> some View {
        let bg = light ? Color(white: 0.96) : Color(white: 0.17)
        let bar = light ? Color(white: 0.88) : Color(white: 0.24)
        let line = light ? Color(white: 0.75) : Color(white: 0.38)
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                bg
                bar.frame(height: 10)
                HStack(spacing: 2.5) {
                    ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 4, height: 4) }
                }
                .padding(.leading, 5).padding(.top, 3)
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(Color.accentColor).frame(width: geo.size.width * 0.5, height: 4)
                    Capsule().fill(line).frame(width: geo.size.width * 0.7, height: 4)
                    Capsule().fill(line).frame(width: geo.size.width * 0.4, height: 4)
                }
                .padding(.top, 18).padding(.leading, 8)
            }
        }
    }

    private func title(_ option: AppAppearance) -> String {
        switch option {
        case .system: return L10n.generalOptionsAppearanceSystem
        case .light: return L10n.generalOptionsAppearanceLight
        case .dark: return L10n.generalOptionsAppearanceDark
        }
    }
}
