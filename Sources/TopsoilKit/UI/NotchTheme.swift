import SwiftUI

/// Resolved theme values derived from `NotchAppearance` plus system state
/// (e.g. reduced motion) that views can read without knowing appearance rules.
public struct NotchThemeTokens: Equatable, Sendable {
    public var accent: Color                 // resolved user accent
    public var cornerRadius: CGFloat         // panel-level
    public var tileCornerRadius: CGFloat     // tile surfaces
    public var glassOpacity: Double          // panel material strength
    public var strokeOpacity: Double         // hairlines / tile strokes
    public var tileFillOpacity: Double       // tile background strength
    public var tileFillTint: Color           // hue of tile fill (white for neutral presets)
    public var backgroundTint: Color         // wash over the black panel (clear for most presets)
    public var fontDesign: Font.Design       // .monospaced for Terminal, .default otherwise
    public var spacingScale: CGFloat         // density multiplier
    public var motionStyle: MotionStyle

    /// nil when motion is reduced — feed straight into .animation(_:value:)
    public var hoverAnimation: Animation? { motionStyle == .reduced ? nil : .easeOut(duration: 0.14) }

    /// Panel/root state transitions (expand, collapse, page changes).
    /// Falls back to a quick fade-style ease when motion is reduced, matching
    /// the system Reduce Motion preference folded into `motionStyle`.
    public var panelAnimation: Animation {
        motionStyle == .reduced
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.36, dampingFraction: 0.80)
    }

    /// Content inside the panel (tiles, module rows) — settles slightly after
    /// the panel frame so expansion reads as the panel revealing its contents.
    public var contentAnimation: Animation {
        motionStyle == .reduced
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.40, dampingFraction: 0.86).delay(0.04)
    }

    /// Button/press feedback — snappy with a hint of overshoot.
    public var pressAnimation: Animation {
        motionStyle == .reduced
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.26, dampingFraction: 0.70)
    }

    // MARK: Type scale
    // One scale for the whole panel. `fontDesign` (monospaced for the terminal
    // preset) flows through automatically, so modules never call
    // `.font(.system(size:))` with ad-hoc numbers.

    /// Large numerals / hero stats (timer clocks, temperatures).
    public var displayFont: Font { .system(size: 17, weight: .semibold, design: .default).monospacedDigit() }
    /// Tile-level titles and primary lines (track title, event name).
    public var titleFont: Font { .system(size: 12, weight: .semibold, design: .default) }
    /// Interactive labels: buttons, chips, segmented options.
    public var labelFont: Font { .system(size: 11, weight: .medium, design: .default) }
    /// Supporting copy (artist line, empty-state message).
    public var bodyFont: Font { .system(size: 11, weight: .regular, design: .default) }
    /// Secondary metadata rows.
    public var captionFont: Font { .system(size: 10, weight: .medium, design: .default) }
    /// Uppercased micro-labels (tile headers). Pair with `.tracking(0.8)`.
    public var caption2Font: Font { .system(size: 9, weight: .semibold, design: .default) }

    // MARK: Text hierarchy

    public var textPrimary: Color { .white.opacity(0.95) }
    public var textSecondary: Color { .white.opacity(0.76) }
    public var textTertiary: Color { .white.opacity(0.60) }
    public var textQuaternary: Color { .white.opacity(0.46) }

    // Shared semantic colors; pair with a label or icon in every status view.
    public var success: Color { Color(red: 0.40, green: 0.85, blue: 0.56) }
    public var warning: Color { Color(red: 1.0, green: 0.76, blue: 0.40) }
    public var error: Color { Color(red: 1.0, green: 0.48, blue: 0.48) }
    public var information: Color { Color(red: 0.48, green: 0.76, blue: 1.0) }

    // MARK: Controls

    /// Inner controls sit 2pt tighter than the tile radius so nesting reads
    /// as one system (concentric corners).
    public var controlCornerRadius: CGFloat { max(5, tileCornerRadius - 2) }

    /// Terminal reads as wireframe-on-black: stroke uses the accent, boosted.
    /// Every other preset uses a plain white hairline at `strokeOpacity`.
    /// `fontDesign == .monospaced` is the terminal preset's own signal, so it
    /// doubles as the check here rather than adding a redundant stored flag.
    /// Hover raises the opacity by +0.09 over the resting value.
    public func tileStrokeColor(hovered: Bool = false) -> Color {
        let isTerminal = fontDesign == .monospaced
        let base = isTerminal ? accent : Color.white
        var opacity = isTerminal ? strokeOpacity + 0.10 : strokeOpacity
        if hovered { opacity += 0.09 }
        return base.opacity(opacity)
    }

    /// Fill opacity is scaled by `glassOpacity / 0.62` so the Glass Intensity
    /// setting visibly affects tile fill (0.62 is the `.balanced` baseline,
    /// so `.balanced` renders identically to the unscaled value).
    /// Hover adds +0.025 before scaling.
    public func tileFillColor(hovered: Bool = false) -> Color {
        let opacity = tileFillOpacity + (hovered ? 0.025 : 0)
        return tileFillTint.opacity(opacity * glassOpacity / 0.62)
    }
}

