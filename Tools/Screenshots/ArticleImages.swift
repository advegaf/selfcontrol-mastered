import AppKit

/// Composites the README images: a drawn ground, and the real window captures
/// placed on it.
///
/// Run as `swift Tools/Screenshots/ArticleImages.swift <raw dir> <out dir>`,
/// where the raw directory holds the captures `make-docs-images.sh` takes.
///
/// Three things here are load bearing.
///
/// The 144 DPI tag is the last thing that happens to a bitmap. Setting the size
/// before drawing makes the context one point per two pixels while every
/// rectangle below is still in pixels, so the whole composite doubles and runs
/// off the canvas.
///
/// A capture carries its own shadow as transparent margin, so the alpha
/// bounding box is what has to be measured to place anything precisely. The
/// window's rounded corners and traffic lights come from the window server;
/// nothing here draws a window frame.
///
/// Text is drawn with AppKit rather than composited from an image because
/// ImageMagick on macOS is commonly built without Freetype, where `-annotate`
/// warns about a missing delegate and then renders nothing at all.

// MARK: - Canvas

func bitmap(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("cannot allocate a \(width) by \(height) bitmap") }
    rep.size = NSSize(width: width, height: height)
    return rep
}

/// Paper. One flat colour behind everything, #101010, which is the ground the
/// portfolio's Minus cards already sit on. SelfControl's own windows are OLED
/// black, so they are darker than this rather than lighter, and what separates
/// them is the window's shadow plus the hairline drawn in `outline`.
func ground(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    let result = bitmap(width, height)
    guard let data = result.bitmapData else { fatalError("no bitmap data") }
    let paper: [UInt8] = [16, 16, 16, 255]
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * result.bytesPerRow + x * 4
            for channel in 0..<4 { data[offset + channel] = paper[channel] }
        }
    }
    return result
}

/// A canvas with nothing on it. The badge needs one: it sits on whatever colour
/// GitHub is painting behind the README, which is white in one theme and near
/// black in the other.
func clearCanvas(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    let result = bitmap(width, height)
    guard let data = result.bitmapData else { fatalError("no bitmap data") }
    memset(data, 0, result.bytesPerRow * height)
    return result
}

func withCanvas(_ canvas: NSBitmapImageRep, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// Half the pixel count means 144 DPI in the encoded file, so the PNG reads as
/// a retina asset rather than a very large 1x one.
func write(_ image: NSBitmapImageRep, to url: URL) {
    let pixels = NSSize(width: image.pixelsWide, height: image.pixelsHigh)
    image.size = NSSize(width: pixels.width / 2, height: pixels.height / 2)
    guard let png = image.representation(using: .png, properties: [:]) else {
        fatalError("cannot encode \(url.lastPathComponent)")
    }
    try! png.write(to: url)
    image.size = pixels
    print("\(url.lastPathComponent) \(image.pixelsWide)x\(image.pixelsHigh)")
}

// MARK: - Captures

struct Capture {
    let image: NSImage
    /// The part of the capture that is not fully transparent, in pixels with
    /// the origin at the top left.
    let content: CGRect
    let size: CGSize
}

func load(_ url: URL) -> Capture {
    guard let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data) else {
        fatalError("cannot read \(url.path)")
    }
    let width = rep.pixelsWide
    let height = rep.pixelsHigh
    rep.size = NSSize(width: width, height: height)
    var minX = width, minY = height, maxX = 0, maxY = 0
    if let data = rep.bitmapData {
        let samples = rep.samplesPerPixel
        for y in 0..<height {
            for x in 0..<width {
                let alpha = data[y * rep.bytesPerRow + x * samples + 3]
                if alpha > 8 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
    }
    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(rep)
    let content = minX <= maxX
        ? CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        : CGRect(x: 0, y: 0, width: width, height: height)
    return Capture(image: image, content: content, size: CGSize(width: width, height: height))
}

/// Draws a capture so its content box lands exactly on `target`, given with the
/// origin at the top left. The transparent shadow margin hangs outside it.
func place(_ capture: Capture, content target: CGRect, canvasHeight: CGFloat,
           interpolation: NSImageInterpolation = .high) {
    let scale = target.width / capture.content.width
    let full = CGRect(x: target.minX - capture.content.minX * scale,
                      y: target.minY - capture.content.minY * scale,
                      width: capture.size.width * scale,
                      height: capture.size.height * scale)
    let flipped = CGRect(x: full.minX, y: canvasHeight - full.maxY, width: full.width, height: full.height)
    NSGraphicsContext.current?.imageInterpolation = interpolation
    capture.image.draw(in: flipped, from: .zero, operation: .sourceOver, fraction: 1)
}

// MARK: - Type

func draw(_ text: String, at point: CGPoint, canvasHeight: CGFloat, size: CGFloat,
          weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
    ]
    let string = text as NSString
    let measured = string.size(withAttributes: attributes)
    string.draw(at: NSPoint(x: point.x, y: canvasHeight - point.y - measured.height),
                withAttributes: attributes)
}

// MARK: - Run

let arguments = CommandLine.arguments
let rawDirectory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "artifacts/article/raw", isDirectory: true)
let outDirectory = URL(fileURLWithPath: arguments.count > 2 ? arguments[2] : "docs/images", isDirectory: true)
try? FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)

