import SwiftUI

/// Mini desktop mockups that illustrate where each indicator appears.
struct IndicatorPreview: View {
    enum Kind { case hud, floating, dock }

    let kind: Kind
    let enabled: Bool
    var light: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: light
                    ? [Color(red: 0.78, green: 0.87, blue: 0.98), Color(red: 0.92, green: 0.84, blue: 0.96)]
                    : [Color(red: 0.16, green: 0.22, blue: 0.38), Color(red: 0.30, green: 0.20, blue: 0.38)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 0) {
                Rectangle().fill((light ? Color.white.opacity(0.6) : Color.black.opacity(0.35))).frame(height: 5)
                Spacer(minLength: 0)
            }
            content
                .opacity(enabled ? 1 : 0.25)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .hud:
            // Centered glass pill, shown briefly.
            glassSquare(size: 42)
        case .floating:
            // Persistent pill parked in a corner.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    glassSquare(size: 26)
                }
            }
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        case .dock:
            VStack {
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2).fill((light ? Color.black.opacity(0.3) : Color.white.opacity(0.55))).frame(width: 8, height: 8)
                    }
                    Image(systemName: "mic.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 8, height: 8)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color.red))
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2).fill((light ? Color.black.opacity(0.3) : Color.white.opacity(0.55))).frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Capsule().fill(light ? Color.white.opacity(0.6) : Color.white.opacity(0.28)))
                .padding(.bottom, 4)
            }
        }
    }

    private func glassSquare(size: CGFloat) -> some View {
        Image(systemName: "mic.slash.fill")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(light ? Color.black.opacity(0.8) : Color.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3).fill(.ultraThinMaterial))
            .background(RoundedRectangle(cornerRadius: size * 0.3).fill(light ? Color.white.opacity(0.4) : Color.black.opacity(0.25)))
    }
}
