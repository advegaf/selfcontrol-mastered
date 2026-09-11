import AppKit

/// Captures one of an app's windows to a file, chosen by how wide it is.
///
/// Run as `swift Scripts/window-shot.swift <ownerName> <out.png> [--shadow]
/// [--min-width N] [--max-width N]`.
///
/// SelfControl puts up two windows at once and they are the same app: a
/// 450x380 borderless panel for the menu bar interface and a 220x43 borderless
/// panel for the floating pill. The width band is what tells them apart.
///
/// This reads `CGWindowListCopyWindowInfo` and nothing else. The Accessibility
/// route the sibling repos use does not work here: SelfControl runs as an
/// accessory app whose panels are borderless and sit at `NSStatusWindowLevel`,
/// and a panel like that is not in `kAXWindowsAttribute` at all. The bounds in
/// the window list are accurate for it because the panel is created once and
/// positioned before it is ordered in, rather than being a fresh window whose
/// bounds are still a stub.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

guard CommandLine.arguments.count > 2 else {
    fail("usage: window-shot.swift <ownerName> <out.png> [--shadow] [--min-width N] [--max-width N]")
}
let owner = CommandLine.arguments[1]
let out = CommandLine.arguments[2]

/// Keeps the window's own drop shadow, which is what a page wants. The capture
/// then measures larger than the window by the shadow's margin.
let keepsShadow = CommandLine.arguments.contains("--shadow")

func numberArgument(_ flag: String, _ fallback: CGFloat) -> CGFloat {
    guard let index = CommandLine.arguments.firstIndex(of: flag),
          index + 1 < CommandLine.arguments.count,
          let value = Double(CommandLine.arguments[index + 1]) else { return fallback }
    return CGFloat(value)
}
let minWidth = numberArgument("--min-width", 300)
let maxWidth = numberArgument("--max-width", 10_000)

/// The largest on-screen window of `owner` inside the width band. Off-screen
/// windows are skipped on purpose: the window server has no backing store for
/// one, and `screencapture -l` fails rather than writing a blank file.
func candidate() -> (number: Int, bounds: CGRect)? {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] ?? []
    var best: (number: Int, bounds: CGRect)?
    for window in list where (window[kCGWindowOwnerName as String] as? String) == owner {
        guard let bounds = window[kCGWindowBounds as String],
              let rect = CGRect(dictionaryRepresentation: bounds as! CFDictionary),
              rect.width >= minWidth, rect.width <= maxWidth,
              let number = window[kCGWindowNumber as String] as? Int
        else { continue }
        if best == nil || rect.width * rect.height > best!.bounds.width * best!.bounds.height {
            best = (number, rect)
        }
    }
    return best
}

let scale = NSScreen.main?.backingScaleFactor ?? 2

for attempt in 1...4 {
    usleep(useconds_t(400_000 * attempt))
    guard let window = candidate() else { continue }

    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = keepsShadow
        ? ["-x", "-l", "\(window.number)", out]
        : ["-x", "-o", "-l", "\(window.number)", out]
    try? capture.run()
    capture.waitUntilExit()

    guard let data = try? Data(contentsOf: URL(fileURLWithPath: out)),
          let rep = NSBitmapImageRep(data: data) else { continue }
    let slack: CGFloat = keepsShadow ? 400 : 4
    if CGFloat(rep.pixelsWide) >= window.bounds.width * scale - 4,
       CGFloat(rep.pixelsWide) <= window.bounds.width * scale + slack,
       CGFloat(rep.pixelsHigh) >= window.bounds.height * scale - 4,
       CGFloat(rep.pixelsHigh) <= window.bounds.height * scale + slack {
        print(out)
        exit(0)
    }
    // The right window squeezed into the wrong size. Deleted rather than left
    // for someone to read as evidence.
    try? FileManager.default.removeItem(atPath: out)
}

fail("no on-screen \(owner) window between \(Int(minWidth)) and \(Int(maxWidth)) points wide; nothing written")
