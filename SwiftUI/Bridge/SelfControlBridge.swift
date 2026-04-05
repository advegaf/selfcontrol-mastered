import SwiftUI

// MARK: - SelfControlBridge

/// Singleton bridge that owns the SwiftUI view models and vends
/// `NSHostingView`-backed views to the Objective-C layer.
///
/// Usage from Obj-C:
/// ```objc
/// NSView *menuBarView = [[SelfControlBridge shared] makeMenuBarContentView];
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
    let modeVM: ModeViewModel

    // MARK: - Init

    override init() {
        NothingFontRegistration.registerFonts()

        blockState = BlockStateViewModel()
        timerVM = TimerViewModel()
        blocklistVM = BlocklistViewModel()
        preferencesVM = PreferencesViewModel()
        modeVM = ModeViewModel()

        super.init()
    }

    // MARK: - View Factories

    /// Returns the menu bar popover content view wrapped in an `NSHostingView`.
    /// All view models are injected as environment objects.
    @objc func makeMenuBarContentView() -> NSView {
        let view = MenuBarContentView()
            .environment(blockState)
            .environment(timerVM)
            .environment(blocklistVM)
            .environment(preferencesVM)
            .environment(modeVM)
        return NSHostingView(rootView: view)
    }
}
