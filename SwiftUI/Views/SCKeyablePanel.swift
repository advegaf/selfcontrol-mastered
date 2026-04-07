import AppKit

/// NSPanel subclass that accepts key window status even when borderless.
/// Required for SwiftUI TextFields to receive keyboard input.
@objc final class SCKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