func raw(_ name: String) -> Capture { load(rawDirectory.appendingPathComponent(name + ".png")) }

let ink = NSColor(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 1)
let inkSoft = NSColor(srgbRed: 0.62, green: 0.62, blue: 0.63, alpha: 1)

/// A 1px hairline at 8% white around a capture's content box. Black on #101010
/// is a 6-point separation, which survives a screenshot but not a thumbnail;
/// the portfolio's own cards solve it the same way with ring-white/10.
///
/// Only for a capture taken without its shadow. With one, the content box is
/// the window plus the shadow's transparent margin, and a line drawn round
/// that reads as a stray frame floating an inch off the window.
func outline(_ rect: CGRect, canvasHeight: CGFloat, radius: CGFloat) {
    let flipped = CGRect(x: rect.minX + 0.5, y: canvasHeight - rect.maxY + 0.5,
                         width: rect.width - 1, height: rect.height - 1)
    let path = NSBezierPath(roundedRect: flipped, xRadius: radius, yRadius: radius)
    path.lineWidth = 1
    NSColor(white: 1, alpha: 0.08).setStroke()
    path.stroke()
}

// The hero. The panel at a readable size with the floating pill beside it,
// because the pill is the part that is on screen while a block runs and the
// panel is the part you only see when you open it. 2400x1600 is the shape the
// portfolio cards use, so the cover comes out of this file.
do {
    let canvas = CGSize(width: 2400, height: 1600)
    let image = ground(Int(canvas.width), Int(canvas.height))
    let panel = raw("blocking")
    let pill = raw("pill")
    withCanvas(image) {
        let blockTop: CGFloat = 120
        let blockHeight: CGFloat = 215

        if let icon = NSImage(contentsOf: rawDirectory.appendingPathComponent("logo.png")) {
            NSGraphicsContext.current?.imageInterpolation = .high
            icon.draw(in: CGRect(x: 150, y: canvas.height - blockTop - 118, width: 118, height: 118))
        }
        draw("SelfControl", at: CGPoint(x: 300, y: blockTop + 2), canvasHeight: canvas.height,
             size: 64, weight: .semibold, color: ink)
        draw("Block it now. Argue with it later.", at: CGPoint(x: 304, y: blockTop + 88),
             canvasHeight: canvas.height, size: 30, weight: .regular, color: inkSoft)

        // The panel is fitted into what the brand block leaves, then the pill
        // is drawn under it at the width it really is relative to the panel.
        // Scaling the two independently would be a lie about how big the pill
        // is on screen, and the pill being small is the point of it.
        let availableTop = blockTop + blockHeight
        let box = CGRect(x: 150, y: availableTop,
                         width: canvas.width - 300,
                         height: canvas.height - availableTop - 95)
        let pillGap: CGFloat = 70
        let pillHeight = pill.content.height * (1.0)
        let scale = min(box.width / panel.content.width,
                        (box.height - pillGap) / (panel.content.height + pillHeight))
        let panelWidth = panel.content.width * scale
        let panelHeight = panel.content.height * scale
        let pillWidth = pill.content.width * scale
        let pillDrawnHeight = pill.content.height * scale
        let stackHeight = panelHeight + pillGap + pillDrawnHeight
        let top = box.maxY - stackHeight

        let panelRect = CGRect(x: box.midX - panelWidth / 2, y: top,
                               width: panelWidth, height: panelHeight)
        place(panel, content: panelRect, canvasHeight: canvas.height)

        let pillRect = CGRect(x: box.midX - pillWidth / 2, y: top + panelHeight + pillGap,
                              width: pillWidth, height: pillDrawnHeight)
        place(pill, content: pillRect, canvasHeight: canvas.height)
        outline(pillRect, canvasHeight: canvas.height, radius: pillDrawnHeight / 2)
    }
    write(image, to: outDirectory.appendingPathComponent("hero.png"))
}

