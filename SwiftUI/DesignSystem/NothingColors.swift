import SwiftUI

// MARK: - Color Hex Initializer

extension Color {
    /// Initialize a Color from a hex string (e.g. "#D71921" or "D71921").
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Nothing Design System Colors

/// Color tokens for the Nothing design system.
///
/// Every token exposes an adaptive `Color` that resolves at runtime
/// based on the current `ColorScheme`.  Use the static properties
/// directly in SwiftUI views — they read the environment automatically
/// via `Color(light:dark:)` helpers.
struct NothingColors {

    private init() {}

    // MARK: - Backgrounds & Surfaces

    /// OLED black in dark mode, warm grey in light mode.
    static let background = Color(
        light: Color(red: 0.96, green: 0.96, blue: 0.96),   // #F5F5F5
        dark:  Color(red: 0.0,  green: 0.0,  blue: 0.0)     // #000000
    )

    static let surface = Color(
        light: Color(red: 1.0,  green: 1.0,  blue: 1.0),    // #FFFFFF
        dark:  Color(red: 0.067, green: 0.067, blue: 0.067)  // #111111
    )

    static let surfaceRaised = Color(
        light: Color(red: 0.941, green: 0.941, blue: 0.941), // #F0F0F0
        dark:  Color(red: 0.102, green: 0.102, blue: 0.102)  // #1A1A1A
    )

    // MARK: - Borders

    static let border = Color(
        light: Color(red: 0.91,  green: 0.91,  blue: 0.91),  // #E8E8E8
        dark:  Color(red: 0.133, green: 0.133, blue: 0.133)   // #222222
    )

    static let borderVisible = Color(
        light: Color(red: 0.8,   green: 0.8,   blue: 0.8),   // #CCCCCC
        dark:  Color(red: 0.2,   green: 0.2,   blue: 0.2)    // #333333
    )

    // MARK: - Text

    static let textDisabled = Color(
        light: Color(red: 0.6,  green: 0.6,  blue: 0.6),     // #999999
        dark:  Color(red: 0.4,  green: 0.4,  blue: 0.4)      // #666666
    )

    static let textSecondary = Color(
        light: Color(red: 0.4,  green: 0.4,  blue: 0.4),     // #666666
        dark:  Color(red: 0.6,  green: 0.6,  blue: 0.6)      // #999999
    )

    static let textPrimary = Color(
        light: Color(red: 0.102, green: 0.102, blue: 0.102),  // #1A1A1A
        dark:  Color(red: 0.91,  green: 0.91,  blue: 0.91)   // #E8E8E8
    )

    static let textDisplay = Color(
        light: Color(red: 0.0,  green: 0.0,  blue: 0.0),     // #000000
        dark:  Color(red: 1.0,  green: 1.0,  blue: 1.0)      // #FFFFFF
    )

    // MARK: - Accent & Status

    /// Nothing Phone(1) signature red. Same in both appearances.
    static let accent = Color(red: 0.843, green: 0.098, blue: 0.129)  // #D71921

    /// Subtle variant of accent for tinted backgrounds.
    static let accentSubtle = Color(red: 0.843, green: 0.098, blue: 0.129)
        .opacity(0.15)

    /// Positive / success indicator. Same in both appearances.
    static let success = Color(red: 0.29, green: 0.62, blue: 0.36)    // #4A9E5C

    /// Warning indicator. Same in both appearances.
    static let warning = Color(red: 0.831, green: 0.659, blue: 0.263) // #D4A843

    /// Interactive / link color. System blue in light mode, softer blue in dark.
    static let interactive = Color(
        light: Color(red: 0.0,   green: 0.478, blue: 1.0),   // #007AFF
        dark:  Color(red: 0.357, green: 0.608, blue: 0.965)   // #5B9BF6
    )
}

// MARK: - Adaptive Color Helper

private extension Color {
    /// Creates an adaptive color that resolves from a light and dark variant.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}
