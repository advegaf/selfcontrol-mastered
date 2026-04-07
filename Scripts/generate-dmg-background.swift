#!/usr/bin/env swift
//
//  generate-dmg-background.swift
//
//  Renders the SelfControl DMG background image in the Nothing design language.
//  Pure black canvas, dot-grid motif, three-layer typographic hierarchy.
//  Horizontally centered composition for a premium feel.
//
//  Usage:
//    swift Scripts/generate-dmg-background.swift <project-root> <output-png>
//

import AppKit
import CoreText
import Foundation

// MARK: - Geometry

// Window content size used by sindresorhus/create-dmg's default layout —
// matching it exactly so we can drop our custom Nothing background straight
// into the produced DMG without recomputing icon positions.
let logicalSize = CGSize(width: 660, height: 400)
let scale: CGFloat = 2.0   // always render @2x; we save as a single PNG
let pixelSize = CGSize(width: logicalSize.width * scale, height: logicalSize.height * scale)

// MARK: - Color tokens (Nothing dark mode)

let bgBlack       = NSColor(srgbRed: 0,    green: 0,    blue: 0,    alpha: 1)
let dotColor      = NSColor(srgbRed: 0.13, green: 0.13, blue: 0.13, alpha: 1)
let textDisplay   = NSColor.white
let textSecondary = NSColor(white: 0.60, alpha: 1)
let textDisabled  = NSColor(white: 0.40, alpha: 1)
let borderSubtle  = NSColor(white: 0.22, alpha: 1)

// MARK: - CLI args

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: generate-dmg-background.swift <project-root> <output-png>\n".data(using: .utf8)!)
    exit(2)
}
let projectRoot = URL(fileURLWithPath: args[1])
let outputURL   = URL(fileURLWithPath: args[2])

// MARK: - Font registration

let fontsDir = projectRoot
    .appendingPathComponent("SwiftUI")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Fonts")

guard FileManager.default.fileExists(atPath: fontsDir.path) else {
    FileHandle.standardError.write("error: fonts directory not found at \(fontsDir.path)\n".data(using: .utf8)!)
    exit(1)
}

let fontFiles = (try? FileManager.default.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil)) ?? []
for url in fontFiles where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
    var errorRef: Unmanaged<CFError>?
    if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef) {
        let err = errorRef?.takeRetainedValue()
        let desc = err.map { CFErrorCopyDescription($0) as String } ?? "unknown"
        if !desc.contains("already") {
            FileHandle.standardError.write("warning: could not register \(url.lastPathComponent): \(desc)\n".data(using: .utf8)!)
        }
    }
}

// MARK: - Font helpers

func nsFont(_ name: String, size: CGFloat) -> NSFont {
    if let f = NSFont(name: name, size: size * scale) { return f }
    FileHandle.standardError.write("warning: font '\(name)' not found, falling back to system\n".data(using: .utf8)!)
    return NSFont.systemFont(ofSize: size * scale)
}

let dotoHero    = nsFont("Ndot57Regular",     size: 48)   // primary hero (sized to fit above sindresorhus's 160px icons)
let labelMono   = nsFont("SpaceMono-Regular", size: 11)   // tertiary labels
let captionMono = nsFont("SpaceMono-Regular", size: 9)    // tagline metadata
let hintMono    = nsFont("SpaceMono-Regular", size: 10)   // install hint

// MARK: - Drawing helpers (same pattern as the previous working version)

/// Top-left logical coords → bottom-up pixel coords. Identical helper to the
/// previous (working) version of this script. The drawing coordinate space of
/// `NSGraphicsContext(bitmapImageRep:)` is the underlying *pixel buffer*, not
/// `rep.size`, so positions and font sizes are in physical pixels.
func tl(_ lx: CGFloat, _ ly: CGFloat) -> CGPoint {
    CGPoint(x: lx * scale, y: (logicalSize.height - ly) * scale)
}

/// Draws ALL CAPS Space Mono text at the given pixel point (bottom-left of bbox).
func drawLabel(_ text: String,
               at point: CGPoint,
               font: NSFont,
               color: NSColor,
               tracking: CGFloat = 1.6) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: tracking * scale,
    ]
    NSAttributedString(string: text.uppercased(), attributes: attrs).draw(at: point)
}

/// Same as drawLabel but horizontally centers the text at `centerXLogical`.
/// Returns the resulting bounding box width in PIXELS so the caller can chain
/// adjacent elements (e.g. an arrow next to a hint).
@discardableResult
func drawCenteredLabel(_ text: String,
                       centerXLogical cx: CGFloat,
                       baselineYLogical by: CGFloat,
                       font: NSFont,
                       color: NSColor,
                       tracking: CGFloat = 1.6) -> CGFloat {
    let upper = text.uppercased()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: tracking * scale,
    ]
    let attr = NSAttributedString(string: upper, attributes: attrs)
    let w = attr.size().width
    let xPixel = cx * scale - w / 2
    let yPixel = (logicalSize.height - by) * scale
    attr.draw(at: CGPoint(x: xPixel, y: yPixel))
    return w
}

/// Centered Doto display text. Doto's metric box is large; this just centers
/// the visible character cluster as best as the layout engine can.
func drawCenteredDoto(_ text: String,
                      centerXLogical cx: CGFloat,
                      baselineYLogical by: CGFloat,
                      font: NSFont,
                      color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
    ]
    let attr = NSAttributedString(string: text, attributes: attrs)
    let w = attr.size().width
    let xPixel = cx * scale - w / 2
    let yPixel = (logicalSize.height - by) * scale
    attr.draw(at: CGPoint(x: xPixel, y: yPixel))
}