// The panel on its own, at its own size, for the sections that need one.
for name in ["idle", "blocking", "settings"] {
    let capture = raw(name)
    let margin: CGFloat = 120
    let canvasSize = CGSize(width: capture.content.width + margin * 2,
                            height: capture.content.height + margin * 2)
    let image = ground(Int(canvasSize.width), Int(canvasSize.height))
    withCanvas(image) {
        let rect = CGRect(x: margin, y: margin,
                          width: capture.content.width, height: capture.content.height)
        place(capture, content: rect, canvasHeight: canvasSize.height, interpolation: .none)
    }
    write(image, to: outDirectory.appendingPathComponent(name + ".png"))
}

// The pill, alone and large, because at its real size on a 2400px canvas it is
// a smudge and the dimming is the thing worth seeing.
do {
    let pill = raw("pill")
    let margin: CGFloat = 90
    let scale: CGFloat = 2
    let width = pill.content.width * scale
    let height = pill.content.height * scale
    let image = ground(Int(width + margin * 2), Int(height + margin * 2))
    withCanvas(image) {
        let rect = CGRect(x: margin, y: margin, width: width, height: height)
        place(pill, content: rect, canvasHeight: height + margin * 2)
        outline(rect, canvasHeight: height + margin * 2, radius: height / 2)
    }
    write(image, to: outDirectory.appendingPathComponent("pill.png"))
}

// The download button the README links to releases with. Drawn rather than
// screenshotted: there is no such button anywhere in the app.
do {
    let canvas = CGSize(width: 950, height: 184)
    let image = clearCanvas(Int(canvas.width), Int(canvas.height))
    withCanvas(image) {
        let pill = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height),
                                xRadius: canvas.height / 2, yRadius: canvas.height / 2)
        NSColor(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 1).setFill()
        pill.fill()

        // U+F8FF is a private-use glyph that only the system font carries. Ask
        // for the font by name so a fallback cannot substitute an empty box.
        let logo = "\u{F8FF}" as NSString
        let mark = NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1)
        let logoAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "SF Pro Text", size: 72) ?? NSFont.systemFont(ofSize: 72),
            .foregroundColor: mark,
        ]
        let label = "Download for macOS" as NSString
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 60, weight: .semibold),
            .foregroundColor: mark,
        ]
        let logoSize = logo.size(withAttributes: logoAttributes)
        let labelSize = label.size(withAttributes: labelAttributes)
        let gap: CGFloat = 34
        let startX = (canvas.width - (logoSize.width + gap + labelSize.width)) / 2
        logo.draw(at: NSPoint(x: startX, y: (canvas.height - logoSize.height) / 2 + 4),
                  withAttributes: logoAttributes)
        label.draw(at: NSPoint(x: startX + logoSize.width + gap, y: (canvas.height - labelSize.height) / 2),
                   withAttributes: labelAttributes)
    }
    write(image, to: outDirectory.appendingPathComponent("download.png"))
}
