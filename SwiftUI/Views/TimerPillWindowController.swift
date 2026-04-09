import SwiftUI

// MARK: - Transparent Hosting View

/// NSHostingView subclass that draws NO background.
/// The default NSHostingView is layer-backed and renders the system
/// window background via Core Animation layers, which shows as a gray
/// rectangle on transparent panels. This subclass clears all layer
/// backgrounds so only the SwiftUI content composites onto the panel.
@available(macOS 16.0, *)
private class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }

    override var isOpaque: Bool { false }
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = CGColor.clear
    }
}

// MARK: - TimerPillWindowController

/// Manages the floating NSPanel that hosts `TimerPillView`.
///
/// The panel is borderless, non-activating, draggable, and floats above
/// normal windows on all Spaces. Position is saved to UserDefaults.
@available(macOS 16.0, *)
@objc final class TimerPillWindowController: NSObject {

    @objc static let shared = TimerPillWindowController()

    private var panel: NSPanel?
    private var levelObserver: NSObjectProtocol?

    /// Shared view models from the bridge — the pill reads the same timer state.
    private var timerVM: TimerViewModel { SelfControlBridge.shared.timerVM }
    private var modeVM: ModeViewModel { SelfControlBridge.shared.modeVM }
    private var blockState: BlockStateViewModel { SelfControlBridge.shared.blockState }
    private var preferencesVM: PreferencesViewModel { SelfControlBridge.shared.preferencesVM }

    /// Just below normal windows — behind apps but above desktop/Finder icons,
    /// so the pill remains interactive (draggable, clickable).
    private static let desktopLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1
    )

    // MARK: - Show / Hide

    @objc func show() {
        guard panel == nil else {
            panel?.orderFront(nil)
            return
        }

        let pillView = TimerPillView()
            .environment(timerVM)
            .environment(modeVM)
            .environment(blockState)

        let hostingView = TransparentHostingView(rootView: pillView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = preferencesVM.timerPillFloatsOnTop ? .floating : Self.desktopLevel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView

        // Restore saved position or default to center-top
        restorePosition(for: panel)

        // Save position when dragged
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        // Auto-hide when block finishes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hide),
            name: .selfControlHideTimerPill,
            object: nil
        )

        // Update level immediately when preference changes
        levelObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            let floats = self.preferencesVM.timerPillFloatsOnTop
            let newLevel: NSWindow.Level = floats ? .floating : Self.desktopLevel
            if panel.level != newLevel {
                panel.level = newLevel
            }
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    @objc func hide() {
        savePosition()
        panel?.orderOut(nil)
        panel = nil
        if let levelObserver { NotificationCenter.default.removeObserver(levelObserver) }
        levelObserver = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .selfControlHideTimerPill, object: nil)
    }

    @objc var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Position Persistence

    @objc private func panelDidMove(_: Notification) {
        savePosition()
    }

    private func savePosition() {
        guard let frame = panel?.frame else { return }
        UserDefaults.standard.set(
            NSStringFromPoint(frame.origin),
            forKey: "TimerPillPosition"
        )
    }

    private func restorePosition(for panel: NSPanel) {
        if let savedString = UserDefaults.standard.string(forKey: "TimerPillPosition") {
            let origin = NSPointFromString(savedString)
            if origin != .zero {
                panel.setFrameOrigin(origin)
                return
            }
        }

        // Default: center horizontally, near top of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panel.frame.width / 2
            let y = screenFrame.maxY - panel.frame.height - 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
