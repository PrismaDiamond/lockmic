import AppKit

/// Draws the menu bar status icon for each style; also used by the Settings previews.
enum MenuBarIconRenderer {
    /// Deeper than `.systemRed` so it stays readable on light menu bars.
    static let liveRed = NSColor(srgbRed: 0.90, green: 0.08, blue: 0.10, alpha: 1)

    /// Renders the icon; while recording, a red dot with a light ring is added at the bottom-right.
    static func image(
        symbol: String,
        style: MenuBarIconStyle,
        state: MicState,
        recording: Bool,
        description: String,
        weight: NSFont.Weight = .medium
    ) -> NSImage {
        let base = baseImage(symbol: symbol, style: style, state: state, description: description, weight: weight)
        guard recording else { return base }
        let image = NSImage(size: base.size, flipped: false) { bounds in
            base.draw(in: bounds)
            if base.isTemplate {
                NSColor.labelColor.set()
                bounds.fill(using: .sourceIn)
            }
            let dot = NSRect(x: bounds.maxX - 7, y: 0.5, width: 6.5, height: 6.5)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: dot.insetBy(dx: -1, dy: -1)).fill()
            liveRed.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = description
        return image
    }

    private static func baseImage(
        symbol: String,
        style: MenuBarIconStyle,
        state: MicState,
        description: String,
        weight: NSFont.Weight
    ) -> NSImage {
        var weight = weight
        let live: Bool = { if case .unmuted = state { return true } else { return false } }()
        let muted: Bool = { if case .muted = state { return true } else { return false } }()

        if style == .textBadge, live || muted {
            return textBadge(live ? "ON" : "OFF", filled: live, description: description)
        }

        enum Look { case template, tinted(NSColor), box(NSColor) }
        let look: Look = {
            switch style {
            case .monochrome: return .template
            case .redWhenLive: return live ? .tinted(Self.liveRed) : .template
            case .redBox: return live ? .box(.systemRed) : .template
            case .textBadge: return .template
            case .redAndGreen: return live ? .tinted(Self.liveRed) : (muted ? .tinted(.systemGreen) : .template)
            }
        }()

        if style == .redWhenLive || style == .redAndGreen, live || muted { weight = .bold }
        var canvas = NSSize(width: 18, height: 18)
        // Same canvas in every state so the item keeps its width when the mic flips.
        if style == .redBox { canvas = NSSize(width: 28, height: 21) }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: weight)
            .applying(NSImage.SymbolConfiguration(scale: .large))
        guard NSImage(systemSymbolName: symbol, accessibilityDescription: description) != nil else {
            return NSImage(size: canvas)
        }

        func symbolImage(_ color: NSColor?) -> NSImage? {
            var c = config
            if let color { c = c.applying(NSImage.SymbolConfiguration(paletteColors: [color])) }
            return NSImage(systemSymbolName: symbol, accessibilityDescription: description)?
                .withSymbolConfiguration(c)
        }

        let needsColor: Bool = {
            if case .template = look { return false }
            return true
        }()

        let image = NSImage(size: canvas, flipped: false) { bounds in
            var glyphBounds = bounds
            var glyphColor: NSColor? = nil
            switch look {
            case .template:
                glyphColor = needsColor ? .labelColor : nil
                if style == .redBox { glyphBounds = bounds.insetBy(dx: (bounds.width - 18) / 2, dy: (bounds.height - 18) / 2) }
            case .tinted(let color): glyphColor = color
            case .box(let color):
                color.setFill()
                NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0), xRadius: 5, yRadius: 5).fill()
                glyphColor = .white
                glyphBounds = bounds.insetBy(dx: 6, dy: 3)
            }
            guard let glyph = symbolImage(glyphColor) else { return true }
            let size = glyph.size
            let scale = min(glyphBounds.width / max(size.width, 1), glyphBounds.height / max(size.height, 1))
            let drawSize = NSSize(width: size.width * scale, height: size.height * scale)
            glyph.draw(
                in: NSRect(
                    x: glyphBounds.midX - drawSize.width / 2,
                    y: glyphBounds.midY - drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                ),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }
        image.isTemplate = !needsColor
        return image
    }

    /// "ON" in a filled red box, "OFF" as an outlined template box that follows the menu bar tint.
    private static func textBadge(_ text: String, filled: Bool, description: String) -> NSImage {
        // Same canvas for ON and OFF so the menu bar item keeps its width when the state flips.
        let canvas = NSSize(width: 32, height: 20)
        let image = NSImage(size: canvas, flipped: false) { bounds in
            let box = filled ? bounds.insetBy(dx: 0.75, dy: 0.75) : bounds.insetBy(dx: 2.75, dy: 1.75)
            let path = NSBezierPath(roundedRect: box, xRadius: 4.5, yRadius: 4.5)
            let textColor: NSColor
            if filled {
                liveRed.setFill()
                path.fill()
                textColor = .white
            } else {
                NSColor.black.setStroke()
                path.lineWidth = 1.5
                path.stroke()
                textColor = .black
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: filled ? 13 : 10.5, weight: .heavy),
                .foregroundColor: textColor
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let size = str.size()
            str.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
            return true
        }
        image.isTemplate = !filled
        image.accessibilityDescription = description
        return image
    }
}
