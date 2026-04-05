import SwiftUI

// MARK: - Nothing Theme

/// Layout, motion, and typographic spacing tokens for the Nothing design system.
///
/// All values are unitless `CGFloat` constants suitable for use in SwiftUI
/// modifiers like `.padding()`, `.cornerRadius()`, and `.animation()`.
struct NothingTheme {

    private init() {}

    // MARK: - Spacing Scale

    /// 2 pt — hairline separators, inline icon gaps.
    static let space2XS: CGFloat = 2

    /// 4 pt — tight internal padding.
    static let spaceXS: CGFloat = 4

    /// 8 pt — compact element spacing.
    static let spaceSM: CGFloat = 8

    /// 16 pt — default content padding.
    static let spaceMD: CGFloat = 16

    /// 24 pt — group separation.
    static let spaceLG: CGFloat = 24

    /// 32 pt — section separation.
    static let spaceXL: CGFloat = 32

    /// 48 pt — major section gaps.
    static let space2XL: CGFloat = 48

    /// 64 pt — page-level vertical rhythm.
    static let space3XL: CGFloat = 64

    /// 96 pt — hero / splash spacing.
    static let space4XL: CGFloat = 96

    // MARK: - Border Radii

    /// 4 pt — sharp technical elements (tags, badges).
    static let radiusTechnical: CGFloat = 4

    /// 8 pt — buttons, inputs, compact cards.
    static let radiusCompact: CGFloat = 8

    /// 12 pt — standard cards, dialogs.
    static let radiusCard: CGFloat = 12

    /// 999 pt — fully rounded / pill shape.
    static let radiusPill: CGFloat = 999

    // MARK: - Animation

    /// 0.15 s — micro interactions (hover, press feedback).
    static let microDuration: Double = 0.15

    /// 0.3 s — standard transitions (expand, slide, fade).
    static let transitionDuration: Double = 0.3

    /// Standard ease-out curve for deceleration-style motion.
    static var easeOut: Animation {
        .easeOut
    }

    /// Micro interaction animation preset.
    static var microAnimation: Animation {
        .easeOut(duration: microDuration)
    }

    /// Standard transition animation preset.
    static var transitionAnimation: Animation {
        .easeOut(duration: transitionDuration)
    }

    // MARK: - Letter Spacing (Tracking)

    /// 0.08 em — label text tracking.
    ///
    /// Multiply by the font's point size to get the absolute tracking value
    /// for use with `.tracking(_:)`:
    /// ```swift
    /// Text("LABEL")
    ///     .font(.nothingLabel)
    ///     .tracking(NothingTheme.labelTracking * 11)
    /// ```
    static let labelTracking: CGFloat = 0.08

    /// 0.06 em — button text tracking.
    static let buttonTracking: CGFloat = 0.06
}
