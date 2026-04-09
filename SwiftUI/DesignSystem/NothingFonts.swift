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
    /// Single weight — the Ndot 57 family only ships Regular.
    static func doto(size: CGFloat) -> Font {
        .custom("Ndot57Regular", size: size)
    }
}

// MARK: - Ndot 57 View Modifiers (font + proportional tracking)

@available(macOS 16.0, *)
extension View {

    /// Ndot 57 36pt + tracking — card titles.
    func nothingDisplayMD() -> some View {
        self.font(.doto(size: 36))
            .tracking(36 * 0.04)
    }
}