/// Shared visual constants so the dashboard and wide-bar layouts stay in sync.
public enum NotchTheme {
    static let tileCornerRadius: CGFloat = 8
    static let tileFill     = Color.white.opacity(0.075)
    static let tileStroke   = Color.white.opacity(0.10)
    static let hairline     = Color.white.opacity(0.10)
    static let accent       = Color(red: 0.36, green: 0.78, blue: 1)

    /// Derives theme tokens from the user's appearance settings, folding in
    /// the system's reduced-motion preference (which always wins).
    public static func tokens(for appearance: NotchAppearance, reduceMotion: Bool) -> NotchThemeTokens {
        let resolvedMotion: MotionStyle = reduceMotion ? .reduced : appearance.motionStyle
        let cornerRadius: CGFloat
        if appearance.preset == .terminal {
            cornerRadius = 6
        } else {
            switch appearance.cornerStyle {
            case .precise: cornerRadius = 6
            case .soft: cornerRadius = 8
            case .pill: cornerRadius = 12
            }
        }

        let glassOpacity: Double
        switch appearance.glassIntensity {
        case .subtle: glassOpacity = 0.50
        case .balanced: glassOpacity = 0.62
        case .vivid: glassOpacity = 0.78
        }

        let spacingScale: CGFloat
        switch appearance.panelDensity {
        case .compact: spacingScale = 0.85
        case .comfortable: spacingScale = 1.0
        case .spacious: spacingScale = 1.2
        }

        let fontDesign: Font.Design = appearance.preset == .terminal ? .monospaced : .default
        let accent = accentColor(for: appearance.accentColor)

        var strokeOpacity: Double = appearance.glassIntensity == .subtle ? 0.08 : 0.14
        var tileFillOpacity: Double
        var tileFillTint: Color
        var backgroundTint: Color

        switch appearance.preset {
        case .studioGlass, .paper:
            tileFillOpacity = 0.070
            tileFillTint = .white
            backgroundTint = .clear
        case .minimalGraphite:
            tileFillOpacity = 0.045
            tileFillTint = .white
            backgroundTint = .clear
            strokeOpacity = min(strokeOpacity, 0.08)
        case .aurora:
            tileFillOpacity = 0.085
            tileFillTint = accent
            backgroundTint = accent.opacity(0.06)
        case .terminal:
            tileFillOpacity = 0.040
            tileFillTint = .white
            backgroundTint = .clear
        }

        return NotchThemeTokens(
            accent: accent,
            cornerRadius: cornerRadius,
            tileCornerRadius: cornerRadius,
            glassOpacity: glassOpacity,
            strokeOpacity: strokeOpacity,
            tileFillOpacity: tileFillOpacity,
            tileFillTint: tileFillTint,
            backgroundTint: backgroundTint,
            fontDesign: fontDesign,
            spacingScale: spacingScale,
            motionStyle: resolvedMotion
        )
    }

    // Kept for older tile callers that still want a subtle top-to-bottom tint.
    static func tileFillGradient(hovered: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(hovered ? 0.10 : 0.075),
                Color.white.opacity(hovered ? 0.08 : 0.060)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func tileStrokeGradient(hovered: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(hovered ? 0.18 : 0.10),
                Color.white.opacity(hovered ? 0.10 : 0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Resolves an accent choice to a concrete color.
    public static func accentColor(for choice: AccentColorChoice) -> Color {
        switch choice {
        case .cyan: return accent
        case .blue: return Color(red: 0.36, green: 0.60, blue: 1.0)
        case .purple: return Color(red: 0.68, green: 0.45, blue: 1.0)
        case .green: return Color(red: 0.40, green: 0.85, blue: 0.55)
        case .amber: return Color(red: 1.0, green: 0.72, blue: 0.30)
        case .red: return Color(red: 1.0, green: 0.40, blue: 0.40)
        }
    }
}

private struct NotchTokensKey: EnvironmentKey {
    static let defaultValue = NotchTheme.tokens(for: .defaults, reduceMotion: false)
}

extension EnvironmentValues {
    var notchTokens: NotchThemeTokens {
        get { self[NotchTokensKey.self] }
        set { self[NotchTokensKey.self] = newValue }
    }
}