/// Centered horizontal hairline.
func drawCenteredHRule(centerXLogical cx: CGFloat,
                       yLogical y: CGFloat,
                       lengthLogical length: CGFloat,
                       color: NSColor,
                       thickness: CGFloat = 1) {
    color.setStroke()
    let half = length / 2
    let path = NSBezierPath()
    path.lineWidth = thickness * scale
    path.move(to: CGPoint(x: (cx - half) * scale, y: (logicalSize.height - y) * scale))
    path.line(to: CGPoint(x: (cx + half) * scale, y: (logicalSize.height - y) * scale))
    path.stroke()
}

/// Subtle dot-grid background motif.
func drawDotGrid(spacing: CGFloat = 16, dotRadius: CGFloat = 0.8) {
    dotColor.setFill()
    let step = spacing * scale
    let r = dotRadius * scale
    var y: CGFloat = step
    while y < pixelSize.height {
        var x: CGFloat = step
        while x < pixelSize.width {
            NSBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
            x += step
        }
        y += step
    }
}

/// Small chevron arrow → drawn from `start` to `end` in logical coordinates.
func drawArrow(fromLogical start: CGPoint, toLogical end: CGPoint, color: NSColor) {
    let s = CGPoint(x: start.x * scale, y: (logicalSize.height - start.y) * scale)
    let e = CGPoint(x: end.x   * scale, y: (logicalSize.height - end.y)   * scale)

    color.setStroke()
    let line = NSBezierPath()
    line.lineWidth = 1.0 * scale
    line.lineCapStyle = .round
    line.move(to: s)
    line.line(to: e)
    line.stroke()

    let headLen: CGFloat = 5 * scale
    let head = NSBezierPath()
    head.lineWidth = 1.0 * scale
    head.lineCapStyle = .round
    head.move(to: CGPoint(x: e.x - headLen, y: e.y - headLen * 0.7))
    head.line(to: e)
    head.line(to: CGPoint(x: e.x - headLen, y: e.y + headLen * 0.7))
    head.stroke()
}

// MARK: - Compose

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pixelSize.width),
    pixelsHigh: Int(pixelSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
)!
// IMPORTANT: do NOT set `rep.size = logicalSize`. That makes path drawing use
// logical points but text drawing use pixels — a coordinate-space mismatch.
// Keep the rep at its native pixel dimensions; we add the 144 DPI metadata
// post-write via `sips` so Finder still treats this as a retina @2x image.

let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

// 1) Background fill
bgBlack.setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: pixelSize)).fill()

// 2) Subtle dot-grid motif
drawDotGrid()

// 3) Centered hero typographic stack — horizontal axis at cx = 330 logical
//    (660 / 2). Hero sits in the top section above where sindresorhus's
//    default icon row will land at y ≈ 200. Hint sits in the bottom strip.
let cx: CGFloat = logicalSize.width / 2

// Layout zones for 660 × 400 with sindresorhus's 160px icons centered at y≈200:
//   - Top zone (y < 110): hero typography
//   - Middle zone (y 120 - 300): icons (we leave this clear)
//   - Bottom zone (y > 320): install hint

// Tertiary label: SELFCONTROL
drawCenteredLabel("SELFCONTROL",
                  centerXLogical: cx,
                  baselineYLogical: 22,
                  font: labelMono,
                  color: textSecondary,
                  tracking: 2.6)

// Hairline divider directly under the label
drawCenteredHRule(centerXLogical: cx, yLogical: 32, lengthLogical: 70, color: borderSubtle)

// Primary hero: 1.0.0 in Doto — the ONE moment of surprise (Section 2.6)
drawCenteredDoto("1.0.0",
                 centerXLogical: cx,
                 baselineYLogical: 85,
                 font: dotoHero,
                 color: textDisplay)

// Secondary tagline below the hero
drawCenteredLabel("FORK / NOTHING DESIGN",
                  centerXLogical: cx,
                  baselineYLogical: 108,
                  font: captionMono,
                  color: textDisabled,
                  tracking: 2.0)

// Tertiary install hint sits in the breathing room between the hero
// typography (ends ~y=170) and the icon row (centers at y=270, top edge
// of icon body at ~y=222 with 96px icons). Putting the hint at y=210
// places it visually adjacent to the icons it describes, well above the
// icon labels — so it never collides.
let hintWidth = drawCenteredLabel("DRAG TO INSTALL",
                                  centerXLogical: cx - 12,
                                  baselineYLogical: 210,
                                  font: hintMono,
                                  color: textSecondary,
                                  tracking: 2.0)
// Arrow → starts just after the hint and points right.
let hintRightLogical = (cx - 12) + (hintWidth / scale) / 2
drawArrow(fromLogical: CGPoint(x: hintRightLogical + 8,  y: 206),
          toLogical:   CGPoint(x: hintRightLogical + 24, y: 206),
          color: textSecondary)

NSGraphicsContext.restoreGraphicsState()

// MARK: - Save

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("error: failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}

try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
do {
    try pngData.write(to: outputURL)
    print("wrote \(outputURL.path) (\(Int(pixelSize.width))x\(Int(pixelSize.height)) @\(Int(scale))x)")
} catch {
    FileHandle.standardError.write("error: failed to write \(outputURL.path): \(error)\n".data(using: .utf8)!)
    exit(1)
}
