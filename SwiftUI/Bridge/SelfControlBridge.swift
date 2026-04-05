import SwiftUI

// MARK: - SelfControlBridge

/// Singleton bridge that owns the SwiftUI view models and vends
/// `NSHostingView`-backed views to the Objective-C layer.
///
/// Usage from Obj-C:
/// ```objc
/// NSView *rootView = [[SelfControlBridge shared] makeRootView];
/// ```
@available(macOS 16.0, *)
@objc
final class SelfControlBridge: NSObject {

    // MARK: - Singleton

    @objc static let shared = SelfControlBridge()

    // MARK: - View Models

    let blockState: BlockStateViewModel
    let timerVM: TimerViewModel
    let blocklistVM: BlocklistViewModel
    let preferencesVM: PreferencesViewModel

    // MARK: - Window Controllers

    private var settingsWindowController: NSWindowController?

    // MARK: - Init

    override init() {
        NothingFontRegistration.registerFonts()

        blockState = BlockStateViewModel()
        timerVM = TimerViewModel()
        blocklistVM = BlocklistViewModel()
        preferencesVM = PreferencesViewModel()

        super.init()
    }

    // MARK: - View Factories

    /// Returns the unified root view (setup + timer in one view)
    /// wrapped in an `NSHostingView`. Timer start is handled by the
    /// view itself via notification-driven state observation.
    @objc func makeRootView() -> NSView {
        let view = UnifiedRootView()
            .environment(blockState)
            .environment(timerVM)
            .environment(blocklistVM)
            .environment(preferencesVM)
        return NSHostingView(rootView: view)
    }

    // MARK: - Settings Window

    /// Opens a standalone settings window (used by the timer cog).
    /// During an active block, the blocklist is shown as read-only.
    @objc func openSettingsWindow() {
        // Reuse existing window if open
        if let existing = settingsWindowController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        blocklistVM.isReadOnly = SCUIUtilities.blockIsRunning()

        let settingsView = SettingsContainerView()
            .environment(blockState)
            .environment(timerVM)
            .environment(blocklistVM)
            .environment(preferencesVM)

        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 620, 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()

        settingsWindowController = NSWindowController(window: window)
        settingsWindowController?.showWindow(nil)
    }
}
