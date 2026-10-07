import SwiftUI
import UIKit

// MARK: - Color helpers

extension UIColor {
    convenience init(hex: String) {
        let digits = hex.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let value = UInt64(digits, radix: 16) ?? 0x808080
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    /// A color that switches with light/dark appearance.
    static func zen(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }

    static func zen(lightHex: String, darkHex: String) -> UIColor {
        zen(light: UIColor(hex: lightHex), dark: UIColor(hex: darkHex))
    }

    /// CSS `color-mix(in srgb, a amount, b)`, re-resolved for light/dark appearance.
    static func zenMix(_ a: UIColor, _ b: UIColor, _ amount: CGFloat) -> UIColor {
        UIColor { traits in
            UIColor.zenLerp(a.resolvedColor(with: traits), b.resolvedColor(with: traits), amount)
        }
    }

    /// Straight sRGB blend of two already-resolved colors; `amount` is how much of `a` to keep.
    static func zenLerp(_ a: UIColor, _ b: UIColor, _ amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let keep = amount, other = 1 - amount
        return UIColor(
            red: r1 * keep + r2 * other,
            green: g1 * keep + g2 * other,
            blue: b1 * keep + b2 * other,
            alpha: a1 * keep + a2 * other
        )
    }
}

// MARK: - Design tokens ("calm zen": warm stone by day, night stone by night)

enum Theme {
    static let bgUI = UIColor.zen(lightHex: "#F6F3EE", darkHex: "#171513")
    static let bgGlowUI = UIColor.zen(lightHex: "#EFE7DA", darkHex: "#221E1A")
    static let surfaceUI = UIColor.zen(lightHex: "#FFFDFA", darkHex: "#211E1B")
    static let surface2UI = UIColor.zen(lightHex: "#EEEAE3", darkHex: "#2B2724")
    static let surface3UI = UIColor.zen(lightHex: "#E4DED5", darkHex: "#36312C")
    static let borderUI = UIColor.zen(lightHex: "#E2DBD0", darkHex: "#36312C")
    static let borderStrongUI = UIColor.zen(lightHex: "#CFC6B8", darkHex: "#4A433C")
    static let textUI = UIColor.zen(lightHex: "#2A2521", darkHex: "#F2EDE6")
    static let textMutedUI = UIColor.zen(lightHex: "#635A51", darkHex: "#B3A99D")
    static let accentUI = UIColor.zen(lightHex: "#3F6E50", darkHex: "#8CC4A0")
    static let accentHoverUI = UIColor.zen(lightHex: "#355D44", darkHex: "#A2D3B3")
    static let onAccentUI = UIColor.zen(lightHex: "#FFFFFF", darkHex: "#12201A")
    static let accentSoftUI = UIColor.zen(lightHex: "#DCE8DF", darkHex: "#24332A")
    static let flameUI = UIColor.zen(lightHex: "#C2511C", darkHex: "#FF8A50")
    static let dangerUI = UIColor.zen(lightHex: "#B42318", darkHex: "#FF8A80")
    static let dangerSoftUI = UIColor.zen(lightHex: "#FBE7E4", darkHex: "#3A2220")
    static let heatmapEmptyUI = UIColor.zen(lightHex: "#E7E1D8", darkHex: "#2C2825")

    static let bg = Color(uiColor: bgUI)
    static let bgGlow = Color(uiColor: bgGlowUI)
    static let surface = Color(uiColor: surfaceUI)
    static let surface2 = Color(uiColor: surface2UI)
    static let surface3 = Color(uiColor: surface3UI)
    static let border = Color(uiColor: borderUI)
    static let borderStrong = Color(uiColor: borderStrongUI)
    static let text = Color(uiColor: textUI)
    static let textMuted = Color(uiColor: textMutedUI)
    static let accent = Color(uiColor: accentUI)
    static let accentHover = Color(uiColor: accentHoverUI)
    static let onAccent = Color(uiColor: onAccentUI)
    static let accentSoft = Color(uiColor: accentSoftUI)
    static let flame = Color(uiColor: flameUI)
    static let danger = Color(uiColor: dangerUI)
    static let dangerSoft = Color(uiColor: dangerSoftUI)
    static let heatmapEmpty = Color(uiColor: heatmapEmptyUI)

