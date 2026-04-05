import SwiftUI
import CoreText

// MARK: - Font Weight Enum

/// Discrete weights available across the Nothing type families.
enum NothingFontWeight: String, Sendable {
    case light   = "Light"
    case regular = "Regular"
    case medium  = "Medium"
    case bold    = "Bold"
}

// MARK: - Font Registration

/// Handles one-time registration of custom font files bundled with the app.
enum NothingFontRegistration {

    /// Call once at app launch (e.g. in your `App.init`) to register every
    /// `.ttf` font file found in the main bundle.
    static func registerFonts() {
        guard let bundleURL = Bundle.main.resourceURL else { return }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }

        let fontExtensions: Set<String> = ["ttf", "otf"]
        for case let fileURL as URL in enumerator where fontExtensions.contains(fileURL.pathExtension.lowercased()) {
            var errorRef: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(
                fileURL as CFURL,
                .process,
                &errorRef
            )
            if !success {
                let error = errorRef?.takeRetainedValue()
                let description = error.map { CFErrorCopyDescription($0) as String } ?? "unknown"
                print("[NothingFonts] Failed to register \(fileURL.lastPathComponent): \(description)")
            }
        }
    }
}

// MARK: - Font Factories

/// SwiftUI `Font` accessors for the Nothing type system.
///
/// Usage:
/// ```swift
/// Text("Hello").font(.nothingBody)
/// Text("DISPLAY").font(.nothingDisplayXL)
/// ```
extension Font {

    // MARK: Family Factories

    /// Returns a Space Grotesk font at the given weight and point size.
    ///
    /// Available weights: `.light` (300), `.regular` (400), `.medium` (500), `.bold` (700).
    static func spaceGrotesk(_ weight: NothingFontWeight, size: CGFloat) -> Font {
        let familyName: String
        switch weight {
        case .light:   familyName = "SpaceGrotesk-Light"
        case .regular: familyName = "SpaceGrotesk-Regular"
        case .medium:  familyName = "SpaceGrotesk-Medium"
        case .bold:    familyName = "SpaceGrotesk-Bold"
        }
        return .custom(familyName, size: size)
    }

    /// Returns a Space Mono font at the given weight and point size.
    ///
    /// Available weights: `.regular` (400), `.bold` (700).
    static func spaceMono(_ weight: NothingFontWeight, size: CGFloat) -> Font {
        let familyName: String
        switch weight {
        case .regular, .light, .medium:
            familyName = "SpaceMono-Regular"
        case .bold:
            familyName = "SpaceMono-Bold"
        }
        return .custom(familyName, size: size)
    }

    /// Returns an Ndot 57 font at the given point size.
    ///
    /// Single weight — all weights map to Regular.
    static func doto(_ weight: NothingFontWeight = .regular, size: CGFloat) -> Font {
        .custom("Ndot57Regular", size: size)
    }

    // MARK: Semantic Tokens — Display

    /// Ndot 57 72pt — hero / splash screens.
    static var nothingDisplayXL: Font { .doto(size: 72) }

    /// Ndot 57 48pt — section headers.
    static var nothingDisplayLG: Font { .doto(size: 48) }

    /// Ndot 57 36pt — card titles.
    static var nothingDisplayMD: Font { .doto(size: 36) }

    // MARK: Semantic Tokens — Headings

    /// Space Grotesk Medium 24pt.
    static var nothingHeading: Font { .spaceGrotesk(.medium, size: 24) }

    /// Space Grotesk Regular 18pt.
    static var nothingSubheading: Font { .spaceGrotesk(.regular, size: 18) }

    // MARK: Semantic Tokens — Body

    /// Space Grotesk Regular 16pt — default reading size.
    static var nothingBody: Font { .spaceGrotesk(.regular, size: 16) }

    /// Space Grotesk Regular 14pt — secondary content.
    static var nothingBodySM: Font { .spaceGrotesk(.regular, size: 14) }

    // MARK: Semantic Tokens — Utility

    /// Space Mono Regular 12pt — timestamps, metadata.
    static var nothingCaption: Font { .spaceMono(.regular, size: 12) }

    /// Space Mono Regular 11pt — form labels, badges.
    static var nothingLabel: Font { .spaceMono(.regular, size: 11) }
}

// MARK: - Ndot 57 View Modifiers (font + proportional tracking)

@available(macOS 16.0, *)
extension View {

    /// Applies Ndot 57 at the given size with proportional tracking.
    func nothingDoto(size: CGFloat) -> some View {
        self.font(.doto(size: size))
            .tracking(size * 0.04)
    }

    /// Ndot 57 72pt + tracking — hero / splash screens.
    func nothingDisplayXL() -> some View { nothingDoto(size: 72) }

    /// Ndot 57 48pt + tracking — section headers.
    func nothingDisplayLG() -> some View { nothingDoto(size: 48) }

    /// Ndot 57 36pt + tracking — card titles.
    func nothingDisplayMD() -> some View { nothingDoto(size: 36) }
}