    /// Border of the progress card once every habit is done.
    static let completeBorder = Color(uiColor: .zenMix(accentUI, borderUI, 0.45))
    /// The warm highlight that sweeps through the full progress bar.
    static let shimmer = Color(uiColor: .zenMix(accentUI, UIColor(hex: "#E0A030"), 0.6))
}

// MARK: - Per-habit colors

/// Everything a habit's accent color turns into: darker "ink" for text and icons,
/// a solid "fill" for the done state, and a soft "tint" for backgrounds.
struct HabitTint {
    let base: UIColor

    init(hex: String) { base = UIColor(hex: hex) }
    init(base: UIColor) { self.base = base }

    var color: Color { Color(uiColor: base) }
    var ink: Color { Color(uiColor: inkUI) }
    var fill: Color { Color(uiColor: fillUI) }
    var tint: Color { Color(uiColor: tintUI) }
    /// Outline of the empty check circle.
    var checkBorder: Color { Color(uiColor: .zenMix(inkUI, Theme.borderStrongUI, 0.55)) }
    /// Card border once the habit is done.
    var doneBorder: Color { Color(uiColor: .zenMix(base, Theme.borderUI, 0.35)) }

    /// Text/icons on top of `fill`.
    static let onHabit = Color(uiColor: .zen(light: .white, dark: UIColor(hex: "#15120F")))

    var inkUI: UIColor {
        let base = self.base
        return UIColor { traits in
            let color = base.resolvedColor(with: traits)
            return traits.userInterfaceStyle == .dark
                ? UIColor.zenLerp(color, .white, 0.72)
                : UIColor.zenLerp(color, .black, 0.68)
        }
    }

    var fillUI: UIColor {
        let base = self.base
        return UIColor { traits in
            let color = base.resolvedColor(with: traits)
            return traits.userInterfaceStyle == .dark ? color : UIColor.zenLerp(color, .black, 0.84)
        }
    }

    var tintUI: UIColor {
        let base = self.base
        return UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            return UIColor.zenLerp(
                base.resolvedColor(with: traits),
                Theme.surfaceUI.resolvedColor(with: traits),
                dark ? 0.16 : 0.13
            )
        }
    }
}

// MARK: - Type

extension Font {
    /// The serif display face used for titles and big numbers (New York).
    static func display(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif, weight: .semibold)
    }
}

// MARK: - Motion

enum Motion {
    /// The app's signature ease-out: cubic-bezier(0.22, 1, 0.36, 1).
    static func ease(_ duration: Double = 0.45) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: duration)
    }

    /// A soft spring with a little overshoot.
    static func spring(_ response: Double = 0.5) -> Animation {
        .spring(response: response, dampingFraction: 0.62)
    }

    /// For things that should settle quickly (toasts, snapping back).
    static let snappy = Animation.spring(response: 0.45, dampingFraction: 0.72)
}

// MARK: - Shadows (warm-tinted in light mode)

enum Elevation {
    case small, medium, large
}

private struct ZenShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let elevation: Elevation

    private struct Layer {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    private var layers: (Layer, Layer) {
        let warm = Color(red: 60 / 255, green: 45 / 255, blue: 30 / 255)
        if colorScheme == .dark {
            switch elevation {
            case .small:
                return (Layer(color: .black.opacity(0.3), radius: 1, y: 1), Layer(color: .clear, radius: 0, y: 0))
            case .medium:
                return (Layer(color: .black.opacity(0.25), radius: 2, y: 2), Layer(color: .black.opacity(0.3), radius: 12, y: 8))
            case .large:
                return (Layer(color: .black.opacity(0.55), radius: 24, y: 16), Layer(color: .clear, radius: 0, y: 0))
            }
        }
        switch elevation {
        case .small:
            return (Layer(color: warm.opacity(0.06), radius: 1, y: 1), Layer(color: warm.opacity(0.05), radius: 3, y: 2))
        case .medium:
            return (Layer(color: warm.opacity(0.05), radius: 2, y: 2), Layer(color: warm.opacity(0.08), radius: 12, y: 8))
        case .large:
            return (Layer(color: warm.opacity(0.18), radius: 24, y: 12), Layer(color: .clear, radius: 0, y: 0))
        }
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: layers.0.color, radius: layers.0.radius, x: 0, y: layers.0.y)
            .shadow(color: layers.1.color, radius: layers.1.radius, x: 0, y: layers.1.y)
    }
}

extension View {
    func zenShadow(_ elevation: Elevation) -> some View {
        modifier(ZenShadow(elevation: elevation))
    }
}
